## scripts/entities/components/EnemyAttack.gd
## Компонент атаки врагов через Area2D-зоны.
##
## ИСПОЛЬЗОВАНИЕ:
## 1. Добавьте Node с этим скриптом как дочерний узел EnemyBase
## 2. Назовите узел "EnemyAttack"
## 3. У EnemyBase должна быть Area2D с именем "Attack"
## 4. Настройки задаются через export или JSON (см. EnemyBase)

class_name EnemyAttack
extends Node

# ===== Настройки =====
@export var combo_id: String = "enemy_basic"
@export var cooldown: float = 1.2
@export var windup_time: float = 0.12  # Задержка перед нанесением урона (удобно под анимацию)
@export var weapon_data_override: Dictionary = {
	"base_damage": 10.0,
	"crit_chance": 0.05
}

# ===== Внутренние переменные =====
var _parent: EnemyBase = null
var _combat_manager: Node = null
var _attack_area: Area2D = null
var _current_targets: Array[Node] = []
var _cooldown_timer: float = 0.0
var _is_attacking: bool = false


# ===== Инициализация =====

func _ready() -> void:
	_parent = get_parent() as EnemyBase
	if not _parent:
		push_error("[EnemyAttack] Родитель должен быть EnemyBase!")
		return
	
	_combat_manager = get_node_or_null("/root/CombatManager")
	if not _combat_manager:
		push_warning("[EnemyAttack] CombatManager не найден в /root")
	
	_setup_attack_area()


func _setup_attack_area() -> void:
	_attack_area = _parent.get_node_or_null("Attack") as Area2D
	if not _attack_area:
		push_warning("[EnemyAttack] Area2D 'Attack' не найдена у %s" % _parent.enemy_name)
		return
	
	_attack_area.body_entered.connect(_on_body_entered)
	_attack_area.body_exited.connect(_on_body_exited)


# ===== Обработка целей в зоне =====

func _on_body_entered(body: Node) -> void:
	if body == _parent or body in _current_targets:
		return
	
	var target := _resolve_target(body)
	if target and _is_hostile(target):
		_current_targets.append(body)
		if Config.DEBUG_LOGS:
			print("[EnemyAttack] %s: цель %s вошла в зону" % [_parent.enemy_name, body.name])


func _on_body_exited(body: Node) -> void:
	_current_targets.erase(body)
	if Config.DEBUG_LOGS:
		print("[EnemyAttack] %s: цель %s покинула зону" % [_parent.enemy_name, body.name])


func _resolve_target(body: Node) -> Node:
	# Возвращает узел, который имеет take_damage (сам body или его родитель)
	if body.has_method("take_damage"):
		return body
	if body.get_parent() and body.get_parent().has_method("take_damage"):
		return body.get_parent()
	return null


func _is_hostile(target: Node) -> bool:
	if not target.has_method("get_faction"):
		return false
	return _parent.is_hostile_to(target.get_faction())


# ===== Обновление кулдауна =====

func _process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta


# ===== Главная атака =====

func try_attack(_ignored: Node = null) -> void:
	# Проверки
	if _is_attacking or _cooldown_timer > 0.0:
		return
	if _current_targets.is_empty():
		if Config.DEBUG_LOGS:
			print("[EnemyAttack] %s: нет целей в зоне" % _parent.enemy_name)
		return
	if not _combat_manager:
		push_warning("[EnemyAttack] CombatManager недоступен")
		return
	
	_is_attacking = true
	_execute_attack()


func _execute_attack() -> void:
	# Windup (задержка для синхронизации с анимацией)
	await get_tree().create_timer(windup_time).timeout
	if not is_instance_valid(_parent):
		_is_attacking = false
		return
	
	# Формируем weapon_data
	var weapon_data := _get_weapon_data()
	
	# Атакуем все цели в зоне
	for body in _current_targets.duplicate():
		if not is_instance_valid(body):
			_current_targets.erase(body)
			continue
		
		var defender := _resolve_target(body)
		if not defender or not _is_hostile(defender):
			continue
		
		_deal_damage_to(defender, weapon_data)
	
	# Сброс кулдауна и флага
	_cooldown_timer = cooldown
	_is_attacking = false
	
	if Config.DEBUG_LOGS:
		print("[EnemyAttack] %s: атака завершена" % _parent.enemy_name)


func _get_weapon_data() -> Dictionary:
	var data := weapon_data_override.duplicate()
	if not data.has("base_damage") or data.get("base_damage", 0.0) <= 0.0:
		data["base_damage"] = float(_parent.attack)
	if not data.has("crit_chance"):
		data["crit_chance"] = _parent.crit_chance
	return data


func _deal_damage_to(defender: Node, weapon_data: Dictionary) -> void:
	var result = _combat_manager.execute_sequence(_parent, defender, combo_id, weapon_data)
	
	if result and result.success:
		if Config.DEBUG_LOGS:
			print("[EnemyAttack] %s → %s | урон: %.1f%s" % [
				_parent.enemy_name,
				defender.name,
				result.damage,
				" [КРИТ]" if result.crit else ""
			])
	elif Config.DEBUG_LOGS:
		push_warning("[EnemyAttack] %s не смог атаковать %s" % [_parent.enemy_name, defender.name])


# ===== Публичное API =====

func has_targets() -> bool:
	return not _current_targets.is_empty()


func get_target_count() -> int:
	return _current_targets.size()


func is_on_cooldown() -> bool:
	return _cooldown_timer > 0.0
