extends CanvasLayer

@onready var storage_label: Label = $Panel/VBox/StorageLabel
@onready var message_label: Label = $Panel/VBox/MessageLabel
@onready var recipe_input: LineEdit = $Panel/VBox/QueueControls/RecipeId
@onready var count_input: SpinBox = $Panel/VBox/QueueControls/CountSpin
@onready var queue_container: VBoxContainer = $Panel/VBox/QueueList

func _ready():
	hide()
	var storage_callable := Callable(self, "_on_storage_changed")
	if not CampStorageManager.storage_changed.is_connected(storage_callable):
		CampStorageManager.storage_changed.connect(storage_callable)
	var queue_callable := Callable(self, "_on_queue_updated")
	if not AutoCrafterManager.queue_updated.is_connected(queue_callable):
		AutoCrafterManager.queue_updated.connect(queue_callable)
	_on_storage_changed(CampStorageManager.get_snapshot())
	_on_queue_updated(AutoCrafterManager.get_orders())

func _on_storage_changed(snapshot: Dictionary) -> void:
	if not storage_label:
		return
	var text := ""
	var capacity := snapshot.get("capacity", {})
	if capacity is Dictionary and not capacity.is_empty():
		text += "Capacity: %d / %d\n" % [
			capacity.get("used", 0),
			capacity.get("limit", 0)
		]
	for item_id in snapshot.get("total", {}).keys():
		var total := snapshot["total"][item_id]
		var reserved := snapshot.get("reserved", {}).get(item_id, 0)
		var free := snapshot.get("free", {}).get(item_id, 0)
		text += "%s: total %d | reserved %d | free %d\n" % [item_id, total, reserved, free]
	if text == "":
		text = "Склад пуст"
	storage_label.text = text

func _on_queue_updated(queue: Array) -> void:
	for child in queue_container.get_children():
		child.queue_free()
	for order in queue:
		var label := Label.new()
		label.text = "%s - %s (%s)" % [order["id"], order["recipe_id"], order["status"]]
		queue_container.add_child(label)

func _on_AddStarter_pressed() -> void:
	CampStorageManager.add({"wood": 5, "stone": 5})
	message_label.text = "Добавлены базовые ресурсы"

func _on_QueueButton_pressed() -> void:
	var recipe_id := recipe_input.text.strip_edges()
	var count := int(count_input.value)
	if recipe_id == "":
		message_label.text = "Укажите рецепт"
		return
	var result := AutoCrafterManager.enqueue(recipe_id, count)
	message_label.text = result.get("message", "")

func _on_ClearQueue_pressed() -> void:
	for order in AutoCrafterManager.get_orders():
		if order["status"] == "in_progress":
			continue
		AutoCrafterManager.cancel_order(order["id"])
	message_label.text = "Очередь очищена"

