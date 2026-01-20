# scripts/world/HarvestableResource.gd
# Базовый класс для собираемых ресурсов (деревья, камни, кусты)

class_name HarvestableResource
extends Node2D

signal harvested(resource_type: String, loot: Array)
signal interaction_started()
signal interaction_cancelled()

@export var resource_type: String = "generic"
@export var harvest_time: float = 1.5
@export var loot_table_id: String = ""
@export var required_tool: String = ""
@export var health: int = 1
@export var max_health: int = 1
@export var respawn_time: float = 0.0

var _is_harvesting: bool = false
var _harvest_progress: float = 0.0
var _harvester: Node = null

@onready var _sprite: Sprite2D = $Sprite if has_node("Sprite") else null
@onready var _collision: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var _interaction_area: Area2D = get_node_or_null("InteractionArea")


func _ready() -> void:
	add_to_group("harvestable")
	add_to_group("resource_%s" % resource_type)
	
	if _interaction_area:
		_interaction_area.body_entered.connect(_on_body_entered)
		_interaction_area.body_exited.connect(_on_body_exited)
	
	if loot_table_id.is_empty():
		loot_table_id = "resource_%s" % resource_type


func interact(harvester: Node = null) -> void:
	if _is_harvesting:
		return
	
	_harvester = harvester
	_is_harvesting = true
	_harvest_progress = 0.0
	emit_signal("interaction_started")
	
	if Config.DEBUG_LOGS:
		print("[HarvestableResource] Начат сбор %s" % resource_type)


func cancel_harvest() -> void:
	if not _is_harvesting:
		return
	
	_is_harvesting = false
	_harvest_progress = 0.0
	_harvester = null
	emit_signal("interaction_cancelled")


func _process(delta: float) -> void:
	if not _is_harvesting:
		return
	
	_harvest_progress += delta
	
	if _harvest_progress >= harvest_time:
		_complete_harvest()


func _complete_harvest() -> void:
	_is_harvesting = false
	health -= 1
	
	var loot := _generate_loot()
	emit_signal("harvested", resource_type, loot)
	
	if _harvester and _harvester.has_method("receive_loot"):
		_harvester.receive_loot(loot)
	
	if Config.DEBUG_LOGS:
		print("[HarvestableResource] %s собран: %s" % [resource_type, str(loot)])
	
	if health <= 0:
		_on_depleted()
	
	_harvester = null


func _generate_loot() -> Array:
	var loot_manager = get_node_or_null("/root/LootManager")
	if loot_manager and loot_manager.has_method("generate_loot"):
		return loot_manager.generate_loot(loot_table_id)
	
	# Фолбэк — базовый лут
	return _get_default_loot()


func _get_default_loot() -> Array:
	var defaults := {
		"tree": [{"id": "wood", "amount": 2}],
		"rock": [{"id": "stone", "amount": 2}],
		"bush": [{"id": "berries", "amount": 1}],
		"ore": [{"id": "iron_ore", "amount": 1}],
		"herb": [{"id": "herb", "amount": 1}]
	}
	return defaults.get(resource_type, [{"id": "junk", "amount": 1}])


func _on_depleted() -> void:
	if respawn_time > 0.0:
		visible = false
		if _collision:
			_collision.disabled = true
		
		await get_tree().create_timer(respawn_time).timeout
		_respawn()
	else:
		queue_free()


func _respawn() -> void:
	health = max_health
	visible = true
	if _collision:
		_collision.disabled = false
	
	if Config.DEBUG_LOGS:
		print("[HarvestableResource] %s восстановлен" % resource_type)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		# TODO: Показать подсказку взаимодействия
		pass


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		cancel_harvest()


func get_harvest_progress() -> float:
	if harvest_time <= 0.0:
		return 1.0
	return _harvest_progress / harvest_time


func is_harvestable() -> bool:
	return health > 0 and not _is_harvesting
