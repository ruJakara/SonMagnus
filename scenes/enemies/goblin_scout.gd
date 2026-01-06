extends EnemyBase

func _ready() -> void:
	# ДИАГНОСТИКА #1: проверяем, что метод вообще вызывается
	print("=== GOBLIN _ready() START ===")
	
	# Загружаем JSON ДО super._ready()
	var json_path = "res://data/enemies/goblin.json"
	print("[GoblinScout] Загружаю JSON: ", json_path)
	
	var loaded = load_from_json(json_path)
	print("[GoblinScout] Результат загрузки: ", loaded)
	
	if not loaded:
		push_error("[GoblinScout] JSON НЕ ЗАГРУЗИЛСЯ! Проверь путь: " + json_path)
	
	# ДИАГНОСТИКА #2: проверяем данные ДО вызова super
	print("[GoblinScout] После load_from_json:")
	print("  entity_name: ", entity_name)
	print("  max_health: ", max_health)
	print("  speed: ", speed)
	print("  behavior_data: ", behavior_data)
	
	# Теперь вызываем super (чтобы Brain видел заполненные данные)
	super._ready()
	
	# ДИАГНОСТИКА #3: финальная проверка
	print("=== GOBLIN DIAGNOSTIC ===")
	print("  Имя: ", entity_name)
	print("  HP: ", health, "/", max_health)
	print("  Скорость: ", speed)
	print("  AI тип: ", behavior_data.get("ai_type", "НЕТ"))
	print("  Brain состояние: ", brain.current_state_name if brain else "НЕТ BRAIN")
	print("  Patrol range: ", behavior_data.get("patrol_walk_distance_min", "НЕТ"))
	print("========================")
