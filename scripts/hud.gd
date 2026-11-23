extends Node2D
## 界面（GBA 风格）：放在 CanvasLayer 里，不受镜头影响。全部用像素字体和带边框的面板。
## 顶部状态栏、底部提示栏、关卡开头横幅、子弹时间黑边、PERFECT SHIFT、过关 / 死亡 / 通关对话框。

const PF := preload("res://scripts/pixel_font.gd")

const W := 480.0
const H := 270.0
const BAR_H := 6.0      # 子弹时间黑边：细一点，不挡地面

const C_BLACK := Color(0, 0, 0)
const C_DARK := Color(0.33, 0.33, 0.33)
const C_MID := Color(0.66, 0.66, 0.66)
const C_WHITE := Color(1, 1, 1)
const C_RED := Color(0.66, 0.08, 0.1)
const C_EMBER := Color(1.0, 0.35, 0.2)
const AUTHOR_CREDIT := "由缕雨吹衣制作"

var game = null
var intro_t: float = 0.0   # 关卡开头的计时（横幅滑入滑出）
var all_clear_t: float = 0.0
var was_all_clear: bool = false
var author_font: SystemFont


func _ready() -> void:
	author_font = SystemFont.new()
	author_font.font_names = PackedStringArray([
		"Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "SimHei", "sans-serif"
	])
	author_font.allow_system_fallback = true


func _process(delta: float) -> void:
	intro_t += delta
	if game != null and game.all_clear:
		if was_all_clear:
			all_clear_t += delta
		else:
			all_clear_t = 0.0
		was_all_clear = true
	else:
		all_clear_t = 0.0
		was_all_clear = false
	queue_redraw()


func _fmt_time(t: float) -> String:
	return "%d:%05.2f" % [int(t) / 60, fmod(t, 60.0)]


## GBA 式对话框：黑底 + 外白内灰双层边框 + 四角铆钉
func _panel(r: Rect2, alpha: float = 1.0) -> void:
	draw_rect(r, Color(0, 0, 0, alpha))
	draw_rect(r, Color(1, 1, 1, alpha), false, 1.0)
	draw_rect(r.grow(-2.0), Color(0.66, 0.66, 0.66, alpha), false, 1.0)
	for corner in [r.position, Vector2(r.end.x - 3.0, r.position.y), Vector2(r.position.x, r.end.y - 3.0), r.end - Vector2(3, 3)]:
		draw_rect(Rect2(corner, Vector2(3, 3)), Color(1, 1, 1, alpha))


func _draw() -> void:
	if game == null:
		return
	if game.select_open:
		_draw_level_select()
		return
	if game.all_clear:
		_draw_final_ending()
		return

	# 子弹时间：上下电影黑边（盖在状态栏外面，压迫感更强）
	var bar: float = BAR_H * game.danger_amt
	if bar > 0.5:
		draw_rect(Rect2(0, 0, W, bar), C_BLACK)
		draw_rect(Rect2(0, H - bar, W, bar), C_BLACK)
		draw_rect(Rect2(0, bar, W, 1), C_RED)
		draw_rect(Rect2(0, H - bar - 1.0, W, 1), C_RED)

	# ---------------- 完美换位：动漫式集中线，从换位点向四周炸开
	if game.burst_t > 0.0:
		var k: float = game.burst_t / 0.35
		var c: Vector2 = game.burst_pos
		for i in 40:
			var ang := float(i) * TAU / 40.0 + float((i * 7919) % 100) * 0.004
			var dir := Vector2.from_angle(ang)
			var r0 := 40.0 + float((i * 37) % 50) + (1.0 - k) * 60.0
			var wdt := 2.0 if i % 3 == 0 else 1.0
			draw_line(c + dir * r0, c + dir * 600.0, Color(1, 1, 1, 0.25 + 0.5 * k), wdt)

	# ---------------- 连杀热度：左右两边的墙烧起来（连杀越多火越大）。只在墙上烧，不挡地面和坑
	var heat: float = game.heat
	if heat > 0.01:
		var tt: float = game.fx_time
		var y := 14.0
		while y < H:
			var n := 0.5 + 0.5 * sin(y * 0.23 - tt * 13.0 + sin(y * 0.05 + tt * 2.0) * 3.0)
			var fw := heat * (6.0 + 12.0 * n)
			draw_rect(Rect2(0, y, fw, 4), Color(C_RED.r, C_RED.g, C_RED.b, 0.6))
			draw_rect(Rect2(0, y + 1.0, fw * 0.55, 2), Color(C_EMBER.r, C_EMBER.g, C_EMBER.b, 0.7))
			var n2 := 0.5 + 0.5 * sin(y * 0.19 - tt * 11.0 + 1.7)
			var fw2 := heat * (6.0 + 12.0 * n2)
			draw_rect(Rect2(W - fw2, y, fw2, 4), Color(C_RED.r, C_RED.g, C_RED.b, 0.6))
			draw_rect(Rect2(W - fw2 * 0.55, y + 1.0, fw2 * 0.55, 2), Color(C_EMBER.r, C_EMBER.g, C_EMBER.b, 0.7))
			y += 4.0

	# ---------------- 顶部状态栏
	draw_rect(Rect2(0, 0, W, 13), C_BLACK)
	draw_rect(Rect2(0, 13, W, 1), C_MID)
	PF.draw(self, Vector2(6, 3), "%d-%d %s" % [game.level_no, game.level_count, game.level_name], 1, C_WHITE)
	# 能量：SHIFT + 三个格子，下一格回复进度用一条小横线表示
	PF.draw(self, Vector2(150, 3), "SHIFT", 1, C_MID)
	for i in game.max_shift_shown:
		var r := Rect2(182 + i * 8, 3, 6, 7)
		if i < game.shift_energy:
			draw_rect(r, C_WHITE)
			draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(2, 2)), C_MID)
		else:
			draw_rect(r, C_DARK, false, 1.0)
			if i == game.shift_energy:
				var k: float = game.regen_t / game.shift_regen_shown
				draw_rect(Rect2(r.position.x + 1, r.end.y - 2, 4.0 * k, 1), C_MID)
	var boss_active: bool = (
		game.boss_mode
		and game.boss_node != null
		and is_instance_valid(game.boss_node)
		and game.boss_node.health_visible
	)
	if boss_active:
		_draw_boss_health(game.boss_node)
	else:
		var enemies: int = game.count_enemies()
		if enemies > 0 and not game.always_open:
			PF.draw(self, Vector2(290, 3), "ENEMIES %d" % enemies, 1, C_WHITE, 1)
		else:
			var blink := int(intro_t * 4.0) % 2 == 0
			PF.draw(self, Vector2(290, 3), "EXIT OPEN", 1, C_EMBER if blink else C_WHITE, 1)
	PF.draw(self, Vector2(474, 3), "%s  DEATHS %d" % [_fmt_time(game.level_time), game.deaths], 1, C_WHITE, 2)

	# 连杀
	if game.combo > 1:
		PF.draw(self, Vector2(W / 2.0, 36 if boss_active else 18), "%d COMBO" % game.combo, 1, C_WHITE, 1, C_RED)

	if (
		game.level_index == 18
		and game.boss_node != null
		and is_instance_valid(game.boss_node)
		and game.boss_node.has_method("needs_wheel_hint")
		and game.boss_node.needs_wheel_hint()
		and game.player != null
		and game.player.position.y > 62.0 * 16.0
		and game.player.position.y < 76.0 * 16.0
	):
		_draw_wheel_hint()

	# ---------------- 底部提示栏：只在每关开头显示 5 秒，然后淡出（之后不挡地面和坑）
	if not game.game_over and intro_t < 5.0:
		var ha := clampf((5.0 - intro_t) * 2.0, 0.0, 1.0)
		draw_rect(Rect2(0, H - 11.0, W, 11), Color(0, 0, 0, ha))
		draw_rect(Rect2(0, H - 12.0, W, 1), Color(C_MID.r, C_MID.g, C_MID.b, ha))
		PF.draw(self, Vector2(W / 2.0, H - 9.0), game.level_hint, 1, Color(C_MID.r, C_MID.g, C_MID.b, ha), 1)

	# ---------------- 关卡开头：横幅从左边滑进来，停一会儿，再从右边滑出去
	if intro_t < 1.8 and not game.game_over:
		var slide := 0.0
		if intro_t < 0.25:
			slide = -W * (1.0 - ease(intro_t / 0.25, 0.4))
		elif intro_t > 1.5:
			slide = W * ease((intro_t - 1.5) / 0.3, 2.0)
		var band := Rect2(slide, 100, W, 34)
		draw_rect(band, C_BLACK)
		draw_rect(Rect2(slide, 100, W, 1), C_WHITE)
		draw_rect(Rect2(slide, 102, W, 1), C_DARK)
		draw_rect(Rect2(slide, 131, W, 1), C_DARK)
		draw_rect(Rect2(slide, 133, W, 1), C_WHITE)
		PF.draw(self, Vector2(slide + W / 2.0, 105), "STAGE %d-%d" % [game.level_no, game.level_count], 1, C_RED, 1)
		PF.draw(self, Vector2(slide + W / 2.0, 115), game.level_name, 2, C_WHITE, 1, C_RED)
		if game.level_no == 9:
			PF.draw(self, Vector2(slide + W / 2.0, 90), "WORLD 2 - NEW RULES", 1, C_EMBER, 1, C_BLACK)
		if game.level_no == 1:
			PF.draw(self, Vector2(slide + W / 2.0, 142), "A/D MOVE  W/SPACE JUMP  MOUSE AIM  SHIFT/CLICK SWAP  R RETRY", 1, C_WHITE, 1, C_BLACK)
			PF.draw(self, Vector2(slide + W / 2.0, 152), "EACH SHIFT COSTS A CHARGE. MAKE THEM KILL EACH OTHER TO GET IT BACK.", 1, C_MID, 1, C_BLACK)

	# ---------------- PERFECT SHIFT：大字弹出，红色投影，最后淡出
	if game.perfect_t > 0.0:
		var k2: float = 1.0 - game.perfect_t / 0.9
		var sc := 3 if k2 < 0.15 else 2
		var alpha := clampf(game.perfect_t * 3.0, 0.0, 1.0)
		var shake := Vector2(randf_range(-1.0, 1.0), 0) if k2 < 0.2 else Vector2.ZERO
		PF.draw(self, Vector2(W / 2.0, 58) + shake, "PERFECT SHIFT", sc, Color(1, 1, 1, alpha), 1, Color(C_RED.r, C_RED.g, C_RED.b, alpha))
		PF.draw(self, Vector2(W / 2.0, 82), "+%d  +SHIFT" % game.perfect_bonus, 1, Color(1, 1, 1, alpha), 1, Color(0, 0, 0, alpha))

	# ---------------- 过关
	if game.cleared:
		_panel(Rect2(140, 78, 200, 92))
		PF.draw(self, Vector2(W / 2.0, 88), "ROOM CLEAR", 2, C_WHITE, 1, C_DARK)
		PF.draw(self, Vector2(W / 2.0 - 24.0, 112), "RANK", 1, C_MID, 1)
		var rank_col := C_EMBER if game.rank == "S" else C_WHITE
		PF.draw(self, Vector2(W / 2.0 + 14.0, 106), game.rank, 3, rank_col, 1, C_RED)
		PF.draw(self, Vector2(W / 2.0, 140), "%s  STYLES %d  PERFECT %d" % [_fmt_time(game.level_time), game.methods_used.size(), game.perfects], 1, C_WHITE, 1)
		PF.draw(self, Vector2(W / 2.0, 152), "SCORE %d" % game.score, 1, C_MID, 1)
		return

	# ---------------- 死亡：先让死亡镜头推近，0.45 秒后再弹出对话框（这时按任意键马上重来）
	if game.game_over and game.death_t > 0.45:
		var a2 := clampf((game.death_t - 0.45) * 4.0, 0.0, 1.0)
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.5 * a2))
		_panel(Rect2(140, 92, 200, 74), a2)
		PF.draw(self, Vector2(W / 2.0, 102), "YOU DIED", 3, Color(1, 1, 1, a2), 1, Color(C_RED.r, C_RED.g, C_RED.b, a2))
		PF.draw(self, Vector2(W / 2.0, 130), "KILLED BY %s" % game.death_cause, 1, Color(0.66, 0.66, 0.66, a2), 1)
		if int(intro_t * 2.0) % 2 == 0:
			PF.draw(self, Vector2(W / 2.0, 146), "SHIFT / CLICK / R - TRY AGAIN", 1, Color(1, 1, 1, a2), 1)


func _draw_final_ending() -> void:
	var t := all_clear_t
	draw_rect(Rect2(-10, -10, W + 20, H + 20), C_BLACK)
	_draw_ending_backdrop(t)
	_draw_ending_ring(t)
	for i in 3:
		var delay := 0.16 + float(i) * 0.14
		var drop := clampf((t - delay) / 0.42, 0.0, 1.0)
		var crack := clampf((t - delay - 0.34) / 0.28, 0.0, 1.0)
		_draw_ending_nail(Vector2(96 + i * 46, 60), drop, crack, i)
	_draw_ending_figure(t)
	_draw_ending_title(t)
	_draw_ending_record()
	_draw_ending_footer(t)


func _draw_ending_backdrop(t: float) -> void:
	var drift := sin(t * 0.55) * 7.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(292 + drift, -16), Vector2(W + 20, -16),
		Vector2(W + 20, 226), Vector2(420 + drift, 184),
		Vector2(338 + drift, 78),
	]), Color(0.22, 0.025, 0.045))
	draw_colored_polygon(PackedVector2Array([
		Vector2(W + 20, -16), Vector2(W + 20, 72),
		Vector2(404 + drift, -16),
	]), C_RED)
	draw_line(Vector2(292 + drift, -16), Vector2(420 + drift, 184), C_RED, 2.0)
	draw_line(Vector2(302 + drift, -16), Vector2(428 + drift, 184), Color(1, 1, 1, 0.38), 1.0)
	for i in 9:
		var y := -10.0 + float(i) * 29.0
		draw_line(
			Vector2(282 + i * 8 + drift, y),
			Vector2(W + 14, y - 104),
			Color(0, 0, 0, 0.76),
			3.0,
		)
	for x in range(16, 464, 24):
		draw_rect(Rect2(x, 0, 1, H), Color(1, 1, 1, 0.022))
	for y in range(18, H, 18):
		draw_rect(Rect2(0, y, W, 1), Color(1, 1, 1, 0.022))
	for y in range(0, H, 3):
		draw_rect(Rect2(0, y, W, 1), Color(0, 0, 0, 0.10))
	for i in 20:
		var speed := 18.0 + float(i % 5) * 7.0
		var x := fmod(float(i) * 73.0 + t * speed, 520.0) - 20.0
		var y := 22.0 + float((i * 47) % 215)
		var length := 4.0 + float((i * 13) % 18)
		draw_line(Vector2(x, y), Vector2(x + length, y), Color(C_RED.r, C_RED.g, C_RED.b, 0.24), 1.0)
	var sweep_y := fmod(t * 46.0, 248.0)
	draw_rect(Rect2(0, sweep_y, W, 1), Color(1, 1, 1, 0.14))
	if t < 1.25:
		var k := t / 1.25
		var center := Vector2(188, 128)
		draw_circle(center, 20.0 + k * 170.0, Color(1, 1, 1, 0.30 * (1.0 - k)))
		draw_arc(center, 12.0 + k * 150.0, 0.0, TAU, 40, Color(C_RED.r, C_RED.g, C_RED.b, 0.8 * (1.0 - k)), 3.0)
		draw_rect(Rect2(0, 0, W, H), Color(1, 1, 1, 0.18 * (1.0 - k)))


func _draw_ending_ring(t: float) -> void:
	var center := Vector2(184, 127)
	for layer in 3:
		var radius := 76.0 + layer * 10.0
		var start := t * (0.32 + layer * 0.08) + layer * 1.7
		for part in 3:
			var arc_start := start + part * TAU / 3.0
			draw_arc(
				center,
				radius,
				arc_start,
				arc_start + 1.28,
				24,
				Color(C_RED.r, C_RED.g, C_RED.b, 0.34 - layer * 0.07),
				2.0,
			)
	for i in 12:
		var angle := float(i) * TAU / 12.0 - t * 0.22
		var p := center + Vector2.from_angle(angle) * 68.0
		var q := center + Vector2.from_angle(angle) * 78.0
		draw_line(p, q, Color(1, 1, 1, 0.20), 2.0)
	draw_line(center + Vector2(-132, 0), center + Vector2(132, 0), Color(C_RED.r, C_RED.g, C_RED.b, 0.42), 1.0)
	draw_line(center + Vector2(0, -112), center + Vector2(0, 112), Color(C_RED.r, C_RED.g, C_RED.b, 0.28), 1.0)


func _draw_ending_nail(base: Vector2, drop: float, crack: float, index: int) -> void:
	if drop <= 0.0:
		return
	var p := Vector2(base.x, lerpf(-34.0, base.y, ease(drop, 2.2)))
	draw_rect(Rect2(p.x - 3, p.y - 24, 6, 25), C_WHITE)
	draw_rect(Rect2(p.x - 5, p.y - 21, 10, 5), C_RED)
	draw_colored_polygon(PackedVector2Array([
		Vector2(p.x - 5, p.y), Vector2(p.x + 5, p.y), Vector2(p.x, p.y + 9)
	]), C_WHITE)
	draw_rect(Rect2(p.x - 1, p.y - 19, 2, 18), C_BLACK)
	if crack > 0.0:
		var jump := sin(float(index) * 7.0 + all_clear_t * 18.0) * 2.0
		draw_line(p + Vector2(-2, 4), p + Vector2(8 + jump, 17), C_RED, 1.0)
		draw_line(p + Vector2(2, 4), p + Vector2(-10 - jump, 19), C_WHITE, 1.0)
		for shard in 3:
			var a := float(index * 5 + shard) * 1.7 + all_clear_t * 0.6
			var q := p + Vector2.from_angle(a) * (10.0 + crack * 18.0)
			draw_rect(Rect2(q, Vector2(3, 2)), C_RED if shard % 2 == 0 else C_WHITE)


func _draw_ending_title(t: float) -> void:
	var reveal := clampf((t - 0.48) / 0.52, 0.0, 1.0)
	if reveal <= 0.0:
		return
	var slam := (1.0 - ease(reveal, 0.3)) * -34.0
	var glitch := t < 1.22 or fmod(t, 3.15) < 0.085
	var offset := Vector2(sin(t * 91.0) * (2.0 if glitch else 0.25), slam)
	if glitch:
		offset.x += -3.0 if int(t * 58.0) % 2 == 0 else 3.0
	var tab := Rect2(42 + offset.x, 82 + offset.y, 72, 18)
	draw_rect(tab, C_RED)
	draw_rect(Rect2(tab.position + Vector2(3, 3), tab.size), Color(1, 1, 1, 0.14))
	PF.draw(self, Vector2(tab.position.x + 8, tab.position.y + 4), "I AM", 2, C_BLACK)
	if glitch:
		for i in 4:
			var gx := 45.0 + float((int(t * 61.0) + i * 73) % 214)
			draw_rect(Rect2(gx + offset.x, 96 + offset.y + i * 15, 28.0 + i * 23, 1), Color(C_RED.r, C_RED.g, C_RED.b, 0.78))
	_draw_ending_word(Vector2(45 + offset.x, 104 + offset.y), "HELL", 8, glitch)
	PF.draw(self, Vector2(49 + offset.x, 168 + offset.y), "THE END", 2, C_EMBER, 0, C_RED)
	if t > 1.55:
		var fade := clampf((t - 1.55) / 0.5, 0.0, 1.0)
		PF.draw(self, Vector2(88, 194), "THE HELL WAS YOU", 1, Color(C_WHITE.r, C_WHITE.g, C_WHITE.b, fade), 0)


func _draw_ending_word(pos: Vector2, text: String, scale: int, glitch: bool) -> void:
	if glitch:
		PF.draw(self, pos + Vector2(-4, 0), text, scale, Color(C_RED.r, C_RED.g, C_RED.b, 0.68))
		PF.draw(self, pos + Vector2(4, 0), text, scale, Color(1, 1, 1, 0.24))
	for off in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
		PF.draw(self, pos + off, text, scale, C_BLACK)
	PF.draw(self, pos + Vector2(7, 7), text, scale, C_RED)
	PF.draw(self, pos, text, scale, C_WHITE)


func _draw_ending_figure(t: float) -> void:
	var reveal := clampf((t - 1.15) / 0.6, 0.0, 1.0)
	if reveal <= 0.0:
		return
	var door := Rect2(48, 184, 32, 37)
	draw_rect(door, C_BLACK)
	draw_rect(door, Color(1, 1, 1, 0.7 * reveal), false, 1.0)
	draw_rect(door.grow(-4.0), Color(C_RED.r, C_RED.g, C_RED.b, 0.32 * reveal))
	var x := 16.0 + ease(reveal, 1.8) * 14.0
	var y := 205.0
	draw_circle(Vector2(x + 4, y - 12), 4.2, C_WHITE)
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - 1, y - 7), Vector2(x + 8, y - 7),
		Vector2(x + 10, y + 8), Vector2(x + 7, y + 14),
		Vector2(x + 2, y + 13), Vector2(x - 3, y + 6),
	]), C_WHITE)
	draw_line(Vector2(x + 1, y + 13), Vector2(x - 3, y + 21), C_WHITE, 2.0)
	draw_line(Vector2(x + 7, y + 13), Vector2(x + 12, y + 21), C_WHITE, 2.0)
	draw_line(Vector2(x, y - 9), Vector2(x - 16, y - 12 + sin(t * 9.0) * 2.0), C_RED, 2.0)
	draw_line(Vector2(x + 1, y - 5), Vector2(x - 10, y + 1 + sin(t * 7.0) * 2.0), Color(C_EMBER.r, C_EMBER.g, C_EMBER.b, 0.7), 1.0)


func _draw_ending_record() -> void:
	var panel := Rect2(304, 71, 154, 132)
	_panel(panel, 0.94)
	PF.draw(self, Vector2(314, 78), "DESCENT RECORD", 1, C_WHITE, 0, C_RED)
	PF.draw(self, Vector2(314, 95), "%d/%d ROOMS" % [game.level_count, game.level_count], 1, C_EMBER, 0)
	var rows := [
		["TIME", _fmt_time(game.get_run_time())],
		["DEATHS", str(game.deaths)],
		["KILLS", str(game.get_run_total_kills())],
		["PERFECT", str(game.get_run_perfects())],
		["BEST COMBO", str(game.get_run_best_combo())],
		["SCORE", str(game.get_total_score())],
	]
	for i in rows.size():
		var y := 112.0 + i * 14.0
		PF.draw(self, Vector2(314, y), rows[i][0], 1, C_MID, 0)
		PF.draw(self, Vector2(448, y), rows[i][1], 1, C_WHITE, 2)


func _draw_ending_footer(t: float) -> void:
	draw_rect(Rect2(0, 225, W, 45), Color(0, 0, 0, 0.94))
	draw_rect(Rect2(0, 225, W, 2), C_RED)
	PF.draw(self, Vector2(W / 2.0, 230), "GAME OFF 2026 ENTRY", 1, C_MID, 1)
	var blink := 0.62 + 0.38 * sin(t * 5.4)
	PF.draw(self, Vector2(W / 2.0, 242), "PRESS R TO DESCEND AGAIN", 1, Color(C_WHITE.r, C_WHITE.g, C_WHITE.b, blink), 1, Color(C_RED.r, C_RED.g, C_RED.b, blink))
	PF.draw(self, Vector2(14, 258), "SOUND: SUBSPACEAUDIO / JUHANI JUNKALA - CC0", 1, C_DARK, 0)
	if author_font != null:
		var credit_panel := Rect2(W - 158.0, 247.0, 144.0, 19.0)
		draw_rect(credit_panel, C_BLACK)
		draw_rect(credit_panel, C_RED, false, 1.0)
		draw_rect(Rect2(credit_panel.position + Vector2(2, 2), credit_panel.size - Vector2(4, 4)), Color(C_RED.r, C_RED.g, C_RED.b, 0.24))
		var pos := Vector2(credit_panel.position.x + 6.0, credit_panel.position.y + 14.0)
		draw_string_outline(author_font, pos, AUTHOR_CREDIT, HORIZONTAL_ALIGNMENT_CENTER, credit_panel.size.x - 12.0, 11, 1, C_BLACK)
		draw_string(author_font, pos, AUTHOR_CREDIT, HORIZONTAL_ALIGNMENT_CENTER, credit_panel.size.x - 12.0, 11, C_WHITE)


func _draw_boss_health(boss) -> void:
	var panel := Rect2(148, 16, 184, 15)
	_panel(panel, 0.92)
	PF.draw(self, Vector2(154, 19), "THE THIRD NAIL", 1, C_WHITE, 1, C_BLACK)
	var flash := int(boss.health_flash * 18.0) % 2 == 0
	for i in boss.max_health:
		var r := Rect2(250 + i * 24, 20, 19, 6)
		draw_rect(r, C_BLACK)
		draw_rect(r, C_MID, false, 1.0)
		if i < boss.health:
			draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(17, 4)), C_WHITE if flash else C_RED)
			draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(15, 1)), C_EMBER)


func _draw_wheel_hint() -> void:
	var panel := Rect2(54, 205, 372, 36)
	draw_rect(panel, Color(0, 0, 0, 0.9))
	draw_rect(panel, C_WHITE, false, 1.0)
	draw_rect(Rect2(panel.position + Vector2(2, 2), Vector2(3, panel.size.y - 4)), C_RED)
	PF.draw(self, Vector2(W / 2.0, 211), "ARMORED CHARGER: NO SHIFT", 1, C_EMBER, 1, C_BLACK)
	PF.draw(self, Vector2(W / 2.0, 225), "LURE IT INTO THE WHEEL TO PULL THE BONE NAIL", 1, C_WHITE, 1, C_BLACK)


## 临时选关面板（main.gd 的 DEBUG_LEVEL_SELECT 关掉后就不会出现）
func _draw_level_select() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.75))
	_panel(Rect2(64, 22, 352, 226))
	PF.draw(self, Vector2(W / 2.0, 30), "LEVEL SELECT", 2, C_WHITE, 1, C_RED)
	var names: Array = game.level_names()
	for i in names.size():
		var r: Rect2 = game.select_item_rect(i)
		var sel: bool = i == game.select_idx
		if sel:
			draw_rect(r, C_RED)
		var cur := "> " if i == game.level_no - 1 else "  "
		PF.draw(self, r.position + Vector2(4, 4), "%s%2d  %s" % [cur, i + 1, names[i]], 1, C_WHITE if sel else C_MID)
	PF.draw(self, Vector2(W / 2.0, 236), "W/S A/D MOVE   ENTER / CLICK GO   TAB CLOSE", 1, C_MID, 1)
