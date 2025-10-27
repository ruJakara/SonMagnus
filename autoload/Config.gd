# autoload/Config.gd
# Глобальные настройки и переключатели для быстрой конфигурации проекта.
# Подключается как Autoload с именем "Config".

extends Node

## @brief Инициализация класса Config.
func _ready():
	print("Config.gd загружен. Режим отладки: %s" % str(DEBUG_LOGS))

# --- [ Настройки Разработки (Dev Switches) ] ---

## Включить/выключить режим отладки (отображение FPS, отладочная информация).
const DEBUG_LOGS: bool = true

## Включить новую версию боевой системы.
const COMBAT_V2_ENABLED: bool = true

## Включить тестовый режим сохранения (отключает шифрование).
const SAVE_TEST_MODE: bool = false

# TODO: Добавить другие глобальные константы и настройки (например, VOLUME_MASTER)

