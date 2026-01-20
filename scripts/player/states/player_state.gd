# scripts/player/states/player_state.gd
# Base class for all player states

class_name PlayerState
extends State

## Convenience references to player and state machine
var player: Node:
	get:
		return entity

var fsm: PlayerStateMachine:
	get:
		return state_machine as PlayerStateMachine

## Helper methods

func play_animation(anim_name: String) -> void:
	if fsm.sprite and fsm.sprite.sprite_frames.has_animation(anim_name):
		fsm.sprite.play(anim_name)

func play_animation_player(anim_name: String) -> void:
	if fsm.animation_player and fsm.animation_player.has_animation(anim_name):
		fsm.animation_player.play(anim_name)

func get_input_vector() -> Vector2:
	var input := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)
	if input.length() > 1.0:
		input = input.normalized()
	return input

func update_facing(velocity: Vector2) -> void:
	if fsm.combat_data["facing_lock_timer"] <= 0.0 and velocity.x != 0.0:
		var dir = 1 if velocity.x > 0 else -1
		set_facing_direction(dir)

func set_facing_direction(dir: int) -> void:
	if fsm.sprite:
		fsm.sprite.flip_h = dir < 0
	
	# Flip zones
	var zone = player.get_node_or_null("zone")
	if zone:
		zone.scale.x = abs(zone.scale.x) * dir

func get_facing_direction() -> int:
	if fsm.sprite:
		return -1 if fsm.sprite.flip_h else 1
	return 1
