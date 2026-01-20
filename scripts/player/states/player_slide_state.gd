# scripts/player/states/player_slide_state.gd
# Slide state - player performs invulnerable dodge/dash

class_name PlayerSlideState
extends PlayerState

const SLIDE_DURATION: float = 0.4  # Уменьшили для более быстрого подката
const SLIDE_SPEED: float = 500.0  # Увеличили скорость

var _animation_finished: bool = false
var _timer: float = 0.0

func enter() -> void:
	_animation_finished = false
	_timer = SLIDE_DURATION
	
	# Make invulnerable
	player.invulnerable = true
	
	# Disable collision with enemies during slide
	if player.has_method("set_collision_mask_value"):
		player.set_collision_mask_value(5, false)  # Disable enemy collision layer
	
	# Apply impulse in facing direction
	var direction = get_facing_direction()
	player.velocity = Vector2(float(direction) * SLIDE_SPEED, 0.0)
	
	# Play slide animation
	if fsm.animation_player and fsm.animation_player.has_animation("slide"):
		fsm.animation_player.play("slide")
		# Connect to animation finished
		if not fsm.animation_player.animation_finished.is_connected(_on_animation_finished):
			fsm.animation_player.animation_finished.connect(_on_animation_finished)
	elif fsm.sprite and fsm.sprite.sprite_frames.has_animation("slide"):
		fsm.sprite.play("slide")
		# Connect to sprite animation finished
		if not fsm.sprite.animation_finished.is_connected(_on_sprite_animation_finished):
			fsm.sprite.animation_finished.connect(_on_sprite_animation_finished)
	
	if Config.DEBUG_LOGS:
		print("[FSM] slide → enter (dir: %d, duration: %.2f)" % [direction, SLIDE_DURATION])

func exit() -> void:
	# Remove invulnerability
	player.invulnerable = false
	_timer = 0.0
	
	# Re-enable collision with enemies
	if player.has_method("set_collision_mask_value"):
		player.set_collision_mask_value(5, true)  # Re-enable enemy collision layer
	
	# Disconnect animation signals
	if fsm.animation_player and fsm.animation_player.animation_finished.is_connected(_on_animation_finished):
		fsm.animation_player.animation_finished.disconnect(_on_animation_finished)
	if fsm.sprite and fsm.sprite.animation_finished.is_connected(_on_sprite_animation_finished):
		fsm.sprite.animation_finished.disconnect(_on_sprite_animation_finished)
	
	if Config.DEBUG_LOGS:
		print("[FSM] slide → exit")

func update(delta: float) -> void:
	# Countdown timer
	_timer -= delta
	
	# Check if slide finished (by timer OR animation)
	if _timer <= 0.0 or _animation_finished:
		if Config.DEBUG_LOGS:
			print("[FSM] slide → finished (timer: %.2f, anim: %s)" % [_timer, _animation_finished])
		transition_to("idle")

func physics_update(delta: float) -> void:
	# Decelerate during slide for smooth stop
	var decel_rate = SLIDE_SPEED * 1.5  # Fast deceleration
	player.velocity = player.velocity.move_toward(Vector2.ZERO, decel_rate * delta)
	player.move_and_slide()

func _on_animation_finished(anim_name: StringName) -> void:
	"""Called when AnimationPlayer finishes"""
	if anim_name == "slide":
		_animation_finished = true
		if Config.DEBUG_LOGS:
			print("[FSM] slide → animation finished")

func _on_sprite_animation_finished() -> void:
	"""Called when AnimatedSprite2D finishes"""
	_animation_finished = true
	if Config.DEBUG_LOGS:
		print("[FSM] slide → sprite animation finished")

func on_input(_event: InputEvent) -> void:
	# No input during slide
	pass

func on_damage_taken(_amount: int, _attacker: Node = null, _from_back: bool = false) -> void:
	# Invulnerable - ignore damage (handled by entity)
	pass
