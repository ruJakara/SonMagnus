# autoload/ComboManager.gd
# Менеджер комбо-цепочек.
# Отвечает ТОЛЬКО за хранение и выдачу данных из res://data/combos.json
# Подключается как Autoload с именем "ComboManager"

extends Node

@export var combos_path: String = "res://data/combos.json"

var combos: Dictionary = {}          # { "combo_id": { ...data... } }
var default_combos: Array = []       # ["basic_l", "parry_counter"]

func _ready() -> void:
	load_combos()


# ==========================
# === LOAD / PARSE DATA ====
# ==========================
func load_combos() -> void:
	combos.clear()
	default_combos.clear()

	if not FileAccess.file_exists(combos_path):
		push_error("[ComboManager] Не найден файл: %s" % combos_path)
		return

	var file := FileAccess.open(combos_path, FileAccess.READ)
	if file == null:
		push_error("[ComboManager] Ошибка открытия файла: %s" % combos_path)
		return

	var json_text := file.get_as_text()
	file.close()

	# === ПРАВИЛЬНЫЙ ПАРСИНГ В GODOT 4 ===
	var parsed = JSON.parse_string(json_text)
	if parsed == null:
		push_error("[ComboManager] Ошибка парсинга JSON: неверный синтаксис")
		return

	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[ComboManager] Корень JSON должен быть объектом")
		return

	if not parsed.has("combos"):
		push_error("[ComboManager] В JSON отсутствует ключ 'combos'")
		return

	var data = parsed["combos"]
	if typeof(data) != TYPE_ARRAY:
		push_error("[ComboManager] Ключ 'combos' должен быть массивом")
		return

	for combo_entry in data:
		if typeof(combo_entry) != TYPE_DICTIONARY:
			continue
		var id := str(combo_entry.get("id", "")).strip_edges()
		if id == "":
			continue
		combos[id] = combo_entry.duplicate(true)
		if combo_entry.get("default", false):
			default_combos.append(id)

	print("[ComboManager] Загружено %d комбо. Дефолтных: %d" % [combos.size(), default_combos.size()])


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
func find_combo_by_sequence(seq: Array) -> String:
	if typeof(seq) != TYPE_ARRAY:
		return ""
	for id in combos.keys():
		var combo = combos[id]
		if typeof(combo) != TYPE_DICTIONARY:
			continue
		var cseq = combo.get("sequence", [])
		if typeof(cseq) == TYPE_ARRAY and cseq == seq:
			return id
	return ""


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
