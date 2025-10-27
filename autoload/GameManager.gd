# autoload/GameManager.gd
# Глобальный менеджер игры. Отвечает за смену сцен, глобальные сигналы и общее состояние игры.
# Подключается как Autoload с именем "GameManager".

extends Node

## Сигнал, который испускается при смене сцены.
signal scene_changed(new_scene_path: String)
## Сигнал, который испускается при паузе/возобновлении игры.
signal game_paused(is_paused: bool)

## @brief Инициализация класса GameManager.
func _ready():
	print("GameManager.gd загружен.")

## @brief Переключает игру в состояние паузы/возобновления.
## @param pause: true для паузы, false для возобновления.
func set_pause(pause: bool):
	get_tree().paused = pause
	game_paused.emit(pause)
	print("Игра %s." % ("поставлена на паузу" if pause else "возобновлена"))

## @brief Асинхронно меняет текущую сцену.
## @param path: Путь к новой сцене (например, "res://scenes/world/forest.tscn").
func change_scene_to_file(path: String):
	print("GameManager: Запрос на смену сцены на: %s" % path)
	var error = get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("GameManager: Ошибка при смене сцены: %s" % error)
		return
	
	scene_changed.emit(path)

# TODO: Добавить глобальное состояние игры (enum State: TITLE, MENU, GAMEPLAY, PAUSED)
# TODO: Добавить методы для выхода из игры (quit_game) и возврата в главное меню

