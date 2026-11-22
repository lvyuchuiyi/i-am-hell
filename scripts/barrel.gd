extends Entity
## 爆炸桶：受重力、能踩、可以换位。被任何攻击打中（子弹、冲锋、锯片、爆炸、地刺）就会爆炸。
## 爆炸会引爆旁边的桶——可以连锁。


func _ready() -> void:
	setup_body(Vector2(12, 14), 1, 1)
	add_to_group("barrel")


func _physics_process(delta: float) -> void:
	if game == null or game.game_over:
		return
	apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
	move_and_slide()


func _draw_body() -> void:
	draw_rect(Rect2(-6, -7, 12, 14), Color.WHITE)
	draw_rect(Rect2(-4, -5, 8, 10), Color.BLACK)
	draw_rect(Rect2(-1, -4, 2, 5), Color.WHITE)
	draw_rect(Rect2(-1, 2, 2, 2), Color.WHITE)
