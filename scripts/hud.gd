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

var game = null
var intro_t: float = 0.0   # 关卡开头的计时（横幅滑入滑出）


func _process(delta: float) -> void:
	intro_t += delta
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
	var enemies: int = game.count_enemies()
	if enemies > 0 and not game.always_open:
		PF.draw(self, Vector2(290, 3), "ENEMIES %d" % enemies, 1, C_WHITE, 1)
	else:
		var blink := int(intro_t * 4.0) % 2 == 0
		PF.draw(self, Vector2(290, 3), "EXIT OPEN", 1, C_EMBER if blink else C_WHITE, 1)
	PF.draw(self, Vector2(474, 3), "%s  DEATHS %d" % [_fmt_time(game.level_time), game.deaths], 1, C_WHITE, 2)

	# 连杀
	if game.combo > 1:
		PF.draw(self, Vector2(W / 2.0, 18), "%d COMBO" % game.combo, 1, C_WHITE, 1, C_RED)

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

	# ---------------- 通关
	if game.all_clear:
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.85))
		_panel(Rect2(110, 70, 260, 130))
		PF.draw(self, Vector2(W / 2.0, 84), "I AM HELL", 4, C_WHITE, 1, C_RED)
		PF.draw(self, Vector2(W / 2.0, 124), "ALL ROOMS CLEARED", 1, C_EMBER, 1)
		PF.draw(self, Vector2(W / 2.0, 142), "TIME %s" % _fmt_time(game.get_run_time()), 1, C_WHITE, 1)
		PF.draw(self, Vector2(W / 2.0, 154), "DEATHS %d   SCORE %d" % [game.deaths, game.get_total_score()], 1, C_WHITE, 1)
		if int(intro_t * 2.0) % 2 == 0:
			PF.draw(self, Vector2(W / 2.0, 180), "PRESS R TO PLAY AGAIN", 1, C_MID, 1)
		PF.draw(self, Vector2(W / 2.0, 214), "SOUND EFFECTS BY SUBSPACEAUDIO (JUHANI JUNKALA) - CC0", 1, C_DARK, 1)
		return

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
