# scripts/player/PlayerCombat.gd
# Боевая система игрока с поддержкой ComboManager и JSON-конфигов

class_name PlayerCombat
extends Node

# ===== Настройки атаки =====
@export var default_combo: String = "sword_basic_l"
@export var attack_cooldown: float = 0.8
@export var windup_time: float = 0.12
@export var weapon_damage: float = 10.0
@export var weapon_crit_chance: float = 0.15

# ===== Настройки блока/парирования =====
@export var parry_window: float = 0.3
@export var block_stamina_cost: float = 5.0
@export var parry_stamina_reward: float = 10.0

# ===== Состояния =====
var is_blocking: bool = false
var is_parrying: bool = false
var _is_attacking: bool = false
var _cooldown_timer: float = 0.0
var _parry_timer: float = 0.0

# ===== Комбо =====
var _current_sequence: Array[String] = []
var _combo_buffer_timer: float = 0.0
const COMBO_BUFFER_WINDOW: float = 0.5
var _last_combo_data: Dictionary = {}

# ===== Оружие =====
var _weapon_active: bool = true

# ===== Ссылки =====
var _player: Node = null
var _hitbox: Area2D = null
var _combat_manager: Node = null
var _combo_manager: Node = null
var _animation_player: AnimationPlayer = null
var _combat_profile: CombatProfile = null


# ===== Инициализация =====

func _ready() -> void:
	_player = get_parent()
	if not _player:
		push_error("[PlayerCombat] Родитель не найден!")
		return
	
	_combat_manager = get_node_or_null("/root/CombatManager")
	if not _combat_manager:
		push_warning("[PlayerCombat] CombatManager не найден")
	
	_combo_manager = get_node_or_null("/root/ComboManager")
	if not _combo_manager:
		push_warning("[PlayerCombat] ComboManager не найден")
	
	_animation_player = _player.get_node_or_null("AnimationPlayer")
	if not _animation_player:
		push_warning("[PlayerCombat] AnimationPlayer не найден")
	else:
		_animation_player.animation_finished.connect(_on_animation_finished)
	
	_combat_profile = CombatProfile.new()
	
	_setup_hitbox()


func _setup_hitbox() -> void:
	_hitbox = _player.get_node_or_null("Hitbox") as Area2D
	if not _hitbox:
		push_warning("[PlayerCombat] Area2D 'Hitbox' не найдена у игрока")
		return
	
	_hitbox.monitoring = false
	# НЕ трогаем monitorable — оставляем true для корректной работы get_overlapping_areas()


# ===== Обновление =====

func _process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
	
	if _parry_timer > 0.0:
		_parry_timer -= delta
		if _parry_timer <= 0.0:
			is_parrying = false
	
	if _combo_buffer_timer > 0.0:
		_combo_buffer_timer -= delta
		if _combo_buffer_timer <= 0.0:
			_reset_combo()


# ===== Обработка ввода =====

func handle_attack_input(button: String) -> void:
	"""Вызывается из player.gd при нажатии ЛКМ ('L') или ПКМ ('R')"""
	if is_blocking:
		return
	
	# Если атакуем — буферизуем нажатие
	if _is_attacking:
		_current_sequence.append(button)
		_combo_buffer_timer = COMBO_BUFFER_WINDOW
		if Config.DEBUG_LOGS:
			print("[PlayerCombat] Буферизация: %s → %s" % [button, _current_sequence])
		return
	
	# Иначе добавляем в последовательность и ищем комбо
	_current_sequence.append(button)
	_execute_combo()


func _execute_combo() -> void:
	"""Ищет комбо по текущей последовательности и запускает анимацию"""
	if not _combo_manager:
		_reset_combo()
		return
	
	var weapon_type = "weapon" if _weapon_active else "unarmed"
	
	# Ищем ID комбо по последовательности и типу оружия
	var combo_id = _combo_manager.find_combo_by_sequence(_current_sequence, weapon_type)
	
	if combo_id.is_empty():
		# Не найдено комбо — сбрасываем
		if Config.DEBUG_LOGS:
			print("[PlayerCombat] Комбо не найдено для %s (%s)" % [_current_sequence, weapon_type])
		_reset_combo()
		return
	
	# Получаем данные комбо по ID
	var combo_data = _combo_manager.get_combo(combo_id)
	
	if combo_data.is_empty():
		if Config.DEBUG_LOGS:
			print("[PlayerCombat] Данные комбо '%s' не найдены" % combo_id)
		_reset_combo()
		return
	
	# Выбираем анимацию (weapon_animation для оружия, animation для голых рук)
	var anim_name = combo_data.get("weapon_animation", combo_data.get("animation", ""))
	if anim_name.is_empty():
		if Config.DEBUG_LOGS:
			print("[PlayerCombat] Нет анимации для комбо: %s" % combo_id)
		_reset_combo()
		return
	
	_start_attack_animation(anim_name, combo_data)


func _start_attack_animation(anim_name: String, combo_data: Dictionary) -> void:
	"""Запускает анимацию атаки (удар происходит по method track в анимации)"""
	if not _animation_player:
		_reset_combo()
		return
	
	# Проверяем стоимость стамины
	var stamina_cost = combo_data.get("stamina_cost", 0.0)
	if stamina_cost > 0.0 and _player.has_method("consume_stamina"):
		if not _player.consume_stamina(stamina_cost):
			if Config.DEBUG_LOGS:
				print("[PlayerCombat] Недостаточно стамины для %s" % combo_data.get("id", "unknown"))
			_reset_combo()
			return
	
	# Сохраняем данные комбо для _on_attack_frame
	_last_combo_data = combo_data.duplicate(true)
	
	_is_attacking = true
	_combo_buffer_timer = combo_data.get("combo_window", COMBO_BUFFER_WINDOW)
	
	var combo_id = combo_data.get("id", "unknown")
	if Config.DEBUG_LOGS:
		print("[PlayerCombat] === START ATTACK === | Комбо: %s | Анимация: %s | Последовательность: %s" % [
			combo_id, anim_name, _current_sequence
		])
	
	# Проигрываем анимацию (удар произойдет через method track _on_attack_frame)
	if _animation_player.has_animation(anim_name):
		_animation_player.play(anim_name)
	else:
		push_warning("[PlayerCombat] Анимация '%s' не найдена!" % anim_name)
		_is_attacking = false
		_reset_combo()
		return


# _execute_hit_detection удален - удар теперь происходит только через _on_attack_frame


func _on_animation_finished(anim_name: StringName) -> void:
	"""Вызывается AnimationPlayer при окончании любой анимации"""
	if Config.DEBUG_LOGS:
		print("[PlayerCombat] === _on_animation_finished === | Анимация: %s" % anim_name)
	
	if anim_name.begins_with("attack") or anim_name.begins_with("punch") or \
	   anim_name.begins_with("kick") or anim_name.begins_with("charge") or \
	   anim_name.begins_with("dash"):
		_is_attacking = false
		_cooldown_timer = attack_cooldown
		
		if Config.DEBUG_LOGS:
			print("[PlayerCombat] Сброс состояния атаки | Буфер: %.2f сек" % _combo_buffer_timer)
		
		# Если в буфере есть нажатия — продолжаем комбо
		if _combo_buffer_timer > 0.0 and _current_sequence.size() > 0:
			if Config.DEBUG_LOGS:
				print("[PlayerCombat] Продолжение комбо из буфера")
			_execute_combo()
		else:
			_reset_combo()


func _on_attack_frame() -> void:
	"""Вызывается из AnimationPlayer method track в момент удара анимации"""
	if Config.DEBUG_LOGS:
		print("[PlayerCombat] === _on_attack_frame ===")
	
	if not _is_attacking:
		if Config.DEBUG_LOGS:
			print("[PlayerCombat] Предупреждение: удар без активной атаки")
		return
	
	# Включаем хитбокс
	if not _hitbox:
		if Config.DEBUG_LOGS:
			print("[PlayerCombat] Ошибка: хитбокс не найден")
		return
	
	_hitbox.monitoring = true
	
	if Config.DEBUG_LOGS:
		print("[PlayerCombat] Хитбокс активирован")
		print("[PlayerCombat]   Hitbox layer: %d, mask: %d" % [_hitbox.collision_layer, _hitbox.collision_mask])
		print("[PlayerCombat]   Hitbox global_pos: %s" % _hitbox.global_position)
		print("[PlayerCombat]   Player global_pos: %s" % _player.global_position)
		# Получаем размер хитбокса
		var shape_node: CollisionShape2D = _hitbox.get_node_or_null("CollisionShape2D")
		if shape_node and shape_node.shape:
			if shape_node.shape is CircleShape2D:
				print("[PlayerCombat]   Hitbox radius: %.1f" % shape_node.shape.radius)
	
	# Ждём ФИЗИЧЕСКИЙ кадр (когда обновятся коллизии)
	await get_tree().physics_frame
	
	# Выполняем проверку попаданий
	if _last_combo_data.is_empty():
		if Config.DEBUG_LOGS:
			print("[PlayerCombat] Ошибка: нет данных последней атаки")
		return
	
	# Логируем все враги для отладки
	if Config.DEBUG_LOGS:
		var enemies = get_tree().get_nodes_in_group("enemies")
		print("[PlayerCombat] Враги в сцене: %d" % enemies.size())
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy is CharacterBody2D:
				var dist: float = _hitbox.global_position.distance_to(enemy.global_position)
				print("[PlayerCombat]   - %s: pos=%s, layer=%d, dist=%.1f, has_take_damage=%s" % [
					enemy.name, 
					enemy.global_position,
					enemy.collision_layer,
					dist,
					enemy.has_method("take_damage")
				])
	
	var targets = _get_targets_in_hitbox()
	if Config.DEBUG_LOGS:
		print("[PlayerCombat] Найдено целей: %d" % targets.size())
		for t in targets:
			print("[PlayerCombat] Цель: %s (группа enemies: %s)" % [t.name, t.is_in_group("enemies")])
	
	var weapon_data = _get_weapon_data()
	weapon_data["damage_mult"] = _last_combo_data.get("damage_mult", 1.0)
	
	if targets.is_empty():
		if Config.DEBUG_LOGS:
			print("[PlayerCombat] Удар в воздух")
	else:
		for target in targets:
			_deal_damage_to(target, _last_combo_data.get("id", default_combo), weapon_data)


func _on_attack_end() -> void:
	"""Вызывается из AnimationPlayer method track в конце атаки"""
	if Config.DEBUG_LOGS:
		print("[PlayerCombat] === _on_attack_end ===")
	
	# Выключаем хитбокс
	if _hitbox:
		_hitbox.monitoring = false
		if Config.DEBUG_LOGS:
			print("[PlayerCombat] Хитбокс деактивирован")
	else:
		if Config.DEBUG_LOGS:
			print("[PlayerCombat] Ошибка: хитбокс не найден")
	
	# Очищаем данные комбо (но НЕ меняем _is_attacking - это делает _on_animation_finished)
	_last_combo_data.clear()


func _reset_combo() -> void:
	_current_sequence.clear()
	_combo_buffer_timer = 0.0


# ===== Блок =====

func handle_block_input(is_pressed: bool) -> void:
	"""Вызывается из player.gd при нажатии/отпускании кнопки блока"""
	if not _weapon_active:
		return
	
	if is_pressed:
		start_block()
	else:
		stop_block()


func start_block() -> void:
	if _is_attacking or is_blocking:
		return
	
	is_blocking = true
	is_parrying = true
	_parry_timer = parry_window
	
	# Пытаемся проиграть анимацию блока (если есть)
	if _animation_player and _animation_player.has_animation("block"):
		_animation_player.play("block")
	
	if Config.DEBUG_LOGS:
		print("[PlayerCombat] Блок активирован | окно парирования: %.2f сек" % parry_window)


func stop_block() -> void:
	is_blocking = false
	is_parrying = false
	_parry_timer = 0.0
	
	if _animation_player and _animation_player.current_animation == "block":
		_animation_player.stop()
	
	if Config.DEBUG_LOGS:
		print("[PlayerCombat] Блок снят")


func try_parry(attacker: Node) -> bool:
	"""Вызывается извне, когда игрок получает урон в блоке"""
	if not is_blocking:
		return false
	
	if is_parrying and _parry_timer > 0.0:
		_on_parry_success(attacker)
		return true
	else:
		_on_block_hit(attacker)
		return false


func _on_parry_success(attacker: Node) -> void:
	if Config.DEBUG_LOGS:
		print("[PlayerCombat] ПАРИРОВАНИЕ! Атакующий: %s" % attacker.name)
	
	if _player.has_method("restore_stamina"):
		_player.restore_stamina(parry_stamina_reward)
	
	if attacker.has_method("apply_status_effect"):
		attacker.apply_status_effect("stunned")
	
	_combat_profile.add_score(&"fencer", 3.0)
	
	is_parrying = false
	_parry_timer = 0.0


func _on_block_hit(attacker: Node) -> void:
	if Config.DEBUG_LOGS:
		print("[PlayerCombat] Блок: удар поглощён от %s" % attacker.name)
	
	if _player.has_method("consume_stamina"):
		if not _player.consume_stamina(block_stamina_cost):
			stop_block()
			if Config.DEBUG_LOGS:
				print("[PlayerCombat] Блок сломан: недостаточно стамины")
	
	_combat_profile.add_score(&"gladiator", 1.0)


# ===== Переключение оружия =====

func toggle_weapon() -> void:
	"""Убрать/достать меч"""
	if _is_attacking or is_blocking:
		return
	
	_weapon_active = not _weapon_active
	
	# Пытаемся проиграть анимацию (если есть)
	if _animation_player:
		var anim = "weaponON" if _weapon_active else "weaponOFF"
		if _animation_player.has_animation(anim):
			_animation_player.play(anim)
	
	if Config.DEBUG_LOGS:
		print("[PlayerCombat] Оружие: %s (тип комбо: %s)" % [
			"достали" if _weapon_active else "убрали",
			"weapon" if _weapon_active else "unarmed"
		])


# ===== Вспомогательные методы =====

func _get_targets_in_hitbox() -> Array[Node]:
	if not _hitbox:
		return []
	
	var targets: Array[Node] = []
	
	# Ищем CharacterBody2D врагов напрямую (обходим Hurtbox)
	var overlapping_bodies: Array[Node2D] = _hitbox.get_overlapping_bodies()
	
	if Config.DEBUG_LOGS:
		print("[PlayerCombat] get_overlapping_bodies() вернул: %d" % overlapping_bodies.size())
		for body in overlapping_bodies:
			if is_instance_valid(body):
				print("[PlayerCombat]   Body: %s (groups: %s, has_take_damage: %s)" % [
					body.name,
					body.get_groups(),
					body.has_method("take_damage")
				])
	
	for body in overlapping_bodies:
		if not is_instance_valid(body) or body == _player:
			continue
		
		if body.is_in_group("enemies") and body.has_method("take_damage"):
			targets.append(body)
			if Config.DEBUG_LOGS:
				var dist: float = _hitbox.global_position.distance_to(body.global_position)
				print("[PlayerCombat] ✅ Найден враг (body): %s | dist: %.1f" % [
					body.name,
					dist
				])
	
	return targets


# УДАЛЕНО: больше не используется после перехода на get_overlapping_bodies()
# func _resolve_target(node: Node) -> Node:
# 	"""Находит сущность с методом take_damage, поднимаясь по иерархии"""
# 	if node.has_method("take_damage"):
# 		return node
# 	
# 	var p: Node = node.get_parent()
# 	while p:
# 		if p.has_method("take_damage"):
# 			return p
# 		p = p.get_parent()
# 	
# 	return null


# УДАЛЕНО: проверка is_in_group("enemies") теперь в _get_targets_in_hitbox()
# func _is_hostile(target: Node) -> bool:
# 	"""Проверяет, является ли цель врагом (через группу enemies)"""
# 	return target.is_in_group("enemies")


func _get_weapon_data() -> Dictionary:
	return {
		"base_damage": weapon_damage,
		"crit_chance": weapon_crit_chance
	}


func _deal_damage_to(defender: Node, combo_id: String, weapon_data: Dictionary) -> void:
	"""Наносит урон цели через CombatManager или fallback"""
	if not defender or not is_instance_valid(defender):
		return
	
	# Пытаемся использовать CombatManager
	if _combat_manager and _combat_manager.has_method("execute_sequence"):
		var result = _combat_manager.execute_sequence(_player, defender, combo_id, weapon_data)
		
		if result and result.success:
			if Config.DEBUG_LOGS:
				print("[PlayerCombat] [CombatManager] %s → %s | %.1f урона%s" % [
					combo_id,
					defender.name,
					result.damage,
					" [КРИТ]" if result.crit else ""
				])
			return
	
	# Fallback: прямой урон без CombatManager
	if not defender.has_method("take_damage"):
		if Config.DEBUG_LOGS:
			print("[PlayerCombat] [Fallback] Цель %s не имеет метода take_damage()" % defender.name)
		return
	
	# Получаем данные комбо для damage_mult
	var damage_mult = 1.0
	if _last_combo_data.has("damage_mult"):
		damage_mult = _last_combo_data.get("damage_mult", 1.0)
	else:
		# Пытаемся получить из ComboManager
		if _combo_manager and _combo_manager.has_method("get_combo"):
			var combo_data = _combo_manager.get_combo(combo_id)
			if not combo_data.is_empty():
				damage_mult = combo_data.get("damage_mult", 1.0)
	
	var base_damage = weapon_data.get("base_damage", weapon_damage)
	var damage = base_damage * damage_mult
	
	# Применяем урон
	defender.take_damage(int(round(damage)))
	
	if Config.DEBUG_LOGS:
		print("[PlayerCombat] [Fallback] %s → %s | %.1f урона (base: %.1f × mult: %.2f)" % [
			combo_id,
			defender.name,
			damage,
			base_damage,
			damage_mult
		])


# ===== Публичное API =====

func is_attacking() -> bool:
	return _is_attacking


func is_on_cooldown() -> bool:
	return _cooldown_timer > 0.0


func can_attack() -> bool:
	return not _is_attacking and not is_blocking and _cooldown_timer <= 0.0


func set_weapon_stats(damage: float, crit: float) -> void:
	weapon_damage = damage
	weapon_crit_chance = crit
	if Config.DEBUG_LOGS:
		print("[PlayerCombat] Оружие: урон=%.1f, крит=%.2f" % [damage, crit])


func get_combat_profile() -> CombatProfile:
	return _combat_profile
