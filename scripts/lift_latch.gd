extends Node2D
## Per-tier release latch for the final central lift. The player must stand on it
## while the lift is waiting at that tier; then the lift is allowed to rise once.

var game = null
var used: bool = false
var charge: float = 0.0


func _physics_process(delta: float) -> void:
	if used or game == null or game.game_over or game.player == null:
		return
	if not game.boss_lift.activated or not game.boss_lift.waiting_release:
		charge = 0.0
		return
	if get_hit_rect().grow(3.0).intersects(game.player.get_hit_rect()):
		charge += delta
		if charge >= 0.22:
			used = true
			game.boss_lift.unlock_current_stop()
			game.play_sfx("tick", 0.0)
			game.rings.append({"p": position, "t": 0.3, "max": 20.0})
	else:
		charge = 0.0
	queue_redraw()


func get_hit_rect() -> Rect2:
	return Rect2(position - Vector2(8, 10), Vector2(16, 14))


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
	draw_rect(Rect2(-8, 5, 16, 5), Color.BLACK)
	draw_rect(Rect2(-7, 5, 14, 4), Color(0.66, 0.66, 0.66))
	if used:
		draw_line(Vector2(-5, -4), Vector2(5, 6), Color.WHITE, 2.0)
		draw_line(Vector2(5, -4), Vector2(-5, 6), Color.WHITE, 2.0)
		draw_rect(Rect2(-2, 7, 4, 1), Color.WHITE)
	else:
		draw_line(Vector2(0, 5), Vector2(0, -8), Color.WHITE, 2.0)
		draw_rect(Rect2(-5, -8, 10, 8), Color.BLACK)
		draw_rect(Rect2(-4, -7, 8, 6), Color.WHITE)
		draw_rect(Rect2(-2, -5, 4, 3),
			Color(1.0, 0.32, 0.22) if charge > 0.0 else Color(0.66, 0.08, 0.1))
		if charge > 0.0:
			draw_rect(Rect2(-10, -12, 20, 20), Color(1, 1, 1, 0.25 + 0.35 * pulse), false, 1.0)
