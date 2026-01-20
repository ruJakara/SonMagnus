# scripts/player/components/player_attack_controller.gd
# Управляет атаками и комбо игрока

class_name PlayerAttackController
extends Node

# ===== Настройки атаки =====
@export var default_combo: String = "sword_basic_l"
@export var attack_cooldown: float = 0.8
@export var weapon_damage: float = 10.0
@export var weapon_crit_chance: float = 0.15

const COMBO_BUFFER_WINDOW: float = 0.5

# ===== Ссылки =====
var _player: Node = null
var _state: PlayerCombatState = null
var _hitbox: Area2D = null
var _animation_player: AnimationPlayer = null
var _combat_manager: Node = null
var _combo_manager: Node = null


func _ready() -> void:
	var combat = get_parent()
	_player = combat.get_parent()
	_state = combat.get_node("State")
	set_process(true)
	
	_combat_manager = get_node_or_null("/root/CombatManager")
	if not _combat_manager:
		push_warning("[AttackController] CombatManager не найден")
	
	_combo_manager = get_node_or_null("/root/ComboManager")
	if not _combo_manager:
		push_warning("[AttackController] ComboManager не найден")
	
	_animation_player = _player.get_node_or_null("AnimationPlayer")
	if not _animation_player:
		push_warning("[AttackController] AnimationPlayer не найден")
	else:
		_animation_player.animation_finished.connect(_on_animation_finished)
	
	_setup_hitbox()


func _setup_hitbox() -> void:
	_hitbox = _player.get_node_or_null("zone/Hitbox") as Area2D
	if not _hitbox:
		push_warning("[AttackController] Area2D 'Hitbox' не найдена у игрока")
		return
	
	# Держим monitoring включённым постоянно, окно удара контролируем логикой
	_hitbox.monitoring = true
	_hitbox.monitorable = true
	_hitbox.collision_mask = 176  # 16 + 32 + 128 (enemy_body + hurtbox + back)
	
	# Подключаем сигналы для событийной обработки попаданий
	_hitbox.body_entered.connect(_on_hitbox_body_entered)
	_hitbox.area_entered.connect(_on_hitbox_area_entered)
	
	if Config.DEBUG_LOGS:
		print("[AttackController] Hitbox настроен с событийной моделью")


func request_attack(button: String) -> void:
	"""ЛКМ/ПКМ: Запрос атаки."""
	# Если атакуем — буферизуем нажатие
	if _state._is_attacking:
		_state.add_to_sequence(button)
		_state.set_combo_buffer(COMBO_BUFFER_WINDOW)
		_state.mark_buffered_input()
		if Config.DEBUG_LOGS:
			print("[AttackController] Буферизация: %s → %s" % [button, _state.get_sequence()])
		return
	
	if not _state.can_attack():
		if Config.DEBUG_LOGS:
			print("[AttackController] Атака заблокирована")
		return
	
	# Иначе добавляем в последовательность и ищем комбо
	_state.add_to_sequence(button)
	_execute_combo()

func _process(_delta: float) -> void:
	if not _state:
		return
	
	if _state._is_attacking:
		return
	
	if _state.is_on_cooldown():
		return
	
	var sequence = _state.get_sequence()
	if _state.has_combo_buffer() and _state.has_buffered_input() and sequence.size() > 0:
		_state.set_combo_buffer(0.0)
		_state.clear_buffered_input()
		_execute_combo()
	elif not _state.has_combo_buffer() and sequence.size() > 0:
		_state.clear_buffered_input()
		_state.reset_combo()

func _execute_combo() -> void:
	"""Ищет комбо по хвосту последовательности и запускает анимацию"""
	if not _combo_manager:
		_state.reset_combo()
		return
	
	var sequence = _state.get_sequence()
	if sequence.is_empty():
		return
	
	var weapon_type := "unarmed"
	if _player.stance == _player.Stance.FIGHT:
		weapon_type = "weapon"
	
	var combo_id := ""
	var used_tail_len := 0
	for len in range(sequence.size(), 0, -1):
		var start_index = sequence.size() - len
		var tail = sequence.slice(start_index, sequence.size())
		var candidate = _combo_manager.find_combo_by_sequence(tail, weapon_type)
		if not candidate.is_empty():
			combo_id = candidate
			used_tail_len = len
			break
	
	if combo_id.is_empty():
		if Config.DEBUG_LOGS:
			print("[AttackController] Комбо не найдено для %s (%s)" % [sequence, weapon_type])
		_state.reset_combo()
		return
	
	var combo_data = _combo_manager.get_combo(combo_id)
	if combo_data.is_empty():
		if Config.DEBUG_LOGS:
			print("[AttackController] Данные комбо '%s' не найдены" % combo_id)
		_state.reset_combo()
		return
	
	var anim_name = combo_data.get("weapon_animation", combo_data.get("animation", ""))
	if anim_name.is_empty():
		if Config.DEBUG_LOGS:
			print("[AttackController] Нет анимации для комбо: %s" % combo_id)
		_state.reset_combo()
		return
	
	if _start_attack_animation(anim_name, combo_data):
		_state.consume_sequence(used_tail_len)

func _start_attack_animation(anim_name: String, combo_data: Dictionary) -> bool:
	"""Запускает анимацию атаки (удар происходит по method track в анимации)"""
	if not _animation_player:
		_state.reset_combo()
		return false
	
	var combo_id: String = combo_data.get("id", default_combo)
	var weapon_data := _get_weapon_data()
	
	if not _combat_manager or not _combat_manager.has_method("build_attack_request"):
		push_warning("[AttackController] CombatManager не готов, урон будет рассчитан напрямую")
		_state._active_attack_request = null
	else:
		var request = _combat_manager.build_attack_request(_player, combo_id, weapon_data)
		if request == null:
			if Config.DEBUG_LOGS:
				print("[AttackController] Не удалось создать запрос атаки для %s" % combo_id)
			_state.reset_combo()
			return false
		
		if not _combat_manager.validate_attack_request(request):
			if Config.DEBUG_LOGS:
				print("[AttackController] Комбо %s недоступно" % combo_id)
			_state.reset_combo()
			return false
		
		request.meta["input_sequence"] = _state.get_sequence().duplicate()
		request.meta["started_at"] = Time.get_ticks_msec()
		_state._active_attack_request = request
	
	# Сохраняем данные комбо для _on_attack_frame
	_state._last_combo_data = combo_data.duplicate(true)
	_state._active_attack_anim = anim_name
	
	_state._is_attacking = true
	# НЕ ставим combo_buffer здесь — только при буферизации реального ввода
	
	if Config.DEBUG_LOGS:
		print("[AttackController] Атака: %s (%s)" % [combo_id, _state.get_sequence()])
	
	# Проигрываем анимацию (удар произойдет через method track _on_attack_frame)
	if _animation_player.has_animation(anim_name):
		_animation_player.play(anim_name)
		# Очистить sequence ПОСЛЕ успешного запуска — каждая атака начинается с чистого листа
		_state._current_sequence.clear()
	else:
		push_warning("[AttackController] Анимация '%s' не найдена!" % anim_name)
		_state._is_attacking = false
		_state.reset_combo()
		_state._active_attack_request = null
		return false

	return true


func _on_animation_finished(anim_name: StringName) -> void:
	"""Вызывается AnimationPlayer при окончании анимации атаки"""
	if _state._active_attack_anim != StringName() and anim_name == _state._active_attack_anim:
		_finalize_attack_cycle()


func _finalize_attack_cycle() -> void:
	if not _state._is_attacking:
		return
	
	_state._is_attacking = false
	_state._cooldown_timer = attack_cooldown
	_state._active_attack_anim = StringName()
	_state._active_attack_request = null
	
	if Config.DEBUG_LOGS:
		print("[AttackController] Атака завершена | Буфер: %.2f сек" % _state._combo_buffer_timer)


# ===== Hit Detection (Event-based, NO await) =====

func _on_attack_frame() -> void:
	"""Вызывается из AnimationPlayer method track в момент удара анимации"""
	# Delegate to FSM if available and in attack state
	var fsm = _player.get_node_or_null("PlayerStateMachine")
	if fsm and fsm.has_method("on_attack_frame"):
		fsm.on_attack_frame()
		# Also run legacy logic if old state is active
		if not _state._is_attacking:
			return
	
	if not _state._is_attacking:
		return
	
	if not _hitbox:
		push_warning("[AttackController] Хитбокс не найден")
		return
	
	if _is_shoot_combo():
		_state._hit_targets.clear()
		_state._hit_window_open = false
		_perform_shoot_stub()
		return
	
	# Открываем окно удара
	_state._hit_targets.clear()
	_state._hit_window_open = true
	
	if _state._active_attack_request:
		_state._active_attack_request.meta["hit_frame_time"] = Time.get_ticks_msec()
	
	if Config.DEBUG_LOGS:
		print("[AttackController] Окно удара открыто")
	
	# ОБРАБОТКА УЖЕ ПЕРЕКРЫВАЮЩИХСЯ ОБЪЕКТОВ
	# (body_entered не сработает для тех, кто уже внутри зоны)
	var overlapping_bodies = _hitbox.get_overlapping_bodies()
	for body in overlapping_bodies:
		if body == _player:
			continue
		if not body.is_in_group("enemies") or not body.has_method("take_damage"):
			continue
		if body in _state._hit_targets:
			continue
		
		_state._hit_targets.append(body)
		_apply_hit_to_target(body)
	
	var overlapping_areas = _hitbox.get_overlapping_areas()
	for area in overlapping_areas:
		var enemy = area.get_parent()
		if not enemy or enemy == _player:
			continue
		if not enemy.is_in_group("enemies") or not enemy.has_method("take_damage"):
			continue
		if enemy in _state._hit_targets:
			continue
		
		_state._hit_targets.append(enemy)
		_apply_hit_to_target(enemy)


func _on_attack_end() -> void:
	"""Вызывается из AnimationPlayer method track в конце окна удара"""
	# Delegate to FSM if available
	var fsm = _player.get_node_or_null("PlayerStateMachine")
	if fsm and fsm.has_method("on_attack_end"):
		fsm.on_attack_end()
	
	_state._hit_window_open = false
	
	if Config.DEBUG_LOGS:
		if _state._hit_targets.is_empty():
			print("[AttackController] Промах")
		else:
			print("[AttackController] Окно удара закрыто")
	
	_state._hit_targets.clear()
	_finalize_attack_cycle()


func _on_hitbox_body_entered(body: Node2D) -> void:
	"""Вызывается когда тело входит в хитбокс во время удара."""
	if not _state._hit_window_open:
		return
	
	if body == _player:
		return
	
	if not body.is_in_group("enemies") or not body.has_method("take_damage"):
		return
	
	if body in _state._hit_targets:
		return
	
	# Добавляем в список целей
	_state._hit_targets.append(body)
	
	_apply_hit_to_target(body)


func _on_hitbox_area_entered(area: Area2D) -> void:
	"""Вызывается когда область входит в хитбокс (для hurtbox врагов)."""
	if not _state._hit_window_open:
		return
	
	# Пытаемся найти родителя с методом take_damage
	var enemy = area.get_parent()
	if not enemy or enemy == _player:
		return
	
	if not enemy.is_in_group("enemies") or not enemy.has_method("take_damage"):
		return
	
	if enemy in _state._hit_targets:
		return
	
	# Добавляем в список целей
	_state._hit_targets.append(enemy)
	
	_apply_hit_to_target(enemy)


# ===== Вспомогательные методы =====

func _apply_hit_to_target(target: Node) -> void:
	if not is_instance_valid(target):
		return
	
	var combo_id: String = _state._last_combo_data.get("id", default_combo)
	var weapon_data := _get_weapon_data()
	weapon_data["damage_mult"] = _state._last_combo_data.get("damage_mult", 1.0)
	
	var is_backstab := _is_backstab_target(target)
	
	if _combat_manager and _state._active_attack_request and _combat_manager.has_method("execute_request"):
		var request = _combat_manager.clone_attack_request(_state._active_attack_request)
		if request:
			request.defender = target
			request.weapon_data = weapon_data
			request.flags["is_backstab"] = is_backstab
			request.meta["hit_position"] = target.global_position
			request.meta["hit_time"] = Time.get_ticks_msec()
			request.meta["hit_index"] = _state._hit_targets.size()
			
			var result = _combat_manager.execute_request(request)
			if result and result.success:
				if Config.DEBUG_LOGS:
					print("[AttackController] %s → %s | %.1f dmg%s" % [
						request.combo_id,
						target.name,
						result.damage,
						" [BACKSTAB]" if is_backstab else ""
					])
				return
	
	_deal_damage_to(target, combo_id, weapon_data, is_backstab)


func _is_backstab_target(target: Node) -> bool:
	if not _hitbox:
		return false
	var back_area = target.get_node_or_null("Back")
	if back_area and back_area is Area2D:
		return _hitbox.overlaps_area(back_area)
	return false


func _is_shoot_combo() -> bool:
	if _state._last_combo_data.is_empty():
		return false
	var combo_type = str(_state._last_combo_data.get("type", ""))
	if combo_type == "shoot":
		return true
	var tags = _state._last_combo_data.get("tags", [])
	if tags is Array or tags is PackedStringArray:
		return "shoot" in tags
	return false


func _perform_shoot_stub() -> void:
	if Config.DEBUG_LOGS:
		print("[AttackController] Shoot frame (stub)")


func _get_weapon_data() -> Dictionary:
	return {
		"base_damage": weapon_damage,
		"crit_chance": weapon_crit_chance
	}


func _deal_damage_to(defender: Node, combo_id: String, weapon_data: Dictionary, is_backstab: bool = false) -> void:
	"""Фолбэк: прямой урон, если CombatManager недоступен"""
	if not defender or not is_instance_valid(defender):
		return
	
	if not defender.has_method("take_damage"):
		return
	
	var damage_mult = weapon_data.get("damage_mult", 1.0)
	var base_damage = weapon_data.get("base_damage", weapon_damage)
	var damage = base_damage * damage_mult
	
	# Применяем бэкстаб
	if is_backstab and defender.get_method_argument_count("take_damage") >= 3:
		defender.take_damage(int(round(damage)), _player, true)
	else:
		defender.take_damage(int(round(damage)))
	
	if Config.DEBUG_LOGS:
		print("[AttackController] %s → %s | %.1f урона%s" % [
			combo_id, defender.name, damage,
			" [BACKSTAB]" if is_backstab else ""
		])


# ===== Публичное API =====

func set_weapon_stats(damage: float, crit: float) -> void:
	weapon_damage = damage
	weapon_crit_chance = crit
