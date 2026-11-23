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
	game.game_over = true
	game.cleared = true
	game.all_clear = true
	game.deaths = 17
	MainScript.run_time = 932.4
	MainScript.total_score = 18420
	MainScript.run_perfects = 26
	MainScript.run_best_combo = 9
	MainScript.run_total_kills = 163
	for i in 110:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "C:/Users/24233/Documents/Codex/2026-11-22/ad/work/iamhell-ending-preview.png"
	var error := image.save_png(path)
	if error != OK:
		push_error("failed to save ending preview: %s" % error)
		quit(1)
		return
	print("ENDING PREVIEW OK")
	quit()
