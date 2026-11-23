extends SceneTree

const MainScript := preload("res://scripts/main.gd")
const MainScene := preload("res://scenes/main.tscn")

var failures: Array = []


func _initialize() -> void:
	Engine.set_meta("iamhell_game_started", true)
	_run.call_deferred()


func _run() -> void:
	MainScript.level_index = 18
	var game = MainScene.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame

	var wing = _find_script(game, "enemy_stone_wing.gd")
	var hook = _find_script(game, "enemy_hook_penitent.gd")
	if wing != null:
		wing.state = 1
		wing.timer = 0.1
		wing.dash_dir = Vector2.RIGHT
		if wing.threatens(wing.position + Vector2(0, -90)):
			failures.append("stone wing warns outside its dash line")
		if not wing.threatens(wing.position + Vector2(24, 0)):
			failures.append("stone wing misses a real dash threat")
	if hook != null:
		hook.state = 1
		hook.timer = 0.1
		hook.hook_dir = Vector2.RIGHT
		if hook.threatens(hook.position + Vector2(0, -90)):
			failures.append("hook penitent warns outside its hook line")
		if not hook.threatens(hook.position + Vector2(38, 0)):
			failures.append("hook penitent misses a real hook threat")

	_finish()


func _find_script(game, file_name: String):
	for e in game.get_entities():
		if e.get_script() != null and e.get_script().resource_path.get_file() == file_name:
			return e
	return null


func _finish() -> void:
	if failures.is_empty():
		print("THREAT PATH SMOKE OK")
		quit()
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
