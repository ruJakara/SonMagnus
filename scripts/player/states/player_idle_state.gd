# scripts/player/states/player_idle_state.gd
# Idle state - player is standing still

class_name PlayerIdleState
extends PlayerState

func enter() -> void:
	# Stop movement
	player.velocity = Vector2.ZERO
	
	# Play appropriate idle animation based on stance
	_play_idle_animation()
	
	if Config.DEBUG_LOGS:
		print("[FSM] idle → enter")

func _play_idle_animation() -> void:
	"""Play appropriate idle animation based on stance"""
	var anim = "idleFight" if player.stance == player.Stance.FIGHT else "idle"
	if fsm.sprite and fsm.sprite.animation != anim:
		play_animation(anim)

func physics_update(delta: float) -> void:
	# Check for movement input
	var input_vector = get_input_vector()
	
	if input_vector.length() > 0.01:
		transition_to("move")
		return
	
	# Ensure animation is playing
	if fsm.sprite and not fsm.sprite.is_playing():
		_play_idle_animation()
	
	# Apply deceleration
	player.velocity = player.velocity.move_toward(Vector2.ZERO, player.deceleration * delta)
	player.move_and_slide()

func on_input(event: InputEvent) -> void:
	# Q: Stance Toggle
	if event.is_action_pressed("toggle_weapon"):
		if fsm.can_toggle_stance():
			transition_to("stance_toggle")
	
	# LMB: Left attack
	elif event.is_action_pressed("attack_left"):
		if fsm.can_attack():
			fsm.add_to_sequence("L")
			transition_to("attack")
	
	# RMB: Right attack
	elif event.is_action_pressed("attack_right"):
		if fsm.can_attack():
			fsm.add_to_sequence("R")
			transition_to("attack")
	
	# Space: Block (hold)
	elif event.is_action_pressed("block"):
		if fsm.can_block():
			transition_to("block")
	
	# Shift: Slide/Dash
	elif event.is_action_pressed("dash"):
		if fsm.can_slide():
			transition_to("slide")

func on_damage_taken(_amount: int, _attacker: Node = null, _from_back: bool = false) -> void:
	# Stay in idle, damage is handled by entity
	pass
