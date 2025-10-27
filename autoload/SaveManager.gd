# autoload/SaveManager.gd
# Менеджер сохранения и загрузки игры. Использует JSON и шифрование AES256.
# Подключается как Autoload с именем "SaveManager".

extends Node

## Сигнал, который испускается после успешного сохранения.
signal game_saved
## Сигнал, который испускается после успешной загрузки.
signal game_loaded

## @brief Инициализация класса SaveManager.
func _ready():
	if Config.DEBUG_LOGS:
		print_debug("[SaveManager] Загружен.")

# --- [ Константы ] ---

## Путь к файлу сохранения.
const SAVE_PATH: String = "user://savegame.dat"
## Ключ шифрования (должен быть 32 байта для AES-256).
const ENCRYPTION_KEY: PackedByteArray = "Это_очень_секретный_ключ_на_32_байта".to_utf8_buffer().sha256_buffer()
## Текущая версия схемы сохранения.
const CURRENT_SAVE_VERSION: int = 1

# --- [ Методы сохранения/загрузки ] ---

## @brief Сохраняет данные игры с шифрованием.
## @param data: Словарь с данными для сохранения.
## @param save_version: Версия схемы сохранения.
## @return: OK в случае успеха.
func save_game(data: Dictionary, save_version: int = CURRENT_SAVE_VERSION) -> int:
	var save_data = {
		"version": save_version,
		"data": data
	}
	
	# 1. Сериализация данных в строку JSON
	var json_string = JSON.stringify(save_data)
	var json_bytes = json_string.to_utf8_buffer()
	
	# 2. Шифрование
	var encrypted_bytes: PackedByteArray
	if Config.SAVE_TEST_MODE:
		encrypted_bytes = json_bytes
		if Config.DEBUG_LOGS: print_debug("[SaveManager] Сохранение в тестовом режиме (без шифрования).")
	else:
		var crypto = Crypto.new()
		# В реальном проекте используйте более безопасный режим (например, CBC или GCM)
		encrypted_bytes = crypto.encrypt(ENCRYPTION_KEY, json_bytes)
		if Config.DEBUG_LOGS: print_debug("[SaveManager] Сохранение с шифрованием.")

	# 3. Запись в файл
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if FileAccess.get_open_error() != OK:
		push_error("[SaveManager] Ошибка открытия файла для записи: %s" % FileAccess.get_open_error())
		return FileAccess.get_open_error()
		
	file.store_buffer(encrypted_bytes)
	file.close()
	
	if Config.DEBUG_LOGS: print_debug("[SaveManager] Игра успешно сохранена в %s (Версия: %d)" % [SAVE_PATH, save_version])
	game_saved.emit()
	return OK

## @brief Загружает данные игры с дешифрованием.
## @return: Словарь с данными или null в случае ошибки.
func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		push_error("[SaveManager] Файл сохранения не найден: %s" % SAVE_PATH)
		return null
		
	# 1. Чтение из файла
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var encrypted_bytes = file.get_buffer(file.get_length())
	file.close()

	# 2. Дешифрование
	var json_bytes: PackedByteArray
	if Config.SAVE_TEST_MODE: 
		json_bytes = encrypted_bytes
		if Config.DEBUG_LOGS: print_debug("[SaveManager] Загрузка в тестовом режиме (без дешифрования).")
	else:
		var crypto = Crypto.new()
		json_bytes = crypto.decrypt(ENCRYPTION_KEY, encrypted_bytes)
		if Config.DEBUG_LOGS: print_debug("[SaveManager] Загрузка с дешифрованием.")

	# 3. Десериализация JSON
	var json_string = json_bytes.get_string_from_utf8()
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error != OK:
		push_error("[SaveManager] Ошибка парсинга JSON после дешифрования. Ошибка: %s" % json.get_error_message())
		return null
		
	var loaded_data = json.get_data()
	
	# 4. Проверка версии и миграция
	var save_version = loaded_data.get("version", 0)
	var data = loaded_data.get("data", {})
	
	if save_version < CURRENT_SAVE_VERSION:
		# TODO: Реализовать миграцию данных (например, _migrate_to_v1(data))
		if Config.DEBUG_LOGS: print_debug("[SaveManager] Требуется миграция данных: V%d -> V%d" % [save_version, CURRENT_SAVE_VERSION])
	
	if Config.DEBUG_LOGS: print_debug("[SaveManager] Игра успешно загружена (Версия: %d)." % save_version)
	game_loaded.emit()
	return data

# --- [ Автосохранение ] ---

## @brief Выполняет автосохранение, если оно включено в Config.
func autosave():
	if not Config.AUTOSAVE_ENABLED:
		if Config.DEBUG_LOGS: print_debug("[SaveManager] Автосохранение отключено в Config.")
		return
		
	# Собираем данные для сохранения через GameManager
	var data_to_save = GameManager.get_autosave_data()
	
	if data_to_save.is_empty():
		push_error("[SaveManager] Невозможно выполнить автосохранение: GameManager.get_autosave_data() вернул пустой словарь.")
		return
		
	var result = save_game(data_to_save)
	
	if result == OK and Config.DEBUG_LOGS:
		print_debug("[SaveManager] Автосохранение успешно выполнено.")

# TODO: Добавить таймер для периодического автосохранения
# TODO: Добавить миграционные функции (например, _migrate_to_v2)
