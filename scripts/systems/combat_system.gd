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
## @param combo_id: ID комбо (опционально, по умолчанию "basic_attack").
func perform_attack(attacker: BaseEntity, defender: BaseEntity, weapon_data: Dictionary, combo_id: String = "basic_attack"):
	# Проверяем, что CombatManager доступен
	if not CombatManager:
		push_error("CombatManager не найден! Боевая система не работает.")
		return

	# Выполняем атаку через CombatManager.execute_sequence
	var result = CombatManager.execute_sequence(attacker, defender, combo_id, weapon_data)

	# Логируем результат
	if result.success:
		print("%s атакует %s через execute_sequence, нанося %.1f урона." % [attacker.entity_name, defender.entity_name, result.damage])
		if result.crit:
			print("Критический удар!")
	else:
		print("%s атакует %s, но атака не удалась." % [attacker.entity_name, defender.entity_name])

	# Проверка смерти (если defender.health == 0, сработает сигнал died в BaseEntity)
	if defender and defender.health == 0:
		print("%s был повержен!" % defender.entity_name)
		# TODO: Испустить сигнал о смерти и начислить опыт

# TODO: Добавить логику для очередности ходов (если пошаговая система)
# TODO: Добавить логику для обработки критических состояний (оглушение, отравление)
