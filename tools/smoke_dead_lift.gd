extends SceneTree
## Focused runtime check for the DEAD LIFT level and PLUMB enemy.

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
	MainScript.level_index = 16
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
		failures.append("expected 5 killable enemies, found %d" % game.count_enemies())
	if _count_char(game.grid, "L") != 2:
		failures.append("expected 2 lasers")
	var plumb = _first_script(game, "enemy_plumb.gd")
	if plumb == null:
		failures.append("PLUMB enemy missing")

	var enemies_at_start: int = game.count_enemies()
	var ground_y := {}
	for e in game.get_entities():
		var file: String = e.get_script().resource_path.get_file()
		if file == "enemy_charger.gd" or file == "enemy_shooter.gd":
			ground_y[e] = e.position.y
	var danger_frames := 0
	for i in 75:
		await physics_frame
		if game.danger:
			danger_frames += 1
	if game.count_enemies() != enemies_at_start:
		failures.append("enemies died before player input: %d -> %d" % [enemies_at_start, game.count_enemies()])
	if danger_frames > 0:
		failures.append("safe spawn entered slow motion for %d frames" % danger_frames)
	for e in ground_y:
		if is_instance_valid(e) and e.alive and absf(e.position.y - float(ground_y[e])) > 2.0:
			failures.append("enemy %s spawned above its support" % e.get_script().resource_path.get_file())
	if plumb != null and is_instance_valid(plumb) and int(plumb.state) != 0:
		failures.append("PLUMB left dormant state before the player approached")
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("DEAD LIFT SMOKE OK")
		quit()
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _count_char(grid: Array, target: String) -> int:
	var count := 0
	for line in grid:
		for ch in line:
			if ch == target:
				count += 1
	return count


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


func _first_script(game, file_name: String):
	for e in game.get_entities():
		if e.get_script().resource_path.get_file() == file_name:
			return e
	return null
