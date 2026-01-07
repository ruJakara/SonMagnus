extends Node2D

@onready var level_root: Node = $LevelRoot
@onready var spawn_marker: Marker2D = $ForestSpawn
@onready var mobs_root: Node2D = $mobs

var _is_active := true

func get_spawn_position() -> Vector2:
	return spawn_marker.global_position if spawn_marker else global_position

func get_level_root() -> Node:
	return level_root

func activate() -> void:
	_set_active_state(true)

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

