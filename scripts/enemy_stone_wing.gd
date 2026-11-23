extends Entity
## Stone Wing: circles a fixed patch of air, locks onto the player, then charges
## in a straight line. If its charge reaches a wall it petrifies and shatters.

enum State { CIRCLE, WINDUP, DASH, PETRIFY }

const ORBIT_RADIUS := 30.0
const ORBIT_SPEED := 1.65
const DETECT_RANGE := 105.0
const DASH_SPEED := 220.0
const WINDUP_TIME := 0.46
const DASH_TIME := 0.62
const PETRIFY_TIME := 0.72

var state: int = State.CIRCLE
var timer: float = 0.0
var orbit_center := Vector2.ZERO
var orbit_angle: float = 0.0
var orbit_radius: float = ORBIT_RADIUS
var dash_dir := Vector2.RIGHT
var impact_speed: float = 0.0
var attack_cooldown: float = 0.7


func _ready() -> void:
	setup_body(Vector2(40, 14), 2, 0)
	swappable = true
	add_to_group("enemy")
	orbit_center = position
	orbit_angle = randf_range(0.0, TAU)


func _physics_process(delta: float) -> void:
	if not alive or game == null or game.game_over:
		return
	var to_p: Vector2 = game.player.position - position
	match state:
		State.CIRCLE:
			attack_cooldown = maxf(attack_cooldown - delta, 0.0)
			orbit_angle += ORBIT_SPEED * delta
			orbit_radius = move_toward(orbit_radius, ORBIT_RADIUS, 95.0 * delta)
			position = orbit_center + Vector2(
				cos(orbit_angle) * orbit_radius,
				sin(orbit_angle) * orbit_radius * 0.46)
			velocity = Vector2.ZERO
			if (
				attack_cooldown <= 0.0 and to_p.length() < DETECT_RANGE
				and game.has_line_of_sight(position, game.player.position)
				and game.is_world_on_screen(position, 10.0)
			):
				state = State.WINDUP
				timer = WINDUP_TIME
				dash_dir = to_p.normalized()
				if absf(dash_dir.x) < 0.2:
					dash_dir.x = 1.0 if to_p.x >= 0.0 else -1.0
					dash_dir = dash_dir.normalized()
				game.play_sfx("windup", 0.08)
		State.WINDUP:
			velocity = Vector2.ZERO
			timer -= delta
			if timer <= 0.0:
				state = State.DASH
				velocity = dash_dir * DASH_SPEED
				timer = DASH_TIME
				game.play_sfx("dash", 0.03)
		State.DASH:
			timer -= delta
			if _move_dash(delta):
				pass
			elif timer <= 0.0:
				orbit_center = position
				orbit_angle = 0.0
				orbit_radius = 0.0
				attack_cooldown = 1.15
				state = State.CIRCLE
		State.PETRIFY:
			velocity = Vector2.ZERO
			timer -= delta
			if timer <= 0.0:
				game.hit_entity(self, "a stone impact")
	queue_redraw()


func _move_dash(delta: float) -> bool:
	var travel := velocity * delta
	var steps := maxi(1, int(ceil(travel.length() / 4.0)))
	var step := travel / float(steps)
	for _i in steps:
		var next := position + step
		if _body_touches_solid(next):
			if step.length() > 0.1:
				position = next - step.normalized() * 2.0
			_impact()
			return true
		for e in game.get_entities():
			if e == self or not e.alive:
				continue
			var is_solid_body: bool = e.is_in_group("crate")
			if not is_solid_body and e.get_script() != null:
				is_solid_body = e.get_script().resource_path.get_file() == "enemy_heavy.gd"
			if is_solid_body and get_hit_rect().grow(2.0).has_point(e.position):
				position = next
				_impact()
				return true
		position = next
		game.damage_rect(get_hit_rect().grow(1.0), "a stone wing", self)
	return false


func _impact() -> void:
	impact_speed = velocity.length()
	velocity = Vector2.ZERO
	state = State.PETRIFY
	timer = PETRIFY_TIME
	game.add_shake(4.0)
	game.play_sfx("slam", 0.06)


func _body_touches_solid(at: Vector2) -> bool:
	for offset in [
		Vector2.ZERO,
		Vector2(-half.x, 0),
		Vector2(half.x, 0),
		Vector2(0, -half.y),
		Vector2(0, half.y),
	]:
		if game.solid_at(at + offset):
			return true
	return false


func on_swapped() -> void:
	if state == State.CIRCLE:
		# The swap placed this body at the player's old position. Rebase the
		# orbit there so the next CIRCLE update cannot snap it back.
		orbit_center = position
		orbit_angle = 0.0
		orbit_radius = 0.0
		velocity = Vector2.ZERO
		attack_cooldown = maxf(attack_cooldown, 0.35)
	elif state == State.DASH:
		if velocity.length() > 1.0:
			dash_dir = velocity.normalized()
		impact_speed = velocity.length()
		game.add_shake(3.0)
	elif state == State.WINDUP:
		dash_dir = (game.player.position - position).normalized()


func threatens(p: Vector2) -> bool:
	if state == State.DASH:
		var probe := Rect2(get_hit_rect().position + velocity * 0.16, get_hit_rect().size)
		return probe.grow(5.0).has_point(p)
	if state == State.WINDUP and timer < 0.2:
		# Warn only if the locked dash line will actually reach the player.
		for t in [0.10, 0.22]:
			var center := position + dash_dir * DASH_SPEED * float(t)
			var probe := Rect2(center - half, half * 2.0)
			if probe.grow(5.0).has_point(p):
				return true
	return false


func _draw_body() -> void:
	var f := signf(dash_dir.x) if absf(dash_dir.x) > 0.1 else facing
	var flap := sin(anim_t * 11.0) if state != State.PETRIFY else 0.0
	var bank := sin(anim_t * 4.0) * 1.4 if state == State.CIRCLE else 0.0
	var body := Rect2(-5, -4 + bank, 10, 9)
	var wing_y := -6.0 + bank - flap * 1.5

	if state == State.PETRIFY:
		draw_rect(Rect2(-10, -8, 20, 16), Color(0.33, 0.33, 0.33))
		draw_rect(Rect2(-7, -5, 14, 10), Color(0.66, 0.66, 0.66))
		draw_line(Vector2(-7, -5), Vector2(7, 5), Color.BLACK, 1.0)
		draw_line(Vector2(7, -5), Vector2(-7, 5), Color.BLACK, 1.0)
		return

	draw_polyline(PackedVector2Array([
		Vector2(-4, -2 + bank), Vector2(-12, wing_y + 2.0),
		Vector2(-20, -3 + bank), Vector2(-13, 2 + bank), Vector2(-5, 1 + bank),
	]), Color.WHITE, 2.0)
	draw_polyline(PackedVector2Array([
		Vector2(4, -2 + bank), Vector2(12, wing_y + 2.0),
		Vector2(20, -3 + bank), Vector2(13, 2 + bank), Vector2(5, 1 + bank),
	]), Color.WHITE, 2.0)
	draw_line(Vector2(-5, 0 + bank), Vector2(-16, 1 + bank), Color.WHITE, 3.0)
	draw_line(Vector2(5, 0 + bank), Vector2(16, 1 + bank), Color.WHITE, 3.0)

	draw_rect(body.grow(1.0), Color.BLACK)
	draw_rect(body, Color(0.66, 0.66, 0.66))
	draw_rect(Rect2(-4, -3 + bank, 8, 4), Color.BLACK)
	draw_rect(Rect2(f * 2.0, -2 + bank, 2, 1),
		Color(1.0, 0.32, 0.22) if state == State.WINDUP else Color(0.66, 0.08, 0.1))
	draw_rect(Rect2(-2, 1 + bank, 4, 3), Color.WHITE)

	if state == State.WINDUP:
		draw_dashed_line(Vector2.ZERO, dash_dir * 300.0, Color(0.66, 0.08, 0.1), 1.0, 4.0)
	elif state == State.DASH:
		for i in 3:
			var y := -4.0 + i * 4.0
			draw_line(Vector2(-12 - i * 3, y), Vector2(-27 - i * 4, y), Color(1, 1, 1, 0.55), 1.0)
