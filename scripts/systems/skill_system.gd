# scripts/systems/skill_system.gd
# Основная логика системы навыков.
# Использует SkillManager (Autoload) для управления опытом.

class_name SkillSystem
extends Node

## Путь к файлу с данными навыков.
const SKILLS_DATA_PATH: String = "res://data/skills.json"

## @brief Инициализация класса SkillSystem.
func _ready():
	print("SkillSystem.gd загружен.")
	# TODO: Загрузить данные навыков с помощью JsonUtils.load_json(SKILLS_DATA_PATH)

## @brief Использование активного навыка.
## @param user: Сущность, использующая навык.
## @param skill_id: ID используемого навыка.
func use_skill(user: BaseEntity, skill_id: String):
	# TODO: Проверить ману/выносливость
	# TODO: Выполнить эффект навыка
	print("%s использует навык: %s" % [user.entity_name, skill_id])
	
	# После использования навыка начисляем опыт
	SkillManager.gain_exp(skill_id, 5)

# TODO: Добавить логику для пассивных навыков
# TODO: Добавить логику для проверки требований к навыку (уровень, класс)
