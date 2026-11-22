extends Entity
## 主角：没有攻击能力，只会跑、跳、换位。
## 带土狼时间（离开平台后短时间内仍可起跳）、跳跃缓冲、松开跳键截断跳跃高度。
##
## 外观：Q 版地狱小鬼。黑色大头 + 白描边 + 弯角 + 红色怒眼 + 白色獠牙，
## 破斗篷（下摆会翻飞）+ 两条小短腿（跑步循环）+ 会飘的红围巾 + 身上不断冒火星。
## 跳跃拉长、落地压扁、跑步颠簸、落地扬尘、眨眼。

const SPEED := 115.0
const ACCEL := 1100.0
const AIR_ACCEL := 750.0
const JUMP_VELOCITY := -340.0   # 约 4 格高
const JUMP_CUT_GRAVITY := 1.6   # 松开跳键时额外重力倍数
const COYOTE_TIME := 0.08
const JUMP_BUFFER := 0.1

const SCARF_POINTS := 6
const SCARF_SEG := 2.2

var coyote: float = 0.0
var jump_buffer: float = 0.0
var jump_was_held: bool = false
var jump_count: int = 0       # 每起跳一次加 1（倒影靠它知道主角跳了）

# 外观动画
var scarf: Array = []         # 世界坐标的围巾节点
var run_phase: float = 0.0
var anim_clock: float = 0.0
var ember_t: float = 0.0
var blink_t: float = 2.0
var air_fall_speed: float = 0.0


func _ready() -> void:
	setup_body(Vector2(8, 12), 2, 1)
	swappable = false
	_reset_scarf()


func _jump_held() -> bool:
	return (Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_SPACE)
		or Input.is_key_pressed(KEY_UP))


func _physics_process(delta: float) -> void:
	invuln = maxf(invuln - delta, 0.0)
	_update_looks(delta)
	if not alive or game == null or game.game_over:
		return

	var dir := 0.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir += 1.0
	if dir != 0.0:
		facing = dir
	var accel := ACCEL if is_on_floor() else AIR_ACCEL
	velocity.x = move_toward(velocity.x, dir * SPEED, accel * delta)

	# 跳跃：按下的那一帧写入缓冲
	var held := _jump_held()
	if held and not jump_was_held:
		jump_buffer = JUMP_BUFFER
	jump_was_held = held
	jump_buffer -= delta
	if is_on_floor():
		coyote = COYOTE_TIME
	else:
		coyote -= delta
	if jump_buffer > 0.0 and coyote > 0.0:
		velocity.y = JUMP_VELOCITY * gdir
		jump_count += 1
		game.play_sfx("jump")
		jump_buffer = 0.0
		coyote = 0.0
		vis_scale = Vector2(0.7, 1.35)   # 起跳拉长

	apply_gravity(delta)
	if velocity.y * gdir < 0.0 and not held:
		velocity.y += GRAVITY * gdir * JUMP_CUT_GRAVITY * delta

	var was_on_floor := is_on_floor()
	if not was_on_floor:
		air_fall_speed = maxf(air_fall_speed, velocity.y * gdir)
	move_and_slide()
	if is_on_floor() and not was_on_floor:
		# 落地压扁 + 扬尘，摔得越狠压得越扁
		var k := clampf(air_fall_speed / 400.0, 0.3, 1.0)
		vis_scale = Vector2(1.0 + 0.45 * k, 1.0 - 0.4 * k)
		game.spawn_dust(position + Vector2(0, half.y * gdir), int(4 + 6 * k))
		if k > 0.45:
			game.play_sfx("land")
		air_fall_speed = 0.0


# ---------------------------------------------------------------- 外观

const C_RED := Color(0.66, 0.08, 0.1)
const C_EMBER := Color(1.0, 0.35, 0.2)


func _reset_scarf() -> void:
	scarf.clear()
	for i in SCARF_POINTS:
		scarf.append(position + Vector2(-facing * SCARF_SEG * i, 0.0))


func _update_looks(delta: float) -> void:
	anim_clock += delta
	blink_t -= delta
	if blink_t < -0.12:
		blink_t = randf_range(1.5, 3.5)
	if is_on_floor() and absf(velocity.x) > 10.0:
		run_phase += delta * 18.0
	else:
		run_phase = 0.0

	# 围巾：系在脖子上，后面每节跟着前一节，往身后飘、顺着重力垂，跑得越快飘得越平
	if scarf.is_empty():
		_reset_scarf()
	var root := position + Vector2(-facing * 2.0, 0.5 * gdir)
	if (scarf[0] as Vector2).distance_to(root) > 40.0:
		_reset_scarf()   # 换位瞬移后直接重置，不拖一条横跨全屏的线
	scarf[0] = root
	var speed_k := clampf(absf(velocity.x) / SPEED, 0.0, 1.0)
	for i in range(1, scarf.size()):
		var prev: Vector2 = scarf[i - 1]
		var cur: Vector2 = scarf[i]
		var flap := sin(anim_clock * 14.0 - i * 0.9) * (0.25 + 0.5 * speed_k)
		cur += Vector2(-facing * (0.5 + speed_k * 0.6), (0.45 * (1.0 - speed_k * 0.7) + flap) * gdir)
		var d := cur - prev
		if d.length() > SCARF_SEG:
			cur = prev + d.normalized() * SCARF_SEG
		scarf[i] = cur

	# 身上不断冒火星（动得越快冒得越多）
	if alive and game != null and not game.game_over:
		ember_t -= delta
		if ember_t <= 0.0:
			ember_t = 0.35 - 0.25 * speed_k
			game.spawn_ember(position + Vector2(randf_range(-4.0, 4.0), -7.0 * gdir))


func _draw_body() -> void:
	var a := 1.0
	if invuln > 0.0:
		a = 0.55
	var white := Color(1, 1, 1, a)
	var black := Color(0, 0, 0, a)
	var red := Color(C_RED.r, C_RED.g, C_RED.b, a)
	var ember := Color(C_EMBER.r, C_EMBER.g, C_EMBER.b, a)
	var f := facing

	if not alive:
		# 尸体：一摊破斗篷 + 掉在地上的围巾 + 打叉的眼睛
		draw_colored_polygon(PackedVector2Array([Vector2(-7, 6), Vector2(-4, 2), Vector2(4, 2), Vector2(7, 6)]), white)
		draw_colored_polygon(PackedVector2Array([Vector2(-5, 5), Vector2(-3, 3), Vector2(3, 3), Vector2(5, 5)]), black)
		draw_rect(Rect2(2, 5, 8, 1), red)
		draw_rect(Rect2(-2, 3, 1, 1), ember)
		draw_rect(Rect2(1, 3, 1, 1), ember)
		return

	var bob := 0.0
	if run_phase > 0.0:
		bob = -absf(sin(run_phase)) * 1.0
	var rising := not is_on_floor() and velocity.y * gdir < -20.0
	var falling := not is_on_floor() and velocity.y * gdir > 20.0

	# ---- 围巾（在身体后面画）：世界坐标转本地坐标，抵消基类的上下翻转
	var pts := PackedVector2Array()
	for p in scarf:
		var lp: Vector2 = (p as Vector2) - position
		pts.append(Vector2(lp.x, lp.y * gdir))
	if pts.size() >= 2:
		draw_polyline(pts, red, 2.0)
		# 末端分叉成两条破布
		var tip: Vector2 = pts[pts.size() - 1]
		var back: Vector2 = pts[pts.size() - 2]
		var dir := (tip - back).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2(-f, 0)
		var side := Vector2(-dir.y, dir.x)
		draw_line(tip, tip + dir * 2.5 + side * 1.5, red, 1.0)
		draw_line(tip, tip + dir * 2.0 - side * 1.5, red, 1.0)

	# ---- 腿：跑步时交替迈步；上升时收腿，下落时腿垂下来
	var l_len := 2.0
	var r_len := 2.0
	var l_x := -1.5
	var r_x := 1.5
	if run_phase > 0.0:
		var s := sin(run_phase)
		l_len = 2.0 + maxf(s, 0.0)
		r_len = 2.0 + maxf(-s, 0.0)
		l_x += s * 1.0
		r_x -= s * 1.0
	elif rising:
		l_len = 1.0
		r_len = 1.0
	elif falling:
		l_len = 3.0
		r_len = 3.0
		l_x -= 0.5
		r_x += 0.5
	draw_rect(Rect2(l_x - 0.5, 4.0 + bob, 1, l_len), white)
	draw_rect(Rect2(r_x - 0.5, 4.0 + bob, 1, r_len), white)

	# ---- 破斗篷：梯形，下摆是会翻飞的锯齿
	var flutter := sin(anim_clock * 12.0) * (0.5 + 0.8 * absf(velocity.x) / SPEED)
	var hem := PackedVector2Array()
	hem.append(Vector2(-2.5, 0.0 + bob))
	hem.append(Vector2(2.5, 0.0 + bob))
	for i in 6:
		var hx := 4.5 - i * 1.8
		var hy := 4.5 + bob + (1.0 if i % 2 == 0 else 0.0) + (flutter if i % 2 == 0 else -flutter * 0.5)
		hem.append(Vector2(hx - f * 0.6 * absf(velocity.x) / SPEED, hy))
	var outline := PackedVector2Array()
	for p in hem:
		outline.append(p * Vector2(1.25, 1.0) + Vector2(0, 0.5))
	draw_colored_polygon(outline, white)
	draw_colored_polygon(hem, black)

	# ---- 围巾结（脖子上）
	draw_rect(Rect2(-3, -0.5 + bob, 6, 2), red)

	# ---- 大头：白描边黑脑袋
	var hc := Vector2(0, -4.5 + bob)
	draw_circle(hc, 5.5, white)
	draw_circle(hc, 4.5, black)

	# ---- 弯角
	draw_colored_polygon(PackedVector2Array([hc + Vector2(-3, -3.5), hc + Vector2(-6.5, -7.5), hc + Vector2(-1.5, -4.5)]), white)
	draw_colored_polygon(PackedVector2Array([hc + Vector2(3, -3.5), hc + Vector2(6.5, -7.5), hc + Vector2(1.5, -4.5)]), white)

	# ---- 红色怒眼（朝面向的方向偏一格，偶尔眨眼），内侧切掉一角显得凶
	var ex := hc.x + f * 1.0
	var ey := hc.y - 1.0
	if blink_t > 0.0:
		draw_rect(Rect2(ex - 3.0, ey, 2, 2), ember)
		draw_rect(Rect2(ex + 1.0, ey, 2, 2), ember)
		draw_rect(Rect2(ex - 2.0, ey, 1, 1), black)
		draw_rect(Rect2(ex + 1.0, ey, 1, 1), black)
	else:
		draw_rect(Rect2(ex - 3.0, ey + 1.0, 2, 1), ember)
		draw_rect(Rect2(ex + 1.0, ey + 1.0, 2, 1), ember)

	# ---- 白色锯齿獠牙
	var my := hc.y + 2.0
	draw_rect(Rect2(ex - 2.0, my, 5, 1), white)
	draw_rect(Rect2(ex - 2.0, my + 1.0, 1, 1), white)
	draw_rect(Rect2(ex, my + 1.0, 1, 1), white)
	draw_rect(Rect2(ex + 2.0, my + 1.0, 1, 1), white)
