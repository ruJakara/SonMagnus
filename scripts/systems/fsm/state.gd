# scripts/systems/fsm/state.gd
# Base State class for FSM
# Each state contains only its own logic, no direct entity manipulation

class_name State
extends RefCounted

## Reference to the state machine that owns this state
var state_machine: Node = null

## Reference to the entity (for convenience)
var entity: Node = null

## Called when entering this state
func enter() -> void:
	pass

## Called when exiting this state
func exit() -> void:
	pass

## Called every frame (_process)
func update(_delta: float) -> void:
	pass

## Called every physics frame (_physics_process)
func physics_update(_delta: float) -> void:
	pass

## Called when entity receives damage
func on_damage_taken(_amount: int, _attacker: Node = null, _from_back: bool = false) -> void:
	pass

## Called on input events
func on_input(_event: InputEvent) -> void:
	pass

## Helper to transition to another state
func transition_to(state_name: String) -> void:
	if state_machine:
		state_machine.transition_to(state_name)
