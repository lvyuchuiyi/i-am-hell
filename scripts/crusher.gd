extends Node2D
## 压路机：挂在天花板上，抖动预警后砸到地面，压扁下面的一切，然后慢慢升回去。
## 打不死，不能换位。drop = 能砸下去的距离（由 main 根据地形算好）。

enum State { IDLE, SHAKE, SLAM, HOLD, RISE }

const SHAKE_TIME := 0.5
const SLAM_SPEED := 520.0
const HOLD_TIME := 0.35
const RISE_SPEED := 60.0
const IDLE_TIME := 1.4

var game = null
var drop: float = 64.0
var state: int = State.IDLE
var timer: float = 1.0
var offset_y: float = 0.0
var jitter := Vector2.ZERO


func get_block_rect() -> Rect2:
	return Rect2(position.x - 8.0, position.y - 8.0 + offset_y, 16, 16)


func _physics_process(delta: float) -> void:
	if game == null or game.game_over:
		return
	jitter = Vector2.ZERO
	match state:
		State.IDLE:
			timer -= delta
			if timer <= 0.0:
				state = State.SHAKE
				timer = SHAKE_TIME
		State.SHAKE:
			timer -= delta
			jitter = Vector2(randf_range(-1.0, 1.0), 0)
			if timer <= 0.0:
				state = State.SLAM
		State.SLAM:
			offset_y += SLAM_SPEED * delta
			game.damage_rect(get_block_rect(), "a crusher")
			if offset_y >= drop:
				offset_y = drop
				game.damage_rect(get_block_rect(), "a crusher")
				game.add_shake(3.0)
				game.play_sfx("slam")
				state = State.HOLD
				timer = HOLD_TIME
		State.HOLD:
			timer -= delta
			if timer <= 0.0:
				state = State.RISE
		State.RISE:
			offset_y -= RISE_SPEED * delta
			if offset_y <= 0.0:
				offset_y = 0.0
				state = State.IDLE
				timer = IDLE_TIME
	queue_redraw()


func threatens(p: Vector2) -> bool:
	if state != State.SHAKE and state != State.SLAM:
		return false
	var r := get_block_rect()
	return absf(p.x - position.x) < 12.0 and p.y > r.position.y and p.y < position.y + drop + 12.0


func _draw() -> void:
	# 预警：抖动时画出会砸到的范围
	if state == State.SHAKE and int(timer * 16.0) % 2 == 0:
		draw_dashed_line(Vector2(-8, 8), Vector2(-8, 8 + drop), Color(0.66, 0.08, 0.1), 1.0, 3.0)
		draw_dashed_line(Vector2(8, 8), Vector2(8, 8 + drop), Color(0.66, 0.08, 0.1), 1.0, 3.0)
	# 连杆
	draw_line(Vector2(-3, -8), Vector2(-3, offset_y - 8.0), Color.WHITE, 1.0)
	draw_line(Vector2(3, -8), Vector2(3, offset_y - 8.0), Color.WHITE, 1.0)
	# 压块 + 底部锯齿
	var o := Vector2(jitter.x, offset_y)
	draw_rect(Rect2(o + Vector2(-8, -8), Vector2(16, 13)), Color.WHITE)
	for i in 4:
		var x := -8.0 + i * 4.0
		draw_colored_polygon(PackedVector2Array([
			o + Vector2(x, 5), o + Vector2(x + 2.0, 8), o + Vector2(x + 4.0, 5)]), Color.WHITE)
