## scripts/player/player.gd
## Расширенный контроллер игрока: движение, взаимодействие с PlayerCombat.

extends BaseEntity

# ===== Movement settings =====
@export var acceleration: float = 1200.0
@export var deceleration: float = 1600.0

const IDLE_ANIM: StringName = &"idle"
const MOVE_ANIM: StringName = &"run"

# ===== References =====
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var player_combat: Node = $PlayerCombat

# ===== Internal state =====
var forced_target: Node = null

func _ready() -> void:
	super._ready()
	_configure_animation_loops()
	if not _sprite.is_playing():
		_sprite.play(IDLE_ANIM)
	_sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(delta: float) -> void:
	var input_vector := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)
	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()

	var target_velocity := input_vector * speed
	var rate := acceleration if input_vector != Vector2.ZERO else deceleration
	velocity = velocity.move_toward(target_velocity, rate * delta)
	
	move_and_slide()
	_update_movement_animation()  # ← обновляем ТОЛЬКО если не атакуем

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

func _update_movement_animation() -> void:
	# 🔥 ВАЖНО: НЕ обновлять анимацию, если игрок атакует
	if player_combat != null and player_combat.is_attacking():
		return

	if velocity.length() > 5.0:
		if _sprite.animation != MOVE_ANIM or not _sprite.is_playing():
			_sprite.play(MOVE_ANIM)
	else:
		if _sprite.animation != IDLE_ANIM or not _sprite.is_playing():
			_sprite.play(IDLE_ANIM)

	if velocity.x != 0.0:
		_sprite.flip_h = velocity.x < 0.0

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

func _on_animation_finished() -> void:
	_update_movement_animation()

func _configure_animation_loops() -> void:
	if not _sprite.sprite_frames:
		return
	var frames := _sprite.sprite_frames
	for anim in [IDLE_ANIM, MOVE_ANIM]:
		if frames.has_animation(anim) and frames.get_animation_loop(anim):
			frames.set_animation_loop(anim, false)
