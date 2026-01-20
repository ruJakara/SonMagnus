# Исправления и Инструкции

## Исправленные проблемы ✅

### 1. Ошибка "keys() на Array" - ИСПРАВЛЕНО
**Проблема**: `ComboManager.get_all_combos()` возвращает Array (список ID), а не Dictionary  
**Решение**: Изменили код в `hud.gd` на использование `get_combos_for_weapon(weapon_type)`

### 2. Дублирующиеся HUD - ИСПРАВЛЕНО
**Проблема**: Были два HUD (hud.gd и player_hud.gd)  
**Решение**: Объединили всё в один `scenes/ui/hud.gd`, удалили дублирующийся player_hud

### 3. Collision layer 5 для Slide - ИСПРАВЛЕНО
**Проблема**: Вы изменили collision layer с 2 на 5  
**Решение**: Обновили `player_slide_state.gd` для использования layer 5

## Что нужно сделать ВРУЧНУЮ

### Шаг 1: Добавить UI элементы в hud.tscn

Откройте `scenes/ui/hud.tscn` в Godot и добавьте:

#### А) PlayerInfoPanel (правый верхний угол)
```
PlayerInfoPanel (Panel)
└── VBox (VBoxContainer)
    ├── StanceLabel (Label) - текст: "Stance: RELAX (Q)"
    ├── StateLabel (Label) - текст: "State: idle"
    └── ComboHintLabel (Label) - текст: "TAB - Show Combos"
```

**Настройки PlayerInfoPanel:**
- Anchor Preset: Top Right
- Размер: примерно 200x100 пикселей
- Modulate Alpha: 0.9 (полупрозрачность)

#### Б) CombosPanel (правая сторона экрана)
```
CombosPanel (Panel)
└── ScrollContainer
    └── VBox (VBoxContainer)
```

**Настройки CombosPanel:**
- Anchor Preset: Center Right
- Размер: примерно 300x400 пикселей
- Visible: ВЫКЛЮЧЕНО (будет показываться по TAB)
- Modulate Alpha: 0.85 (полупрозрачность)

### Шаг 2: Проверить пути в hud.gd

Скрипт ожидает такие пути:
```gdscript
$PlayerInfoPanel/VBox/StanceLabel
$PlayerInfoPanel/VBox/StateLabel
$PlayerInfoPanel/VBox/ComboHintLabel
$CombosPanel/ScrollContainer/VBox
```

### Шаг 3: Запустить игру и проверить

После настройки сцены:
1. Запустите игру
2. Вы увидите в правом верхнем углу:
   - Текущую стойку (RELAX/FIGHT)
   - Текущее состояние FSM (idle/attack/move/...)
   - Подсказку про TAB
3. Нажмите **TAB** - должна появиться панель с комбо

## Функционал HUD

### Основное (всегда видно):
- **Полоски** (верх слева): HP, Mana, Stamina, Hunger
- **Player Info** (верх справа): Stance, State, подсказка TAB
- **Скиллы** (низ): слоты умений и оружия
- **Часы** (верх справа): день/ночь

### По нажатию TAB:
- **Панель комбо**: список всех доступных комбо
  - [UNARMED]: комбо без оружия
  - [WEAPON]: комбо с оружием
  - Формат: "L → R → L: Triple Punch"

## Устранение неполадок

### Ошибка "Invalid get index"
➜ Проверьте структуру сцены, пути должны совпадать с @onready

### Комбо не показываются
➜ Проверьте что:
1. ComboManager загружен (автолоад в project.godot)
2. Файлы комбо есть в `res://data/combos/*.json`

### Player info не обновляется
➜ Проверьте что:
1. Player в группе "player"
2. У Player есть свойства `stance` и `state_machine`

## Файлы изменены

✅ `scenes/ui/hud.gd` - объединённый HUD скрипт  
✅ `scripts/player/states/player_slide_state.gd` - исправлен collision layer 5  
❌ `scenes/ui/player_hud.gd` - УДАЛЁН (дублирующийся)  
❌ `scenes/ui/player_hud.tscn` - УДАЛЁН (дублирующийся)  

## Следующие шаги

После настройки HUD сцены:
1. Тестируйте бой - урон должен проходить
2. Проверьте slide - должен проходить сквозь врагов и завершаться
3. Проверьте stance toggle - должен быть плавным
4. Проверьте TAB - должны показываться все комбо

Если всё работает - FSM рефакторинг завершён! 🎉
