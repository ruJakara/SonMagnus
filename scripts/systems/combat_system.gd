# scripts/systems/combat_system.gd
# Основная логика боевой системы.
# Использует CombatManager (Autoload) для инициации и расчетов.

class_name CombatSystem
extends Node

## @brief Инициализация класса CombatSystem.
func _ready():
	print("CombatSystem.gd загружен.")

## @brief Запускает боевое взаимодействие между двумя сущностями.
## @param attacker: Сущность, которая атакует.
## @param defender: Сущность, которая защищается.
## @param weapon_data: Данные об оружии, используемом в атаке.
func perform_attack(attacker: BaseEntity, defender: BaseEntity, weapon_data: Dictionary):
	# Делегируем расчет урона глобальному менеджеру
	var damage = CombatManager.calculate_damage(attacker, defender, weapon_data)
	
	print("%s атакует %s, нанося %d урона." % [attacker.entity_name, defender.entity_name, damage])
	
	if defender.health == 0:
		print("%s был повержен!" % defender.entity_name)
		# TODO: Испустить сигнал о смерти и начислить опыт
	
# TODO: Добавить логику для очередности ходов (если пошаговая система)
# TODO: Добавить логику для обработки критических состояний (оглушение, отравление)
