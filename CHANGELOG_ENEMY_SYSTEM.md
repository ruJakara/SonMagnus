# Changelog - Enemy System Implementation

## [v1.0.0] - 2026-01-04

### Added - Core System
- **EnemyBase** class (extends BaseEntity)
  - JSON data loading system
  - Animation management
  - Damage handling with backstab/sleeping multipliers
  - Visual effects (blink, knockback)
  - Loot spawning on death
  
- **EnemyBrain** component
  - State machine implementation
  - Cone vision detection system
  - Hostility checking
  - Help calling system
  - Attack cooldown management

- **EnemyState** base class
  - Common interface for all states
  - enter(), exit(), update(), physics_update() methods
  - on_damage_taken() callback

### Added - States (8 total)
- **IdleState** - stands and watches
- **PatrolState** - random patrolling with pauses
- **ChaseState** - pursues target
- **AttackState** - attacks via CombatManager
- **DeadState** - death animation and cleanup
- **SleepState** - sleeping (wakes on damage)
- **StunnedState** - stunned state
- **CallHelpState** - calls for reinforcements

### Added - Loot System
- **LootManager** (Autoload)
  - JSON loot table loading
  - Roll system with drop chances
  - Variable item amounts
- Loot table structure (`data/loot_tables/`)
- Example: `goblin_common.json`

### Added - Data Files
- `data/enemies/goblin.json` - goblin scout configuration
- `data/loot_tables/goblin_common.json` - goblin loot table
- Combo `enemy_basic` in `data/combos/unarmed.json` (already existed)

### Added - Scenes
- `scenes/enemies/EnemyBase.tscn` - base enemy scene with collision zones
- `scenes/enemies/goblin_scout.tscn` - example enemy
- `scenes/enemies/goblin_scout.gd` - initialization script
- `scenes/test_enemy.tscn` - testing scene

### Added - Documentation
- `docs/enemy_system.md` - full system documentation
- `docs/enemy_examples.md` - usage examples (7 scenarios)
- `docs/enemy_implementation_report.md` - technical report
- `README_ENEMY_SYSTEM.md` - quick start guide

### Added - Tests
- `tests/test_enemy_system.gd` - unit tests for enemy system

### Modified
- `project.godot` - added LootManager to autoload
- `scenes/enemies/EnemyBase.tscn` - restructured collision layers

### Technical Details
- **Architecture**: State Pattern + Data-Driven (90% in JSON)
- **Integration**: Uses CombatManager, ComboManager, EffectManager
- **Collision Layers**: Compatible with existing player system
- **Performance**: Optimized state switching, minimal overhead

### Features
- ✅ Cone vision detection (configurable angle)
- ✅ Random patrolling
- ✅ Target pursuit
- ✅ Combat integration
- ✅ Backstab mechanic (2x damage + stun)
- ✅ Sleeping mechanic (2.5x damage + stun)
- ✅ Call for help (at low HP)
- ✅ Loot drop system
- ✅ Easy to extend (add new states/enemies)

### TODO (Optional Improvements)
- [ ] Add AnimationPlayer method tracks for attacks
- [ ] Add "player" tag to player tags array
- [ ] Create LootMarker scene for visual loot representation
- [ ] Add sound effects (attack, death, call for help)
- [ ] Debug visualization for vision cone
- [ ] Ally reinforcement logic
- [ ] Loot UI

### Breaking Changes
None - system is fully additive

### Migration Guide
No migration needed. To use:
1. Add method tracks in AnimationPlayer (one-time setup)
2. Add "player" tag to player (one line of code)

### File Structure
```
scripts/entities/enemies/
├── enemy_base.gd
├── enemy_brain.gd
└── states/ (9 files)

scenes/enemies/
├── EnemyBase.tscn
├── goblin_scout.tscn
└── goblin_scout.gd

data/
├── enemies/goblin.json
└── loot_tables/goblin_common.json

autoload/
└── LootManager.gd

docs/ (4 files)
tests/test_enemy_system.gd
README_ENEMY_SYSTEM.md
```

### Credits
- Implementation based on detailed specification
- State Pattern for clean, maintainable AI
- Data-driven design for easy content creation


