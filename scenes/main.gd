extends Node

@onready var player = $Player/Player
@onready var hud = $Node2D/HUD
@onready var forest = $Forest
@onready var enemy = $mobs/GoblinScout

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
	
	# Подключаем освещение
	if forest and forest.has_method("get_node_or_null"):
		var world_lighting = forest.get_node_or_null("LevelRoot")
		if world_lighting:
			world_lighting.torch_properties_changed.connect(_on_torch_properties_changed)

func _on_torch_properties_changed(energy: float, scale: float) -> void:
	if player and player.has_node("Torch"):
		var torch = player.get_node("Torch")
		torch.energy = energy
		torch.texture_scale = scale
