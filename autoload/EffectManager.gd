# autoload/EffectManager.gd
# Менеджер эффектов. Управляет всеми баффами и дебаффами в игре.
# Подключается как Autoload с именем "EffectManager".

extends Node
const _effects_data_ref = preload("res://data/status_effects.json")

signal effect_applied(target, effect_id)
signal effect_expired(target, effect_id)
signal effect_tick(target, effect_id)

var active_effects: Dictionary = {}   # key = target_id (int), value = Array[effect_instances]
var effects_data: Dictionary = {}     # key = effect_id, value = Dictionary
var tick_timer: Timer

func _ready() -> void:
	print("[EffectManager] Загружен.")
	_load_effects_data()
	_init_timer()


# ============================================
# === ЗАГРУЗКА ДАННЫХ ЭФФЕКТОВ ==============
# ============================================
func _load_effects_data() -> void:
	var path := "res://data/status_effects.json"
	if not FileAccess.file_exists(path):
		push_error("[EffectManager] Файл эффектов не найден: %s" % path)
		return

	var file := FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(text)
	if error != OK:
		push_error("[EffectManager] Ошибка парсинга JSON: %s (строка: %d)" % [
			json.get_error_message(),
			json.get_error_line()
		])
		return  # ← ВАЖНО: выходим, если ошибка

	# Только после проверки на ошибку — получаем данные
	var parsed = json.get_data()  # ← parsed объявлен ВНЕ if

	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[EffectManager] Корень JSON должен быть объектом (Dictionary)")
		return

	effects_data = parsed.duplicate(true)
	print("[EffectManager] Загружено эффектов: %d" % effects_data.size())
	


# ============================================
# === ТАЙМЕР И ТИК ЦИКЛ =====================
# ============================================
func _init_timer() -> void:
	if tick_timer and is_instance_valid(tick_timer):
		return
	tick_timer = Timer.new()
	tick_timer.wait_time = 1.0
	tick_timer.autostart = true
	tick_timer.one_shot = false
	tick_timer.timeout.connect(_on_tick)
	add_child(tick_timer)


# ============================================
# === ОСНОВНЫЕ ОПЕРАЦИИ =====================
# ============================================

func apply_effect(target: Node, effect_id: String) -> void:
	if not target:
		return
	if not effects_data.has(effect_id):
		push_warning("[EffectManager] Неизвестный эффект '%s'" % effect_id)
		return

	var effect_data: Dictionary = effects_data[effect_id]
	var tid := str(target.get_instance_id())
	if not active_effects.has(tid):
		active_effects[tid] = []

	# Проверяем дубликаты
	for e in active_effects[tid]:
		if e["id"] == effect_id:
			e["duration"] = effect_data.get("duration", 3)
			print("[EffectManager] Обновлён эффект:", effect_id)
			return

	var instance := {
		"id": effect_id,
		"duration": effect_data.get("duration", 3),
		"data": effect_data.duplicate(true)
	}
	active_effects[tid].append(instance)
	emit_signal("effect_applied", target, effect_id)
	print("[EffectManager] %s получает эффект %s" % [target.name, effect_id])

	_apply_stat_modifiers(target, effect_data)


func remove_effect(target: Node, effect_id: String) -> void:
	if not target:
		return
	var tid := str(target.get_instance_id())
	if not active_effects.has(tid):
		return
	active_effects[tid] = active_effects[tid].filter(func(e): return e["id"] != effect_id)
	emit_signal("effect_expired", target, effect_id)
	print("[EffectManager] Эффект снят:", effect_id)


func clear_all(target: Node) -> void:
	if not target:
		return
	var tid := str(target.get_instance_id())
	if not active_effects.has(tid):
		return
	for e in active_effects[tid]:
		emit_signal("effect_expired", target, e["id"])
	active_effects.erase(tid)


# ============================================
# === ТИК ОБНОВЛЕНИЯ ========================
# ============================================
func _on_tick() -> void:
	var to_remove: Array = []
	for tid in active_effects.keys():
		var target := _find_target_by_id(tid)
		if not is_instance_valid(target):
			to_remove.append(tid)
			continue

		var effects = active_effects[tid]
		var expired_ids: Array = []

		for e in effects:
			var id = e["id"]
			var data = e["data"]
			e["duration"] -= 1

			if data.has("tick_damage") and target.has_method("take_damage"):
				target.take_damage(data["tick_damage"])
				emit_signal("effect_tick", target, id)
				print("%s получает урон от %s: %.1f" % [target.name, id, data["tick_damage"]])

			elif data.has("heal_tick") and target.has("health") and target.has("max_health"):
				target.health = min(target.health + data["heal_tick"], target.max_health)
				emit_signal("effect_tick", target, id)
				print("%s восстанавливает здоровье от %s: +%.1f" % [target.name, id, data["heal_tick"]])

			if e["duration"] <= 0:
				expired_ids.append(id)
				emit_signal("effect_expired", target, id)
				print("[EffectManager] Эффект %s истёк у %s" % [id, target.name])

		for id in expired_ids:
			remove_effect(target, id)

	for tid in to_remove:
		active_effects.erase(tid)


# ============================================
# === УТИЛИТЫ ===============================
# ============================================

func _apply_stat_modifiers(target: Node, data: Dictionary) -> void:
	if data.has("attack_bonus") and target.has("attack"):
		target.attack += data["attack_bonus"]
	if data.has("defense_bonus") and target.has("defense"):
		target.defense += data["defense_bonus"]
	if data.has("speed_modifier") and target.has("speed"):
		target.speed += data["speed_modifier"]


func _find_target_by_id(tid: String) -> Node:
	for node in get_tree().get_nodes_in_group("entities"):
		if str(node.get_instance_id()) == tid:
			return node
	return null
