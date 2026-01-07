# scripts/entities/enemies/enemy_brain.gd
# AI и State Machine для врагов
# Управляет поведением, обнаружением целей, переключением состояний

class_name EnemyBrain
extends Node

signal help_called(position: Vector2)
signal target_detected(target: Node)
signal state_changed(old_state: String, new_state: String)

## Ссылка на владельца (EnemyBase)
var enemy: EnemyBase = null

## Словарь состояний {имя: EnemyState}
var states: Dictionary = {}

## Текущее состояние
var current_state: EnemyState = null
var current_state_name: String = ""

## Текущая цель
var current_target: Node = null

## Ссылки на данные врага (для удобства)
var behavior_data: Dictionary = {}
var combat_data: Dictionary = {}
var hostility_data: Dictionary = {}

## Ссылки на зоны
var attack_area: Area2D = null
var hurtbox: Area2D = null
var back_area: Area2D = null

## Флаги и таймеры
var stun_timer: float = 0.0
var has_called_help: bool = false
var _attack_cooldown_timer: float = 0.0

func _ready() -> void:
	# Получаем ссылку на EnemyBase
	enemy = get_parent() as EnemyBase
	if not enemy:
		push_error("[EnemyBrain] Родитель не является EnemyBase!")
		return
	
		# ===== ДОБАВЬ ЭТУ СТРОКУ =====
	# Ждём 1 кадр, чтобы goblin_scout.gd успел загрузить JSON
	await get_tree().process_frame
	# =============================
	# Копируем ссылки на данные
	behavior_data = enemy.behavior_data
	combat_data = enemy.combat_data
	hostility_data = enemy.hostility_data
	
	# Копируем ссылки на зоны
	attack_area = enemy.attack_area
	hurtbox = enemy.hurtbox
	back_area = enemy.back_area
	
	# Регистрируем состояния (будут созданы в _register_states)
	_register_states()
	
	# Стартуем с начального состояния
	var initial_state = "idle"
	if behavior_data.get("ai_type", "") == "patrol":
		initial_state = "patrol"
	elif behavior_data.get("ai_type", "") == "sleep":
		initial_state = "sleep"
	
	change_state(initial_state)
	
	if Config.DEBUG_LOGS:
		print_debug("[EnemyBrain] Инициализирован для %s, состояние: %s" % [enemy.entity_name, initial_state])

## Регистрация всех состояний
func _register_states() -> void:
	# Базовые состояния
	_add_state("idle", preload("res://scripts/entities/enemies/states/idle_state.gd").new())
	_add_state("patrol", preload("res://scripts/entities/enemies/states/patrol_state.gd").new())
	_add_state("chase", preload("res://scripts/entities/enemies/states/chase_state.gd").new())
	_add_state("attack", preload("res://scripts/entities/enemies/states/attack_state.gd").new())
	_add_state("dead", preload("res://scripts/entities/enemies/states/dead_state.gd").new())
	
	# Дополнительные состояния
	_add_state("sleep", preload("res://scripts/entities/enemies/states/sleep_state.gd").new())
	_add_state("stunned", preload("res://scripts/entities/enemies/states/stunned_state.gd").new())
	_add_state("call_help", preload("res://scripts/entities/enemies/states/call_help_state.gd").new())

## Добавляет состояние в словарь
func _add_state(state_name: String, state: EnemyState) -> void:
	state.brain = self
	states[state_name] = state

## Переключение состояния
func change_state(new_state_name: String, _context: Dictionary = {}) -> void:
	if not states.has(new_state_name):
		push_warning("[EnemyBrain] Состояние не найдено: %s" % new_state_name)
		return
	
	# Выход из текущего состояния
	if current_state:
		current_state.exit()
	
	# Сохраняем старое имя для сигнала
	var old_state_name = current_state_name
	
	# Переключаем
	current_state_name = new_state_name
	current_state = states[new_state_name]
	
	# Вход в новое состояние
	current_state.enter()
	
	emit_signal("state_changed", old_state_name, new_state_name)
	
	if Config.DEBUG_LOGS:
		print_debug("[EnemyBrain] %s: %s → %s" % [enemy.entity_name, old_state_name, new_state_name])

func _process(delta: float) -> void:
	if not enemy or not enemy.is_alive:
		return
	
	# Обновляем таймеры
	if stun_timer > 0.0:
		stun_timer -= delta
	
	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer -= delta
	
	# Обновляем текущее состояние
	if current_state:
		current_state.update(delta)

func _physics_process(delta: float) -> void:
	if not enemy or not enemy.is_alive:
		return
	
	if current_state:
		current_state.physics_update(delta)

## Обнаружение цели в конусе обзора
func detect_target_in_cone() -> Node:
	if not enemy:
		return null
	
	var facing_dir = Vector2.RIGHT if enemy._sprite.flip_h == false else Vector2.LEFT
	var cone_angle = behavior_data.get("vision_cone_angle", 120.0)
	var vision_range = behavior_data.get("vision_range", 180.0)
	
	# Собираем кандидатов (УБРАНО + "s")
	var candidates: Array = []
	for group in hostility_data.get("hostile_groups", []):
		candidates.append_array(get_tree().get_nodes_in_group(group))
	
	# Проверяем каждого кандидата
	for target in candidates:
		if not is_instance_valid(target):
			continue
		
		# Проверяем жив ли
		if target.get("is_alive") and not target.is_alive:
			continue
		
		var to_target = target.global_position - enemy.global_position
		var distance = to_target.length()
		
		# Проверяем дистанцию
		if distance > vision_range:
			continue
		
		# Проверяем угол
		var angle = facing_dir.angle_to(to_target.normalized())
		if abs(rad_to_deg(angle)) <= cone_angle / 2.0:
			return target
	
	return null

## Проверка, является ли цель враждебной
func is_hostile_target(target: Node) -> bool:
	if not target:
		return false
	
	# Проверяем по тегам
	if target.has("tags"):
		for tag in target.tags:
			if tag in hostility_data.get("hostile_tags", []):
				return true
	
	# Проверяем по группам
	for group in hostility_data.get("hostile_groups", []):
		if target.is_in_group(group):
			return true
	
	return false

## Вызывается когда враг получает урон
func on_damage_taken(amount: int, attacker: Node = null) -> void:
	# Передаём в текущее состояние
	if current_state:
		current_state.on_damage_taken(amount, attacker)
	
	# Устанавливаем цель
	if attacker and is_hostile_target(attacker):
		current_target = attacker
		emit_signal("target_detected", attacker)
	
	# Зов помощи при низком HP
	if not has_called_help:
		var hp_ratio = float(enemy.health) / float(enemy.max_health)
		var call_threshold = behavior_data.get("call_help_threshold", 0.3)
		if hp_ratio <= call_threshold:
			call_for_help()

## Зов на помощь
func call_for_help() -> void:
	if has_called_help:
		return
	
	has_called_help = true
	emit_signal("help_called", enemy.global_position)
	
	# Проигрываем звук
	var sound_path = enemy.sounds.get("call_help", "")
	if not sound_path.is_empty():
		# TODO: Воспроизвести звук через AudioManager
		pass
	
	if Config.DEBUG_LOGS:
		print_debug("[EnemyBrain] %s зовёт на помощь!" % enemy.entity_name)

## Проверка может ли атаковать
func can_attack() -> bool:
	return _attack_cooldown_timer <= 0.0

## Начать атаку (запускает кулдаун)
func start_attack() -> void:
	
	_attack_cooldown_timer = combat_data.get("attack_cooldown", 1.5)

## Вызывается из EnemyBase._on_attack_frame() (который вызывается из AnimationPlayer)
func _on_attack_frame() -> void:
	if current_state and current_state.has_method("_on_attack_frame"):
		current_state._on_attack_frame()

## Вызывается из EnemyBase._on_attack_end() (который вызывается из AnimationPlayer)
func _on_attack_end() -> void:
	if current_state and current_state.has_method("_on_attack_end"):
		current_state._on_attack_end()
