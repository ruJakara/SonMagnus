# scripts/entities/enemies/states/patrol_state.gd
# Состояние патрулирования - случайное движение с паузами

class_name PatrolState
extends EnemyState

var _target_position: Vector2 = Vector2.ZERO
var _is_paused: bool = false
var _pause_timer: float = 0.0

func enter() -> void:
	_choose_new_target()
	brain.enemy.play_animation("patrol")

func exit() -> void:
	_is_paused = false
	_pause_timer = 0.0

func update(delta: float) -> void:
	# Проверяем конус обзора
	var target = brain.detect_target_in_cone()
	if target:
		brain.current_target = target
		brain.emit_signal("target_detected", target)
		brain.change_state("chase")
		return
	
	# Если на паузе
	if _is_paused:
		_pause_timer -= delta
		if _pause_timer <= 0.0:
			_is_paused = false
			_choose_new_target()
			brain.enemy.play_animation("patrol")
		return
	
	# Проверяем достижение цели
	var distance = brain.enemy.global_position.distance_to(_target_position)
	if distance < 10.0:
		_start_pause()

func physics_update(delta: float) -> void:
	if _is_paused:
		return
	
	# Движение к целевой точке
	var direction = (_target_position - brain.enemy.global_position).normalized()
	brain.enemy.velocity = direction * brain.enemy.speed
	
	# Поворачиваем врага (флипаем спрайт и зоны)
	brain.enemy.face_direction(direction)
	
	brain.enemy.move_and_slide()

func on_damage_taken(amount: int, attacker: Node = null) -> void:
	# При получении урона переходим в преследование
	if attacker and brain.is_hostile_target(attacker):
		brain.current_target = attacker
		brain.change_state("chase")

## Выбирает новую случайную точку для патруля
func _choose_new_target() -> void:
	var dist = randf_range(
		brain.behavior_data.get("patrol_walk_distance_min", 80.0),
		brain.behavior_data.get("patrol_walk_distance_max", 200.0)
	)
	var angle = randf_range(0, TAU)
	_target_position = brain.enemy.global_position + Vector2(cos(angle), sin(angle)) * dist

## Начинает паузу патрулирования
func _start_pause() -> void:
	_is_paused = true
	brain.enemy.play_animation("idle")
	brain.enemy.velocity = Vector2.ZERO
	_pause_timer = randf_range(
		brain.behavior_data.get("patrol_pause_min", 1.0),
		brain.behavior_data.get("patrol_pause_max", 3.0)
	)

