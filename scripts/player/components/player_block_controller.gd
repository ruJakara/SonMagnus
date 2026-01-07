# scripts/player/components/player_block_controller.gd
# Управляет блоком и парированием

class_name PlayerBlockController
extends Node

# ===== Настройки блока/парирования =====
@export var parry_window: float = 0.3
@export var block_stamina_cost: float = 5.0
@export var parry_stamina_reward: float = 10.0

# ===== Ссылки =====
var _player: Node = null
var _state: PlayerCombatState = null
var _animation_player: AnimationPlayer = null
var _combat_profile: CombatProfile = null


func _ready() -> void:
	var combat = get_parent()
	_player = combat.get_parent()
	_state = combat.get_node("State")
	_animation_player = _player.get_node_or_null("AnimationPlayer")
	_combat_profile = CombatProfile.new()


func request_block(is_pressed: bool) -> void:
	"""Space: Блок (hold)."""
	if not _state.can_block():
		return
	
	if is_pressed:
		start_block()
	else:
		stop_block()


func start_block() -> void:
	if _state._is_attacking or _state.is_blocking:
		return
	
	_state.is_blocking = true
	_state.is_parrying = true
	_state._parry_timer = parry_window
	
	if _animation_player and _animation_player.has_animation("block"):
		_animation_player.play("block")
	
	if Config.DEBUG_LOGS:
		print("[BlockController] Блок активирован")


func stop_block() -> void:
	_state.is_blocking = false
	_state.is_parrying = false
	_state._parry_timer = 0.0
	
	if _animation_player and _animation_player.current_animation == "block":
		_animation_player.stop()
	
	if Config.DEBUG_LOGS:
		print("[BlockController] Блок снят")


func try_parry(attacker: Node) -> bool:
	"""Вызывается извне, когда игрок получает урон в блоке"""
	if not _state.is_blocking:
		return false
	
	if _state.is_parrying and _state._parry_timer > 0.0:
		_on_parry_success(attacker)
		return true
	else:
		_on_block_hit(attacker)
		return false


func _on_parry_success(attacker: Node) -> void:
	if _player.has_method("restore_stamina"):
		_player.restore_stamina(parry_stamina_reward)
	
	if attacker and attacker.has_method("apply_status_effect"):
		attacker.apply_status_effect("stunned")
	
	_combat_profile.add_score(&"fencer", 3.0)
	
	_state.is_parrying = false
	_state._parry_timer = 0.0
	
	if Config.DEBUG_LOGS:
		print("[BlockController] Парирование успешно!")


func _on_block_hit(attacker: Node) -> void:
	if _player.has_method("consume_stamina"):
		if not _player.consume_stamina(block_stamina_cost):
			stop_block()
			if Config.DEBUG_LOGS:
				print("[BlockController] Блок сломан (нет стамины)")
	
	_combat_profile.add_score(&"gladiator", 1.0)
	
	if Config.DEBUG_LOGS:
		print("[BlockController] Блок поглотил урон")


func get_combat_profile() -> CombatProfile:
	return _combat_profile
