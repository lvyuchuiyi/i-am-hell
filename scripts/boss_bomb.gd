extends Entity
## Swappable ritual bomb for the final boss. It is harmless until the boss
## crushes it under the execution ring.

var primed: bool = false
var detonating: bool = false
var detonate_t: float = 0.0
var boss = null


func _ready() -> void:
	setup_body(Vector2(14, 14), 2, 1)
	killable = false
	swappable = true
	add_to_group("boss_bomb")


func _physics_process(delta: float) -> void:
	if detonating:
		detonate_t -= delta
		if detonate_t <= 0.0:
			queue_free()
		return
	if game == null or game.game_over:
		return
	apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
	move_and_slide()


func on_swapped() -> void:
	if detonating:
		return
	primed = true
	velocity = Vector2.ZERO
	flash = 0.14
	game.rings.append({"p": position, "t": 0.22, "max": 24.0})
	if boss != null and is_instance_valid(boss) and boss.is_waiting_for_bomb():
		boss._begin_slam(self)
	queue_redraw()


func detonate() -> void:
	if detonating:
		return
	detonating = true
	alive = false
	swappable = false
	detonate_t = 0.22
	queue_redraw()


func _draw_body() -> void:
	var pulse := 0.5 + 0.5 * sin(anim_t * 18.0)
	if primed:
		draw_circle(Vector2.ZERO, 13.0 + pulse * 2.0, Color(1.0, 0.32, 0.22, 0.18 + 0.18 * pulse))
		draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 16, Color.WHITE, 1.0)
	draw_circle(Vector2.ZERO, 8.0, Color.BLACK)
	draw_circle(Vector2.ZERO, 7.0, Color.WHITE)
	draw_circle(Vector2.ZERO, 4.5, Color.BLACK)
	draw_rect(Rect2(-2, -9, 4, 3), Color.WHITE)
	draw_line(Vector2(1, -9), Vector2(5, -14), Color.WHITE, 1.0)
	if int(anim_t * 16.0) % 2 == 0:
		draw_rect(Rect2(4, -16, 2, 2), Color(1.0, 0.32, 0.22))
	if primed:
		draw_line(Vector2(-5, -2), Vector2(5, 2), Color(0.66, 0.08, 0.1), 1.0)
