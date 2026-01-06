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

func on_damage_taken(amount: int, attacker: Node = null) -> void:
	# При получении урона переходим в преследование
	if attacker and brain.is_hostile_target(attacker):
		brain.current_target = attacker
		brain.change_state("chase")

