# autoload/WorldPopulator.gd
# Система наполнения мира: спавнит врагов и ресурсы при загрузке локации

extends Node

signal population_started(location_id: String)
signal population_completed(location_id: String, stats: Dictionary)
signal enemy_spawned(enemy: Node, location_id: String)
signal resource_spawned(resource: Node, location_id: String)

const SPAWN_CONFIGS_PATH := "res://data/world/spawn_configs/"

var _spawn_configs: Dictionary = {}
var _active_spawns: Dictionary = {}

@onready var _enemy_factory: Node = get_node_or_null("/root/EnemyFactory")


func _ready() -> void:
	_load_spawn_configs()


func populate_location(location_id: String, spawn_root: Node2D, bounds: Rect2 = Rect2()) -> Dictionary:
	emit_signal("population_started", location_id)
	
	var config := _get_spawn_config(location_id)
	if config.is_empty():
		push_warning("[WorldPopulator] Нет конфига для локации: %s, используем дефолт" % location_id)
		config = _get_default_config()
	
	var stats := {
		"enemies_spawned": 0,
		"resources_spawned": 0,
		"total_spawned": 0
	}
	
	# Определяем границы спавна
	if bounds.size == Vector2.ZERO:
		bounds = Rect2(0, 200, 2000, 600)
	
	# Спавним врагов
	var enemy_count := _calculate_spawn_count(config.get("enemies", {}))
	for i in range(enemy_count):
		var enemy := _spawn_random_enemy(config.get("enemies", {}), spawn_root, bounds)
		if enemy:
			stats["enemies_spawned"] += 1
			emit_signal("enemy_spawned", enemy, location_id)
	
	# Спавним ресурсы
	var resource_count := _calculate_spawn_count(config.get("resources", {}))
	for i in range(resource_count):
		var resource := _spawn_random_resource(config.get("resources", {}), spawn_root, bounds)
		if resource:
			stats["resources_spawned"] += 1
			emit_signal("resource_spawned", resource, location_id)
	
	stats["total_spawned"] = stats["enemies_spawned"] + stats["resources_spawned"]
	
	_active_spawns[location_id] = stats
	emit_signal("population_completed", location_id, stats)
	
	if Config.DEBUG_LOGS:
		print("[WorldPopulator] %s: %d врагов, %d ресурсов" % [
			location_id, stats["enemies_spawned"], stats["resources_spawned"]
		])
	
	return stats


func clear_location(location_id: String, spawn_root: Node2D) -> void:
	for child in spawn_root.get_children():
		if child.is_in_group("spawned"):
			child.queue_free()
	
	_active_spawns.erase(location_id)


func get_location_stats(location_id: String) -> Dictionary:
	return _active_spawns.get(location_id, {})


func _calculate_spawn_count(spawn_data: Dictionary) -> int:
	var min_count: int = spawn_data.get("min_count", 1)
	var max_count: int = spawn_data.get("max_count", 5)
	return randi_range(min_count, max_count)


func _spawn_random_enemy(enemy_config: Dictionary, parent: Node2D, bounds: Rect2) -> Node:
	var enemy_pool: Array = enemy_config.get("pool", ["goblin_scout"])
	if enemy_pool.is_empty():
		return null
	
	var weights: Array = enemy_config.get("weights", [])
	var enemy_id: String = _weighted_random_pick(enemy_pool, weights)
	
	var pos := _get_random_position(bounds)
	
	# Пробуем через EnemyFactory
	if _enemy_factory and _enemy_factory.has_method("spawn_enemy"):
		var enemy = _enemy_factory.spawn_enemy(enemy_id, pos, parent)
		if enemy:
			enemy.add_to_group("spawned")
			return enemy
	
	# Фолбэк: грузим сцену напрямую
	var scene_path := "res://scenes/enemies/goblin_scout.tscn"
	if enemy_id == "goblin_scout":
		scene_path = "res://scenes/enemies/goblin_scout.tscn"
	
	var packed := load(scene_path) as PackedScene
	if not packed:
		push_warning("[WorldPopulator] Не удалось загрузить сцену врага: %s" % scene_path)
		return null
	
	var enemy := packed.instantiate()
	if enemy is Node2D:
		enemy.position = pos
	enemy.add_to_group("spawned")
	parent.add_child(enemy)
	
	return enemy


func _spawn_random_resource(resource_config: Dictionary, parent: Node2D, bounds: Rect2) -> Node:
	var resource_pool: Array = resource_config.get("pool", ["tree", "rock", "bush"])
	if resource_pool.is_empty():
		return null
	
	var weights: Array = resource_config.get("weights", [])
	var resource_type: String = _weighted_random_pick(resource_pool, weights)
	
	var pos := _get_random_position(bounds)
	
	# Пробуем загрузить сцену ресурса
	var scene_path := "res://scenes/resources/%s.tscn" % resource_type
	var packed := load(scene_path) as PackedScene
	
	if not packed:
		# Создаём заглушку
		var stub := _create_resource_stub(resource_type, pos)
		stub.add_to_group("spawned")
		parent.add_child(stub)
		return stub
	
	var resource := packed.instantiate()
	if resource is Node2D:
		resource.position = pos
	resource.add_to_group("spawned")
	parent.add_child(resource)
	
	return resource


func _create_resource_stub(resource_type: String, pos: Vector2) -> Node2D:
	var stub := Node2D.new()
	stub.name = "%s_stub" % resource_type.capitalize()
	stub.position = pos
	stub.add_to_group("harvestable")
	stub.add_to_group("resource_%s" % resource_type)
	
	# Добавляем визуальную заглушку
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	
	# Цвета для разных типов ресурсов
	var colors := {
		"tree": Color(0.2, 0.6, 0.2),
		"rock": Color(0.5, 0.5, 0.5),
		"bush": Color(0.3, 0.7, 0.3),
		"ore": Color(0.6, 0.4, 0.2),
		"herb": Color(0.4, 0.8, 0.4)
	}
	
	var sizes := {
		"tree": Vector2(40, 80),
		"rock": Vector2(50, 40),
		"bush": Vector2(30, 25),
		"ore": Vector2(35, 30),
		"herb": Vector2(20, 20)
	}
	
	# Создаём простой прямоугольник
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(colors.get(resource_type, Color.WHITE))
	var tex := ImageTexture.create_from_image(img)
	sprite.texture = tex
	sprite.scale = sizes.get(resource_type, Vector2(30, 30)) / 32.0
	sprite.position.y = -sizes.get(resource_type, Vector2(30, 30)).y / 2.0
	
	stub.add_child(sprite)
	
	# Добавляем метаданные
	stub.set_meta("resource_type", resource_type)
	stub.set_meta("is_stub", true)
	
	# Добавляем скрипт заглушки
	var script := GDScript.new()
	script.source_code = """
extends Node2D

var resource_type: String = ""
var harvest_time: float = 1.0
var loot_table: String = ""

func _ready() -> void:
	resource_type = get_meta("resource_type", "unknown")
	loot_table = "resource_%s" % resource_type

func interact() -> void:
	if Config.DEBUG_LOGS:
		print("[ResourceStub] Взаимодействие с %s (заглушка)" % resource_type)

func harvest() -> Array:
	if Config.DEBUG_LOGS:
		print("[ResourceStub] Сбор %s (заглушка)" % resource_type)
	queue_free()
	return []
"""
	script.reload()
	stub.set_script(script)
	
	return stub


func _get_random_position(bounds: Rect2) -> Vector2:
	return Vector2(
		randf_range(bounds.position.x, bounds.position.x + bounds.size.x),
		randf_range(bounds.position.y, bounds.position.y + bounds.size.y)
	)


func _weighted_random_pick(pool: Array, weights: Array) -> String:
	if pool.is_empty():
		return ""
	
	if weights.is_empty() or weights.size() != pool.size():
		return pool[randi() % pool.size()]
	
	var total_weight: float = 0.0
	for w in weights:
		total_weight += float(w)
	
	var roll: float = randf() * total_weight
	var cumulative: float = 0.0
	
	for i in range(pool.size()):
		cumulative += float(weights[i])
		if roll <= cumulative:
			return str(pool[i])
	
	return str(pool[0])


func _load_spawn_configs() -> void:
	_spawn_configs = {}
	
	# Загружаем конфиги из папки
	var dir := DirAccess.open(SPAWN_CONFIGS_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"):
				var config_path := SPAWN_CONFIGS_PATH + file_name
				var data: Variant = JsonUtils.load_json(config_path)
				if typeof(data) == TYPE_DICTIONARY:
					var location_id: String = file_name.get_basename()
					_spawn_configs[location_id] = data
			file_name = dir.get_next()
		dir.list_dir_end()
	
	# Добавляем дефолтные конфиги если папки нет
	if _spawn_configs.is_empty():
		_spawn_configs = _get_builtin_configs()


func _get_spawn_config(location_id: String) -> Dictionary:
	return _spawn_configs.get(location_id, {})


func _get_default_config() -> Dictionary:
	return {
		"enemies": {
			"min_count": 2,
			"max_count": 5,
			"pool": ["goblin_scout"],
			"weights": [1.0]
		},
		"resources": {
			"min_count": 5,
			"max_count": 15,
			"pool": ["tree", "rock", "bush"],
			"weights": [3.0, 2.0, 4.0]
		}
	}


func _get_builtin_configs() -> Dictionary:
	return {
		"forest": {
			"enemies": {
				"min_count": 3,
				"max_count": 7,
				"pool": ["goblin_scout"],
				"weights": [1.0]
			},
			"resources": {
				"min_count": 8,
				"max_count": 20,
				"pool": ["tree", "rock", "bush", "herb"],
				"weights": [4.0, 2.0, 3.0, 1.0]
			}
		},
		"cave": {
			"enemies": {
				"min_count": 4,
				"max_count": 10,
				"pool": ["goblin_worker", "spider_small"],
				"weights": [2.0, 3.0]
			},
			"resources": {
				"min_count": 5,
				"max_count": 12,
				"pool": ["rock", "ore"],
				"weights": [3.0, 2.0]
			}
		}
	}
