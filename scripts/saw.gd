extends Node2D
## 锯片：碰到的一切都会被切开（敌人、主角、爆炸桶）。
## speed > 0 时沿地面来回移动，碰墙或走到边缘就掉头。

var game = null
var speed: float = 70.0
var dir: float = 1.0
var radius: float = 7.0
var angle: float = 0.0


func _physics_process(delta: float) -> void:
	if game == null or game.game_over:
		return
	angle += delta * 14.0 * dir
	if speed > 0.0:
		var ahead := position + Vector2(dir * (radius + 1.0), 0)
		var below := position + Vector2(dir * (radius + 1.0), radius + 4.0)
		if game.solid_at(ahead) or not game.is_ground(below):
			dir = -dir
		position.x += dir * speed * delta
	game.damage_circle(position, radius - 1.0, "a saw")
	queue_redraw()


func threatens(p: Vector2) -> bool:
	var d := p.distance_to(position)
	if speed <= 0.0:
		return d < 20.0
	return d < 30.0 and signf(p.x - position.x) == dir


func _draw() -> void:
	var pts := PackedVector2Array()
	var teeth := 8
	for i in teeth * 2:
		var a := angle + float(i) * PI / float(teeth)
		var r := radius if i % 2 == 0 else radius - 2.5
		pts.append(Vector2.from_angle(a) * r)
	draw_colored_polygon(pts, Color.WHITE)
	draw_circle(Vector2.ZERO, 2.0, Color.BLACK)
