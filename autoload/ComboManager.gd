# autoload/ComboManager.gd
# Менеджер комбо-цепочек.
# Отвечает ТОЛЬКО за хранение и выдачу данных из res://data/combos/
# Подключается как Autoload с именем "ComboManager"

extends Node

@export var combos_folder: String = "res://data/combos/"

var combos: Dictionary = {}          # { "combo_id": { ...data... } }
var default_combos: Array = []       # ["basic_l", "parry_counter"]
var combos_by_weapon: Dictionary = {}  # { "weapon_type": [combo_id, ...] }

func _ready() -> void:
	load_combos()


# ==========================
# === LOAD / PARSE DATA ====
# ==========================
func load_combos() -> void:
	combos.clear()
	default_combos.clear()
	combos_by_weapon.clear()
	
	var files := _get_json_files_in_folder(combos_folder)
	for file_path in files:
		var weapon_type: String = file_path.get_file().get_basename()  # <- добавить : String
		_load_combos_from_file(file_path, weapon_type)
	
	print("[ComboManager] Загружено %d комбо из %d файлов" % [combos.size(), files.size()])

func _get_json_files_in_folder(folder_path: String) -> Array:
	var files := []
	var dir := DirAccess.open(folder_path)
	if dir == null:
		push_error("[ComboManager] Не удалось открыть папку: %s" % folder_path)
		return files
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			files.append(folder_path + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	return files

func _load_combos_from_file(file_path: String, weapon_type: String) -> void:
	if not FileAccess.file_exists(file_path):
		push_warning("[ComboManager] Файл не найден: %s" % file_path)
		return
	
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("[ComboManager] Ошибка открытия файла: %s" % file_path)
		return
	
	var json_text := file.get_as_text()
	file.close()
	
	var parsed = JSON.parse_string(json_text)
	if parsed == null:
		push_error("[ComboManager] Ошибка парсинга JSON в файле %s: неверный синтаксис" % file_path)
		return
	
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[ComboManager] Корень JSON должен быть объектом в файле %s" % file_path)
		return
	
	if not parsed.has("combos"):
		push_error("[ComboManager] В JSON отсутствует ключ 'combos' в файле %s" % file_path)
		return
	
	var data = parsed["combos"]
	if typeof(data) != TYPE_ARRAY:
		push_error("[ComboManager] Ключ 'combos' должен быть массивом в файле %s" % file_path)
		return
	
	for combo_entry in data:
		if typeof(combo_entry) != TYPE_DICTIONARY:
			continue
		
		var id := str(combo_entry.get("id", "")).strip_edges()
		if id == "":
			continue
		
		# Если weapon_type не указан в комбо, добавляем из имени файла
		if not combo_entry.has("weapon_type"):
			combo_entry["weapon_type"] = weapon_type
		
		combos[id] = combo_entry.duplicate(true)
		
		# Добавляем в индекс по типу оружия
		if not combos_by_weapon.has(weapon_type):
			combos_by_weapon[weapon_type] = []
		combos_by_weapon[weapon_type].append(id)
		
		if combo_entry.get("default", false):
			default_combos.append(id)


# ==========================
# === DATA ACCESS LAYER ====
# ==========================

## Получить данные комбо по ID (возвращает копию)
func get_combo(id: String) -> Dictionary:
	if combos.has(id):
		return combos[id].duplicate(true)
	return {}


## Проверить наличие комбо
func has_combo(id: String) -> bool:
	return combos.has(id)


## Проверить, является ли комбо дефолтным
func is_default_combo(id: String) -> bool:
	return id in default_combos


## Вернуть список всех ID комбо
func get_all_combos() -> Array:
	return combos.keys().duplicate(true)


## Поиск комбо по последовательности (["L","L","R"])
## weapon_type: фильтр по типу оружия ("unarmed", "sword", "" = все)
func find_combo_by_sequence(seq: Array, weapon_type: String = "") -> String:
	if typeof(seq) != TYPE_ARRAY:
		return ""
	
	var search_pool := combos.keys()
	if weapon_type != "" and combos_by_weapon.has(weapon_type):
		search_pool = combos_by_weapon[weapon_type]
	
	for id in search_pool:
		var combo = combos[id]
		if typeof(combo) != TYPE_DICTIONARY:
			continue
		var cseq = combo.get("sequence", [])
		if typeof(cseq) == TYPE_ARRAY and cseq == seq:
			return id
	return ""

## Получить список комбо для указанного типа оружия
func get_combos_for_weapon(weapon_type: String) -> Array:
	if combos_by_weapon.has(weapon_type):
		return combos_by_weapon[weapon_type].duplicate()
	return []


## Получить список всех эффектов, встречающихся в комбо
func get_all_effects() -> Array:
	var effs: Array = []
	for c in combos.values():
		if typeof(c) != TYPE_DICTIONARY:
			continue
		var earr = c.get("effects", [])
		if typeof(earr) != TYPE_ARRAY:
			continue
		for e in earr:
			if not e in effs:
				effs.append(e)
	return effs.duplicate(true)
