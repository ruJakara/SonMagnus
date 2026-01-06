# 🎮 Система врагов - Быстрый старт

## ✅ Что реализовано

Полноценная система врагов с **AI**, **state machine**, **системой лута** и интеграцией с боевой системой.

---

## 🚀 Запуск

### 1. Тестовая сцена
Запустите `scenes/test_enemy.tscn` чтобы увидеть работающего гоблина.

### 2. Финальная настройка (2 шага)

#### ✅ Шаг А: Код-правки (ВЫПОЛНЕНО)
Все необходимые правки кода уже применены! См. `APPLIED_FIXES.md`

#### Шаг Б: Добавить method tracks (5 минут, ручная настройка)
1. Открыть `scenes/enemies/EnemyBase.tscn` в Godot Editor
2. Выбрать узел `EnemyBase` (корневой)
3. Открыть `AnimationPlayer` → анимация "attack"
4. Добавить track → Call Method Track → выбрать `EnemyBase` (не Brain!)
5. На кадре удара (~0.2s): добавить вызов `_on_attack_frame()`
6. В конце анимации (~0.5s): добавить вызов `_on_attack_end()`
7. Повторить для "attack2", "call_help"
8. Сохранить сцену

#### Шаг В: Добавить тег игроку (1 строка)
В `scripts/player/player.gd`, в методе `_ready()`:
```gdscript
func _ready() -> void:
    super._ready()
    add_to_group("player")
    tags.append("player")  # ← ДОБАВИТЬ ЭТУ СТРОКУ
    # ... остальной код
```

**После шагов Б и В враги полностью функциональны!**

---

## 📝 Создание нового врага (3 шага)

### 1. JSON файл
```json
// data/enemies/wolf.json
{
  "id": "wolf",
  "name": "Волк",
  "max_health": 40,
  "speed": 150.0,
  "attack": 12.0,
  "behavior": {
    "ai_type": "patrol",
    "vision_range": 200.0,
    "attack_range": 40.0
  },
  "hostility": {
    "hostile_tags": ["player"]
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

### 2. Скрипт врага
```gdscript
# scenes/enemies/wolf.gd
extends EnemyBase

func _ready() -> void:
    load_from_json("res://data/enemies/wolf.json")
    add_to_group("enemies")
    super._ready()
```

### 3. Сцена
1. Дублировать `EnemyBase.tscn` → `wolf.tscn`
2. Прикрепить скрипт `wolf.gd`
3. Настроить AnimatedSprite2D с анимациями волка
4. Сохранить

**Всё!** Волк автоматически патрулирует, преследует, атакует.

---

## 🎯 Возможности

### AI поведение
- ✅ Патрулирование (случайное)
- ✅ Обнаружение игрока (конус обзора)
- ✅ Преследование
- ✅ Атака через CombatManager
- ✅ Зов помощи при низком HP

### Боевая система
- ✅ Бэкстаб: **х2 урон + стан**
- ✅ Удар по спящему: **х2.5 урон + стан**
- ✅ Комбо атаки
- ✅ Статус-эффекты

### Лут
- ✅ Автоматический дроп при смерти
- ✅ Настраиваемые шансы
- ✅ Случайное количество

---

## 📚 Документация

- `docs/enemy_system.md` - полная документация
- `docs/enemy_examples.md` - примеры (босс, летающий враг, квесты)
- `docs/enemy_implementation_report.md` - технический отчёт

---

## 🔧 Параметры врага (JSON)

### Основные
- `max_health` - HP
- `attack` - базовый урон
- `speed` - скорость движения
- `defense` - защита

### Поведение (behavior)
- `ai_type` - "patrol", "idle", "sleep"
- `vision_cone_angle` - угол обзора (60-360°)
- `vision_range` - дистанция обзора
- `attack_range` - дистанция атаки
- `lose_range` - дистанция потери цели

### Враждебность (hostility)
- `hostile_tags` - теги врагов (["player", "animal"])
- `faction` - фракция ("goblin", "animal")

### Лут (loot)
- `loot_table_id` - ID таблицы лута
- `can_be_looted` - можно ли лутать

### Анимации (animations)
- `idle`, `patrol`, `chase`, `attack`, `death`, `take_hit`

---

## 🎮 Состояния

| Состояние | Поведение |
|-----------|-----------|
| **idle** | Стоит, смотрит вокруг |
| **patrol** | Случайно ходит + паузы |
| **sleep** | Спит (просыпается от урона) |
| **chase** | Бежит за целью |
| **attack** | Атакует цель |
| **stunned** | Оглушён |
| **call_help** | Зовёт союзников |
| **dead** | Мёртв (спавн лута) |

---

## 💡 Советы

### Балансировка
- **Медленный танк**: speed 60-80, hp 100+
- **Средний боец**: speed 100-120, hp 50-80
- **Быстрый ассасин**: speed 150+, hp 30-50

### Обзор
- **360°** - слаймы, големы (без глаз)
- **180°** - люди, орки
- **120°** - стандарт
- **60°** - сфокусированные враги

### Дистанции
- `vision_range`: 150-250
- `lose_range`: vision_range × 2
- `attack_range`: 40-60 (ближний бой)

---

## 🐛 Если что-то не работает

1. **Враг не видит игрока**
   - Проверьте что игрок в группе "player" ✅
   - Проверьте `hostile_tags` в JSON
   - Проверьте `vision_cone_angle` и `vision_range`

2. **Враг не атакует**
   - Добавьте method tracks в AnimationPlayer
   - Проверьте `attack_range`

3. **Лут не выпадает**
   - Проверьте что `can_be_looted: true`
   - Проверьте существование таблицы лута
   - Включите `Config.DEBUG_LOGS = true`

---

## 🎉 Готово!

Система полностью работает. Создавайте новых врагов, меняя только JSON!

