extends "res://addons/gut/test.gd"

# Ссылки на автолоады
var combat: Node
var combo: Node
var effects: Node

# Тестовые сущности
var attacker: Node
var defender: Node


func before_all():
	# === Создаём автолоады вручную (чтобы GUT видел их без main.tscn) ===
	
	var combo_node = load("res://autoload/ComboManager.gd").new()
	get_tree().root.add_child(combo_node)

	var effects_node = load("res://autoload/EffectManager.gd").new()
	get_tree().root.add_child(effects_node)

	var combat_node = load("res://autoload/CombatManager.gd").new()
	get_tree().root.add_child(combat_node)

	# Получаем ссылки (если нужны глобально)
	combo = combo_node
	effects = effects_node
	combat = combat_node

	# === Моки бойцов — теперь с использованием DummyEntity ===
	var Dummy = preload("res://tests/dummy_entity.gd")

	attacker = Dummy.new()
	attacker.name = "Hero"
	attacker.health = 100.0
	attacker.max_health = 100.0
	attacker.attack = 12.0
	attacker.defense = 2.0
	attacker.entity_class = "warrior"
	attacker._stamina = 100.0
	attacker.skills = [{"id":"skill_sword","level":12},{"id":"skill_parry","level":6}]
	# если нужно — отмечаем какие комбо явно доступны:
	attacker.set_meta("unlocked_combos", ["basic_l","parry_counter","triple_l_r"])

	defender = Dummy.new()
	defender.name = "Dummy"
	defender.health = 100.0
	defender.max_health = 100.0
	defender.defense = 1.0
	defender.entity_class = "enemy"

	# Теперь добавляем их в дерево (уже созданные объекты)
	get_tree().root.add_child(attacker)
	get_tree().root.add_child(defender)





func after_all():
	for node in [combat, combo, effects]:
		if node and is_instance_valid(node) and node.get_parent():
			node.queue_free()
	if is_instance_valid(attacker):
		attacker.queue_free()
	if is_instance_valid(defender):
		defender.queue_free()





# === ТЕСТЫ ======================================================

func test_damage_without_combo():
	var result = combat.calculate_damage(attacker, defender, {"base_damage": 10}, "")
	assert_eq(result.damage, 10.0, "Базовый урон должен быть 10")


func test_combo_execution_basic():
	var combo_id = "basic_attack"
	if not combo.has_combo(combo_id):
		push_warning("SKIP: Комбо '%s' не найдено в combos.json" % combo_id)
		return

	var weapon_data = {"base_damage": 8, "crit_chance": 0.0}
	var result = combat.execute_sequence(attacker, defender, combo_id, weapon_data)

	assert_true(result.success, "Комбо должно выполниться")
	assert_gt(result.damage, 0, "Урон должен быть больше 0")
	assert_lt(defender.health, defender.max_health, "Защитник должен потерять здоровье")



func test_effect_application():
	var effect_id = "bleed"
	if not effects.effects_data.has(effect_id):
		push_warning("SKIP: эффект '%s' не найден" % effect_id)
		return

	var initial_hp = defender.health

	# Применяем эффект
	effects.apply_effect(defender, effect_id)

	# Эмулируем 3 тика (по 1 секунде каждый)
	for i in range(3):
		effects._on_tick()

	assert_lt(defender.health, initial_hp, "После 3 секунд кровотечения здоровье должно уменьшиться")
