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
	var boss = game.boss_node
	if boss == null or game.player == null:
		_fail("boss or player missing")
		return
	boss.break_left_chain()
	boss.break_right_chain()
	game.boss_lift.activate()
	for e in game.get_entities():
		if e.is_in_group("enemy"):
			e.alive = false
	game.player.position = Vector2(15 * 16 + 8, 14 * 16 + 8)
	game.player.velocity = Vector2.ZERO
	boss._try_start_fight()
	if not boss.health_visible:
		_fail("boss health did not unlock")
		return

	var saw_window := false
	for i in 420:
		if boss.state == 4:
			saw_window = true
		if game.game_over:
			break
		await physics_frame
	if not saw_window:
		_fail("bomb window never opened")
	elif not game.game_over:
		_fail("ignoring the bomb did not trigger a lethal slam")
	elif not game.death_cause.contains("third nail"):
		_fail("no-swap death had wrong cause: %s" % game.death_cause)
	else:
		print("BOSS NO SWAP SMOKE OK")
		quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
