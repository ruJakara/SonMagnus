# FSM Quick Reference

## 📁 New File Structure

```
scripts/
├── systems/fsm/
│   ├── state_machine.gd          # Base StateMachine class
│   └── state.gd                   # Base State class
│
├── player/
│   ├── player.gd                  # Refactored - no lock flags
│   ├── player_state_machine.gd    # NEW - Player FSM
│   └── states/
│       ├── player_state.gd        # NEW - Base player state
│       ├── player_idle_state.gd   # NEW
│       ├── player_move_state.gd   # NEW
│       ├── player_attack_state.gd # NEW
│       ├── player_block_state.gd  # NEW
│       ├── player_slide_state.gd  # NEW
│       └── player_stance_toggle_state.gd # NEW
│
└── entities/enemies/
    ├── enemy_brain.gd             # Refactored - extends StateMachine
    └── states/
        ├── enemy_state.gd         # Refactored - extends State
        ├── idle_state.gd          # Compatible
        ├── patrol_state.gd        # Compatible
        ├── chase_state.gd         # Compatible
        ├── attack_state.gd        # Compatible
        ├── sleep_state.gd         # Compatible
        ├── dead_state.gd          # Compatible
        └── call_help_state.gd     # Compatible
```

## 🎮 Player State Transitions

```
          Input Events
               ↓
        PlayerStateMachine
               ↓
    ┌──────────┴──────────┐
    │   Current State     │
    └─────────────────────┘
            ↓
    State Transition Logic


IDLE ←──────────────┐
  │                 │
  ├─→ MOVE ─────────┤
  ├─→ ATTACK ───────┤
  ├─→ BLOCK ────────┤
  ├─→ SLIDE ────────┤
  └─→ STANCE_TOGGLE─┘
```

### State Conditions

| From State | To State | Trigger | Condition |
|------------|----------|---------|-----------|
| IDLE | MOVE | WASD input | Input vector > 0 |
| MOVE | IDLE | No input | Input vector = 0 |
| IDLE/MOVE | ATTACK | LMB/RMB | can_attack() |
| IDLE/MOVE | BLOCK | Space | can_block() |
| IDLE/MOVE | SLIDE | Shift | can_slide() |
| IDLE/MOVE | STANCE_TOGGLE | Q | can_toggle_stance() |
| ATTACK | IDLE | Anim end | No buffered input |
| BLOCK | IDLE | Space release | - |
| SLIDE | IDLE | Timer end | slide_timer = 0 |
| STANCE_TOGGLE | IDLE | Anim end | - |

## 👾 Enemy State Transitions

```
IDLE → PATROL → CHASE → ATTACK → CHASE → IDLE
  ↓      ↓        ↓        ↓
SLEEP  CHASE   CALL_HELP  IDLE
  ↓
CHASE

Any State → DEAD (when health = 0)
```

### State Conditions

| From State | To State | Trigger | Condition |
|------------|----------|---------|-----------|
| IDLE | PATROL | Init | ai_type = "patrol" |
| IDLE | SLEEP | Init | ai_type = "sleep" |
| IDLE/PATROL | CHASE | Detection | Target in cone |
| CHASE | ATTACK | Distance | distance <= attack_range |
| CHASE | IDLE | Distance | distance > lose_range |
| CHASE | CALL_HELP | HP Low | hp_ratio <= threshold |
| ATTACK | CHASE | Distance | distance > attack_range |
| ATTACK | IDLE | No target | target invalid |
| SLEEP | CHASE | Damage | - |
| ANY | DEAD | Death | health = 0 |

## 💻 Code Patterns

### Creating a New State

```gdscript
# scripts/player/states/my_new_state.gd
class_name MyNewState
extends PlayerState

func enter() -> void:
    # Setup state
    play_animation("my_anim")
    if Config.DEBUG_LOGS:
        print("[FSM] my_state → enter")

func exit() -> void:
    # Cleanup state
    pass

func update(delta: float) -> void:
    # Check for transition conditions
    if some_condition:
        transition_to("idle")

func physics_update(delta: float) -> void:
    # Physics logic
    player.move_and_slide()

func on_input(event: InputEvent) -> void:
    # Handle input
    if event.is_action_pressed("action"):
        transition_to("other_state")
```

### Adding State to Machine

```gdscript
# In PlayerStateMachine._register_states()
func _register_states() -> void:
    # ... existing states ...
    add_state("my_state", preload("res://scripts/player/states/my_new_state.gd").new())
```

### Transitioning Between States

```gdscript
# CORRECT ✅ - Call from within state
transition_to("idle")

# CORRECT ✅ - Call from state machine
state_machine.transition_to("idle")

# WRONG ❌ - Never manipulate directly
state_machine.current_state = some_state
```

## 🔍 Debug Logs

Enable in `autoload/Config.gd`:
```gdscript
const DEBUG_LOGS: bool = true
```

Expected log format:
```
[FSM] idle → move
[FSM] move → attack
[FSM] attack → idle
```

## 🚨 Common Pitfalls

### ❌ DON'T DO THIS:
```gdscript
# Don't check state manually
if player.is_attacking:  # ❌ No such flag anymore
    do_something()

# Don't manipulate state directly
player.current_state = attack_state  # ❌ Wrong

# Don't use lock flags
if not lock_attack:  # ❌ No lock flags
    attack()
```

### ✅ DO THIS INSTEAD:
```gdscript
# Check state through FSM
if player.state_machine.is_attacking():  # ✅
    do_something()

# Transition through FSM
player.state_machine.transition_to("attack")  # ✅

# States handle their own logic
# No need for external locks!
```

## 📚 Key Classes

### StateMachine (Base)
- **Properties**: `current_state`, `current_state_name`, `states`, `entity`
- **Methods**: `transition_to()`, `add_state()`, `on_damage_taken()`, `on_input()`

### State (Base)
- **Properties**: `state_machine`, `entity`
- **Methods**: `enter()`, `exit()`, `update()`, `physics_update()`, `on_damage_taken()`, `on_input()`, `transition_to()`

### PlayerStateMachine
- **Extends**: `StateMachine`
- **Extra**: `combat_data` dictionary for shared combat state

### EnemyBrain
- **Extends**: `StateMachine`
- **Extra**: `behavior_data`, `combat_data`, `hostility_data`, AI detection methods

## 🎯 Next Steps

1. Open Godot Editor
2. Follow manual setup in [fsm_testing_guide.md](fsm_testing_guide.md)
3. Test all player states
4. Test all enemy states
5. Check debug logs
6. Report any issues

Good luck! 🚀
