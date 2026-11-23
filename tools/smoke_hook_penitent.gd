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
	game.player.invuln = 9999.0
	var enemy = _find_script(game, "enemy_hook_penitent.gd")
	if enemy == null:
		_finish()
		return
	# Swapping during an upward reel must interrupt it without launching player.
	enemy.state = 3  # PULL
	enemy.anchor_position = enemy.position + Vector2(0, -120)
	enemy.velocity = Vector2(0, -250)
	game.player.position = enemy.position + Vector2(-20, 0)
	game.player.velocity = Vector2.ZERO
	game.target = enemy
	game.shift_energy = 3
	game.swap_cd = 0.0
	game.try_swap()
	if game.player.velocity.y < -1.0:
		failures.append("hook reel launched player upward after swap")

	# A hook sent from the runway must pass one-way support and anchor on the wall.
	enemy.state = 2  # THROW
	enemy.position = Vector2(420, enemy.position.y)
	enemy.hook_dir = Vector2.RIGHT
	enemy.hook_spawn = enemy.position
	enemy.hook_position = enemy.position
	for i in 240:
		await physics_frame
		if not is_instance_valid(enemy) or not enemy.alive:
			break
	if is_instance_valid(enemy) and enemy.alive:
		failures.append("hook penitent did not die on its solid anchor")

	_finish()


func _find_script(game, file_name: String):
	for e in game.get_entities():
		if e.get_script() != null and e.get_script().resource_path.get_file() == file_name:
			return e
	return null


func _finish() -> void:
	if failures.is_empty():
		print("HOOK PENITENT SMOKE OK")
		quit()
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
