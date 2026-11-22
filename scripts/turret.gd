extends Node2D
## 炮塔：嵌在墙里，打不死。平时炮管跟着主角转，蓄力时锁定方向并显示瞄准线，然后开火。
## 子弹会打中路上的任何东西。

const INTERVAL := 2.2
const WINDUP := 0.6
const BULLET_SPEED := 160.0

var game = null
var timer: float = 1.5
var winding: bool = false
var aim := Vector2.RIGHT


func _physics_process(delta: float) -> void:
	if game == null or game.game_over or game.player == null:
		return
	var to: Vector2 = game.player.position - position
	timer -= delta
	if not winding:
		if to.length() > 0.01:
			aim = to.normalized()
		if timer <= 0.0:
			winding = true
			game.play_sfx("windup", 0.05)
			timer = WINDUP
	else:
		if timer <= 0.0:
			winding = false
			timer = INTERVAL
			game.spawn_bullet(position + aim * 12.0, aim * BULLET_SPEED, null)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-8, -8, 16, 16), Color.WHITE)
	draw_rect(Rect2(-5, -5, 10, 10), Color.BLACK)
	if winding:
		if int(timer * 20.0) % 2 == 0:
			draw_rect(Rect2(-3, -3, 6, 6), Color.WHITE)
		draw_dashed_line(aim * 10.0, aim * 420.0, Color(0.66, 0.08, 0.1), 1.0, 4.0)
	draw_line(Vector2.ZERO, aim * 9.0, Color.WHITE, 3.0)
