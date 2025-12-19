extends Area2D
class_name DepthZone

@export_range(1, 3, 1) var depth_level: int = 1

var _level_root: Node = null

func _ready() -> void:
	_level_root = get_tree().get_first_node_in_group("level_root")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	# Ожидается, что Player в группе "player".
	if not body.is_in_group("player"):
		return
	if _level_root and _level_root.has_method("set_depth"):
		_level_root.set_depth(depth_level)
