extends Node

const UPGRADES_DIR := "res://data/camp_upgrades"

signal upgrades_changed(modifiers: Dictionary)

var upgrade_definitions: Dictionary = {}
var upgrade_states: Dictionary = {}
var modifiers: Dictionary = {}
var camp_level: int = 1

func _ready():
	reload()

func reload() -> void:
	_load_definitions()
	_recalculate_modifiers()

func _load_definitions() -> void:
	upgrade_definitions.clear()
	if not DirAccess.dir_exists_absolute(UPGRADES_DIR):
		return
	for file_name in DirAccess.get_files_at(UPGRADES_DIR):
		if not file_name.ends_with(".json"):
			continue
		var full_path := "%s/%s" % [UPGRADES_DIR, file_name]
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(full_path)) != OK:
			push_warning("[CampUpgradeManager] Не удалось загрузить %s" % full_path)
			continue
		if json.data is Dictionary:
			var def: Dictionary = json.data.duplicate(true)
			var upgrade_id := def.get("upgrade_id", file_name.get_basename())
			if upgrade_id == "":
				push_warning("[CampUpgradeManager] upgrade_id отсутствует в %s" % full_path)
				continue
			def["levels"] = _sorted_levels(def.get("levels", []))
			def["max_level"] = int(def.get("max_level", def["levels"].size()))
			upgrade_definitions[upgrade_id] = def
			if upgrade_states.has(upgrade_id):
				upgrade_states[upgrade_id] = clamp(upgrade_states[upgrade_id], 0, def["max_level"])

func _sorted_levels(levels: Array) -> Array:
	var copy := []
	for level_data in levels:
		if level_data is Dictionary:
			copy.append(level_data.duplicate(true))
	copy.sort_custom(func(a, b):
		return int(a.get("level", 0)) < int(b.get("level", 0))
	)
	return copy

func get_upgrade_definitions() -> Dictionary:
	return upgrade_definitions.duplicate(true)

func get_upgrade_state(upgrade_id: String) -> int:
	return upgrade_states.get(upgrade_id, 0)

func get_upgrade_status(upgrade_id: String) -> Dictionary:
	var definition := upgrade_definitions.get(upgrade_id, {})
	if definition.is_empty():
		return {}
	var current_level := get_upgrade_state(upgrade_id)
	var next_level_data := _get_level_data(definition, current_level + 1)
	return {
		"upgrade_id": upgrade_id,
		"definition": definition,
		"current_level": current_level,
		"max_level": int(definition.get("max_level", 0)),
		"next_level_data": next_level_data
	}

func _get_level_data(definition: Dictionary, level: int) -> Dictionary:
	for level_data in definition.get("levels", []):
		if int(level_data.get("level", 0)) == level:
			return level_data.duplicate(true)
	return {}

func can_upgrade(upgrade_id: String) -> Dictionary:
	var status := get_upgrade_status(upgrade_id)
	if status.is_empty():
		return {"success": false, "reason": "Неизвестное улучшение"}
	if status["current_level"] >= status["max_level"]:
		return {"success": false, "reason": "Достигнут максимальный уровень"}
	var next_level: Dictionary = status["next_level_data"]
	if next_level.is_empty():
		return {"success": false, "reason": "Нет данных по следующему уровню"}
	var requirements := next_level.get("requirements", {})
	var req_check := _check_requirements(requirements)
	if not req_check["success"]:
		return req_check
	var cost: Dictionary = next_level.get("cost", {})
	if not CampStorageManager.has_free(cost):
		return {
			"success": false,
			"reason": "Недостаточно ресурсов",
			"cost": cost
		}
	return {
		"success": true,
		"reason": "Готов к улучшению",
		"cost": cost,
		"next_level": next_level
	}

func _check_requirements(requirements: Dictionary) -> Dictionary:
	var result := {"success": true, "reason": ""}
	var min_camp_level := int(requirements.get("min_camp_level", 0))
	if min_camp_level > camp_level:
		result["success"] = false
		result["reason"] = "Требуется уровень лагеря %d" % min_camp_level
		return result
	var upgrade_reqs: Dictionary = requirements.get("requires_upgrades", {})
	for upgrade_id in upgrade_reqs.keys():
		var required_level := int(upgrade_reqs[upgrade_id])
		if get_upgrade_state(upgrade_id) < required_level:
			result["success"] = false
			result["reason"] = "Нужно %s уровня %d" % [upgrade_id, required_level]
			return result
	return result

func apply_upgrade(upgrade_id: String) -> Dictionary:
	var can_result := can_upgrade(upgrade_id)
	if not can_result["success"]:
		return can_result
	var cost: Dictionary = can_result.get("cost", {})
	if not CampStorageManager.consume_free(cost):
		return {"success": false, "reason": "Не удалось списать ресурсы"}
	var new_level := get_upgrade_state(upgrade_id) + 1
	upgrade_states[upgrade_id] = new_level
	_recalculate_modifiers()
	return {
		"success": true,
		"new_level": new_level,
		"message": "Улучшение %s достигло уровня %d" % [upgrade_id, new_level]
	}

func _recalculate_modifiers() -> void:
	modifiers = {}
	for upgrade_id in upgrade_definitions.keys():
		var current_level := get_upgrade_state(upgrade_id)
		if current_level <= 0:
			continue
		var definition := upgrade_definitions[upgrade_id]
		for level_data in definition.get("levels", []):
			if int(level_data.get("level", 0)) <= current_level:
				_merge_effects(level_data.get("effects", {}))
	if not modifiers.has("autocraft_speed_multiplier"):
		modifiers["autocraft_speed_multiplier"] = 1.0
	if not modifiers.has("unlock_station_types"):
		modifiers["unlock_station_types"] = []
	if not modifiers.has("station_level_bonus"):
		modifiers["station_level_bonus"] = {}
	emit_signal("upgrades_changed", modifiers)

func _merge_effects(effects: Dictionary) -> void:
	for key in effects.keys():
		var value = effects[key]
		match key:
			"unlock_station_type":
				var arr: Array = modifiers.get("unlock_station_types", []).duplicate()
				if value is String and not arr.has(value):
					arr.append(value)
				modifiers["unlock_station_types"] = arr
			"station_level_bonus":
				if value is Dictionary:
					var map: Dictionary = modifiers.get("station_level_bonus", {}).duplicate()
					for station in value.keys():
						map[station] = map.get(station, 0) + int(value[station])
					modifiers["station_level_bonus"] = map
				else:
					modifiers["station_level_bonus"] = modifiers.get("station_level_bonus", 0) + int(value)
			"autocraft_speed_multiplier":
				var current := modifiers.get("autocraft_speed_multiplier", 1.0)
				modifiers["autocraft_speed_multiplier"] = current * float(value)
			_:
				if value is bool:
					modifiers[key] = modifiers.get(key, false) or bool(value)
				elif value is float:
					modifiers[key] = modifiers.get(key, 0.0) + float(value)
				else:
					modifiers[key] = modifiers.get(key, 0) + int(value)

func get_effective_modifiers() -> Dictionary:
	if modifiers.is_empty():
		_recalculate_modifiers()
	return modifiers.duplicate(true)

func get_modifier(key: String, default_value):
	if modifiers.is_empty():
		_recalculate_modifiers()
	return modifiers.get(key, default_value)

func get_upgrade_states() -> Dictionary:
	return upgrade_states.duplicate()

func reset_progress() -> void:
	upgrade_states.clear()
	_recalculate_modifiers()

