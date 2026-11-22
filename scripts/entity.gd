class_name Entity
extends CharacterBody2D
## 所有“实体”（主角、敌人、箱子）的基类。
## 地形碰撞交给 Godot 的 CharacterBody2D；实体之间的命中用矩形判断，由 main.gd 统一管理。
## 碰撞层：1 = 地形和箱子，2 = 主角和敌人（互相穿过，只撞地形）。
## 子类在 _draw_body() 里画自己；基类负责换位时的挤压拉伸和闪白。

const GRAVITY := 900.0
const MAX_FALL := 420.0

var game = null              # main.gd 的引用，生成时由 main 赋值
var half := Vector2(4, 6)    # 半尺寸（命中判定用）
var alive: bool = true
var swappable: bool = true   # 能否被主角换位
var killable: bool = true    # 能否被杀死（箱子不行）
var invuln: float = 0.0      # 无敌剩余时间（主要给主角用）
var facing: float = 1.0      # 1 = 朝右，-1 = 朝左
var gdir: float = 1.0        # 重力方向：1 = 向下，-1 = 向上（在重力反转区里）

var vis_scale := Vector2.ONE # 只影响画面的缩放（不影响碰撞）
var flash: float = 0.0       # 闪白剩余时间
var anim_t: float = 0.0      # 动画时钟


func setup_body(size: Vector2, layer: int, mask: int) -> void:
	half = size * 0.5
	collision_layer = layer
	collision_mask = mask
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	cs.shape = shape
	add_child(cs)


func get_hit_rect() -> Rect2:
	return Rect2(position - half, half * 2.0)


## 根据所在格子更新重力方向；反转时“地面”变成天花板
func update_gravity_dir() -> void:
	if game != null:
		gdir = game.gravity_dir_at(position)
	up_direction = Vector2(0, -gdir)


func apply_gravity(delta: float) -> void:
	update_gravity_dir()
	if not is_on_floor():
		velocity.y = clampf(velocity.y + GRAVITY * gdir * delta, -MAX_FALL, MAX_FALL)


## 换位瞬间：先压成一条竖线再弹回 + 闪白
func play_swap_fx(strength: float) -> void:
	vis_scale = Vector2(0.15, 1.0 + 0.9 * strength)
	flash = 0.08 + 0.06 * strength


func on_swapped() -> void:
	pass


## 看向主角的方向（本地坐标，已抵消重力翻转），用来让眼睛跟着主角转
func look_vec() -> Vector2:
	if game == null or game.player == null:
		return Vector2(facing, 0)
	var d: Vector2 = game.player.position - position
	d.y *= gdir
	if d.length() < 0.01:
		return Vector2(facing, 0)
	return d.normalized()


func _process(delta: float) -> void:
	anim_t += delta
	vis_scale = vis_scale.lerp(Vector2.ONE, 1.0 - exp(-14.0 * delta))
	flash = maxf(flash - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	# 重力反转时整个角色上下颠倒
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(vis_scale.x, vis_scale.y * gdir))
	_draw_body()
	if flash > 0.0:
		draw_rect(Rect2(-half - Vector2(1, 1), half * 2.0 + Vector2(2, 2)), Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_body() -> void:
	pass
