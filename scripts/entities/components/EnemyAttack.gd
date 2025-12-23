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

var _parent: EnemyBase = null # Ensure _parent is typed as EnemyBase
var _combat_manager: Node = null
var _cooldown_timer: float = 0.0
var _is_attacking: bool = false  # Флаг: атакуем прямо сейчас (для защиты от спама)


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
	# Базовые проверки
	if not target or not is_instance_valid(target):
		return
	
	if _cooldown_timer > 0.0:
		return
	
	if _is_attacking:
		return
	
	if not _combat_manager:
		push_warning("[EnemyAttack] CombatManager недоступен")
		return
	
	# Блокируем повторный вызов
	_is_attacking = true
	
	# Ставим состояние атаки (для анимации)
	_parent.state = "attack"
	
	# Небольшой windup перед нанесением урона
	await get_tree().create_timer(0.12).timeout
	if not is_instance_valid(_parent) or not is_instance_valid(target):
		_is_attacking = false
		return
	
	# Готовим weapon_data
	var weapon_data := weapon_data_override.duplicate()
	if not weapon_data.has("base_damage") or weapon_data.get("base_damage", 0.0) <= 0.0:
		weapon_data["base_damage"] = float(_parent.attack)
	if not weapon_data.has("crit_chance"):
		weapon_data["crit_chance"] = _parent.crit_chance
	
	# Вызываем CombatManager
	var result = _combat_manager.execute_sequence(_parent, target, combo_id, weapon_data)
	
	# Кулдаун
	_cooldown_timer = cooldown
	
	# Короткое окно, пока держим state = "attack"
	await get_tree().create_timer(0.12).timeout
	if is_instance_valid(_parent) and _parent.state == "attack":
		_parent.state = "chase"
	
	# Разблокируем атаку
	_is_attacking = false
	
	if result and result.success:
		print("[EnemyAttack] %s атаковал %s (урон: %.1f)" % [_parent.enemy_name, target.name, result.damage])
