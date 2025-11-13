## autoload/EnemyFactory.gd
## Фабрика врагов: загружает данные и создаёт экземпляры врагов по идентификатору.

extends Node

const ENEMIES_DATA_PATH := "res://data/enemies.json"

var _enemy_registry: Dictionary = {}
var _scene_cache: Dictionary = {}


func _ready() -> void:
	_load_registry()


func spawn_enemy(enemy_id: String, position: Vector2, parent: Node = null) -> Node:
	var enemy_data: Variant = _enemy_registry.get(enemy_id)
	if typeof(enemy_data) != TYPE_DICTIONARY:
		push_warning("EnemyFactory: неизвестный enemy_id '%s'." % enemy_id)
		return null

	var enemy_dict: Dictionary = enemy_data

	var scene_path: String = enemy_dict.get("scene", "res://scenes/enemies/BaseEnemy.tscn")
	var packed_scene := _get_packed_scene(scene_path)
	if packed_scene == null:
		push_warning("EnemyFactory: не удалось загрузить сцену '%s' для '%s'." % [scene_path, enemy_id])
		return null

	var instance := packed_scene.instantiate()
	if not instance:
		push_warning("EnemyFactory: не удалось инстанцировать сцену '%s'." % scene_path)
		return null

	if instance.has_method("initialize_from_data"):
		instance.call("initialize_from_data", enemy_id, enemy_dict)

	if instance is Node2D:
		instance.position = position
	elif instance.has_method("set_global_position"):
		instance.call("set_global_position", position)

	if parent == null:
		parent = get_tree().current_scene
	if parent:
		parent.add_child(instance)
	else:
		push_warning("EnemyFactory: отсутствует родитель для размещения врага '%s'." % enemy_id)

	return instance


func get_enemy_data(enemy_id: String) -> Dictionary:
	return _enemy_registry.get(enemy_id, {})


func _load_registry() -> void:
	var data: Variant = JsonUtils.load_json(ENEMIES_DATA_PATH)
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("EnemyFactory: файл %s содержит некорректные данные." % ENEMIES_DATA_PATH)
		_enemy_registry = {}
	else:
		_enemy_registry = data


func _get_packed_scene(scene_path: String) -> PackedScene:
	if _scene_cache.has(scene_path):
		return _scene_cache[scene_path]

	var packed := ResourceLoader.load(scene_path)
	if packed and packed is PackedScene:
		_scene_cache[scene_path] = packed
		return packed

	push_warning("EnemyFactory: ресурс %s не является PackedScene." % scene_path)
	return null
