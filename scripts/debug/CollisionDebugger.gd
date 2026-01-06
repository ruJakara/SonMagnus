extends Node
## Отладочный скрипт для диагностики коллизий игрока и врагов

const LAYER_NAMES: Dictionary = {
	1: "world",              # Layer 1 = 2^0 = 1
	2: "player_body",        # Layer 2 = 2^1 = 2
	4: "player_hurtbox",     # Layer 3 = 2^2 = 4
	8: "player_hitbox",      # Layer 4 = 2^3 = 8
	16: "enemy_body",        # Layer 5 = 2^4 = 16
	32: "enemy_hurtbox",     # Layer 6 = 2^5 = 32
	64: "enemy_attack",      # Layer 7 = 2^6 = 64
	128: "enemy_back",       # Layer 8 = 2^7 = 128
	256: "triggers"          # Layer 9 = 2^8 = 256
}

func _ready() -> void:
	if not Config.DEBUG_LOGS:
		return
	
	# Даём время на инициализацию сцены
	await get_tree().create_timer(0.5).timeout
	
	print("\n[CollisionDebugger] ═══════════════════════════════")
	print("[CollisionDebugger] ДИАГНОСТИКА КОЛЛИЗИЙ")
	print("[CollisionDebugger] ═══════════════════════════════")

	print("\n📋 Схема слоёв коллизий:")
	print("  Layer 1 (00000001) = world (стены, пол)")
	print("  Layer 2 (00000010) = player_body (тело игрока для физики)")
	print("  Layer 3 (00000100) = player_hurtbox (зона получения урона игрока)")
	print("  Layer 4 (00001000) = player_hitbox (зона атаки игрока)")
	print("  Layer 5 (00010000) = enemy_body (тело врага для физики)")
	print("  Layer 6 (00100000) = enemy_hurtbox (зона получения урона врага)")
	print("  Layer 7 (01000000) = enemy_attack (зона атаки врага)")
	print("  Layer 8 (10000000) = enemy_back (зона бэкстаба врага)")
	print("  Layer 9+ = triggers, NPCs, etc.")
	print("")
	
	_check_player()
	_check_enemies()
	_check_compatibility()
	
	print("\n[CollisionDebugger] ═══════════════════════════════")

func _check_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		push_warning("[CollisionDebugger] ⚠ Игрок не найден в группе 'player'!")
		return
	
	var player: CharacterBody2D = players[0] as CharacterBody2D
	if not player:
		push_warning("[CollisionDebugger] ⚠ Игрок не является CharacterBody2D!")
		return
	
	print("\n🎮 [ИГРОК] %s" % player.name)
	print("  📍 Позиция: %s" % player.global_position)
	print("  🔹 Collision Layer: %d (bin: %s) → %s" % [
		player.collision_layer, 
		_to_binary(player.collision_layer),
		_get_layer_name(player.collision_layer)
	])
	print("  🔸 Collision Mask: %d (bin: %s) → %s" % [
		player.collision_mask, 
		_to_binary(player.collision_mask),
		_get_mask_names(player.collision_mask)
	])
	print("  🏷️  Группы: %s" % player.get_groups())
	
	# Проверяем Hitbox игрока (зона атаки)
	var hitbox: Area2D = player.get_node_or_null("zone/Hitbox")
	if hitbox:
		print("\n  ⚔️  [Hitbox] %s (зона атаки)" % hitbox.name)
		print("    📍 Позиция (локальная): %s" % hitbox.position)
		print("    📍 Позиция (глобальная): %s" % hitbox.global_position)
		print("    🔹 Layer: %d (bin: %s) → %s" % [
			hitbox.collision_layer, 
			_to_binary(hitbox.collision_layer),
			_get_layer_name(hitbox.collision_layer)
		])
		print("    🔸 Mask: %d (bin: %s) → %s" % [
			hitbox.collision_mask, 
			_to_binary(hitbox.collision_mask),
			_get_mask_names(hitbox.collision_mask)
		])
		print("    👁️  Monitoring: %s" % hitbox.monitoring)
		print("    👀 Monitorable: %s" % hitbox.monitorable)
		
		_print_shape(hitbox, "    ")
		
		# Проверка корректности
		var expected_layer = 8   # Layer 4 (player_hitbox) = 2^3 = 8
		var expected_mask = 160  # Layer 6 (32) + Layer 8 (128) = enemy_hurtbox + enemy_back
		
		if hitbox.collision_layer != expected_layer:
			print("    ⚠️  ПРОБЛЕМА: Layer должен быть %d (player_hitbox), а не %d!" % [expected_layer, hitbox.collision_layer])
		if hitbox.collision_mask != expected_mask:
			print("    ⚠️  ПРОБЛЕМА: Mask должен быть %d (enemy_hurtbox+back), а не %d!" % [expected_mask, hitbox.collision_mask])
		if not hitbox.monitorable:
			print("    ⚠️  ПРОБЛЕМА: Monitorable должен быть true!")
	else:
		print("  ❌ Hitbox не найден у игрока!")
	
	# Проверяем Hurtbox игрока (зона получения урона)
	var hurtbox: Area2D = player.get_node_or_null("zone/Hurtbox")
	if hurtbox:
		print("\n  🛡️  [Hurtbox] %s (зона получения урона)" % hurtbox.name)
		print("    📍 Позиция (локальная): %s" % hurtbox.position)
		print("    📍 Позиция (глобальная): %s" % hurtbox.global_position)
		print("    🔹 Layer: %d (bin: %s) → %s" % [
			hurtbox.collision_layer, 
			_to_binary(hurtbox.collision_layer),
			_get_layer_name(hurtbox.collision_layer)
		])
		print("    🔸 Mask: %d (bin: %s) → %s" % [
			hurtbox.collision_mask, 
			_to_binary(hurtbox.collision_mask),
			_get_mask_names(hurtbox.collision_mask)
		])
		print("    👁️  Monitoring: %s" % hurtbox.monitoring)
		print("    👀 Monitorable: %s" % hurtbox.monitorable)
		
		_print_shape(hurtbox, "    ")
		
		# Проверка корректности
		var expected_layer = 4   # Layer 3 (player_hurtbox) = 2^2 = 4
		var expected_mask = 64   # Layer 7 (enemy_attack) = 2^6 = 64
		
		if hurtbox.collision_layer != expected_layer:
			print("    ⚠️  ПРОБЛЕМА: Layer должен быть %d (player_hurtbox), а не %d!" % [expected_layer, hurtbox.collision_layer])
		if hurtbox.collision_mask != expected_mask:
			print("    ⚠️  ПРОБЛЕМА: Mask должен быть %d (enemy_attack), а не %d!" % [expected_mask, hurtbox.collision_mask])
	else:
		print("  ❌ Hurtbox не найден у игрока!")

func _check_enemies() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		push_warning("[CollisionDebugger] ⚠ Враги не найдены в группе 'enemies'!")
		return
	
	print("\n👹 [ВРАГИ] Найдено: %d" % enemies.size())
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		var script_name = enemy.get_script().get_path().get_file() if enemy.get_script() else "no_script"
		print("\n  🔴 [ВРАГ] %s (%s)" % [enemy.name, script_name])
		print("    📍 Позиция: %s" % str(enemy.global_position))
		
		if enemy is CharacterBody2D:
			print("    🔹 Collision Layer: %d (bin: %s) → %s" % [
				enemy.collision_layer, 
				_to_binary(enemy.collision_layer),
				_get_layer_name(enemy.collision_layer)
			])
			print("    🔸 Collision Mask: %d (bin: %s) → %s" % [
				enemy.collision_mask, 
				_to_binary(enemy.collision_mask),
				_get_mask_names(enemy.collision_mask)
			])
		
		print("    🏷️  Группы: %s" % str(enemy.get_groups()))
		
		var hurtbox: Area2D = enemy.get_node_or_null("Hurtbox")
		if hurtbox:
			print("\n    🛡️  [Hurtbox] %s" % hurtbox.name)
			print("      📍 Позиция (глобальная): %s" % str(hurtbox.global_position))
			print("      🔹 Layer: %d (bin: %s) → %s" % [
				hurtbox.collision_layer, 
				_to_binary(hurtbox.collision_layer),
				_get_layer_name(hurtbox.collision_layer)
			])
			print("      🔸 Mask: %d (bin: %s) → %s" % [
				hurtbox.collision_mask, 
				_to_binary(hurtbox.collision_mask),
				_get_mask_names(hurtbox.collision_mask)
			])
			print("      👁️  Monitoring: %s" % str(hurtbox.monitoring))
			print("      👀 Monitorable: %s" % str(hurtbox.monitorable))
			
			_print_shape(hurtbox, "      ")
			
			if hurtbox.collision_layer != 32:  # Layer 6 = 2^5 = 32
				print("      ⚠️  ПРОБЛЕМА: Layer должен быть 32 (enemy_hurtbox), а не %d!" % hurtbox.collision_layer)
			if not hurtbox.monitorable:
				print("      ⚠️  КРИТИЧНО: Monitorable = false! Игрок не увидит врага при атаке!")
		else:
			print("    ❌ Hurtbox не найден у врага %s!" % enemy.name)
		
		var attack: Area2D = enemy.get_node_or_null("Attack")
		if attack:
			print("\n    ⚔️  [Attack] %s" % attack.name)
			print("      📍 Позиция (локальная): %s" % str(attack.position))
			print("      🔹 Layer: %d (bin: %s) → %s" % [
				attack.collision_layer, 
				_to_binary(attack.collision_layer),
				_get_layer_name(attack.collision_layer)
			])
			print("      🔸 Mask: %d (bin: %s) → %s" % [
				attack.collision_mask, 
				_to_binary(attack.collision_mask),
				_get_mask_names(attack.collision_mask)
			])
			print("      👁️  Monitoring: %s" % str(attack.monitoring))
			print("      👀 Monitorable: %s" % str(attack.monitorable))
			
			if attack.collision_layer != 64:  # Layer 7 = 2^6 = 64
				print("      ⚠️  ПРОБЛЕМА: Layer должен быть 64 (enemy_attack), а не %d!" % attack.collision_layer)
			if attack.collision_mask != 4:  # Layer 3 (player_hurtbox) = 2^2 = 4
				print("      ⚠️  ПРОБЛЕМА: Mask должен быть 4 (player_hurtbox), а не %d!" % attack.collision_mask)
		
		var back: Area2D = enemy.get_node_or_null("Back")
		if back:
			print("\n    🔪 [Back] %s (зона бэкстаба)" % back.name)
			print("      📍 Позиция (локальная): %s" % str(back.position))
			print("      🔹 Layer: %d (bin: %s) → %s" % [
				back.collision_layer, 
				_to_binary(back.collision_layer),
				_get_layer_name(back.collision_layer)
			])
			print("      🔸 Mask: %d (bin: %s) → %s" % [
				back.collision_mask, 
				_to_binary(back.collision_mask),
				_get_mask_names(back.collision_mask)
			])
			print("      👁️  Monitoring: %s" % str(back.monitoring))
			print("      👀 Monitorable: %s" % str(back.monitorable))
			
			if back.collision_layer != 128:  # Layer 8 = 2^7 = 128
				print("      ⚠️  ПРОБЛЕМА: Layer должен быть 128 (enemy_back), а не %d!" % back.collision_layer)
			if not back.monitorable:
				print("      ⚠️  КРИТИЧНО: Monitorable = false! Бэкстаб не будет работать!")

func _check_compatibility() -> void:
	"""Проверяет совместимость слоёв между игроком и врагами"""
	print("\n🔍 [ПРОВЕРКА СОВМЕСТИМОСТИ]")
	
	var players = get_tree().get_nodes_in_group("player")
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	if players.is_empty() or enemies.is_empty():
		print("  ⚠️  Недостаточно объектов для проверки")
		return
	
	var player: CharacterBody2D = players[0] as CharacterBody2D
	var player_hitbox: Area2D = player.get_node_or_null("zone/Hitbox") if player else null
	
	if not player_hitbox:
		print("  ❌ Hitbox игрока не найден!")
		return
	
	print("\n  🎮 Игрок Hitbox:")
	print("    Layer: %d (%s)" % [player_hitbox.collision_layer, _get_layer_name(player_hitbox.collision_layer)])
	print("    Mask: %d (%s)" % [player_hitbox.collision_mask, _get_mask_names(player_hitbox.collision_mask)])
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		var enemy_hurtbox: Area2D = enemy.get_node_or_null("Hurtbox")
		var enemy_back: Area2D = enemy.get_node_or_null("Back")
		
		if not enemy_hurtbox:
			print("\n  ❌ %s: Hurtbox не найден!" % enemy.name)
			continue
		
		print("\n  🔴 Враг %s:" % enemy.name)
		print("    Hurtbox Layer: %d (%s)" % [enemy_hurtbox.collision_layer, _get_layer_name(enemy_hurtbox.collision_layer)])
		print("    Hurtbox Monitorable: %s" % enemy_hurtbox.monitorable)
		
		# Проверка: может ли Hitbox игрока "видеть" Hurtbox врага
		var can_hit: bool = (player_hitbox.collision_mask & enemy_hurtbox.collision_layer) != 0
		var is_monitorable: bool = enemy_hurtbox.monitorable
		
		print("    → Hitbox.mask (%d) & Hurtbox.layer (%d) = %d → %s" % [
			player_hitbox.collision_mask,
			enemy_hurtbox.collision_layer,
			player_hitbox.collision_mask & enemy_hurtbox.collision_layer,
			"✅ СОВМЕСТИМО" if can_hit else "❌ НЕ СОВМЕСТИМО"
		])
		
		if not is_monitorable:
			print("    ⚠️  КРИТИЧНО: Hurtbox.monitorable = false! get_overlapping_bodies() не найдёт врага!")
		
		# Проверка бэкстаба
		if enemy_back:
			var can_backstab: bool = (player_hitbox.collision_mask & enemy_back.collision_layer) != 0
			print("    🔪 Back Layer: %d (%s) → %s" % [
				enemy_back.collision_layer,
				_get_layer_name(enemy_back.collision_layer),
				"✅ Бэкстаб работает" if can_backstab and enemy_back.monitorable else "❌ Бэкстаб НЕ работает"
			])
		
		# Расстояние
		var dist: float = player_hitbox.global_position.distance_to(enemy_hurtbox.global_position)
		var player_radius: float = _get_radius(player_hitbox)
		var enemy_radius: float = _get_radius(enemy_hurtbox)
		var total_radius: float = player_radius + enemy_radius
		
		print("    📏 Расстояние: %.1f px | Радиусы: %.1f + %.1f = %.1f | %s" % [
			dist, player_radius, enemy_radius, total_radius,
			"✅ В ЗОНЕ АТАКИ" if dist <= total_radius else "⏸️  СЛИШКОМ ДАЛЕКО"
		])

func _get_radius(area: Area2D) -> float:
	var shape: CollisionShape2D = area.get_node_or_null("CollisionShape2D")
	if not shape or not shape.shape:
		return 0.0
	
	if shape.shape is CircleShape2D:
		return shape.shape.radius
	elif shape.shape is CapsuleShape2D:
		return shape.shape.radius
	elif shape.shape is RectangleShape2D:
		return shape.shape.size.length() / 2.0
	return 0.0

func _print_shape(area: Area2D, indent: String) -> void:
	var collision_shape: CollisionShape2D = area.get_node_or_null("CollisionShape2D")
	if collision_shape and collision_shape.shape:
		var shape = collision_shape.shape
		if shape is CircleShape2D:
			print("%s📐 Shape: CircleShape2D, Радиус: %.1f" % [indent, shape.radius])
		elif shape is RectangleShape2D:
			print("%s📐 Shape: RectangleShape2D, Size: %s" % [indent, shape.size])
		elif shape is CapsuleShape2D:
			print("%s📐 Shape: CapsuleShape2D, Радиус: %.1f, Высота: %.1f" % [indent, shape.radius, shape.height])

func _to_binary(value: int) -> String:
	"""Преобразует число в бинарное представление (8 бит)"""
	var binary := ""
	for i in range(8):
		binary = ("1" if (value >> i) & 1 else "0") + binary
	return binary

func _get_layer_name(layer: int) -> String:
	"""Возвращает название слоя"""
	if layer in LAYER_NAMES:
		return LAYER_NAMES[layer]
	return "unknown"

func _get_mask_names(mask: int) -> String:
	"""Возвращает список названий слоёв в маске"""
	var names := []
	for layer in LAYER_NAMES.keys():
		if (mask & layer) != 0:
			names.append(LAYER_NAMES[layer])
	return ", ".join(names) if not names.is_empty() else "none"
