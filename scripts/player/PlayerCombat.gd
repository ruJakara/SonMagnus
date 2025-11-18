# scripts/player/PlayerCombat.gd
# Attack State Machine для игрока
# Управляет состояниями атак и combo-цепочками
# Использует AnimationPlayer для проигрывания анимаций

extends Node

# ===== Состояния =====
enum State {
	IDLE,
	ATTACK_1,
	ATTACK_2,
	ATTACK_3,
	CHARGED,
	BLOCK,
	DASH
}

# ===== Signals =====
signal state_changed(old_state: State, new_state: State)
signal attack_performed(attack_number: int)
signal combo_window_opened()
signal combo_window_closed()

# ===== Экспорт параметров =====
@export var combo_window_duration: float = 0.3
@export var attack_1_damage_multiplier: float = 1.0
@export var attack_2_damage_multiplier: float = 1.2
@export var attack_3_damage_multiplier: float = 1.5

# ===== Внутренние переменные =====
var current_state: State = State.IDLE
var previous_state: State = State.IDLE
var combo_window_active: bool = false
var combo_window_timer: float = 0.0
var queued_input: String = ""
var attack_chain_count: int = 0  # Счетчик текущей цепочки атак (0, 1, 2, 3)
var current_combo_id: String = ""  # ID текущего комбо для CombatManager

# ===== References =====
var player: CharacterBody2D = null
var animation_player: AnimationPlayer = null
var combat_manager: Node = null
var combo_manager: Node = null
var combat_profile_manager: Node = null

# ===== Константы анимаций =====
const ANIM_ATTACK_1: String = "attack_1"
const ANIM_ATTACK_2: String = "attack_2" 
const ANIM_ATTACK_3: String = "attack_3"
const ANIM_CHARGED: String = "charged_attack"
const ANIM_BLOCK: String = "block"
const ANIM_DASH: String = "dash"


func _ready() -> void:
	_setup_references()


func _setup_references() -> void:
	# Получаем ссылки на компоненты
	player = get_parent() as CharacterBody2D
	
	if player:
		animation_player = player.get_node_or_null("AnimationPlayer")
	
	combat_manager = get_node_or_null("/root/CombatManager")
	combo_manager = get_node_or_null("/root/ComboManager")
	combat_profile_manager = get_node_or_null("/root/CombatProfileManager")
	
	# Подключаемся к сигналам CombatManager для отслеживания критов
	if combat_manager:
		if not combat_manager.is_connected("critical_hit", _on_critical_hit):
			combat_manager.connect("critical_hit", _on_critical_hit)
	
	if Config.DEBUG_LOGS:
		print_debug("[PlayerCombat] Инициализация. Player: %s, AnimationPlayer: %s" % [player != null, animation_player != null])


func _process(delta: float) -> void:
	_update_combo_window(delta)


func _update_combo_window(delta: float) -> void:
	if combo_window_active:
		combo_window_timer -= delta
		if combo_window_timer <= 0.0:
			_close_combo_window()


# ===== Input Handling =====
func handle_attack_input(side: String) -> void:
	"""Обработка ввода атаки (L или R)
	Вызывается извне при нажатии attack_left или attack_right
	"""
	if Config.DEBUG_LOGS:
		print_debug("[PlayerCombat] handle_attack_input: side=%s, state=%s, combo_window=%s, chain=%d" % [side, State.keys()[current_state], combo_window_active, attack_chain_count])
	
	match current_state:
		State.IDLE:
			# Начинаем атаку с первого удара
			_start_attack_1(side)
		
		State.ATTACK_1, State.ATTACK_2, State.ATTACK_3:
			# Если окно комбо открыто, продолжаем цепочку
			if combo_window_active:
				_continue_combo(side)
			else:
				# Окно комбо закрыто - запоминаем ввод для следующей атаки
				queued_input = side


func handle_charged_attack(side: String) -> void:
	"""Обработка заряженной атаки
	Вызывается извне при удержании кнопки атаки
	"""
	if current_state == State.IDLE:
		_start_charged_attack(side)


func handle_block_input() -> void:
	"""Обработка блока
	Вызывается извне при нажатии block
	"""
	if current_state == State.IDLE:
		_change_state(State.BLOCK)
		_play_animation(ANIM_BLOCK)
		
		# Регистрируем попытку парирования
		if combat_profile_manager:
			combat_profile_manager.register_event(&"parry_attempt")


func handle_dash_input() -> void:
	"""Обработка рывка
	Вызывается извне при нажатии dash
	"""
	if current_state == State.IDLE:
		_change_state(State.DASH)
		_play_animation(ANIM_DASH)


# ===== State Management =====
func _change_state(new_state: State) -> void:
	"""Смена состояния"""
	if current_state == new_state:
		return
	
	previous_state = current_state
	current_state = new_state
	
	if Config.DEBUG_LOGS:
		print_debug("[PlayerCombat] State changed: %s -> %s" % [State.keys()[previous_state], State.keys()[new_state]])
	
	emit_signal("state_changed", previous_state, new_state)
	
	# Обработка перехода в IDLE
	if new_state == State.IDLE:
		_reset_attack_chain()


func _start_attack_1(side: String) -> void:
	"""Начать первую атаку в цепочке"""
	_change_state(State.ATTACK_1)
	attack_chain_count = 1
	current_combo_id = "attack_1"
	_play_animation(ANIM_ATTACK_1)
	emit_signal("attack_performed", 1)
	
	# Регистрируем событие в CombatProfileManager
	if combat_profile_manager:
		combat_profile_manager.register_event(&"straight_hit")


func _continue_combo(side: String) -> void:
	"""Продолжить комбо-цепочку"""
	_close_combo_window()
	
	match current_state:
		State.ATTACK_1:
			# Переход к атаке 2
			_change_state(State.ATTACK_2)
			attack_chain_count = 2
			current_combo_id = "attack_2"
			_play_animation(ANIM_ATTACK_2)
			emit_signal("attack_performed", 2)
		
		State.ATTACK_2:
			# Переход к атаке 3
			_change_state(State.ATTACK_3)
			attack_chain_count = 3
			current_combo_id = "attack_3"
			_play_animation(ANIM_ATTACK_3)
			emit_signal("attack_performed", 3)
			
			# Регистрируем завершение комбо из 3 ударов
			if combat_profile_manager:
				combat_profile_manager.register_event(&"combo_3hit")
		
		State.ATTACK_3:
			# Финальная атака - возвращаемся к первой
			_reset_attack_chain()
			_start_attack_1(side)


func _start_charged_attack(side: String) -> void:
	"""Начать заряженную атаку"""
	_change_state(State.CHARGED)
	attack_chain_count = 0
	current_combo_id = "charged_attack"
	_play_animation(ANIM_CHARGED)
	
	# Регистрируем событие заряженной атаки
	if combat_profile_manager:
		combat_profile_manager.register_event(&"charged_attack")


func _reset_attack_chain() -> void:
	"""Сбросить цепочку атак"""
	attack_chain_count = 0
	current_combo_id = ""
	_close_combo_window()
	queued_input = ""


# ===== Combo Window Management =====
func _open_combo_window() -> void:
	"""Открыть окно для combo
	Вызывается через notify из AnimationPlayer
	"""
	if combo_window_active:
		return
	
	combo_window_active = true
	combo_window_timer = combo_window_duration
	
	if Config.DEBUG_LOGS:
		print_debug("[PlayerCombat] Combo window opened (duration: %.2fs)" % combo_window_duration)
	
	emit_signal("combo_window_opened")


func _close_combo_window() -> void:
	"""Закрыть окно combo"""
	if not combo_window_active:
		return
	
	combo_window_active = false
	combo_window_timer = 0.0
	
	if Config.DEBUG_LOGS:
		print_debug("[PlayerCombat] Combo window closed")
	
	emit_signal("combo_window_closed")


# ===== Animation Control =====
func _play_animation(anim_name: String) -> void:
	"""Проиграть анимацию через AnimationPlayer"""
	if not animation_player:
		if Config.DEBUG_LOGS:
			print_debug("[PlayerCombat] AnimationPlayer не найден!")
		return
	
	if not animation_player.has_animation(anim_name):
		if Config.DEBUG_LOGS:
			print_debug("[PlayerCombat] Анимация '%s' не найдена в AnimationPlayer!" % anim_name)
		return
	
	animation_player.play(anim_name)
	
	if Config.DEBUG_LOGS:
		print_debug("[PlayerCombat] Играю анимацию: %s" % anim_name)

# ===== Animation Notify Callbacks =====
# Эти методы вызываются из AnimationPlayer через notify tracks

func _on_attack_frame() -> void:
	"""Вызывается из AnimationPlayer на кадре нанесения урона
	Вызывает CombatManager.execute_sequence для нанесения урона
	"""
	if Config.DEBUG_LOGS:
		print_debug("[PlayerCombat] _on_attack_frame вызван, состояние=%s, combo_id=%s" % [State.keys()[current_state], current_combo_id])
	
	# Открываем окно combo на кадре атаки
	_open_combo_window()
	
	# Выполняем атаку через CombatManager
	if current_combo_id.is_empty():
		if Config.DEBUG_LOGS:
			print_debug("[PlayerCombat] Нет combo_id для выполнения атаки")
		return
	
	# Проверяем наличие необходимых компонентов
	if not player or not combat_manager:
		if Config.DEBUG_LOGS:
			print_debug("[PlayerCombat] Не все компоненты доступны (player=%s, combat_manager=%s)" % [player != null, combat_manager != null])
		return
	
	# Получаем цель
	var target = null
	if player.has_method("get_target"):
		target = player.get_target()
	
	if not target:
		if Config.DEBUG_LOGS:
			print_debug("[PlayerCombat] Нет цели для атаки")
		return
	
	# Формируем weapon_data согласно заданию
	var weapon_data: Dictionary = {
		"base_damage": 10,
		"crit_chance": 0.1
	}
	
	# Вызываем CombatManager.execute_sequence
	if Config.DEBUG_LOGS:
		print_debug("[PlayerCombat] Вызываю CombatManager.execute_sequence(player=%s, target=%s, combo_id=%s, weapon_data=%s)" % [player.name, target.name if target.has("name") else target, current_combo_id, weapon_data])
	
	var result = combat_manager.execute_sequence(player, target, current_combo_id, weapon_data)
	
	if result and result.success:
		if Config.DEBUG_LOGS:
			print_debug("[PlayerCombat] Атака успешна: урон=%.1f, крит=%s" % [result.damage, result.crit])
	else:
		if Config.DEBUG_LOGS:
			print_debug("[PlayerCombat] Атака не удалась или вернула пустой результат")


func _on_attack_end() -> void:
	"""Вызывается из AnimationPlayer в конце анимации атаки
	Используется для завершения атаки и перехода в следующее состояние
	"""
	if Config.DEBUG_LOGS:
		print_debug("[PlayerCombat] _on_attack_end вызван, состояние=%s" % State.keys()[current_state])
	
	# Закрываем окно combo
	_close_combo_window()
	
	# Проверяем, есть ли отложенный ввод
	if queued_input != "":
		var input := queued_input
		queued_input = ""
		handle_attack_input(input)
	else:
		# Возвращаемся в IDLE
		_change_state(State.IDLE)


# ===== Public API =====
func is_attacking() -> bool:
	"""Проверка, атакует ли игрок в данный момент"""
	return current_state in [State.ATTACK_1, State.ATTACK_2, State.ATTACK_3, State.CHARGED]


func is_combo_window_active() -> bool:
	"""Проверка, активно ли окно combo"""
	return combo_window_active


func get_current_state() -> State:
	"""Получить текущее состояние"""
	return current_state


func reset() -> void:
	"""Сброс состояния в IDLE"""
	_change_state(State.IDLE)
	_reset_attack_chain()


# ===== Combat Profile Event Handlers =====
func _on_critical_hit(attacker, defender, damage: float) -> void:
	"""Обработчик критического удара от CombatManager"""
	# Проверяем, что это именно наш игрок нанес крит
	if attacker == player and combat_profile_manager:
		combat_profile_manager.register_event(&"critical_hit")
