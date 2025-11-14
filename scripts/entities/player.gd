## scripts/entities/player.gd
## Расширенный контроллер игрока: движение, комбо, взаимодействие с CombatManager/ComboManager.

extends BaseEntity

# ===== Signals =====
signal combo_executed(combo_id: String, result: Dictionary)
signal basic_attack(side: String)
signal charged_attack(side: String)
signal parry_triggered()

# ===== Movement settings =====
@export var acceleration: float = 1200.0
@export var deceleration: float = 1600.0

# ===== Combat settings =====
@export var input_timeout: float = 0.7
@export var hold_threshold: float = 0.45
@export var max_sequence: int = 4
@export var attack_step_distance: float = 24.0
@export var hit_stop_time: float = 0.04
@export var camera_shake_strength: float = 4.0
@export var base_crit_chance: float = 0.05

const ATTACK_PRIMARY_ANIM: StringName = &"LP"
const ATTACK_SECONDARY_ANIM: StringName = &"RP"
const IDLE_ANIM: StringName = &"idle"
const MOVE_ANIM: StringName = &"run"
const DOUBLE_PRESS_WINDOW: float = 0.12

# ===== References =====
@onready var Combo: Node = get_node_or_null("/root/ComboManager")
@onready var Combat: Node = get_node_or_null("/root/CombatManager")
@onready var EffectMgr: Node = get_node_or_null("/root/EffectManager")
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

# ===== Internal state =====
var _sequence: Array[String] = []
var _sequence_timer: float = 0.0

var _left_holding: bool = false
var _right_holding: bool = false
var _left_hold_time: float = 0.0
var _right_hold_time: float = 0.0

var _last_left_pressed_time: float = -1.0
var _last_right_pressed_time: float = -1.0

var _is_attacking: bool = false
var _queued_attack: StringName = &""
var _current_attack: StringName = &""

var forced_target: Node = null


func _ready() -> void:
	super._ready()
	_configure_animation_loops()
	if not _sprite.is_playing():
		_sprite.play(IDLE_ANIM)
	_sprite.animation_finished.connect(_on_animation_finished)
	_sequence.clear()
	_sequence_timer = 0.0


func _process(delta: float) -> void:
	_handle_holds(delta)
	_update_sequence_timer(delta)


func _physics_process(delta: float) -> void:
	if _is_attacking:
		velocity = Vector2.ZERO
	else:
		velocity = _calculate_movement_velocity(delta)
	move_and_slide()
	_update_movement_animation()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("attack_left"):
		if Config.DEBUG_LOGS:
			print_debug("[Player] ЛКМ pressed")
		_on_attack_pressed("L")
	elif event.is_action_released("attack_left"):
		if Config.DEBUG_LOGS:
			print_debug("[Player] ЛКМ released")
		_on_attack_released("L")

	if event.is_action_pressed("attack_right"):
		if Config.DEBUG_LOGS:
			print_debug("[Player] ПКМ pressed")
		_on_attack_pressed("R")
	elif event.is_action_released("attack_right"):
		if Config.DEBUG_LOGS:
			print_debug("[Player] ПКМ released")
		_on_attack_released("R")

	if event.is_action_pressed("block"):
		_on_block_pressed()
	elif event.is_action_released("block"):
		_on_block_released()

	if event.is_action_pressed("dash"):
		_do_dash()


func _calculate_movement_velocity(delta: float) -> Vector2:
	var input_vector := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)
	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()

	var target_velocity := input_vector * speed
	var rate := acceleration if input_vector != Vector2.ZERO else deceleration
	return velocity.move_toward(target_velocity, rate * delta)


func _update_movement_animation() -> void:
	if _is_attacking:
		return

	if velocity.length() > 5.0:
		if _sprite.animation != MOVE_ANIM or not _sprite.is_playing():
			_sprite.play(MOVE_ANIM)
	else:
		if _sprite.animation != IDLE_ANIM or not _sprite.is_playing():
			_sprite.play(IDLE_ANIM)

	if velocity.x != 0.0:
		_sprite.flip_h = velocity.x < 0.0


func get_target() -> Node:
	if forced_target and is_instance_valid(forced_target):
		return forced_target
	return null


func _on_attack_pressed(side: String) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if side == "L":
		_last_left_pressed_time = now
		_left_holding = true
		_left_hold_time = 0.0
	elif side == "R":
		_last_right_pressed_time = now
		_right_holding = true
		_right_hold_time = 0.0


func _on_attack_released(side: String) -> void:
	if side == "L":
		_left_holding = false
		var held := _left_hold_time >= hold_threshold
		_left_hold_time = 0.0
		if held:
			_register_input("HOLD_L")
			_execute_charged_attack("L")
		else:
			_register_input("L")
			
	elif side == "R":
		_right_holding = false
		var held := _right_hold_time >= hold_threshold
		_right_hold_time = 0.0
		if held:
			_register_input("HOLD_R")
			_execute_charged_attack("R")
		else:
			_register_input("R")
			


func _on_block_pressed() -> void:
	_register_input("BLOCK")
	emit_signal("parry_triggered")


func _on_block_released() -> void:
	pass


func _handle_holds(delta: float) -> void:
	if _left_holding:
		_left_hold_time += delta
	if _right_holding:
		_right_hold_time += delta


func _register_input(token: String) -> void:
	if token.is_empty():
		return
	
	_sequence.append(token)
	if _sequence.size() > max_sequence:
		_sequence = _sequence.slice(_sequence.size() - max_sequence, max_sequence)
	_sequence_timer = input_timeout
	
	if Config.DEBUG_LOGS:
		print_debug("[Player] Зарегистрирован инпут: %s, последовательность: %s" % [token, _sequence])


func _try_execute_sequence() -> void:
	if Config.DEBUG_LOGS:
		print_debug("[Player] _try_execute_sequence вызвана, последовательность: %s" % _sequence)
	
	if _sequence.is_empty():
		return
	
	# Если это заряженная атака — уже выполнена, очистить последовательность
	if _sequence.size() == 1 and (_sequence[0] == "HOLD_L" or _sequence[0] == "HOLD_R"):
		# Выполняем заряженную атаку
		var side := "L" if _sequence[0] == "HOLD_L" else "R"
		if Config.DEBUG_LOGS:
			print_debug("[Player] Выполняем заряженную атаку: %s" % _sequence[0])
		_execute_charged_attack(side) # <-- Выполняем заряженную атаку
		_sequence.clear() # <-- Теперь сбрасываем после выполнения
		return
	
	# Попытка найти комбо по текущей последовательности
	var combo_id := ""
	if Combo and Combo.has_method("find_combo_by_sequence"):
		combo_id = Combo.find_combo_by_sequence(_sequence)
	
	if Config.DEBUG_LOGS:
		print_debug("[Player] Найдено комбо: %s" % combo_id)
	
	# Если комбо найдено — выполнить
	if combo_id != "":
		# Для базовых одиночных атак (basic_l, basic_r) используем _execute_basic_attack
		if combo_id == "basic_l" or combo_id == "basic_r":
			var side := "L" if combo_id == "basic_l" else "R"
			if Config.DEBUG_LOGS:
				print_debug("[Player] Выполняем базовую атаку через комбо: %s" % side)
			_execute_basic_attack(side)
		else:
			_execute_combo(combo_id)
		_sequence.clear()
		
		return


func _update_sequence_timer(delta: float) -> void:
	if _sequence.is_empty():
		return
	_sequence_timer -= delta
	if _sequence_timer <= 0.0:
		# Таймаут последовательности - выполнить то что есть
		_try_execute_sequence()
		_sequence.clear()


func _execute_basic_attack(side_token: String) -> void:
	if Config.DEBUG_LOGS:
		print_debug("[Player] _execute_basic_attack вызвана для стороны: %s" % side_token)
	
	var weapon_data: Dictionary = {
		"base_damage": attack,
		"crit_chance": base_crit_chance
	}
	var target := get_target()
	
	# Всегда проигрываем анимацию атаки, даже если нет цели
	_play_attack_animation(side_token)
	_attack_step("basic")
	emit_signal("basic_attack", side_token)
	
	# Если есть цель - наносим урон через CombatManager
	if target:
		var result: CombatManager.AttackResult = null
		var combo_id := "basic_l" if side_token == "L" else "basic_r"
		
		if Combat and Combat.has_method("execute_sequence") and Combo and Combo.has_combo(combo_id):
			result = Combat.execute_sequence(self, target, combo_id, weapon_data)
		
		if result and result.success:
			_do_attack_feedback(result)


func _execute_combo(combo_id: String) -> void:
	var weapon_data: Dictionary = {
		"base_damage": attack,
		"crit_chance": base_crit_chance
	}
	var target := get_target()
	
	# Всегда проигрываем анимацию комбо
	_play_combo_animation(combo_id)
	_attack_step("combo")
	
	# Если есть цель - наносим урон через CombatManager
	if target:
		var result: CombatManager.AttackResult = null
		
		if Combat and Combat.has_method("execute_sequence"):
			result = Combat.execute_sequence(self, target, combo_id, weapon_data)
		
		if result and result.success:
			emit_signal("combo_executed", combo_id, {
				"success": result.success,
				"damage": result.damage,
				"crit": result.crit
			})
			_do_attack_feedback(result)
		else:
			emit_signal("combo_executed", combo_id, {})
	else:
		# Нет цели - просто сигнал без урона
		emit_signal("combo_executed", combo_id, {})


func _execute_charged_attack(side_token: String) -> void:
	var weapon_data: Dictionary = {
		"base_damage": attack * 1.5,
		"crit_chance": base_crit_chance + 0.1
	}
	var target := get_target()
	var combo_id := "charged_attack_L" if side_token == "L" else "charged_attack_R"
	
	# Всегда проигрываем анимацию заряженной атаки
	_play_attack_animation(side_token, true)
	_attack_step("charged")
	emit_signal("charged_attack", side_token)
	
	# Если есть цель - наносим урон через CombatManager
	if target:
		var result: CombatManager.AttackResult = null
		
		if Combat and Combat.has_method("execute_sequence") and Combo and Combo.has_combo(combo_id):
			result = Combat.execute_sequence(self, target, combo_id, weapon_data)
		
		if result and result.success:
			_do_attack_feedback(result)
			emit_signal("combo_executed", combo_id, {
				"success": result.success,
				"damage": result.damage,
				"crit": result.crit
			})
		else:
			emit_signal("combo_executed", combo_id, {})
	else:
		# Нет цели - просто сигнал без урона
		emit_signal("combo_executed", combo_id, {})


func _do_attack_feedback(res) -> void:
	var hit := false
	var dmg := 0.0
	if typeof(res) == TYPE_DICTIONARY:
		hit = res.get("success", false)
		var r = res.get("result", {})
		if typeof(r) == TYPE_DICTIONARY:
			dmg = r.get("damage", 0.0)
	elif res is CombatManager.AttackResult:
		hit = res.success
		dmg = res.damage

	if hit:
		_hit_stop(hit_stop_time)
		var cam := get_node_or_null("/root/Camera2D")
		if cam and cam.has_method("shake"):
			var shake_power: float = clamp(dmg, 1.0, camera_shake_strength)
			cam.call("shake", shake_power)


func _attack_step(kind: String) -> void:
	var dist := attack_step_distance
	if kind == "charged":
		dist *= 1.4
	elif kind == "combo":
		dist *= 1.2
	var dir := Vector2.RIGHT
	if is_facing_left():
		dir = Vector2.LEFT
	translate(dir * dist)


func _do_dash() -> void:
	var dash_strength := 200.0
	var dir := Vector2.RIGHT
	if is_facing_left():
		dir = Vector2.LEFT
	translate(dir * dash_strength * get_process_delta_time())


func _hit_stop(duration: float) -> void:
	if duration <= 0.0:
		return
	Engine.time_scale = 0.001
	call_deferred("_restore_time_scale", duration)


func _restore_time_scale(duration: float) -> void:
	var t := get_tree().create_timer(duration)
	await t.timeout
	Engine.time_scale = 1.0


func is_facing_left() -> bool:
	return _sprite.flip_h


func force_combo(combo_id: String) -> void:
	_execute_combo(combo_id)


func _play_attack_animation(side: String, charged: bool = false) -> void:
	if Config.DEBUG_LOGS:
		print_debug("[Player] _play_attack_animation side=%s, charged=%s" % [side, charged])
	
	var anim := ATTACK_PRIMARY_ANIM
	if side == "R":
		anim = ATTACK_SECONDARY_ANIM
	if charged and _sprite.sprite_frames:
		var charged_anim_name := "%s_charged" % side.to_lower()
		var charged_anim := StringName(charged_anim_name)
		if _sprite.sprite_frames.has_animation(charged_anim):
			anim = charged_anim
	
	if Config.DEBUG_LOGS:
		print_debug("[Player] Выбрана анимация: %s" % anim)
	
	# Обновляем flip_h на основе того, куда смотрит персонаж
	if velocity.x < 0.0:
		_sprite.flip_h = true
	elif velocity.x > 0.0:
		_sprite.flip_h = false
	
	_request_attack(anim)


func _play_combo_animation(combo_id: String) -> void:
	if Config.DEBUG_LOGS:
		print_debug("[Player] _play_combo_animation вызвана для комбо: %s" % combo_id)
	
	if not _sprite.sprite_frames:
		return
	
	# Сначала проверяем, есть ли анимация с именем самого комбо
	var combo_anim := StringName(combo_id)
	if _sprite.sprite_frames.has_animation(combo_anim):
		if Config.DEBUG_LOGS:
			print_debug("[Player] Найдена анимация по ID комбо: %s" % combo_anim)
		_request_attack(combo_anim)
		return
	
	# Иначе ищем в данных комбо
	if Combo:
		var data: Dictionary = Combo.get_combo(combo_id)
		if data.has("animation"):
			var anim_name := StringName(data["animation"])
			if Config.DEBUG_LOGS:
				print_debug("[Player] Анимация из данных комбо: %s, существует: %s" % [anim_name, _sprite.sprite_frames.has_animation(anim_name)])
			if _sprite.sprite_frames.has_animation(anim_name):
				_request_attack(anim_name)
				return
	
	if Config.DEBUG_LOGS:
		print_debug("[Player] Анимация для комбо %s не найдена!" % combo_id)


func _request_attack(animation_name: StringName) -> void:
	if _is_attacking:
		_queued_attack = animation_name
		return
	_start_attack(animation_name)


func _start_attack(animation_name: StringName) -> void:
	if not _sprite.sprite_frames or not _sprite.sprite_frames.has_animation(animation_name):
		return
	_is_attacking = true
	_current_attack = animation_name
	_sprite.play(animation_name)


func _on_animation_finished() -> void:
	if not _is_attacking:
		return
	if _queued_attack != &"":
		var next_attack := _queued_attack
		_queued_attack = &""
		_start_attack(next_attack)
		return
	_is_attacking = false
	_current_attack = &""
	_update_movement_animation()


func _configure_animation_loops() -> void:
	if not _sprite.sprite_frames:
		return
	var frames := _sprite.sprite_frames
	for attack_anim in [ATTACK_PRIMARY_ANIM, ATTACK_SECONDARY_ANIM]:
		if frames.has_animation(attack_anim) and frames.get_animation_loop(attack_anim):
			frames.set_animation_loop(attack_anim, false)
