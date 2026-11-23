extends Entity
## 射手：和主角保持水平距离，前摇时显示瞄准虚线，然后沿锁定方向开一枪。
## 子弹不受重力，会打中任何东西——包括其他敌人。

enum State { MOVE, WINDUP, COOLDOWN }

const SPEED := 30.0
const PREFERRED_DIST := 120.0
const WINDUP_TIME := 0.6
const COOLDOWN_TIME := 1.5
const BULLET_SPEED := 170.0

var state: int = State.MOVE
var timer: float = 0.0
var aim_dir := Vector2.RIGHT
var aggro_range: float = 0.0
var requires_los: bool = false
var require_on_screen: bool = false


func _ready() -> void:
	setup_body(Vector2(10, 12), 2, 1)
	add_to_group("enemy")
	timer = randf_range(0.8, 1.6)


func _physics_process(delta: float) -> void:
	if not alive or game == null or game.game_over:
		return
	var to_p: Vector2 = game.player.position - position
	var can_engage := _can_engage(to_p)
	apply_gravity(delta)
	match state:
		State.MOVE:
			if can_engage:
				var dx := absf(to_p.x)
				var move := 0.0
				if dx > PREFERRED_DIST + 20.0:
					move = signf(to_p.x)
				elif dx < PREFERRED_DIST - 20.0:
					move = -signf(to_p.x)
				if is_on_floor() and not game.safe_step(self, move):
					move = 0.0
				velocity.x = move * SPEED
				if absf(to_p.x) > 1.0:
					facing = signf(to_p.x)
				timer -= delta
				if timer <= 0.0:
					state = State.WINDUP
					game.play_sfx("windup", 0.1)
					timer = WINDUP_TIME
					if to_p.length() > 0.01:
						aim_dir = to_p.normalized()
			else:
				velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
				timer = maxf(timer, 0.2)
		State.WINDUP:
			velocity.x = 0.0
			if not can_engage:
				state = State.MOVE
				timer = 0.35
			else:
				timer -= delta
				if timer <= 0.0:
					game.spawn_bullet(position + aim_dir * 9.0, aim_dir * BULLET_SPEED, self)
					state = State.COOLDOWN
					timer = COOLDOWN_TIME
		State.COOLDOWN:
			velocity.x = 0.0
			timer -= delta
			if timer <= 0.0:
				state = State.MOVE
				timer = randf_range(0.3, 0.9)
	move_and_slide()


func _can_engage(to_p: Vector2) -> bool:
	if aggro_range > 0.0 and to_p.length() > aggro_range:
		return false
	if requires_los and not game.has_line_of_sight(position, game.player.position):
		return false
	if require_on_screen and not game.is_world_on_screen(position, 10.0):
		return false
	return true


func _draw_body() -> void:
	# 造型：戴尖兜帽的独眼枪手。大眼珠跟着你转，蓄力时瞳孔缩成一个点。
	# 基类在重力反转时会上下翻转画面，瞄准方向要翻回来
	var ad := Vector2(aim_dir.x, aim_dir.y * gdir)
	var white := Color.WHITE
	var black := Color.BLACK
	var look := ad if state == State.WINDUP else look_vec()
	var just_fired := state == State.COOLDOWN and timer > COOLDOWN_TIME - 0.15
	var rec := -ad * 2.0 if just_fired else Vector2.ZERO   # 开枪后坐力
	var filled := true
	if state == State.WINDUP:
		filled = int(timer * 20.0) % 2 == 0
		draw_dashed_line(ad * 10.0, ad * 320.0, Color(0.66, 0.08, 0.1), 1.0, 4.0)

	# 腿
	var step := 0.0
	if is_on_floor() and absf(velocity.x) > 3.0:
		step = sin(anim_t * 14.0)
	draw_rect(Rect2(-4, 3, 2, 3.0 - maxf(step, 0.0)), white)
	draw_rect(Rect2(2, 3, 2, 3.0 + minf(step, 0.0)), white)

	# 身体 + 兜帽
	var body := Rect2(rec + Vector2(-5, -6), Vector2(10, 10))
	var hood := PackedVector2Array([rec + Vector2(-5, -6), rec + Vector2(0, -11), rec + Vector2(5, -6)])
	draw_rect(body.grow(1.0), black)
	if filled:
		draw_rect(body, white)
		draw_colored_polygon(hood, white)
	else:
		draw_rect(body, white, false, 1.0)
		draw_polyline(PackedVector2Array([hood[0], hood[1], hood[2]]), white, 1.0)

	# 独眼
	var eye := rec + Vector2(0, -2)
	if filled:
		draw_circle(eye, 3.0, black)
	else:
		draw_arc(eye, 3.0, 0.0, TAU, 12, white, 1.0)
	var pupil := 0.7 if state == State.WINDUP else 1.3
	draw_circle(eye + look * 1.4, pupil, white)

	# 枪管指向瞄准方向
	draw_line(rec + ad * 3.0, rec + ad * 10.0, black, 4.0)
	draw_line(rec + ad * 3.0, rec + ad * 10.0, white, 2.0)

	# 枪口火光
	if just_fired:
		var tip := rec + ad * 12.0
		for i in 4:
			var dv := Vector2.from_angle(ad.angle() + (i - 1.5) * 0.6)
			draw_line(tip, tip + dv * 3.5, white, 1.0)
