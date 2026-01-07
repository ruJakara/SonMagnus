# autoload/CraftManager.gd
extends Node

const RECIPES_DIR := "res://data/recipes"
const EXPERIMENTS_DIR := "res://data/experiments"
const FALLBACK_ETHER_ID := "ether"

var recipes: Dictionary = {}
var recipes_by_pair: Dictionary = {}
var experiments: Array = []
var rng := RandomNumberGenerator.new()

func _ready():
	rng.randomize()
	reload_data()

func reload_data() -> void:
	_load_recipes()
	_load_experiments()

func _load_recipes() -> void:
	recipes.clear()
	recipes_by_pair.clear()
	if not DirAccess.dir_exists_absolute(RECIPES_DIR):
		return
	for file_name in DirAccess.get_files_at(RECIPES_DIR):
		if not file_name.ends_with(".json"):
			continue
		var full_path := "%s/%s" % [RECIPES_DIR, file_name]
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(full_path)) != OK:
			push_warning("CraftManager: ошибка разбора %s" % full_path)
			continue
		if not (json.data is Dictionary):
			continue
		var recipe: Dictionary = json.data.duplicate(true)
		var recipe_id := recipe.get("id", file_name.get_basename())
		if recipe_id == "":
			push_warning("CraftManager: рецепт без id (%s)" % full_path)
			continue
		recipes[recipe_id] = recipe
		var key := _pair_key(recipe.get("slot1_id", ""), recipe.get("slot2_id", ""))
		if key == "":
			continue
		if not recipes_by_pair.has(key):
			recipes_by_pair[key] = []
		recipes_by_pair[key].append(recipe_id)

func _load_experiments() -> void:
	experiments.clear()
	if not DirAccess.dir_exists_absolute(EXPERIMENTS_DIR):
		return
	for file_name in DirAccess.get_files_at(EXPERIMENTS_DIR):
		if not file_name.ends_with(".json"):
			continue
		var full_path := "%s/%s" % [EXPERIMENTS_DIR, file_name]
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(full_path)) != OK:
			push_warning("CraftManager: ошибка разбора %s" % full_path)
			continue
		if json.data is Dictionary:
			experiments.append(json.data.duplicate(true))

func try_manual(slot1_id: String, slot2_id: String, slot3_id: String = "", workshop_type := "forge", mode := "craft") -> Dictionary:
	var result := _initial_result()
	var primary := slot1_id.strip_edges()
	var secondary := slot2_id.strip_edges()
	var tertiary := slot3_id.strip_edges()
	if primary == "" or secondary == "":
		result["message"] = "Нужно два основных ингредиента"
		return result
	var is_experiment := tertiary != ""
	var recipe := {}
	if not is_experiment:
		recipe = get_recipe_for_slots(primary, secondary, workshop_type)
		if recipe.is_empty():
			result["message"] = "Неизвестный рецепт"
			return result
	var required := _build_requirements(primary, secondary, tertiary if is_experiment else "")
	if not CampStorageManager.has_free(required):
		result["message"] = "Недостаточно ресурсов на складе"
		return result
	if not CampStorageManager.consume_free(required):
		result["message"] = "Не удалось списать ресурсы"
		return result
	result["success"] = true
	result["consumed_items"] = required
	result["is_experiment"] = is_experiment
	if is_experiment:
		result["produced_items"], result["used_fallback_ether"] = _resolve_experiment(primary, secondary, tertiary)
		result["message"] = "Эксперимент завершён"
	else:
		result["produced_items"] = get_recipe_output(recipe, 1)
		result["message"] = "Создан предмет по рецепту %s" % recipe.get("label", recipe.get("id", ""))
	return result

func get_recipe(recipe_id: String) -> Dictionary:
	return recipes.get(recipe_id, {}).duplicate(true)

func get_recipe_for_slots(slot1_id: String, slot2_id: String, workshop_type := "forge") -> Dictionary:
	var key := _pair_key(slot1_id, slot2_id)
	if key == "":
		return {}
	if not recipes_by_pair.has(key):
		return {}
	for recipe_id in recipes_by_pair[key]:
		var recipe: Dictionary = recipes.get(recipe_id, {})
		if recipe.is_empty():
			continue
		if recipe.get("workshop_type", "forge") == workshop_type:
			return recipe.duplicate(true)
	return {}

func get_recipe_ingredients(recipe: Dictionary, count: int = 1) -> Dictionary:
	var ingredients := {}
	var slot1 := recipe.get("slot1_id", "")
	var slot2 := recipe.get("slot2_id", "")
	for i in range(max(count, 1)):
		if slot1 != "":
			ingredients[slot1] = ingredients.get(slot1, 0) + 1
		if slot2 != "":
			ingredients[slot2] = ingredients.get(slot2, 0) + 1
	return ingredients

func get_recipe_output(recipe: Dictionary, count: int = 1) -> Dictionary:
	var output := {}
	var base := recipe.get("output", {})
	for item_id in base.keys():
		var amount := int(base[item_id]) * max(count, 1)
		if amount == 0:
			continue
		output[item_id] = output.get(item_id, 0) + amount
	return output

func _build_requirements(slot1_id: String, slot2_id: String, slot3_id: String) -> Dictionary:
	var requirements := {}
	var slots := [slot1_id, slot2_id, slot3_id]
	for id in slots:
		if id == null or id == "":
			continue
		requirements[id] = requirements.get(id, 0) + 1
	return requirements

func _pair_key(slot1_id: String, slot2_id: String) -> String:
	if slot1_id == "" or slot2_id == "":
		return ""
	var ordered := [slot1_id, slot2_id]
	ordered.sort()
	return "%s+%s" % [ordered[0], ordered[1]]

func _initial_result() -> Dictionary:
	return {
		"success": false,
		"is_experiment": false,
		"consumed_items": {},
		"produced_items": {},
		"used_fallback_ether": false,
		"message": ""
	}

func _resolve_experiment(slot1_id: String, slot2_id: String, _slot3_id: String) -> Array:
	var definition := _find_experiment_definition(slot1_id, slot2_id)
	if definition.is_empty():
		return [_fallback_ether({}), true]
	var pool: Array = definition.get("outcome_pool", [])
	if pool.is_empty():
		return [_fallback_ether(definition), true]
	var total_weight := 0.0
	for entry in pool:
		total_weight += float(entry.get("weight", 1.0))
	var pick := rng.randf_range(0.0, max(total_weight, 0.001))
	var accumulator := 0.0
	for entry in pool:
		accumulator += float(entry.get("weight", 1.0))
		if pick > accumulator:
			continue
		var amount := _roll_amount(entry)
		var produced := {entry.get("item_id", FALLBACK_ETHER_ID): amount}
		var bonus := definition.get("ether_bonus_per_slot3", 0)
		if bonus > 0:
			produced[FALLBACK_ETHER_ID] = produced.get(FALLBACK_ETHER_ID, 0) + int(bonus)
		return [produced, false]
	return [_fallback_ether(definition), true]

func _roll_amount(entry: Dictionary) -> int:
	var min_amount := int(entry.get("min_amount", entry.get("amount", 1)))
	var max_amount := int(entry.get("max_amount", min_amount))
	if max_amount < min_amount:
		max_amount = min_amount
	return rng.randi_range(min_amount, max_amount)

func _fallback_ether(definition: Dictionary) -> Dictionary:
	if definition.has("fallback") and definition["fallback"] is Dictionary:
		var data: Dictionary = definition["fallback"]
		var item_id := data.get("item_id", FALLBACK_ETHER_ID)
		var amount := max(int(data.get("amount", 1)), 1)
		return {item_id: amount}
	return {FALLBACK_ETHER_ID: 1}

func _find_experiment_definition(slot1_id: String, slot2_id: String) -> Dictionary:
	var key := _pair_key(slot1_id, slot2_id)
	for definition in experiments:
		var pair := definition.get("core_pair", [])
		if pair.size() < 2:
			continue
		var def_key := _pair_key(pair[0], pair[1])
		if def_key == key:
			return definition.duplicate(true)
	return {}
