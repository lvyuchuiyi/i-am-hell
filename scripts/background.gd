extends Node2D
## 背景（GBA 风格的多层视差）：远处的石笋剪影、垂下来的铁链、底部的岩浆红光、往上飘的火星。
## 放在 CanvasLayer(-1) 里，用屏幕坐标画；跟着镜头轻微反向移动，做出视差。
## 颜色故意用很暗的灰和红，调色板 shader 会把它们抖动成网点，营造 GBA 的层次感。

const W := 480.0
const H := 270.0
const CENTER := Vector2(240, 137)

var game = null
var t: float = 0.0
var far_pts := PackedVector2Array()
var near_pts := PackedVector2Array()


func _ready() -> void:
	# 用固定种子生成两层山形，每次进游戏都一样
	var rng := RandomNumberGenerator.new()
	rng.seed = 666
	far_pts = _ridge(rng, 150.0, 70.0, 22.0, 40.0)
	near_pts = _ridge(rng, 205.0, 45.0, 34.0, 60.0)


## 生成一条锯齿状的山脊（从左到右），最后闭合到画面底部
func _ridge(rng: RandomNumberGenerator, base_y: float, amp: float, step_min: float, step_max: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var x := -40.0
	pts.append(Vector2(x, H + 20.0))
	while x < W + 40.0:
		var peak := rng.randf() < 0.35
		var y := base_y - rng.randf_range(0.0, amp) * (1.6 if peak else 0.6)
		pts.append(Vector2(x, y))
		x += rng.randf_range(step_min, step_max)
	pts.append(Vector2(W + 40.0, H + 20.0))
	return pts


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var cam_off := Vector2.ZERO
	if game != null and game.camera != null:
		cam_off = (game.camera.position - CENTER) + game.camera.offset

	# 岩浆红光：越往下越亮（调色板会把它抖动成一层层红色网点）
	for i in 10:
		var y := H - 70.0 + i * 7.0
		var a := 0.06 + i * 0.045
		draw_rect(Rect2(0, y, W, 7), Color(0.55, 0.06, 0.06, a))

	# 远山：几乎和背景一样黑，只露一点轮廓
	_draw_layer(far_pts, cam_off * -0.08, Color(0.13, 0.13, 0.13))
	# 近山：深灰
	_draw_layer(near_pts, cam_off * -0.18, Color(0.24, 0.24, 0.24))

	# 垂下来的铁链，轻轻摇晃
	var chain_off := cam_off * -0.25
	for k in 5:
		var cx := 40.0 + k * 100.0 + chain_off.x
		var length := 50.0 + float((k * 37) % 60)
		var sway := sin(t * 0.8 + k) * 3.0
		var y := 0.0
		while y < length:
			var px := cx + sway * (y / length)
			var link_w := 3.0 if int(y / 4.0) % 2 == 0 else 1.0
			draw_rect(Rect2(px - link_w * 0.5, y + chain_off.y, link_w, 3), Color(0.3, 0.3, 0.3))
			y += 4.0
		# 链子末端挂着的钩子
		var hx := cx + sway
		draw_rect(Rect2(hx - 2.0, length + chain_off.y, 4, 1), Color(0.3, 0.3, 0.3))
		draw_rect(Rect2(hx + 1.0, length + 1.0 + chain_off.y, 1, 3), Color(0.3, 0.3, 0.3))

	# 往上飘的火星
	for i in 36:
		var speed := 10.0 + float((i * 13) % 17)
		var y := H - fmod(t * speed + float(i * 41), H + 20.0)
		var x := fmod(float(i * 53) + sin(t * 0.7 + i) * 8.0, W)
		var life := clampf((y - 40.0) / 200.0, 0.0, 1.0)
		var c := Color(1.0, 0.35, 0.2, life) if i % 3 != 0 else Color(0.7, 0.12, 0.1, life)
		draw_rect(Rect2(x, y, 1, 1 + (i % 2)), c)


func _draw_layer(pts: PackedVector2Array, off: Vector2, color: Color) -> void:
	var moved := PackedVector2Array()
	for p in pts:
		moved.append(p + off)
	draw_colored_polygon(moved, color)
