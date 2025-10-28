# scripts/entities/base_entity.gd
# Базовый класс для всех игровых сущностей (игрока, NPC, монстров).
# Содержит общие свойства и методы, такие как здоровье, уровень, получение урона.

class_name BaseEntity
extends CharacterBody2D # Изменено на 2D по запросу пользователя

## Сигнал, который испускается при изменении здоровья сущности.
signal health_changed(new_health: int, max_health: int)
## Сигнал, который испускается при смерти сущности.
signal died

## Внутреннее поле для здоровья (backing field).
var _health: int = 100

## Максимальное здоровье сущности.
var max_health: int = 100
## Уровень сущности.
var level: int = 1
## Имя сущности.
var entity_name: String = "Unnamed Entity"

## Публичное свойство health с геттером/сеттером.
var health: int:
	get:
		return _health
	set(value):
		_health = clamp(value, 0, max_health)
		emit_signal("health_changed", _health, max_health)
		if _health == 0:
			emit_signal("died")

## @brief Инициализирует сущность с заданными параметрами.
## @param name: Имя сущности.
## @param max_hp: Максимальное здоровье.
## @param lvl: Уровень.
func initialize(name: String, max_hp: int, lvl: int) -> void:
	entity_name = name
	max_health = max_hp
	health = max_hp
	level = lvl

## @brief Принимает урон.
## @param damage_amount: Количество урона.
func take_damage(damage_amount: int) -> void:
	health -= damage_amount
	print("%s получил %d урона. Здоровье: %d/%d" % [entity_name, damage_amount, health, max_health])

## @brief Возвращает значение защиты сущности от определенного типа урона.
## @param damage_type: Тип урона (например, "physical", "magic").
## @return: Значение защиты.
func get_defense(damage_type: String) -> int:
	# TODO: Реализовать логику расчета защиты (броня, резисты)
	# Возвращаем простейшую заглушку для работы CombatManager V2
	return level * 2

# TODO: Добавить метод для получения опыта (gain_experience)
# TODO: Добавить метод для применения статусного эффекта (apply_status_effect)

