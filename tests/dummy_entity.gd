# res://tests/dummy_entity.gd
extends Node
class_name DummyEntity

# Простейшие свойства
var health: float = 100.0
var max_health: float = 100.0
var attack: float = 10.0
var defense: float = 0.0
var speed: float = 1.0
var entity_class: String = ""

# Ста́мина/навыки
var _stamina: float = 100.0
var skills: Array = []

func _init():
	pass

func get_stamina() -> float:
	return _stamina

func reduce_stamina(cost: float) -> void:
	_stamina = max(0.0, _stamina - cost)

func get_skill_level(skill_name: String) -> int:
	for s in skills:
		if typeof(s) == TYPE_DICTIONARY and s.has("id") and s["id"] == skill_name:
			return int(s.get("level", 0))
	return 0

func has_unlocked_combo(combo_id: String) -> bool:
	# По умолчанию — нет, можно менять в тесте через unlocked_combos
	return true

# Урон/эффекты
func take_damage(amount: float) -> void:
	health -= amount

func apply_status_effect(effect_id: String) -> void:
	if EffectManager:
		EffectManager.apply_effect(self, effect_id)
	elif has_node("/root/EffectManager"):
		get_node("/root/EffectManager").apply_effect(self, effect_id)
	else:
		print("⚠️ EffectManager не найден, имитация эффекта:", effect_id)
