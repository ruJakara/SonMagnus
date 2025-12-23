# scripts/player/PlayerCombat.gd
# Гибкая система комбо на основе последовательностей
# Поддержка неограниченных цепочек, кулдауна, отдачи

extends Node

# ===== Состояния =====
enum State {
	IDLE,
	RUN,
	WALK,
	ATTACKING,
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
var equipped_weapon: WeaponResource = null # Текущее оружие (ресурс)
var is_blocking: bool = false           # Состояние блока

# ===== References =====
var player: CharacterBody2D = null
var animation_player: AnimationPlayer = null
var combat_manager: Node = null
var combo_manager: Node = null
var combat_profile_manager: Node = null

func _ready() -> void:
	_setup_references()
	_configure_combat_animations()

func _setup_references() -> void:

	player = get_parent() as CharacterBody2D
	animation_player = player.get_node_or_null("AnimationPlayer")
	combat_manager = get_node_or_null("/root/CombatManager")
	combo_manager = get_node_or_null("/root/ComboManager")
	combat_profile_manager = get_node_or_null("/root/CombatProfileManager")
	
	# ===== NEW: Подключаем сигнал завершения анимации спрайта =====
	var sprite: AnimatedSprite2D = player.get_node_or_null("AnimatedSprite2D")
	if sprite and not sprite.is_connected("animation_finished", _on_sprite_animation_finished):
		sprite.connect("animation_finished", _on_sprite_animation_finished)
	# ==============================================================
	
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

# MODIFIED: проверка с учетом can_cancel
func _can_start_attack() -> bool:
	# Запрет атак в смерти или оглушении
	if current_state in [State.DEATH, State.HURT]:
		return false

	# Если уже атакуем — проверяем can_cancel и окно комбо
	if current_state == State.ATTACKING:
		var combo_data := ComboManager.get_combo(current_combo_id)
		var can_cancel: bool = combo_data.get("can_cancel", true)
		return can_cancel and _combo_window_timer > 0.0

	# В остальных состояниях — проверяем только кулдаун
	return _attack_cooldown <= 0.0

# ===== Combo Logic =====
func _find_longest_matching_combo(sequence: Array) -> String:
	# Определяем тип оружия для фильтрации комбо
	var weapon_type := "unarmed"
	if has_weapon:
		weapon_type = "weapon"
	
	# Ищем от самой длинной к короткой
	for i in range(sequence.size(), 0, -1):
		var candidate = sequence.slice(0, i)
		var combo_id = ComboManager.find_combo_by_sequence(candidate, weapon_type)
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
	var weapon_data: Dictionary = _get_weapon_stats()
	var result = combat_manager.execute_sequence(player, target, combo_id, weapon_data)

	if result and result.success and Config.DEBUG_LOGS:
		print_debug("[PlayerCombat] Атака %s: урон=%.1f" % [combo_id, result.damage])

func _get_weapon_stats() -> Dictionary:
	if equipped_weapon:
		return {
			"weapon_name": equipped_weapon.weapon_name,
			"weapon_type": equipped_weapon.weapon_type,
			"base_damage": equipped_weapon.base_damage,
			"crit_chance": equipped_weapon.crit_chance,
			"attack_speed": equipped_weapon.attack_speed,
			"block_power": equipped_weapon.block_power,
			"durability": equipped_weapon.durability,
			"max_durability": equipped_weapon.max_durability,
		}
	# Без оружия (кулаки)
	return {
		"weapon_name": "Кулаки",
		"weapon_type": "unarmed",
		"base_damage": 8.0,
		"crit_chance": 0.05,
		"attack_speed": 1.0,
		"block_power": 0.1,
		"durability": 0.0,
		"max_durability": 0.0,
	}


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

	# MODIFIED: окно комбо с автосбросом
	if _combo_window_timer > 0.0:
		_combo_window_timer -= delta
		if _combo_window_timer <= 0.0:
			_reset_combo()  # закрыли окно — сбросили цепочку

	# MODIFIED: возврат в IDLE/RUN/WALK с учетом лагеря
	if current_state == State.ATTACKING and not _is_attacking_animation_playing():
		if player.velocity.length() < 5.0:
			_change_state(State.IDLE)
		else:
			if player.has_method("is_camp") and player.is_camp():
				_change_state(State.WALK)
			else:
				_change_state(State.RUN)

func _is_attacking_animation_playing() -> bool:
	# Сначала проверяем тайминг через AnimationPlayer
	if animation_player and animation_player.is_playing():
		return true
	# Затем сверяемся со спрайтом (атакующая анимация в AnimatedSprite2D)
	var sprite: AnimatedSprite2D = player.get_node_or_null("AnimatedSprite2D")
	if sprite and sprite.is_playing():
		return true
	return false

# ===== Animation =====
func _play_combo_animation(combo_id: String) -> void:
	var combo_data = ComboManager.get_combo(combo_id)
	if combo_data.is_empty():
		return
	# Выбираем нужное имя анимации (оружие / без оружия)
	var anim_name := _get_animation_for_combo(combo_data)
	var sprite: AnimatedSprite2D = player.get_node_or_null("AnimatedSprite2D")

	# Проверяем наличие анимации у спрайта
	if sprite and sprite.sprite_frames and anim_name != "" and sprite.sprite_frames.has_animation(anim_name):
		_play_animation_safe(anim_name)
		return

	# Если анимации нет — используем безопасный запасной удар
	var fallback_anim := "punchLeft" if player.is_facing_left() else "punchRight"
	var missing_anim := anim_name if anim_name != "" else fallback_anim
	push_warning("# TODO: добавить анимацию: %s" % missing_anim)
	_play_animation_safe(fallback_anim)

func _get_animation_for_combo(combo_data: Dictionary) -> String:
	# Возвращает финальное имя анимации с учётом оружия и запасного варианта
	var unarmed_anim: String = combo_data.get("animation", "")
	var weapon_anim: String = combo_data.get("weapon_animation", "")

	if has_weapon:
		if weapon_anim != "":
			return weapon_anim
		var missing_weapon_anim := weapon_anim if weapon_anim != "" else "weapon_animation_missing"
		push_warning("# TODO: добавить анимацию: %s" % missing_weapon_anim)
		return unarmed_anim

	# Без оружия — используем базовую анимацию, при отсутствии — падение к weapon_anim
	if unarmed_anim != "":
		return unarmed_anim
	if weapon_anim != "":
		push_warning("# TODO: добавить анимацию: %s" % weapon_anim)
		return weapon_anim
	# Совсем нет имени — вернём пустую строку, дальше сработает фолбэк
	return ""

func _play_animation_safe(anim_name: String) -> void:
	# Безопасно играет анимацию спрайта и тайминга, игнорируя отсутствующие
	var sprite: AnimatedSprite2D = player.get_node_or_null("AnimatedSprite2D")
	var played := false

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		sprite.stop()
		sprite.play(anim_name)
		played = true

	if animation_player and animation_player.has_animation(anim_name):
		animation_player.play(anim_name)
		played = true

	if not played:
		push_warning("[PlayerCombat] Отсутствует анимация '%s' в AnimatedSprite2D/AnimationPlayer" % anim_name)

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
	# ВАЖНО: маска должна видеть слой врагов (3-й бит)
	query.collision_mask = 1 << 3
	query.exclude = [player]

	var result = space_state.intersect_ray(query)
	if not result:
		return null
	
	var collider = result.collider
	if not collider or collider == player:
		return null
	
	# Прямо на объекте есть take_damage
	if collider.has_method("take_damage"):
		return collider
	
	# Или у родителя (например, если попали в Hurtbox/дочерний узел)
	var parent : Node = collider.get_parent()
	if parent and parent.has_method("take_damage"):
		return parent
	
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


# ===== Weapon Toggle =====
signal weapon_equipped(weapon: WeaponResource)

func equip_weapon(weapon: WeaponResource) -> void:
	equipped_weapon = weapon
	has_weapon = equipped_weapon != null and equipped_weapon.weapon_type != "unarmed"
	emit_signal("weapon_equipped", equipped_weapon)

func toggle_weapon() -> void:
	has_weapon = not has_weapon
	
	# Проигрываем анимацию экипировки/снятия
	_play_weapon_toggle_animation(has_weapon)
	
	emit_signal("weapon_equipped", has_weapon)
	
	if Config.DEBUG_LOGS:
		print_debug("[PlayerCombat] Оружие: %s" % ("экипировано" if has_weapon else "снято"))

func _play_weapon_toggle_animation(equipping: bool) -> void:
	var anim_name := "equip_weapon" if equipping else "unequip_weapon"
	
	# Проверяем наличие анимации
	var sprite: AnimatedSprite2D = player.get_node_or_null("AnimatedSprite2D")
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
		return
	
	# Если анимации нет — просто показываем/скрываем оружие мгновенно
	push_warning("# TODO: добавить анимацию %s" % anim_name)
	_toggle_weapon_visibility(equipping)

func _toggle_weapon_visibility(visible: bool) -> void:
	# Заглушка: ищем узел Weapon (если есть) и меняем видимость
	var weapon_sprite = player.get_node_or_null("WeaponSprite")
	if weapon_sprite and weapon_sprite is Sprite2D:
		weapon_sprite.visible = visible

# NEW: заглушка для блока (пока пустая, доделаем в Этапе 2)
func handle_block_input(pressed: bool) -> void:
	is_blocking = pressed
	# TODO: Этап 2 - реализация блока (анимация, защита от урона и т.д.)

# ===== Combat Profile =====
func _on_critical_hit(attacker, defender, damage: float) -> void:
	if attacker == player and combat_profile_manager:
		combat_profile_manager.register_event(&"critical_hit")
# ===== Animation Events (вызываются из AnimationPlayer) =====

# Вызывается в момент нанесения урона (ключевой кадр атаки)
# ===== Animation Events =====
func _on_attack_frame() -> void:
	if Config.DEBUG_LOGS:
		print_debug("[PlayerCombat] Attack frame")
	# TODO: VFX, hitbox enable, звук удара

func _on_attack_end() -> void:
	if Config.DEBUG_LOGS:
		print_debug("[PlayerCombat] Attack end")
	# Можно принудительно вернуть в IDLE, если нужно
	# _change_state(State.IDLE)

func _on_sprite_animation_finished() -> void:
	var sprite: AnimatedSprite2D = player.get_node_or_null("AnimatedSprite2D")
	if not sprite:
		return
	
	# Останавливаем зацикливание боевых анимаций
	var anim := sprite.animation
	if anim in ["kick", "chargedPunch", "punchCombo2", "punchCombo3", 
				"attack1", "attack2", "attack3", "attack4", "dashPunch"]:
		sprite.stop()

func _configure_combat_animations() -> void:
	# 1. Отключаем loop в AnimatedSprite2D
	var sprite: AnimatedSprite2D = player.get_node_or_null("AnimatedSprite2D")
	if sprite and sprite.sprite_frames:
		var frames := sprite.sprite_frames
		var combat_anims := [
			"punchLeft", "punchRight", "kick", "chargedPunch",
			"punchCombo2", "punchCombo3", "dashPunch",
			"attack1", "attack2", "attack3", "attack4",
			"equip_weapon", "unequip_weapon"
		]
		
		for anim in combat_anims:
			if frames.has_animation(anim):
				frames.set_animation_loop(anim, false)
	
	# 2. NEW: Отключаем loop в AnimationPlayer
	if animation_player:
		var anim_list := animation_player.get_animation_list()
		for anim_name in anim_list:
			var anim := animation_player.get_animation(anim_name)
			if anim:
				anim.loop_mode = Animation.LOOP_NONE  # <- вот это главное!
		
		if Config.DEBUG_LOGS:
			print_debug("[PlayerCombat] Отключен loop для %d AnimationPlayer анимаций" % anim_list.size())
