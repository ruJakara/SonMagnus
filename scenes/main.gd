extends Node

@onready var player_root := $Player
@onready var player := $Player/Player
@onready var hud := $Player/HUD
@onready var location_root := $LocationRoot
@onready var forest_scene := $LocationRoot/Forest
@onready var camp_scene := $LocationRoot/Camp
@onready var crafting_ui := $CraftingUI

var current_location := ""
var _forest_lighting: Node = null

func _ready():
	await get_tree().process_frame
	_bind_player_to_hud()
	_seed_storage_for_mvp()
	if crafting_ui:
		crafting_ui.set_camp_mode(false)
	switch_to_forest()

func _bind_player_to_hud() -> void:
	if not (player and hud):
		push_warning("Player или HUD не найдены")
		return
	player.health_changed.connect(hud.update_health)
	player.mana_changed.connect(hud.update_mana)
	player.stamina_changed.connect(hud.update_stamina)
	player.hunger_changed.connect(hud.update_hunger)
	hud.update_health(player.health, player.max_health)
	hud.update_mana(player.mana, player.max_mana)
	hud.update_stamina(player.stamina, player.max_stamina)
	hud.update_hunger(player.hunger, player.max_hunger)

func _seed_storage_for_mvp() -> void:
	if CampStorageManager.get_total("wood") == 0 and CampStorageManager.get_total("stone") == 0:
		CampStorageManager.add({"wood": 4, "stone": 4})

func switch_to_camp() -> void:
	if current_location == "camp":
		return
	_disconnect_forest_lighting()
	if forest_scene:
		forest_scene.deactivate()
	if camp_scene:
		camp_scene.activate()
		_move_player_to(camp_scene.get_spawn_position())
	current_location = "camp"
	if crafting_ui:
		crafting_ui.set_camp_mode(true)

func switch_to_forest() -> void:
	if current_location == "forest":
		return
	if camp_scene:
		camp_scene.deactivate()
	if forest_scene:
		forest_scene.activate()
		_connect_forest_lighting()
		_move_player_to(forest_scene.get_spawn_position())
	current_location = "forest"
	if crafting_ui:
		crafting_ui.set_camp_mode(false)

func _move_player_to(position: Vector2) -> void:
	if player_root:
		player_root.global_position = position

func _connect_forest_lighting() -> void:
	if not forest_scene:
		return
	var level_root = forest_scene.get_level_root()
	if not level_root:
		return
	_forest_lighting = level_root
	var callable := Callable(self, "_on_torch_properties_changed")
	if not level_root.torch_properties_changed.is_connected(callable):
		level_root.torch_properties_changed.connect(callable)

func _disconnect_forest_lighting() -> void:
	if _forest_lighting:
		var callable := Callable(self, "_on_torch_properties_changed")
		if _forest_lighting.torch_properties_changed.is_connected(callable):
			_forest_lighting.torch_properties_changed.disconnect(callable)
	_forest_lighting = null

func _on_torch_properties_changed(energy: float, scale: float) -> void:
	if player and player.has_node("Torch"):
		var torch = player.get_node("Torch")
		torch.energy = energy
		torch.texture_scale = scale

func _unhandled_input(event):
	if event.is_action_pressed("go_camp"):
		switch_to_camp()
	elif event.is_action_pressed("go_forest"):
		switch_to_forest()
	elif event.is_action_pressed("campupgrade") and current_location == "camp":
		if camp_scene and camp_scene.has_method("toggle_upgrade_ui"):
			camp_scene.toggle_upgrade_ui()
