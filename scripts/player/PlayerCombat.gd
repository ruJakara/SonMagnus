# scripts/player/PlayerCombat.gd
# Фасад для боевой системы игрока - делегирует в компоненты

class_name PlayerCombat
extends Node

# ===== Компоненты =====
@onready var state: PlayerCombatState = $State
@onready var stance: PlayerStanceController = $Stance
@onready var slide: PlayerSlideController = $Slide
@onready var attack: PlayerAttackController = $Attack
@onready var block: PlayerBlockController = $Block

# ===== Публичное свойство для совместимости =====
var is_blocking: bool:
	get:
		return state.is_blocking if state else false


# ===== Публичное API (делегирует в компоненты) =====

func request_toggle_stance() -> void:
	"""Q: Переключение стойки RELAX ↔ FIGHT."""
	stance.request_toggle_stance()


func request_attack(button: String) -> void:
	"""ЛКМ/ПКМ: Запрос атаки."""
	attack.request_attack(button)


func request_block(is_pressed: bool) -> void:
	"""Space: Блок (hold)."""
	block.request_block(is_pressed)


func request_slide() -> void:
	"""Shift: Подкат/скольжение."""
	slide.request_slide()


func try_parry(attacker: Node) -> bool:
	"""Вызывается извне, когда игрок получает урон в блоке"""
	return block.try_parry(attacker)


func is_attacking() -> bool:
	return state.is_attacking()


func is_on_cooldown() -> bool:
	return state.is_on_cooldown()


func can_attack() -> bool:
	return state.can_attack()


func set_weapon_stats(damage: float, crit: float) -> void:
	attack.set_weapon_stats(damage, crit)


func get_combat_profile() -> CombatProfile:
	return block.get_combat_profile()

func _on_attack_frame() -> void:
	if attack:
		attack._on_attack_frame()

func _on_attack_end() -> void:
	if attack:
		attack._on_attack_end()
