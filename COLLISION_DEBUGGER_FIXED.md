# ✅ CollisionDebugger.gd исправлен

## Проблема
Код использовал десятичные номера слоёв (1-8), а Godot использует **степени двойки** (битовые маски).

## Исправления

### 1. ✅ LAYER_NAMES - исправлены ключи словаря

**Было:**
```gdscript
const LAYER_NAMES: Dictionary = {
	1: "world",
	2: "player_body",
	3: "player_hurtbox",  # ❌ Неправильно!
	4: "player_hitbox",   # ❌ Неправильно!
	5: "enemy_body",      # ❌ Неправильно!
	6: "enemy_hurtbox",   # ❌ Неправильно!
	7: "enemy_attack",    # ❌ Неправильно!
	8: "enemy_back",      # ❌ Неправильно!
	9: "triggers"         # ❌ Неправильно!
}
```

**Стало:**
```gdscript
const LAYER_NAMES: Dictionary = {
	1: "world",              # Layer 1 = 2^0 = 1
	2: "player_body",        # Layer 2 = 2^1 = 2
	4: "player_hurtbox",     # Layer 3 = 2^2 = 4
	8: "player_hitbox",      # Layer 4 = 2^3 = 8
	16: "enemy_body",        # Layer 5 = 2^4 = 16
	32: "enemy_hurtbox",     # Layer 6 = 2^5 = 32
	64: "enemy_attack",      # Layer 7 = 2^6 = 64
	128: "enemy_back",       # Layer 8 = 2^7 = 128
	256: "triggers"          # Layer 9 = 2^8 = 256
}
```

---

### 2. ✅ Player Hitbox - исправлены проверки

**Было:**
```gdscript
var expected_layer = 4   # ❌ Неправильно!
var expected_mask = 14   # ❌ Неправильно!
```

**Стало:**
```gdscript
var expected_layer = 8    # Layer 4 (player_hitbox) = 2^3 = 8
var expected_mask = 160   # Layer 6 (32) + Layer 8 (128) = 160
```

**Объяснение:**
- `expected_mask = 32 + 128 = 160` — Hitbox игрока должен "видеть" enemy_hurtbox (32) и enemy_back (128)

---

### 3. ✅ Player Hurtbox - исправлены проверки

**Было:**
```gdscript
var expected_layer = 3   # ❌ Неправильно!
var expected_mask = 7    # ❌ Неправильно!
```

**Стало:**
```gdscript
var expected_layer = 4   # Layer 3 (player_hurtbox) = 2^2 = 4
var expected_mask = 64   # Layer 7 (enemy_attack) = 2^6 = 64
```

---

### 4. ✅ Enemy Hurtbox - исправлена проверка

**Было:**
```gdscript
if hurtbox.collision_layer != 6:  # ❌ Неправильно!
```

**Стало:**
```gdscript
if hurtbox.collision_layer != 32:  # Layer 6 = 2^5 = 32
```

---

### 5. ✅ Enemy Attack - исправлены проверки

**Было:**
```gdscript
if attack.collision_layer != 7:  # ❌ Неправильно!
if attack.collision_mask != 3:   # ❌ Неправильно!
```

**Стало:**
```gdscript
if attack.collision_layer != 64:  # Layer 7 = 2^6 = 64
if attack.collision_mask != 4:    # Layer 3 (player_hurtbox) = 2^2 = 4
```

---

### 6. ✅ Enemy Back - исправлена проверка

**Было:**
```gdscript
if back.collision_layer != 8:  # ❌ Неправильно!
```

**Стало:**
```gdscript
if back.collision_layer != 128:  # Layer 8 = 2^7 = 128
```

---

## Таблица соответствия

| Номер слоя | Степень двойки | Десятичное значение | Назначение |
|------------|----------------|---------------------|------------|
| Layer 1 | 2^0 | 1 | World |
| Layer 2 | 2^1 | 2 | Player Body |
| Layer 3 | 2^2 | **4** | Player Hurtbox |
| Layer 4 | 2^3 | **8** | Player Hitbox |
| Layer 5 | 2^4 | **16** | Enemy Body |
| Layer 6 | 2^5 | **32** | Enemy Hurtbox |
| Layer 7 | 2^6 | **64** | Enemy Attack |
| Layer 8 | 2^7 | **128** | Enemy Back |
| Layer 9 | 2^8 | **256** | Triggers |

---

## Правильные значения для настройки

### Player Hitbox (зона атаки игрока)
```
collision_layer = 8        # Layer 4
collision_mask = 160       # Layers 6 + 8 (32 + 128)
monitoring = true
monitorable = true
```

### Player Hurtbox (зона получения урона игрока)
```
collision_layer = 4        # Layer 3
collision_mask = 64        # Layer 7
monitoring = false
monitorable = true
```

### Enemy Hurtbox (зона получения урона врага)
```
collision_layer = 32       # Layer 6
collision_mask = 0
monitoring = false
monitorable = true
```

### Enemy Attack (зона атаки врага)
```
collision_layer = 64       # Layer 7
collision_mask = 4         # Layer 3
monitoring = true
monitorable = false
```

### Enemy Back (зона бэкстаба)
```
collision_layer = 128      # Layer 8
collision_mask = 0
monitoring = false
monitorable = true
```

---

## Почему степени двойки?

Godot использует битовые маски для проверки коллизий:
- `collision_layer` — на каком слое находится объект
- `collision_mask` — какие слои объект "видит"

**Проверка пересечения:**
```gdscript
if (object_A.collision_mask & object_B.collision_layer) != 0:
    # Объекты могут взаимодействовать
```

Поэтому каждый слой — это **отдельный бит**:
- Layer 1 = `00000001` = 1
- Layer 2 = `00000010` = 2
- Layer 3 = `00000100` = 4
- Layer 4 = `00001000` = 8
- И т.д.

---

## Пример расчёта Mask

Если Hitbox игрока должен "видеть" Enemy Hurtbox (Layer 6) и Enemy Back (Layer 8):

```
Enemy Hurtbox = Layer 6 = 2^5 = 32  = 00100000
Enemy Back    = Layer 8 = 2^7 = 128 = 10000000
────────────────────────────────────────────────
Mask = 32 + 128 = 160               = 10100000
```

При проверке:
```gdscript
# Hitbox.mask = 160 (10100000)
# Hurtbox.layer = 32 (00100000)
# 160 & 32 = 32 (не 0) → пересечение есть! ✅

# Hitbox.mask = 160 (10100000)
# Back.layer = 128 (10000000)
# 160 & 128 = 128 (не 0) → пересечение есть! ✅
```

---

## Статус

✅ **CollisionDebugger.gd полностью исправлен**  
✅ **Все проверки используют правильные степени двойки**  
✅ **Нет ошибок линтера**  
✅ **Debug логи будут корректно показывать проблемы**

Теперь отладчик коллизий работает правильно! 🎯

