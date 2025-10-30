# autoload/ItemManager.gd
extends Node

var items_data: Dictionary = {}

func _ready():
	var path = "res://data/items.json"
	if FileAccess.file_exists(path):
		items_data = JSON.parse_string(FileAccess.open(path, FileAccess.READ).get_as_text())
		print("[ItemManager] Загружено предметов:", items_data.size())

# Получить данные предмета
func get_item_data(item_id: String) -> Dictionary:
	if items_data.has(item_id):
		return items_data[item_id]
	else:
		push_warning("ItemManager: Неизвестный предмет '%s'" % item_id)
		return {}
