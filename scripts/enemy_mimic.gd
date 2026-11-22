extends Entity
## 倒影：没有自己的脑子，只会照着主角做，而且左右是反的。
## 主角往右走它就往左走，主角起跳它也起跳（松开跳键早，它也跳得矮）。
## 碰到它不会死。想杀它，就自己走位，让它走进地刺、深渊，或者在刺下面跳。
## 撞到墙它会停下，主角却还能继续走：靠墙可以把两边的距离“对齐”。

const JUMP_VELOCITY := -340.0
const JUMP_CUT := 1.6

var last_jump: int = -1


func _ready() -> void:
	setup_body(Vector2(8, 12), 2, 1)
	add_to_group("enemy")


func _physics_process(delta: float) -> void:
	if not alive or game == null or game.game_over:
		return
	var p = game.player
	var p_ok: bool = p != null and is_instance_valid(p) and p.alive
	if p_ok:
		velocity.x = -p.velocity.x
		facing = -p.facing
		if last_jump < 0:
			last_jump = p.jump_count
	else:
		velocity.x = 0.0
	apply_gravity(delta)
	if p_ok and p.jump_count != last_jump:
		last_jump = p.jump_count
		if is_on_floor():
			velocity.y = JUMP_VELOCITY * gdir
	if p_ok and velocity.y * gdir < 0.0 and not p.jump_was_held:
		velocity.y += GRAVITY * gdir * JUMP_CUT * delta
	move_and_slide()


func _draw_body() -> void:
	# 造型：主角的“底片”——白色身体、黑色眼睛，角和斗篷的轮廓一样，没有围巾
	var f := facing
	var white := Color.WHITE
	var black := Color.BLACK
	var bob := 0.0
	if is_on_floor() and absf(velocity.x) > 10.0:
		bob = -absf(sin(anim_t * 18.0)) * 1.0
	# 腿
	draw_rect(Rect2(-2.5, 4.0, 1.5, 2.0), white)
	draw_rect(Rect2(1.0, 4.0, 1.5, 2.0), white)
	# 斗篷身体
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4.5, 4.5 + bob), Vector2(-3.5, -1.0 + bob), Vector2(3.5, -1.0 + bob), Vector2(4.5, 4.5 + bob)]), white)
	# 大头（黑描边，白填充）
	draw_rect(Rect2(-4.5, -7.5 + bob, 9.0, 7.0), black)
	draw_rect(Rect2(-3.5, -6.5 + bob, 7.0, 5.0), white)
	# 弯角
	draw_colored_polygon(PackedVector2Array([
		Vector2(-3.5, -6.5 + bob), Vector2(-5.5, -10.0 + bob), Vector2(-2.0, -7.0 + bob)]), white)
	draw_colored_polygon(PackedVector2Array([
		Vector2(3.5, -6.5 + bob), Vector2(5.5, -10.0 + bob), Vector2(2.0, -7.0 + bob)]), white)
	# 黑眼睛（主角是红眼，倒影是空洞的黑眼）
	draw_rect(Rect2(f * 1.0 - 1.5, -5.0 + bob, 1.0, 2.0), black)
	draw_rect(Rect2(f * 1.0 + 1.0, -5.0 + bob, 1.0, 2.0), black)
	# 脚下一道竖线裂纹：表示它是“镜子里出来的”
	draw_line(Vector2(0, -1.0 + bob), Vector2(0, 3.0 + bob), black, 1.0)
