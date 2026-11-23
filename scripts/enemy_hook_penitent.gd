extends Entity
## Hook Penitent: throws a physical hook through one-way platforms. The hook only
## anchors to walls, crates or heavy bodies; the penitent then reels itself toward
## that solid anchor and shatters on impact.

enum State { IDLE, LOCK, THROW, PULL, STUN, DEAD }

const DETECT_RANGE := 120.0
const LOCK_TIME := 0.58
const HOOK_SPEED := 285.0
const HOOK_MAX_DIST := 175.0
const PULL_SPEED := 250.0
const STUN_TIME := 0.85
const DEATH_TIME := 0.62

var state: int = State.IDLE
var timer: float = 0.0
var hook_dir := Vector2.RIGHT
var hook_position := Vector2.ZERO
var anchor_position := Vector2.ZERO
var anchor_kind: String = ""
var hook_spawn := Vector2.ZERO


func _ready() -> void:
	setup_body(Vector2(16, 20), 2, 1)
	add_to_group("enemy")
	hook_position = position + Vector2(10, 8)


func _physics_process(delta: float) -> void:
	if not alive or game == null or game.game_over:
		return
	var to_p: Vector2 = game.player.position - position
	match state:
		State.IDLE:
			apply_gravity(delta)
			velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
			move_and_slide()
			hook_position = position + Vector2(facing * 11.0, 8.0)
			if (
				to_p.length() < DETECT_RANGE
				and game.has_line_of_sight(position, game.player.position)
				and game.is_world_on_screen(position, 10.0)
			):
				hook_dir = to_p.normalized()
				facing = signf(to_p.x) if absf(to_p.x) > 1.0 else facing
				state = State.LOCK
				timer = LOCK_TIME
				game.play_sfx("windup", 0.04)
		State.LOCK:
			velocity.x = 0.0
			timer -= delta
			hook_position = position + hook_dir * 10.0
			if timer <= 0.0:
				state = State.THROW
				hook_spawn = hook_position
				game.play_sfx("dash", 0.05)
		State.THROW:
			velocity = Vector2.ZERO
			_move_hook(delta)
		State.PULL:
			velocity = (anchor_position - position).normalized() * PULL_SPEED
			position = position.move_toward(anchor_position, PULL_SPEED * delta)
			game.damage_rect(get_hit_rect().grow(1.0), "a hook penitent", self)
			if position.distance_to(anchor_position) <= 8.0:
				state = State.DEAD
				timer = DEATH_TIME
				velocity = Vector2.ZERO
				game.add_shake(8.0)
				game.play_sfx("slam", 0.0)
		State.STUN:
			apply_gravity(delta)
			velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
			move_and_slide()
			timer -= delta
			if timer <= 0.0:
				state = State.IDLE
		State.DEAD:
			velocity = Vector2.ZERO
			timer -= delta
			if timer <= 0.0:
				game.hit_entity(self, "a chain impact")
	queue_redraw()


func _move_hook(delta: float) -> void:
	var travel := hook_dir * HOOK_SPEED * delta
	var steps := maxi(1, int(ceil(travel.length() / 4.0)))
	var step := travel / float(steps)
	for _i in steps:
		var next := hook_position + step
		if game.solid_at(next):
			_anchor_hook(next, "solid")
			return
		for e in game.get_entities():
			if e == self or not e.alive:
				continue
			var is_solid_body: bool = e.is_in_group("crate")
			if not is_solid_body and e.get_script() != null:
				is_solid_body = e.get_script().resource_path.get_file() == "enemy_heavy.gd"
			if is_solid_body and e.get_hit_rect().grow(3.0).has_point(next):
				_anchor_hook(e.position, "body")
				return
		hook_position = next
		game.damage_rect(Rect2(hook_position - Vector2(4, 4), Vector2(8, 8)),
			"a hook penitent", self)
		if hook_position.distance_to(hook_spawn) >= HOOK_MAX_DIST:
			state = State.STUN
			timer = STUN_TIME
			hook_position = position + Vector2(facing * 11.0, 8.0)
			return


func _anchor_hook(at: Vector2, kind: String) -> void:
	hook_position = at
	anchor_position = at
	anchor_kind = kind
	state = State.PULL
	game.add_shake(3.0)
	game.rings.append({"p": at, "t": 0.22, "max": 15.0})


func on_swapped() -> void:
	if state == State.THROW or state == State.PULL:
		var was_pulling := state == State.PULL
		state = State.STUN
		timer = STUN_TIME
		hook_position = position + Vector2(facing * 11.0, 8.0)
		velocity = Vector2.ZERO
		if was_pulling:
			# Swapping must interrupt the reel, not transfer its upward pull
			# velocity into the player and launch them toward the ceiling.
			game.player.velocity = Vector2.ZERO
		game.play_sfx("fail", 0.05)


func threatens(p: Vector2) -> bool:
	if state == State.LOCK:
		if timer >= 0.22:
			return false
		var a := position + hook_dir * 10.0
		var b := a + hook_dir * 70.0
		return _distance_to_segment(p, a, b) < 10.0
	if state == State.THROW:
		var probe := Rect2(hook_position + hook_dir * 18.0 - Vector2(5, 5), Vector2(10, 10))
		return probe.has_point(p)
	if state == State.PULL:
		var probe := get_hit_rect()
		probe.position += (anchor_position - position).normalized() * 18.0
		return probe.grow(4.0).has_point(p)
	return false


func _distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	if ab.length_squared() <= 0.001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _draw_body() -> void:
	var crouch := 2.0 if state == State.LOCK else 0.0
	var lean := 2.0 if state == State.PULL else 0.0
	var white := Color.WHITE
	var gray := Color(0.66, 0.66, 0.66)
	var dark := Color.BLACK
	var spool_glow := state == State.LOCK or state == State.PULL

	# Chain is drawn in local space from the spool to the hook.
	var spool := Vector2(-8, -5 + crouch)
	var hook_local := hook_position - position
	draw_line(spool, hook_local, Color(0.33, 0.33, 0.33), 2.0)
	for i in 7:
		var q := spool.lerp(hook_local, float(i) / 7.0)
		draw_rect(Rect2(q - Vector2(2, 1), Vector2(4, 2)),
			Color(1.0, 0.32, 0.22) if spool_glow else white)

	# Hood and long bent robe.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4 + lean, -13 + crouch), Vector2(0 + lean, -16 + crouch),
		Vector2(4 + lean, -13 + crouch), Vector2(6 + lean, -8 + crouch),
		Vector2(10 + lean, -4 + crouch), Vector2(9 + lean, 3),
		Vector2(6 + lean, 10), Vector2(2 + lean, 7),
		Vector2(-1 + lean, 11), Vector2(-4 + lean, 7),
		Vector2(-7 + lean, 9), Vector2(-6 + lean, 2),
		Vector2(-5 + lean, -6 + crouch),
	]), dark)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-3 + lean, -12 + crouch), Vector2(0 + lean, -14 + crouch),
		Vector2(3 + lean, -12 + crouch), Vector2(5 + lean, -7 + crouch),
		Vector2(8 + lean, -3 + crouch), Vector2(7 + lean, 2),
		Vector2(5 + lean, 8), Vector2(2 + lean, 5),
		Vector2(-1 + lean, 9), Vector2(-3 + lean, 5),
		Vector2(-5 + lean, 7), Vector2(-4 + lean, 1),
		Vector2(-4 + lean, -5 + crouch),
	]), white)
	draw_colored_polygon(PackedVector2Array([
		Vector2(2 + lean, -11 + crouch), Vector2(5 + lean, -7 + crouch),
		Vector2(7 + lean, -2 + crouch), Vector2(5 + lean, 8),
		Vector2(4 + lean, 3), Vector2(3 + lean, -7 + crouch),
	]), gray)
	draw_rect(Rect2(-3 + lean, -11 + crouch, 6, 5), dark)
	draw_rect(Rect2(-1 + lean, -8 + crouch, 2, 2),
		Color(1.0, 0.32, 0.22) if spool_glow else Color(0.66, 0.08, 0.1))

	# Chain spool fixed to the left shoulder.
	draw_circle(spool, 6.0, dark)
	draw_circle(spool, 5.0, gray)
	draw_circle(spool, 2.0, Color(1.0, 0.32, 0.22) if spool_glow else white)
	draw_line(spool + Vector2(-4, 0), spool + Vector2(4, 0), white, 1.0)
	draw_line(spool + Vector2(0, -4), spool + Vector2(0, 4), white, 1.0)

	# Boots and outstretched hook arm.
	draw_rect(Rect2(-5 + lean, 8, 4, 3), dark)
	draw_rect(Rect2(-4 + lean, 8, 3, 2), white)
	draw_rect(Rect2(5 + lean, 7, 4, 3), dark)
	draw_rect(Rect2(5 + lean, 7, 3, 2), gray)
	draw_line(Vector2(3 + lean, -3), Vector2(9 + lean, 2 + crouch), white, 2.0)

	_draw_hook(hook_local, facing)
	if state == State.LOCK:
		draw_dashed_line(Vector2.ZERO, hook_dir * 230.0, Color(0.66, 0.08, 0.1), 1.0, 4.0)
	elif state == State.PULL:
		for i in 3:
			draw_line(Vector2(-13 - i * 4, -3 + i * 4),
				Vector2(-26 - i * 6, -3 + i * 4), Color(1, 1, 1, 0.45), 1.0)
	elif state == State.STUN:
		draw_rect(Rect2(-9, -19, 18, 2), Color(0.66, 0.08, 0.1), false, 1.0)
	elif state == State.DEAD:
		draw_line(Vector2(-8, -12), Vector2(8, 10), Color(0.66, 0.08, 0.1), 2.0)
		draw_line(Vector2(8, -12), Vector2(-8, 10), Color(0.66, 0.08, 0.1), 2.0)


func _draw_hook(at: Vector2, side: float) -> void:
	var s := signf(side) if absf(side) > 0.1 else 1.0
	draw_rect(Rect2(at + Vector2(-1, -5), Vector2(3, 8)), Color.BLACK)
	if s > 0.0:
		draw_rect(Rect2(at + Vector2(2, 1), Vector2(5, 3)), Color.BLACK)
		draw_rect(Rect2(at + Vector2(2, 1), Vector2(4, 1)), Color(0.66, 0.66, 0.66))
	else:
		draw_rect(Rect2(at + Vector2(-7, 1), Vector2(5, 3)), Color.BLACK)
		draw_rect(Rect2(at + Vector2(-6, 1), Vector2(4, 1)), Color(0.66, 0.66, 0.66))
	draw_rect(Rect2(at + Vector2(-1, -5), Vector2(1, 7)), Color.WHITE)
