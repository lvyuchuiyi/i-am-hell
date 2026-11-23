extends SceneTree
## Verifies music autoload routing, decoded durations, and slow-motion filtering.

var failures: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var music = root.get_node_or_null("Music")
	if music == null:
		failures.append("Music autoload is missing")
		_finish()
		return

	for id in ["menu", "electro_swing", "wacky", "boss"]:
		var stream: AudioStream = music._get_stream(id)
		if stream == null:
			failures.append("%s stream did not load" % id)
		elif stream.get_length() < 10.0:
			failures.append("%s stream length is %.2f" % [id, stream.get_length()])

	music.play_menu()
	await process_frame
	if music.current_id != "menu":
		failures.append("menu track was not selected")

	music.play_stage(0, false)
	await process_frame
	if music.current_id != "electro_swing":
		failures.append("level 1 did not select electro_swing")

	music.play_stage(1, false)
	await process_frame
	if music.current_id != "wacky":
		failures.append("level 2 did not select wacky")

	music.play_stage(18, true)
	await process_frame
	if music.current_id != "boss":
		failures.append("boss level did not select boss track")

	if music.music_bus < 0 or music.lowpass == null:
		failures.append("music bus or low-pass filter is missing")
	else:
		music.set_danger(1.0)
		await process_frame
		if not is_equal_approx(music.lowpass.cutoff_hz, 1800.0):
			failures.append("danger did not open the low-pass filter")

	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("MUSIC SMOKE OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
