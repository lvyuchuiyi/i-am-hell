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
	game.player.invuln = 9999.0
	var hook = null
	for e in game.get_entities():
		if e.get_script() != null and e.get_script().resource_path.get_file() == "enemy_hook_penitent.gd":
			hook = e
			break
	if hook == null:
		print("NO HOOK")
		quit(1)
		return

	game.player.position = hook.position + Vector2(-24, -8)
	game.player.velocity = Vector2(0, -100)
	var before_player: Vector2 = game.player.position
	var before_hook: Vector2 = hook.position
	game.target = hook
	game.shift_energy = 3
	game.swap_cd = 0.0
	game.try_swap()
	print("after swap player=", game.player.position, " hook=", hook.position, " player_vel=", game.player.velocity)
	for i in 12:
		await physics_frame
		print(i, " player=", game.player.position, " vel=", game.player.velocity, " hook=", hook.position, " state=", hook.state)
	print("moved player=", before_player.distance_to(game.player.position), " hook=", before_hook.distance_to(hook.position))
	quit()
