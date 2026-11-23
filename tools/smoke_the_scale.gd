extends SceneTree
## Focused check for THE SCALE's linked lift mechanic.

const MainScript := preload("res://scripts/main.gd")
const MainScene := preload("res://scenes/main.tscn")
const LevelsScript := preload("res://scripts/levels.gd")

var failures: Array = []


func _initialize() -> void:
	Engine.set_meta("iamhell_game_started", true)
	_run.call_deferred()


func _run() -> void:
	if LevelsScript.LEVELS.size() != 19:
		failures.append("level count is %d, expected 19" % LevelsScript.LEVELS.size())
	MainScript.level_index = 17
	var game = MainScene.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	if game.player == null:
		failures.append("player missing")
		_finish()
		return
	game.player.invuln = 999.0
	if game.level_count != 19:
		failures.append("runtime level count is %d" % game.level_count)
	if not _spawn_has_support(game.grid):
		failures.append("player spawn has no support")
	if game.count_enemies() != 5:
		failures.append("expected 5 enemies, found %d" % game.count_enemies())
	var pair = _first_script_in_children(game.fx_root, "weighted_lift_pair.gd")
	if pair == null:
		failures.append("weighted lift pair missing")
		_finish()
		return

	var initial_left: float = pair.left_y
	var initial_right: float = pair.right_y
	var enemies_at_start: int = game.count_enemies()
	var ground_y := {}
	for e in game.get_entities():
		var file: String = e.get_script().resource_path.get_file()
		if file == "enemy_charger.gd" or file == "enemy_shooter.gd" or file == "crate.gd":
			ground_y[e] = e.position.y
	var danger_frames := 0
	for i in 75:
		await physics_frame
		if game.danger:
			danger_frames += 1
	if pair.active:
		failures.append("lift activated while the player was still at spawn")
	if game.count_enemies() != enemies_at_start:
		failures.append("enemies died before player input")
	if danger_frames > 0:
		failures.append("safe spawn entered slow motion for %d frames" % danger_frames)
	for e in ground_y:
		if is_instance_valid(e) and e.alive and absf(e.position.y - float(ground_y[e])) > 2.0:
			failures.append("enemy or crate %s spawned above its support" % e.get_script().resource_path.get_file())

	game.player.position = Vector2(pair.left_position.x, pair.left_y - 10.0)
	game.player.velocity = Vector2.ZERO
	for i in 90:
		await physics_frame
	if not pair.active:
		failures.append("lift did not activate when player approached")
	if pair.left_y >= initial_left:
		failures.append("heavier right lift did not raise the left lift")
	if pair.right_y <= initial_right:
		failures.append("lifts did not move in opposite directions")
	game.player.position = Vector2(pair.right_position.x, pair.right_y - 8.0)
	game.player.velocity = Vector2.ZERO
	pair.active = true
	pair.moving_step = 1.0
	if pair.threatens(game.player.position):
		failures.append("riding a moving lift incorrectly counts as being crushed")

	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("THE SCALE SMOKE OK")
		quit()
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _spawn_has_support(grid: Array) -> bool:
	for r in grid.size():
		var c: int = (grid[r] as String).find("P")
		if c < 0:
			continue
		if r + 1 >= grid.size():
			return false
		var below: String = (grid[r + 1] as String)[c]
		return below == "#" or below == "-"
	return false


func _first_script_in_children(parent, file_name: String):
	for child in parent.get_children():
		if child.get_script() != null and child.get_script().resource_path.get_file() == file_name:
			return child
	return null
