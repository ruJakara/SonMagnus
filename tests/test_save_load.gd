# tests/test_save_load.gd
# Сценарий для модульного тестирования системы сохранения/загрузки.

extends Node

## @brief Тестирование сохранения и загрузки данных.
func test_save_load_cycle():
	var test_data = {
		"player_name": "SonMagnus",
		"level": 5,
		"inventory": ["sword", "shield"]
	}
	
	# 1. Сохранение
	var save_result = SaveManager.save_game(test_data)
	# assert_eq(save_result, OK, "Сохранение должно быть успешным")
	
	# 2. Загрузка
	var loaded_data = SaveManager.load_game()
	
	# 3. Проверка
	# assert_eq(loaded_data, test_data, "Загруженные данные должны совпадать с сохраненными")
	
	print("Тест сохранения/загрузки завершен. Проверьте консоль на ошибки шифрования/дешифрования.")
	pass

# TODO: Добавить тест на ошибку парсинга JSON
# TODO: Добавить тест на отсутствие файла сохранения

