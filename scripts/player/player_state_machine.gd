# scripts/player/player_state_machine.gd
# Player State Machine
# Manages player states (idle, move, attack, block, slide, stance_toggle)

class_name PlayerStateMachine
extends StateMachine

## Player-specific references
var player: Node = null
var sprite: AnimatedSprite2D = null
var animation_player: AnimationPlayer = null
var hitbox: Area2D = null

## Shared combat data (accessed by states)
var combat_data: Dictionary = {
	"attack_cooldown": 0.0,
	"combo_sequence": [],
	"combo_buffer_timer": 0.0,
	"active_attack_request": null,
	"hit_targets": [],
	"hit_window_open": false,
	"parry_timer": 0.0,
	"slide_timer": 0.0,
	"facing_lock_timer": 0.0
}

func _ready() -> void:
	# Get player references
	player = get_parent()
	sprite = player.get_node_or_null("AnimatedSprite2D")
	animation_player = player.get_node_or_null("AnimationPlayer")
	hitbox = player.get_node_or_null("zone/Hitbox")
	
	super._ready()

func _register_states() -> void:
	# Register all player states
	add_state("idle", preload("res://scripts/player/states/player_idle_state.gd").new())
	add_state("move", preload("res://scripts/player/states/player_move_state.gd").new())
	add_state("attack", preload("res://scripts/player/states/player_attack_state.gd").new())
	add_state("block", preload("res://scripts/player/states/player_block_state.gd").new())
	add_state("slide", preload("res://scripts/player/states/player_slide_state.gd").new())
	add_state("stance_toggle", preload("res://scripts/player/states/player_stance_toggle_state.gd").new())

func _get_initial_state() -> String:
	return "idle"

## Helper methods for states

func is_attacking() -> bool:
	return current_state_name == "attack"

func is_blocking() -> bool:
	return current_state_name == "block"

func is_sliding() -> bool:
	return current_state_name == "slide"

func can_attack() -> bool:
	return combat_data["attack_cooldown"] <= 0.0

func can_block() -> bool:
	return current_state_name in ["idle", "move"]

func can_slide() -> bool:
	return current_state_name in ["idle", "move"]

func can_toggle_stance() -> bool:
	return current_state_name in ["idle", "move"]

## Combat sequence management

func add_to_sequence(button: String) -> void:
	combat_data["combo_sequence"].append(button)
	if combat_data["combo_sequence"].size() > 6:
		combat_data["combo_sequence"].pop_front()

func reset_sequence() -> void:
	combat_data["combo_sequence"].clear()

func get_sequence() -> Array:
	return combat_data["combo_sequence"]

## Timer management
func _process(delta: float) -> void:
	super._process(delta)
	
	# Update combat timers
	if combat_data["attack_cooldown"] > 0.0:
		combat_data["attack_cooldown"] -= delta
	
	if combat_data["combo_buffer_timer"] > 0.0:
		combat_data["combo_buffer_timer"] -= delta
	
	if combat_data["parry_timer"] > 0.0:
		combat_data["parry_timer"] -= delta
	
	if combat_data["slide_timer"] > 0.0:
		combat_data["slide_timer"] -= delta
	
	if combat_data["facing_lock_timer"] > 0.0:
		combat_data["facing_lock_timer"] -= delta

## Animation callback bridges - called by AnimationPlayer method tracks
func on_attack_frame() -> void:
	"""Called from AnimationPlayer during attack animation hit frame"""
	if current_state and current_state.has_method("on_attack_frame"):
		current_state.on_attack_frame()

func on_attack_end() -> void:
	"""Called from AnimationPlayer at the end of attack animation"""
	if current_state and current_state.has_method("on_attack_end"):
		current_state.on_attack_end()
