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
	var combo_id: String = ""
	var combo_data: Dictionary = {}
	var weapon_data: Dictionary = {}
	var flags: Dictionary = {}
	var meta: Dictionary = {}

class AttackRequest:
	var attacker
	var defender
	var combo_id: String = ""
	var combo_data: Dictionary = {}
	var weapon_data: Dictionary = {}
	var flags: Dictionary = {}
	var meta: Dictionary = {}

func _ready() -> void:
	if not has_node("/root/ComboManager"):
		push_warning("[CombatManager] ComboManager не найден в /root")
	if not has_node("/root/EffectManager"):
		push_warning("[CombatManager] EffectManager не найден в /root")


func build_attack_request(attacker, combo_id: String, weapon_data: Dictionary, flags: Dictionary = {}, meta: Dictionary = {}) -> AttackRequest:
	if attacker == null:
		return null
	if not ComboManager.has_combo(combo_id):
		push_warning("[CombatManager] Комбо %s не найдено" % combo_id)
		return null
	
	var request := AttackRequest.new()
	request.attacker = attacker
	request.combo_id = combo_id
	request.combo_data = ComboManager.get_combo(combo_id).duplicate(true)
	request.weapon_data = weapon_data.duplicate(true)
	request.flags = flags.duplicate(true)
	request.meta = meta.duplicate(true)
	return request


func clone_attack_request(request: AttackRequest) -> AttackRequest:
	if request == null:
		return null
	var clone := AttackRequest.new()
	clone.attacker = request.attacker
	clone.defender = request.defender
	clone.combo_id = request.combo_id
	clone.combo_data = request.combo_data.duplicate(true)
	clone.weapon_data = request.weapon_data.duplicate(true)
	clone.flags = request.flags.duplicate(true)
	clone.meta = request.meta.duplicate(true)
	return clone


func validate_attack_request(request: AttackRequest, ignore_cost_override: bool = false) -> bool:
	if request == null or request.attacker == null:
		return false
	if request.combo_id.is_empty():
		return false
	if request.combo_data.is_empty():
		if not ComboManager.has_combo(request.combo_id):
			return false
		request.combo_data = ComboManager.get_combo(request.combo_id).duplicate(true)
	
	var skip_cost = ignore_cost_override or request.flags.get("ignore_cost", false)
	return is_combo_available(request.attacker, request.combo_id, skip_cost)


func execute_request(request: AttackRequest) -> AttackResult:
	var result := AttackResult.new()
	if request == null:
		return result
	
	if not request.flags.get("skip_validation", false):
		if not validate_attack_request(request):
			if Config.DEBUG_LOGS:
				print("[CombatManager] Request for %s отклонён" % request.combo_id)
			return result
	
	var ctx := AttackContext.new()
	ctx.attacker = request.attacker
	ctx.defender = request.defender
	ctx.combo_id = request.combo_id
	ctx.combo_data = request.combo_data
	if ctx.combo_data.is_empty() and ComboManager.has_combo(request.combo_id):
		ctx.combo_data = ComboManager.get_combo(request.combo_id).duplicate(true)
	ctx.weapon_data = request.weapon_data
	ctx.flags = request.flags
	ctx.meta = request.meta
	
	var damage_result = calculate_damage(ctx)
	apply_damage(ctx, damage_result)
	
	result.success = ctx.defender != null and damage_result.damage > 0.0
	result.damage = damage_result.damage
	result.effects = damage_result.effects
	result.combo_id = ctx.combo_id
	result.crit = damage_result.crit
	
	if result.success:
		emit_signal("attack_executed", ctx.attacker, ctx.defender, ctx.combo_id, damage_result)
		if result.crit:
			emit_signal("critical_hit", ctx.attacker, ctx.defender, result.damage)
	
	return result

# =============================
# === MAIN EXECUTION CHAIN ====
# =============================
func execute_sequence(attacker, defender, combo_id: String, weapon_data: Dictionary) -> AttackResult:
	var request = build_attack_request(attacker, combo_id, weapon_data)
	if request == null:
		return AttackResult.new()
	request.defender = defender
	return execute_request(request)


# =============================
# === COMBO AVAILABILITY ====
# =============================
func is_combo_available(entity, combo_id: String, ignore_cost: bool = false) -> bool:
	if not ComboManager.has_combo(combo_id):
		return false

	var combo_data = ComboManager.get_combo(combo_id)

	# Проверка стамины
	if not ignore_cost:
		var stamina_cost = combo_data.get("stamina_cost", 0)
		var current_stamina := 0.0
		if entity.has_method("get_stamina"):
			current_stamina = entity.get_stamina()
		else:
			var stamina_val = entity.get("stamina")
			if stamina_val != null:
				current_stamina = float(stamina_val)
		if current_stamina < stamina_cost:
			return false

	# Проверка unlock-статуса
	var unlock_cond = combo_data.get("unlock_condition", {})
	
	# Если нет условий разблокировки — комбо всегда доступно
	if unlock_cond.is_empty():
		return true
	
	# Если есть условия — проверяем по навыкам
	if entity.has_method("has_unlocked_combo"):
		return entity.has_unlocked_combo(combo_id)
	
	# Fallback: проверяем по уровню навыков
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
		var entity_class = entity.get("entity_class")
		if entity_class == null:
			return false
		if not (entity_class in restrictions):
			return false

	return true


# =============================
# === CONTEXT AND DAMAGE  ====
# =============================
func init_attack(attacker, defender, combo_id: String, weapon_data: Dictionary) -> AttackContext:
	var ctx := AttackContext.new()
	ctx.attacker = attacker
	ctx.defender = defender
	ctx.combo_id = combo_id
	ctx.combo_data = ComboManager.get_combo(combo_id)
	ctx.weapon_data = weapon_data
	ctx.flags = {}
	ctx.meta = {}
	return ctx


func calculate_damage(ctx: AttackContext) -> Dictionary:
	var result := {
		"damage": 0.0,
		"effects": [],
		"crit": false
	}

	var weapon_data = ctx.weapon_data if ctx.weapon_data else {}
	var combo_data = ctx.combo_data if ctx.combo_data else {}
	var base_damage = weapon_data.get("base_damage", 10.0)
	var damage_mult = ctx.meta.get("damage_mult_override", combo_data.get("damage_mult", 1.0))
	var crit_chance = weapon_data.get("crit_chance", 0.0)

	# Если используется комбо — учитываем множитель
	if not ctx.combo_id.is_empty():
		result.effects = combo_data.get("effects", []).duplicate()

	if ctx.flags.get("is_backstab", false):
		damage_mult *= combo_data.get("backstab_damage_mult", 1.0)
	
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
# В CombatManager.gd
func apply_damage(ctx: AttackContext, damage_result: Dictionary) -> void:
	# Проверяем, есть ли атакующий и цель
	if not ctx.attacker:
		push_warning("[CombatManager] Контекст атаки: attacker == null.")
		return # Нечем атаковать - выходим

	if not ctx.defender:
		# Цель может быть null, если, например, атака была в воздух
		push_warning("[CombatManager] Контекст атаки: defender == null. Урон не нанесён.")
		# Вместо push_error используем push_warning - это не фатальная ошибка
		# Можно добавить эффект атаки в воздух, если нужно
		# spawn_attack_effect(ctx.attacker.global_position, ctx.attacker.is_facing_left())
		return # Цели нет - выходим

	# Если оба есть, выполняем основную логику
	# Нанесение урона
	if ctx.defender.has_method("take_damage"):
		var method_argc = ctx.defender.get_method_argument_count("take_damage")
		var args: Array = []
		if method_argc >= 1:
			args.append(int(round(damage_result.damage)))
		if method_argc >= 2:
			args.append(ctx.attacker)
		if method_argc >= 3:
			args.append(ctx.flags.get("is_backstab", false))
		ctx.defender.callv("take_damage", args)
	else:
		push_warning("[CombatManager] Цель %s не имеет метода take_damage()" % ctx.defender.name)

	# Применение эффектов
	for eff in damage_result.effects:
		if ctx.defender.has_method("apply_status_effect"):
			ctx.defender.apply_status_effect(eff)
			emit_signal("effect_applied", ctx.defender, eff)
		else:
			push_warning("[CombatManager] Цель %s не имеет метода apply_status_effect()" % ctx.defender.name)

	# Списание стамины у атакующего (только если атака успешна)
	var cost = ctx.combo_data.get("stamina_cost", 0)
	if cost > 0 and not ctx.flags.get("skip_cost", false):
		if ctx.attacker.has_method("reduce_stamina"):
			ctx.attacker.reduce_stamina(cost)
		elif ctx.attacker.has("stamina"):
			ctx.attacker.stamina -= cost

	# Отладочный вывод
	if Config.DEBUG_LOGS:
		var attacker_name = ctx.attacker.name if ctx.attacker is Node else str(ctx.attacker)
		var defender_name = ctx.defender.name if ctx.defender is Node else str(ctx.defender)
		print("[CombatManager] %s → %s | %.1f dmg%s" % [
			attacker_name,
			defender_name,
			damage_result.damage,
			" [CRIT]" if damage_result.crit else ""
		])
