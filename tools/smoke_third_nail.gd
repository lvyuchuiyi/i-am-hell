extends SceneTree
## Focused check for THE THIRD NAIL: execution wheel, swing transfer, final fall.

const MainScript := preload("res://scripts/main.gd")
const MainScene := preload("res://scenes/main.tscn")
const LevelsScript := preload("res://scripts/levels.gd")
const BOSS_BOMB_WINDOW := 4
const BOSS_DEFEATED := 9

var failures: Array = []


func _initialize() -> void:
	Engine.set_meta("iamhell_game_started", true)
	_run.call_deferred()


func _run() -> void:
	if LevelsScript.LEVELS.size() != 19:
		failures.append("level count is %d, expected 19" % LevelsScript.LEVELS.size())
	MainScript.level_index = 18
	var game = MainScene.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	if game.player == null:
		failures.append("player missing")
		_finish()
		return
	game.player.invuln = 9999.0
	if game.boss_node == null:
		failures.append("boss missing")
		_finish()
		return
	if game.chain_wheel == null or game.chain_pendulum == null:
		failures.append("wheel or pendulum missing")
	elif not _has_static_body(game.chain_wheel):
		failures.append("execution wheel has no physical body")
	if game.bone_nail == null or not is_instance_valid(game.bone_nail):
		failures.append("physical left nail missing")
	if game.boss_lift == null:
		failures.append("central boss lift missing")
	for r in game.grid.size():
		if (game.grid[r] as String).length() != 30:
			failures.append("map row %d has inconsistent width" % r)
			break
	if game.count_enemies() != 25:
		failures.append("expected 25 killable enemies, found %d" % game.count_enemies())
	if _count_char(game.grid, "S") != 9:
		failures.append("expected nine shooters")
	if _count_char(game.grid, "R") + _count_char(game.grid, "G") + _count_char(game.grid, "1") + _count_char(game.grid, "2") != 0:
		failures.append("old nail mechanisms still present")
	if _count_char(game.grid, "V") != 4 or _count_char(game.grid, "U") != 2:
		failures.append("new monster counts are wrong")
	if _count_char(game.grid, "F") != 5:
		failures.append("expected five central-lift release latches")
	if _count_char(game.grid, "J") != 0:
		failures.append("wheel-room safety grip is still present")
	if _count_char(game.grid, "c") != 1:
		failures.append("expected one execution-wheel charger marker")
	var execution_charger = _find_execution_charger(game)
	if execution_charger == null:
		failures.append("execution-wheel charger is missing")
	elif execution_charger.swappable:
		failures.append("execution-wheel charger can still be shifted")
	if _count_char(game.grid, "L") != 2:
		failures.append("expected two final-area lasers")
	var laser = _find_fx_script_at(game, "laser.gd", Vector2(1 * 16 + 8, 26 * 16 + 8))
	var laser_latch = _find_fx_at(game, Vector2(10 * 16 + 8, 24 * 16 + 8))
	if laser == null or laser_latch == null:
		failures.append("laser release tier is incomplete")
	else:
		if laser.get_beam_rect().size.x < 20.0 * 16.0:
			failures.append("laser is not a full-room timing gate")
		if laser_latch.position.y >= laser.position.y:
			failures.append("laser latch is not on the ledge above the beam")
		if (game.grid[25] as String)[4] != "-" or (game.grid[28] as String)[3] != "-":
			failures.append("laser gate is missing its upper or lower landing")
	for laser_row in [20, 26]:
		var gate = _find_fx_script_at(game, "laser.gd", Vector2(1 * 16 + 8, laser_row * 16 + 8))
		if gate == null or gate.get_beam_rect().size.x < 20.0 * 16.0:
			failures.append("laser row %d is not a full-room gate" % laser_row)
	if game.boss_lift.stops.size() < 4 or game.boss_lift.stops[3] != 28.0 * 16.0 + 3.0:
		failures.append("central lift does not stop below the laser gate")

	var spawn_danger := 0
	for i in 40:
		await physics_frame
		if game.danger:
			spawn_danger += 1
	if spawn_danger > 0:
		failures.append("safe spawn triggered slow motion for %d frames" % spawn_danger)

	# LEFT NAIL: spin the execution wheel.
	var anchor_charger = _find_execution_charger(game)
	if anchor_charger != null:
		anchor_charger.position = game.chain_wheel.position + Vector2(-18, 0)
		anchor_charger.velocity = Vector2.ZERO
	Engine.time_scale = 1.0
	game.danger = false
	game.danger_amt = 0.0
	game.chain_wheel._trigger(anchor_charger)
	if anchor_charger != null and anchor_charger.state != 4:
		failures.append("wheel charger was not pinned on impact")
	for i in 360:
		await physics_frame
	if not game.boss_node.left_bridge_created:
		failures.append("wheel did not break the left nail or create the bridge (wheel=%d boss=%d)" % [game.chain_wheel.state, game.boss_node.state])
	if not game.chain_pendulum.active:
		failures.append("wheel did not activate the swing hook")
	if anchor_charger != null and is_instance_valid(anchor_charger) and anchor_charger.alive:
		failures.append("left nail blast did not kill the wheel charger")

	# RIGHT NAIL: drive the already activated hook through the nail seat.
	game.chain_pendulum.velocity = Vector2(999, 0)
	game.chain_pendulum.on_swapped()
	if absf(game.chain_pendulum.angular_velocity) > 3.21:
		failures.append("chain boost exceeded its speed cap")
	if game.chain_pendulum.boost_t <= 0.0:
		failures.append("chain swap did not enable boosted sweep")
	game.chain_pendulum.active = true
	game.chain_pendulum.angle = 1.05
	game.chain_pendulum.angular_velocity = 2.2
	for i in 100:
		await physics_frame
		if game.boss_node.state >= 2:
			break
	if not game.boss_node.right_bridge_created:
		failures.append("swing hook did not break the right nail")
	if not game.chain_pendulum.locked or not game.chain_pendulum.chain_steps_created:
		failures.append("swing hook did not lock into the nail and create its chain path")
	if game.chain_pendulum.chain_step_rects.size() != 7:
		failures.append("chain path visual/physical step count mismatch")
	if not game.boss_lift.activated:
		failures.append("right nail did not activate the central lift")
	Engine.time_scale = 1.0
	var released_latches := 0
	for i in 400:
		if game.boss_lift.waiting_release:
			break
		await physics_frame
	var first_latch = _find_fx_at(game, Vector2(10 * 16 + 8, 34 * 16 + 8))
	if not game.boss_lift.waiting_release or first_latch == null:
		failures.append("central lift never waited at the first release tier")
	else:
		game.player.position = Vector2(first_latch.position.x, 35 * 16 - 7)
		game.player.velocity = Vector2.ZERO
		for i in 30:
			await physics_frame
		if not first_latch.used or game.boss_lift.waiting_release:
			failures.append("standing on the first release latch did not unlock the lift")
		else:
			released_latches += 1
	for i in 1200:
		if game.boss_lift.waiting_release:
			game.boss_lift.unlock_current_stop()
			released_latches += 1
		if game.boss_lift.stop_index == game.boss_lift.stops.size() - 1:
			break
		await physics_frame
	if game.boss_lift.stop_index != game.boss_lift.stops.size() - 1:
		failures.append("central lift did not reach the boss platform")
	if released_latches != 5:
		failures.append("central lift releases=%d stop=%d" % [released_latches, game.boss_lift.stop_index])
	var boss_top: float = game.boss_lift.y - 3.0
	var boss_landing := Rect2(0, 15 * 16, 30 * 16, 6)
	if not boss_landing.has_point(Vector2(game.boss_lift.position.x, boss_top)):
		failures.append("central lift has no shared landing with the boss platform")

	# FINAL: enter the arena, swap a bomb under the pinned player, repeat 3 times.
	game.player.position = Vector2(15 * 16 + 8, 14 * 16 + 8)
	game.player.velocity = Vector2.ZERO
	for i in 120:
		if game.boss_node.health_visible:
			break
		await physics_frame
	if not game.boss_node.health_visible or game.boss_node.health != 3:
		failures.append("boss health did not unlock at the arena")

	var swapped_cycles := 0
	var bomb_counts: Array = []
	var health_after: Array = []
	var last_health: int = game.boss_node.health
	for i in 1800:
		var boss = game.boss_node
		if boss.health < last_health:
			last_health = boss.health
			health_after.append(last_health)
		if boss.state == BOSS_BOMB_WINDOW and swapped_cycles == boss.hit_count and not boss.bombs.is_empty():
			for bomb in boss.bombs:
				if boss.get_fall_rect().intersects(bomb.get_hit_rect()):
					failures.append("boss bomb spawned inside the slam zone")
			if absf(game.player.position.x - boss.position.x) > 3.0:
				failures.append("boss did not pin the player under itself")
			var bomb = boss.bombs[0]
			var before: Vector2 = game.player.position
			var bomb_pos: Vector2 = bomb.position
			game._swap_bodies(game.player, bomb)
			game._swap_fx(before, bomb_pos, game.player, bomb, true)
			bomb.on_swapped()
			if boss.state != 5:
				failures.append("bomb swap did not start the slam windup immediately")
			bomb_counts.append(boss.bombs.size())
			swapped_cycles += 1
		if boss.state == BOSS_DEFEATED:
			break
		await physics_frame
	if swapped_cycles != 3:
		failures.append("boss bomb cycles=%d, expected 3" % swapped_cycles)
	if bomb_counts != [2, 1, 2]:
		failures.append("boss bomb counts=%s" % str(bomb_counts))
	if health_after != [2, 1, 0]:
		failures.append("boss health after explosions=%s" % str(health_after))
	if not game.boss_defeated:
		failures.append("boss core was not shattered after three explosions")

	if game.count_enemies() <= 0:
		failures.append("boss clear test unexpectedly had no remaining enemies")
	game._check_door()
	if not game.door_open:
		failures.append("exit stayed closed after the boss died")

	_finish()


func _count_char(grid: Array, ch: String) -> int:
	var total := 0
	for row in grid:
		total += (row as String).count(ch)
	return total


func _find_script(game, file_name: String):
	for e in game.get_entities():
		if e.get_script() != null and e.get_script().resource_path.get_file() == file_name:
			return e
	return null


func _find_execution_charger(game):
	for e in game.get_entities():
		if (
			e.get_script() != null
			and e.get_script().resource_path.get_file() == "enemy_charger.gd"
			and e.execution_variant
		):
			return e
	return null


func _find_fx_script(game, file_name: String):
	for e in game.fx_root.get_children():
		if e.get_script() != null and e.get_script().resource_path.get_file() == file_name:
			return e
	return null


func _find_fx_script_at(game, file_name: String, p: Vector2):
	for e in game.fx_root.get_children():
		if e.get_script() != null and e.get_script().resource_path.get_file() == file_name and e.position.distance_to(p) < 1.0:
			return e
	return null


func _find_fx_at(game, p: Vector2):
	for e in game.fx_root.get_children():
		if e.get_script() != null and e.get_script().resource_path.get_file() == "lift_latch.gd" and e.position.distance_to(p) < 1.0:
			return e
	return null


func _has_static_body(node) -> bool:
	for child in node.get_children():
		if child is StaticBody2D:
			return true
	return false


func _finish() -> void:
	if failures.is_empty():
		print("THE THIRD NAIL SMOKE OK")
		quit()
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
