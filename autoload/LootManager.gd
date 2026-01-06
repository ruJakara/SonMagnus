# autoload/LootManager.gd
# Глобальный менеджер для обработки дропа предметов
# Загружает таблицы лута и генерирует предметы по шансам

extends Node

## Загруженные таблицы лута {id: loot_table_data}
var _loot_tables: Dictionary = {}

## Путь к директории с таблицами лута
const LOOT_TABLES_DIR: String = "res://data/loot_tables/"

func _ready() -> void:
	_load_all_loot_tables()

## Загружает все таблицы лута из директории
func _load_all_loot_tables() -> void:
	var dir = DirAccess.open(LOOT_TABLES_DIR)
	if dir == null:
		push_warning("[LootManager] Директория таблиц лута не найдена: %s" % LOOT_TABLES_DIR)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".json") and not dir.current_is_dir():
			var path = LOOT_TABLES_DIR + file_name
			_load_loot_table(path)
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	if Config.DEBUG_LOGS:
		print_debug("[LootManager] Загружено таблиц лута: %d" % _loot_tables.size())

## Загружает одну таблицу лута
func _load_loot_table(path: String) -> bool:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[LootManager] Не удалось открыть файл: %s" % path)
		return false
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		push_error("[LootManager] Ошибка парсинга JSON: %s (line %d)" % [path, json.get_error_line()])
		return false
	
	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		push_error("[LootManager] JSON таблицы лута должен быть объектом: %s" % path)
		return false
	
	var table_id = data.get("id", "")
	if table_id.is_empty():
		push_error("[LootManager] Таблица лута без ID: %s" % path)
		return false
	
	_loot_tables[table_id] = data
	
	if Config.DEBUG_LOGS:
		print_debug("[LootManager] Загружена таблица лута: %s (%d предметов)" % [table_id, data.get("items", []).size()])
	
	return true

## Генерирует лут по таблице
## @param table_id: ID таблицы лута
## @return Array[Dictionary] - список сгенерированных предметов {item_id, amount}
func roll_loot(table_id: String) -> Array:
	if not _loot_tables.has(table_id):
		push_warning("[LootManager] Таблица лута не найдена: %s" % table_id)
		return []
	
	var table = _loot_tables[table_id]
	var items_data = table.get("items", [])
	var result: Array = []
	
	for item_entry in items_data:
		if typeof(item_entry) != TYPE_DICTIONARY:
			continue
		
		var drop_chance = item_entry.get("drop_chance", 1.0)
		var roll = randf()
		
		# Проверяем выпал ли предмет
		if roll <= drop_chance:
			var item_id = item_entry.get("item_id", "")
			var min_amount = item_entry.get("min_amount", 1)
			var max_amount = item_entry.get("max_amount", 1)
			var amount = randi_range(min_amount, max_amount)
			
			result.append({
				"item_id": item_id,
				"amount": amount
			})
			
			if Config.DEBUG_LOGS:
				print_debug("[LootManager] Выпал предмет: %s x%d (шанс: %.2f%%)" % [item_id, amount, drop_chance * 100])
	
	return result

## Получает данные таблицы лута
func get_loot_table(table_id: String) -> Dictionary:
	return _loot_tables.get(table_id, {})

## Перезагружает все таблицы лута
func reload_loot_tables() -> void:
	_loot_tables.clear()
	_load_all_loot_tables()


