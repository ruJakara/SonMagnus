# scripts/player/states/player_move_state.gd
# Move state - player is moving

class_name PlayerMoveState
extends PlayerState

func enter() -> void:
	# Start running animation
	_play_run_animation()
	
	if Config.DEBUG_LOGS:
		print("[FSM] move → enter")

func _play_run_animation() -> void:
	"""Play appropriate run animation based on context"""
	var anim_name = "run"
	if player.is_camp_area:
		anim_name = "walk"
	if fsm.sprite and fsm.sprite.animation != anim_name:
		play_animation(anim_name)

func physics_update(delta: float) -> void:
	var input_vector = get_input_vector()
	
	# Check if stopped moving
	if input_vector.length() < 0.01:
		transition_to("idle")
		return
	
	# Ensure animation is playing (in case it was interrupted)
	if fsm.sprite and not fsm.sprite.is_playing():
		_play_run_animation()
	
	# Calculate movement
	var effective_speed = player.speed
	if player.is_camp_area:
		effective_speed *= player.walk_speed_multiplier
	
	var target_velocity = input_vector * effective_speed
	player.velocity = player.velocity.move_toward(target_velocity, player.acceleration * delta)
	
	# Update facing direction
	update_facing(player.velocity)
	
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
	# Stay in move, damage is handled by entity
	pass
