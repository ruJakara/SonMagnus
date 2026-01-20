# scripts/systems/fsm/state_machine.gd
# Base State Machine class
# Manages state transitions and owns current_state

class_name StateMachine
extends Node

## Current active state
var current_state: State = null
var current_state_name: String = ""

## Dictionary of all registered states {name: State}
var states: Dictionary = {}

## Reference to the entity that owns this state machine
var entity: Node = null

## Signals
signal state_changed(old_state: String, new_state: String)

func _ready() -> void:
	# Entity is the parent node
	entity = get_parent()
	
	# Wait one frame to ensure entity is fully initialized
	await get_tree().process_frame
	
	# Register states - override in subclass
	_register_states()
	
	# Start with initial state - override in subclass
	var initial_state = _get_initial_state()
	if not initial_state.is_empty():
		transition_to(initial_state)

## Override in subclass to register all states
func _register_states() -> void:
	pass

## Override in subclass to define initial state
func _get_initial_state() -> String:
	return ""

## Add a state to the machine
func add_state(state_name: String, state: State) -> void:
	state.state_machine = self
	state.entity = entity
	states[state_name] = state

## Transition to a new state (ONLY way to change states)
func transition_to(new_state_name: String) -> void:
	if not states.has(new_state_name):
		push_warning("[FSM] State not found: %s" % new_state_name)
		return
	
	# Exit current state
	if current_state:
		current_state.exit()
	
	# Save old state name for signal
	var old_state_name = current_state_name
	
	# Switch to new state
	current_state_name = new_state_name
	current_state = states[new_state_name]
	
	# Enter new state
	current_state.enter()
	
	# Emit signal
	emit_signal("state_changed", old_state_name, new_state_name)
	
	if Config.DEBUG_LOGS:
		print("[FSM] %s → %s" % [old_state_name, new_state_name])

func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

## Event handlers - delegate to current state

func on_damage_taken(amount: int, attacker: Node = null, from_back: bool = false) -> void:
	if current_state:
		current_state.on_damage_taken(amount, attacker, from_back)

func on_input(event: InputEvent) -> void:
	if current_state:
		current_state.on_input(event)
