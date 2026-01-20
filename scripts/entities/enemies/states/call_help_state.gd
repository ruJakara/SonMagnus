# scripts/entities/enemies/states/call_help_state.gd
# Состояние зова помощи - проигрывает анимацию и эмитит сигнал

class_name CallHelpState
extends EnemyState

var _animation_finished: bool = false
var _expected_anim: String = ""

func enter() -> void:
	_animation_finished = false
	brain.enemy.velocity = Vector2.ZERO
	brain.enemy.play_animation("call_help")
	brain.call_for_help()
	
	# Ждём завершения анимации. Если используем AnimationPlayer — слушаем его,
	# иначе (fallback) слушаем AnimatedSprite2D.
	_expected_anim = brain.enemy.animations.get("call_help", "call_help")
	if brain.enemy.animation_player and brain.enemy.animation_player.has_animation(_expected_anim):
		brain.enemy.animation_player.animation_finished.connect(_on_animation_player_finished, CONNECT_ONE_SHOT)
	elif brain.enemy._sprite:
		brain.enemy._sprite.animation_finished.connect(_on_animation_finished, CONNECT_ONE_SHOT)

func exit() -> void:
	# Не нужно disconnect, CONNECT_ONE_SHOT сам отключится
	pass

func update(delta: float) -> void:
	# После завершения анимации возвращаемся в chase
	if _animation_finished:
		if brain.current_target and is_instance_valid(brain.current_target):
			change_state("chase")
		else:
			change_state("idle")

func _on_animation_finished() -> void:
	_animation_finished = true

func _on_animation_player_finished(anim_name: StringName) -> void:
	if String(anim_name) == _expected_anim:
		_animation_finished = true

func on_damage_taken(_amount: int, attacker: Node = null, from_back: bool = false) -> void:
	# Можем прервать зов помощи и перейти в chase
	if attacker and brain.is_hostile_target(attacker):
		brain.current_target = attacker
		change_state("chase")
