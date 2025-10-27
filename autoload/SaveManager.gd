# autoload/SaveManager.gd
# Менеджер сохранения и загрузки игры. Использует JSON и шифрование AES256.
# Подключается как Autoload с именем "SaveManager".

extends Node

## @brief Инициализация класса SaveManager.
func _ready():
	print("SaveManager.gd загружен.")

# --- [ Константы ] ---

## Путь к файлу сохранения.
const SAVE_PATH: String = "user://savegame.dat"
## Ключ шифрования (должен быть 32 байта для AES-256).
const ENCRYPTION_KEY: PackedByteArray = "Это_очень_секретный_ключ_на_32_байта".to_utf8_buffer().sha256_buffer()

## @brief Сохраняет данные игры с шифрованием.
## @param data: Словарь с данными для сохранения.
## @return: OK в случае успеха.
func save_game(data: Dictionary) -> int:
	# 1. Сериализация данных в строку JSON
	var json_string = JSON.stringify(data)
	var json_bytes = json_string.to_utf8_buffer()
	
	# 2. Шифрование
	var crypto = Crypto.new()
	var encrypted_bytes: PackedByteArray
	
	if Config.SAVE_TEST_MODE: # Проверка на dev-переключатель
		encrypted_bytes = json_bytes
		print("SaveManager: Сохранение в тестовом режиме (без шифрования).")
	else:
		# Используем AES-256 в режиме ECB (простейший для примера)
		# В реальном проекте лучше использовать режимы с IV (например, CBC или GCM)
		encrypted_bytes = crypto.encrypt(ENCRYPTION_KEY, json_bytes)
		print("SaveManager: Сохранение с шифрованием.")

	# 3. Запись в файл
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if FileAccess.get_open_error() != OK:
		push_error("SaveManager: Ошибка открытия файла для записи: %s" % FileAccess.get_open_error())
		return FileAccess.get_open_error()
		
	file.store_buffer(encrypted_bytes)
	file.close()
	
	print("SaveManager: Игра успешно сохранена в %s" % SAVE_PATH)
	return OK

## @brief Загружает данные игры с дешифрованием.
## @return: Словарь с данными или null в случае ошибки.
func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		push_error("SaveManager: Файл сохранения не найден: %s" % SAVE_PATH)
		return null
		
	# 1. Чтение из файла
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var encrypted_bytes = file.get_buffer(file.get_length())
	file.close()

	# 2. Дешифрование
	var json_bytes: PackedByteArray
	
	if Config.SAVE_TEST_MODE: # Проверка на dev-переключатель
		json_bytes = encrypted_bytes
		print("SaveManager: Загрузка в тестовом режиме (без дешифрования).")
	else:
		var crypto = Crypto.new()
		# Дешифрование
		json_bytes = crypto.decrypt(ENCRYPTION_KEY, encrypted_bytes)
		print("SaveManager: Загрузка с дешифрованием.")

	# 3. Десериализация JSON
	var json_string = json_bytes.get_string_from_utf8()
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error != OK:
		push_error("SaveManager: Ошибка парсинга JSON после дешифрования. Ошибка: %s" % json.get_error_message())
		return null
		
	print("SaveManager: Игра успешно загружена.")
	return json.get_data()

# TODO: Добавить проверку версии сохранения (save_schema_v1.json)
# TODO: Добавить автосохранение

