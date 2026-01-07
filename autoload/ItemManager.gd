# autoload/ItemManager.gd
extends Node

const LEGACY_ITEMS_PATH := "res://data/items.json"
const ITEMS_DIR := "res://data/items"

var items_data: Dictionary = {}

signal items_reloaded(items: Dictionary)

func _ready():
	reload()

func reload() -> void:
	items_data.clear()
	_load_legacy_items()
	_load_items_from_dir(ITEMS_DIR)
	emit_signal("items_reloaded", items_data)
	print("[ItemManager] Загружено предметов:", items_data.size())

func _load_legacy_items() -> void:
	if not FileAccess.file_exists(LEGACY_ITEMS_PATH):
		return
	var json := JSON.new()
	var parse_err := json.parse(FileAccess.get_file_as_string(LEGACY_ITEMS_PATH))
	if parse_err != OK:
		push_warning("ItemManager: ошибка разбора %s" % LEGACY_ITEMS_PATH)
		return
	if json.data is Dictionary:
		var legacy_data: Dictionary = json.data
		for legacy_id in legacy_data.keys():
			if not legacy_data[legacy_id] is Dictionary:
				continue
			var entry: Dictionary = legacy_data[legacy_id]
			items_data[legacy_id] = entry.duplicate(true)

func _load_items_from_dir(dir_path: String) -> void:
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	for file_name in DirAccess.get_files_at(dir_path):
		if not file_name.ends_with(".json"):
			continue
		var full_path := "%s/%s" % [dir_path, file_name]
		var json := JSON.new()
		var parse_err := json.parse(FileAccess.get_file_as_string(full_path))
		if parse_err != OK:
			push_warning("ItemManager: ошибка разбора %s" % full_path)
			continue
		if json.data is Dictionary:
			var item_source: Dictionary = json.data
			var item_dict: Dictionary = item_source.duplicate(true)
			var item_id: String = str(item_dict.get("id", file_name.get_basename()))
			if item_id == "":
				push_warning("ItemManager: пропущен id в %s" % full_path)
				continue
			items_data[item_id] = item_dict

func get_item_data(item_id: String) -> Dictionary:
	if items_data.has(item_id):
		return items_data[item_id]
	push_warning("ItemManager: Неизвестный предмет '%s'" % item_id)
	return {}

func has_item(item_id: String) -> bool:
	return items_data.has(item_id)

func get_all_items() -> Dictionary:
	return items_data.duplicate(true)
