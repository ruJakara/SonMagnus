# scripts/entities/enemies/enemy_brain.gd
# Enemy State Machine (renamed from EnemyBrain for consistency)
# Manages enemy AI behavior, target detection, and state transitions

class_name EnemyBrain
extends StateMachine

signal help_called(position: Vector2)
signal target_detected(target: Node)

## Ссылка на владельца (EnemyBase)
var enemy: EnemyBase = null


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
	if enemy.has_signal("damage_taken"):
		enemy.damage_taken.connect(_on_enemy_damage_taken)
	
	# Ждём 1 кадр, чтобы goblin_scout.gd успел загрузить JSON
	await get_tree().process_frame
	
	# Копируем ссылки на данные
	behavior_data = enemy.behavior_data
	combat_data = enemy.combat_data
	hostility_data = enemy.hostility_data
	
	# Копируем ссылки на зоны
	attack_area = enemy.attack_area
	hurtbox = enemy.hurtbox
	back_area = enemy.back_area
	
	# Call parent to initialize state machine
	super._ready()

## Override from StateMachine
func _register_states() -> void:
	# Базовые состояния
	add_state("idle", preload("res://scripts/entities/enemies/states/idle_state.gd").new())
	add_state("patrol", preload("res://scripts/entities/enemies/states/patrol_state.gd").new())
	add_state("chase", preload("res://scripts/entities/enemies/states/chase_state.gd").new())
	add_state("attack", preload("res://scripts/entities/enemies/states/attack_state.gd").new())
	add_state("dead", preload("res://scripts/entities/enemies/states/dead_state.gd").new())
	
	# Дополнительные состояния
	add_state("sleep", preload("res://scripts/entities/enemies/states/sleep_state.gd").new())
	#add_state("stunned", preload("res://scripts/entities/enemies/states/stunned_state.gd").new())
	add_state("call_help", preload("res://scripts/entities/enemies/states/call_help_state.gd").new())

func _get_initial_state() -> String:
	# Стартуем с начального состояния
	var initial_state = "idle"
	if behavior_data.get("ai_type", "") == "patrol":
		initial_state = "patrol"
	elif behavior_data.get("ai_type", "") == "sleep":
		initial_state = "sleep"
	
	if Config.DEBUG_LOGS:
		print_debug("[EnemyBrain] Инициализирован для %s, состояние: %s" % [enemy.entity_name, initial_state])
	
	return initial_state

## Override parent's _process to add enemy-specific timer updates
func _process(delta: float) -> void:
	if not enemy or not enemy.is_alive:
		return
	
	# Обновляем таймеры
	if stun_timer > 0.0:
		stun_timer -= delta
	
	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer -= delta
	
	# Call parent to update current state
	super._process(delta)

func _physics_process(delta: float) -> void:
	# Call parent to update current state physics
	super._physics_process(delta)

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
	if target.get("tags"):
		for tag in target.tags:
			if tag in hostility_data.get("hostile_tags", []):
				return true
	
	# Проверяем по группам
	for group in hostility_data.get("hostile_groups", []):
		if target.is_in_group(group):
			return true
	
	return false

## Вызывается когда враг получает урон (override from StateMachine)
func on_damage_taken(amount: int, attacker: Node = null, from_back: bool = false) -> void:
	# Передаём в текущее состояние
	if current_state:
		current_state.on_damage_taken(amount, attacker, from_back)
	
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
	var sound_path: String = enemy.sounds.get("call_help", "")
	if not sound_path.is_empty():
		_play_sound(sound_path)
	
	# Привлекаем союзников в радиусе
	var call_radius: float = behavior_data.get("call_help_radius", 350.0)
	var faction: String = hostility_data.get("faction", "")
	
	_alert_nearby_allies(call_radius, faction)
	
	if Config.DEBUG_LOGS:
		print_debug("[EnemyBrain] %s зовёт на помощь! (радиус: %.0f)" % [enemy.entity_name, call_radius])


func _alert_nearby_allies(radius: float, faction: String) -> void:
	if not current_target:
		return
	
	var allies := get_tree().get_nodes_in_group("enemies")
	for ally in allies:
		if ally == enemy:
			continue
		if not is_instance_valid(ally):
			continue
		
		# Проверяем фракцию
		var ally_brain: EnemyBrain = ally.get_node_or_null("EnemyBrain") as EnemyBrain
		if not ally_brain:
			continue
		
		var ally_faction: String = ally_brain.hostility_data.get("faction", "")
		if not faction.is_empty() and ally_faction != faction:
			continue
		
		# Проверяем расстояние
		var distance := enemy.global_position.distance_to(ally.global_position)
		if distance > radius:
			continue
		
		# Устанавливаем цель союзнику
		if ally_brain.current_target == null:
			ally_brain.current_target = current_target
			ally_brain.emit_signal("target_detected", current_target)
			
			# Переводим в состояние преследования
			if ally_brain.current_state_name in ["idle", "patrol", "sleep"]:
				ally_brain.transition_to("chase")
			
			if Config.DEBUG_LOGS:
				print_debug("[EnemyBrain] %s услышал зов и присоединяется!" % ally.entity_name)


func _play_sound(sound_path: String) -> void:
	if sound_path.is_empty():
		return
	
	# Пробуем AudioManager или создаём AudioStreamPlayer2D
	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager and audio_manager.has_method("play_sound_at"):
		audio_manager.play_sound_at(sound_path, enemy.global_position)
		return
	
	# Фолбэк: создаём временный AudioStreamPlayer2D
	var stream := load(sound_path) as AudioStream
	if not stream:
		if Config.DEBUG_LOGS:
			print_debug("[EnemyBrain] Не удалось загрузить звук: %s" % sound_path)
		return
	
	var player := AudioStreamPlayer2D.new()
	player.stream = stream
	player.position = enemy.global_position
	player.bus = "SFX"
	get_tree().current_scene.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

## Проверка может ли атаковать
func can_attack() -> bool:
	return _attack_cooldown_timer <= 0.0

## Начать атаку (запускает кулдаун)
func start_attack() -> void:
	
	_attack_cooldown_timer = combat_data.get("attack_cooldown", 1.5)

## Вызывается из EnemyBase._on_attack_frame() (который вызывается из AnimationPlayer)
func _on_attack_frame() -> void:
	print("[EnemyBrain] _on_attack_frame вызван!")
	if current_state and current_state.has_method("_on_attack_frame"):
		print("[EnemyBrain] Передаём attack_state")
		current_state._on_attack_frame()
	else:
		print("[EnemyBrain] У current_state нет _on_attack_frame")


func _on_attack_end() -> void:
	if current_state and current_state.has_method("_on_attack_end"):
		current_state._on_attack_end()

func stun(duration: float) -> void:
	stun_timer = duration
	transition_to("stunned")
	
	if Config.DEBUG_LOGS:
		print("[EnemyBrain] %s оглушён на %.1f сек" % [enemy.entity_name, duration])

func _on_enemy_damage_taken(amount: int, attacker: Node, from_back: bool) -> void:
	# Передаём событие текущему состоянию
	if current_state:
		current_state.on_damage_taken(amount, attacker, from_back)

## Вызывается из AnimationPlayer
