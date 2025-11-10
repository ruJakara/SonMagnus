extends Control

@onready var _title := $Panel/VBox/Title
@onready var _list := $Panel/VBox/Choices
@onready var _btn_defer := $Panel/VBox/Buttons/Defer

var _player: Node = null
var _choices: Array = []

func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	_btn_defer.pressed.connect(_on_defer)

func setup(player: Node, choices: Array) -> void:
	_player = player
	_choices = choices
	_title.text = "Выберите класс"
	_build_choices()

func _build_choices() -> void:
	for c in _list.get_children():
		c.queue_free()
	for cid in _choices:
		var btn: Button = Button.new()
		btn.text = _get_class_display(cid)
		btn.pressed.connect(func(): _on_select(cid))
		_list.add_child(btn)

func _get_class_display(class_id: String) -> String:
	var name := class_id
	for path in [
		"res://data/classes/common_classes.json",
		"res://data/classes/rare_classes.json",
		"res://data/classes/legendary_classes.json",
		"res://data/classes/mythic_classes.json"
	]:
		if ResourceLoader.exists(path):
			var text := FileAccess.get_file_as_string(path)
			if text != "":
				var json := JSON.new()
				if json.parse(text) == OK:
					var d: Dictionary = json.get_data()
					if d.has(class_id):
						name = d[class_id].get("name", class_id)
						break
	return name

func _on_select(class_id: String) -> void:
	var cm := get_node_or_null("/root/ClassManagerSingleton")
	if cm:
		cm.call("assign_class", _player, class_id)
	_close()

func _on_defer() -> void:
	_close()

func _close() -> void:
	get_tree().paused = false
	queue_free()

