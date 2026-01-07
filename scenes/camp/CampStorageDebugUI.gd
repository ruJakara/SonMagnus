extends CanvasLayer

@onready var storage_label: Label = $Panel/VBox/StorageLabel
@onready var message_label: Label = $Panel/VBox/MessageLabel
@onready var recipe_input: LineEdit = $Panel/VBox/QueueControls/RecipeId
@onready var count_input: SpinBox = $Panel/VBox/QueueControls/CountSpin
@onready var queue_container: VBoxContainer = $Panel/VBox/QueueList

func _ready() -> void:
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
	var text: String = ""
	var capacity_variant: Variant = snapshot.get("capacity", {})
	if capacity_variant is Dictionary:
		var capacity: Dictionary = capacity_variant
		text += "Capacity: %d / %d\n" % [
			capacity.get("used", 0),
			capacity.get("limit", 0)
		]
	var total_variant: Variant = snapshot.get("total", {})
	var reserved_variant: Variant = snapshot.get("reserved", {})
	var free_variant: Variant = snapshot.get("free", {})
	var total_map: Dictionary = total_variant if total_variant is Dictionary else {}
	var reserved_map: Dictionary = reserved_variant if reserved_variant is Dictionary else {}
	var free_map: Dictionary = free_variant if free_variant is Dictionary else {}
	for item_id in total_map.keys():
		var total: int = total_map.get(item_id, 0)
		var reserved: int = reserved_map.get(item_id, 0)
		var free: int = free_map.get(item_id, 0)
		text += "%s: total %d | reserved %d | free %d\n" % [item_id, total, reserved, free]
	if text == "":
		text = "Склад пуст"
	storage_label.text = text

func _on_queue_updated(queue: Array) -> void:
	for child in queue_container.get_children():
		child.queue_free()
	for order_variant in queue:
		if not order_variant is Dictionary:
			continue
		var order: Dictionary = order_variant
		var label := Label.new()
		label.text = "%s - %s (%s)" % [order["id"], order["recipe_id"], order["status"]]
		queue_container.add_child(label)

func _on_AddStarter_pressed() -> void:
	CampStorageManager.add({"wood": 5, "stone": 5})
	message_label.text = "Добавлены базовые ресурсы"

func _on_QueueButton_pressed() -> void:
	var recipe_id: String = recipe_input.text.strip_edges()
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

