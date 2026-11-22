extends Node
## 音效播放器。
## 先读 assets/sfx/*.wav：来自 SubspaceAudio（Juhani Junkala）的 CC0 音效包，用 tools/import_sfx_pack.py 导入；
## 没有的再读 assets/sfx_synth/*.wav：tools/make_sfx.py 从零合成的备用音效（模拟 GBA 发声芯片）。
## - 每次播放随机微调音高，同一个声音连续响也不会显得机械
## - 子弹时间里音高整体压低，听起来更沉
## - 同一个声音 30 毫秒内只响一次，避免一帧里叠十几个变成噪音
## 音量在 VOLUME 里调（分贝，0 最响，-6 大约一半）。

const NAMES := [
	"swap", "perfect", "fail", "kill", "new_style", "death", "jump", "land",
	"shoot", "windup", "dash", "explode", "laser_charge", "laser_fire", "slam",
	"reflect", "enemy_swap", "door", "clear", "tick", "slowmo",
]
const VOLUME := {
	"swap": -5.0, "perfect": -3.0, "fail": -8.0, "kill": -3.0, "new_style": -9.0,
	"death": -5.0, "jump": -11.0, "land": -12.0, "shoot": -9.0, "windup": -10.0,
	"dash": -8.0, "explode": -2.0, "laser_charge": -12.0, "laser_fire": -6.0,
	"slam": -4.0, "reflect": -7.0, "enemy_swap": -4.0, "door": -6.0, "clear": -4.0,
	"tick": -14.0, "slowmo": -7.0,
}
const POOL := 12

var game = null
var streams := {}
var players: Array = []
var next_player: int = 0
var last_play := {}


func _ready() -> void:
	for n in NAMES:
		for folder in ["sfx", "sfx_synth"]:
			var path := "res://assets/%s/%s.wav" % [folder, n]
			if ResourceLoader.exists(path):
				streams[n] = load(path)
				break
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)


func play(id: String, pitch_var: float = 0.06) -> void:
	if not streams.has(id):
		return
	var now := Time.get_ticks_msec()
	if now - int(last_play.get(id, -1000)) < 30:
		return
	last_play[id] = now
	var p: AudioStreamPlayer = players[next_player]
	next_player = (next_player + 1) % POOL
	p.stream = streams[id]
	var slow: float = 0.0
	if game != null:
		slow = game.danger_amt
	p.pitch_scale = randf_range(1.0 - pitch_var, 1.0 + pitch_var) * lerpf(1.0, 0.85, slow)
	p.volume_db = VOLUME.get(id, -6.0)
	p.play()
