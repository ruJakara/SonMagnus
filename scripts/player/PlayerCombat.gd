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
	_hitbox.monitorable = false


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
	"""Запускает анимацию атаки и активирует хитбокс"""
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
	
	_is_attacking = true
	_combo_buffer_timer = combo_data.get("combo_window", COMBO_BUFFER_WINDOW)
	
	if Config.DEBUG_LOGS:
		print("[PlayerCombat] Комбо: %s | Анимация: %s | Последовательность: %s" % [
			combo_data.get("id", "unknown"), anim_name, _current_sequence
		])
	
	# Проигрываем анимацию
	if _animation_player.has_animation(anim_name):
		_animation_player.play(anim_name)
	else:
		push_warning("[PlayerCombat] Анимация '%s' не найдена!" % anim_name)
		_is_attacking = false
		_reset_combo()
		return
	
	# Включаем хитбокс через windup
	await get_tree().create_timer(windup_time).timeout
	if _hitbox and _is_attacking:
		_hitbox.monitoring = true
		_execute_hit_detection(combo_data)


func _execute_hit_detection(combo_data: Dictionary) -> void:
	"""Проверяет попадания в текущий момент"""
	var targets = _get_targets_in_hitbox()
	var weapon_data = _get_weapon_data()
	weapon_data["damage_mult"] = combo_data.get("damage_mult", 1.0)
	
	if targets.is_empty():
		if Config.DEBUG_LOGS:
			print("[PlayerCombat] Удар в воздух")
	else:
		for target in targets:
			_deal_damage_to(target, combo_data.get("id", default_combo), weapon_data)
	
	# Выключаем хитбокс
	if _hitbox:
		_hitbox.monitoring = false


func _on_animation_finished(anim_name: StringName) -> void:
	"""Вызывается AnimationPlayer при окончании любой анимации"""
	if anim_name.begins_with("attack") or anim_name.begins_with("punch") or \
	   anim_name.begins_with("kick") or anim_name.begins_with("charge") or \
	   anim_name.begins_with("dash"):
		_is_attacking = false
		_cooldown_timer = attack_cooldown
		
		# Если в буфере есть нажатия — продолжаем комбо
		if _combo_buffer_timer > 0.0 and _current_sequence.size() > 0:
			_execute_combo()
		else:
			_reset_combo()


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
	for body in _hitbox.get_overlapping_bodies():
		if not is_instance_valid(body) or body == _player:
			continue
		
		var defender = _resolve_target(body)
		if defender and _is_hostile(defender):
			targets.append(defender)
	
	return targets


func _resolve_target(body: Node) -> Node:
	if body.has_method("take_damage"):
		return body
	if body.get_parent() and body.get_parent().has_method("take_damage"):
		return body.get_parent()
	return null


func _is_hostile(target: Node) -> bool:
	if not target.has_method("get_faction"):
		return false
	
	var target_faction = target.get_faction()
	if _player.has_method("get_faction"):
		var player_faction = _player.get_faction()
		if target.has_method("is_hostile_to"):
			return target.is_hostile_to(player_faction)
	
	return target_faction != &"player"


func _get_weapon_data() -> Dictionary:
	return {
		"base_damage": weapon_damage,
		"crit_chance": weapon_crit_chance
	}


func _deal_damage_to(defender: Node, combo_id: String, weapon_data: Dictionary) -> void:
	if not _combat_manager:
		return
	
	var result = _combat_manager.execute_sequence(_player, defender, combo_id, weapon_data)
	
	if result and result.success and Config.DEBUG_LOGS:
		print("[PlayerCombat] %s → %s | %.1f урона%s" % [
			combo_id,
			defender.name,
			result.damage,
			" [КРИТ]" if result.crit else ""
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
