# scripts/systems/CombatProfile.gd
# Ресурс для хранения профиля боевого стиля игрока
# Работает как скрытая характеристика, влияющая на предложение классов

class_name CombatProfile
extends Resource

## Словарь со шкалами боевых стилей
## Ключи: String, Значения: float
@export var styles: Dictionary = {}

## Список всех доступных стилей
const STYLE_NAMES: Array[StringName] = [
	&"berserk",
	&"duelist",
	&"gladiator",
	&"fencer",
	&"strategist",
	&"sniper",
	&"trickster",
	&"plunder",
	&"sage",
	&"arcane"
]


func _init() -> void:
	reset()


## Сброс всех значений стилей к нулю
func reset() -> void:
	styles.clear()
	for style_name in STYLE_NAMES:
		styles[style_name] = 0.0


## Добавить очки к определенному стилю
func add_score(style: StringName, amount: float) -> void:
	if not styles.has(style):
		push_warning("[CombatProfile] Неизвестный стиль: %s" % style)
		return
	
	styles[style] = styles[style] + amount


## Получить стиль с максимальным значением
func get_top_style() -> StringName:
	var max_value: float = -INF
	var top_style: StringName = &""
	
	for style_name in styles:
		var value: float = styles[style_name]
		if value > max_value:
			max_value = value
			top_style = style_name
	
	return top_style


## Получить текущее значение стиля
func get_style_value(style: StringName) -> float:
	if not styles.has(style):
		return 0.0
	return styles[style]


## Получить все стили, отсортированные по значению (по убыванию)
func get_sorted_styles() -> Array[Dictionary]:
	var sorted: Array[Dictionary] = []
	
	for style_name in styles:
		sorted.append({
			"style": style_name,
			"value": styles[style_name]
		})
	
	sorted.sort_custom(func(a, b): return a.value > b.value)
	
	return sorted
