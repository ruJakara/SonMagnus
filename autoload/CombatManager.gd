# autoload/CombatManager.gd
# Менеджер боевой системы. Отвечает за расчет урона, инициацию боя и управление боевыми событиями.
# Подключается как Autoload с именем "CombatManager".

extends Node

## @brief Инициализация класса CombatManager.
func _ready():
		if Config.DEBUG_LOGS:
			print_debug("[CombatManager] Загружен.")
		if Config.COMBAT_V2_ENABLED:
			print_debug("[CombatManager] Используется Боевая Система V2.")

## @brief Рассчитывает урон, наносимый атакующим защитнику.
## @param attacker: Объект атакующего (BaseEntity или производный).
## @param defender: Объект защитника (BaseEntity или производный).
## @param weapon_data: Словарь с данными об оружии (например, {"base_damage": 10, "crit_chance": 0.1}).
## @return: Рассчитанное значение урона.
func calculate_damage(attacker: Node, defender: Node, weapon_data: Dictionary) -> int:
	# Проверка, что attacker и defender являются сущностями
	if not attacker is BaseEntity or not defender is BaseEntity:
		push_error("CombatManager: Атакующий или защитник не являются BaseEntity.")
		return 0
		
	var base_damage = weapon_data.get("base_damage", 1)
	var crit_chance = weapon_data.get("crit_chance", 0.0)
	
	# Простейший расчет урона
	var final_damage = base_damage
	
	# Проверка на критический удар
	if randf() < crit_chance:
		final_damage *= 2 # Двойной урон
		print("Критический удар!")
		
	# TODO: Добавить расчет защиты, резистов, уязвимостей
	# TODO: Использовать Config.COMBAT_V2_ENABLED для выбора формулы расчета
	
	defender.take_damage(final_damage)
	
	return final_damage

# TODO: Добавить метод для инициации боя (start_combat)
# TODO: Добавить сигналы о нанесении урона, смерти, начале/конце боя
