# scripts/entities/enemies/states/sleep_state.gd
# Состояние сна - враг спит и не реагирует на окружение

class_name SleepState
extends EnemyState

func enter() -> void:
	brain.enemy.play_animation("sleep")
	brain.enemy.velocity = Vector2.ZERO

func update(delta: float) -> void:
	# В состоянии сна не проверяем обзор
	pass

func on_damage_taken(amount: int, attacker: Node = null, from_back: bool = false) -> void:
	# Просыпаемся от урона!
	if attacker and brain.is_hostile_target(attacker):
		brain.current_target = attacker
		brain.change_state("chase")
		
		if Config.DEBUG_LOGS:
			print_debug("[SleepState] %s проснулся от атаки!" % brain.enemy.entity_name)
