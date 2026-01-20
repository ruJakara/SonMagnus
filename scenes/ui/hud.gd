extends CanvasLayer

# --- 1. ССЫЛКИ НА ПОЛОСКИ ---
@onready var health_bar = $StatusBars/HealthBar
@onready var mana_bar = $StatusBars/ManaBar
@onready var stamina_bar = $StatusBars/StaminaBar
@onready var hunger_bar = $StatusBars/HungerBar

# --- 2. ССЫЛКИ НА СЛОТЫ ---
@onready var skills_container = $BottomBar/CenterContainer/Skills
# Ссылки на большие квадраты (оружие)
@onready var left_item_panel = $BottomBar/CenterContainer/LeftItems/LeftWeapon
@onready var right_item_panel = $BottomBar/CenterContainer/RightItems/RightWeapon

# --- 3. ССЫЛКИ НА ЧАСЫ ---
@onready var celestial_pivot = $ClockContainer/DayNightClock/CelestialPivot

# --- 4. НОВОЕ: Player Info Panel ---
@onready var player_info_panel: Panel = $PlayerInfoPanel
@onready var stance_label: Label = $PlayerInfoPanel/VBox/StanceLabel
@onready var state_label: Label = $PlayerInfoPanel/VBox/StateLabel
@onready var combo_hint_label: Label = $PlayerInfoPanel/VBox/ComboHintLabel

# --- 5. НОВОЕ: Combos Panel ---
@onready var combos_panel: Panel = $CombosPanel
@onready var combos_list: VBoxContainer = $CombosPanel/ScrollContainer/VBox

var skill_panels: Array[Panel] = []
var debug_game_time: float = 12.0
var _bound_player: Node = null
var _combo_manager: Node = null

func _ready():
	# Get ComboManager
	_combo_manager = get_node_or_null("/root/ComboManager")
	
	# Инициализация скиллов
	if skills_container:
		for child in skills_container.get_children():
			if child is Panel:
				skill_panels.append(child)
		highlight_skill(0)
	
	# Делаем оружие чуть темнее на старте
	if left_item_panel: left_item_panel.modulate = Color(0.8, 0.8, 0.8, 1)
	if right_item_panel: right_item_panel.modulate = Color(0.8, 0.8, 0.8, 1)
	
	# Проверяем часы
	if not celestial_pivot:
		print("Warning: CelestialPivot not found in HUD!")
	
	# НОВОЕ: Инициализируем player info панель
	if player_info_panel:
		player_info_panel.visible = true
	if combos_panel:
		combos_panel.visible = false  # Hidden by default, toggle with TAB
	
	# Populate combos
	_populate_combos()
	
	_try_bind_player()

func _process(delta):
	# Подхватываем игрока
	if _bound_player == null or not is_instance_valid(_bound_player):
		_try_bind_player()
	
	# Update player info (stance, state)
	if _bound_player:
		_update_player_info()
	
	# Логика времени
	debug_game_time += delta 
	if debug_game_time >= 24.0:
		debug_game_time = 0.0
	update_clock(debug_game_time)

func _try_bind_player() -> void:
	var p: Node = null
	if get_tree():
		p = get_tree().get_first_node_in_group("player")
	if p == null:
		return
	if _bound_player == p:
		return
	
	_bound_player = p
	
	# Подписка на сигналы статов (если доступны)
	if p.has_signal("health_changed"):
		var c := Callable(self, "update_health")
		if not p.health_changed.is_connected(c):
			p.health_changed.connect(c)
	if p.has_signal("mana_changed"):
		var c := Callable(self, "update_mana")
		if not p.mana_changed.is_connected(c):
			p.mana_changed.connect(c)
	if p.has_signal("stamina_changed"):
		var c := Callable(self, "update_stamina")
		if not p.stamina_changed.is_connected(c):
			p.stamina_changed.connect(c)
	if p.has_signal("hunger_changed"):
		var c := Callable(self, "update_hunger")
		if not p.hunger_changed.is_connected(c):
			p.hunger_changed.connect(c)
	
	# Первичная синхронизация значений (через get(), чтобы не падать на тестовых объектах)
	var hp = p.get("health")
	var max_hp = p.get("max_health")
	if hp != null and max_hp != null:
		update_health(hp, max_hp)
	
	var mp = p.get("mana")
	var max_mp = p.get("max_mana")
	if mp != null and max_mp != null:
		update_mana(mp, max_mp)
	
	var st = p.get("stamina")
	var max_st = p.get("max_stamina")
	if st != null and max_st != null:
		update_stamina(st, max_st)
	
	var hg = p.get("hunger")
	var max_hg = p.get("max_hunger")
	if hg != null and max_hg != null:
		update_hunger(hg, max_hg)

func _input(event: InputEvent) -> void:
	# TAB: Toggle combos panel
	if event.is_action_pressed("ui_focus_next") and combos_panel:  # Tab key
		combos_panel.visible = !combos_panel.visible

func _update_player_info() -> void:
	"""Update player stance and state display"""
	if not _bound_player:
		return
	
	# Update stance
	if stance_label:
		var stance = _bound_player.get("stance")
		if stance != null:
			var stance_text = "FIGHT" if stance == 1 else "RELAX"
			stance_label.text = "Stance: %s (Q)" % stance_text
	
	# Update state
	if state_label:
		var state_machine = _bound_player.get("state_machine")
		if state_machine:
			var current_state = state_machine.get("current_state_name")
			if current_state:
				state_label.text = "State: %s" % current_state
	
	# Update combo hint
	if combo_hint_label:
		combo_hint_label.text = "TAB - Show Combos"

func _populate_combos() -> void:
	"""Populate available combos list"""
	if not _combo_manager or not combos_list:
		return
	
	# Clear existing
	for child in combos_list.get_children():
		child.queue_free()
	
	# Add header
	var header = Label.new()
	header.text = "=== AVAILABLE COMBOS ==="
	header.add_theme_font_size_override("font_size", 16)
	combos_list.add_child(header)
	
	# Get all combos
	var weapon_types = ["unarmed", "weapon"]
	for weapon_type in weapon_types:
		var type_label = Label.new()
		type_label.text = "\n[%s]" % weapon_type.to_upper()
		type_label.add_theme_color_override("font_color", Color.YELLOW)
		combos_list.add_child(type_label)
		
		if _combo_manager.has_method("get_combos_for_weapon"):
			var weapon_combos = _combo_manager.get_combos_for_weapon(weapon_type)
			if weapon_combos.size() == 0:
				var no_combo = Label.new()
				no_combo.text = "  (No combos)"
				no_combo.add_theme_color_override("font_color", Color.GRAY)
				combos_list.add_child(no_combo)
			else:
				for combo_id in weapon_combos:
					var combo_data = _combo_manager.get_combo(combo_id)
					if not combo_data.is_empty():
						var sequence = combo_data.get("sequence", [])
						var name_str = combo_data.get("name", combo_id)
						var seq_str = " → ".join(sequence)
						
						var combo_label = Label.new()
						combo_label.text = "  %s: %s" % [seq_str, name_str]
						combo_label.add_theme_font_size_override("font_size", 12)
						combos_list.add_child(combo_label)

# --- 4. ФУНКЦИЯ ОБНОВЛЕНИЯ ЧАСОВ (НОВОЕ) ---
func update_clock(time_in_hours: float):
	if not celestial_pivot:
		return
		
	# Логика вращения:
	# В сутках 24 часа, круг 360 градусов. 360 / 24 = 15 градусов на час.
	# В нашей сцене Солнце прикреплено сверху (Rotation 0), а Луна снизу.
	# Значит Rotation 0 = 12:00 (Полдень).
	# Rotation 180 = 00:00 (Полночь).
	
	# Формула: (Время - 12) * 15
	# Пример: 12:00 -> (0) * 15 = 0 град. (Солнце вверху)
	# Пример: 18:00 -> (6) * 15 = 90 град. (Закат)
	# Пример: 00:00 -> (-12) * 15 = -180 град. (Луна вверху)
	
	var rotation_deg = (time_in_hours - 12.0) * 15.0
	celestial_pivot.rotation_degrees = rotation_deg

# --- 5. ФУНКЦИИ ОБНОВЛЕНИЯ СТАТУСА ---
func update_health(current, max_val):
	if health_bar:
		health_bar.max_value = max_val
		health_bar.value = current

func update_mana(current, max_val):
	if mana_bar:
		mana_bar.max_value = max_val
		mana_bar.value = current

func update_stamina(current, max_val):
	if stamina_bar:
		stamina_bar.max_value = max_val
		stamina_bar.value = current

func update_hunger(current, max_val):
	if hunger_bar:
		hunger_bar.min_value = 0
		hunger_bar.max_value = max_val
		hunger_bar.value = current

# --- 6. ПОДСВЕТКА СКИЛЛОВ ---
func highlight_skill(index: int):
	for i in range(skill_panels.size()):
		var panel = skill_panels[i]
		# Проверяем стиль рамки, чтобы менять цвет границы
		var style = panel.get_theme_stylebox("panel")
		
		# Создаем копию стиля, чтобы не менять его у всех сразу (если они используют один ресурс)
		# Но для производительности лучше, если стили уже уникальны или `local_to_scene`
		if style is StyleBoxFlat:
			if i == index:
				# Активный: Белая рамка, ярче
				style.border_color = Color(1, 1, 1, 1)
				panel.modulate = Color(1.2, 1.2, 1.2, 1)
			else:
				# Неактивный: Серая рамка, темнее
				style.border_color = Color(0.5, 0.5, 0.5, 0.5)
				panel.modulate = Color(0.7, 0.7, 0.7, 1)

# --- 7. АНИМАЦИЯ ПРЕДМЕТОВ ---
func animate_item_usage(side: String):
	var target_panel: Panel = null
	
	if side == "left":
		target_panel = left_item_panel
	elif side == "right":
		target_panel = right_item_panel
		
	if target_panel:
		var tween = create_tween()
		# Вспышка (очень ярко)
		target_panel.modulate = Color(2.0, 2.0, 2.0, 1)
		# Плавное затухание обратно к нормальному цвету
		tween.tween_property(target_panel, "modulate", Color(0.8, 0.8, 0.8, 1), 0.5)
