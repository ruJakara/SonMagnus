@tool
extends "res://addons/gut/test.gd"

# Вспомогательный фейковый игрок/цель
class DummyEntity extends Node:
	var entity_name: String = "Dummy"
	var health: float = 100.0
	var stamina: float = 100.0
	var skills = [{"id": "skill_sword", "level": 12}, {"id": "skill_parry", "level": 6}]
	var unlocked_combos = ["basic_l", "parry_counter"]

	func take_damage(amount: float) -> void:
		health -= amount

	func apply_status_effect(effect_id: String) -> void:
		pass

	func get_global_level() -> int:
		return 5

	func reduce_stamina(cost: float) -> void:
		stamina -= cost

	func get_stamina() -> float:
		return stamina

	func has_unlocked_combo(id: String) -> bool:
		return id in unlocked_combos

	func get_skill_level(skill_name: String) -> int:
		for s in skills:
			if s.id == skill_name:
				return s.level
		return 0


func test_basic_attack_success() -> void:
	var combat = Engine.get_singleton("CombatManager")
	var p = DummyEntity.new()
	var e = DummyEntity.new()
	var wpn = {"base_damage": 10, "crit_chance": 0.0}
	var dmg = combat.calculate_damage(p, e, wpn)
	assert_true(dmg > 0, "Damage must be > 0")


func test_no_stamina_fail() -> void:
	var combat = Engine.get_singleton("CombatManager")
	var p = DummyEntity.new()
	p.stamina = 0
	var ok = combat.is_combo_available(p, "basic_l")
	assert_false(ok, "Combo should not be available if stamina < cost")
