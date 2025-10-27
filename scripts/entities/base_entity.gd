# scripts/entities/base_entity.gd
# Базовый класс для всех игровых сущностей (игрока, NPC, монстров).
# Содержит общие свойства и методы, такие как здоровье, уровень, получение урона.

class_name BaseEntity
extends CharacterBody3D # Или CharacterBody2D, в зависимости от типа проекта

## Сигнал, который испускается при изменении здоровья сущности.
signal health_changed(new_health: int, max_health: int)
## Сигнал, который испускается при смерти сущности.
signal died

## Текущее здоровье сущности.
var health: int = 100:
	set(value):
		health = clamp(value, 0, max_health)
		health_changed.emit(health, max_health)
		if health == 0:
			died.emit()

## Максимальное здоровье сущности.
var max_health: int = 100
## Уровень сущности.
var level: int = 1
## Имя сущности.
var entity_name: String = "Unnamed Entity"

## @brief Инициализирует сущность с заданными параметрами.
## @param name: Имя сущности.
## @param max_hp: Максимальное здоровье.
## @param lvl: Уровень.
func initialize(name: String, max_hp: int, lvl: int):
	entity_name = name
	max_health = max_hp
	health = max_hp
	level = lvl

## @brief Принимает урон.
## @param damage_amount: Количество урона.
func take_damage(damage_amount: int):
	health -= damage_amount
	print("%s получил %d урона. Здоровье: %d/%d" % [entity_name, damage_amount, health, max_health])

# TODO: Добавить метод для получения опыта (gain_experience)
# TODO: Добавить метод для применения статусного эффекта (apply_status_effect)

