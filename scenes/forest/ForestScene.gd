extends Node2D

const LOCATION_ID := "forest"

@onready var level_root: Node = $LevelRoot
@onready var spawn_marker: Marker2D = $ForestSpawn
@onready var mobs_root: Node2D = $mobs

@export var auto_populate: bool = true
@export var spawn_bounds: Rect2 = Rect2(100, 300, 1500, 400)

var _is_active := true
var _populated := false

@onready var _world_populator: Node = get_node_or_null("/root/WorldPopulator")


func _ready() -> void:
	if auto_populate and not _populated:
		call_deferred("_populate_world")


func _populate_world() -> void:
	if _populated:
		return
	
	# Очищаем существующих врагов (кроме вручную размещённых)
	_clear_spawned_entities()
	
	if _world_populator and _world_populator.has_method("populate_location"):
		var stats: Dictionary = _world_populator.populate_location(LOCATION_ID, mobs_root, spawn_bounds)
		_populated = true
		
		if Config.DEBUG_LOGS:
			print("[ForestScene] Мир наполнен: %s" % str(stats))
	else:
		push_warning("[ForestScene] WorldPopulator не найден, используем ручное размещение")


func _clear_spawned_entities() -> void:
	if not mobs_root:
		return
	
	for child in mobs_root.get_children():
		if child.is_in_group("spawned"):
			child.queue_free()


func repopulate() -> void:
	_populated = false
	_populate_world()


func get_spawn_position() -> Vector2:
	return spawn_marker.global_position if spawn_marker else global_position


func get_level_root() -> Node:
	return level_root


func activate() -> void:
	_set_active_state(true)
	if not _populated:
		_populate_world()


func deactivate() -> void:
	_set_active_state(false)


func _set_active_state(value: bool) -> void:
	if _is_active == value:
		return
	_is_active = value
	visible = value
	set_process(value)
	if level_root:
		level_root.visible = value
