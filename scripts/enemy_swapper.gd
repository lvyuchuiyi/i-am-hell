extends Entity
## 换位者：它也会 SHIFT。隔一段时间蓄力（和主角之间出现闪烁的折线），然后强行和主角互换位置。
## 对策：在它换位的那一刻，让自己正处在致命的位置——它会替你去死。

enum State { MOVE, WINDUP, COOLDOWN }

const SPEED := 28.0
const PREFERRED_DIST := 110.0
const WINDUP_TIME := 0.9
const COOLDOWN_TIME := 2.6

var state: int = State.MOVE
var timer: float = 0.0
var orbit_a: float = 0.0


func _ready() -> void:
	setup_body(Vector2(10, 12), 2, 1)
	add_to_group("enemy")
	timer = randf_range(1.5, 2.5)


func _physics_process(delta: float) -> void:
	var spin := 3.0
	if state == State.WINDUP:
		spin = 3.0 + (1.0 - timer / WINDUP_TIME) * 20.0
	orbit_a += delta * spin
	if not alive or game == null or game.game_over:
		return
	var to_p: Vector2 = game.player.position - position
	apply_gravity(delta)
	match state:
		State.MOVE:
			var dx := absf(to_p.x)
			var move := 0.0
			if dx > PREFERRED_DIST + 20.0:
				move = signf(to_p.x)
			elif dx < PREFERRED_DIST - 20.0:
				move = -signf(to_p.x)
			if is_on_floor() and not game.safe_step(self, move):
				move = 0.0
			velocity.x = move * SPEED
			timer -= delta
			if timer <= 0.0:
				if not _may_swap():
					timer = 0.3   # 岩浆关：它比你高时不出手，等你爬到它上面
				else:
					state = State.WINDUP
					game.play_sfx("windup", 0.02)
					timer = WINDUP_TIME
		State.WINDUP:
			velocity.x = 0.0
			timer -= delta
			if timer <= 0.0:
				if _may_swap():
					game.enemy_swap(self)
				state = State.COOLDOWN
				timer = COOLDOWN_TIME
		State.COOLDOWN:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			timer -= delta
			if timer <= 0.0:
				state = State.MOVE
				timer = randf_range(0.5, 1.2)
	move_and_slide()


## 岩浆关里换位者只会把你往下拽（它在你下面才出手），不会白白把你送上去
func _may_swap() -> bool:
	if game.lava_speed <= 0.0:
		return true
	var py: float = game.player.position.y
	return position.y > py + 8.0


## 快换位的时候主角有危险（触发子弹时间）
func threatens(_p: Vector2) -> bool:
	return state == State.WINDUP and timer < 0.3


func _draw_body() -> void:
	# 造型：浮在半空的菱形，两颗小方块绕着它转。蓄力时越转越快、越收越紧。
	var white := Color.WHITE
	var black := Color.BLACK
	var hover := sin(anim_t * 3.0) * 1.5
	var filled := true
	var orbit_r := 9.0
	if state == State.WINDUP:
		var k := 1.0 - timer / WINDUP_TIME
		orbit_r = 9.0 - k * 4.0
		filled = int(timer * 18.0) % 2 == 0
	var c := Vector2(0, -1.0 + hover)

	# 脚下的影子（它是飘着的）
	draw_line(Vector2(-3, 6), Vector2(3, 6), Color(1, 1, 1, 0.4), 1.0)

	# 环绕的小方块：后半圈先画（在身体后面）
	for i in 2:
		var a := orbit_a + i * PI
		if sin(a) < 0.0:
			_draw_orbiter(c, a, orbit_r)

	# 菱形身体
	var pts := PackedVector2Array([c + Vector2(0, -7), c + Vector2(6, 0), c + Vector2(0, 7), c + Vector2(-6, 0)])
	var outline := PackedVector2Array([c + Vector2(0, -8.5), c + Vector2(7.5, 0), c + Vector2(0, 8.5), c + Vector2(-7.5, 0)])
	draw_colored_polygon(outline, black)
	if filled:
		draw_colored_polygon(pts, white)
		# 身上的 ⇄
		draw_line(c + Vector2(-3, -1.5), c + Vector2(3, -1.5), black, 1.0)
		draw_line(c + Vector2(3, -1.5), c + Vector2(1.5, -3), black, 1.0)
		draw_line(c + Vector2(3, 1.5), c + Vector2(-3, 1.5), black, 1.0)
		draw_line(c + Vector2(-3, 1.5), c + Vector2(-1.5, 3), black, 1.0)
	else:
		pts.append(pts[0])
		draw_polyline(pts, white, 1.0)

	# 前半圈后画（在身体前面）
	for i in 2:
		var a := orbit_a + i * PI
		if sin(a) >= 0.0:
			_draw_orbiter(c, a, orbit_r)


func _draw_orbiter(c: Vector2, a: float, r: float) -> void:
	var op := c + Vector2(cos(a) * r, sin(a) * r * 0.45)
	draw_rect(Rect2(op - Vector2(2.5, 2.5), Vector2(5, 5)), Color.BLACK)
	draw_rect(Rect2(op - Vector2(1.5, 1.5), Vector2(3, 3)), Color.WHITE)


func _draw() -> void:
	super._draw()
	# 蓄力时：和主角之间闪烁的折线（世界坐标，不受翻转影响）
	if state == State.WINDUP and game != null and game.player != null:
		if int(timer * 12.0) % 2 == 0:
			var to: Vector2 = game.player.position - position
			var mid := to * 0.5 + Vector2(-to.y, to.x).normalized() * 8.0
			draw_polyline(PackedVector2Array([Vector2.ZERO, mid, to]), Color(0.66, 0.08, 0.1), 1.0)
