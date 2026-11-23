extends Node2D
## Two one-way platforms linked by a shared counterweight.

const HALF_WIDTH := 27.0
const HALF_THICK := 3.0
const MAX_SPEED := 34.0
const WEIGHT_ACCEL := 13.0
const RETURN_SPEED := 24.0
const BALANCE_EPSILON := 0.45

var game = null
var left_position := Vector2.ZERO
var right_position := Vector2.ZERO
var left_y: float = 0.0
var right_y: float = 0.0
var min_y: float = 48.0
var max_y: float = 320.0
var left_body: StaticBody2D
var right_body: StaticBody2D
var moving_step: float = 0.0
var active: bool = false
var neutral_y: float = 0.0


func _ready() -> void:
	left_y = left_position.y
	right_y = right_position.y
	neutral_y = (left_y + right_y) * 0.5
	left_body = _make_platform(left_position.x)
	right_body = _make_platform(right_position.x)
	_update_bodies()
	queue_redraw()


func _make_platform(x: float) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(HALF_WIDTH * 2.0, HALF_THICK * 2.0)
	cs.shape = shape
	cs.one_way_collision = true
	body.add_child(cs)
	body.position = Vector2(x, left_y)
	add_child(body)
	return body


func _physics_process(delta: float) -> void:
	if game == null or game.game_over:
		return
	if not active:
		if game.player != null and (
			game.player.position.distance_to(Vector2(left_position.x, left_y)) < 70.0
			or game.player.position.distance_to(Vector2(right_position.x, right_y)) < 70.0
		):
			active = true
			game.play_sfx("windup", 0.08)
		else:
			return
	var lrect := Rect2(Vector2(left_position.x - HALF_WIDTH, left_y - HALF_THICK), Vector2(HALF_WIDTH * 2.0, HALF_THICK * 2.0))
	var rrect := Rect2(Vector2(right_position.x - HALF_WIDTH, right_y - HALF_THICK), Vector2(HALF_WIDTH * 2.0, HALF_THICK * 2.0))
	var lriders: Array = _riders_on(lrect)
	var rriders: Array = _riders_on(rrect)
	var load_diff := _load(lriders) - _load(rriders)
	moving_step = 0.0
	var step := 0.0
	if absf(load_diff) > 0.01:
		step = clampf(load_diff * WEIGHT_ACCEL * delta, -MAX_SPEED * delta, MAX_SPEED * delta)
	else:
		var error := neutral_y - left_y
		if absf(error) <= BALANCE_EPSILON:
			left_y = neutral_y
			right_y = neutral_y
		else:
			step = clampf(error, -RETURN_SPEED * delta, RETURN_SPEED * delta)
	if absf(step) > 0.0001:
		var new_left := clampf(left_y + step, min_y, max_y)
		step = new_left - left_y
		var new_right := clampf(right_y - step, min_y, max_y)
		step = right_y - new_right
		moving_step = step
		left_y += step
		right_y -= step
		for e in lriders:
			e.position.y += step
		for e in rriders:
			e.position.y -= step
		_update_bodies()
	else:
		_update_bodies()
	queue_redraw()


func _riders_on(rect: Rect2):
	var out: Array = []
	for e in game.get_entities():
		if absf(e.position.x - rect.get_center().x) > HALF_WIDTH + e.half.x:
			continue
		var feet: float = e.position.y + e.gdir * e.half.y
		if absf(feet - rect.position.y) < 6.0:
			out.append(e)
	return out


func _load(riders: Array) -> float:
	var total := 0.0
	for e in riders:
		if e.get_script().resource_path.get_file() == "crate.gd":
			total += 2.0
		else:
			total += 1.0
	return total


func get_side_load(index: int) -> float:
	var rect := Rect2(
		Vector2(left_position.x if index == 0 else right_position.x, left_y if index == 0 else right_y) - Vector2(HALF_WIDTH, HALF_THICK),
		Vector2(HALF_WIDTH * 2.0, HALF_THICK * 2.0))
	return _load(_riders_on(rect))


func get_side_y(index: int) -> float:
	return left_y if index == 0 else right_y


func _update_bodies() -> void:
	left_body.position = Vector2(left_position.x, left_y)
	right_body.position = Vector2(right_position.x, right_y)


func threatens(p: Vector2) -> bool:
	if not active or absf(moving_step) < 0.005 or game.player == null:
		return false
	var left_rect := Rect2(Vector2(left_position.x - HALF_WIDTH, left_y - HALF_THICK), Vector2(HALF_WIDTH * 2.0, HALF_THICK * 2.0))
	var right_rect := Rect2(Vector2(right_position.x - HALF_WIDTH, right_y - HALF_THICK), Vector2(HALF_WIDTH * 2.0, HALF_THICK * 2.0))
	var player_rect: Rect2 = game.player.get_hit_rect()
	for rect in [left_rect, right_rect]:
		if not rect.grow(1.0).intersects(player_rect):
			continue
		var feet: float = p.y + game.player.gdir * game.player.half.y
		var standing: bool = absf(feet - rect.position.y) < 7.0
		if not standing:
			return true
	return false


func _draw() -> void:
	draw_line(Vector2(left_position.x, 18), Vector2(320, 18), Color(1, 1, 1, 0.45), 1.0)
	draw_line(Vector2(320, 18), Vector2(right_position.x, 18), Color(1, 1, 1, 0.45), 1.0)
	draw_circle(Vector2(320, 18), 9.0, Color.BLACK)
	draw_circle(Vector2(320, 18), 7.0, Color.WHITE)
	_draw_platform(Vector2(left_position.x, left_y), true)
	_draw_platform(Vector2(right_position.x, right_y), false)
	draw_line(Vector2(left_position.x, 18), Vector2(left_position.x, left_y - 4.0), Color(1, 1, 1, 0.4), 1.0)
	draw_line(Vector2(right_position.x, 18), Vector2(right_position.x, right_y - 4.0), Color(1, 1, 1, 0.4), 1.0)


func _draw_platform(center: Vector2, left: bool) -> void:
	var rect := Rect2(center + Vector2(-HALF_WIDTH, -HALF_THICK), Vector2(HALF_WIDTH * 2.0, HALF_THICK * 2.0))
	draw_rect(rect, Color.WHITE)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1)), Color.BLACK)
	for i in 5:
		var x := rect.position.x + 5.0 + i * 10.0
		draw_line(Vector2(x, rect.position.y - 1), Vector2(x + (3.0 if left else -3.0), rect.position.y - 6), Color(1, 1, 1, 0.45), 1.0)
