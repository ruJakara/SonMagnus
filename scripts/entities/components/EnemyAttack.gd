## scripts/entities/components/EnemyAttack.gd
## Компонент атаки для врагов: вызывает CombatManager.execute_sequence().
##
## ИСПОЛЬЗОВАНИЕ В СЦЕНЕ:
## 1. Добавьте Node как дочерний узел EnemyBase
## 2. Назовите узел "EnemyAttack"
## 3. Подключите этот скрипт
## 4. Настройки можно задать через export или через JSON в EnemyBase

class_name EnemyAttack
extends Node

@export var combo_id: String = "enemy_basic"  # ID комбо из ComboManager
@export var cooldown: float = 1.2              # Кулдаун между атаками (секунды)
@export var weapon_data_override: Dictionary = {  # Данные оружия для CombatManager
	"base_damage": 10.0,
	"crit_chance": 0.05
}

var _parent: EnemyBase = null
var _combat_manager: Node = null
var _cooldown_timer: float = 0.0


func _ready() -> void:
	_parent = get_parent() as EnemyBase
	if not _parent:
		push_error("[EnemyAttack] Родитель должен быть EnemyBase!")
		return
	
	_combat_manager = get_node_or_null("/root/CombatManager")
	if not _combat_manager:
		push_warning("[EnemyAttack] CombatManager не найден в /root")


func _process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta


func try_attack(target: Node) -> void:
	if not target or not is_instance_valid(target):
		return
	
	if _cooldown_timer > 0.0:
		return
	
	if not _combat_manager:
		push_warning("[EnemyAttack] CombatManager недоступен")
		return
	
	# Формируем weapon_data из override и данных родителя
	var weapon_data = weapon_data_override.duplicate()
	if not weapon_data.has("base_damage") or weapon_data.get("base_damage", 0.0) <= 0.0:
		weapon_data["base_damage"] = float(_parent.attack)
	if not weapon_data.has("crit_chance"):
		weapon_data["crit_chance"] = _parent.crit_chance
	
	# Вызываем CombatManager
	var result = _combat_manager.execute_sequence(_parent, target, combo_id, weapon_data)
	
	# Сбрасываем кулдаун
	_cooldown_timer = cooldown
	
	if result and result.success:
		print("[EnemyAttack] %s атаковал %s (урон: %.1f)" % [_parent.enemy_name, target.name, result.damage])

