# autoload/AutoCrafterManager.gd
extends Node

signal queue_updated(queue: Array)
signal station_busy_changed(is_busy: bool)

const BASE_QUEUE_SLOTS := 2

var queue: Array[Dictionary] = []
var _current_order_id: String = ""
var _station_busy := false
var _upgrade_manager: Node = null

func _ready() -> void:
	set_process(true)
	_upgrade_manager = get_node_or_null("/root/CampUpgradeManager")
	var storage_callable := Callable(self, "_on_storage_changed")
	if not CampStorageManager.storage_changed.is_connected(storage_callable):
		CampStorageManager.storage_changed.connect(storage_callable)

func enqueue(recipe_id: String, count: int = 1) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"reserved_items": {},
		"message": ""
	}
	if count <= 0:
		result["message"] = "Количество должно быть положительным"
		return result
	if queue.size() >= _get_queue_limit():
		result["message"] = "Очередь автокрафта заполнена"
		return result
	var recipe := CraftManager.get_recipe(recipe_id)
	if recipe.is_empty():
		result["message"] = "Рецепт не найден"
		return result
	var required := CraftManager.get_recipe_ingredients(recipe, count)
	var reservation_id := "autocraft_%s" % Time.get_ticks_msec()
	var reserve_result := CampStorageManager.reserve(required, reservation_id)
	if not reserve_result["success"]:
		return reserve_result
	var order_id := reserve_result.get("reservation_id", reservation_id)
	var base_time := float(recipe.get("craft_time_sec", 1.0)) * count
	var final_time := base_time * _get_speed_multiplier()
	var order: Dictionary = {
		"id": order_id,
		"recipe_id": recipe_id,
		"count": count,
		"status": "reserved",
		"required_items": required,
		"reserved_items": reserve_result["reserved_items"],
		"craft_time_sec": final_time,
		"time_left": final_time,
		"base_time_sec": base_time,
		"result_items": CraftManager.get_recipe_output(recipe, count),
		"workshop_type": recipe.get("workshop_type", "forge")
	}
	queue.append(order)
	result["success"] = true
	result["reserved_items"] = reserve_result["reserved_items"]
	result["message"] = "Заказ добавлен в очередь"
	emit_signal("queue_updated", queue)
	_try_start_next()
	return result

func cancel_order(order_id: String) -> bool:
	for i in range(queue.size()):
		var order: Dictionary = queue[i]
		if order["id"] != order_id:
			continue
		if order["status"] == "in_progress":
			return false
		CampStorageManager.unreserve(order_id)
		queue.remove_at(i)
		emit_signal("queue_updated", queue)
		return true
	return false

func _process(delta: float) -> void:
	if not _station_busy:
		_try_start_next()
		return
	var order := _get_current_order()
	if order.is_empty():
		_station_busy = false
		emit_signal("station_busy_changed", _station_busy)
		return
	order["time_left"] -= delta
	if order["time_left"] <= 0.0:
		_complete_order(order)

func _try_start_next() -> void:
	if _station_busy:
		return
	for order in queue:
		if order["status"] != "reserved":
			continue
		var consumed := CampStorageManager.consume_reserved(order["id"], order["required_items"])
		if not consumed:
			order["status"] = "paused_no_resources"
			continue
		order["status"] = "in_progress"
		var base_time := order.get("base_time_sec", order["craft_time_sec"])
		order["craft_time_sec"] = base_time * _get_speed_multiplier()
		order["time_left"] = order["craft_time_sec"]
		_current_order_id = order["id"]
		_station_busy = true
		emit_signal("station_busy_changed", _station_busy)
		emit_signal("queue_updated", queue)
		return

func _complete_order(order: Dictionary) -> void:
	var added := CampStorageManager.add(order["result_items"])
	if not added:
		order["status"] = "waiting_storage"
		order["time_left"] = 0.0
		order["pending_output"] = order["result_items"]
		_current_order_id = ""
		_station_busy = false
		emit_signal("station_busy_changed", _station_busy)
		emit_signal("queue_updated", queue)
		return
	order["status"] = "completed"
	order["time_left"] = 0.0
	_current_order_id = ""
	_station_busy = false
	emit_signal("station_busy_changed", _station_busy)
	emit_signal("queue_updated", queue)
	_try_start_next()

func _get_current_order() -> Dictionary:
	if _current_order_id == "":
		return {}
	for order in queue:
		if order["id"] == _current_order_id:
			return order
	return {}

func get_orders() -> Array[Dictionary]:
	return queue.duplicate(true)

func _on_storage_changed(_snapshot: Dictionary) -> void:
	var updated := false
	for order in queue:
		match order.get("status", ""):
			"paused_no_resources":
				var reserve_again := CampStorageManager.reserve(order["required_items"], order["id"])
				if reserve_again["success"]:
					order["status"] = "reserved"
					order["reserved_items"] = reserve_again["reserved_items"]
					updated = true
			"waiting_storage":
				var payload := order.get("pending_output", order.get("result_items", {}))
				if CampStorageManager.add(payload):
					order["status"] = "completed"
					order.erase("pending_output")
					updated = true
			_:
				continue
	if updated:
		emit_signal("queue_updated", queue)
	_try_start_next()

func _get_speed_multiplier() -> float:
	if _upgrade_manager and _upgrade_manager.has_method("get_modifier"):
		return float(_upgrade_manager.call("get_modifier", "autocraft_speed_multiplier", 1.0))
	return 1.0

func _get_queue_limit() -> int:
	var bonus := 0
	if _upgrade_manager and _upgrade_manager.has_method("get_modifier"):
		bonus = int(_upgrade_manager.call("get_modifier", "autocraft_queue_slots_bonus", 0))
	return BASE_QUEUE_SLOTS + bonus

