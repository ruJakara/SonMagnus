# scripts/entities/enemies/states/dead_state.gd
# Состояние смерти - финальное состояние

class_name DeadState
extends EnemyState

func enter() -> void:
	# НЕ вызываем _die(), он уже вызван из BaseEntity при health == 0
	# Просто отключаем процессы Brain
	brain.set_process(false)
	brain.set_physics_process(false)

func update(delta: float) -> void:
	# Ничего не делаем, состояние финальное
	pass

func physics_update(delta: float) -> void:
	# Ничего не делаем
	pass

