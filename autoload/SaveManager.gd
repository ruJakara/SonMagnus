extends Node

signal game_saved(path)
signal game_loaded(data)
signal save_failed(error_message)
signal load_failed(error_message)
signal autosave_triggered(data)

const SAVE_PATH := "user://savegame.dat"
const BACKUP_PATH := "user://savegame.bak"
const TEMP_PATH := "user://savegame.tmp"
const AUTOSAVE_INTERVAL := 60.0

var _autosave_timer: Timer
var ENCRYPTION_KEY: PackedByteArray

func _ready():
	var crypto := Crypto.new()
	ENCRYPTION_KEY = crypto.generate_random_bytes(32)  # 256 бит случайный ключ
	if Config.DEBUG_LOGS:
		print_debug("[SaveManager] Загружен")

	_autosave_timer = Timer.new()
	_autosave_timer.wait_time = AUTOSAVE_INTERVAL
	_autosave_timer.autostart = true
	_autosave_timer.timeout.connect(_on_autosave_timeout)
	add_child(_autosave_timer)

# ------------------------------------
# СОХРАНЕНИЕ
# ------------------------------------
func save_game(data: Dictionary) -> int:
	data["version"] = "1.0"
	var json_bytes := JSON.stringify(data).to_utf8_buffer()

	var encrypted := json_bytes if Config.SAVE_TEST_MODE else _encrypt(json_bytes)

	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if FileAccess.get_open_error() != OK:
		var err := FileAccess.get_open_error()
		push_error("SaveManager: ошибка записи файла %s" % err)
		emit_signal("save_failed", str(err))
		return err

	file.store_buffer(encrypted)
	file.close()

	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.rename_absolute(SAVE_PATH, BACKUP_PATH)
	DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH)

	emit_signal("game_saved", SAVE_PATH)
	if Config.DEBUG_LOGS:
		print_debug("[SaveManager] Сохранено → %s" % SAVE_PATH)
	return OK

# ------------------------------------
# ЗАГРУЗКА
# ------------------------------------
func load_game() -> Variant:
	if not FileAccess.file_exists(SAVE_PATH):
		emit_signal("load_failed", "Файл не найден")
		return null

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var encrypted := file.get_buffer(file.get_length())
	file.close()

	if encrypted.is_empty():
		emit_signal("load_failed", "Файл пуст")
		_try_restore_backup()
		return null

	var json_bytes := encrypted if Config.SAVE_TEST_MODE else _decrypt(encrypted)
	var json_string := json_bytes.get_string_from_utf8()

	var json := JSON.new()
	if json.parse(json_string) != OK:
		emit_signal("load_failed", json.get_error_message())
		_try_restore_backup()
		return null

	var data: Dictionary = json.get_data()

	emit_signal("game_loaded", data)
	if Config.DEBUG_LOGS:
		print_debug("[SaveManager] Загрузка успешна")
	return data

# ------------------------------------
# АВТОСОХРАНЕНИЕ
# ------------------------------------
func _on_autosave_timeout():
	if not Config.AUTOSAVE_ENABLED:
		return
	if not ("get_autosave_data" in GameManager):
		return
	var data := GameManager.get_autosave_data()
	if data.is_empty():
		return
	save_game(data)
	emit_signal("autosave_triggered", data)
	if Config.DEBUG_LOGS:
		print_debug("[SaveManager] Автосейв выполнен")

# ------------------------------------
# ВСПОМОГАТЕЛЬНЫЕ
# ------------------------------------
func _encrypt(data: PackedByteArray) -> PackedByteArray:
	var crypto := Crypto.new()
	var key := CryptoKey.new()
	key.load_from_buffer(ENCRYPTION_KEY)
	return crypto.encrypt(key, data)

func _decrypt(data: PackedByteArray) -> PackedByteArray:
	var crypto := Crypto.new()
	var key := CryptoKey.new()
	key.load_from_buffer(ENCRYPTION_KEY)
	return crypto.decrypt(key, data)

func _try_restore_backup():
	if FileAccess.file_exists(BACKUP_PATH):
		print_debug("[SaveManager] Восстанавливаю из резервной копии…")
		DirAccess.rename_absolute(BACKUP_PATH, SAVE_PATH)
	else:
		push_error("SaveManager: резервная копия не найдена")
