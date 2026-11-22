extends Entity
## 镜子：站着不动，只朝一个方向。正面挨子弹会把子弹原路弹回去（打回射手脸上）；
## 背面、冲锋、锯片、地刺、爆炸都能杀死它。可以换位——换位后朝向不变，拿来摆位置。
## 地图里 R = 朝右，r = 朝左。


var glint: float = 0.0   # 刚弹回子弹时的闪光


func _ready() -> void:
	setup_body(Vector2(10, 14), 2, 1)
	add_to_group("enemy")


## 子弹速度为 v 时，是不是打在正面
func reflects(v: Vector2) -> bool:
	var hit_front := v.x * facing < 0.0
	if hit_front:
		glint = 0.25
	return hit_front


func _physics_process(delta: float) -> void:
	glint = maxf(glint - delta, 0.0)
	if not alive or game == null or game.game_over:
		return
	apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
	move_and_slide()


func _draw_body() -> void:
	# 造型：举着大盾的小骑士。盾面上一道反光来回扫，弹回子弹时盾牌闪光。
	var f := facing
	var white := Color.WHITE
	var black := Color.BLACK
	var breathe := sin(anim_t * 3.0) * 0.5

	# 身体（头盔骑士）
	var body := Rect2(-4.5, -6.0 + breathe, 8.0, 13.0 - breathe)
	draw_rect(body.grow(1.0), black)
	draw_rect(body, white)
	# 面罩缝
	draw_rect(Rect2(-3.0 + f * 0.5, -3.0 + breathe, 5, 1.5), black)
	# 头盔上的羽毛
	draw_line(Vector2(-f * 1.0, -6.0 + breathe), Vector2(-f * 4.0, -9.5 + breathe), white, 1.5)

	# 大盾
	var sx := f * 5.5
	var shield := Rect2(sx - 2.0, -9, 4, 18)
	draw_rect(shield.grow(1.0), black)
	draw_rect(shield, white)
	# 反光：一道斜线从上往下扫
	var sweep := fmod(anim_t * 0.8, 1.6) - 0.3
	if sweep > 0.0 and sweep < 1.0:
		var y := -9.0 + sweep * 18.0
		draw_line(Vector2(sx - 2.0, y + 2.0), Vector2(sx + 2.0, y - 2.0), black, 1.0)
	# 刚弹回子弹：盾牌外一圈扩散的闪光
	if glint > 0.0:
		draw_rect(shield.grow(2.0 + (0.25 - glint) * 24.0), Color(1, 1, 1, glint * 4.0), false, 1.0)
