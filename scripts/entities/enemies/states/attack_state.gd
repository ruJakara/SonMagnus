# scripts/entities/enemies/states/attack_state.gd
# Состояние атаки - проигрывает анимацию и наносит урон через CombatManager

class_name AttackState
extends EnemyState

var _is_attacking: bool = false

func enter() -> void:
	_is_attacking = true
	brain.enemy.velocity = Vector2.ZERO
	brain.enemy.play_animation("attack")
	brain.start_attack()
	
	# Ждём сигнал от AnimationPlayer (через method track)
	# Метод _on_attack_frame будет вызван из анимации

func exit() -> void:
	_is_attacking = false
	if brain.attack_area:
		brain.attack_area.monitoring = false

func update(_delta: float) -> void:
	# Проверяем завершилась ли анимация
	if not _is_attacking:
		# Проверяем нужно ли продолжить преследование
		if brain.current_target and is_instance_valid(brain.current_target):
			var distance = brain.enemy.global_position.distance_to(brain.current_target.global_position)
			var attack_range = brain.behavior_data.get("attack_range", 50.0)
			
			if distance <= attack_range:
				# Остаёмся в атаке, но ждём кулдауна
				if brain.can_attack():
					brain.change_state("attack")
			else:
				brain.change_state("chase")
		else:
			brain.change_state("idle")

## Вызывается из AnimationPlayer на нужном кадре (method track)
func _on_attack_frame() -> void:
	if not brain.attack_area:
		return
	
	# Активируем зону атаки
	brain.attack_area.monitoring = true
	
	# Ждём физический кадр
	await brain.get_tree().physics_frame
	
	# ПРОВЕРКА: всё ещё в AttackState?
	if brain.current_state != self:
		brain.attack_area.monitoring = false
		return
	
	# Получаем цели из зоны
	var targets = brain.attack_area.get_overlapping_bodies()
	
	# Фильтруем враждебные цели
	var weapon_data = {
		"base_damage": brain.enemy.attack,
		"crit_chance": brain.enemy.get("crit_chance", 0.05)
	}
	
	for target in targets:
		if brain.is_hostile_target(target):
			# Используем CombatManager
			var combo_id = brain.combat_data.get("combo_id", "enemy_basic")
			CombatManager.execute_sequence(
				brain.enemy,
				target,
				combo_id,
				weapon_data
			)
	
	# Деактивируем зону
	brain.attack_area.monitoring = false

## Вызывается из AnimationPlayer в конце анимации (method track)
func _on_attack_end() -> void:
	_is_attacking = false

func on_damage_taken(_amount: int, attacker: Node = null) -> void:
	# Можем прервать атаку если получили сильный урон
	if attacker and brain.is_hostile_target(attacker):
		brain.current_target = attacker
