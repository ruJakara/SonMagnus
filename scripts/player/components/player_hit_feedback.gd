# scripts/player/components/player_hit_feedback.gd
# Компонент для визуального фидбека при получении урона
# Использует: Tween для блинка, shader для эффектов, hitstop для динамики

class_name PlayerHitFeedback
extends Node

# ===== Настройки =====
@export var blink_duration: float = 0.15
@export var blink_count: int = 2
@export var hitstop_duration: float = 0.05
@export var knockback_strength: float = 150.0

# ===== Ссылки =====
var _player: CharacterBody2D = null
var _sprite: AnimatedSprite2D = null
var _animation_player: AnimationPlayer = null

# ===== Состояние =====
var _is_hit_stunned: bool = false


func _ready() -> void:
	_player = get_parent().get_parent() if get_parent().get_parent() is CharacterBody2D else null
	if not _player:
		push_error("[HitFeedback] Не могу найти игрока!")
		return
	
	_sprite = _player.get_node_or_null("AnimatedSprite2D")
	_animation_player = _player.get_node_or_null("AnimationPlayer")


func play_hit_effect(attacker: Node = null) -> void:
	"""Проигрывает эффект получения урона"""
	if not _sprite:
		return
	
	# Hitstop (freeze frame)
	_apply_hitstop()
	
	# Блинк эффект
	_play_blink()
	
	# Knockback
	if attacker:
		_apply_knockback(attacker)
	
	# Hurt анимация (если есть)
	_try_play_hurt_animation()


func _apply_hitstop() -> void:
	"""Останавливает время на короткий миг для ощущения удара"""
	if _is_hit_stunned:
		return
	
	_is_hit_stunned = true
	
	# Замедляем время (Godot 4.5 способ)
	Engine.time_scale = 0.0
	
	# Восстанавливаем через таймер
	await get_tree().create_timer(hitstop_duration, true, false, true).timeout
	
	Engine.time_scale = 1.0
	_is_hit_stunned = false


func _play_blink() -> void:
	"""Блинк эффект через мерцание альфа-канала"""
	if not _sprite:
		return
	
	# Отменяем предыдущие твины
	var tw = _sprite.get_tree()
	if tw:
		tw.call_deferred("create_tween").kill()
	
	var tween = create_tween()
	tween.set_loops(blink_count)
	
	# Альтернативный подход: красный оверлей вместо альфы
	tween.tween_property(_sprite, "modulate", Color(1.5, 0.5, 0.5, 1.0), blink_duration / 2.0)
	tween.tween_property(_sprite, "modulate", Color.WHITE, blink_duration / 2.0)
	
	# После завершения гарантируем белый цвет
	tween.finished.connect(func(): _sprite.modulate = Color.WHITE)


func _apply_knockback(attacker: Node) -> void:
	"""Применяет легкий отброс от атакующего"""
	if not _player or not attacker:
		return
	
	var knockback_dir = (_player.global_position - attacker.global_position).normalized()
	
	# Применяем импульс
	_player.velocity = knockback_dir * knockback_strength


func _try_play_hurt_animation() -> void:
	"""Пытается проиграть hurt анимацию если она есть"""
	if not _animation_player:
		return
	
	# Проверяем наличие hurt анимации
	if _animation_player.has_animation("hurt"):
		_animation_player.play("hurt")
	elif _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation("hurt"):
		_sprite.play("hurt")


# ===== Публичное API =====

func is_stunned() -> bool:
	"""Находится ли в состоянии hitstop"""
	return _is_hit_stunned

