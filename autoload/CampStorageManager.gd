# autoload/CampStorageManager.gd
extends Node

signal storage_changed(snapshot: Dictionary)
signal reservation_changed(reservation_id: String, data: Dictionary)
signal reservation_warning(message: String, data: Dictionary)

const BASE_CAPACITY := 200

var _total: Dictionary = {}
var _reserved: Dictionary = {}
var _reservations: Dictionary = {}
var _reservation_sequence: int = 1
var _capacity_bonus: int = 0
var _max_capacity: int = BASE_CAPACITY
var _max_stack_bonus: int = 0

func _ready() -> void:
	var upgrade_manager: Node = get_node_or_null("/root/CampUpgradeManager")
	if upgrade_manager:
		upgrade_manager.upgrades_changed.connect(_on_upgrade_modifiers_changed)
		_on_upgrade_modifiers_changed(upgrade_manager.get_effective_modifiers())

func add(items: Dictionary) -> bool:
	var required_capacity := _calculate_amount(items)
	if required_capacity == 0:
		return true
	if not _has_capacity_for(required_capacity):
		emit_signal("reservation_warning", "Недостаточно места на складе", {
			"required": required_capacity,
			"free_capacity": get_free_capacity()
		})
		return false
	for item_id in items.keys():
		var amount := int(items[item_id])
		if amount == 0:
			continue
		_total[item_id] = get_total(item_id) + amount
	_emit_storage_changed()
	return true

func has_free(items: Dictionary) -> bool:
	for item_id in items.keys():
		if get_free(item_id) < int(items[item_id]):
			return false
	return true

func consume_free(items: Dictionary) -> bool:
	if not has_free(items):
		return false
	for item_id in items.keys():
		var amount := int(items[item_id])
		if amount == 0:
			continue
		_total[item_id] = get_total(item_id) - amount
	_emit_storage_changed()
	return true

func reserve(items: Dictionary, reservation_id := "") -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"reservation_id": "",
		"reserved_items": {},
		"missing_items": {},
		"message": ""
	}
	if not has_free(items):
		for item_id in items.keys():
			var needed := int(items[item_id])
			var available := get_free(item_id)
			if available < needed:
				result["missing_items"][item_id] = needed - available
		result["message"] = "Недостаточно свободных ресурсов"
		return result
	if reservation_id != "" and _reservations.has(reservation_id):
		unreserve(reservation_id)
	var rid := reservation_id if reservation_id != "" else _generate_reservation_id()
	var snapshot: Dictionary = {}
	for item_id in items.keys():
		var amount := int(items[item_id])
		if amount <= 0:
			continue
		snapshot[item_id] = amount
		_reserved[item_id] = get_reserved(item_id) + amount
	_reservations[rid] = snapshot
	result["success"] = true
	result["reservation_id"] = rid
	result["reserved_items"] = snapshot.duplicate(true)
	result["message"] = "Ресурсы зарезервированы"
	_emit_storage_changed()
	emit_signal("reservation_changed", rid, snapshot)
	return result

func unreserve(reservation_id: String, items: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"released_items": {},
		"message": ""
	}
	if not _reservations.has(reservation_id):
		result["message"] = "Резерв не найден"
		return result
	var stored_variant: Variant = _reservations.get(reservation_id, null)
	if not stored_variant is Dictionary:
		result["message"] = "Резерв повреждён"
		return result
	var stored: Dictionary = stored_variant
	var released: Dictionary = {}
	if items.is_empty():
		released = stored.duplicate(true)
		_reservations.erase(reservation_id)
	else:
		for item_id in items.keys():
			var amount: int = clamp(int(items[item_id]), 0, stored.get(item_id, 0))
			if amount == 0:
				continue
			stored[item_id] -= amount
			released[item_id] = released.get(item_id, 0) + amount
		for key in stored.keys():
			if stored[key] <= 0:
				stored.erase(key)
		if stored.is_empty():
			_reservations.erase(reservation_id)
		else:
			_reservations[reservation_id] = stored
	if released.is_empty():
		result["message"] = "Нечего снимать с резерва"
		return result
	for item_id in released.keys():
		var amount: int = int(released[item_id])
		_reserved[item_id] = max(get_reserved(item_id) - amount, 0)
	result["success"] = true
	result["released_items"] = released
	result["message"] = "Резерв скорректирован"
	_emit_storage_changed()
	emit_signal("reservation_changed", reservation_id, _reservations.get(reservation_id, {}))
	return result

func consume_reserved(reservation_id: String, items: Dictionary = {}) -> bool:
	if not _reservations.has(reservation_id):
		return false
	var stored_variant: Variant = _reservations.get(reservation_id, null)
	if not stored_variant is Dictionary:
		return false
	var stored: Dictionary = stored_variant
	var payload: Dictionary = stored if items.is_empty() else items
	for item_id in payload.keys():
		var amount: int = int(payload[item_id])
		if stored.get(item_id, 0) < amount:
			return false
	for item_id in payload.keys():
		var amount: int = int(payload[item_id])
		stored[item_id] -= amount
		if stored[item_id] <= 0:
			stored.erase(item_id)
		_reserved[item_id] = max(get_reserved(item_id) - amount, 0)
		_total[item_id] = get_total(item_id) - amount
	if stored.is_empty():
		_reservations.erase(reservation_id)
	else:
		_reservations[reservation_id] = stored
	_emit_storage_changed()
	emit_signal("reservation_changed", reservation_id, _reservations.get(reservation_id, {}))
	return true

func get_total(item_id: String) -> int:
	return _total.get(item_id, 0)

func get_reserved(item_id: String) -> int:
	return _reserved.get(item_id, 0)

func get_free(item_id: String) -> int:
	return get_total(item_id) - get_reserved(item_id)

func get_snapshot() -> Dictionary:
	return {
		"total": _total.duplicate(true),
		"reserved": _reserved.duplicate(true),
		"free": _get_free_snapshot(),
		"capacity": {
			"used": get_used_capacity(),
			"limit": get_capacity_limit()
		}
	}

func _get_free_snapshot() -> Dictionary:
	var free: Dictionary = {}
	for item_id in _total.keys():
		free[item_id] = get_free(item_id)
	return free

func _emit_storage_changed() -> void:
	emit_signal("storage_changed", get_snapshot())

func _generate_reservation_id() -> String:
	var rid := "camp_order_%s" % _reservation_sequence
	_reservation_sequence += 1
	return rid

func get_capacity_limit() -> int:
	return _max_capacity

func get_used_capacity() -> int:
	var total_used := 0
	for amount in _total.values():
		total_used += int(amount)
	return total_used

func get_free_capacity() -> int:
	return max(get_capacity_limit() - get_used_capacity(), 0)

func _calculate_amount(items: Dictionary) -> int:
	var sum := 0
	for value in items.values():
		sum += int(value)
	return sum

func _has_capacity_for(amount: int) -> bool:
	return get_free_capacity() >= amount

func _on_upgrade_modifiers_changed(modifiers: Dictionary) -> void:
	_capacity_bonus = int(modifiers.get("storage_capacity_bonus", 0))
	_max_capacity = BASE_CAPACITY + _capacity_bonus
	_max_stack_bonus = int(modifiers.get("storage_max_stacks_bonus", 0))
	_emit_storage_changed()

