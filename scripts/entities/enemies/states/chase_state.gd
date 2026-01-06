# scripts/entities/enemies/states/chase_state.gd
# Состояние преследования - враг бежит за целью

class_name ChaseState
extends EnemyState

func enter() -> void:
	brain.enemy.play_animation("chase")

func update(delta: float) -> void:
	# Проверяем наличие цели
	if not brain.current_target or not is_instance_valid(brain.current_target):
		brain.change_state("idle")
		return
	
	# Проверяем жива ли цель
	if brain.current_target.get("is_alive") and not brain.current_target.is_alive:
		brain.current_target = null
		brain.change_state("idle")
		return
	
	var distance = brain.enemy.global_position.distance_to(brain.current_target.global_position)
	
	# Проверяем дистанцию для атаки
	var attack_range = brain.behavior_data.get("attack_range", 50.0)
	if distance <= attack_range and brain.can_attack():
		brain.change_state("attack")
		return
	
	# Проверяем дистанцию потери цели
	var lose_range = brain.behavior_data.get("lose_range", 300.0)
	if distance > lose_range:
		brain.current_target = null
		brain.change_state("idle")
		return
	
	# Проверяем порог зова помощи
	if not brain.has_called_help:
		var hp_ratio = float(brain.enemy.health) / float(brain.enemy.max_health)
		var call_threshold = brain.behavior_data.get("call_help_threshold", 0.3)
		if hp_ratio <= call_threshold:
			brain.change_state("call_help")
			return

func physics_update(delta: float) -> void:
	if not brain.current_target or not is_instance_valid(brain.current_target):
		return
	
	# Движение к цели
	var direction = (brain.current_target.global_position - brain.enemy.global_position).normalized()
	brain.enemy.velocity = direction * brain.enemy.speed
	
	# Поворачиваем врага (флипаем спрайт и зоны)
	brain.enemy.face_direction(direction)
	
	brain.enemy.move_and_slide()

func on_damage_taken(amount: int, attacker: Node = null) -> void:
	# Обновляем цель если атаковал кто-то другой
	if attacker and brain.is_hostile_target(attacker):
		brain.current_target = attacker
