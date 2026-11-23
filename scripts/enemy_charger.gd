extends Entity
## 冲锋者：在同一高度靠近主角后原地抖动蓄力，然后锁定方向水平冲刺。
## 冲刺撞到谁就撞死谁（主角或其他敌人），撞墙或箱子会停下。

enum State { CHASE, WINDUP, DASH, RECOVER, PINNED }

const WALK_SPEED := 40.0
const DASH_SPEED := 280.0
const TRIGGER_X := 150.0
const TRIGGER_Y := 24.0
const WINDUP_TIME := 0.5
const DASH_TIME := 0.5
const RECOVER_TIME := 0.7

var state: int = State.CHASE
var timer: float = 0.0
var jitter := Vector2.ZERO
var pinned_to = null
var pinned_offset := Vector2.ZERO
var execution_variant: bool = false


func _ready() -> void:
	setup_body(Vector2(15, 12) if execution_variant else Vector2(12, 10), 2, 1)
	add_to_group("enemy")
	if execution_variant:
		swappable = false
	timer = randf_range(0.5, 1.2)


func _physics_process(delta: float) -> void:
	if not alive or game == null or game.game_over:
		return
	if state == State.PINNED:
		velocity = Vector2.ZERO
		if pinned_to != null and is_instance_valid(pinned_to):
			position = pinned_to.position + pinned_offset
		queue_redraw()
		return
	var to_p: Vector2 = game.player.position - position
	apply_gravity(delta)
	match state:
		State.CHASE:
			if absf(to_p.x) > 4.0:
				facing = signf(to_p.x)
			if is_on_floor() and not game.safe_step(self, facing):
				velocity.x = 0.0
			else:
				velocity.x = facing * WALK_SPEED
			timer -= delta
			if timer <= 0.0 and is_on_floor() and absf(to_p.x) < TRIGGER_X and absf(to_p.y) < TRIGGER_Y:
				state = State.WINDUP
				game.play_sfx("windup")
				timer = WINDUP_TIME
		State.WINDUP:
			velocity.x = 0.0
			timer -= delta
			if timer <= 0.0:
				state = State.DASH
				game.play_sfx("dash")
				timer = DASH_TIME
		State.DASH:
			velocity.x = facing * DASH_SPEED
			timer -= delta
		State.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			timer -= delta
			if timer <= 0.0:
				state = State.CHASE
				timer = randf_range(0.4, 1.0)
	move_and_slide()

	if state == State.DASH:
		game.dash_hit(self)
		if is_on_wall() or timer <= 0.0:
			if is_on_wall():
				game.add_shake(2.0)
			state = State.RECOVER
			timer = RECOVER_TIME


func pin_to_wheel(anchor, offset: Vector2) -> void:
	state = State.PINNED
	pinned_to = anchor
	pinned_offset = offset
	velocity = Vector2.ZERO
	position = anchor.position + offset


func can_trigger_wheel() -> bool:
	return state == State.DASH or state == State.RECOVER


## 主角在 p 位置时，这只冲锋者是否马上要撞到他（用于触发子弹时间）
func threatens(p: Vector2) -> bool:
	if state != State.DASH and not (state == State.WINDUP and timer < 0.25):
		return false
	var dx := p.x - position.x
	return signf(dx) == facing and absf(dx) < 90.0 and absf(p.y - position.y) < 16.0


func _draw_body() -> void:
	# 造型：低矮的公牛。四条短腿，前面一大一小两只角。
	var f := facing
	var white := Color.WHITE
	var black := Color.BLACK
	var body_color := Color(0.66, 0.08, 0.1) if execution_variant else white
	var jx := 0.0
	var crouch := 0.0
	if state == State.WINDUP:
		# 蓄力：压低身子、原地发抖、鼻孔喷气
		jx = randf_range(-1.0, 1.0)
		crouch = 1.5
		draw_dashed_line(Vector2(f * 9.0, 0), Vector2(f * DASH_SPEED * DASH_TIME, 0), Color(0.66, 0.08, 0.1), 1.0, 4.0)
		var puff := fmod(anim_t * 6.0, 1.0)
		draw_circle(Vector2(jx + f * (9.0 + puff * 4.0), -1.0 - puff * 2.0), 1.0 + puff, Color(1, 1, 1, 1.0 - puff))
	elif state == State.DASH:
		# 冲刺：身后拖出速度线
		for i in 3:
			var ly := -3.0 + i * 2.5
			draw_line(Vector2(-f * 8.0, ly), Vector2(-f * (13.0 + i * 3.0), ly), Color(1, 1, 1, 0.7), 1.0)

	# 腿：走路时交替抬起
	var moving := is_on_floor() and absf(velocity.x) > 5.0
	for i in 4:
		var lift := 0.0
		if moving:
			lift = maxf(0.0, sin(anim_t * 18.0 + i * PI)) * 1.5
		draw_rect(Rect2(jx - 5.5 + i * 3.3, 2.0, 2.0, 3.0 - lift), white)

	# 身体（黑描边，贴墙也看得清）
	var top := -5.0 + crouch
	var body := Rect2(jx - 6.5, top, 13.0, 7.5 - crouch)
	draw_rect(body.grow(1.0), black)
	if state == State.RECOVER:
		draw_rect(body, white, false, 1.0)
	else:
		draw_rect(body, body_color)

	# 两只角
	var hx := jx + f * 4.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(hx, top + 1.0), Vector2(hx + f * 6.0, top - 4.0), Vector2(hx + f * 2.0, top + 3.0)]), white)
	draw_colored_polygon(PackedVector2Array([
		Vector2(hx - f * 3.0, top + 0.5), Vector2(hx + f * 0.5, top - 3.0), Vector2(hx - f * 1.0, top + 2.0)]), white)

	# 眼睛：平时一个黑点，蓄力和冲刺时压下眉毛，撞晕了变成 x
	var ex := jx + f * 3.5
	if state == State.WINDUP or state == State.DASH:
		draw_line(Vector2(ex - f * 2.0, top + 1.0), Vector2(ex + f * 1.0, top + 2.5), black, 1.0)
		draw_rect(Rect2(ex - 1.0, top + 2.5, 2, 2), black)
	elif state == State.RECOVER:
		draw_line(Vector2(ex - 1.0, top + 1.5), Vector2(ex + 1.0, top + 3.5), white, 1.0)
		draw_line(Vector2(ex + 1.0, top + 1.5), Vector2(ex - 1.0, top + 3.5), white, 1.0)
	else:
		draw_rect(Rect2(ex - 1.0, top + 2.0, 2, 2), black)

	# 撞晕了：头顶转圈的星星
	if state == State.RECOVER:
		for i in 3:
			var a := anim_t * 8.0 + i * TAU / 3.0
			var sp := Vector2(jx + cos(a) * 5.0, top - 4.0 + sin(a) * 1.5)
			draw_rect(Rect2(sp - Vector2(1, 1), Vector2(2, 2)), white)
	elif state == State.PINNED:
		draw_rect(body.grow(2.0), Color(0.66, 0.08, 0.1), false, 1.0)
		draw_line(Vector2(0, top - 1.0), Vector2(0, top - 9.0), Color(1, 1, 1, 0.7), 1.0)
		draw_rect(Rect2(-2, top - 11.0, 4, 3), Color(0.66, 0.08, 0.1))
		draw_rect(Rect2(ex - 1.0, top + 2.0, 2, 2), Color(1.0, 0.32, 0.22))

	if execution_variant:
		# Armored execution runner: heavier shoulders, a locked collar, and a
		# visible no-swap seal so the player reads it as machinery, not a target.
		draw_rect(Rect2(jx - 9.0, top + 0.5, 18.0, 2.0), white)
		draw_rect(Rect2(jx - 7.0, top - 1.0, 3.0, 2.0), white)
		draw_rect(Rect2(jx + 4.0, top - 1.0, 3.0, 2.0), white)
		draw_rect(Rect2(jx - 2.0, top - 8.0, 4.0, 4.0), black)
		draw_rect(Rect2(jx - 1.0, top - 7.0, 2.0, 2.0), Color(0.66, 0.08, 0.1))
		draw_line(Vector2(jx - 3.0, top - 10.0), Vector2(jx + 3.0, top - 4.0), white, 1.0)
		draw_line(Vector2(jx + 3.0, top - 10.0), Vector2(jx - 3.0, top - 4.0), white, 1.0)
