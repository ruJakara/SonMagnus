# Примеры использования системы врагов

## Пример 1: Создание простого врага

### Шаг 1: JSON данные
```json
// data/enemies/slime.json
{
  "id": "slime_green",
  "name": "Зелёный слайм",
  "max_health": 30,
  "stamina": 50,
  "attack": 5.0,
  "defense": 1.0,
  "speed": 80.0,
  
  "behavior": {
    "ai_type": "idle",
    "vision_cone_angle": 360.0,
    "vision_range": 150.0,
    "lose_range": 250.0,
    "attack_range": 40.0
  },
  
  "combat": {
    "combo_id": "enemy_basic",
    "attack_cooldown": 2.0,
    "backstab_damage_mult": 1.0,
    "backstab_stun_duration": 0.0
  },
  
  "hostility": {
    "hostile_tags": ["player"],
    "hostile_groups": ["player"],
    "faction": "monster"
  },
  
  "loot": {
    "loot_table_id": "slime_common",
    "can_be_looted": true
  },
  
  "tags": ["slime", "monster"],
  
  "animations": {
    "idle": "idle",
    "patrol": "idle",
    "chase": "move",
    "attack": "attack",
    "death": "death",
    "take_hit": "hit"
  }
}
```

### Шаг 2: Сцена врага
```gdscript
# scenes/enemies/slime_green.gd
extends EnemyBase

func _ready() -> void:
    load_from_json("res://data/enemies/slime.json")
    add_to_group("enemies")
    add_to_group("monsters")
    super._ready()
```

### Шаг 3: Настройка анимаций
В Godot Editor:
1. Открыть `scenes/enemies/EnemyBase.tscn`
2. Дублировать как `slime_green.tscn`
3. Прикрепить скрипт `slime_green.gd`
4. Настроить AnimatedSprite2D с анимациями слайма
5. Сохранить

**Готово!** Враг работает со всеми состояниями.

---

## Пример 2: Босс с особой механикой

### JSON с фазами
```json
// data/enemies/boss_orc.json
{
  "id": "boss_orc",
  "name": "Вождь орков",
  "max_health": 500,
  "attack": 25.0,
  "speed": 100.0,
  
  "behavior": {
    "ai_type": "patrol",
    "vision_cone_angle": 180.0,
    "vision_range": 300.0,
    "attack_range": 60.0,
    "call_help_threshold": 0.5
  },
  
  "combat": {
    "combo_id": "boss_slam",
    "attack_cooldown": 1.0
  },
  
  "custom": {
    "phase_2_threshold": 0.5,
    "enrage_threshold": 0.2
  }
}
```

### Скрипт с кастомной логикой
```gdscript
# scenes/enemies/boss_orc.gd
extends EnemyBase

var _phase: int = 1

func _ready() -> void:
    load_from_json("res://data/enemies/boss_orc.json")
    add_to_group("bosses")
    health_changed.connect(_on_health_changed)
    super._ready()

func _on_health_changed(new_hp: int, max_hp: int) -> void:
    var hp_ratio = float(new_hp) / float(max_hp)
    
    # Фаза 2: ускоряется
    if hp_ratio <= 0.5 and _phase == 1:
        _phase = 2
        speed *= 1.5
        combat_data["attack_cooldown"] = 0.7
        play_animation("roar")
        print("БОСС ВОШЁЛ В ФАЗУ 2!")
    
    # Энрейдж: бьёт сильнее
    if hp_ratio <= 0.2 and _phase == 2:
        _phase = 3
        attack *= 1.5
        play_animation("enrage")
        print("БОСС В ЯРОСТИ!")
```

---

## Пример 3: Летающий враг

### JSON с особым поведением
```json
{
  "id": "bat",
  "name": "Летучая мышь",
  "behavior": {
    "ai_type": "patrol",
    "flying": true,
    "patrol_pause_min": 0.5,
    "patrol_pause_max": 1.0
  }
}
```

### Кастомное состояние патруля
```gdscript
# scripts/entities/enemies/states/flying_patrol_state.gd
class_name FlyingPatrolState
extends PatrolState

func _choose_new_target() -> void:
    # Патрулирует в 3D пространстве (x, y)
    var dist = randf_range(100.0, 200.0)
    var angle = randf_range(0, TAU)
    _target_position = brain.enemy.global_position + Vector2(cos(angle), sin(angle)) * dist
    
    # Случайная высота
    _target_position.y += randf_range(-50.0, 50.0)
```

Зарегистрировать в Brain:
```gdscript
if behavior_data.get("flying", false):
    _add_state("patrol", FlyingPatrolState.new())
else:
    _add_state("patrol", PatrolState.new())
```

---

## Пример 4: Система подкрепления

### Логика зова помощи
```gdscript
# В main.gd или EnemyManager
func _ready() -> void:
    # Подписываемся на все зовы помощи
    get_tree().call_group("enemies", "connect", "help_called", _on_enemy_help_called)

func _on_enemy_help_called(position: Vector2, caller: Node) -> void:
    var allies = get_tree().get_nodes_in_group("enemies")
    
    for ally in allies:
        if not ally.is_alive or ally == caller:
            continue
        
        var distance = ally.global_position.distance_to(position)
        var help_radius = caller.behavior_data.get("call_help_radius", 300.0)
        
        # Если союзник рядом - он тоже атакует
        if distance <= help_radius:
            ally.brain.current_target = caller.brain.current_target
            ally.brain.change_state("chase")
```

---

## Пример 5: Спящий стражник

### JSON с начальным состоянием
```json
{
  "id": "guard_sleeping",
  "name": "Спящий стражник",
  "behavior": {
    "ai_type": "sleep"
  },
  "combat": {
    "sleeping_damage_mult": 3.0,
    "sleeping_stun_duration": 3.0
  }
}
```

Враг будет спать пока не получит урон. Первый удар даст х3 урон + 3 сек стан!

---

## Пример 6: Интеграция с квестами

### Отслеживание убийств врагов
```gdscript
# В квест-системе
func _on_enemy_died(enemy: Node) -> void:
    if enemy.has_meta("quest_target"):
        var quest_id = enemy.get_meta("quest_target")
        QuestManager.increment_objective(quest_id, "kill_goblins")
```

### Установка квестового врага
```gdscript
var goblin = preload("res://scenes/enemies/goblin_scout.tscn").instantiate()
goblin.set_meta("quest_target", "quest_goblin_hunt")
goblin.died.connect(_on_enemy_died.bind(goblin))
get_parent().add_child(goblin)
```

---

## Пример 7: Дроп особого предмета

### JSON с гарантированным лутом
```json
{
  "id": "goblin_king",
  "loot": {
    "loot_table_id": "goblin_king_loot",
    "can_be_looted": true
  }
}
```

### Таблица лута босса
```json
// data/loot_tables/goblin_king_loot.json
{
  "id": "goblin_king_loot",
  "items": [
    {
      "item_id": "goblin_crown",
      "min_amount": 1,
      "max_amount": 1,
      "drop_chance": 1.0
    },
    {
      "item_id": "boss_chest_key",
      "min_amount": 1,
      "max_amount": 1,
      "drop_chance": 1.0
    },
    {
      "item_id": "rare_weapon",
      "min_amount": 1,
      "max_amount": 1,
      "drop_chance": 0.3
    }
  ]
}
```

---

## Советы по балансировке

### Скорость
- **Медленный враг**: 60-80 (танк, тяжёлый)
- **Средний враг**: 100-120 (стандарт)
- **Быстрый враг**: 140-180 (ассасин, зверь)

### HP
- **Слабый**: 20-40
- **Средний**: 50-80
- **Сильный**: 100-150
- **Босс**: 300-1000

### Дистанции обзора
- **vision_range**: 150-250 (чтобы не видел через всю карту)
- **lose_range**: vision_range × 1.5-2.0
- **attack_range**: 40-60 (ближний бой)

### Углы обзора
- **360°**: для существ без глаз (слаймы, големы)
- **180°**: для людей, орков (широкое зрение)
- **120°**: для осторожных врагов
- **60°**: для очень сфокусированных

### Cooldown атаки
- **Быстрый**: 0.5-1.0 сек
- **Средний**: 1.5-2.0 сек
- **Медленный**: 2.5-3.5 сек (но больше урона)


