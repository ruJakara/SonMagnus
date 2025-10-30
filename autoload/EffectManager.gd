# autoload/EffectManager.gd
# Менеджер эффектов. Управляет всеми баффами и дебаффами в игре.
# Подключается как Autoload с именем "EffectManager".

extends Node

## Сигналы
signal effect_applied(target, effect_id)
signal effect_expired(target, effect_id)
signal effect_tick(target, effect_id)

## Все активные эффекты
var active_effects: Dictionary = {}
## Словарь со всеми доступными эффектами (загружается из JSON)
var effects_data: Dictionary = {}

## Таймер обновления
var tick_timer: Timer

func _ready() -> void:
	print("EffectManager загружен.")
	_load_effects_data()
	_init_timer()

func _load_effects_data() -> void:
	var path = "res://data/status_effects.json"
	if not FileAccess.file_exists(path):
		push_error("EffectManager: Файл эффектов не найден: %s" % path)
		return
	var text = FileAccess.open(path, FileAccess.READ).get_as_text()
	effects_data = JSON.parse_string(text)
	if typeof(effects_data) != TYPE_DICTIONARY:
		push_error("EffectManager: Ошибка загрузки JSON эффектов.")
		effects_data = {}
	else:
		print("EffectManager: эффекты успешно загружены →", effects_data.keys())

func _init_timer() -> void:
	tick_timer = Timer.new()
	tick_timer.wait_time = 1.0
	tick_timer.autostart = true
	tick_timer.timeout.connect(_on_tick)
	add_child(tick_timer)

## Добавить эффект цели
func apply_effect(target: Node, effect_id: String) -> void:
	if not target or not effects_data.has(effect_id):
		push_warning("EffectManager: Неизвестный эффект '%s'" % effect_id)
		return

	var effect_data = effects_data[effect_id]
	if not active_effects.has(target):
		active_effects[target] = []

	# Проверка — не дублируется ли эффект
	for e in active_effects[target]:
		if e["id"] == effect_id:
			e["duration"] = effect_data.get("duration", 3)
			print("EffectManager: Эффект обновлён:", effect_id)
			return

	var instance = {
		"id": effect_id,
		"duration": effect_data.get("duration", 3),
		"data": effect_data.duplicate(true)
	}
	active_effects[target].append(instance)

	emit_signal("effect_applied", target, effect_id)
	print("%s получает эффект: %s" % [target.name, effect_data.get("name", effect_id)])

	_apply_stat_modifiers(target, effect_data)

## Снять эффект вручную
func remove_effect(target: Node, effect_id: String) -> void:
	if not active_effects.has(target):
		return

	active_effects[target] = active_effects[target].filter(func(e): return e["id"] != effect_id)
	emit_signal("effect_expired", target, effect_id)
	print("EffectManager: Эффект снят:", effect_id)

## Очистить все эффекты с цели
func clear_all(target: Node) -> void:
	if not active_effects.has(target):
		return
	for e in active_effects[target]:
		emit_signal("effect_expired", target, e["id"])
	active_effects.erase(target)

## Обработка эффектов каждый тик
func _on_tick() -> void:
	for target in active_effects.keys():
		var to_remove: Array = []
		for e in active_effects[target]:
			var id = e["id"]
			var data = e["data"]
			e["duration"] -= 1

			if data.has("tick_damage") and target.has_method("take_damage"):
				target.take_damage(data["tick_damage"])
				emit_signal("effect_tick", target, id)
				print("%s получает урон от %s: %d" % [target.name, id, data["tick_damage"]])

			elif data.has("heal_tick") and "health" in target:
				target.health = min(target.health + data["heal_tick"], target.max_health)
				emit_signal("effect_tick", target, id)
				print("%s восстанавливает здоровье от %s: +%d" % [target.name, id, data["heal_tick"]])

			if e["duration"] <= 0:
				to_remove.append(id)
				emit_signal("effect_expired", target, id)
				print("EffectManager: эффект %s истёк у %s" % [id, target.name])

		for id in to_remove:
			remove_effect(target, id)

## Временные модификаторы характеристик
func _apply_stat_modifiers(target: Node, data: Dictionary) -> void:
	if data.has("attack_bonus") and "attack" in target:
		target.attack += data["attack_bonus"]
	if data.has("defense_bonus") and "defense" in target:
		target.defense += data["defense_bonus"]
	if data.has("speed_modifier") and "speed" in target:
		target.speed += data["speed_modifier"]
