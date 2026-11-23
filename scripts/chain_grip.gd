extends Node2D
## A fixed swappable chain handle used to leave a dangerous track without
## introducing another physics body or collider.

var game = null
var alive: bool = true
var swappable: bool = true
var killable: bool = false
var velocity := Vector2.ZERO
var half := Vector2(5, 5)
var gdir: float = 1.0
var phase: float = 0.0


func get_hit_rect() -> Rect2:
	return Rect2(position - half, half * 2.0)


func on_swapped() -> void:
	game.play_sfx("tick", 0.0)


func _process(delta: float) -> void:
	phase += delta
	queue_redraw()


func _draw() -> void:
	var sway := sin(phase * 2.2) * 1.5
	draw_line(Vector2(sway, -44), Vector2(0, -8), Color(1, 1, 1, 0.5), 1.0)
	for i in 5:
		var p := Vector2(sway, -44).lerp(Vector2(0, -8), float(i) / 5.0)
		draw_rect(Rect2(p - Vector2(2, 1), Vector2(4, 2)), Color.WHITE)
	draw_rect(Rect2(-7, -8, 14, 14), Color.BLACK)
	draw_rect(Rect2(-5, -6, 10, 10), Color.WHITE)
	draw_rect(Rect2(-3, -3, 6, 6), Color.BLACK)
	draw_rect(Rect2(-1, -1, 2, 2), Color(0.66, 0.08, 0.1))
