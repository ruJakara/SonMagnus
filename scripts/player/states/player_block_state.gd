# scripts/player/states/player_block_state.gd
# Block state - player is blocking attacks

class_name PlayerBlockState
extends PlayerState

const PARRY_WINDOW: float = 0.3

func enter() -> void:
	# Stop movement
	player.velocity = Vector2.ZERO
	
	# Start parry window
	fsm.combat_data["parry_timer"] = PARRY_WINDOW
	
	# Play block animation (in AnimatedSprite2D, not AnimationPlayer)
	play_animation("block")
	
	if Config.DEBUG_LOGS:
		print("[FSM] block → enter (parry active)")

func exit() -> void:
	fsm.combat_data["parry_timer"] = 0.0

func physics_update(delta: float) -> void:
	# Decelerate during block
	player.velocity = player.velocity.move_toward(Vector2.ZERO, player.deceleration * delta)
	player.move_and_slide()

func on_input(event: InputEvent) -> void:
	# Release block
	if event.is_action_released("block"):
		transition_to("idle")

func on_damage_taken(amount: int, attacker: Node = null, from_back: bool = false) -> void:
	# Check parry window
	if fsm.combat_data["parry_timer"] > 0.0:
		_on_parry_success(attacker)
	else:
		_on_block_hit(attacker)

func _on_parry_success(attacker: Node) -> void:
	# Restore stamina
	if player.has_method("restore_stamina"):
		player.restore_stamina(10.0)
	
	# Stun attacker
	if attacker and attacker.has_method("apply_status_effect"):
		attacker.apply_status_effect("stunned")
	
	# Add combat profile score
	# TODO: Restore combat profile system
	
	# End parry window
	fsm.combat_data["parry_timer"] = 0.0
	
	if Config.DEBUG_LOGS:
		print("[FSM] block → parry успешно!")

func _on_block_hit(attacker: Node) -> void:
	# Consume stamina
	if player.has_method("consume_stamina"):
		if not player.consume_stamina(5.0):
			# Out of stamina - break block
			transition_to("idle")
			if Config.DEBUG_LOGS:
				print("[FSM] block → сломан (нет стамины)")
			return
	
	if Config.DEBUG_LOGS:
		print("[FSM] block → поглотил урон")
