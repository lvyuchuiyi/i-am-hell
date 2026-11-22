extends Node2D
## 地形绘制（GBA 风格）：带高光和阴影的砖块、钢梁平台、尖上带血的地刺、被尸体堵住的刺。
## 地形不动，所以只在关卡读入和地刺被堵时重画，不是每帧都画。
##
## 颜色只用 4 个灰阶 + 红色，最后由调色板 shader 统一换成游戏的调色板。

const T := 16
const C_BLACK := Color(0, 0, 0)
const C_DARK := Color(0.33, 0.33, 0.33)
const C_MID := Color(0.66, 0.66, 0.66)
const C_LIGHT := Color(1, 1, 1)
const C_BLOOD := Color(0.85, 0.1, 0.12)
const C_BLOOD_DARK := Color(0.45, 0.05, 0.06)

var game = null


func _hash(c: int, r: int) -> int:
	return absi((c * 73856093) ^ (r * 19349663)) % 97


func _draw() -> void:
	if game == null:
		return
	for r in game.rows:
		for c in game.cols:
			if game.is_solid_tile(c, r):
				_draw_solid(c, r)
	for p in game.platforms:
		_draw_platform(p)
	for s in game.spikes_up:
		_draw_spike(s, true)
	for s in game.spikes_down:
		_draw_spike(s, false)
	for cg in game.clogged:
		_draw_clogged(cg["rect"], cg["up"])


func _draw_solid(c: int, r: int) -> void:
	var x := float(c * T)
	var y := float(r * T)
	var open_up: bool = not game.is_solid_tile(c, r - 1)
	var open_down: bool = not game.is_solid_tile(c, r + 1)
	var open_left: bool = not game.is_solid_tile(c - 1, r)
	var open_right: bool = not game.is_solid_tile(c + 1, r)
	var h := _hash(c, r)

	if not (open_up or open_down or open_left or open_right):
		# 墙体内部：暗色，零星几个碎石点
		draw_rect(Rect2(x, y, T, T), C_DARK)
		if h % 5 == 0:
			draw_rect(Rect2(x + float(h % 12) + 2.0, y + float((h / 5) % 12) + 2.0, 2, 1), C_BLACK)
		if h % 7 == 1:
			draw_rect(Rect2(x + float((h * 3) % 13) + 1.0, y + float((h / 7) % 13) + 1.0, 1, 1), C_MID)
		return

	# 外露的砖块：中灰底 + 错缝砖纹
	draw_rect(Rect2(x, y, T, T), C_MID)
	for br in 4:
		var by := y + br * 4
		draw_rect(Rect2(x, by + 3, T, 1), C_DARK)
		var off := 0 if (br + r) % 2 == 0 else 4
		for k in 2:
			var bx := x + off + k * 8
			draw_rect(Rect2(bx, by, 1, 3), C_DARK)
	# 裂缝
	if h % 6 == 0:
		draw_rect(Rect2(x + 5, y + 5, 1, 2), C_BLACK)
		draw_rect(Rect2(x + 6, y + 7, 1, 2), C_BLACK)
		draw_rect(Rect2(x + 7, y + 9, 2, 1), C_BLACK)
	# 高光和阴影：光从左上方来
	if open_up:
		draw_rect(Rect2(x, y, T, 2), C_LIGHT)
		draw_rect(Rect2(x, y + 2, T, 1), C_DARK)
		# 地面上偶尔有一点骨头碎屑
		if h % 9 == 0:
			draw_rect(Rect2(x + float(h % 10) + 2.0, y - 1, 3, 1), C_LIGHT)
	if open_left:
		draw_rect(Rect2(x, y, 1, T), C_LIGHT)
	if open_right:
		draw_rect(Rect2(x + T - 1, y, 1, T), C_DARK)
	if open_down:
		draw_rect(Rect2(x, y + T - 1, T, 1), C_BLACK)
		draw_rect(Rect2(x, y + T - 2, T, 1), C_DARK)


func _draw_platform(p: Rect2) -> void:
	# 钢梁：亮顶边 + 中灰梁身 + 斜撑 + 暗底边
	draw_rect(Rect2(p.position, Vector2(p.size.x, 1)), C_LIGHT)
	draw_rect(Rect2(p.position + Vector2(0, 1), Vector2(p.size.x, 4)), C_MID)
	draw_rect(Rect2(p.position + Vector2(0, 5), Vector2(p.size.x, 1)), C_DARK)
	var x := p.position.x
	while x < p.end.x - 1.0:
		draw_rect(Rect2(x, p.position.y + 1, 1, 4), C_DARK)
		for k in 4:
			if x + 1.0 + k < p.end.x:
				draw_rect(Rect2(x + 1.0 + k, p.position.y + 1.0 + k, 1, 1), C_DARK)
		x += 8.0
	# 两端的铆钉
	draw_rect(Rect2(p.position.x + 1, p.position.y + 2, 1, 1), C_LIGHT)
	draw_rect(Rect2(p.end.x - 2, p.position.y + 2, 1, 1), C_LIGHT)


func _draw_spike(s: Rect2, up: bool) -> void:
	# 每格两根刺：左半边受光、右半边背光，刺尖带血
	for k in 2:
		var sx := s.position.x + k * 8.0
		var base_y := s.end.y if up else s.position.y
		var tip_y := s.position.y if up else s.end.y
		draw_colored_polygon(PackedVector2Array([
			Vector2(sx, base_y), Vector2(sx + 4.0, tip_y), Vector2(sx + 4.0, base_y)]), C_LIGHT)
		draw_colored_polygon(PackedVector2Array([
			Vector2(sx + 4.0, tip_y), Vector2(sx + 8.0, base_y), Vector2(sx + 4.0, base_y)]), C_MID)
		var ty := tip_y if up else tip_y - 2.0
		draw_rect(Rect2(sx + 3.0, ty, 2, 2), C_BLOOD)


func _draw_clogged(cr: Rect2, up: bool) -> void:
	# 断掉的刺桩 + 一坨压扁的残骸 + 血
	var base_y := cr.end.y if up else cr.position.y
	var d := -1.0 if up else 1.0
	for k in 2:
		var bx := cr.position.x + 2.0 + k * 8.0
		draw_rect(Rect2(bx, base_y + (d * 2.0 if up else 0.0), 3, 2), C_MID)
	var lump_y := base_y - 5.0 if up else base_y + 1.0
	draw_rect(Rect2(cr.position.x + 1.0, lump_y, 14, 4), C_LIGHT)
	draw_rect(Rect2(cr.position.x + 1.0, lump_y + (3.0 if up else 0.0), 14, 1), C_DARK)
	draw_rect(Rect2(cr.position.x + 4.0, lump_y + 1.0, 2, 2), C_BLACK)
	draw_rect(Rect2(cr.position.x + 9.0, lump_y + 1.0, 2, 1), C_BLACK)
	# 血迹往两边溅
	draw_rect(Rect2(cr.position.x - 2.0, base_y + (-1.0 if up else 0.0), 4, 1), C_BLOOD)
	draw_rect(Rect2(cr.position.x + 13.0, base_y + (-1.0 if up else 0.0), 5, 1), C_BLOOD_DARK)
	draw_rect(Rect2(cr.position.x + 6.0, lump_y - (1.0 if up else -4.0), 3, 1), C_BLOOD)
