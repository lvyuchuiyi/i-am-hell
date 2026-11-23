extends Entity
## PLUMB: a tiny executioner riding a huge plumb that drops through a shaft.

enum State { DORMANT, WAIT, WIND, DROP, HOLD, RISE }

const WIND_TIME := 0.48
const DROP_SPEED := 420.0
const HOLD_TIME := 0.34
const RISE_SPEED := 58.0

var state: int = State.DORMANT
var timer: float = 1.0
var base_y: float = 0.0
var anchor_y: float = 0.0
var drop_distance: float = 64.0
var offset_y: float = 0.0
var phase: float = 0.0


func _ready() -> void:
	setup_body(Vector2(17, 22), 2, 1)
	add_to_group("enemy")
	base_y = position.y
	anchor_y = base_y - 30.0
	phase = randf_range(0.0, TAU)
	_reset_drop_distance()


func _physics_process(delta: float) -> void:
	if not alive or game == null or game.game_over:
		return
	phase += delta * 4.0
	match state:
		State.DORMANT:
			offset_y = 0.0
			if game.player != null and game.player.position.distance_to(position) < 120.0:
				state = State.WAIT
				timer = 0.55
				game.play_sfx("windup", 0.12)
		State.WAIT:
			offset_y = 0.0
			timer -= delta
			if timer <= 0.0:
				state = State.WIND
				timer = WIND_TIME
				game.play_sfx("windup", 0.1)
		State.WIND:
			offset_y = 0.0
			timer -= delta
			if timer <= 0.0:
				state = State.DROP
				game.play_sfx("dash", 0.04)
		State.DROP:
			offset_y = minf(offset_y + DROP_SPEED * delta, drop_distance)
			game.damage_rect(get_plumb_rect(), "a plumb", self)
			if offset_y >= drop_distance:
				game.damage_rect(get_plumb_rect(), "a plumb", self)
				game.add_shake(5.0)
				game.play_sfx("slam", 0.02)
				state = State.HOLD
				timer = HOLD_TIME
		State.HOLD:
			timer -= delta
			if timer <= 0.0:
				state = State.RISE
		State.RISE:
			offset_y -= RISE_SPEED * delta
			if offset_y <= 0.0:
				offset_y = 0.0
				state = State.WAIT
				timer = 1.15
	position.y = base_y + offset_y


func on_swapped() -> void:
	base_y = position.y
	anchor_y = base_y - 30.0
	offset_y = 0.0
	timer = 0.35
	state = State.WAIT
	_reset_drop_distance()


func _reset_drop_distance() -> void:
	if game == null:
		return
	var c := floori(position.x / 16.0)
	var r := floori(position.y / 16.0) + 1
	while r < game.rows and not game.is_ground(Vector2(position.x, r * 16.0 + 2.0)):
		r += 1
	var floor_y := float(mini(r, game.rows)) * 16.0
	drop_distance = maxf(floor_y - (base_y + half.y), 16.0)


func get_plumb_rect() -> Rect2:
	return Rect2(position - half, half * 2.0)


func threatens(p: Vector2) -> bool:
	if state != State.DROP:
		return false
	var next_y := position.y + DROP_SPEED * 0.12
	var next_rect := Rect2(Vector2(position.x - half.x, next_y - half.y), half * 2.0)
	return next_rect.grow(2.0).has_point(p)


func _draw_body() -> void:
	var anchor_local := Vector2(0, anchor_y - position.y)
	draw_line(anchor_local, Vector2(0, -10), Color.WHITE, 1.0)
	for i in 4:
		var q := anchor_local.lerp(Vector2(0, -10), float(i + 1) / 5.0)
		draw_rect(Rect2(q - Vector2(2, 1), Vector2(4, 2)), Color.BLACK)

	var shake := Vector2(randf_range(-1.0, 1.0), 0.0) if state == State.WIND else Vector2.ZERO
	var panic := state == State.DROP
	var hood := shake + Vector2(0, -17 if not panic else -19)
	draw_colored_polygon(PackedVector2Array([
		hood + Vector2(-5, 5), hood + Vector2(-3, -3), hood + Vector2(0, -7),
		hood + Vector2(3, -3), hood + Vector2(5, 5), hood + Vector2(0, 8),
	]), Color.BLACK)
	draw_colored_polygon(PackedVector2Array([
		hood + Vector2(-3, 3), hood + Vector2(0, -4), hood + Vector2(3, 3),
	]), Color.WHITE)
	var eye_color := Color(0.66, 0.08, 0.1, 0.35) if state == State.DORMANT else Color(0.66, 0.08, 0.1)
	draw_rect(Rect2(hood + Vector2(-3, 0), Vector2(2, 1)), eye_color)
	draw_rect(Rect2(hood + Vector2(2, 0), Vector2(2, 1)), eye_color)
	draw_line(hood + Vector2(-4, 5), hood + Vector2(-8, 9), Color.WHITE, 2.0)
	draw_line(hood + Vector2(4, 5), hood + Vector2(8, 9), Color.WHITE, 2.0)
	if panic:
		draw_line(hood + Vector2(-5, 7), hood + Vector2(-10, 4 + sin(phase) * 2.0), Color.WHITE, 1.0)
		draw_line(hood + Vector2(5, 7), hood + Vector2(10, 4 - sin(phase) * 2.0), Color.WHITE, 1.0)

	var body := Rect2(Vector2(-8, -4) + shake, Vector2(16, 19))
	draw_rect(body.grow(1.0), Color.BLACK)
	draw_rect(body, Color.WHITE)
	draw_rect(Rect2(body.position + Vector2(3, 3), Vector2(10, 13)), Color.BLACK)
	draw_line(body.position + Vector2(5, 5), body.position + Vector2(10, 9), Color(0.66, 0.08, 0.1), 2.0)
	draw_line(body.position + Vector2(10, 9), body.position + Vector2(6, 13), Color(0.66, 0.08, 0.1), 2.0)
	if state == State.WIND:
		draw_rect(body.grow(3.0), Color(0.66, 0.08, 0.1), false, 1.0)
	elif state == State.DROP:
		draw_line(body.position + Vector2(-12, -6), body.position + Vector2(-5, -6), Color(1, 1, 1, 0.55), 1.0)
		draw_line(body.position + Vector2(18, -6), body.position + Vector2(25, -6), Color(1, 1, 1, 0.55), 1.0)
