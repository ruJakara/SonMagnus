extends Node
## Отладочный скрипт для диагностики коллизий игрока и врагов

const LAYER_NAMES: Dictionary = {
	1: "world",
	2: "player",
	4: "enemies", 
	8: "player_attack",
	16: "enemy_hurtbox",
	32: "triggers"
}

func _ready() -> void:
	if not Config.DEBUG_LOGS:
		return
	
	# Даём время на инициализацию сцены
	await get_tree().create_timer(0.5).timeout
	

	print("[CollisionDebugger] ДИАГНОСТИКА КОЛЛИЗИЙ")

	print("\nСхема слоёв коллизий:")
	print("  Layer 1 (001) = world")
	print("  Layer 2 (002) = player body")
	print("  Layer 4 (004) = enemies body")
	print("  Layer 8 (008) = player attack hitbox")
	print("  Layer 16 (016) = enemy hurtbox (получение урона)")
	print("  Layer 32 (032) = triggers")
	print("")
	
	_check_player()
	_check_enemies()
	_check_compatibility()
	


func _check_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		push_warning("[CollisionDebugger] ⚠ Игрок не найден в группе 'player'!")
		return
	
	var player: CharacterBody2D = players[0] as CharacterBody2D
	if not player:
		push_warning("[CollisionDebugger] ⚠ Игрок не является CharacterBody2D!")
		return
	
	print("\n[ИГРОК] %s" % player.name)
	print("  Позиция: %s" % player.global_position)
	print("  Collision Layer: %d (bin: %s)" % [player.collision_layer, _to_binary(player.collision_layer)])
	print("  Collision Mask: %d (bin: %s)" % [player.collision_mask, _to_binary(player.collision_mask)])
	print("  Группы: %s" % player.get_groups())
	
	# Проверяем Hitbox игрока
	var hitbox: Area2D = player.get_node_or_null("Hitbox")
	if hitbox:
		print("\n  [Hitbox] %s" % hitbox.name)
		print("    Позиция (локальная): %s" % hitbox.position)
		print("    Позиция (глобальная): %s" % hitbox.global_position)
		print("    Collision Layer: %d (bin: %s)" % [hitbox.collision_layer, _to_binary(hitbox.collision_layer)])
		print("    Collision Mask: %d (bin: %s)" % [hitbox.collision_mask, _to_binary(hitbox.collision_mask)])
		print("    Monitoring: %s" % hitbox.monitoring)
		print("    Monitorable: %s" % hitbox.monitorable)
		
		var shape_owner = hitbox.shape_owner_get_owner(0) if hitbox.get_shape_owners().size() > 0 else null
		if shape_owner != null:
			var collision_shape: CollisionShape2D = hitbox.get_node_or_null("CollisionShape2D")
			if collision_shape and collision_shape.shape:
				var shape = collision_shape.shape
				if shape is CircleShape2D:
					print("    Shape: CircleShape2D, Радиус: %.1f" % shape.radius)
				elif shape is RectangleShape2D:
					print("    Shape: RectangleShape2D, Size: %s" % shape.size)
	else:
		push_warning("  ⚠ Hitbox не найден у игрока!")

func _check_enemies() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		push_warning("[CollisionDebugger] ⚠ Враги не найдены в группе 'enemies'!")
		return
	
	print("\n[ВРАГИ] Найдено: %d" % enemies.size())
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		print("\n  [ВРАГ] %s (%s)" % [enemy.name, enemy.get_script().get_path().get_file()])
		print("    Позиция: %s" % enemy.global_position)
		
		# Если враг - CharacterBody2D или PhysicsBody2D
		if enemy is CharacterBody2D:
			print("    Collision Layer: %d (bin: %s)" % [enemy.collision_layer, _to_binary(enemy.collision_layer)])
			print("    Collision Mask: %d (bin: %s)" % [enemy.collision_mask, _to_binary(enemy.collision_mask)])
		
		print("    Группы: %s" % enemy.get_groups())
		
		# Проверяем Hurtbox врага
		var hurtbox: Area2D = enemy.get_node_or_null("Hurtbox")
		if hurtbox:
			print("\n    [Hurtbox] %s" % hurtbox.name)
			print("      Позиция (локальная): %s" % hurtbox.position)
			print("      Позиция (глобальная): %s" % hurtbox.global_position)
			print("      Collision Layer: %d (bin: %s)" % [hurtbox.collision_layer, _to_binary(hurtbox.collision_layer)])
			print("      Collision Mask: %d (bin: %s)" % [hurtbox.collision_mask, _to_binary(hurtbox.collision_mask)])
			print("      Monitoring: %s" % hurtbox.monitoring)
			print("      Monitorable: %s" % hurtbox.monitorable)
			
			var collision_shape: CollisionShape2D = hurtbox.get_node_or_null("CollisionShape2D")
			if collision_shape and collision_shape.shape:
				var shape = collision_shape.shape
				if shape is CircleShape2D:
					print("      Shape: CircleShape2D, Радиус: %.1f" % shape.radius)
				elif shape is RectangleShape2D:
					print("      Shape: RectangleShape2D, Size: %s" % shape.size)
				elif shape is CapsuleShape2D:
					print("      Shape: CapsuleShape2D, Радиус: %.1f, Высота: %.1f" % [shape.radius, shape.height])
		else:
			push_warning("    ⚠ Hurtbox не найден у врага %s!" % enemy.name)
		
		# Проверяем зону атаки Attack
		var attack: Area2D = enemy.get_node_or_null("Attack")
		if attack:
			print("\n    [Attack] %s" % attack.name)
			print("      Позиция (локальная): %s" % attack.position)
			print("      Collision Layer: %d (bin: %s)" % [attack.collision_layer, _to_binary(attack.collision_layer)])
			print("      Collision Mask: %d (bin: %s)" % [attack.collision_mask, _to_binary(attack.collision_mask)])

func _check_compatibility() -> void:
	"""Проверяет совместимость слоёв между игроком и врагами"""
	print("\n[ПРОВЕРКА СОВМЕСТИМОСТИ]")
	
	var players = get_tree().get_nodes_in_group("player")
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	if players.is_empty() or enemies.is_empty():
		print("  ⚠ Недостаточно объектов для проверки")
		return
	
	var player: CharacterBody2D = players[0] as CharacterBody2D
	var player_hitbox: Area2D = player.get_node_or_null("Hitbox") if player else null
	
	if not player_hitbox:
		print("  ⚠ Hitbox игрока не найден!")
		return
	
	print("\n  Игрок Hitbox: layer=%d, mask=%d" % [player_hitbox.collision_layer, player_hitbox.collision_mask])
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		var enemy_hurtbox: Area2D = enemy.get_node_or_null("Hurtbox")
		if not enemy_hurtbox:
			print("  ⚠ %s: Hurtbox не найден!" % enemy.name)
			continue
		
		print("\n  Враг %s Hurtbox: layer=%d, mask=%d, monitorable=%s" % [
			enemy.name,
			enemy_hurtbox.collision_layer,
			enemy_hurtbox.collision_mask,
			enemy_hurtbox.monitorable
		])
		
		# Проверка: может ли Hitbox игрока "видеть" Hurtbox врага
		var hitbox_can_see_hurtbox: bool = (player_hitbox.collision_mask & enemy_hurtbox.collision_layer) != 0
		var hurtbox_is_monitorable: bool = enemy_hurtbox.monitorable
		
		print("  → Hitbox.mask & Hurtbox.layer = %d & %d = %d → %s" % [
			player_hitbox.collision_mask,
			enemy_hurtbox.collision_layer,
			player_hitbox.collision_mask & enemy_hurtbox.collision_layer,
			"✓ СОВМЕСТИМО" if hitbox_can_see_hurtbox else "✗ НЕ СОВМЕСТИМО"
		])
		
		if not hurtbox_is_monitorable:
			print("  ⚠ КРИТИЧНО: Hurtbox.monitorable = false! get_overlapping_areas() не найдёт его!")
		
		# Расстояние
		var dist: float = player_hitbox.global_position.distance_to(enemy_hurtbox.global_position)
		
		# Получаем радиусы
		var player_radius: float = 0.0
		var enemy_radius: float = 0.0
		
		var p_shape: CollisionShape2D = player_hitbox.get_node_or_null("CollisionShape2D")
		if p_shape and p_shape.shape is CircleShape2D:
			player_radius = p_shape.shape.radius
		
		var e_shape: CollisionShape2D = enemy_hurtbox.get_node_or_null("CollisionShape2D")
		if e_shape and e_shape.shape is CircleShape2D:
			enemy_radius = e_shape.shape.radius
		elif e_shape and e_shape.shape is CapsuleShape2D:
			enemy_radius = e_shape.shape.radius
		
		var total_radius: float = player_radius + enemy_radius
		print("  → Расстояние: %.1f px | Радиусы: %.1f + %.1f = %.1f | %s" % [
			dist, player_radius, enemy_radius, total_radius,
			"✓ В ЗОНЕ" if dist <= total_radius else "✗ СЛИШКОМ ДАЛЕКО"
		])

func _to_binary(value: int) -> String:
	"""Преобразует число в бинарное представление (8 бит)"""
	var binary := ""
	for i in range(8):
		binary = ("1" if (value >> i) & 1 else "0") + binary
	return binary
