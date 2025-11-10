extends Node
class_name ClassManagerSingleton

signal class_offered(player_node: Node, choices: Array)
signal class_assigned(player_node: Node, class_id: String)
signal class_unlocked(player_node: Node, class_id: String)

const VERSION: int = 1

var _classes_by_id: Dictionary = {}
var _classes_by_rank: Dictionary = {
	"common": {},
	"rare": {},
	"legendary": {},
	"mythic": {}
}

func _ready() -> void:
	if not _is_enabled():
		return
	_load_all_class_data()
	_connect_dynamic_triggers_if_available()

func _is_enabled() -> bool:
	if not has_node("/root/Config"):
		return false
	# Прямое обращение к свойству Config
	return Config.CLASS_SYSTEM_ENABLED

func _load_all_class_data() -> void:
	_classes_by_id.clear()
	for path in [
		"res://data/classes/common_classes.json",
		"res://data/classes/rare_classes.json",
		"res://data/classes/legendary_classes.json",
		"res://data/classes/mythic_classes.json"
	]:
		var dict := _load_json(path)
		for id in dict.keys():
			var entry: Dictionary = dict[id]
			_classes_by_id[id] = entry
			var rank := String(entry.get("rank", "common"))
			if not _classes_by_rank.has(rank):
				_classes_by_rank[rank] = {}
			_classes_by_rank[rank][id] = entry
	if Config.DEBUG_LOGS:
		print_debug("[ClassManager] Загружено классов: %d" % _classes_by_id.size())

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("[ClassManager] Не найден файл: %s" % path)
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("[ClassManager] Ошибка парсинга JSON %s: %s" % [path, json.get_error_message()])
		return {}
	var data: Variant = json.get_data()
	if typeof(data) == TYPE_DICTIONARY:
		return data
	return {}

func check_level_for_class(player_node: Node) -> void:
	if not _is_enabled():
		return
	if player_node == null:
		return
	var lvl: int = 0
	if player_node.has("global_level"):
		lvl = int(player_node.get("global_level"))
	if lvl == 0 or lvl % 10 != 0:
		return
	var choices := offer_classes(player_node, lvl)
	if choices.size() > 0:
		class_offered.emit(player_node, choices)
	# проверить скрытые триггеры тоже
	var mythics := evaluate_hidden_triggers(player_node)
	for m_id in mythics:
		class_unlocked.emit(player_node, m_id)

func offer_classes(player_node: Node, level: int) -> Array:
	if not _is_enabled():
		return []
	if player_node == null:
		return []
	var owned_val = player_node.get("owned_classes") if player_node.has("owned_classes") else []
	var owned: Array = owned_val if owned_val is Array else []
	var pool: Array[String] = []
	# базовый пул по рангам: на каждом десятке предлагать более высокий/соответствующий
	var ranks_cycle: Array[String] = ["common", "rare", "legendary"]
	var rank_idx: int = min(ranks_cycle.size() - 1, int(floor(level / 10.0)))
	var target_rank: String = ranks_cycle[rank_idx]
	for id in _classes_by_rank.get(target_rank, {}).keys():
		if id in owned:
			continue
		var entry: Dictionary = _classes_by_id[id]
		var unlock_level: int = int(entry.get("unlock_level", 1))
		if level >= unlock_level:
			pool.append(id)
	# добавить подходящие next_choices из уже имеющихся
	for owned_id in owned:
		var e: Dictionary = _classes_by_id.get(owned_id, {})
		if e.has("next_choices") and typeof(e["next_choices"]) == TYPE_ARRAY:
			for nxt in e.get("next_choices", []):
				if nxt in owned:
					continue
				if _classes_by_id.has(nxt):
					var en: Dictionary = _classes_by_id[nxt]
					if int(en.get("unlock_level", 1)) <= level:
						pool.append(nxt)
	# уникализировать
	var unique_pool: Array[String] = []
	var seen: Dictionary = {}
	for cid in pool:
		if not seen.has(cid):
			seen[cid] = true
			unique_pool.append(cid)
	# подобрать 3-4 варианта (с учётом мификов, если уже разблокированы)
	unique_pool.shuffle()
	return unique_pool.slice(0, min(4, unique_pool.size()))

func assign_class(player_node: Node, class_id: String) -> bool:
	if not _is_enabled():
		return false
	if player_node == null:
		return false
	if not _classes_by_id.has(class_id):
		push_warning("[ClassManager] Неизвестный class_id: %s" % class_id)
		return false
	# добавить в сущность
	var already := false
	if player_node.has_method("has_class"):
		already = player_node.call("has_class", class_id)
	else:
		var arr_val = player_node.get("owned_classes") if player_node.has("owned_classes") else []
		var arr: Array = arr_val if arr_val is Array else []
		already = class_id in arr
	if already:
		return false
	if player_node.has_method("add_class"):
		player_node.call("add_class", class_id)
	else:
		if not player_node.has("owned_classes"):
			player_node.set("owned_classes", [])
		var arr2: Array = player_node.get("owned_classes")
		arr2.append(class_id)
		player_node.set("owned_classes", arr2)
	# выдать стартовые навыки
	var sm := get_node_or_null("/root/SkillManager")
	if sm and sm.has_method("unlock_skills_for_class"):
		sm.call("unlock_skills_for_class", player_node, class_id)
	# побочные эффекты можно навесить через EffectManager при наличии
	# сохранение
	var save_ok := true
	var saver := get_node_or_null("/root/SaveManager")
	if saver and saver.has_method("save_game"):
		var data: Dictionary = {}
		if has_node("/root/GameManager") and GameManager.has_method("get_autosave_data"):
			var gm_data = GameManager.get_autosave_data()
			if gm_data is Dictionary:
				data = gm_data
		var res_val = saver.call("save_game", data)
		var res: int = int(res_val) if res_val != null else ERR_INVALID_DATA
		save_ok = res == OK
	else:
		save_ok = false
		push_warning("[ClassManager] SaveManager недоступен — класс присвоен без сохранения.")
	class_assigned.emit(player_node, class_id)
	return save_ok

func evaluate_hidden_triggers(player_node: Node) -> Array:
	if not _is_enabled():
		return []
	if player_node == null:
		return []
	var candidates: Array = []
	for id in _classes_by_rank.get("mythic", {}).keys():
		var entry: Dictionary = _classes_by_id[id]
		var hidden := bool(entry.get("hidden", false))
		if not hidden:
			continue
		var cond: Dictionary = entry.get("trigger_condition", {})
		if _evaluate_condition_dict(player_node, cond):
			candidates.append(id)
	return candidates

func get_available_classes_for_player(player_node: Node) -> Array:
	if not _is_enabled():
		return []
	if player_node == null:
		return []
	var lvl := int(player_node.get("global_level") if player_node.has("global_level") else 1)
	return offer_classes(player_node, lvl)

func _evaluate_condition_dict(player_node: Node, cond: Dictionary) -> bool:
	# Поддержка простых выражений вида ">=N", "<N", "==true/false", или конкретных значений
	for key in cond.keys():
		var expr: String = String(cond[key])
		var value_on_player: Variant = _get_player_stat_like(player_node, key)
		if expr.begins_with(">="):
			var thr = int(expr.substr(2, expr.length()))
			if int(value_on_player) < thr:
				return false
		elif expr.begins_with("<="):
			var thr2 = int(expr.substr(2, expr.length()))
			if int(value_on_player) > thr2:
				return false
		elif expr.begins_with(">"):
			var t = int(expr.substr(1, expr.length()))
			if int(value_on_player) <= t:
				return false
		elif expr.begins_with("<"):
			var t2 = int(expr.substr(1, expr.length()))
			if int(value_on_player) >= t2:
				return false
		elif expr.begins_with("=="):
			var rhs = expr.substr(2, expr.length()).strip_edges()
			var bool_map = {"true": true, "false": false}
			var cmp_val: Variant = rhs
			if bool_map.has(rhs):
				cmp_val = bool_map[rhs]
			if str(value_on_player) != str(cmp_val):
				return false
		else:
			if str(value_on_player) != str(expr):
				return false
	return true

func _get_player_stat_like(player_node: Node, key: String) -> Variant:
	# ищем простые счетчики/флаги на игроке, затем в словаре stats, затем в метаданных
	if player_node.has(key):
		return player_node.get(key)
	if player_node.has("stats"):
		var stats_val = player_node.get("stats")
		if stats_val is Dictionary:
			var stats: Dictionary = stats_val
			if stats.has(key):
				return stats[key]
	# попробуем Metadata
	if player_node.has_method("has_meta") and player_node.call("has_meta", key):
		return player_node.call("get_meta", key)
	return 0

func _connect_dynamic_triggers_if_available() -> void:
	# Опциональные подключения к сигналам событий (если существуют глобальные узлы/сигналы)
	var combat := get_node_or_null("/root/CombatManager")
	if combat:
		if combat.has_signal("skill_used"):
			combat.connect("skill_used", Callable(self, "_on_skill_used"))
		if combat.has_signal("entity_killed"):
			combat.connect("entity_killed", Callable(self, "_on_entity_killed"))
		if combat.has_signal("damage_dealt"):
			combat.connect("damage_dealt", Callable(self, "_on_damage_dealt"))

func _on_skill_used(player_node: Node, _skill_id: String) -> void:
	if not _is_enabled():
		return
	if player_node and player_node.has("stats"):
		var stats: Dictionary = player_node.get("stats")
		stats["skills_used"] = int(stats.get("skills_used", 0)) + 1
		player_node.set("stats", stats)
	evaluate_hidden_triggers(player_node)

func _on_entity_killed(killer: Node, _victim: Node) -> void:
	if not _is_enabled():
		return
	if killer and killer.has("stats"):
		var stats: Dictionary = killer.get("stats")
		stats["kills"] = int(stats.get("kills", 0)) + 1
		killer.set("stats", stats)
	evaluate_hidden_triggers(killer)

func _on_damage_dealt(source: Node, amount: int) -> void:
	if not _is_enabled():
		return
	if source and source.has("stats"):
		var stats: Dictionary = source.get("stats")
		stats["damage_dealt"] = int(stats.get("damage_dealt", 0)) + int(amount)
		source.set("stats", stats)
	evaluate_hidden_triggers(source)
