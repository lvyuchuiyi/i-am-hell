extends Entity
## Giant swappable chain hook. Player velocity is converted to angular velocity
## by the existing swap rule, allowing one well-timed swap to extend the arc.

const SWING_GRAVITY := 9.8
const DAMPING := 0.16
const MAX_ANGLE := 1.18
const MIN_HIT_SPEED := 95.0
const BOOST_TIME := 0.7
const BOOST_CAP := 3.2

var pivot := Vector2.ZERO
var chain_length: float = 118.0
var angle: float = -0.45
var angular_velocity: float = 0.0
var active: bool = false
var nail_position := Vector2.ZERO
var hook_hit: bool = false
var locked: bool = false
var chain_steps_created: bool = false
var chain_step_rects: Array = []
var boost_t: float = 0.0
var kill_flash_t: float = 0.0
var kill_window_t: float = 0.0
var kill_window_count: int = 0


func _ready() -> void:
	setup_body(Vector2(18, 18), 2, 0)
	killable = false
	swappable = true
	pivot = pivot if pivot != Vector2.ZERO else position - Vector2(0, chain_length)
	_update_transform()


func activate() -> void:
	active = true
	angular_velocity += 0.18


func _physics_process(delta: float) -> void:
	if game == null or game.game_over:
		return
	boost_t = maxf(boost_t - delta, 0.0)
	kill_flash_t = maxf(kill_flash_t - delta, 0.0)
	kill_window_t = maxf(kill_window_t - delta, 0.0)
	if kill_window_t <= 0.0:
		kill_window_count = 0
	if locked:
		return
	var previous := position
	if active:
		angular_velocity += (-SWING_GRAVITY / maxf(chain_length, 20.0)) * sin(angle) * 18.0 * delta
		angular_velocity *= exp(-DAMPING * delta)
		angle = clampf(angle + angular_velocity * delta, -MAX_ANGLE, MAX_ANGLE)
		if absf(angle) >= MAX_ANGLE - 0.001:
			angular_velocity *= -0.62
	_update_transform()
	var speed := velocity.length()
	if speed > MIN_HIT_SPEED:
		# The giant hook never harms the player. It still kills other entities.
		var killed := 0
		if boost_t > 0.0:
			var sweep := Rect2(previous, Vector2.ZERO).expand(position).grow(12.0)
			killed = game.damage_rect(sweep, "a giant hook", game.player)
		else:
			killed = game.damage_rect(get_hit_rect().grow(2.0), "a giant hook", game.player)
		if killed > 0:
			_register_sweep_kills(killed)
	if not hook_hit and nail_position != Vector2.ZERO and speed > 150.0:
		if position.distance_to(nail_position) < 18.0:
			_lock_on_nail()


func on_swapped() -> void:
	if locked:
		return
	var offset := position - pivot
	angle = clampf(atan2(offset.x, maxf(offset.y, 1.0)), -MAX_ANGLE, MAX_ANGLE)
	var tangent := Vector2(cos(angle), -sin(angle))
	angular_velocity = clampf(
		velocity.dot(tangent) / maxf(chain_length, 20.0),
		-BOOST_CAP,
		BOOST_CAP,
	)
	if absf(angular_velocity) < 1.2:
		angular_velocity += 1.2 * signf(sin(angle + 0.001))
	boost_t = BOOST_TIME
	active = true
	game.play_sfx("perfect", 0.02)
	game.add_shake(7.0)
	game.invert_t = maxf(game.invert_t, 0.045)
	game.burst_t = 0.3
	game.burst_pos = game.world_to_screen(position)
	game.rings.append({"p": position, "t": 0.32, "max": 40.0})


func _register_sweep_kills(count: int) -> void:
	kill_window_t = 0.24
	kill_window_count += count
	kill_flash_t = maxf(kill_flash_t, 0.3)
	game.add_shake(4.0 + float(count) * 2.6)
	game.hitstop(minf(0.035 + float(count) * 0.012, 0.12))
	game.invert_t = maxf(game.invert_t, 0.028 + float(count) * 0.008)
	game.burst_t = maxf(game.burst_t, 0.32 + float(count) * 0.045)
	game.burst_pos = game.world_to_screen(position)
	for i in 2:
		game.rings.append({
			"p": position,
			"t": 0.24 + i * 0.06,
			"max": 30.0 + i * 18.0 + float(count) * 5.0,
		})
	if kill_window_count >= 2:
		game.labels.append({
			"p": position + Vector2(0, -20),
			"text": "CHAIN SWEEP x%d" % kill_window_count,
			"t": 0.9,
			"big": true,
		})


func threatens(p: Vector2) -> bool:
	return false


func _lock_on_nail() -> void:
	hook_hit = true
	locked = true
	active = false
	velocity = Vector2.ZERO
	angular_velocity = 0.0
	position = nail_position
	swappable = false
	_create_chain_path()
	game.add_shake(8.0)
	game.invert_t = maxf(game.invert_t, 0.035)
	game.rings.append({"p": nail_position, "t": 0.4, "max": 42.0})
	if game.boss_node != null and is_instance_valid(game.boss_node):
		game.boss_node.break_right_chain()


func _create_chain_path() -> void:
	if chain_steps_created:
		return
	chain_steps_created = true
	for i in 7:
		var t := float(i) / 6.0
		var p := nail_position.lerp(pivot, t)
		var rect := Rect2(p.x - 18.0, p.y - 3.0, 36.0, 6.0)
		chain_step_rects.append(rect)
		game._add_static_rect(rect, true)


func _update_transform() -> void:
	position = pivot + Vector2(sin(angle), cos(angle)) * chain_length
	var tangent := Vector2(cos(angle), -sin(angle))
	velocity = tangent * angular_velocity * chain_length


func _draw_body() -> void:
	var pivot_local := pivot - position
	if boost_t > 0.0 or kill_flash_t > 0.0:
		var trail_points := PackedVector2Array()
		for i in 9:
			var trail_angle := angle - angular_velocity * 0.018 * float(i)
			trail_points.append(pivot_local + Vector2(sin(trail_angle), cos(trail_angle)) * chain_length)
		if trail_points.size() >= 2:
			var trail_alpha := maxf(boost_t / BOOST_TIME * 0.7, kill_flash_t / 0.3)
			draw_polyline(trail_points, Color(1.0, 0.32, 0.22, trail_alpha), 6.0)
			draw_polyline(trail_points, Color(1, 1, 1, trail_alpha * 0.9), 2.0)
		for i in 3:
			var ghost_angle := angle - angular_velocity * 0.055 * float(i + 1)
			var ghost := pivot_local + Vector2(sin(ghost_angle), cos(ghost_angle)) * chain_length
			var alpha := (1.0 - float(i) / 4.0) * (boost_t / BOOST_TIME)
			draw_line(pivot_local, ghost, Color(1.0, 0.32, 0.22, alpha * 0.7), 3.0)
			draw_circle(ghost, 10.0, Color(1.0, 0.13, 0.12, alpha * 0.24))
			draw_arc(ghost, 14.0 + i * 3.0, 0.0, TAU, 12, Color(1, 1, 1, alpha * 0.8), 1.0)
	if kill_flash_t > 0.0:
		var flash := kill_flash_t / 0.3
		draw_circle(Vector2.ZERO, 22.0 + (1.0 - flash) * 18.0, Color(1.0, 0.13, 0.12, 0.24 * flash))
		for i in 12:
			var dir := Vector2.from_angle(float(i) * TAU / 12.0 + anim_t * 2.0)
			draw_line(dir * (16.0 + (1.0 - flash) * 10.0), dir * (40.0 + (1.0 - flash) * 26.0), Color.WHITE if i % 2 == 0 else Color(1.0, 0.32, 0.22), 2.0)
		draw_arc(Vector2.ZERO, 25.0 + (1.0 - flash) * 14.0, 0.0, TAU, 20, Color(1, 1, 1, flash), 2.0)
	draw_line(pivot_local, Vector2.ZERO, Color(1, 1, 1, 0.5), 2.0)
	var steps := maxi(5, int(chain_length / 9.0))
	for i in steps:
		var p := pivot_local.lerp(Vector2.ZERO, float(i) / float(steps))
		draw_rect(Rect2(p - Vector2(2, 1), Vector2(4, 2)), Color.WHITE)

	if locked:
		for world_rect in chain_step_rects:
			var rect: Rect2 = world_rect
			var local := Rect2(rect.position - position, rect.size)
			draw_rect(local, Color.BLACK)
			draw_rect(Rect2(local.position + Vector2(1, 1), local.size - Vector2(2, 2)), Color(0.66, 0.66, 0.66))
			draw_rect(Rect2(local.position + Vector2(0, 0), Vector2(local.size.x, 2)), Color.WHITE)
			for k in 3:
				draw_rect(Rect2(local.position + Vector2(6 + k * 11, 2), Vector2(4, 2)), Color.BLACK)

	draw_colored_polygon(PackedVector2Array([
		Vector2(-9, -8), Vector2(9, -8), Vector2(13, 2),
		Vector2(7, 11), Vector2(-7, 11), Vector2(-13, 2),
	]), Color.BLACK)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7, -6), Vector2(7, -6), Vector2(10, 1),
		Vector2(5, 8), Vector2(-5, 8), Vector2(-10, 1),
	]), Color.WHITE)
	draw_rect(Rect2(-4, -2, 8, 5), Color.BLACK)
	draw_line(Vector2(-7, 9), Vector2(-15, 18), Color.WHITE, 4.0)
	draw_line(Vector2(7, 9), Vector2(15, 18), Color.WHITE, 4.0)
	if absf(angular_velocity) > 0.8:
		draw_line(Vector2(-18, 3), Vector2(-28, 7), Color(0.66, 0.08, 0.1), 2.0)
