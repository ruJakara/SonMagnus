# scripts/entities/enemies/states/enemy_state.gd
# Base class for all enemy states
# Uses unified FSM pattern

class_name EnemyState
extends State

## Ссылка на мозг врага (владелец state machine)
var brain: EnemyBrain:
	get:
		return state_machine as EnemyBrain

## Helper to transition to another state (uses parent's state_machine)
# Note: This overrides State.transition_to() but calls the same method
func change_state(state_name: String) -> void:
	transition_to(state_name)
