# autoload/EconomyManager.gd
# Менеджер экономики. Отвечает за управление валютой, торговлю и ценообразование.
# Подключается как Autoload с именем "EconomyManager".

extends Node

## Сигнал, который испускается при изменении баланса валюты.
signal currency_changed(new_amount: int)

## Текущее количество основной валюты.
var gold_amount: int = 0:
	set(value):
		gold_amount = max(0, value)
		currency_changed.emit(gold_amount)

## @brief Инициализация класса EconomyManager.
func _ready():
	print("EconomyManager.gd загружен.")

## @brief Добавляет или отнимает валюту.
## @param amount: Количество валюты (может быть отрицательным для списания).
func modify_currency(amount: int):
	gold_amount += amount
	print("Баланс золота изменен на %d. Текущий баланс: %d" % [amount, gold_amount])

## @brief Рассчитывает цену продажи предмета.
## @param item_id: ID предмета.
## @return: Цена продажи.
func calculate_sell_price(_item_id: String) -> int:
	# TODO: Загрузить базовую цену из res://data/items.json
	# TODO: Применить модификаторы (например, скидка торговца)
	return 10 # Заглушка

# TODO: Добавить методы для покупки/продажи предметов
