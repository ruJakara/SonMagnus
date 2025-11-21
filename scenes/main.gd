extends Node

@onready var player = $Player
@onready var hud = $HUD

func _ready():
	await get_tree().process_frame
	
	if player and hud:
		# Подключаем основные статы
		player.health_changed.connect(hud.update_health)
		player.mana_changed.connect(hud.update_mana)
		player.stamina_changed.connect(hud.update_stamina)
		
		# Подключаем ГОЛОД (теперь должно работать!)
		player.hunger_changed.connect(hud.update_hunger)
		
		# Подключаем АНИМАЦИЮ ПРЕДМЕТОВ (Q/E)
		#player.item_used.connect(hud.animate_item_usage)
		
		# Подключаем смену навыка
		#player.skill_changed.connect(hud.highlight_skill)
		
		# Обновляем всё при старте
		hud.update_health(player.health, player.max_health)
		hud.update_mana(player.mana, player.max_mana)
		hud.update_stamina(player.stamina, player.max_stamina)
		hud.update_hunger(player.hunger, player.max_hunger)
		#hud.highlight_skill(player._current_skill_index)
	else:
		print("Ошибка: Player или HUD не найдены!")
