# scripts/player/components/player_slide_controller.gd
# Управляет подкатом/скольжением игрока

class_name PlayerSlideController
extends Node

# ===== Настройки подката =====
@export var slide_stamina_cost: float = 15.0
@export var slide_speed: float = 300.0
@export var slide_duration: float = 0.4

# ===== Ссылки =====
var _player: Node = null
var _state: PlayerCombatState = null
var _animation_player: AnimationPlayer = null


func _ready() -> void:
	var combat = get_parent()
	_player = combat.get_parent()
	_state = combat.get_node("State")
	_animation_player = _player.get_node_or_null("AnimationPlayer")
	
	if _animation_player:
		_animation_player.animation_finished.connect(_on_animation_finished)


func _process(delta: float) -> void:
	# Обработка подката по таймеру (если анимации нет)
	if _state._is_sliding and _state._slide_timer > 0.0:
		_state._slide_timer -= delta
		if _state._slide_timer <= 0.0:
			end_slide()


func request_slide() -> void:
	"""Shift: Подкат/скольжение."""
	if not _state.can_slide():
		if Config.DEBUG_LOGS:
			print("[SlideController] Подкат заблокирован")
		return
	
	# Проверяем стамину
	if not _player.consume_stamina(slide_stamina_cost):
		if Config.DEBUG_LOGS:
			print("[SlideController] Недостаточно стамины для подката")
		return
	
	_start_slide()


func _start_slide() -> void:
	"""Начинает подкат с неуязвимостью."""
	_state._is_sliding = true
	_state._slide_timer = slide_duration
	_player.invulnerable = true
	
	# Блокируем другие действия
	_player.lock_attack = true
	_player.lock_block = true
	_player.lock_stance_toggle = true
	
	# Применяем импульс в направлении взгляда
	var direction: int = _player.get_facing_direction()
	_player.velocity = Vector2(float(direction) * slide_speed, 0.0)
	
	if Config.DEBUG_LOGS:
		print("[SlideController] Подкат начат (dir: %d)" % direction)
	
	# Проигрываем анимацию если есть
	if _animation_player and _animation_player.has_animation("slide"):
		_animation_player.play("slide")
	else:
		# Если анимации нет - завершаем по таймеру
		pass


func _on_animation_finished(anim_name: StringName) -> void:
	"""Обрабатываем завершение анимации подката."""
	if anim_name == "slide":
		end_slide()


func end_slide() -> void:
	"""Завершает подкат."""
	if not _state._is_sliding:
		return
	
	_state._is_sliding = false
	_state._slide_timer = 0.0
	_player.invulnerable = false
	
	# Снимаем блокировки
	_player.lock_attack = false
	_player.lock_block = false
	_player.lock_stance_toggle = false
	
	if Config.DEBUG_LOGS:
		print("[SlideController] Подкат завершён")
