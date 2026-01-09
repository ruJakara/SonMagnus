# scripts/entities/enemies/states/idle_state.gd
# Состояние бездействия - враг стоит и смотрит по сторонам

class_name IdleState
extends EnemyState

func enter() -> void:
	brain.enemy.play_animation("idle")
	brain.enemy.velocity = Vector2.ZERO

func update(delta: float) -> void:
	# Проверяем конус обзора
	var target = brain.detect_target_in_cone()
	if target:
		brain.current_target = target
		brain.emit_signal("target_detected", target)
		brain.change_state("chase")
		return

func on_damage_taken(amount: int, attacker: Node = null, from_back: bool = false) -> void:
	# При получении урона сразу переходим в атаку, если атакующий близко
	if attacker and brain.is_hostile_target(attacker):
		brain.current_target = attacker
		
		# Если удар в спину — оглушение
		if from_back:
			brain.stun(1.0)
			return
		
		# Если враг в зоне атаки — сразу в attack
		var distance = brain.enemy.global_position.distance_to(attacker.global_position)
		var attack_range = brain.behavior_data.get("attack_range", 50.0)
		
		if distance <= attack_range and brain.can_attack():
			brain.change_state("attack")
		else:
			brain.change_state("chase")
