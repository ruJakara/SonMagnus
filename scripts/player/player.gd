## scripts/player/player.gd
## Расширенный контроллер игрока: движение, взаимодействие с PlayerCombat.

extends BaseEntity

# ===== Movement settings =====
@export var acceleration: float = 1200.0
@export var deceleration: float = 1600.0
@export var walk_speed_multiplier: float = 0.5
@export var is_camp_area: bool = false

const IDLE_ANIM: StringName = &"idle"
const MOVE_ANIM: StringName = &"run"

# ===== References =====
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var player_combat: Node = $PlayerCombat
@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var _hitbox: Area2D = $zone/Hitbox

# ===== Internal state =====
var forced_target: Node = null

func _ready() -> void:
	super._ready()
	add_to_group("player")  # Для поиска врагами через EnemyAI
	add_to_group("targetable")  # Для системы фракций и охоты
	_configure_animation_loops()
	if not _sprite.is_playing():
		_sprite.play(IDLE_ANIM)
	_sprite.animation_finished.connect(_on_animation_finished)
	# Инициализируем позицию Hitbox при старте
	_set_facing_direction(1)  # По умолчанию смотрим вправо

func _physics_process(delta: float) -> void:
	# ИСПРАВЛЕНО: проверка блока ПЕРЕД расчётом движения
	if player_combat.is_blocking:
		velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)
		move_and_slide()
		return
	
	var input_vector := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)
	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()

	var effective_speed := speed
	if is_camp_area:
		effective_speed *= walk_speed_multiplier

	var target_velocity := input_vector * effective_speed
	var rate := acceleration if input_vector != Vector2.ZERO else deceleration
	velocity = velocity.move_toward(target_velocity, rate * delta)
	
	move_and_slide()
	_update_movement_animation()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("attack_left"):
		if Config.DEBUG_LOGS:
			print_debug("[Player] ЛКМ pressed")
		player_combat.handle_attack_input("L")

	if event.is_action_pressed("attack_right"):
		if Config.DEBUG_LOGS:
			print_debug("[Player] ПКМ pressed")
		player_combat.handle_attack_input("R")

	if event.is_action_pressed("block"):
		player_combat.handle_block_input(true)
	elif event.is_action_released("block"):
		player_combat.handle_block_input(false)

	if event.is_action_pressed("dash"):
		_do_dash()
	
	if event.is_action_pressed("toggle_weapon"):
		player_combat.toggle_weapon()

func _update_movement_animation() -> void:
	if player_combat != null and player_combat.is_attacking():
		return

	if velocity.length() > 5.0:
		if _sprite.animation != MOVE_ANIM or not _sprite.is_playing():
			_sprite.play(MOVE_ANIM)
	else:
		if _sprite.animation != IDLE_ANIM or not _sprite.is_playing():
			_sprite.play(IDLE_ANIM)

	if velocity.x != 0.0:
		_set_facing_direction(1 if velocity.x > 0 else -1)

func get_target() -> Node:
	if forced_target and is_instance_valid(forced_target):
		return forced_target
	return null

func _do_dash() -> void:
	var dash_strength := 200.0
	var dir := Vector2.RIGHT
	if is_facing_left():
		dir = Vector2.LEFT
	translate(dir * dash_strength * get_process_delta_time())

func is_facing_left() -> bool:
	return _sprite.flip_h

func is_camp() -> bool:
	return is_camp_area

func _on_animation_finished() -> void:
	_update_movement_animation()

func _configure_animation_loops() -> void:
	if not _sprite.sprite_frames:
		return
	var frames := _sprite.sprite_frames
	for anim in [IDLE_ANIM, MOVE_ANIM]:
		if frames.has_animation(anim) and frames.get_animation_loop(anim):
			frames.set_animation_loop(anim, false)

func _set_facing_direction(dir: int) -> void:
	"""Устанавливает направление персонажа (1 = вправо, -1 = влево) и поворачивает Hitbox"""
	_sprite.flip_h = dir < 0
	
	# Поворачиваем Hitbox вместе с направлением
	if _hitbox:
		# Сохраняем абсолютное значение X позиции и применяем направление
		var base_x : float = abs(_hitbox.position.x) if _hitbox.position.x != 0 else 16.0  # 16 - дефолтная позиция из сцены
		_hitbox.position.x = base_x * dir
