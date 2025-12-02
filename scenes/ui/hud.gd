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

# --- 3. ССЫЛКИ НА ЧАСЫ (НОВОЕ) ---
# Ссылка на узел вращения, который мы добавили в сцену
@onready var celestial_pivot = $ClockContainer/DayNightClock/CelestialPivot

var skill_panels: Array[Panel] = []

# Переменная для теста времени (от 0 до 24)
var debug_game_time: float = 12.0 # Начинаем с полдня

func _ready():
	# Инициализация скиллов
	if skills_container:
		for child in skills_container.get_children():
			if child is Panel:
				skill_panels.append(child)
		highlight_skill(0)
	
	# Делаем оружие чуть темнее на старте, чтобы вспышка была видна
	if left_item_panel: left_item_panel.modulate = Color(0.8, 0.8, 0.8, 1)
	if right_item_panel: right_item_panel.modulate = Color(0.8, 0.8, 0.8, 1)
	
	# Проверяем, нашли ли мы часы
	if not celestial_pivot:
		print("Ошибка: Не найден CelestialPivot в сцене HUD!")

func _process(delta):
	# --- ЛОГИКА ВРЕМЕНИ (ДЕМОНСТРАЦИЯ) ---
	# Если у тебя есть Global.time, удали этот блок и вызывай update_clock извне.
	# Здесь 1 игровой час проходит за 1 реальную секунду.
	debug_game_time += delta 
	if debug_game_time >= 24.0:
		debug_game_time = 0.0
	
	update_clock(debug_game_time)

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
