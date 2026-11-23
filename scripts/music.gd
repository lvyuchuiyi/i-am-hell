extends Node
## Persistent BGM controller. Keeps music alive across scene changes and
## crossfades tracks in real time so Engine.time_scale does not stretch fades.

const TRACKS := {
	"menu": {
		"path": "res://assets/music/menu_quest_of_doom.ogg",
		"db": -12.0,
	},
	"electro_swing": {
		"path": "res://assets/music/stage_electro_swing.mp3",
		"db": -10.5,
	},
	"wacky": {
		"path": "res://assets/music/stage_wacky_workings.ogg",
		"db": -13.0,
	},
	"boss": {
		"path": "res://assets/music/boss_inferior_deity.ogg",
		"db": -10.0,
	},
}
const STAGE_TRACKS := ["electro_swing", "wacky"]
const MUSIC_BUS := "Music"
const SILENT_DB := -60.0
const FADE_SPEED_DB := 58.0
const LOOP_FADE := 0.7
const BUS_BASE_DB := -4.0
const DANGER_DUCK_DB := 3.0
const CUTOFF_OPEN := 20000.0
const CUTOFF_DANGER := 1800.0

var players: Array[AudioStreamPlayer] = []
var targets: Array[float] = [SILENT_DB, SILENT_DB]
var streams := {}
var active_player: int = 0
var current_id: String = ""
var danger_amt: float = 0.0
var last_us: int = 0
var music_bus: int = -1
var lowpass: AudioEffectLowPassFilter


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_music_bus()
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = MUSIC_BUS
		player.volume_db = SILENT_DB
		add_child(player)
		players.append(player)
	last_us = Time.get_ticks_usec()


func play_menu() -> void:
	play_track("menu")


func play_stage(level_index: int, boss_mode: bool) -> void:
	var id: String = "boss" if boss_mode else STAGE_TRACKS[absi(level_index) % STAGE_TRACKS.size()]
	play_track(id)


func play_ending() -> void:
	play_track("menu")


func play_track(id: String) -> void:
	if current_id == id and players[active_player].playing:
		return
	var stream := _get_stream(id)
	if stream == null:
		return
	var next := 1 - active_player
	targets[active_player] = SILENT_DB
	_start_player(next, stream, float(TRACKS[id]["db"]))
	active_player = next
	current_id = id


func set_danger(value: float) -> void:
	danger_amt = clampf(value, 0.0, 1.0)


func fade_out() -> void:
	current_id = ""
	for i in players.size():
		targets[i] = SILENT_DB
	set_danger(0.0)


func _get_stream(id: String) -> AudioStream:
	if not TRACKS.has(id):
		return null
	if streams.has(id):
		return streams[id]
	var path: String = TRACKS[id]["path"]
	if not ResourceLoader.exists(path):
		push_warning("Missing music asset: %s" % path)
		return null
	var stream: AudioStream = load(path)
	_set_native_loop(stream, false)
	streams[id] = stream
	return stream


func _start_player(index: int, stream: AudioStream, target_db: float) -> void:
	var player := players[index]
	player.stop()
	player.stream = stream
	player.volume_db = SILENT_DB
	player.pitch_scale = lerpf(1.0, 0.975, danger_amt)
	player.play()
	targets[index] = target_db


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real_dt := minf(float(now - last_us) / 1000000.0, 0.1)
	last_us = now

	for i in players.size():
		var player := players[i]
		if not player.playing:
			continue
		player.volume_db = move_toward(player.volume_db, targets[i], real_dt * FADE_SPEED_DB)
		player.pitch_scale = lerpf(player.pitch_scale, lerpf(1.0, 0.975, danger_amt), minf(real_dt * 8.0, 1.0))
		if targets[i] <= SILENT_DB and player.volume_db <= SILENT_DB + 0.5:
			player.stop()

	var active := players[active_player]
	if current_id != "" and active.playing:
		var length := active.stream.get_length()
		if length > 4.0 and active.get_playback_position() >= length - LOOP_FADE:
			var next := 1 - active_player
			targets[active_player] = SILENT_DB
			_start_player(next, active.stream, float(TRACKS[current_id]["db"]))
			active_player = next

	if music_bus >= 0 and lowpass != null:
		lowpass.cutoff_hz = lerpf(CUTOFF_OPEN, CUTOFF_DANGER, danger_amt)
		AudioServer.set_bus_volume_db(music_bus, BUS_BASE_DB - DANGER_DUCK_DB * danger_amt)


func _set_native_loop(stream: AudioStream, enabled: bool) -> void:
	if stream is AudioStreamOggVorbis:
		stream.loop = enabled
	elif stream is AudioStreamMP3:
		stream.loop = enabled


func _setup_music_bus() -> void:
	music_bus = AudioServer.get_bus_index(MUSIC_BUS)
	if music_bus < 0:
		AudioServer.add_bus()
		music_bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(music_bus, MUSIC_BUS)
		AudioServer.set_bus_send(music_bus, "Master")
	AudioServer.set_bus_volume_db(music_bus, BUS_BASE_DB)
	lowpass = AudioEffectLowPassFilter.new()
	lowpass.cutoff_hz = CUTOFF_OPEN
	AudioServer.add_bus_effect(music_bus, lowpass)
