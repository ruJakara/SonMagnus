# scripts/player/components/player_combat_state.gd
# Хранит все состояния боевой системы игрока

class_name PlayerCombatState
extends Node

# ===== Состояния =====
var is_blocking: bool = false
var is_parrying: bool = false
var _is_attacking: bool = false
var _is_sliding: bool = false
var _is_toggling_stance: bool = false

# ===== Таймеры =====
var _cooldown_timer: float = 0.0
var _parry_timer: float = 0.0
var _slide_timer: float = 0.0

# ===== Комбо =====
var _current_sequence: Array[String] = []
var _combo_buffer_timer: float = 0.0
var _last_combo_data: Dictionary = {}
var _active_attack_request: Variant = null  # хранит ссылку на CombatManager.AttackRequest
var _active_attack_anim: StringName = &""

# ===== Hit Detection =====
var _hit_targets: Array[Node] = []
var _hit_window_open: bool = false

# ===== Ссылки =====
var _player: Node = null


func _ready() -> void:
	_player = get_parent().get_parent()  # PlayerCombat -> Player


func _process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
	
	if _parry_timer > 0.0:
		_parry_timer -= delta
		if _parry_timer <= 0.0:
			is_parrying = false
	
	if _combo_buffer_timer > 0.0:
		_combo_buffer_timer -= delta
	
	if _slide_timer > 0.0:
		_slide_timer -= delta


# ===== Публичные проверки =====

func can_attack() -> bool:
	"""Может ли игрок атаковать сейчас?"""
	return not _is_toggling_stance and not _is_sliding and not is_blocking and not _is_attacking


func can_slide() -> bool:
	"""Может ли игрок сделать подкат сейчас?"""
	return not _is_attacking and not is_blocking and not _is_toggling_stance and not _is_sliding


func can_block() -> bool:
	"""Может ли игрок блокировать сейчас?"""
	if not _player:
		return false
	return _player.stance == _player.Stance.FIGHT and not _is_attacking and not _is_sliding and not _is_toggling_stance


func can_toggle_stance() -> bool:
	"""Может ли игрок переключить стойку сейчас?"""
	return not _is_attacking and not is_blocking and not _is_sliding and not _is_toggling_stance


func is_attacking() -> bool:
	return _is_attacking


func is_on_cooldown() -> bool:
	return _cooldown_timer > 0.0


# ===== Управление комбо =====

func reset_combo() -> void:
	_current_sequence.clear()
	_combo_buffer_timer = 0.0
	_active_attack_request = null
	_active_attack_anim = &""
	_last_combo_data.clear()


func add_to_sequence(button: String) -> void:
	_current_sequence.append(button)


func get_sequence() -> Array[String]:
	return _current_sequence


func set_combo_buffer(duration: float) -> void:
	_combo_buffer_timer = duration


func has_combo_buffer() -> bool:
	return _combo_buffer_timer > 0.0
