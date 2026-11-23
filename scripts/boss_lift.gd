extends Node2D
## Final level's processional lift. After the right nail breaks it rises through
## the traversal tiers and waits for each tier's release latch.

const HALF_WIDTH := 29.0
const HALF_THICK := 3.0
const SPEED := 38.0
const WAIT_TIME := 1.25

var game = null
var activated: bool = false
var stops: Array = []
var stop_index: int = 0
var wait_t: float = 0.0
var y: float = 0.0
var body: StaticBody2D
var waiting_release: bool = false
var released_stops: Dictionary = {}


func _ready() -> void:
	y = position.y
	if stops.is_empty():
		stops = [position.y, position.y - 160.0]
	stops.sort()
	stops.reverse()
	stop_index = 0
	for i in stops.size():
		if absf(stops[i] - y) < 0.1:
			stop_index = i
			break

	body = StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(HALF_WIDTH * 2.0, HALF_THICK * 2.0)
	cs.shape = shape
	cs.one_way_collision = true
	body.add_child(cs)
	add_child(body)
	_update_body()


func activate() -> void:
	if activated:
		return
	activated = true
	wait_t = WAIT_TIME
	game.play_sfx("door", 0.12)
	queue_redraw()


func _process(_delta: float) -> void:
	# The lift y is driven by physics; redraw every frame so the artwork follows
	# the collision body instead of remaining at its initial map position.
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not activated or game == null or game.game_over:
		return
	if wait_t > 0.0:
		wait_t = maxf(wait_t - delta, 0.0)
		return
	if waiting_release:
		return
	if stop_index >= stops.size() - 1:
		return

	var next_index := stop_index + 1
	var target: float = stops[next_index]
	var riders := _riders_on()
	var step := clampf(target - y, -SPEED * delta, SPEED * delta)
	y += step
	for e in riders:
		e.position.y += step
	_update_body()

	if absf(y - target) <= 0.01:
		y = target
		stop_index = next_index
		wait_t = WAIT_TIME
		if stop_index < stops.size() - 1 and not released_stops.has(stop_index):
			waiting_release = true
		game.add_shake(1.2)
		game.play_sfx("tick", 0.03)
	queue_redraw()


func unlock_current_stop() -> void:
	if not activated or waiting_release == false:
		return
	released_stops[stop_index] = true
	waiting_release = false
	wait_t = 1.0
	game.play_sfx("door", 0.0)
	game.rings.append({"p": position + Vector2(0, y - position.y), "t": 0.3, "max": 24.0})
	queue_redraw()


func _riders_on() -> Array:
	var out: Array = []
	var platform_top := y - HALF_THICK
	for e in game.get_entities():
		if absf(e.position.x - position.x) > HALF_WIDTH + e.half.x:
			continue
		var feet: float = e.position.y + e.gdir * e.half.y
		if absf(feet - platform_top) < 7.0:
			out.append(e)
	return out


func _update_body() -> void:
	body.position = Vector2(0.0, y - position.y)


func _draw() -> void:
	var local_y := y - position.y
	draw_line(Vector2(0, -position.y - 20.0), Vector2(0, local_y - HALF_THICK), Color(1, 1, 1, 0.35), 1.0)
	var rect := Rect2(Vector2(-HALF_WIDTH, local_y - HALF_THICK), Vector2(HALF_WIDTH * 2.0, HALF_THICK * 2.0))
	draw_rect(rect, Color.WHITE)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1)), Color.BLACK)
	for i in 6:
		var x := -22.0 + i * 9.0
		draw_line(Vector2(x, rect.position.y - 1.0), Vector2(x + 3.0, rect.position.y - 6.0), Color(1, 1, 1, 0.45), 1.0)
	if not activated:
		draw_rect(rect.grow(2.0), Color(0.66, 0.08, 0.1), false, 1.0)
	elif waiting_release:
		draw_rect(rect.grow(3.0), Color(0.66, 0.08, 0.1), false, 1.0)
		var lock_c := rect.position + Vector2(HALF_WIDTH + 5.0, 1.0)
		draw_rect(Rect2(lock_c - Vector2(3, 3), Vector2(6, 6)), Color.WHITE)
		draw_rect(Rect2(lock_c - Vector2(2, 2), Vector2(4, 4)), Color(0.66, 0.08, 0.1))
	elif wait_t > 0.0:
		var k := clampf(wait_t / WAIT_TIME, 0.0, 1.0)
		draw_rect(rect.grow(2.0 + k * 3.0), Color(1, 1, 1, k * 0.55), false, 1.0)
