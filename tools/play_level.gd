extends SceneTree
## Debug launcher: godot --path . --script res://tools/play_level.gd -- 17

const MainScript := preload("res://scripts/main.gd")
const MainScene := preload("res://scenes/main.tscn")


func _initialize() -> void:
	Engine.set_meta("iamhell_game_started", true)
	var requested := 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			requested = int(arg.trim_prefix("--level="))
		elif arg.is_valid_int():
			requested = int(arg)
	MainScript.level_index = maxi(requested - 1, 0)
	var game = MainScene.instantiate()
	root.add_child(game)
	current_scene = game
