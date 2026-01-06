# scripts/entities/enemies/enemy_base.gd
# Базовый класс для всех врагов
# Наследует BaseEntity, добавляет загрузку из JSON, управление анимациями и зонами

class_name EnemyBase
extends BaseEntity


## Флаг жизни (для быстрой проверки)
var is_alive: bool = true

## Флаг для предотвращения повторного вызова _die()
var _died: bool = false

## Данные из JSON
var behavior_data: Dictionary = {}
var combat_data: Dictionary = {}
var hostility_data: Dictionary = {}
var loot_data: Dictionary = {}
var animations: Dictionary = {}
var sounds: Dictionary = {}

## Ссылки на узлы
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer")
@onready var hurtbox: Area2D = get_node_or_null("Hurtbox")
@onready var attack_area: Area2D = get_node_or_null("Attack")
@onready var back_area: Area2D = get_node_or_null("Back")
@onready var brain: Node = get_node_or_null("EnemyBrain")

## Загружает данные врага из JSON файла
func load_from_json(json_path: String) -> bool:
	if not FileAccess.file_exists(json_path):
		push_error("Файл врага не найден: %s" % json_path)
		return false
	
	var file = FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_error("Не удалось открыть файл врага: %s" % json_path)
		return false
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		push_error("Ошибка парсинга JSON врага: %s (line %d)" % [json_path, json.get_error_line()])
		return false
	
	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		push_error("JSON врага должен быть объектом: %s" % json_path)
		return false
	
	# Загружаем базовые параметры
	entity_name = data.get("name", "Unknown Enemy")
	max_health = data.get("max_health", 50)
	health = max_health
	max_stamina = data.get("stamina", 80.0)
	stamina = max_stamina
	attack = data.get("attack", 10.0)
	defense = data.get("defense", 0.0)
	speed = data.get("speed", 100.0)
	tags = data.get("tags", [])
	
	# Загружаем специфичные данные
	behavior_data = data.get("behavior", {})
	combat_data = data.get("combat", {})
	hostility_data = data.get("hostility", {})
	loot_data = data.get("loot", {})
	animations = data.get("animations", {})
	sounds = data.get("sounds", {})
	
	if Config.DEBUG_LOGS:
		print_debug("[EnemyBase] Загружен враг: %s (HP: %d, Attack: %.1f)" % [entity_name, max_health, attack])
	
	return true

## Проигрывает анимацию по имени состояния
func play_animation(state_name: String) -> void:
	if not _sprite:
		return
	
	var anim_name = animations.get(state_name, state_name)
	if _sprite.sprite_frames and _sprite.sprite_frames.has_animation(anim_name):
		if _sprite.animation != anim_name:
			_sprite.play(anim_name)
	elif Config.DEBUG_LOGS:
		print_debug("[EnemyBase] Анимация не найдена: %s (состояние: %s)" % [anim_name, state_name])

## Переопределяем take_damage для визуальных эффектов и уведомления Brain
func take_damage(amount: int, attacker: Node = null, from_back: bool = false) -> void:
	if not is_alive:
		return
	
	var final_damage = amount
	var stun_duration = 0.0
	
	# Бэкстаб
	if from_back:
		final_damage = int(final_damage * combat_data.get("backstab_damage_mult", 1.0))
		stun_duration = combat_data.get("backstab_stun_duration", 0.0)
	
	# Удар по спящему
	if brain and brain.current_state_name == "sleep":
		final_damage = int(final_damage * combat_data.get("sleeping_damage_mult", 1.0))
		stun_duration = max(stun_duration, combat_data.get("sleeping_stun_duration", 0.0))
	
	# Применяем урон через BaseEntity
	super.take_damage(final_damage)
	
	# Визуальные эффекты (без await!)
	_play_hit_effects()
	
	# Стан
	if stun_duration > 0.0:
		apply_status_effect("stunned")
		if brain:
			brain.stun_timer = stun_duration
			brain.change_state("stunned")
	
	# Уведомляем Brain
	if brain:
		brain.on_damage_taken(final_damage, attacker)
	
	if Config.DEBUG_LOGS:
		print_debug("[EnemyBase] %s получил %d урона (от спины: %s), HP: %d/%d" % [entity_name, final_damage, from_back, health, max_health])

## Визуальные эффекты при получении урона (блинк, толчок)
func _play_hit_effects() -> void:
	if not _sprite:
		return
	
	# Блинк через Tween
	var tween = create_tween()
	tween.tween_property(_sprite, "modulate:a", 0.5, 0.1)
	tween.tween_property(_sprite, "modulate:a", 1.0, 0.1)
	
	# Толчок назад (небольшой)
	if brain and brain.current_target:
		var knockback_dir = (global_position - brain.current_target.global_position).normalized()
		velocity = knockback_dir * 100.0

## Переопределяем _die() для спавна лута и отключения AI
func _die() -> void:
	if _died:
		return  # Уже умирали
	_died = true
	
	is_alive = false
	emit_signal("died")
	
	# Отключаем Brain
	if brain:
		brain.set_process(false)
		brain.set_physics_process(false)
	
	# Спавн лута
	if loot_data.get("can_be_looted", false):
		_spawn_loot()
	
	# Проигрываем анимацию смерти (без await)
	play_animation("death")
	
	if Config.DEBUG_LOGS:
		print_debug("[EnemyBase] %s умер" % entity_name)

## Спавн лута
func _spawn_loot() -> void:
	var loot_table_id = loot_data.get("loot_table_id", "")
	if loot_table_id.is_empty():
		return
	
	# Генерируем лут через LootManager
	var loot_items = LootManager.roll_loot(loot_table_id)
	
	if loot_items.is_empty():
		if Config.DEBUG_LOGS:
			print_debug("[EnemyBase] Ничего не выпало из %s" % entity_name)
		return
	
	# TODO: Создать визуальный маркер лута (LootMarker scene)
	# var loot_marker = preload("res://scenes/loot_marker.tscn").instantiate()
	# loot_marker.global_position = global_position
	# loot_marker.setup(loot_items, self)
	# get_parent().add_child(loot_marker)
	
	if Config.DEBUG_LOGS:
		print_debug("[EnemyBase] Спавн лута от %s: %s" % [entity_name, loot_items])

## Попытка лутания трупа
func try_loot(looter: Node) -> void:
	if is_alive:
		return
	
	if not loot_data.get("can_be_looted", false):
		return
	
	# TODO: Открыть UI лута, передать список предметов
	if Config.DEBUG_LOGS:
		print_debug("[EnemyBase] %s лутает труп %s" % [looter.entity_name if looter.has("entity_name") else "Player", entity_name])
	
	loot_data.can_be_looted = false

## Поворачивает врага в направлении вектора, также флипает зоны коллизий
func face_direction(direction: Vector2) -> void:
	if direction.x == 0:
		return
	
	var dir_sign = sign(direction.x)
	_sprite.flip_h = (dir_sign < 0)
	
	# Флипаем зоны через scale.x
	if attack_area:
		attack_area.scale.x = abs(attack_area.scale.x) * dir_sign
	if back_area:
		back_area.scale.x = abs(back_area.scale.x) * dir_sign
	if hurtbox:
		hurtbox.scale.x = abs(hurtbox.scale.x) * dir_sign

## Вызывается из AnimationPlayer method track на кадре удара
func _on_attack_frame() -> void:
	if brain:
		brain._on_attack_frame()

## Вызывается из AnimationPlayer method track в конце анимации атаки
func _on_attack_end() -> void:
	if brain:
		brain._on_attack_end()
