# scripts/entities/enemies/states/stunned_state.gd
# Состояние оглушения - враг не может действовать

class_name StunnedState
extends EnemyState

func enter() -> void:
	brain.enemy.play_animation("take_hit")
	brain.enemy.velocity = Vector2.ZERO

func update(delta: float) -> void:
	# Проверяем истёк ли стан
	if brain.stun_timer <= 0.0:
		# Проверяем цель на валидность и жизнь
		if brain.current_target and is_instance_valid(brain.current_target):
			if brain.current_target.has("is_alive") and brain.current_target.is_alive:
				brain.change_state("chase")
				return
		
		# Если цели нет или она мертва - в idle
		brain.change_state("idle")

func on_damage_taken(amount: int, attacker: Node = null) -> void:
	# Обновляем цель, но остаёмся в стане
	if attacker and brain.is_hostile_target(attacker):
		brain.current_target = attacker
