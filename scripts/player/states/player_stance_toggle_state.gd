# scripts/player/states/player_stance_toggle_state.gd
# Stance toggle state - player switches between RELAX and FIGHT stances

class_name PlayerStanceToggleState
extends PlayerState

var _animation_name: String = ""
var _toggle_timer: float = 0.0
var _completed: bool = false
const TOGGLE_DURATION: float = 0.6  # Fallback duration if animation doesn't signal

func enter() -> void:
	# Stop movement
	player.velocity = Vector2.ZERO
	_completed = false
	
	# Determine animation based on current stance
	_animation_name = "weaponOFF" if player.stance == player.Stance.FIGHT else "weaponON"
	_toggle_timer = TOGGLE_DURATION
	
	# IMPORTANT: Reset sprite speed to normal for stance animations
	if fsm.sprite:
		fsm.sprite.speed_scale = 1.0
	
	# Play animation using AnimatedSprite2D (these animations are in sprite frames, not AnimationPlayer)
	if fsm.sprite and fsm.sprite.sprite_frames.has_animation(_animation_name):
		fsm.sprite.play(_animation_name)
		# Connect to sprite animation finished (only once)
		if not fsm.sprite.animation_finished.is_connected(_on_sprite_animation_finished):
			fsm.sprite.animation_finished.connect(_on_sprite_animation_finished)
	else:
		if Config.DEBUG_LOGS:
			print("[FSM] stance_toggle → WARNING: animation not found: %s" % _animation_name)
	
	if Config.DEBUG_LOGS:
		print("[FSM] stance_toggle → %s" % _animation_name)

func exit() -> void:
	# Disconnect animation signal to prevent callbacks after state change
	if fsm.sprite and fsm.sprite.animation_finished.is_connected(_on_sprite_animation_finished):
		fsm.sprite.animation_finished.disconnect(_on_sprite_animation_finished)

func update(delta: float) -> void:
	# Fallback timer in case animation doesn't trigger finished signal
	_toggle_timer -= delta
	if _toggle_timer <= 0.0:
		_complete_stance_toggle()

func physics_update(delta: float) -> void:
	# Stay still during stance change
	player.velocity = player.velocity.move_toward(Vector2.ZERO, player.deceleration * delta)
	player.move_and_slide()

func on_input(_event: InputEvent) -> void:
	# No input during stance toggle
	pass

func _on_sprite_animation_finished() -> void:
	_complete_stance_toggle()

func _complete_stance_toggle() -> void:
	# Guard against double completion
	if _completed:
		return
	_completed = true
	
	# Toggle stance
	if player.stance == player.Stance.FIGHT:
		player.stance = player.Stance.RELAX
	else:
		player.stance = player.Stance.FIGHT
	
	if Config.DEBUG_LOGS:
		print("[FSM] stance_toggle → завершён, новая стойка: %s" % ["RELAX" if player.stance == player.Stance.RELAX else "FIGHT"])
	
	# Return to idle
	transition_to("idle")
