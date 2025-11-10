# autoload/CombatManager.gd
# Менеджер боя. Отвечает за расчеты урона, выполнение комбо и логику боя.
# Подключается как Autoload с именем "CombatManager".

extends Node

signal attack_executed(attacker, defender, combo_id, result: Dictionary)
signal critical_hit(attacker, defender, damage: float)
signal effect_applied(defender, effect_id: String)

## Структура результата атаки
class AttackResult:
	var success: bool = false
	var damage: float = 0.0
	var effects: Array = []
	var combo_id: String = ""
	var crit: bool = false

## Структура контекста атаки
class AttackContext:
	var attacker
	var defender
	var combo_data: Dictionary = {}
	var weapon_data: Dictionary = {}

# =============================
# === MAIN EXECUTION CHAIN ====
# =============================
func execute_sequence(attacker, defender, combo_id: String, weapon_data: Dictionary) -> AttackResult:
	var result := AttackResult.new()

	if not ComboManager.has_combo(combo_id):
		push_warning("[CombatManager] Комбо %s не найдено" % combo_id)
		return result

	var _combo_data = ComboManager.get_combo(combo_id)

	# Проверка доступности
	if not is_combo_available(attacker, combo_id):
		push_warning("[CombatManager] Комбо %s недоступно для %s" % [combo_id, attacker.name])
		return result

	# Инициализация атаки
	var ctx = init_attack(attacker, defender, combo_id, weapon_data)

	# Расчет урона
	var damage_result = calculate_damage(attacker, defender, weapon_data, combo_id)

	# Применение урона
	apply_damage(ctx, damage_result)

	result.success = true
	result.damage = damage_result.damage
	result.effects = damage_result.effects
	result.combo_id = combo_id
	result.crit = damage_result.crit

	emit_signal("attack_executed", attacker, defender, combo_id, damage_result)
	if result.crit:
		emit_signal("critical_hit", attacker, defender, result.damage)

	return result


# =============================
# === COMBO AVAILABILITY ====
# =============================
func is_combo_available(entity, combo_id: String) -> bool:
	if not ComboManager.has_combo(combo_id):
		return false

	var combo_data = ComboManager.get_combo(combo_id)

	# Проверка стамины
	var stamina_cost = combo_data.get("stamina_cost", 0)
	var current_stamina := 0.0
	if entity.has_method("get_stamina"):
		current_stamina = entity.get_stamina()
	elif entity.has("stamina"):
		current_stamina = float(entity.stamina)
	if current_stamina < stamina_cost:
		return false

	# Проверка unlock-статуса (если есть)
	if entity.has_method("has_unlocked_combo"):
		if not entity.has_unlocked_combo(combo_id):
			# если не разблокировано — проверим, можно ли по условиям
			var unlock_cond = combo_data.get("unlock_condition", {})
			if unlock_cond.size() == 0:
				return false
	else:
		# Без метода — fallback на проверку по навыкам
		var unlock_cond = combo_data.get("unlock_condition", {})
		for skill in unlock_cond.keys():
			var req = unlock_cond[skill]
			var lvl = 0
			if entity.has_method("get_skill_level"):
				lvl = entity.get_skill_level(skill)
			if lvl < req:
				return false

	# Проверка ограничений по классу
	var restrictions = combo_data.get("class_restriction", [])
	if restrictions.size() > 0:
		if not entity.has("entity_class"):
			return false
		if not (entity.entity_class in restrictions):
			return false

	return true


# =============================
# === CONTEXT AND DAMAGE  ====
# =============================
func init_attack(attacker, defender, combo_id: String, weapon_data: Dictionary) -> AttackContext:
	var ctx := AttackContext.new()
	ctx.attacker = attacker
	ctx.defender = defender
	ctx.combo_data = ComboManager.get_combo(combo_id)
	ctx.weapon_data = weapon_data
	return ctx


func calculate_damage(_attacker, _defender, weapon_data: Dictionary, combo_id: String = "") -> Dictionary:
	var result := {
		"damage": 0.0,
		"effects": [],
		"crit": false
	}

	var base_damage = weapon_data.get("base_damage", 10.0)
	var damage_mult = 1.0
	var crit_chance = weapon_data.get("crit_chance", 0.0)

	# Если используется комбо — учитываем множитель
	if combo_id != "":
		var combo_data = ComboManager.get_combo(combo_id)
		damage_mult = combo_data.get("damage_mult", 1.0)
		result.effects = combo_data.get("effects", []).duplicate()

	# Итоговый урон
	var final_damage = base_damage * damage_mult

	# Проверка крита
	if randf() < crit_chance:
		final_damage *= 2.0
		result.crit = true

	result.damage = final_damage
	return result


# =============================
# === APPLY DAMAGE / EFFECTS ==
# =============================
func apply_damage(ctx: AttackContext, damage_result: Dictionary) -> void:
	if not ctx.defender or not ctx.attacker:
		push_error("[CombatManager] Контекст атаки неполный.")
		return

	# Нанесение урона
	if ctx.defender.has_method("take_damage"):
		ctx.defender.take_damage(damage_result.damage)
	else:
		push_warning("[CombatManager] Defender %s не имеет take_damage()" % ctx.defender.name)

	# Применение эффектов
	for eff in damage_result.effects:
		if ctx.defender.has_method("apply_status_effect"):
			ctx.defender.apply_status_effect(eff)
			emit_signal("effect_applied", ctx.defender, eff)
		else:
			push_warning("[CombatManager] %s не имеет apply_status_effect()" % ctx.defender.name)

	# Списание стамины
	var cost = ctx.combo_data.get("stamina_cost", 0)
	if cost > 0:
		if ctx.attacker.has_method("reduce_stamina"):
			ctx.attacker.reduce_stamina(cost)
		elif ctx.attacker.has("stamina"):
			ctx.attacker.stamina -= cost

	print("[CombatManager] %s нанес %.1f урона %s" % [ctx.attacker.name, damage_result.damage, ctx.defender.name])
	if damage_result.crit:
		print("[CombatManager] Критический удар!")
