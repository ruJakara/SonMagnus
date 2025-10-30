# autoload/CraftManager.gd
# Менеджер системы крафта. Отвечает за проверку рецептов, инвентаря и создание предметов.
# Подключается как Autoload с именем "CraftManager".

extends Node

## @brief Инициализация класса CraftManager.
func _ready():
	print("CraftManager.gd загружен.")

## @brief Проверяет, может ли игрок создать предмет по указанному рецепту.
## @param recipe_id: ID рецепта (соответствует данным в res://data/recipes.json).
## @return: true, если крафт возможен, false иначе.
func can_craft(recipe_id: String) -> bool:
	# TODO: Загрузить рецепт из res://data/recipes.json
	# TODO: Проверить наличие ингредиентов в инвентаре
	return false

## @brief Выполняет крафт предмета.
## @param recipe_id: ID рецепта.
## @return: true, если крафт успешен, false иначе.
func craft_item(recipe_id: String) -> bool:
	if can_craft(recipe_id):
		# TODO: Потребление ингредиентов
		# TODO: Добавление созданного предмета в инвентарь
		print("Предмет создан по рецепту %s." % recipe_id)
		return true
	
	push_error("Невозможно создать предмет по рецепту %s: нет ингредиентов или рецепт не существует." % recipe_id)
	return false

# TODO: Добавить сигналы о начале/конце крафта
