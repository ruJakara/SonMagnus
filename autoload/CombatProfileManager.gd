# autoload/CombatProfileManager.gd
# Менеджер профиля боевого стиля игрока
# Отслеживает боевые события и обновляет скрытые характеристики
# Автозагружается как синглтон

class_name CombatProfileManager
extends Node

## Сигнал об изменении профиля
signal profile_changed(style: StringName, new_value: float)

## Ресурс с профилем боевого стиля
var profile: CombatProfile = null

## Словарь событий и их влияния на стили
## Загружается из JSON или задается вручную
var event_mappings: Dictionary = {}


func _ready() -> void:
	profile = CombatProfile.new()
	_load_event_mappings()
	
	if Config.DEBUG_LOGS:
		print_debug("[CombatProfileManager] Инициализирован")


## Загрузить маппинг событий из JSON
func _load_event_mappings() -> void:
	var json_path: String = "res://data/combat_events.json"
	
	if not FileAccess.file_exists(json_path):
		if Config.DEBUG_LOGS:
			print_debug("[CombatProfileManager] Файл %s не найден, использую дефолтный маппинг" % json_path)
		_setup_default_mappings()
		return
	
	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_warning("[CombatProfileManager] Не удалось открыть файл %s" % json_path)
		_setup_default_mappings()
		return
	
	var json_text: String = file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_result := json.parse(json_text)
	
	if parse_result != OK:
		push_warning("[CombatProfileManager] Ошибка парсинга JSON: %s" % json.get_error_message())
		_setup_default_mappings()
		return
	
	event_mappings = json.data
	
	if Config.DEBUG_LOGS:
		print_debug("[CombatProfileManager] Загружено событий: %d" % event_mappings.size())


## Установить дефолтный маппинг событий
func _setup_default_mappings() -> void:
	event_mappings = {
		"straight_hit": {"style": "berserk", "amount": 1.0},
		"parry_attempt": {"style": "fencer", "amount": 2.0},
		"parry_success": {"style": "fencer", "amount": 5.0},
		"combo_finish": {"style": "gladiator", "amount": 1.0},
		"combo_3hit": {"style": "gladiator", "amount": 3.0},
		"headshot": {"style": "sniper", "amount": 3.0},
		"critical_hit": {"style": "duelist", "amount": 2.0},
		"trap_damage": {"style": "trickster", "amount": 4.0},
		"poison_tick": {"style": "plunder", "amount": 1.0},
		"long_range_shot": {"style": "strategist", "amount": 2.0},
		"backstab": {"style": "trickster", "amount": 5.0},
		"spell_cast": {"style": "sage", "amount": 2.0},
		"elemental_damage": {"style": "arcane", "amount": 3.0},
		"charged_attack": {"style": "berserk", "amount": 2.0},
		"counter_attack": {"style": "duelist", "amount": 3.0},
		"defensive_stance": {"style": "strategist", "amount": 1.0}
	}


## Зарегистрировать боевое событие
func register_event(event: StringName) -> void:
	if not event_mappings.has(event):
		if Config.DEBUG_LOGS:
			print_debug("[CombatProfileManager] Неизвестное событие: %s" % event)
		return
	
	var mapping: Dictionary = event_mappings[event]
	var style: StringName = mapping.get("style", &"")
	var amount: float = mapping.get("amount", 0.0)
	
	if style.is_empty() or amount == 0.0:
		if Config.DEBUG_LOGS:
			print_debug("[CombatProfileManager] Некорректный маппинг для события %s" % event)
		return
	
	# Добавляем очки к стилю
	profile.add_score(style, amount)
	
	# Получаем новое значение
	var new_value: float = profile.get_style_value(style)
	
	if Config.DEBUG_LOGS:
		print_debug("[CombatProfileManager] Событие: %s -> %s +%.1f (всего: %.1f)" % [event, style, amount, new_value])
	
	# Отправляем сигнал
	emit_signal("profile_changed", style, new_value)


## Получить текущий топовый стиль
func get_top_style() -> StringName:
	return profile.get_top_style()


## Получить значение конкретного стиля
func get_style_value(style: StringName) -> float:
	return profile.get_style_value(style)


## Получить все стили, отсортированные по значению
func get_sorted_styles() -> Array[Dictionary]:
	return profile.get_sorted_styles()


## Сбросить профиль
func reset_profile() -> void:
	profile.reset()
	
	if Config.DEBUG_LOGS:
		print_debug("[CombatProfileManager] Профиль сброшен")


## Добавить кастомный маппинг события
func add_event_mapping(event: StringName, style: StringName, amount: float) -> void:
	event_mappings[event] = {
		"style": style,
		"amount": amount
	}


## Получить статистику профиля для отладки
func get_profile_stats() -> Dictionary:
	var stats: Dictionary = {}
	var sorted_styles := profile.get_sorted_styles()
	
	for style_data in sorted_styles:
		stats[style_data.style] = style_data.value
	
	return stats
