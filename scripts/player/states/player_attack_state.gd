# scripts/player/states/player_attack_state.gd
# Attack state - player performs combo attacks

class_name PlayerAttackState
extends PlayerState

const COMBO_BUFFER_WINDOW: float = 0.6  # Увеличили для более легкого ввода комбо
const ATTACK_COOLDOWN: float = 0.3  # Уменьшили для более динамичного боя

var _combo_manager: Node = null
var _combat_manager: Node = null
var _current_anim_name: String = ""
var _has_buffered_next: bool = false

func enter() -> void:
	# Get managers
	if not _combo_manager:
		_combo_manager = player.get_node_or_null("/root/ComboManager")
	if not _combat_manager:
		_combat_manager = player.get_node_or_null("/root/CombatManager")
	
	# Execute combo based on current sequence
	_execute_combo()
	
	# Connect to animation finished (single connection)
	if fsm.animation_player:
		if not fsm.animation_player.animation_finished.is_connected(_on_animation_finished):
			fsm.animation_player.animation_finished.connect(_on_animation_finished)
	
	if Config.DEBUG_LOGS:
		print("[FSM] attack → enter, sequence: %s" % [str(fsm.get_sequence())])

func exit() -> void:
	# Disconnect animation signals to prevent callbacks after state change
	if fsm.animation_player and fsm.animation_player.animation_finished.is_connected(_on_animation_finished):
		fsm.animation_player.animation_finished.disconnect(_on_animation_finished)
	if fsm.sprite and fsm.sprite.animation_finished.is_connected(_on_sprite_animation_finished):
		fsm.sprite.animation_finished.disconnect(_on_sprite_animation_finished)
	
	# Clear hit detection state
	fsm.combat_data["hit_targets"].clear()
	fsm.combat_data["hit_window_open"] = false
	fsm.combat_data["active_attack_request"] = null
	_has_buffered_next = false
	_current_anim_name = ""

func update(delta: float) -> void:
	# Check if attack animation finished
	if _current_anim_name.is_empty():
		# Check if we have buffered attacks to continue combo
		if _has_buffered_next and fsm.combat_data["combo_buffer_timer"] > 0.0:
			if fsm.can_attack():
				# Continue combo immediately
				_has_buffered_next = false
				fsm.combat_data["combo_buffer_timer"] = 0.0
				_execute_combo()
				return
		
		# No buffered input or cooldown not ready - return to idle
		if fsm.combat_data["combo_buffer_timer"] <= 0.0:
			fsm.reset_sequence()
		transition_to("idle")

func physics_update(_delta: float) -> void:
	# Minimal movement during attack (slight drift)
	player.move_and_slide()

func on_input(event: InputEvent) -> void:
	# Buffer next attack input
	if event.is_action_pressed("attack_left"):
		fsm.add_to_sequence("L")
		fsm.combat_data["combo_buffer_timer"] = COMBO_BUFFER_WINDOW
		_has_buffered_next = true
		if Config.DEBUG_LOGS:
			print("[FSM] attack → buffered L, sequence: %s" % [str(fsm.get_sequence())])
	
	elif event.is_action_pressed("attack_right"):
		fsm.add_to_sequence("R")
		fsm.combat_data["combo_buffer_timer"] = COMBO_BUFFER_WINDOW
		_has_buffered_next = true
		if Config.DEBUG_LOGS:
			print("[FSM] attack → buffered R, sequence: %s" % [str(fsm.get_sequence())])

func _execute_combo() -> void:
	"""Find combo by sequence and execute"""
	var sequence = fsm.get_sequence()
	if sequence.is_empty():
		transition_to("idle")
		return
	
	# Determine weapon type
	var weapon_type = "weapon" if player.stance == player.Stance.FIGHT else "unarmed"
	
	# Try to find combo via ComboManager
	var combo_id = ""
	var anim_name = ""
	var used_tail_len = 0
	
	if _combo_manager and _combo_manager.has_method("find_combo_by_sequence"):
		for len in range(sequence.size(), 0, -1):
			var start_index = sequence.size() - len
			var tail = sequence.slice(start_index, sequence.size())
			var candidate = _combo_manager.find_combo_by_sequence(tail, weapon_type)
			if not candidate.is_empty():
				combo_id = candidate
				used_tail_len = len
				break
		
		if not combo_id.is_empty():
			var combo_data = _combo_manager.get_combo(combo_id)
			if not combo_data.is_empty():
				anim_name = combo_data.get("weapon_animation", combo_data.get("animation", ""))
	
	# Fallback: use basic attack animation based on last input
	if anim_name.is_empty():
		var last_input = sequence[-1] if sequence.size() > 0 else "L"
		if weapon_type == "unarmed":
			anim_name = "punchLeft" if last_input == "L" else "punchRight"
		else:
			# Determine attack animation based on sequence length (simple combo)
			var attack_num = mini(sequence.size(), 3)
			anim_name = "attack%d" % attack_num
		used_tail_len = 1
		
		if Config.DEBUG_LOGS:
			print("[FSM] attack → using fallback animation: %s" % anim_name)
	
	# Build attack request
	if _combat_manager and _combat_manager.has_method("build_attack_request") and not combo_id.is_empty():
		var weapon_data = _get_weapon_data()
		var request = _combat_manager.build_attack_request(player, combo_id, weapon_data)
		if request and _combat_manager.validate_attack_request(request):
			request.meta["input_sequence"] = sequence.duplicate()
			request.meta["started_at"] = Time.get_ticks_msec()
			fsm.combat_data["active_attack_request"] = request
	
	# Play animation via AnimationPlayer (has method tracks for hit detection)
	if fsm.animation_player and fsm.animation_player.has_animation(anim_name):
		_current_anim_name = anim_name
		# Play with faster speed for more dynamic combat
		fsm.animation_player.speed_scale = 1.3  # 30% faster animations
		fsm.animation_player.play(anim_name)
		
		# Consume used sequence
		for i in range(used_tail_len):
			if not sequence.is_empty():
				sequence.pop_front()
		
		if Config.DEBUG_LOGS:
			print("[FSM] attack → executing: %s (anim: %s)" % [combo_id if combo_id else "fallback", anim_name])
	# Fallback: try AnimatedSprite2D
	elif fsm.sprite and fsm.sprite.sprite_frames.has_animation(anim_name):
		_current_anim_name = anim_name
		# Speed up sprite animations too
		fsm.sprite.speed_scale = 1.5  # Even faster for sprite animations
		fsm.sprite.play(anim_name)
		
		# Connect to sprite animation finished
		if not fsm.sprite.animation_finished.is_connected(_on_sprite_animation_finished):
			fsm.sprite.animation_finished.connect(_on_sprite_animation_finished)
		
		for i in range(used_tail_len):
			if not sequence.is_empty():
				sequence.pop_front()
		
		if Config.DEBUG_LOGS:
			print("[FSM] attack → fallback sprite anim: %s" % anim_name)
	else:
		if Config.DEBUG_LOGS:
			push_warning("[FSM] attack → animation not found: %s" % anim_name)
		fsm.reset_sequence()
		transition_to("idle")

func _on_sprite_animation_finished() -> void:
	"""Fallback for sprite animation completion"""
	_current_anim_name = ""
	fsm.combat_data["attack_cooldown"] = ATTACK_COOLDOWN
	
	# Reset sprite speed
	if fsm.sprite:
		fsm.sprite.speed_scale = 1.0
	
	if Config.DEBUG_LOGS:
		print("[FSM] attack → sprite animation finished")

func _on_animation_finished(anim_name: StringName) -> void:
	"""Called when AnimationPlayer finishes playing animation"""
	if anim_name == _current_anim_name:
		_current_anim_name = ""
		fsm.combat_data["attack_cooldown"] = ATTACK_COOLDOWN
		
		# Reset animation speed
		if fsm.animation_player:
			fsm.animation_player.speed_scale = 1.0
		
		if Config.DEBUG_LOGS:
			print("[FSM] attack → animation finished: %s" % anim_name)

## Called from AnimationPlayer method track at end of hit window
func on_attack_end() -> void:
	"""Closes the hit window and ends the attack animation"""
	fsm.combat_data["hit_window_open"] = false
	fsm.combat_data["hit_targets"].clear()
	
	# End the attack (same as animation_finished)
	# This is crucial because some attack animations are looped and animation_finished won't fire
	if not _current_anim_name.is_empty():
		_current_anim_name = ""
		fsm.combat_data["attack_cooldown"] = ATTACK_COOLDOWN
		
		if Config.DEBUG_LOGS:
			print("[FSM] attack → animation ended (via method track)")
	
	if Config.DEBUG_LOGS:
		print("[FSM] attack → hit window closed")

func _get_weapon_data() -> Dictionary:
	# TODO: Get actual weapon data from player's equipment
	return {
		"damage": 10.0,
		"crit_chance": 0.15,
		"type": "sword"
	}

## Called from AnimationPlayer method track
func on_attack_frame() -> void:
	"""Called during attack animation to perform hit detection"""
	if Config.DEBUG_LOGS:
		print("[FSM] attack → on_attack_frame called!")
	
	if not fsm.hitbox:
		if Config.DEBUG_LOGS:
			print("[FSM] attack → ERROR: hitbox not found!")
		return
	
	# Clear previous targets
	fsm.combat_data["hit_targets"].clear()
	fsm.combat_data["hit_window_open"] = true
	
	# Check overlapping bodies
	var overlapping_bodies = fsm.hitbox.get_overlapping_bodies()
	if Config.DEBUG_LOGS:
		print("[FSM] attack → checking %d overlapping bodies" % overlapping_bodies.size())
	
	for body in overlapping_bodies:
		if body == player:
			continue
		if Config.DEBUG_LOGS:
			print("[FSM] attack → found body: %s, groups: %s" % [body.name, body.get_groups()])
		
		if not body.is_in_group("enemies"):
			if Config.DEBUG_LOGS:
				print("[FSM] attack → body not in enemies group")
			continue
		
		if not body.has_method("take_damage"):
			if Config.DEBUG_LOGS:
				print("[FSM] attack → body has no take_damage method")
			continue
		
		if body in fsm.combat_data["hit_targets"]:
			continue
		
		fsm.combat_data["hit_targets"].append(body)
		if Config.DEBUG_LOGS:
			print("[FSM] attack → HIT! Applying damage to %s" % body.name)
		_apply_hit_to_target(body)
	
	# Check overlapping areas
	var overlapping_areas = fsm.hitbox.get_overlapping_areas()
	for area in overlapping_areas:
		var enemy = area.get_parent()
		if not enemy or enemy == player:
			continue
		if not enemy.is_in_group("enemies") or not enemy.has_method("take_damage"):
			continue
		if enemy in fsm.combat_data["hit_targets"]:
			continue
		
		fsm.combat_data["hit_targets"].append(enemy)
		_apply_hit_to_target(enemy)

func _apply_hit_to_target(target: Node) -> void:
	"""Apply damage to target using CombatManager"""
	if Config.DEBUG_LOGS:
		print("[FSM] attack → _apply_hit_to_target: %s" % target.name)
	
	# ALWAYS use direct damage for now (CombatManager may not be working)
	if target.has_method("take_damage"):
		var damage_amount = 15  # Base damage
		if Config.DEBUG_LOGS:
			print("[FSM] attack → calling take_damage(%d) on %s" % [damage_amount, target.name])
		target.take_damage(damage_amount, player)
		if Config.DEBUG_LOGS:
			print("[FSM] attack → damage applied successfully!")
	else:
		if Config.DEBUG_LOGS:
			print("[FSM] attack → ERROR: target has no take_damage method!")
