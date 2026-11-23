extends SceneTree

const MainScript := preload("res://scripts/main.gd")
const MainScene := preload("res://scenes/main.tscn")


func _initialize() -> void:
	Engine.set_meta("iamhell_game_started", true)
	_run.call_deferred()


func _run() -> void:
	MainScript.level_index = 18
	var game = MainScene.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	var chain = game.chain_pendulum
	if chain == null or game.player == null:
		_fail("chain or player missing")
		return
	game.player.invuln = 9999.0

	var targets: Array = []
	for e in game.get_entities():
		if targets.size() >= 3:
			break
		if e.get_script() != null and e.get_script().resource_path.get_file() == "enemy_charger.gd":
			targets.append(e)
	if targets.size() != 3:
		_fail("not enough test targets")
		return

	var angles := [-0.75, 0.0, 0.75]
	for i in targets.size():
		var enemy = targets[i]
		enemy.position = chain.pivot + Vector2(sin(angles[i]), cos(angles[i])) * chain.chain_length
		enemy.velocity = Vector2.ZERO
		enemy.set_physics_process(false)

	chain.active = true
	chain.angle = -0.92
	chain.angular_velocity = chain.BOOST_CAP
	chain.boost_t = chain.BOOST_TIME
	var max_window_kills := 0
	for i in 120:
		max_window_kills = maxi(max_window_kills, chain.kill_window_count)
		await physics_frame

	var killed := 0
	for enemy in targets:
		if not is_instance_valid(enemy) or not enemy.alive:
			killed += 1
	if killed < 3:
		_fail("boosted chain killed %d targets, expected 3" % killed)
		return
	if max_window_kills < 3:
		_fail("chain multi-kill window peaked at %d" % max_window_kills)
		return
	print("CHAIN SWEEP SMOKE OK")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
