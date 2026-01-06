extends Node2D
## Визуальная отладка хитбоксов в реальном времени

@export var enable_hitbox_debug := true
var debug_lines: Array[Dictionary] = []

func _ready() -> void:
	if not Config.DEBUG_LOGS:
		enable_hitbox_debug = false
		return
	
	set_process(true)
	z_index = 100  # Рисуем поверх всего

func _process(_delta: float) -> void:
	if not enable_hitbox_debug:
		return
	
	queue_redraw()  # Перерисовываем каждый кадр

func _draw() -> void:
	if not enable_hitbox_debug:
		return
	
	# Отрисовка хитбокса игрока
	var players = get_tree().get_nodes_in_group("player")
	for player in players:
		if not is_instance_valid(player):
			continue
		
		var hitbox: Area2D = player.get_node_or_null("Hitbox")
		if hitbox:
			_draw_area2d(hitbox, Color.CYAN, "Player Hitbox")
	
	# Отрисовка хитбоксов врагов
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		var hurtbox: Area2D = enemy.get_node_or_null("Hurtbox")
		if hurtbox:
			_draw_area2d(hurtbox, Color.RED, "%s Hurtbox" % enemy.name)
		
		var attack: Area2D = enemy.get_node_or_null("Attack")
		if attack:
			_draw_area2d(attack, Color.ORANGE, "%s Attack" % enemy.name)

func _draw_area2d(area: Area2D, color: Color, label: String) -> void:
	if not is_instance_valid(area):
		return
	
	var collision_shape: CollisionShape2D = area.get_node_or_null("CollisionShape2D")
	if not collision_shape or not collision_shape.shape:
		return
	
	var shape = collision_shape.shape
	var pos: Vector2 = area.global_position
	
	# Преобразуем в локальные координаты для отрисовки
	var local_pos = to_local(pos)
	
	# Рисуем форму
	if shape is CircleShape2D:
		draw_circle(local_pos, shape.radius, Color(color, 0.2))  # Заливка
		draw_arc(local_pos, shape.radius, 0, TAU, 32, color, 2.0)  # Контур
		
		# Рисуем центральную точку
		draw_circle(local_pos, 3.0, color)
		
	elif shape is RectangleShape2D:
		var rect = Rect2(local_pos - shape.size / 2, shape.size)
		draw_rect(rect, Color(color, 0.2))  # Заливка
		draw_rect(rect, color, false, 2.0)  # Контур
		
	elif shape is CapsuleShape2D:
		var half_height = shape.height / 2
		# Рисуем капсулу как два полукруга + прямоугольник
		draw_circle(local_pos + Vector2(0, -half_height), shape.radius, Color(color, 0.2))
		draw_circle(local_pos + Vector2(0, half_height), shape.radius, Color(color, 0.2))
		var rect = Rect2(local_pos - Vector2(shape.radius, half_height), Vector2(shape.radius * 2, shape.height))
		draw_rect(rect, Color(color, 0.2))
		draw_arc(local_pos + Vector2(0, -half_height), shape.radius, 0, TAU, 16, color, 2.0)
		draw_arc(local_pos + Vector2(0, half_height), shape.radius, 0, TAU, 16, color, 2.0)
	
	# Рисуем label (смещаем вверх)
	var font = ThemeDB.fallback_font
	var font_size = 12
	var label_pos = local_pos - Vector2(0, 40)
	
	# Тень для текста
	draw_string(font, label_pos + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.BLACK)
	# Основной текст
	draw_string(font, label_pos, label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)
	
	# Рисуем информацию о слоях
	var layer_info = "L:%d M:%d" % [area.collision_layer, area.collision_mask]
	var info_pos = label_pos + Vector2(0, 15)
	draw_string(font, info_pos + Vector2(1, 1), layer_info, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color.BLACK)
	draw_string(font, info_pos, layer_info, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color.YELLOW)

