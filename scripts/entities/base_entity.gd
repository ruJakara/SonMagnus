# scripts/entities/base_entity.gd
# Базовый класс для всех игровых сущностей (игрок, NPC, монстры).
# Совместим с Godot 4.5.1 (2D). Без варнингов и обращений к несуществующим глобалям.

class_name BaseEntity
extends CharacterBody2D

signal health_changed(new_health: int, max_health: int)
signal died
signal effect_applied(effect_id: String)
signal effect_removed(effect_id: String)

@export var entity_name: String = "Безымянный"
@export var max_health: int = 100
@export var level: int = 1
@export var attack: float = 10.0
@export var defense: float = 5.0
@export var speed: float = 100.0

# Внутреннее поле здоровья (явно типизировано)
var _health: int = 100

# Активные эффекты для этой сущности (ключ — effect_id, значение — true)
var active_effects: Dictionary = {}

# Ссылка на EffectManager (будет получена в _ready)
var _effect_manager: Node = null

# Свойство health с геттером/сеттером
var health: int:
	get:
		return _health
	set(value):
		_health = clamp(value, 0, max_health)
		emit_signal("health_changed", _health, max_health)
		if _health == 0:
			_die()

func _ready() -> void:
	# Получаем ссылку на EffectManager безопасно (если автолоад подключён)
	_effect_manager = get_node_or_null("/root/EffectManager")
	# Инициализация здоровья при спавне
	_health = max_health
	if Config.DEBUG_LOGS:
		print_debug("[%s] ready — HP: %d/%d" % [entity_name, _health, max_health])

# Инициализация вручную
func initialize(name: String, max_hp: int, lvl: int) -> void:
	entity_name = name
	max_health = max_hp
	level = lvl
	health = max_hp

# Получить значение защиты (можно расширять)
func get_defense(damage_type: String) -> int:
	# TODO: учесть резисты по типам урона
	return int(defense)

# Получение урона
func take_damage(amount: int) -> void:
	var final_damage: int = max(0, amount - get_defense("physical"))
	health -= final_damage
	if Config.DEBUG_LOGS:
		print_debug("[%s] получил %d урона, HP: %d/%d" % [entity_name, final_damage, health, max_health])

# Лечение
func heal(amount: int) -> void:
	health = min(health + amount, max_health)
	if Config.DEBUG_LOGS:
		print_debug("[%s] восстановил %d HP, HP: %d/%d" % [entity_name, amount, health, max_health])

# Вызов при смерти
func _die() -> void:
	if Config.DEBUG_LOGS:
		print_debug("[%s] умер" % entity_name)
	emit_signal("died")

# --- Работа с эффектами (без прямых обращений к глобалям) ---

# Применить эффект: безопасно вызывает EffectManager, если тот есть
func apply_status_effect(effect_id: String) -> void:
	if _effect_manager == null:
		# Попытка получить ещё раз (на случай порядка загрузки)
		_effect_manager = get_node_or_null("/root/EffectManager")
		if _effect_manager == null:
			push_warning("EffectManager не подключён — эффект %s не применён к %s" % [effect_id, entity_name])
			return

	# Ожидаем, что EffectManager имеет метод apply_effect(target, effect_id)
	if _effect_manager.has_method("apply_effect"):
		_effect_manager.call("apply_effect", self, effect_id)
		active_effects[effect_id] = true
		emit_signal("effect_applied", effect_id)
	else:
		push_warning("EffectManager не реализует apply_effect — эффект не применён.")

# Снять эффект
func remove_status_effect(effect_id: String) -> void:
	if _effect_manager == null:
		_effect_manager = get_node_or_null("/root/EffectManager")
		if _effect_manager == null:
			return
	if _effect_manager.has_method("remove_effect"):
		_effect_manager.call("remove_effect", self, effect_id)
	active_effects.erase(effect_id)
	emit_signal("effect_removed", effect_id)

# Очистить все эффекты
func clear_all_effects() -> void:
	if _effect_manager == null:
		_effect_manager = get_node_or_null("/root/EffectManager")
		if _effect_manager == null:
			active_effects.clear()
			return
	for effect_id in active_effects.keys():
		if _effect_manager.has_method("remove_effect"):
			_effect_manager.call("remove_effect", self, effect_id)
	active_effects.clear()
