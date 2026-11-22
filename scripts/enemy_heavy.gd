extends Entity
## 重装：又大又慢，一路朝主角走过来，碰到谁压死谁（主角、其他敌人都一样）。
## 子弹打不动，也不能被换位。但它很蠢——不看路，会自己走下平台、走进地刺和深渊。

const SPEED := 22.0

var step_phase: float = 0.0
var last_step: float = 1.0


func _ready() -> void:
	setup_body(Vector2(16, 16), 2, 1)
	add_to_group("enemy")
	swappable = false


func immune_to(cause: String) -> bool:
	return cause == "a bullet"


func _physics_process(delta: float) -> void:
	if not alive or game == null or game.game_over:
		return
	var to_p: Vector2 = game.player.position - position
	apply_gravity(delta)
	if absf(to_p.x) > 2.0:
		facing = signf(to_p.x)
	velocity.x = facing * SPEED
	move_and_slide()
	if is_on_floor():
		step_phase += delta * 8.0
		var st := signf(sin(step_phase))
		if st != last_step:
			last_step = st
			game.spawn_dust(position + Vector2(0, half.y * gdir), 2)
	game.contact_kill(self, "a heavy")


func _draw_body() -> void:
	# 造型：方头方脑的重甲。黑色面罩里一道发光的眼缝跟着你转，走路一步一顿。
	var white := Color.WHITE
	var black := Color.BLACK
	var s := sin(step_phase)
	var bob := -absf(s) * 1.0

	# 腿：抬起的那条腿短一截
	draw_rect(Rect2(-7, 5, 5, 3.0 - maxf(s, 0.0) * 2.0), white)
	draw_rect(Rect2(2, 5, 5, 3.0 - maxf(-s, 0.0) * 2.0), white)

	# 躯干
	var body := Rect2(-8, -8 + bob, 16, 13)
	draw_rect(body.grow(1.0), black)
	draw_rect(body, white)
	# 肩甲
	draw_rect(Rect2(-10, -8 + bob, 4, 6), black)
	draw_rect(Rect2(-9.5, -7.5 + bob, 3, 5), white)
	draw_rect(Rect2(6, -8 + bob, 4, 6), black)
	draw_rect(Rect2(6.5, -7.5 + bob, 3, 5), white)
	# 面罩 + 发光眼缝
	draw_rect(Rect2(-6, -5 + bob, 12, 4), black)
	var look := look_vec()
	draw_rect(Rect2(look.x * 3.0 - 2.0, -4 + bob, 4, 2), white)
	# 胸甲接缝和铆钉
	draw_line(Vector2(-6, 1 + bob), Vector2(6, 1 + bob), black, 1.0)
	draw_rect(Rect2(-6, 2.5 + bob, 1, 1), black)
	draw_rect(Rect2(5, 2.5 + bob, 1, 1), black)
