## scripts/entities/enemy.gd
## Базовая логика врага: здоровье, эффекты, простая интеграция с AI.

class_name Enemy
extends Node2D

signal died(enemy_id: String)
signal health_changed(current_health: int, max_health: int)

@export var enemy_id: String = "unknown_enemy"
@export var enemy_name: String = "Безымянный враг"
@export var max_health: int = 50
@export var speed: float = 80.0
@export var attack: int = 10
@export var defense: int = 5
@export var crit_chance: float = 0.05

var _health: int = 50
var _effect_manager: Node = null
var _active_effects: Dictionary = {}
var state: StringName = &"idle" # idle, chase, attack, flee, dead


func _ready() -> void:
	_health = max_health
	_effect_manager = get_node_or_null("/root/EffectManager")


func _process(delta: float) -> void:
	update_ai(delta)


func initialize_from_data(id: String, data: Dictionary) -> void:
	enemy_id = id
	enemy_name = data.get("name", enemy_name)
	max_health = int(data.get("max_health", max_health))
	attack = int(data.get("attack", attack))
	defense = int(data.get("defense", defense))
	crit_chance = float(data.get("crit_chance", crit_chance))
	speed = float(data.get("speed", speed))
	_health = max_health


func take_damage(amount: int) -> void:
	if amount <= 0:
		return

	_health = max(_health - amount, 0)
	emit_signal("health_changed", _health, max_health)
	if _health <= 0:
		die()


func apply_status_effect(effect_id: String) -> void:
	if effect_id.is_empty():
		return

	if _effect_manager == null or not is_instance_valid(_effect_manager):
		_effect_manager = get_node_or_null("/root/EffectManager")

	if _effect_manager and _effect_manager.has_method("apply_effect"):
		_effect_manager.call("apply_effect", self, effect_id)
		_active_effects[effect_id] = true
	else:
		push_warning("Enemy '%s': EffectManager недоступен — эффект '%s' не применён." % [enemy_id, effect_id])


func remove_status_effect(effect_id: String) -> void:
	if not _active_effects.has(effect_id):
		return

	if _effect_manager == null or not is_instance_valid(_effect_manager):
		_effect_manager = get_node_or_null("/root/EffectManager")

	if _effect_manager and _effect_manager.has_method("remove_effect"):
		_effect_manager.call("remove_effect", self, effect_id)
	_active_effects.erase(effect_id)


func die() -> void:
	emit_signal("died", enemy_id)
	queue_free()


func update_ai(delta: float) -> void:
	# Заглушка: конкретные враги могут переопределить эту функцию или подписаться на _process.
	pass


func has_status_effect(effect_id: String) -> bool:
	return _active_effects.has(effect_id)
