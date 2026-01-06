# Система врагов

## Архитектура

Система врагов реализована на основе паттерна **State Machine** с полной загрузкой данных из JSON.

### Основные компоненты

#### 1. EnemyBase (extends BaseEntity)
Базовый класс для всех врагов, отвечает за:
- Загрузку данных из JSON (`load_from_json()`)
- Управление анимациями
- Обработку урона (с поддержкой бэкстаба и удара по спящему)
- Визуальные эффекты (блинк, толчок)
- Спавн лута при смерти

#### 2. EnemyBrain (компонент)
Управляет AI и state machine:
- Переключение состояний
- Обнаружение целей (конус обзора)
- Проверка враждебности
- Зов на помощь

#### 3. EnemyState (базовый класс для состояний)
Все состояния наследуются от этого класса:
- `enter()`, `exit()` - вход/выход из состояния
- `update(delta)` - обновление каждый кадр
- `physics_update(delta)` - физическое обновление
- `on_damage_taken()` - реакция на урон

### Состояния

| Состояние | Описание | Переходы |
|-----------|----------|----------|
| **idle** | Стоит на месте | → patrol, chase |
| **patrol** | Случайное патрулирование | → chase |
| **chase** | Преследование цели | → attack, idle, call_help |
| **attack** | Атака через CombatManager | → chase, idle |
| **sleep** | Спит (не реагирует на обзор) | → chase (от урона) |
| **stunned** | Оглушён | → chase, idle |
| **call_help** | Зовёт подкрепление | → chase, idle |
| **dead** | Мёртв | (финальное) |

## Создание нового врага

### 1. Создайте JSON файл
```json
// data/enemies/wolf.json
{
  "id": "wolf",
  "name": "Лесной волк",
  "max_health": 40,
  "speed": 150.0,
  "attack": 12.0,
  "behavior": {
    "ai_type": "patrol",
    "vision_cone_angle": 140.0,
    "vision_range": 200.0,
    "attack_range": 40.0
  },
  "hostility": {
    "hostile_tags": ["player"],
    "faction": "animal"
  },
  "loot": {
    "loot_table_id": "wolf_common"
  },
  "animations": {
    "idle": "idle",
    "patrol": "run",
    "chase": "run",
    "attack": "bite",
    "death": "death"
  }
}
```

### 2. Создайте сцену врага
```gdscript
# scenes/enemies/wolf.gd
extends EnemyBase

func _ready() -> void:
    load_from_json("res://data/enemies/wolf.json")
    add_to_group("enemies")
    add_to_group("animals")
    super._ready()
```

### 3. Настройте AnimatedSprite2D
- Добавьте все анимации из JSON (idle, run, attack, death, take hit)
- Настройте скорости анимаций

### 4. (Опционально) Добавьте method tracks в AnimationPlayer
Для атаки:
- На кадре удара: вызов `EnemyBrain._on_attack_frame()`
- В конце анимации: вызов `EnemyBrain._on_attack_end()`

**Готово!** Враг автоматически использует все состояния без изменения кода.

## Collision Layers (текущая конфигурация)

| Слой | Название | Назначение |
|------|----------|------------|
| 1 | World | Стены, пол |
| 2 | Player Body | Тело игрока |
| 3 | (не используется) | |
| 4 | Enemy Body | Тело врага |
| 5 | (player mask) | |
| 16 | Player/Enemy Hurtbox | Зона получения урона |
| 32 | Enemy Back | Зона бэкстаба |

**Настройка EnemyBase:**
- Body: layer 4, mask 3 (видит World + Player)
- Hurtbox: layer 16, mask 0 (видна атакующим)
- Attack: layer 0, mask 16 (атакует Hurtbox'ы)
- Back: layer 32, mask 0 (видна атакующим для бэкстаба)

## Система лута

### Создание таблицы лута
```json
// data/loot_tables/wolf_common.json
{
  "id": "wolf_common",
  "items": [
    {
      "item_id": "wolf_pelt",
      "min_amount": 1,
      "max_amount": 1,
      "drop_chance": 0.8
    },
    {
      "item_id": "raw_meat",
      "min_amount": 1,
      "max_amount": 3,
      "drop_chance": 1.0
    }
  ]
}
```

LootManager автоматически загружает все таблицы из `data/loot_tables/`.

## Интеграция с боевой системой

Враги используют `CombatManager.execute_sequence()` для атак:
- Комбо из `data/combos/`
- Поддержка критов, эффектов, урона
- Бэкстаб даёт х2 урон + стан
- Удар по спящему даёт х2.5 урон + стан

## Добавление нового состояния

```gdscript
# scripts/entities/enemies/states/flee_state.gd
class_name FleeState
extends EnemyState

func enter() -> void:
    brain.enemy.play_animation("run")

func update(delta: float) -> void:
    if not brain.current_target:
        brain.change_state("idle")
        return
    
    var direction = (brain.enemy.global_position - brain.current_target.global_position).normalized()
    brain.enemy.velocity = direction * brain.enemy.speed * 1.5
    brain.enemy.move_and_slide()
    
    var dist = brain.enemy.global_position.distance_to(brain.current_target.global_position)
    if dist > brain.behavior_data.lose_range:
        brain.change_state("idle")
```

Зарегистрируйте в `EnemyBrain._register_states()`:
```gdscript
_add_state("flee", preload("res://scripts/entities/enemies/states/flee_state.gd").new())
```

## Тестирование

Запустите `scenes/test_enemy.tscn` для проверки врагов.

## Debug

Включите `Config.DEBUG_LOGS = true` для логов:
- Переключение состояний
- Обнаружение целей
- Атаки и урон
- Спавн лута

