## scripts/player/player.gd
## Расширенный контроллер игрока: движение, взаимодействие с PlayerCombat.

extends BaseEntity

# ===== Stance enum =====
enum Stance { RELAX, FIGHT }

# ===== Movement settings =====
@export var acceleration: float = 1200.0
@export var deceleration: float = 1600.0
@export var walk_speed_multiplier: float = 0.5
@export var is_camp_area: bool = false

const IDLE_ANIM: StringName = &"idle"
const IDLE_FIGHT_ANIM: StringName = &"idleFight"
const MOVE_ANIM: StringName = &"run"

# ===== References =====
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var player_combat: Node = $PlayerCombat
@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var _hitbox: Area2D = $zone/Hitbox

# ===== Player State =====
var stance: Stance = Stance.RELAX
var invulnerable: bool = false

# Lock flags - when true, action is blocked
var lock_attack: bool = false
var lock_block: bool = false
var lock_slide: bool = false
var lock_stance_toggle: bool = false

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
	# Q: Stance Toggle
	if event.is_action_pressed("toggle_weapon"):
		player_combat.request_toggle_stance()
	
	# ЛКМ: Left attack
	if event.is_action_pressed("attack_left"):
		player_combat.request_attack("L")
	
	# ПКМ: Right attack
	if event.is_action_pressed("attack_right"):
		player_combat.request_attack("R")
	
	# Space: Block (hold)
	if event.is_action_pressed("block"):
		player_combat.request_block(true)
	elif event.is_action_released("block"):
		player_combat.request_block(false)
	
	# Shift: Slide/Dash
	if event.is_action_pressed("dash"):
		player_combat.request_slide()
	
	# TODO: Skills 1-6 (not implemented yet)
	# TODO: E - interact (not implemented yet)
	# TODO: R/F - quick items (not implemented yet)
	# TODO: X - hide (not implemented yet)

func _update_movement_animation() -> void:
	if player_combat != null and player_combat.is_attacking():
		return

	if velocity.length() > 5.0:
		if _sprite.animation != MOVE_ANIM or not _sprite.is_playing():
			_sprite.play(MOVE_ANIM)
	else:
		# Choose idle animation based on stance
		var target_idle := IDLE_FIGHT_ANIM if stance == Stance.FIGHT else IDLE_ANIM
		if _sprite.animation != target_idle or not _sprite.is_playing():
			_sprite.play(target_idle)

	if velocity.x != 0.0:
		_set_facing_direction(1 if velocity.x > 0 else -1)

func get_target() -> Node:
	if forced_target and is_instance_valid(forced_target):
		return forced_target
	return null

func is_facing_left() -> bool:
	return _sprite.flip_h

func get_facing_direction() -> int:
	"""Возвращает -1 для левого направления, 1 для правого."""
	return -1 if is_facing_left() else 1

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

@onready var _zone: Node2D = $zone

func _set_facing_direction(dir: int) -> void:
	_sprite.flip_h = dir < 0
	
	# Флипаем зоны через scale.x (НЕ через position!)
	# Это правильный способ для Area2D чтобы коллизии работали корректно
	if _zone:
		_zone.scale.x = abs(_zone.scale.x) * dir

# ===== Resource Management =====

func consume_stamina(cost: float) -> bool:
	"""Пытается потратить стамину. Возвращает true если хватило."""
	if _stamina >= cost:
		reduce_stamina(cost)
		return true
	return false

# ===== Combat Overrides =====

func take_damage(amount: int, attacker: Node = null, from_back: bool = false) -> void:
	"""Переопределяем take_damage для проверки invulnerable и блока."""
	
	# Игнорируем урон если неуязвимы
	if invulnerable:
		if Config.DEBUG_LOGS:
			print("[Player] Урон заблокирован (invulnerable)")
		return
	
	# Проверяем парирование/блок через PlayerCombat
	if player_combat and player_combat.is_blocking:
		if player_combat.try_parry(attacker):
			if Config.DEBUG_LOGS:
				print("[Player] Парирование успешно!")
			return
		else:
			if Config.DEBUG_LOGS:
				print("[Player] Блок поглотил урон")
			return
	
	# Обычный урон через BaseEntity
	super.take_damage(amount)
	
	# Визуальный фидбек
	_play_hit_feedback(attacker)


func _play_hit_feedback(attacker: Node = null) -> void:
	"""Визуальный фидбек при получении урона"""
	if not _sprite:
		return
	
	# Hitstop
	Engine.time_scale = 0.0
	await get_tree().create_timer(0.05, true, false, true).timeout
	Engine.time_scale = 1.0
	
	# Блинк эффект
	var tween = create_tween()
	tween.set_loops(2)
	tween.tween_property(_sprite, "modulate", Color(1.5, 0.5, 0.5, 1.0), 0.075)
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.075)
	tween.finished.connect(func(): _sprite.modulate = Color.WHITE)
	
	# Knockback
	if attacker:
		var knockback_dir = (global_position - attacker.global_position).normalized()
		velocity = knockback_dir * 150.0
