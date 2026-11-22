extends Entity
## 箱子：受重力，能站在上面，挡子弹、挡冲锋，杀不死，可以换位（当作瞬移点）。
## 箱子在碰撞层 1（和地形一样），所以主角和敌人都会被它挡住。


func _ready() -> void:
	setup_body(Vector2(14, 14), 1, 1)
	killable = false
	add_to_group("crate")


func _physics_process(delta: float) -> void:
	if game == null or game.game_over:
		return
	apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
	move_and_slide()


func _draw_body() -> void:
	draw_rect(Rect2(-7, -7, 14, 14), Color.WHITE, false, 1.0)
	draw_line(Vector2(-7, -7), Vector2(7, 7), Color.WHITE, 1.0)
	draw_line(Vector2(7, -7), Vector2(-7, 7), Color.WHITE, 1.0)
