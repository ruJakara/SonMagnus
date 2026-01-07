# scripts/entities/enemies/states/call_help_state.gd
# Состояние зова помощи - проигрывает анимацию и эмитит сигнал

class_name CallHelpState
extends EnemyState

var _animation_finished: bool = false

func enter() -> void:
	_animation_finished = false
	brain.enemy.velocity = Vector2.ZERO
	brain.enemy.play_animation("call_help")
	brain.call_for_help()
	
	# CONNECT_ONE_SHOT автоматически отключится после первого срабатывания
	if brain.enemy._sprite:
		brain.enemy._sprite.animation_finished.connect(_on_animation_finished, CONNECT_ONE_SHOT)

func exit() -> void:
	# Не нужно disconnect, CONNECT_ONE_SHOT сам отключится
	pass

func update(delta: float) -> void:
	# После завершения анимации возвращаемся в chase
	if _animation_finished:
		if brain.current_target and is_instance_valid(brain.current_target):
			brain.change_state("chase")
		else:
			brain.change_state("idle")

func _on_animation_finished() -> void:
	_animation_finished = true

func on_damage_taken(_amount: int, attacker: Node = null) -> void:
	# Можем прервать зов помощи и перейти в chase
	if attacker and brain.is_hostile_target(attacker):
		brain.current_target = attacker
		brain.change_state("chase")
