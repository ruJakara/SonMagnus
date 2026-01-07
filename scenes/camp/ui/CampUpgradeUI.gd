extends Control

@onready var panel: Panel = $Panel
@onready var status_label: Label = $Panel/VBox/StatusLabel
@onready var upgrade_list: VBoxContainer = $Panel/VBox/ScrollContainer/UpgradeList
@onready var close_button: Button = $Panel/VBox/TitleBar/CloseButton
@onready var refresh_button: Button = $Panel/VBox/RefreshButton

var _manager: Node = null

func _ready():
	hide()
	_manager = get_node_or_null("/root/CampUpgradeManager")
	if close_button:
		close_button.pressed.connect(close_ui)
	if refresh_button:
		refresh_button.pressed.connect(refresh)
	if _manager:
		var callable := Callable(self, "_on_upgrades_changed")
		if not _manager.upgrades_changed.is_connected(callable):
			_manager.upgrades_changed.connect(callable)
	refresh()

func open_ui() -> void:
	refresh()
	visible = true
	if panel:
		panel.grab_focus()

func close_ui() -> void:
	visible = false

func toggle_ui() -> void:
	if visible:
		close_ui()
	else:
		open_ui()

func refresh() -> void:
	if not upgrade_list:
		return
	for child in upgrade_list.get_children():
		child.queue_free()
	var definitions := {}
	if _manager:
		definitions = _manager.get_upgrade_definitions()
	var upgrade_ids := definitions.keys()
	upgrade_ids.sort()
	for upgrade_id in upgrade_ids:
		var row := _build_row(upgrade_id, definitions[upgrade_id])
		upgrade_list.add_child(row)

func _build_row(upgrade_id: String, definition: Dictionary) -> Control:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 4)
	container.add_theme_constant_override("margin_left", 6)
	container.add_theme_constant_override("margin_right", 6)
	var header := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = "%s (%s)" % [definition.get("name_key", upgrade_id), definition.get("category", "other")]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var level_label := Label.new()
	var status := _manager != null ? _manager.get_upgrade_status(upgrade_id) : {}
	var current_level := int(status.get("current_level", 0))
	var max_level := int(status.get("max_level", 0))
	level_label.text = "Уровень %d / %d" % [current_level, max_level]
	header.add_child(name_label)
	header.add_child(level_label)
	container.add_child(header)

	var desc_label := Label.new()
	desc_label.text = str(definition.get("description_key", ""))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	container.add_child(desc_label)

	var next_level: Dictionary = status.get("next_level_data", {})
	if next_level.is_empty():
		var max_label := Label.new()
		max_label.text = "Максимальный уровень достигнут"
		container.add_child(max_label)
	else:
		var effect_label := Label.new()
		effect_label.text = "Следующий уровень:\n%s" % _describe_effects(next_level.get("effects", {}))
		effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		container.add_child(effect_label)

		var cost_label := Label.new()
		cost_label.text = "Стоимость: %s" % _format_cost(next_level.get("cost", {}))
		container.add_child(cost_label)

		var requirements_label := Label.new()
		var can_result := _manager != null ? _manager.can_upgrade(upgrade_id) : {"success": false, "reason": "Менеджер недоступен"}
		var upgrade_button := Button.new()
		upgrade_button.text = "Upgrade"
		upgrade_button.disabled = not can_result["success"]
		upgrade_button.pressed.connect(func():
			_on_upgrade_pressed(upgrade_id)
		)
		container.add_child(upgrade_button)
		if not can_result["success"]:
			requirements_label.text = can_result.get("reason", "")
			requirements_label.modulate = Color(1, 0.6, 0.6, 1)
			container.add_child(requirements_label)

	var separator := HSeparator.new()
	container.add_child(separator)
	return container

func _format_cost(cost: Dictionary) -> String:
	if cost.is_empty():
		return "Бесплатно"
	var parts: Array[String] = []
	for item_id in cost.keys():
		parts.append("%s x%d" % [item_id, int(cost[item_id])])
	return ", ".join(parts)

func _describe_effects(effects: Dictionary) -> String:
	if effects.is_empty():
		return "Нет новых эффектов"
	var lines: Array[String] = []
	for key in effects.keys():
		var value = effects[key]
		match key:
			"storage_capacity_bonus":
				lines.append("+%d к вместимости склада" % int(value))
			"storage_max_stacks_bonus":
				lines.append("+%d к лимиту стаков" % int(value))
			"autocraft_speed_multiplier":
				lines.append("Скорость автокрафта x%.2f" % float(value))
			"autocraft_queue_slots_bonus":
				lines.append("+%d слотов очереди автокрафта" % int(value))
			"unlock_station_type":
				lines.append("Разблокирован станок: %s" % str(value))
			"station_level_bonus":
				lines.append("+%s к уровню станков" % str(value))
			"camp_defense_level_bonus":
				lines.append("+%d к защите лагеря" % int(value))
			"unlock_fence_visual":
				if bool(value):
					lines.append("Периметр визуально укрепляется")
			_:
				lines.append("%s: %s" % [key, str(value)])
	return "\n".join(lines)

func _on_upgrade_pressed(upgrade_id: String) -> void:
	if not _manager:
		status_label.text = "Менеджер улучшений недоступен"
		return
	var result := _manager.apply_upgrade(upgrade_id)
	status_label.text = result.get("message", result.get("reason", ""))
	refresh()

func _on_upgrades_changed(_mods: Dictionary) -> void:
	refresh()

