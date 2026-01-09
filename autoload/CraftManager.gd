# autoload/CraftManager.gd
extends Node

const RECIPES_DIR := "res://data/recipes"
const EXPERIMENTS_DIR := "res://data/experiments"
const FALLBACK_ETHER_ID := "ether"

var recipes: Dictionary = {}
var recipes_by_pair: Dictionary = {}
var experiments: Array = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

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
		var source_recipe_variant: Variant = json.data
		var source_recipe: Dictionary = source_recipe_variant
		var recipe: Dictionary = source_recipe.duplicate(true)
		var recipe_id: String = recipe.get("id", file_name.get_basename())
		if recipe_id == "":
			push_warning("CraftManager: рецепт без id (%s)" % full_path)
			continue
		recipes[recipe_id] = recipe
		var key: String = _pair_key(recipe.get("slot1_id", ""), recipe.get("slot2_id", ""))
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
			var experiment_variant: Variant = json.data
			var experiment_definition: Dictionary = experiment_variant
			experiments.append(experiment_definition.duplicate(true))

func try_manual(slot1_id: String, slot2_id: String, slot3_id: String = "", workshop_type := "forge", _mode := "craft") -> Dictionary:
	var result: Dictionary = _initial_result()
	var primary: String = slot1_id.strip_edges()
	var secondary: String = slot2_id.strip_edges()
	var tertiary: String = slot3_id.strip_edges()
	if primary == "" or secondary == "":
		result["message"] = "Нужно два основных ингредиента"
		return result
	var is_experiment := tertiary != ""
	var recipe: Dictionary = {}
	if not is_experiment:
		recipe = get_recipe_for_slots(primary, secondary, workshop_type)
		if recipe.is_empty():
			result["message"] = "Неизвестный рецепт"
			return result
	var slot3_for_requirements: String = tertiary if is_experiment else ""
	var required: Dictionary = _build_requirements(primary, secondary, slot3_for_requirements)
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
		var experiment_resolution: Dictionary = _resolve_experiment(primary, secondary, tertiary)
		result["produced_items"] = experiment_resolution.get("produced_items", {})
		result["used_fallback_ether"] = experiment_resolution.get("used_fallback_ether", false)
		result["message"] = experiment_resolution.get("message", "Эксперимент завершён")
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
	var ingredients: Dictionary = {}
	var slot1: String = recipe.get("slot1_id", "")
	var slot2: String = recipe.get("slot2_id", "")
	for i in range(max(count, 1)):
		if slot1 != "":
			ingredients[slot1] = ingredients.get(slot1, 0) + 1
		if slot2 != "":
			ingredients[slot2] = ingredients.get(slot2, 0) + 1
	return ingredients

func get_recipe_output(recipe: Dictionary, count: int = 1) -> Dictionary:
	var output: Dictionary = {}
	var base: Dictionary = recipe.get("output", {})
	for item_id in base.keys():
		var amount: int = int(base[item_id]) * max(count, 1)
		if amount == 0:
			continue
		output[item_id] = output.get(item_id, 0) + amount
	return output

func _build_requirements(slot1_id: String, slot2_id: String, slot3_id: String) -> Dictionary:
	var requirements: Dictionary = {}
	var slots: Array = [slot1_id, slot2_id, slot3_id]
	for ingredient in slots:
		if ingredient == null or ingredient == "":
			continue
		requirements[ingredient] = requirements.get(ingredient, 0) + 1
	return requirements

func _pair_key(slot1_id: String, slot2_id: String) -> String:
	if slot1_id == "" or slot2_id == "":
		return ""
	var ordered: Array = [slot1_id, slot2_id]
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

func _resolve_experiment(slot1_id: String, slot2_id: String, _slot3_id: String) -> Dictionary:
	var definition: Dictionary = _find_experiment_definition(slot1_id, slot2_id)
	if definition.is_empty():
		return {
			"produced_items": _fallback_ether({}),
			"used_fallback_ether": true,
			"message": "Апгрейд не найден, получен эфир"
		}
	var pool_variant: Variant = definition.get("outcome_pool", [])
	var pool: Array = pool_variant if pool_variant is Array else []
	if pool.is_empty():
		return {
			"produced_items": _fallback_ether(definition),
			"used_fallback_ether": true,
			"message": "Нет результатов эксперимента, получен эфир"
		}
	var total_weight: float = 0.0
	for entry_variant in pool:
		if not entry_variant is Dictionary:
			continue
		var weight_entry: Dictionary = entry_variant
		total_weight += float(weight_entry.get("weight", 1.0))
	var pick: float = rng.randf_range(0.0, max(total_weight, 0.001))
	var accumulator: float = 0.0
	for entry_variant in pool:
		if not entry_variant is Dictionary:
			continue
		var entry: Dictionary = entry_variant
		accumulator += float(entry.get("weight", 1.0))
		if pick > accumulator:
			continue
		var amount: int = _roll_amount(entry)
		var produced: Dictionary = {entry.get("item_id", FALLBACK_ETHER_ID): amount}
		var bonus: int = int(definition.get("ether_bonus_per_slot3", 0))
		if bonus > 0:
			produced[FALLBACK_ETHER_ID] = produced.get(FALLBACK_ETHER_ID, 0) + int(bonus)
		return {
			"produced_items": produced,
			"used_fallback_ether": false,
			"message": "Эксперимент завершён"
		}
	return {
		"produced_items": _fallback_ether(definition),
		"used_fallback_ether": true,
		"message": "Апгрейд вернул эфир"
	}

func _roll_amount(entry: Dictionary) -> int:
	var min_amount: int = int(entry.get("min_amount", entry.get("amount", 1)))
	var max_amount: int = int(entry.get("max_amount", min_amount))
	if max_amount < min_amount:
		max_amount = min_amount
	return rng.randi_range(min_amount, max_amount)

func _fallback_ether(definition: Dictionary) -> Dictionary:
	if definition.has("fallback") and definition["fallback"] is Dictionary:
		var data_variant: Variant = definition["fallback"]
		var data: Dictionary = data_variant
		var item_id: String = data.get("item_id", FALLBACK_ETHER_ID)
		var amount: int = max(int(data.get("amount", 1)), 1)
		return {item_id: amount}
	return {FALLBACK_ETHER_ID: 1}

func _find_experiment_definition(slot1_id: String, slot2_id: String) -> Dictionary:
	var key: String = _pair_key(slot1_id, slot2_id)
	for definition_variant in experiments:
		if not definition_variant is Dictionary:
			continue
		var definition: Dictionary = definition_variant
		var pair_variant: Variant = definition.get("core_pair", [])
		var pair: Array = pair_variant if pair_variant is Array else []
		if pair.size() < 2:
			continue
		var def_key := _pair_key(pair[0], pair[1])
		if def_key == key:
			return definition.duplicate(true)
	return {}
