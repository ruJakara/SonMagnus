# scripts/entities/enemies/states/attack_state.gd
# Состояние атаки - проигрывает анимацию и наносит урон через CombatManager

class_name AttackState
extends EnemyState

var _is_attacking: bool = false
var _hit_frame_fired: bool = false

func _resolve_entity_from_overlap(obj: Node) -> CharacterBody2D:
	# Overlap может вернуть Area2D (например Player.zone/Hurtbox), а нам нужен сам BaseEntity.
	var n: Node = obj
	while n:
		# Важно: нельзя типизировать как BaseEntity здесь, потому что этот скрипт preload-ится
		# раньше регистрации class_name BaseEntity → Parse Error на старте проекта.
		if n is CharacterBody2D:
			return n as CharacterBody2D
		n = n.get_parent()
	return null

func enter() -> void:
	_is_attacking = true
	_hit_frame_fired = false
	brain.enemy.velocity = Vector2.ZERO
	brain.start_attack() # КД начинается при старте атаки, а не зависит от треков в AnimationPlayer
	brain.enemy.play_animation("attack")
	
	# Важно: Attack Area могла быть выключена в exit(), включаем обратно.
	if brain.attack_area:
		brain.attack_area.monitoring = true
	
	if Config.DEBUG_LOGS:
		print("[AttackState] %s начинает атаку" % brain.enemy.entity_name)

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
				# Мы в радиусе удара, но атака уже завершилась.
				# Если сейчас КД не готов — НЕ оставляем последний кадр атаки, а уходим в idle (recovery).
				brain.enemy.velocity = Vector2.ZERO
				var dir = (brain.current_target.global_position - brain.enemy.global_position)
				if dir.length() > 0.001:
					brain.enemy.face_direction(dir)
				brain.enemy.play_animation("idle")
				
				# Остаёмся в атаке, но ждём кулдауна
				if brain.can_attack():
					# Перезапускаем атаку (через change_state для сброса _is_attacking)
					brain.change_state("attack")
			else:
				brain.change_state("chase")
		else:
			brain.change_state("idle")

func on_damage_taken(_amount: int, attacker: Node = null, from_back: bool = false) -> void:
	# Если удар в спину — прерываем атаку и оглушение
	if from_back:
		brain.stun(1.0)
		return
	
	# Обычный урон — обновляем цель
	if attacker and brain.is_hostile_target(attacker):
		brain.current_target = attacker

## Вызывается из AnimationPlayer на нужном кадре (method track)
func _on_attack_frame() -> void:
	if not brain.attack_area:
		return
	if _hit_frame_fired:
		return
	_hit_frame_fired = true
	
	# СРАЗУ проверяем overlapping.
	# Важно: у игрока "hurtbox" — это Area2D, поэтому используем и bodies и areas.
	var overlapped: Array = []
	overlapped.append_array(brain.attack_area.get_overlapping_bodies())
	overlapped.append_array(brain.attack_area.get_overlapping_areas())
	
	if Config.DEBUG_LOGS:
		print("[AttackState] %s _on_attack_frame | overlapped: %d" % [brain.enemy.entity_name, overlapped.size()])
	
	var weapon_data = {
		"base_damage": brain.enemy.attack,
		"crit_chance": brain.enemy.crit_chance
	}
	
	for obj in overlapped:
		var target_entity := _resolve_entity_from_overlap(obj)
		if not target_entity:
			continue
		if target_entity == brain.enemy:
			continue
		
		if brain.is_hostile_target(target_entity):
			var combo_id = brain.combat_data.get("combo_id", "enemy_basic")
			CombatManager.execute_sequence(
				brain.enemy,
				target_entity,
				combo_id,
				weapon_data
			)
			
			if Config.DEBUG_LOGS:
				print("[AttackState] %s ударил %s" % [brain.enemy.entity_name, target_entity.name])

func _on_attack_end() -> void:
	_is_attacking = false
