extends Node2D
## 延时炸弹圈：外圈是范围，内圈逐渐扩大表示倒计时，爆炸时圈内全灭。

var game = null
var radius: float = 20.0
var cause: String = "a bomb"
var fuse: float = 1.0
var total: float = 1.0
var exploded: bool = false
var linger: float = 0.12


func _physics_process(delta: float) -> void:
	if game == null or game.game_over:
		return
	if not exploded:
		fuse -= delta
		if fuse <= 0.0:
			exploded = true
			game.play_sfx("explode", 0.1)
			game.damage_circle(position, radius, cause)
			game.add_shake(5.0)
	else:
		linger -= delta
		if linger <= 0.0:
			queue_free()
	queue_redraw()


func threatens(p: Vector2) -> bool:
	return not exploded and fuse < 0.35 and p.distance_to(position) < radius + 4.0


func _draw() -> void:
	if exploded:
		draw_circle(Vector2.ZERO, radius, Color.WHITE)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0.66, 0.08, 0.1), 2.0)
		return
	var k := clampf(1.0 - fuse / total, 0.0, 1.0)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0.66, 0.08, 0.1), 1.0)
	if k > 0.02:
		draw_arc(Vector2.ZERO, radius * k, 0.0, TAU, 32, Color(1, 1, 1, 0.45), 1.0)
	if int(fuse * 12.0) % 2 == 0:
		draw_line(Vector2(-3, -3), Vector2(3, 3), Color.WHITE, 1.0)
		draw_line(Vector2(3, -3), Vector2(-3, 3), Color.WHITE, 1.0)
