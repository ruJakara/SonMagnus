# scripts/debug/hitbox_visualizer.gd
# Визуализация хитбоксов для отладки боевой системы
# Добавьте как дочерний узел к сущности для отображения областей

class_name HitboxVisualizer
extends Node2D

@export var enabled: bool = true
@export var hitbox_color: Color = Color(1, 0, 0, 0.3)  # Красный для атаки
@export var hurtbox_color: Color = Color(0, 1, 0, 0.3)  # Зелёный для получения урона
@export var back_color: Color = Color(0, 0, 1, 0.3)     # Синий для спины

var _areas: Array[Area2D] = []


func _ready() -> void:
	if not enabled or not Config.DEBUG_LOGS:
		queue_free()
		return
	
	# Ищем все Area2D в родителе
	_find_areas(get_parent())
	
	# Включаем отрисовку
	set_process(false)  # Не нужен process
	queue_redraw()


func _find_areas(node: Node) -> void:
	"""Рекурсивно ищет все Area2D"""
	for child in node.get_children():
		if child is Area2D:
			_areas.append(child)
		_find_areas(child)


func _draw() -> void:
	if not enabled:
		return
	
	for area in _areas:
		if not is_instance_valid(area):
			continue
		
		# Определяем цвет по имени
		var color = hitbox_color
		if "hurt" in area.name.to_lower() or "Hurtbox" in area.name:
			color = hurtbox_color
		elif "back" in area.name.to_lower() or "Back" in area.name:
			color = back_color
		
		# Рисуем все CollisionShape2D
		for shape_owner in area.get_children():
			if shape_owner is CollisionShape2D:
				_draw_collision_shape(shape_owner, color, area)


func _draw_collision_shape(shape_node: CollisionShape2D, color: Color, area: Area2D) -> void:
	"""Рисует форму коллизии"""
	if not shape_node.shape or shape_node.disabled:
		return
	
	# Трансформация от area до этого узла
	var transform = area.global_transform.affine_inverse() * global_transform
	var local_pos = transform * shape_node.global_position
	
	var shape = shape_node.shape
	
	if shape is CircleShape2D:
		draw_circle(local_pos, shape.radius, color)
		draw_arc(local_pos, shape.radius, 0, TAU, 32, Color(color.r, color.g, color.b, 1.0), 2.0)
	
	elif shape is RectangleShape2D:
		var half_size = shape.size / 2.0
		draw_rect(Rect2(local_pos - half_size, shape.size), color)
	
	elif shape is CapsuleShape2D:
		# Упрощенная капсула (круги + прямоугольник)
		var height = shape.height
		var radius = shape.radius
		draw_circle(local_pos + Vector2(0, -height/2), radius, color)
		draw_circle(local_pos + Vector2(0, height/2), radius, color)
		draw_rect(Rect2(local_pos + Vector2(-radius, -height/2), Vector2(radius*2, height)), color)


func _process(_delta: float) -> void:
	# Перерисовываем каждый кадр если включено
	if enabled and Config.DEBUG_LOGS:
		queue_redraw()
