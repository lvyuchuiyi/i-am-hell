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
	game.player.position = Vector2(240, 900)
	game.cam_y = game.player.position.y - 24.0
	game.focus = Vector2(240, 137)
	game.focus_w = 0.0
	game.danger_amt = 0.0
	game._update_camera(0.0)
	var calm_y: float = game.camera.position.y
	game.danger_amt = 0.25
	game._update_camera(0.016)
	var danger_y: float = game.camera.position.y
	if absf(danger_y - calm_y) > 10.0:
		failures.append("danger camera jumped %.2f px on entering slow motion" % absf(danger_y - calm_y))
	if danger_y < 300.0:
		failures.append("high-level danger camera fell back to screen-space coordinates")
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("CAMERA FOLLOW SMOKE OK")
		quit()
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
