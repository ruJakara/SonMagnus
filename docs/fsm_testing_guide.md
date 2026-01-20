# FSM Refactoring - Testing Guide

## 🔧 Manual Setup Steps (REQUIRED)

### 1. Update player.tscn Scene File

Open `scenes/player/player.tscn` in Godot Editor and:

1. **Delete the old PlayerCombat node** and its children:
   - PlayerCombat
     - State
     - Stance
     - Slide
     - Attack
     - Block

2. **Add PlayerStateMachine node**:
   - Right-click on Player root node
   - Add Child Node
   - Select "Node"
   - Rename to "PlayerStateMachine"
   - Attach script: `res://scripts/player/player_state_machine.gd`

3. **Save the scene**

### 2. Update AnimationPlayer Attack Tracks

For attack animations that call `_on_attack_frame()`:

**OLD method track:**
```
$PlayerCombat/Attack._on_attack_frame()
```

**NEW method track:**
```
$PlayerStateMachine.current_state.on_attack_frame()
```

Attack animations to update:
- `light_attack_left`
- `light_attack_right`
- `heavy_attack_left`
- `heavy_attack_right`
- Any combo animations

### 3. Delete Obsolete Files (Optional but Recommended)

These files are no longer used:
```
scripts/player/PlayerCombat.gd
scripts/player/components/player_combat_state.gd
scripts/player/components/player_attack_controller.gd
scripts/player/components/player_block_controller.gd
scripts/player/components/player_slide_controller.gd
scripts/player/components/player_stance_controller.gd
```

## ✅ Testing Checklist

### Player FSM Tests

#### 1. Basic Movement
- [ ] Player starts in idle state
- [ ] WASD movement transitions to move state
- [ ] Releasing movement keys returns to idle
- [ ] Player faces correct direction when moving
- [ ] Camp area applies walk speed multiplier

#### 2. Attack System
- [ ] LMB/RMB triggers attack state
- [ ] Combo sequences work correctly
- [ ] Attack animations play fully
- [ ] Attack cooldown prevents spam
- [ ] Buffered inputs during attack work
- [ ] Hit detection works (enemies take damage)
- [ ] Returns to idle after attack completes

#### 3. Block/Parry
- [ ] Spacebar enters block state
- [ ] Player stops moving during block
- [ ] Parry window activates at block start
- [ ] Successful parry stuns attacker
- [ ] Successful parry restores stamina
- [ ] Normal block consumes stamina
- [ ] Block breaks when out of stamina
- [ ] Releasing space returns to idle

#### 4. Slide/Dash
- [ ] Shift key triggers slide state
- [ ] Player becomes invulnerable during slide
- [ ] Slide moves in facing direction
- [ ] Slide animation plays
- [ ] Returns to idle after slide duration
- [ ] Cannot take damage during slide

#### 5. Stance Toggle
- [ ] Q key triggers stance toggle
- [ ] Cannot move during stance change
- [ ] Animation plays correctly (weaponON/weaponOFF)
- [ ] Stance actually changes after animation
- [ ] Returns to idle after toggle completes
- [ ] Idle animation reflects new stance

#### 6. Debug Logs
Enable `Config.DEBUG_LOGS = true` and verify:
- [ ] Log format: `[FSM] state_from → state_to`
- [ ] State transitions logged correctly
- [ ] No duplicate or missing transitions

### Enemy FSM Tests

#### 1. Idle State
- [ ] Enemy stands still
- [ ] Detects player in vision cone
- [ ] Transitions to chase when player spotted
- [ ] Reacts to damage with chase/attack

#### 2. Patrol State
- [ ] Random movement between waypoints
- [ ] Pauses at waypoints
- [ ] Detects player during patrol
- [ ] Transitions to chase on detection

#### 3. Chase State
- [ ] Pursues detected target
- [ ] Maintains pursuit within lose range
- [ ] Transitions to attack in attack range
- [ ] Returns to idle if target too far
- [ ] Calls for help at low HP threshold

#### 4. Attack State
- [ ] Stops and attacks when in range
- [ ] Attack animation plays
- [ ] Damage dealt to player
- [ ] Respects attack cooldown
- [ ] Continues chase if target moves away
- [ ] Returns to idle after combat

#### 5. Sleep State
- [ ] Enemy doesn't react to vision
- [ ] Wakes up when damaged
- [ ] Transitions to chase after waking

#### 6. Dead State
- [ ] Death animation plays
- [ ] Loot spawns correctly
- [ ] No further state transitions

## 🐛 Known Issues to Watch For

### Player Issues
1. **Animation Player references**: Make sure all method tracks point to correct node path
2. **Hitbox detection**: Verify attack hit detection still works with new state
3. **Input buffering**: Test rapid button presses during attacks
4. **Facing lock**: Knockback should not flip sprite immediately

### Enemy Issues
1. **State transitions**: Verify `brain.change_state()` calls work correctly
2. **Vision detection**: Ensure detection still works properly
3. **Attack timing**: Verify attack cooldown and animations sync

## 📊 Performance Checks

With `Config.DEBUG_LOGS = true`:
- Check for excessive state transitions
- Verify no infinite loops between states
- Confirm states exit cleanly (no resource leaks)

## 🎯 Success Criteria

✅ Player can move, attack, block, slide, and toggle stance smoothly
✅ All animations play correctly
✅ Enemy AI behaviors function as before
✅ Zero console errors or warnings
✅ Debug logs show clean FSM transitions
✅ No duplicate flags or state management code

## 📝 Reporting Issues

If you encounter issues, note:
1. Current state before issue
2. Input/event that triggered issue
3. Expected vs actual behavior
4. Console errors/warnings
5. Debug log output

Good luck testing! 🚀
