# scripts/entities/enemies/states/enemy_state.gd
# Базовый класс для всех состояний врагов
# Реализует паттерн State для AI врагов

class_name EnemyState
extends RefCounted

## Ссылка на мозг врага (владелец state machine)
var brain: Node = null

## Вызывается при входе в состояние
func enter() -> void:
	pass

## Вызывается при выходе из состояния
func exit() -> void:
	pass

## Вызывается каждый кадр (_process)
func update(delta: float) -> void:
	pass

## Вызывается каждый физический кадр (_physics_process)
func physics_update(delta: float) -> void:
	pass

## Вызывается когда враг получает урон
## @param amount: количество полученного урона
## @param attacker: атакующий (Node или null)
func on_damage_taken(amount: int, attacker: Node = null) -> void:
	pass

