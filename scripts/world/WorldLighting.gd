extends Node2D
class_name WorldLighting

# === СИГНАЛЫ ===
signal torch_properties_changed(energy: float, scale: float)

# === ДЕНЬ/НОЧЬ ===
@export var day_length_seconds: float = 300.0
@export var day_color: Color = Color(0.9, 0.9, 0.9, 1.0)
@export var night_color: Color = Color(0.1, 0.1, 0.2, 1.0)

# === ТИНТЫ ГЛУБИНЫ ЛЕСА ===
@export var depth1_tint: Color = Color(1.05, 1.0, 0.95, 1.0)
@export var depth2_tint: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var depth3_tint: Color = Color(0.6, 0.7, 1.0, 1.0)

@export var transition_seconds: float = 1.0

# === ФАКЕЛ (по глубинам) ===
@export var depth1_torch_energy_scale: float = 0.8
@export var depth2_torch_energy_scale: float = 1.0
@export var depth3_torch_energy_scale: float = 1.3

@export var depth1_torch_scale: float = 0.9
@export var depth2_torch_scale: float = 1.0
@export var depth3_torch_scale: float = 1.15

# === ТУМАН/СВЕТЛЯЧКИ (по глубинам) ===
@export var depth1_fog_density: float = 0.3
@export var depth2_fog_density: float = 0.6
@export var depth3_fog_density: float = 1.0

@export var depth1_motes_amount: float = 0.3
@export var depth2_motes_amount: float = 0.7
@export var depth3_motes_amount: float = 1.0

# === УЗЛЫ СЦЕНЫ ===
@onready var ambient: CanvasModulate = $Ambient
@onready var lights_root: Node2D = $Lights
@onready var player_torch: PointLight2D = get_node_or_null("/root/Main/Node2D/Player/Torch")
@onready var optional_moon: Light2D = $Lights/OptionalMoon if has_node("Lights/OptionalMoon") else null

@onready var fog: GPUParticles2D = $VFX/Fog
@onready var motes: GPUParticles2D = $VFX/Motes

# === СОСТОЯНИЕ ===
var time_of_day: float = 0.0
var _current_depth: int = 1
var _current_depth_tint: Color

var _base_torch_energy: float
var _base_torch_scale: float
var _base_fog_amount: int
var _base_motes_amount: int


func _ready() -> void:
	add_to_group("level_root")

	_current_depth_tint = _get_depth_tint(_current_depth)

	# Запоминаем базовые значения для факела и частиц
	# Since we're using signals now, we'll use default values
	_base_torch_energy = 1.0
	_base_torch_scale = 1.0
	_base_fog_amount = fog.amount
	_base_motes_amount = motes.amount

	_init_fog_material()
	_init_motes_material()

	_update_all_immediate()
	regenerate_visibility_rect()

	# РЕКОМЕНДАЦИИ:
	# - UI и Cursor держи в отдельном CanvasLayer (или SubViewport) вне влияния CanvasModulate.
	# - Для "туманного зрения" ночью можно добавить второй Light2D в режиме MODE_MASK
	#   с item_cull_mask, совпадающим с масками мира (но не UI).


func _process(delta: float) -> void:
	# День/ночь
	if day_length_seconds > 0.0:
		time_of_day = fposmod(time_of_day + delta / day_length_seconds, 1.0)
	_update_all_immediate()


func _update_all_immediate() -> void:
	# Считаем итоговый цвет = день/ночь * тинт глубины
	var base_color := _get_time_of_day_color()
	var tint := _current_depth_tint
	var final_color := Color(
		base_color.r * tint.r,
		base_color.g * tint.g,
		base_color.b * tint.b,
		base_color.a * tint.a
	)
	ambient.color = final_color
	
	# Обновляем параметры факела/частиц от текущей глубины
	_update_depth_dependent_params()



func _update_depth_dependent_params() -> void:
	# Факел
	var torch_scale := _base_torch_scale * _get_depth_torch_scale(_current_depth)
	var torch_energy := _base_torch_energy * _get_depth_torch_energy_scale(_current_depth)
	emit_signal("torch_properties_changed", torch_energy, torch_scale)
	
	# Туман/светлячки — всегда от БАЗЫ, чтобы не было экспоненциального роста
	fog.amount = int(max(1.0, float(_base_fog_amount) * _get_depth_fog_density(_current_depth)))
	motes.amount = int(max(1.0, float(_base_motes_amount) * _get_depth_motes_amount(_current_depth)))

func _get_time_of_day_color() -> Color:
	# Плавный синус день->ночь
	var t: float = clamp(sin(time_of_day * TAU - PI / 2.0) * 0.5 + 0.5, 0.0, 1.0)
	return day_color.lerp(night_color, 1.0 - t)


# === ГЕТТЕРЫ ПО ГЛУБИНЕ ===

func _get_depth_tint(depth: int) -> Color:
	match depth:
		1:
			return depth1_tint
		2:
			return depth2_tint
		3:
			return depth3_tint
		_:
			return Color(1, 1, 1, 1)


func _get_depth_torch_energy_scale(depth: int) -> float:
	match depth:
		1:
			return depth1_torch_energy_scale
		2:
			return depth2_torch_energy_scale
		3:
			return depth3_torch_energy_scale
		_:
			return 1.0


func _get_depth_torch_scale(depth: int) -> float:
	match depth:
		1:
			return depth1_torch_scale
		2:
			return depth2_torch_scale
		3:
			return depth3_torch_scale
		_:
			return 1.0


func _get_depth_fog_density(depth: int) -> float:
	match depth:
		1:
			return depth1_fog_density
		2:
			return depth2_fog_density
		3:
			return depth3_fog_density
		_:
			return 1.0


func _get_depth_motes_amount(depth: int) -> float:
	match depth:
		1:
			return depth1_motes_amount
		2:
			return depth2_motes_amount
		3:
			return depth3_motes_amount
		_:
			return 1.0


# === ПУБЛИЧНЫЙ API ===

func set_depth(depth: int) -> void:
	depth = clamp(depth, 1, 3)
	if depth == _current_depth:
		return

	var from_tint: Color = _current_depth_tint
	var to_tint: Color = _get_depth_tint(depth)

	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Меняем только _current_depth_tint плавно.
	# ambient.color будет обновляться в _process() автоматически каждый кадр.
	tween.tween_method(
		func(value: float) -> void:
			_current_depth_tint = from_tint.lerp(to_tint, value)
			, 0.0, 1.0, transition_seconds
	)

	# Факел
	var to_energy: float = _base_torch_energy * _get_depth_torch_energy_scale(depth)
	var to_scale: float = _base_torch_scale * _get_depth_torch_scale(depth)
	emit_signal("torch_properties_changed", to_energy, to_scale)

	# Туман/светлячки (считаем от базы, чтобы не улетало)
	if fog.process_material is ParticleProcessMaterial:
		var to_fog := int(max(1.0, float(_base_fog_amount) * _get_depth_fog_density(depth)))
		tween.parallel().tween_property(fog, "amount", to_fog, transition_seconds)

	if motes.process_material is ParticleProcessMaterial:
		var to_motes := int(max(1.0, float(_base_motes_amount) * _get_depth_motes_amount(depth)))
		tween.parallel().tween_property(motes, "amount", to_motes, transition_seconds)

	_current_depth = depth


func regenerate_visibility_rect() -> void:
	# Вызывай после изменения масштаба карты/частиц
	# или используй в редакторе: "Particles -> Generate Visibility Rect".
	if is_instance_valid(fog):
		fog.visibility_rect = Rect2(Vector2(-1024, -512), Vector2(2048, 1024))
	if is_instance_valid(motes):
		motes.visibility_rect = Rect2(Vector2(-1024, -512), Vector2(2048, 1024))


func _init_fog_material() -> void:
	if fog.process_material is ParticleProcessMaterial:
		return
	var mat := ParticleProcessMaterial.new()
	mat.gravity = Vector3(0, 0, 0)
	mat.color = Color(0.8, 0.85, 0.9, 0.25)
	fog.process_material = mat


func _init_motes_material() -> void:
	if motes.process_material is ParticleProcessMaterial:
		return
	var mat := ParticleProcessMaterial.new()
	mat.gravity = Vector3(0, 0, 0)
	mat.color = Color(1.0, 0.95, 0.8, 0.8)
	motes.process_material = mat
