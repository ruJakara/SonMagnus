# autoload/Config.gd
# Глобальные настройки и переключатели для быстрой конфигурации проекта.
# Подключается как Autoload с именем "Config".

extends Node

## @brief Инициализация класса Config.
func _ready():
	if DEBUG_LOGS:
		print_debug("[Config] Загружен.")

# --- [ Настройки Разработки (Dev Switches) ] ---

## Включить/выключить режим отладки (отображение FPS, отладочная информация).
var DEBUG_LOGS := true

## Включить новую версию боевой системы.
var COMBAT_V2_ENABLED := true

## Включить тестовый режим сохранения (отключает шифрование).
var SAVE_TEST_MODE := false

## Включить автоматическое сохранение.
var AUTOSAVE_ENABLED := true

# TODO: Добавить другие глобальные константы и настройки (например, VOLUME_MASTER)
