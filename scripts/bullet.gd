extends Node2D
## 子弹：直线飞行，碰到墙壁消失，命中第一个碰到的实体。

var game = null
var velocity := Vector2.ZERO
var shooter = null
var grace: float = 0.12   # 刚射出时不打自己
var radius: float = 1.5


func _physics_process(delta: float) -> void:
	if game == null or game.game_over:
		return
	position += velocity * delta
	grace -= delta
	if game.solid_at(position) or position.x < -20.0 or position.x > 500.0 or position.y < -20.0 or position.y > game.rows * 16.0 + 18.0:
		queue_free()
		return
	var ignore = null
	if grace > 0.0:
		ignore = shooter
	var hit = game.first_entity_hit(position, radius, ignore)
	if hit != null and hit.has_method("reflects") and hit.reflects(velocity):
		# 打在镜子正面：原路弹回去
		velocity = -velocity
		shooter = hit
		grace = 0.12
		position += velocity.normalized() * 4.0
		game.add_shake(1.5)
		game.play_sfx("reflect")
		return
	if hit != null and game.hit_entity(hit, "a bullet"):
		queue_free()
		return
	queue_redraw()


func threatens(p: Vector2) -> bool:
	var to := p - position
	return to.length() < 40.0 and to.dot(velocity) > 0.0


func _draw() -> void:
	var back := -velocity.normalized()
	draw_rect(Rect2(back * 3.0 - Vector2(1, 1), Vector2(2, 2)), Color(0.66, 0.08, 0.1))
	draw_rect(Rect2(-1.5, -1.5, 3, 3), Color.WHITE)
