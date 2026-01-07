extends Node2D

@onready var spawn_marker: Marker2D = $CampSpawn
@onready var storage_ui: CanvasLayer = $CampStorageDebugUI
@onready var upgrade_ui: Control = $CampUpgradeLayer/CampUpgradeUI

var _is_active := false

func get_spawn_position() -> Vector2:
	return spawn_marker.global_position if spawn_marker else global_position

func set_active(active: bool) -> void:
	_set_active_state(active)

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
	if storage_ui:
		storage_ui.visible = value
	if not value and upgrade_ui:
		upgrade_ui.close_ui()

func toggle_upgrade_ui() -> void:
	if not _is_active:
		return
	if upgrade_ui:
		upgrade_ui.toggle_ui()

func close_upgrade_ui() -> void:
	if upgrade_ui:
		upgrade_ui.close_ui()

