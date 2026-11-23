extends Node2D
## 激光：嵌在墙里，周期性地横向发射，充能时闪烁细线预警，开火时整条线上的一切都会被烧掉。
## 打不死，不能换位。

enum State { OFF, CHARGE, FIRE }

const OFF_TIME := 1.8
const CHARGE_TIME := 0.8
const FIRE_TIME := 0.45

var game = null
var dir: float = 1.0          # 发射方向
var end_x: float = 0.0        # 光束终点（撞到的墙）
var state: int = State.OFF
var timer: float = 1.0


func get_beam_rect() -> Rect2:
	var x0 := position.x + dir * 8.0
	return Rect2(minf(x0, end_x), position.y - 2.5, absf(end_x - x0), 5.0)


func _physics_process(delta: float) -> void:
	if game == null or game.game_over:
		return
	timer -= delta
	match state:
		State.OFF:
			if timer <= 0.0:
				state = State.CHARGE
				if game.is_world_on_screen(position, 24.0):
					game.play_sfx("laser_charge", 0.03)
				timer = CHARGE_TIME
		State.CHARGE:
			if timer <= 0.0:
				state = State.FIRE
				if game.is_world_on_screen(position, 24.0):
					game.play_sfx("laser_fire", 0.03)
				timer = FIRE_TIME
				game.add_shake(2.0)
		State.FIRE:
			game.damage_rect(get_beam_rect(), "a laser")
			if timer <= 0.0:
				state = State.OFF
				timer = OFF_TIME
	queue_redraw()


func threatens(p: Vector2) -> bool:
	var hot := state == State.FIRE or (state == State.CHARGE and timer < 0.3)
	if not hot:
		return false
	var r := get_beam_rect()
	return absf(p.y - position.y) < 10.0 and p.x >= r.position.x - 4.0 and p.x <= r.end.x + 4.0


func _draw() -> void:
	# 发射口
	draw_rect(Rect2(-8, -8, 16, 16), Color.WHITE)
	draw_rect(Rect2(-5, -5, 10, 10), Color.BLACK)
	draw_rect(Rect2(dir * 4.0 - 2.0, -2, 4, 4), Color.WHITE)
	var a := Vector2(dir * 8.0, 0)
	var b := Vector2(end_x - position.x, 0)
	match state:
		State.CHARGE:
			if int(timer * 20.0) % 2 == 0:
				draw_dashed_line(a, b, Color(0.66, 0.08, 0.1), 1.0, 3.0)
		State.FIRE:
			var w := 5.0 if int(timer * 30.0) % 2 == 0 else 4.0
			draw_line(a, b, Color(0.66, 0.08, 0.1), w + 2.0)
			draw_line(a, b, Color.WHITE, w - 2.0)
