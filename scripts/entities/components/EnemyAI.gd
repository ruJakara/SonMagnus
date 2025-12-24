## scripts/entities/components/EnemyAI.gd
## Компонент AI для врагов: простая state machine (IDLE → CHASE → ATTACK).
##
## ИСПОЛЬЗОВАНИЕ В СЦЕНЕ:
## 1. Добавьте Node как дочерний узел EnemyBase
## 2. Назовите узел "EnemyAI"
## 3. Подключите этот скрипт
## 4. Настройки можно задать через export или через JSON в EnemyBase
##
## Обновлено для использования Area2D-зон атаки:
## - В _update_attack вызов try_attack() теперь без параметров

class_name EnemyAI
extends Node

@export var detection_range: float = 250.0  # Радиус обнаружения игрока
@export var lose_range: float = 350.0        # Радиус потери цели
@export var attack_range: float = 55.0       # Радиус атаки

var _parent: EnemyBase = null # Ensure _parent is typed as EnemyBase
var _attack_component: EnemyAttack = null
var _player: Node = null
var _attack_cooldown: float = 0.0  # Кулдаун между попытками атаки


func _ready() -> void:
	_parent = get_parent() as EnemyBase
	if not _parent:
		push_error("[EnemyAI] Родитель должен быть EnemyBase!")
		return
	
	# Ищем компонент атаки у родителя
	_attack_component = _parent.get_node_or_null("EnemyAttack") as EnemyAttack
	if not _attack_component:
		push_warning("[EnemyAI] Компонент EnemyAttack не найден у родителя")


func _process(delta: float) -> void:
	if not _parent or _parent.state == "dead":
		return
	
	# Обновляем кулдаун атаки
	if _attack_cooldown > 0.0:
		_attack_cooldown -= delta
	
	# Поиск цели (если еще не найдена)
	if not _player or not is_instance_valid(_player):
		_find_target()
	
	# Обновление состояния
	match _parent.state:
		"idle":
			_update_idle(delta)
		"chase":
			_update_chase(delta)
		"attack":
			_update_attack(delta)


func _find_target() -> void:
	var candidates = get_tree().get_nodes_in_group("targetable")
	var best: Node = null
	var best_dist := INF

	for c in candidates:
		if c == _parent:
			continue
		if not is_instance_valid(c):
			continue
		if not c.has_method("get_faction"):
			continue

		var cfaction: StringName = c.get_faction()
		if not _parent.is_hostile_to(cfaction):
			continue

		var d := _parent.global_position.distance_to(c.global_position)
		if d < best_dist:
			best_dist = d
			best = c

	if best != null:
		_player = best
		_parent.current_target = best
	else:
		_player = null
		_parent.current_target = null


func _update_idle(delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		return
	
	var distance = _parent.global_position.distance_to(_player.global_position)
	if distance <= detection_range:
		_parent.state = "chase"


func _update_chase(delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		_parent.state = "idle"
		_parent.current_target = null
		return
	
	# Если цель больше не враждебна — сброс
	if _player and _player.has_method("get_faction"):
		if not _parent.is_hostile_to(_player.get_faction()):
			_player = null
			_parent.current_target = null
			_parent.state = "idle"
			return
	
	var distance = _parent.global_position.distance_to(_player.global_position)
	
	# Если игрок слишком далеко — теряем цель
	if distance > lose_range:
		_parent.state = "idle"
		_parent.current_target = null
		return
	
	# Если в радиусе атаки — переходим в режим атаки
	if distance <= attack_range:
		_parent.state = "attack"
		return
	
	# Поворот к цели
	_parent.face_target(_player)
	
	# Движение к игроку
	var direction = (_player.global_position - _parent.global_position).normalized()
	_parent.global_position += direction * _parent.speed * delta


func _update_attack(delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		_parent.state = "idle"
		_parent.current_target = null
		return
	
	# Если цель больше не враждебна — сброс
	if _player and _player.has_method("get_faction"):
		if not _parent.is_hostile_to(_player.get_faction()):
			_player = null
			_parent.current_target = null
			_parent.state = "idle"
			return
	
	var distance = _parent.global_position.distance_to(_player.global_position)
	
	# Если игрок слишком далеко — преследуем
	if distance > attack_range:
		_parent.state = "chase"
		return
	
	# Если слишком далеко для преследования — теряем цель
	if distance > lose_range:
		_parent.state = "idle"
		_parent.current_target = null
		return
	
	# Поворот к цели
	_parent.face_target(_player)
	
	# Пытаемся атаковать, если кулдаун прошел
	if _attack_component and _attack_cooldown <= 0.0:
		print("[EnemyAI] %s: вызываем try_attack()" % _parent.enemy_name)
		_attack_component.try_attack()  # Используем Area2D-зоны вместо прямого указания цели
		_attack_cooldown = 0.5  # Устанавливаем кулдаун между попытками атаки
	# После атаки сразу возвращаемся в chase, если цель всё ещё рядом
		_parent.state = "chase"
