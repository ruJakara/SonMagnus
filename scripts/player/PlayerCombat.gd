# scripts/player/PlayerCombat.gd
# Гибкая система комбо на основе последовательностей
# Поддержка неограниченных цепочек, кулдауна, отдачи

extends Node

# ===== Состояния =====
enum State {
	IDLE,
	RUN,
	WALK,
	ATTACKING,  # ← одно состояние для всех атак
	CHARGING,
	CASTING,
	DEATH,
	HURT
}

# ===== Signals =====
signal state_changed(old_state: State, new_state: State)
signal combo_executed(combo_id: String)
signal attack_cooldown_started(duration: float)

# ===== Экспорт =====
@export var base_combo_window: float = 0.3
@export var base_recoil_strength: float = 10.0
@export var base_attack_cooldown: float = 0.2

# ===== Внутреннее состояние =====
var current_state: State = State.IDLE
var input_sequence: Array = []          # ["L", "L", "R", ...]
var current_combo_id: String = ""
var _attack_cooldown: float = 0.0
var _combo_window_timer: float = 0.0
var has_weapon: bool = false            # ← заглушка для оружия

# ===== References =====
var player: CharacterBody2D = null
var animation_player: AnimationPlayer = null
var combat_manager: Node = null
var combo_manager: Node = null
var combat_profile_manager: Node = null

func _ready() -> void:
	_setup_references()

func _setup_references() -> void:
	player = get_parent() as CharacterBody2D
	animation_player = player.get_node_or_null("AnimationPlayer")
	combat_manager = get_node_or_null("/root/CombatManager")
	combo_manager = get_node_or_null("/root/ComboManager")
	combat_profile_manager = get_node_or_null("/root/CombatProfileManager")
	
	if combat_manager and not combat_manager.is_connected("critical_hit", _on_critical_hit):
		combat_manager.connect("critical_hit", _on_critical_hit)

# ===== Input Handling =====
func handle_attack_input(side: String) -> void:
	if not _can_start_attack():
		return

	input_sequence.append(side)
	
	# Находим самую длинную подходящую комбинацию
	var matched_combo = _find_longest_matching_combo(input_sequence)
	
	if matched_combo != "":
		_execute_combo(matched_combo)
	else:
		# Нет совпадения — сбрасываем и делаем базовую атаку
		_reset_combo()
		var base_combo = "basic_l" if side == "L" else "basic_r"
		_execute_combo(base_combo)
		# И убираем последний ввод, чтобы не мешал
		if input_sequence.size() > 0:
			input_sequence.pop_back()

func _can_start_attack() -> bool:
	return current_state not in [State.DEATH, State.HURT] and _attack_cooldown <= 0.0

# ===== Combo Logic =====
func _find_longest_matching_combo(sequence: Array) -> String:
	# Ищем от самой длинной к короткой
	for i in range(sequence.size(), 0, -1):
		var candidate = sequence.slice(0, i)
		var combo_id = ComboManager.find_combo_by_sequence(candidate)
		if combo_id != "":
			return combo_id
	return ""

func _execute_combo(combo_id: String) -> void:
	var combo_data = ComboManager.get_combo(combo_id)
	if combo_data.is_empty():
		return

	# === ДВИЖЕНИЕ ВПЕРЁД (если нужно) ===
	var move_fwd = combo_data.get("move_forward", 0.0)
	if move_fwd > 0.0:
		var forward_dir = Vector2.RIGHT
		if player.is_facing_left():
			forward_dir = Vector2.LEFT
		player.translate(forward_dir * move_fwd)

	# === Состояние ===
	_change_state(State.ATTACKING)
	current_combo_id = combo_id

	# === Анимация ===
	_play_combo_animation(combo_id)

	# === Отдача ===
	var recoil = combo_data.get("recoil", base_recoil_strength)
	_apply_recoil(recoil)

	# === Кулдаун ===
	var cooldown = combo_data.get("cooldown", base_attack_cooldown)
	_attack_cooldown = cooldown
	emit_signal("attack_cooldown_started", cooldown)

	# === Окно комбо ===
	var window = combo_data.get("combo_window", base_combo_window)
	_combo_window_timer = window

	# === Урон ===
	_perform_attack(combo_id)

	emit_signal("combo_executed", combo_id)

func _perform_attack(combo_id: String) -> void:
	if not combat_manager:
		return

	var target = _find_target_in_front(player, 80.0)
	var weapon_data: Dictionary = { "base_damage": 10, "crit_chance": 0.1 }
	var result = combat_manager.execute_sequence(player, target, combo_id, weapon_data)

	if result and result.success and Config.DEBUG_LOGS:
		print_debug("[PlayerCombat] Атака %s: урон=%.1f" % [combo_id, result.damage])

# ===== State & Reset =====
func _change_state(new_state: State) -> void:
	if current_state == new_state:
		return
	var old = current_state
	current_state = new_state
	emit_signal("state_changed", old, new_state)

func _reset_combo() -> void:
	input_sequence.clear()
	_combo_window_timer = 0.0

# ===== Process =====
func _process(delta: float) -> void:
	# Кулдаун атаки
	if _attack_cooldown > 0.0:
		_attack_cooldown -= delta

	# Окно комбо
	if _combo_window_timer > 0.0:
		_combo_window_timer -= delta
		if _combo_window_timer <= 0.0:
			# Окно закрылось — сбрасываем последовательность
			# Но не очищаем полностью, на случай продолжения
			pass

	# Автоматический возврат в IDLE после атаки (если нет движения)
	if current_state == State.ATTACKING and not _is_attacking_animation_playing():
		if player.velocity.length() < 5.0:
			_change_state(State.IDLE)
		else:
			_change_state(State.RUN)

func _is_attacking_animation_playing() -> bool:
	# Можно улучшить через AnimationPlayer
	return animation_player and animation_player.is_playing()

# ===== Animation =====
func _play_combo_animation(combo_id: String) -> void:
	var combo_data = ComboManager.get_combo(combo_id)
	if combo_data.is_empty():
		return

	# Поддержка оружия: префикс
	var anim_key = "animation"
	if has_weapon:
		anim_key = "weapon_animation"

	var anim_name = combo_data.get(anim_key, combo_data.get("animation", "idle"))
	
	var sprite = player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		sprite.stop()
		sprite.play(anim_name)

	# Тайминг через AnimationPlayer
	var timing_anim = anim_name  # или отдельное поле в JSON
	if animation_player and animation_player.has_animation(timing_anim):
		animation_player.play(timing_anim)

func _apply_recoil(strength: float) -> void:
	var dir = Vector2.LEFT if player.is_facing_left() else Vector2.RIGHT
	player.velocity -= dir * strength * 20  # scale as needed

# ===== Target Finding =====
func _find_target_in_front(player: Node, range: float) -> Node:
	var direction = Vector2.RIGHT
	if player.is_facing_left():
		direction = Vector2.LEFT

	var start = player.global_position
	var end = start + direction * range

	var space_state = player.get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.new()
	query.from = start
	query.to = end
	query.collision_mask = 0
	query.exclude = [player]

	var result = space_state.intersect_ray(query)
	if result and result.collider is BaseEntity and result.collider != player:
		return result.collider
	return null

# ===== Public API =====
func is_attacking() -> bool:
	return current_state == State.ATTACKING

func get_current_combo() -> String:
	return current_combo_id

func reset() -> void:
	_change_state(State.IDLE)
	_reset_combo()
	_attack_cooldown = 0.0

# ===== Weapon Toggle (заглушка) =====
func toggle_weapon() -> void:
	has_weapon = not has_weapon
	print("Оружие: %s" % ("включено" if has_weapon else "выключено"))

# ===== Combat Profile =====
func _on_critical_hit(attacker, defender, damage: float) -> void:
	if attacker == player and combat_profile_manager:
		combat_profile_manager.register_event(&"critical_hit")
