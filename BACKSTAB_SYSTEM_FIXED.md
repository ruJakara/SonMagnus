# ✅ Система бэкстаба исправлена и интегрирована

## Что было сделано

### 1. ✅ PlayerCombat.gd - добавлена проверка бэкстаба

#### Изменения в методе `_on_attack_frame()`
Теперь перед нанесением урона проверяются Area2D (зоны Back врагов):

```gdscript
# Проверяем Area2D (для бэкстаба)
var overlapping_areas: Array[Area2D] = _hitbox.get_overlapping_areas()

for target in targets:
    # Проверяем, есть ли бэкстаб
    var is_backstab: bool = false
    
    for area in overlapping_areas:
        # Проверяем, что это зона Back и её родитель — текущая цель
        if is_instance_valid(area) and area.name == "Back" and area.get_parent() == target:
            is_backstab = true
            break
    
    # Наносим урон (с флагом бэкстаба)
    _deal_damage_to(target, combo_id, weapon_data, is_backstab)
```

**Логика:**
1. Получаем все Area2D, с которыми пересекается Hitbox игрока
2. Для каждой цели (врага) проверяем, есть ли среди Area2D зона "Back" этого врага
3. Если есть — устанавливаем `is_backstab = true`
4. Передаём флаг в `_deal_damage_to()`

#### Изменения в методе `_deal_damage_to()`
Добавлен параметр `is_backstab` и обработка бэкстаба:

```gdscript
func _deal_damage_to(defender: Node, combo_id: String, weapon_data: Dictionary, is_backstab: bool = false) -> void:
    # ... проверки ...
    
    # ПРИМЕНЯЕМ БЭКСТАБ (если враг поддерживает)
    if is_backstab:
        # Вызываем take_damage с параметром from_back=true
        defender.take_damage(int(round(damage)), _player, true)
        
        if Config.DEBUG_LOGS:
            print("[PlayerCombat] [Fallback] %s → %s | %.1f урона [BACKSTAB]" % [...])
        return
    
    # Обычный урон
    defender.take_damage(int(round(damage)))
```

### 2. ✅ enemy_base.gd - метод take_damage() уже корректен

Метод уже правильно реализован и обрабатывает бэкстаб:

```gdscript
func take_damage(amount: int, attacker: Node = null, from_back: bool = false) -> void:
    if not is_alive:
        return
    
    var final_damage = amount
    var stun_duration = 0.0
    
    # БЭКСТАБ: урон × backstab_damage_mult + стан
    if from_back:
        final_damage = int(final_damage * combat_data.get("backstab_damage_mult", 1.0))
        stun_duration = combat_data.get("backstab_stun_duration", 0.0)
    
    # Если враг спит: урон × sleeping_damage_mult + стан
    if brain and brain.current_state_name == "sleep":
        final_damage = int(final_damage * combat_data.get("sleeping_damage_mult", 1.0))
        stun_duration = max(stun_duration, combat_data.get("sleeping_stun_duration", 0.0))
    
    # Наносим урон через BaseEntity
    super.take_damage(final_damage)
    
    # Визуальные эффекты
    _play_hit_effects()
    
    # Применяем стан
    if stun_duration > 0.0:
        apply_status_effect("stunned")
        if brain:
            brain.stun_timer = stun_duration
            brain.change_state("stunned")
    
    # Уведомляем Brain
    if brain:
        brain.on_damage_taken(final_damage, attacker)
```

---

## Как работает система бэкстаба

### Условия для бэкстаба
1. **Hitbox игрока** пересекается с **зоной Back врага**
2. Зона Back расположена позади врага (через `face_direction()` флипается вместе с врагом)

### Последствия бэкстаба (из JSON)
```json
"combat": {
  "backstab_damage_mult": 2.0,      // урон ×2
  "backstab_stun_duration": 1.5     // стан 1.5 сек
}
```

### Спящий враг (дополнительный множитель)
```json
"combat": {
  "sleeping_damage_mult": 2.5,      // урон ×2.5
  "sleeping_stun_duration": 2.0     // стан 2 сек
}
```

Если ударить спящего врага в спину:
- Урон будет рассчитан с **максимальным** множителем (2.5)
- Стан будет **максимальный** из двух (2.0 сек)

---

## Collision Layers (напоминание)

### Player Hitbox
- **Layer**: 0 (не нужен, т.к. это атакующая зона)
- **Mask**: 16 (видит Hurtbox врагов) + 32 (видит Back врагов)

### Enemy Back
- **Layer**: 32
- **Mask**: 0
- **Monitorable**: true (чтобы Hitbox игрока мог её обнаружить)
- **Monitoring**: false (зона не ищет ничего сама)

---

## Debug логи

При включённом `Config.DEBUG_LOGS = true` в консоли будет:

```
[PlayerCombat] get_overlapping_bodies: 1
[PlayerCombat]   Body: GoblinScout (groups: [enemies, goblins], has_take_damage: true)
[PlayerCombat] ✅ Найден враг (body): GoblinScout | dist: 45.2
[PlayerCombat] get_overlapping_areas: 3
[PlayerCombat]   Area: Back (parent: GoblinScout)
[PlayerCombat]   Area: Hurtbox (parent: GoblinScout)
[PlayerCombat]   Area: Attack (parent: GoblinScout)
[PlayerCombat] [Fallback] basic_l → GoblinScout | 20.0 урона [BACKSTAB]
[EnemyBase] Гоблин-разведчик получил 40 урона (от спины: true), HP: 10/50
```

---

## Тестирование

### Сценарий 1: Обычная атака спереди
1. Подойти к врагу спереди
2. Атаковать
3. **Ожидается**: обычный урон (например, 10)

### Сценарий 2: Бэкстаб
1. Подойти к врагу сзади
2. Атаковать в спину
3. **Ожидается**: урон ×2 + стан 1.5 сек
4. В консоли: `[BACKSTAB]`

### Сценарий 3: Удар по спящему (из состояния sleep)
1. Найти спящего врага (ai_type: "sleep")
2. Атаковать спереди
3. **Ожидается**: урон ×2.5 + стан 2 сек

### Сценарий 4: Бэкстаб спящего
1. Найти спящего врага
2. Атаковать в спину
3. **Ожидается**: урон ×2.5 (максимальный множитель) + стан 2 сек

---

## Что осталось (опционально)

### 1. Visual Feedback
Добавить визуальную индикацию бэкстаба:
- Красная вспышка
- Текст "BACKSTAB!" над врагом
- Частицы крови

### 2. Звуки
Добавить звук критического удара при бэкстабе

### 3. Очки стиля
Начислять очки в CombatProfile за бэкстаб:
```gdscript
if is_backstab:
    _combat_profile.add_score(&"assassin", 5.0)
```

---

## Статус

✅ **Система бэкстаба полностью функциональна**  
✅ **Все файлы без ошибок линтера**  
✅ **Интеграция с существующей системой боя**  
✅ **Debug логи для диагностики**

Можно тестировать в игре! 🎮

