extends Entity
## 投弹手：定期在主角当前位置放一个延时炸弹圈，圈里的所有东西都会被炸死。

const SPEED := 25.0
const KEEP_DIST := 60.0
const THROW_INTERVAL := 2.6
const BLAST_RADIUS := 20.0
const BLAST_FUSE := 1.0

var timer: float = 0.0
var throwing: float = 0.0


func _ready() -> void:
	setup_body(Vector2(12, 12), 2, 1)
	add_to_group("enemy")
	timer = randf_range(1.2, 2.2)


func _physics_process(delta: float) -> void:
	if not alive or game == null or game.game_over:
		return
	var to_p: Vector2 = game.player.position - position
	apply_gravity(delta)
	var move := 0.0
	if absf(to_p.x) > KEEP_DIST:
		move = signf(to_p.x)
	if is_on_floor() and not game.safe_step(self, move):
		move = 0.0
	velocity.x = move * SPEED
	throwing = maxf(throwing - delta, 0.0)
	timer -= delta
	if timer <= 0.0:
		timer = THROW_INTERVAL
		throwing = 0.3
		game.spawn_blast(game.player.position, BLAST_RADIUS, BLAST_FUSE)
		game.play_sfx("windup", 0.15)
	move_and_slide()


const HOLD_TIME := 0.6   # 扔之前把炸弹举过头顶的时间


func _draw_body() -> void:
	# 造型：圆滚滚的炸弹人，头顶引线滋滋冒火花，快扔的时候把炸弹举过头顶。
	var white := Color.WHITE
	var black := Color.BLACK
	var look := look_vec()
	var bob := sin(anim_t * 4.0) * 0.5

	# 脚
	var step := 0.0
	if is_on_floor() and absf(velocity.x) > 3.0:
		step = sin(anim_t * 12.0)
	draw_rect(Rect2(-4, 4, 3, 2.0 - maxf(step, 0.0)), white)
	draw_rect(Rect2(1, 4, 3, 2.0 + minf(step, 0.0)), white)

	# 身体
	var c := Vector2(0, -0.5 + bob)
	draw_circle(c, 6.5, black)
	draw_circle(c, 5.5, white)

	# 引线 + 闪烁的火花
	var tip := c + Vector2(2.5, -8.5)
	draw_line(c + Vector2(0, -5.5), c + Vector2(1.5, -7.5), white, 1.0)
	draw_line(c + Vector2(1.5, -7.5), tip, white, 1.0)
	if int(anim_t * 12.0) % 2 == 0:
		draw_line(tip + Vector2(-1.5, 0), tip + Vector2(1.5, 0), white, 1.0)
		draw_line(tip + Vector2(0, -1.5), tip + Vector2(0, 1.5), white, 1.0)

	# 眼睛和咧嘴（跟着主角转）
	var eo := look * 1.5
	draw_rect(Rect2(c + eo + Vector2(-3, -2.5), Vector2(2, 2)), black)
	draw_rect(Rect2(c + eo + Vector2(1, -2.5), Vector2(2, 2)), black)
	draw_line(c + eo + Vector2(-2, 1.5), c + eo + Vector2(2, 1.5), black, 1.0)

	if timer < HOLD_TIME and throwing <= 0.0:
		# 快扔了：炸弹越举越高，炸弹上的火花也在闪
		var lift := (HOLD_TIME - timer) / HOLD_TIME
		var bp := c + Vector2(-look.x * 2.0, -11.0 - lift * 3.0)
		draw_line(c + Vector2(-2, -4), bp + Vector2(0, 2), white, 1.0)
		draw_circle(bp, 3.2, black)
		draw_circle(bp, 2.4, white)
		if int(anim_t * 20.0) % 2 == 0:
			draw_rect(Rect2(bp + Vector2(1, -4), Vector2(1, 1)), white)
	elif throwing > 0.0:
		# 刚扔完：手臂往前甩
		draw_line(c + Vector2(look.x * 3.0, -3), c + Vector2(look.x * 9.0, -6), white, 1.0)
