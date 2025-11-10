extends Node

func migrate(data: Dictionary) -> Dictionary:
	var out := data.duplicate(true)
	var player: Dictionary = out.get("player", {})
	if not player.has("global_level"):
		player["global_level"] = 1
	if not player.has("owned_classes"):
		player["owned_classes"] = []
	out["player"] = player
	return out


