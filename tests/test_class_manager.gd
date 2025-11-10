extends "res://addons/gut/test.gd"

var _cm: Node = null
var _config: Node = null
var _skill: Node = null

class DummyPlayer:
	extends Node
	var global_level: int = 1
	var owned_classes: Array = []
	var stats := {}
	signal class_changed(class_id: String)
	func add_class(class_id: String) -> void:
		if class_id in owned_classes:
			return
		owned_classes.append(class_id)
		emit_signal("class_changed", class_id)
	func has_class(class_id: String) -> bool:
		return class_id in owned_classes

func before_each():
	_config = get_node_or_null("/root/Config")
	if _config == null:
		_config = Node.new()
		_config.set_script(load("res://autoload/Config.gd"))
		get_tree().root.add_child(_config)
	# включаем фичу
	_config.CLASS_SYSTEM_ENABLED = true
	# SkillManager (заглушка)
	_skill = get_node_or_null("/root/SkillManager")
	if _skill == null:
		_skill = Node.new()
		_skill.set_script(load("res://autoload/SkillManager.gd"))
		get_tree().root.add_child(_skill)
	# ClassManager
	_cm = Node.new()
	_cm.set_script(load("res://autoload/ClassManager.gd"))
	get_tree().root.add_child(_cm)

func after_each():
	if is_instance_valid(_cm):
		_cm.queue_free()
	if is_instance_valid(_skill):
		_skill.queue_free()

func test_offer_emitted_on_level_10():
	var player := DummyPlayer.new()
	player.global_level = 10
	var offered := false
	_cm.connect("class_offered", func(p, choices):
		offered = true
		assert_true(choices.size() > 0, "Choices should not be empty on level 10")
	)
	_cm.call("check_level_for_class", player)
	assert_true(offered, "class_offered should emit at level 10")

func test_assign_adds_class_and_unlocks_skills():
	var player := DummyPlayer.new()
	var result := _cm.call("assign_class", player, "warrior")
	assert_true(result == true, "assign_class should return true")
	assert_true(player.has_class("warrior"), "Player should own 'warrior'")

func test_mythic_trigger_evaluate():
	var player := DummyPlayer.new()
	player.global_level = 20
	player.stats = {
		"skills_used": 120,
		"completed_quest_ancient_ruins": true
	}
	var mythics: Array = _cm.call("evaluate_hidden_triggers", player)
	assert_true("void_walker" in mythics, "void_walker should be returned for given triggers")
