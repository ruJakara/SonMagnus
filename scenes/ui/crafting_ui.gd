extends CanvasLayer

@onready var panel: Panel = $Panel
@onready var slot1_input: LineEdit = $Panel/VBox/Slots/Slot1/Input
@onready var slot2_input: LineEdit = $Panel/VBox/Slots/Slot2/Input
@onready var slot3_input: LineEdit = $Panel/VBox/Slots/Slot3/Input
@onready var result_label: Label = $Panel/VBox/ResultLabel
@onready var storage_label: Label = $Panel/VBox/StorageLabel
@onready var forge_animation: AnimationPlayer = $ForgeAnimation

var camp_mode_enabled := false
var pending_result: Dictionary = {}

func _ready():
	hide()
	slot1_input.text = "wood"
	slot2_input.text = "stone"
	var storage_callable := Callable(self, "_on_storage_changed")
	if not CampStorageManager.storage_changed.is_connected(storage_callable):
		CampStorageManager.storage_changed.connect(storage_callable)
	_on_storage_changed(CampStorageManager.get_snapshot())

func set_camp_mode(active: bool) -> void:
	camp_mode_enabled = active
	if not active:
		hide()
		_set_result("Крафт доступен только в лагере")

func _input(event):
	if event.is_action_pressed("craftmenu"):
		if not camp_mode_enabled:
			_set_result("Нужен лагерь, чтобы открыть кузницу")
			return
		visible = not visible
		if visible:
			slot1_input.grab_focus()
		else:
			pending_result.clear()

func _on_CraftButton_pressed() -> void:
	if not camp_mode_enabled:
		_set_result("Вы не в лагере")
		return
	var slot1 := slot1_input.text.strip_edges()
	var slot2 := slot2_input.text.strip_edges()
	var slot3 := slot3_input.text.strip_edges()
	if slot1 == "" or slot2 == "":
		_set_result("Нужно задать Slot1 и Slot2")
		return
	var craft_result := CraftManager.try_manual(slot1, slot2, slot3)
	if not craft_result["success"]:
		_set_result(craft_result.get("message", "Крафт не удался"))
		return
	pending_result = craft_result
	_set_result("Станок занят...")
	if forge_animation.has_animation("craft"):
		forge_animation.play("craft")
	else:
		on_craft_phase_complete()

func on_craft_phase_complete() -> void:
	if pending_result.is_empty():
		return
	var produced: Dictionary = pending_result.get("produced_items", {})
	if not produced.is_empty():
		CampStorageManager.add(produced)
	var message := pending_result.get("message", "Крафт завершён")
	message += " => %s" % _format_items(produced)
	if pending_result.get("used_fallback_ether", false):
		message += " (fallback ether)"
	_set_result(message)
	pending_result.clear()
	_on_storage_changed(CampStorageManager.get_snapshot())

func _on_storage_changed(snapshot: Dictionary) -> void:
	var text := ""
	for item_id in snapshot.get("free", {}).keys():
		text += "%s: %d free\n" % [item_id, snapshot["free"][item_id]]
	if text == "":
		text = "В лагере нет ресурсов"
	storage_label.text = text

func _set_result(text: String) -> void:
	result_label.text = text

func _format_items(items: Dictionary) -> String:
	if items.is_empty():
		return "пусто"
	var parts: Array[String] = []
	for item_id in items.keys():
		parts.append("%s x%d" % [item_id, items[item_id]])
	return ", ".join(parts)

func _on_ForgeAnimation_animation_finished(anim_name: String) -> void:
	if anim_name == "craft":
		on_craft_phase_complete()

func _on_ClearButton_pressed() -> void:
	slot1_input.clear()
	slot2_input.clear()
	slot3_input.clear()

