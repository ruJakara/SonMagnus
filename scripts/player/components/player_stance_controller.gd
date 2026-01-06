# scripts/player/components/player_stance_controller.gd
# Управляет переключением стойки игрока (RELAX ↔ FIGHT)

class_name PlayerStanceController
extends Node

# ===== Ссылки =====
var _player: Node = null
var _state: PlayerCombatState = null
var _animation_player: AnimationPlayer = null


func _ready() -> void:
	var combat = get_parent()
	_player = combat.get_parent()
	_state = combat.get_node("State")
	_animation_player = _player.get_node_or_null("AnimationPlayer")
	
	if _animation_player:
		_animation_player.animation_finished.connect(_on_animation_finished)


func request_toggle_stance() -> void:
	"""Q: Переключение стойки RELAX ↔ FIGHT."""
	if not _state.can_toggle_stance():
		if Config.DEBUG_LOGS:
			print("[StanceController] Переключение стойки заблокировано")
		return
	
	_state._is_toggling_stance = true
	_player.lock_attack = true
	_player.lock_block = true
	_player.lock_slide = true
	_player.lock_stance_toggle = true
	
	# Определяем анимацию в зависимости от текущей стойки
	var anim_name := "weaponOFF" if _player.stance == _player.Stance.FIGHT else "weaponON"
	
	if Config.DEBUG_LOGS:
		print("[StanceController] Переключение стойки: %s" % anim_name)
	
	if _animation_player and _animation_player.has_animation(anim_name):
		_animation_player.play(anim_name)
	else:
		# Если анимации нет - переключаем сразу
		_finish_stance_toggle()


func _on_animation_finished(anim_name: StringName) -> void:
	"""Обрабатываем завершение анимаций переключения стойки."""
	if anim_name == "weaponON" or anim_name == "weaponOFF":
		_finish_stance_toggle()


func _finish_stance_toggle() -> void:
	"""Завершает переключение стойки после окончания анимации."""
	# Меняем стойку
	if _player.stance == _player.Stance.RELAX:
		_player.stance = _player.Stance.FIGHT
	else:
		_player.stance = _player.Stance.RELAX
	
	# Снимаем блокировки
	_state._is_toggling_stance = false
	_player.lock_attack = false
	_player.lock_block = false
	_player.lock_slide = false
	_player.lock_stance_toggle = false
	
	if Config.DEBUG_LOGS:
		print("[StanceController] Стойка изменена: %s" % ("FIGHT" if _player.stance == _player.Stance.FIGHT else "RELAX"))

