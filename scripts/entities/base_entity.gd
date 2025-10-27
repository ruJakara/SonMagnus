# scripts/entities/base_entity.gd
# Базовый класс для всех игровых сущностей (игрока, NPC, монстров).
# Содержит общие свойства и методы, такие как здоровье, уровень, получение урона.

extends CharacterBody2D
class_name BaseEntity

## Сигналы
signal health_changed(new_health: int, max_health: int)
signal died

## Параметры
var max_health: int = 100
var health: int = 100:
	set(value):
		health = clamp(value, 0, max_health)
		health_changed.emit(health, max_health)
		if health == 0:
			died.emit()

var level: int = 1
var entity_name: String = "Unnamed Entity"

## Инициализация сущности
func initialize(name: String, max_hp: int, lvl: int) -> void:
	entity_name = name
	max_health = max_hp
	health = max_hp
	level = lvl

## Получение урона
func take_damage(damage_amount: int) -> void:
	health -= damage_amount
	print("%s получил %d урона. Здоровье: %d/%d" % [entity_name, damage_amount, health, max_health])

## Возвращает значение защиты (заглушка для CombatManager)
func get_defense(damage_type: String) -> int:
	# TODO: Реализовать логику расчета защиты (броня, резисты)
	# Возвращаем простейшую заглушку для работы CombatManager V2
	return level * 2

# TODO: Добавить метод для получения опыта (gain_experience)
# TODO: Добавить метод для применения статусного эффекта (apply_status_effect)
