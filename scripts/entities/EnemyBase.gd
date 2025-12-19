## scripts/entities/EnemyBase.gd
## Базовый класс врага: здоровье, урон, эффекты, совместимость с CombatManager.
## 
## ИСПОЛЬЗОВАНИЕ В СЦЕНЕ:
## 1. Создайте Node2D с этим скриптом
## 2. Добавьте дочерние узлы: EnemyAI (Node) и EnemyAttack (Node)
## 3. В Inspector укажите enemy_id и путь к JSON (data_path) или настройте параметры вручную
## 4. Вызовите initialize_from_data() в _ready() или через export var data_path

class_name EnemyBase
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
@export var data_path: String = ""  # Путь к JSON файлу врага (например, "res://data/enemies/goblin.json")
@export var faction: StringName = &"goblins"
@export var hostile_factions: Array[StringName] = [&"player", &"animals"]

var _health: int = 50
var _effect_manager: Node = null
var _active_effects: Dictionary = {}
var state: String = "idle"  # idle, chase, attack, dead
var current_target: Node = null

# Ссылки на компоненты
var _ai_component: EnemyAI = null
var _attack_component: EnemyAttack = null
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	_health = max_health
	_effect_manager = get_node_or_null("/root/EffectManager")
	
	# Поиск компонентов
	_ai_component = get_node_or_null("EnemyAI") as EnemyAI
	_attack_component = get_node_or_null("EnemyAttack") as EnemyAttack
	
	# Загрузка данных из JSON, если указан путь
	if not data_path.is_empty():
		load_from_json(data_path)
	
	# Отключаем loop для анимации атаки
	if _sprite and _sprite.sprite_frames:
		if _sprite.sprite_frames.has_animation("attack"):
			_sprite.sprite_frames.set_animation_loop("attack", false)


func load_from_json(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_warning("[EnemyBase] JSON файл не найден: %s" % path)
		return
	
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("[EnemyBase] Не удалось открыть файл: %s" % path)
		return
	
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()
	
	if error != OK:
		push_warning("[EnemyBase] Ошибка парсинга JSON: %s" % json.get_error_message())
		return
	
	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("[EnemyBase] JSON должен быть объектом")
		return
	
	# Извлекаем ID из имени файла или используем из данных
	if enemy_id == "unknown_enemy" and data.has("id"):
		enemy_id = data.get("id", enemy_id)
	
	initialize_from_data(enemy_id, data)


func initialize_from_data(id: String, data: Dictionary) -> void:
	enemy_id = id
	enemy_name = data.get("name", enemy_name)
	max_health = int(data.get("max_health", max_health))
	attack = int(data.get("attack", attack))
	defense = int(data.get("defense", defense))
	crit_chance = float(data.get("crit_chance", crit_chance))
	speed = float(data.get("speed", speed))
	_health = max_health
	
	# Инициализация фракции из данных
	if data.has("faction"):
		faction = StringName(str(data.get("faction")))
	if data.has("hostile_factions"):
		hostile_factions.clear()
		for f in data.get("hostile_factions", []):
			hostile_factions.append(StringName(str(f)))
	
	# Инициализация компонентов из данных
	_initialize_components_from_data(data)


func _initialize_components_from_data(data: Dictionary) -> void:
	# Применяем AI настройки
	if _ai_component and data.has("ai"):
		var ai_data = data.get("ai", {})
		if ai_data.has("detection_range"):
			_ai_component.detection_range = float(ai_data.get("detection_range", 250))
		if ai_data.has("lose_range"):
			_ai_component.lose_range = float(ai_data.get("lose_range", 350))
		if ai_data.has("attack_range"):
			_ai_component.attack_range = float(ai_data.get("attack_range", 55))
	
	# Применяем настройки атаки
	if _attack_component and data.has("attack_data"):
		var attack_data = data.get("attack_data", {})
		if attack_data.has("combo_id"):
			_attack_component.combo_id = attack_data.get("combo_id", "enemy_basic")
		if attack_data.has("cooldown"):
			_attack_component.cooldown = float(attack_data.get("cooldown", 1.2))
		if attack_data.has("weapon_data"):
			_attack_component.weapon_data_override = attack_data.get("weapon_data", {})
		elif attack_data.has("base_damage"):
			# Если base_damage указан напрямую в attack_data
			_attack_component.weapon_data_override["base_damage"] = float(attack_data.get("base_damage", 10.0))
			_attack_component.weapon_data_override["crit_chance"] = float(attack_data.get("crit_chance", crit_chance))


func take_damage(amount: float) -> void:
	if amount <= 0:
		return
	
	# Учитываем защиту: max(amount - defense, 0)
	var final_damage: float = max(amount - float(defense), 0.0)
	
	_health = max(_health - int(round(final_damage)), 0)
	emit_signal("health_changed", _health, max_health)
	
	# Визуал попадания: вспышка через modulate
	var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
	if sprite:
		sprite.modulate = Color(1, 0.6, 0.6)
		await get_tree().create_timer(0.08).timeout
		if is_instance_valid(sprite):
			sprite.modulate = Color(1, 1, 1)
	
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
		push_warning("[EnemyBase] '%s': EffectManager недоступен — эффект '%s' не применён." % [enemy_id, effect_id])


func remove_status_effect(effect_id: String) -> void:
	if not _active_effects.has(effect_id):
		return
	
	if _effect_manager == null or not is_instance_valid(_effect_manager):
		_effect_manager = get_node_or_null("/root/EffectManager")
	
	if _effect_manager and _effect_manager.has_method("remove_effect"):
		_effect_manager.call("remove_effect", self, effect_id)
	_active_effects.erase(effect_id)


func die() -> void:
	state = "dead"
	emit_signal("died", enemy_id)
	# TODO: можно добавить задержку перед queue_free() для анимации смерти
	queue_free()


func has_status_effect(effect_id: String) -> bool:
	return _active_effects.has(effect_id)


func get_health() -> int:
	return _health


func get_max_health() -> int:
	return max_health


func get_faction() -> StringName:
	return faction


func is_hostile_to(other_faction: StringName) -> bool:
	return other_faction in hostile_factions


func _process(_delta: float) -> void:
	_update_anim()


func _update_anim() -> void:
	if not _sprite:
		return

	if state == "attack":
		if _sprite.animation != "attack":
			_sprite.play("attack")
	elif state == "chase":
		if _sprite.animation != "run":
			_sprite.play("run")
	else:
		if _sprite.animation != "idle":
			_sprite.play("idle")


func face_target(target: Node) -> void:
	if not _sprite or not target or not is_instance_valid(target):
		return
	
	var direction = target.global_position.x - global_position.x
	_sprite.flip_h = direction < 0.0
