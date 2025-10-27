# scripts/utils/json_utils.gd
# Утилиты для работы с JSON-файлами.
# Используются для загрузки и сохранения игровых данных (items, skills, recipes).

class_name JsonUtils

## Загружает данные из JSON-файла по указанному пути.
## @param path: Абсолютный или относительный путь к файлу (например, "res://data/items.json").
## @return: Dictionary или Array с данными, или null в случае ошибки.
static func load_json(path: String) -> Variant:
	var file = FileAccess.open(path, FileAccess.READ)
	if FileAccess.get_open_error() != OK:
		push_error("JsonUtils: Ошибка открытия файла: %s. Код ошибки: %s" % [path, FileAccess.get_open_error()])
		return null
	
	var content = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(content)
	
	if error != OK:
		push_error("JsonUtils: Ошибка парсинга JSON в файле: %s. Ошибка: %s" % [path, json.get_error_message()])
		return null
		
	return json.get_data()

## Сохраняет данные в JSON-файл по указанному пути.
## @param path: Абсолютный или относительный путь к файлу (например, "user://savegame.json").
## @param data: Dictionary или Array для сохранения.
## @return: OK в случае успеха, или код ошибки.
static func save_json(path: String, data: Variant) -> int:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if FileAccess.get_open_error() != OK:
		push_error("JsonUtils: Ошибка создания/открытия файла для записи: %s. Код ошибки: %s" % [path, FileAccess.get_open_error()])
		return FileAccess.get_open_error()
		
	var content = JSON.stringify(data, "\t") # Используем табуляцию для читаемости
	file.store_string(content)
	file.close()
	
	return OK
