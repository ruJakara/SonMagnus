# tests/test_enemy_system.gd
# Тесты для системы врагов

extends "res://addons/gut/test.gd"

var enemy_base: EnemyBase
var enemy_brain: EnemyBrain
var player: Node

func before_each() -> void:
	# Создаём игрока (мок)
	player = Node2D.new()
	player.name = "Player"
	player.set_meta("is_alive", true)
	player.add_to_group("player")
	add_child(player)
	player.global_position = Vector2(100, 0)
	
	# Создаём врага
	enemy_base = preload("res://scripts/entities/enemies/enemy_base.gd").new()
	enemy_base.name = "TestEnemy"
	add_child(enemy_base)
	
	# Добавляем необходимые узлы
	var sprite = AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	enemy_base.add_child(sprite)
	
	var hurtbox = Area2D.new()
	hurtbox.name = "Hurtbox"
	enemy_base.add_child(hurtbox)
	
	var attack_area = Area2D.new()
	attack_area.name = "Attack"
	enemy_base.add_child(attack_area)
	
	var back_area = Area2D.new()
	back_area.name = "Back"
	enemy_base.add_child(back_area)
	
	enemy_brain = preload("res://scripts/entities/enemies/enemy_brain.gd").new()
	enemy_brain.name = "EnemyBrain"
	enemy_base.add_child(enemy_brain)
	
	# Загружаем данные
	enemy_base.load_from_json("res://data/enemies/goblin.json")
	
	# Ждём готовности
	await get_tree().process_frame

func after_each() -> void:
	if is_instance_valid(enemy_base):
		enemy_base.queue_free()
	if is_instance_valid(player):
		player.queue_free()

func test_enemy_loads_from_json() -> void:
	assert_not_null(enemy_base, "EnemyBase должен быть создан")
	assert_eq(enemy_base.entity_name, "Гоблин-разведчик", "Имя загружено из JSON")
	assert_eq(enemy_base.max_health, 50, "HP загружено из JSON")
	assert_eq(enemy_base.speed, 120.0, "Скорость загружена из JSON")

func test_enemy_has_behavior_data() -> void:
	assert_true(enemy_base.behavior_data.has("ai_type"), "Есть behavior_data")
	assert_eq(enemy_base.behavior_data["ai_type"], "patrol", "AI тип правильный")
	assert_eq(enemy_base.behavior_data["vision_cone_angle"], 120.0, "Угол обзора правильный")

func test_enemy_brain_initialized() -> void:
	assert_not_null(enemy_brain, "EnemyBrain создан")
	assert_not_null(enemy_brain.enemy, "Brain имеет ссылку на enemy")
	assert_true(enemy_brain.states.size() > 0, "States зарегистрированы")

func test_enemy_starts_in_patrol_state() -> void:
	assert_eq(enemy_brain.current_state_name, "patrol", "Начинает в patrol (ai_type=patrol)")

func test_enemy_can_change_state() -> void:
	enemy_brain.change_state("idle")
	assert_eq(enemy_brain.current_state_name, "idle", "Состояние изменено на idle")

func test_enemy_detects_target_in_cone() -> void:
	# Размещаем игрока перед врагом
	enemy_base.global_position = Vector2(0, 0)
	enemy_base._sprite.flip_h = false  # Смотрит вправо
	player.global_position = Vector2(100, 0)  # Перед врагом
	
	var detected = enemy_brain.detect_target_in_cone()
	assert_not_null(detected, "Цель обнаружена")
	assert_eq(detected, player, "Обнаружен игрок")

func test_enemy_does_not_detect_target_behind() -> void:
	# Размещаем игрока позади врага
	enemy_base.global_position = Vector2(0, 0)
	enemy_base._sprite.flip_h = false  # Смотрит вправо
	player.global_position = Vector2(-100, 0)  # Позади врага
	
	var detected = enemy_brain.detect_target_in_cone()
	assert_null(detected, "Цель позади не обнаружена")

func test_enemy_takes_damage() -> void:
	var initial_hp = enemy_base.health
	enemy_base.take_damage(10)
	assert_eq(enemy_base.health, initial_hp - 10, "HP уменьшилось на 10")

func test_enemy_backstab_multiplier() -> void:
	var initial_hp = enemy_base.health
	enemy_base.take_damage(10, null, true)  # from_back = true
	var expected_damage = int(10 * enemy_base.combat_data["backstab_damage_mult"])
	assert_eq(enemy_base.health, initial_hp - expected_damage, "Бэкстаб удвоил урон")

func test_enemy_dies_at_zero_health() -> void:
	enemy_base.health = 1
	var signal_emitted = false
	enemy_base.died.connect(func(): signal_emitted = true)
	
	enemy_base.take_damage(10)
	
	assert_false(enemy_base.is_alive, "Враг мёртв")
	await get_tree().process_frame
	assert_true(signal_emitted, "Сигнал died эмитирован")

func test_loot_manager_exists() -> void:
	assert_not_null(LootManager, "LootManager существует")

func test_loot_table_loaded() -> void:
	var table = LootManager.get_loot_table("goblin_common")
	assert_not_null(table, "Таблица лута загружена")
	assert_true(table.has("items"), "Таблица содержит предметы")

func test_loot_roll() -> void:
	var items = LootManager.roll_loot("goblin_common")
	# Лут случайный, но должен быть array
	assert_typeof(items, TYPE_ARRAY, "Лут возвращается как Array")


