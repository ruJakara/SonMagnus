## scripts/player/player.gd
## Refactored player with FSM - no lock flags, state machine owns all state

extends BaseEntity

# ===== Stance enum =====
enum Stance { RELAX, FIGHT }

# ===== Movement settings =====
@export var acceleration: float = 1200.0
@export var deceleration: float = 1600.0
@export var walk_speed_multiplier: float = 0.5
@export var is_camp_area: bool = false

# ===== References =====
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var state_machine: PlayerStateMachine = $PlayerStateMachine
@onready var _animation_player: AnimationPlayer = $AnimationPlayer

# ===== Player State =====
var stance: Stance = Stance.RELAX
var invulnerable: bool = false

# ===== Internal state =====
var forced_target: Node = null

func _ready() -> void:
	super._ready()
	add_to_group("player")  # Для поиска врагами через EnemyAI
	add_to_group("targetable")  # Для системы фракций и охоты
	_configure_animation_loops()
	# State machine will handle animations and facing
	# Initial facing direction
	_set_facing_direction(1)  # По умолчанию смотрим вправо

func _physics_process(delta: float) -> void:
	# State machine handles all physics
	pass

func _input(event: InputEvent) -> void:
	# Delegate all input to state machine
	if state_machine:
		state_machine.on_input(event)
	
	# TODO: Skills 1-6 (not implemented yet)
	# TODO: E - interact (not implemented yet)
	# TODO: R/F - quick items (not implemented yet)
	# TODO: X - hide (not implemented yet)

# Movement animation is now handled by states

func get_target() -> Node:
	if forced_target and is_instance_valid(forced_target):
		return forced_target
	return null

func is_facing_left() -> bool:
	return _sprite.flip_h if _sprite else false

func get_facing_direction() -> int:
	"""Возвращает -1 для левого направления, 1 для правого."""
	return -1 if is_facing_left() else 1

func is_camp() -> bool:
	return is_camp_area

# Animation finished is now handled by states

func _configure_animation_loops() -> void:
	if not _sprite or not _sprite.sprite_frames:
		return
	var frames := _sprite.sprite_frames
	# Ensure looping animations are set to loop
	for anim in ["idle", "run", "idleFight", "walk", "sprint"]:
		if frames.has_animation(anim):
			frames.set_animation_loop(anim, true)

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
	"""Переопределяем take_damage для проверки invulnerable и делегирования в FSM."""
	
	# Игнорируем урон если неуязвимы
	if invulnerable:
		if Config.DEBUG_LOGS:
			print("[Player] Урон заблокирован (invulnerable)")
		return
	
	# Delegate to state machine FIRST - let state handle it
	var damage_prevented = false
	if state_machine and state_machine.is_blocking():
		# Block state will handle parry/block logic
		state_machine.on_damage_taken(amount, attacker, from_back)
		damage_prevented = true  # Block state handled damage
	
	if damage_prevented:
		return  # Don't apply damage
	
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
	if attacker and state_machine:
		var knockback_dir = (global_position - attacker.global_position).normalized()
		velocity = knockback_dir * 150.0
		# Короткая блокировка разворота, чтобы нокбэк не флипал спрайт.
		state_machine.combat_data["facing_lock_timer"] = 0.2
