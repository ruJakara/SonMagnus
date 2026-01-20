# HUD Setup Guide

## Overview
The HUD has been unified into a single system that displays:
- **Status bars**: HP, Mana, Stamina, Hunger (top left)
- **Player info**: Current stance and FSM state (new)
- **Skills bar**: Skills and weapon slots (bottom)
- **Day/Night clock**: Celestial rotation (top right)
- **Combos panel**: Available combos (toggle with TAB)

## Setup Instructions

### 1. Add Player Info Panel to HUD Scene

Open `scenes/ui/hud.tscn` in Godot and add the following nodes:

```
CanvasLayer (root)
├── StatusBars (existing)
├── BottomBar (existing)
├── ClockContainer (existing)
└── PlayerInfoPanel (NEW - Add this)
    └── VBox (NEW - VBoxContainer)
        ├── StanceLabel (NEW - Label)
        ├── StateLabel (NEW - Label)
        └── ComboHintLabel (NEW - Label)
```

**PlayerInfoPanel settings:**
- Type: `Panel`
- Position: Top-right corner (below clock)
- Size: ~200x100 pixels
- Anchor Preset: Top Right
- Modulate: Slightly transparent (e.g., 0.9 alpha)

**VBox settings:**
- Type: `VBoxContainer`
- Layout: Fill parent
- Separation: 5 pixels

**Labels settings:**
- Font Size: 14
- Text Color: White
- Shadow: Enabled (for readability)

### 2. Add Combos Panel

```
CanvasLayer (root)
└── CombosPanel (NEW - Add this)
    └── ScrollContainer (NEW)
        └── VBox (NEW - VBoxContainer)
```

**CombosPanel settings:**
- Type: `Panel`
- Position: Right side of screen
- Size: ~300x400 pixels
- Anchor Preset: Center Right
- Visible: `false` (hidden by default, toggle with TAB)
- Modulate: Semi-transparent (e.g., 0.85 alpha)

**ScrollContainer settings:**
- Type: `ScrollContainer`
- Layout: Fill parent with margins
- Vertical Scroll: Enabled
- Horizontal Scroll: Auto

**VBox (inside ScrollContainer):**
- Type: `VBoxContainer`
- Separation: 3 pixels
- Name: `VBox` (important - script expects this name)

### 3. Update Node References in Script

The script `scenes/ui/hud.gd` expects these exact node paths:

```gdscript
@onready var player_info_panel: Panel = $PlayerInfoPanel
@onready var stance_label: Label = $PlayerInfoPanel/VBox/StanceLabel
@onready var state_label: Label = $PlayerInfoPanel/VBox/StateLabel
@onready var combo_hint_label: Label = $PlayerInfoPanel/VBox/ComboHintLabel

@onready var combos_panel: Panel = $CombosPanel
@onready var combos_list: VBoxContainer = $CombosPanel/ScrollContainer/VBox
```

Make sure your scene structure matches these paths exactly!

### 4. Test the HUD

1. Open your main game scene
2. Make sure `hud.tscn` is instanced (should already be there)
3. Run the game
4. You should see:
   - Stance (RELAX/FIGHT) displayed
   - Current FSM state (idle/attack/move/etc.)
   - "TAB - Show Combos" hint
5. Press **TAB** to toggle the combos panel

## Features

### Player Info Panel
Displays in real-time:
- **Stance**: RELAX or FIGHT (toggle with Q)
- **State**: Current FSM state (idle, attack, move, block, slide, stance_toggle)
- **Hint**: Reminder to press TAB for combos

### Combos Panel (TAB to toggle)
Shows all available combos organized by weapon type:
- **[UNARMED]**: Punch combos
- **[WEAPON]**: Weapon attack combos

Each combo displays:
- Sequence: e.g., "L → L → R"
- Name: e.g., "Triple Punch Combo"

## Troubleshooting

### "Invalid get index" errors
**Problem**: Node paths don't match
**Solution**: Check that your scene structure matches the @onready paths exactly

### Combos not showing
**Problem**: ComboManager not found or no combos loaded
**Solution**: 
1. Check that ComboManager is autoloaded in project settings
2. Verify combo JSON files exist in `res://data/combos/`
3. Enable debug logs to see ComboManager load messages

### Player info not updating
**Problem**: Player reference not found
**Solution**: 
1. Make sure player is in "player" group
2. Check that player has `stance` and `state_machine` properties

### Collision layer 5 error in slide
**Problem**: You modified collision layer from 2 to 5
**Fix applied**: `player_slide_state.gd` now uses layer 5 for enemy collision

## Next Steps

If you want to customize:
- **Colors**: Edit theme colors in scene
- **Position**: Adjust anchors and margins
- **Font**: Override theme font and size
- **Animation**: Add show/hide animations for combos panel

## Related Files

- `scenes/ui/hud.gd` - Main HUD script
- `scenes/ui/hud.tscn` - HUD scene (needs manual setup)
- `scripts/player/states/player_slide_state.gd` - Uses collision layer 5
- `autoload/ComboManager.gd` - Provides combo data
