extends Node2D
## LEVEL 19 boss: the headless Third Nail.
## Death is not caused by a generic hazard. The right-arm counterweight reverses
## the three broken chains, pulls the body into its own execution ring and
## shatters the red core.

enum State {
	LEFT_LOCKED,
	LEFT_BROKEN,
	RIGHT_BROKEN,
	PULLING,
	BOMB_WINDOW,
	SLAM_WINDUP,
	FALLING,
	RECOVER,
	CHAIN_SNAP,
	DEFEATED,
}

const DRAW_SCALE := 0.58
const LEFT_BRIDGE := Rect2(9 * 16, 59 * 16, 13 * 16, 6)
const RIGHT_BRIDGE := Rect2(15 * 16, 38 * 16, 8 * 16, 6)
const WINDUP_TIME := 1.1
const FALL_ACCEL := 840.0
const FALL_LIMIT := 56.0
const CHAIN_SNAP_TIME := 1.28
const PULL_TIME := 0.42
const BOMB_WINDOW_TIME := 1.35
const RECOVER_TIME := 1.15
const BOMB_LEFT := Vector2(88, 224)
const BOMB_RIGHT := Vector2(408, 224)

const WHITE := Color.WHITE
const BLACK := Color.BLACK
const BLOOD := Color(0.66, 0.08, 0.1)
const HOT := Color(1.0, 0.32, 0.22)

var game = null
var state: int = State.LEFT_LOCKED
var max_health: int = 3
var health: int = 3
var health_visible: bool = false
var health_flash: float = 0.0
var fight_started: bool = false
var hit_count: int = 0
var fall_offset: float = 0.0
var fall_speed: float = 0.0
var windup_t: float = 0.0
var windup_beat: int = -1
var pull_t: float = 0.0
var pull_start := Vector2.ZERO
var bomb_window_t: float = 0.0
var recover_t: float = 0.0
var impact_bomb = null
var bombs: Array = []
var explosion_t: float = 0.0
var chain_t: float = 0.0
var pulse_t: float = 0.0
var pull_k: float = 0.0
var defeated: bool = false
var left_bridge_created: bool = false
var right_bridge_created: bool = false
var nail_flash: float = 0.0
var anim_t: float = 0.0


func _ready() -> void:
	z_index = 1


func _process(delta: float) -> void:
	anim_t += delta
	queue_redraw()


func _physics_process(delta: float) -> void:
	if game == null or game.game_over:
		return
	nail_flash = maxf(nail_flash - delta, 0.0)
	health_flash = maxf(health_flash - delta, 0.0)
	explosion_t = maxf(explosion_t - delta, 0.0)
	pulse_t += delta
	match state:
		State.LEFT_BROKEN:
			pass
		State.RIGHT_BROKEN:
			_try_start_fight()
		State.PULLING:
			pull_t -= delta
			var pull_k := 1.0 - clampf(pull_t / PULL_TIME, 0.0, 1.0)
			if game.player != null and game.player.alive:
				game.player.velocity = Vector2.ZERO
				game.player.position = pull_start.lerp(
					_pull_target(),
					ease(pull_k, 0.35),
				)
			if pull_t <= 0.0:
				_pin_player()
				_spawn_bomb_wave()
		State.BOMB_WINDOW:
			var bomb = _bomb_under_boss()
			if bomb != null:
				_begin_slam(bomb)
			else:
				_pin_player()
				bomb_window_t -= delta
				var urgency := 1.0 - clampf(bomb_window_t / BOMB_WINDOW_TIME, 0.0, 1.0)
				game.add_shake(0.4 + urgency * 2.4)
				if bomb_window_t <= 0.0:
					_begin_slam(null)
		State.SLAM_WINDUP:
			windup_t -= delta
			pulse_t += delta * 9.0
			var charge_k := _windup_k()
			game.add_shake(2.0 + charge_k * 4.0)
			var beat := int(charge_k * 6.0)
			if beat != windup_beat:
				windup_beat = beat
				game.rings.append({
					"p": position + Vector2(0, -92),
					"t": 0.24,
					"max": 16.0 + charge_k * 30.0,
				})
				if charge_k > 0.66:
					game.invert_t = maxf(game.invert_t, 0.018)
			if windup_t <= 0.0:
				state = State.FALLING
				fall_speed = 55.0
				game.play_sfx("dash", 0.0)
		State.FALLING:
			fall_speed = minf(fall_speed + FALL_ACCEL * delta, 520.0)
			fall_offset = minf(fall_offset + fall_speed * delta, FALL_LIMIT)
			game.damage_rect(get_fall_rect(), "the third nail")
			if fall_offset >= FALL_LIMIT - 0.01:
				_resolve_slam()
		State.RECOVER:
			fall_offset = move_toward(fall_offset, 0.0, 115.0 * delta)
			recover_t -= delta
			if recover_t <= 0.0:
				_begin_pull()
		State.CHAIN_SNAP:
			chain_t += delta
			pull_k = clampf(chain_t / CHAIN_SNAP_TIME, 0.0, 1.0)
			var beat := int(chain_t * 9.0)
			if beat != int((chain_t - delta) * 9.0):
				game.add_shake(5.0 + pull_k * 4.0)
				game.rings.append({
					"p": position + Vector2(0, 18 + 54 * pull_k),
					"t": 0.26,
					"max": 24.0 + 34.0 * pull_k,
				})
				game.invert_t = maxf(game.invert_t, 0.025)
			if chain_t >= CHAIN_SNAP_TIME:
				_shatter_core()


func break_left_chain() -> void:
	if state != State.LEFT_LOCKED:
		return
	state = State.LEFT_BROKEN
	nail_flash = 0.45
	_create_bridge(LEFT_BRIDGE)
	left_bridge_created = true
	game.play_sfx("slam", 0.0)
	game.add_shake(8.0)
	game.hitstop(0.1)
	game.invert_t = 0.06
	game.rings.append({"p": _left_anchor(), "t": 0.4, "max": 42.0})
	if game.chain_pendulum != null and is_instance_valid(game.chain_pendulum):
		game.chain_pendulum.activate()


func break_right_chain() -> void:
	if state != State.LEFT_BROKEN:
		return
	state = State.RIGHT_BROKEN
	nail_flash = 0.45
	_create_bridge(RIGHT_BRIDGE)
	right_bridge_created = true
	if game.boss_lift != null and is_instance_valid(game.boss_lift):
		game.boss_lift.activate()
	game.play_sfx("slam", 0.02)
	game.add_shake(7.0)
	game.hitstop(0.09)
	game.rings.append({"p": _right_anchor(), "t": 0.4, "max": 36.0})


func _try_start_fight() -> void:
	if fight_started or state != State.RIGHT_BROKEN:
		return
	if game.player == null or game.boss_lift == null or not game.boss_lift.activated:
		return
	var p: Vector2 = game.player.position
	if p.y > 258.0 or p.x < 8 * 16 or p.x > 22 * 16:
		return
	fight_started = true
	health_visible = true
	health = max_health
	hit_count = 0
	game.add_shake(8.0)
	game.invert_t = maxf(game.invert_t, 0.05)
	game.rings.append({"p": position + Vector2(0, 10), "t": 0.55, "max": 62.0})
	_begin_pull()


func _begin_pull() -> void:
	if state == State.DEFEATED:
		return
	_clear_bombs()
	impact_bomb = null
	fall_offset = 0.0
	fall_speed = 0.0
	pull_t = PULL_TIME
	pull_start = game.player.position
	state = State.PULLING
	game.play_sfx("windup", 0.04)
	game.add_shake(5.0)
	for i in 3:
		game.rings.append({
			"p": pull_start,
			"t": 0.22 + i * 0.05,
			"max": 24.0 + i * 12.0,
		})


func _pull_target() -> Vector2:
	var target := Vector2(position.x, 15.0 * 16.0 - game.player.half.y - 0.1)
	return target


func _pin_player() -> void:
	if game.player == null or not game.player.alive:
		return
	game.player.velocity = Vector2.ZERO
	game.player.position = _pull_target()


func _spawn_bomb_wave() -> void:
	_clear_bombs()
	state = State.BOMB_WINDOW
	bomb_window_t = BOMB_WINDOW_TIME
	var count := 2 if hit_count % 2 == 0 else 1
	var points := [BOMB_LEFT, BOMB_RIGHT]
	if count == 1:
		points = [BOMB_RIGHT if hit_count % 4 == 1 else BOMB_LEFT]
	for point in points:
		var bomb = game.spawn_boss_bomb(point)
		bomb.boss = self
		bombs.append(bomb)
		game.rings.append({"p": point, "t": 0.4, "max": 32.0})
	game.play_sfx("door", 0.0)
	game.add_shake(4.0)


func _bomb_under_boss():
	for bomb in bombs:
		if bomb == null or not is_instance_valid(bomb) or bomb.detonating:
			continue
		if absf(bomb.position.x - position.x) < 48.0 and bomb.position.y > 200.0:
			return bomb
	return null


func is_waiting_for_bomb() -> bool:
	return state == State.BOMB_WINDOW


func needs_wheel_hint() -> bool:
	return state == State.LEFT_LOCKED


func _begin_slam(bomb = null) -> void:
	if state != State.BOMB_WINDOW:
		return
	impact_bomb = bomb
	state = State.SLAM_WINDUP
	fall_offset = 0.0
	fall_speed = 0.0
	windup_t = WINDUP_TIME
	windup_beat = -1
	game.play_sfx("windup", 0.0)
	game.add_shake(6.0)
	game.rings.append({"p": position + Vector2(0, -92), "t": 0.4, "max": 40.0})


func _resolve_slam() -> void:
	var hit_pos := Vector2(position.x, 15.0 * 16.0 - 6.0)
	var valid_bomb = (
		impact_bomb != null
		and is_instance_valid(impact_bomb)
		and not impact_bomb.detonating
		and absf(impact_bomb.position.x - position.x) < 52.0
	)
	if valid_bomb:
		impact_bomb.detonate()
		_take_bomb_hit(hit_pos)
	else:
		game.play_sfx("slam", 0.0)
		game.add_shake(12.0)
		game.invert_t = maxf(game.invert_t, 0.08)
	_clear_bombs()
	impact_bomb = null
	if health <= 0:
		_start_chain_snap()
	else:
		state = State.RECOVER
		recover_t = RECOVER_TIME
		fall_speed = 0.0


func _take_bomb_hit(hit_pos: Vector2) -> void:
	health = maxi(health - 1, 0)
	hit_count += 1
	health_flash = 0.8
	explosion_t = 0.62
	game.spawn_blast(hit_pos, 46.0, 0.025, "a bomb")
	game.play_sfx("explode", 0.0)
	game.play_sfx("slam", 0.0)
	game.add_shake(18.0)
	game.hitstop(0.17)
	game.invert_t = maxf(game.invert_t, 0.16)
	game.burst_t = 0.55
	game.burst_pos = game.world_to_screen(hit_pos)
	game._spawn_debris(hit_pos, 42, 1.1)
	game._splat(hit_pos + Vector2(0, 8), 1.0)
	for i in 6:
		game.rings.append({
			"p": hit_pos,
			"t": 0.32 + i * 0.07,
			"max": 34.0 + i * 18.0,
		})


func _clear_bombs() -> void:
	for bomb in bombs:
		if bomb != null and is_instance_valid(bomb):
			bomb.queue_free()
	bombs.clear()


func _start_chain_snap() -> void:
	if state == State.CHAIN_SNAP or state == State.DEFEATED:
		return
	_clear_bombs()
	state = State.CHAIN_SNAP
	chain_t = 0.0
	pull_k = 0.0
	game.play_sfx("slam", 0.0)
	game.hitstop(0.13)
	game.invert_t = 0.11
	game.add_shake(13.0)
	game.burst_t = 0.4
	game.burst_pos = game.world_to_screen(position + Vector2(0, 32))
	for i in 3:
		game.rings.append({
			"p": position + Vector2((i - 1) * 30.0, 22.0),
			"t": 0.42 + i * 0.08,
			"max": 36.0 + i * 14.0,
		})


func _shatter_core() -> void:
	if defeated:
		return
	defeated = true
	state = State.DEFEATED
	pull_k = 1.0
	health = 0
	game.boss_defeated = true
	game.play_sfx("perfect", 0.0)
	game.play_sfx("slam", 0.0)
	game.add_shake(17.0)
	game.invert_t = 0.19
	game.hitstop(0.24)
	game.burst_t = 0.55
	game.burst_pos = game.world_to_screen(position + Vector2(0, 28))
	game._spawn_debris(position + Vector2(0, 24), 34, 0.9)
	game._splat(position + Vector2(0, 52), 1.0)
	for i in 5:
		game.rings.append({
			"p": position + Vector2(0, 28),
			"t": 0.42 + i * 0.07,
			"max": 34.0 + i * 17.0,
		})
	game.labels.append({"p": position + Vector2(0, -32), "text": "CHAIN REVERSAL", "t": 1.8, "big": true})


func _create_bridge(rect: Rect2) -> void:
	game._add_static_rect(rect, true)


func _left_anchor() -> Vector2:
	if game != null and game.bone_nail != null and is_instance_valid(game.bone_nail):
		return game.bone_nail.position
	if game != null and game.chain_wheel != null and is_instance_valid(game.chain_wheel):
		return game.chain_wheel.position
	return Vector2(12 * 16 + 8, 72 * 16 + 8)


func _right_anchor() -> Vector2:
	if game != null and game.hook_nail != Vector2.ZERO:
		return game.hook_nail
	return Vector2(22 * 16 + 8, 47 * 16 + 8)


func get_fall_rect() -> Rect2:
	return Rect2(position + Vector2(-106, -72 + fall_offset), Vector2(212, 226))


func _windup_k() -> float:
	return clampf(1.0 - windup_t / WINDUP_TIME, 0.0, 1.0)


func threatens(p: Vector2) -> bool:
	if state != State.FALLING:
		return false
	var probe := get_fall_rect()
	probe.position.y += 28.0
	return probe.grow(5.0).has_point(p)


func _draw() -> void:
	if state == State.SLAM_WINDUP:
		_draw_fall_warning(_windup_k())
	elif state == State.FALLING:
		_draw_fall_warning(1.0)
	elif state == State.BOMB_WINDOW:
		_draw_bomb_window_fx(1.0 - clampf(bomb_window_t / BOMB_WINDOW_TIME, 0.0, 1.0))
	_draw_chains()

	var body_offset := Vector2.ZERO
	var body_rotation := 0.0
	var body_scale := Vector2(DRAW_SCALE, DRAW_SCALE)
	if state == State.SLAM_WINDUP:
		var k := _windup_k()
		body_rotation = sin(anim_t * 36.0) * (0.012 + 0.018 * k)
		body_offset = Vector2(sin(anim_t * 47.0) * 2.0 * k, -12.0 * k)
		body_scale = Vector2(
			DRAW_SCALE * (1.0 - 0.1 * k),
			DRAW_SCALE * (1.0 + 0.16 * k),
		)
	elif state == State.FALLING:
		body_rotation = 0.12
		body_offset.y = fall_offset
	elif state == State.RECOVER:
		body_rotation = sin(anim_t * 31.0) * 0.045
		body_offset.y = fall_offset
	elif state == State.PULLING or state == State.BOMB_WINDOW:
		body_rotation = sin(anim_t * 19.0) * 0.018
	elif state == State.CHAIN_SNAP:
		body_rotation = 0.12 - 0.2 * pull_k
		body_offset.y = fall_offset - 18.0 * sin(pull_k * PI)
		body_scale = Vector2(DRAW_SCALE * (1.0 + 0.08 * sin(pull_k * PI)), DRAW_SCALE * (1.0 - 0.11 * pull_k))
	elif state == State.DEFEATED:
		body_rotation = 0.08
		body_offset.y = 22.0
		body_scale = Vector2(DRAW_SCALE * 1.03, DRAW_SCALE * 0.89)

	draw_set_transform(body_offset, body_rotation, body_scale)
	_draw_boss_body()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if left_bridge_created:
		_draw_fallen_arm(LEFT_BRIDGE)
	if right_bridge_created:
		_draw_fallen_arm(RIGHT_BRIDGE)
	_draw_nail(_right_anchor(), state != State.LEFT_LOCKED and state != State.LEFT_BROKEN)
	_draw_nail(Vector2(position.x, position.y - 92), state >= State.FALLING)
	if state == State.SLAM_WINDUP:
		_draw_windup_fx(_windup_k())
	elif state == State.CHAIN_SNAP:
		_draw_reversal_fx(pull_k)
	elif state == State.DEFEATED:
		_draw_core_shards()
	if explosion_t > 0.0:
		_draw_bomb_hit_fx(1.0 - explosion_t / 0.62)


func _draw_fall_warning(k: float) -> void:
	var local := Rect2(get_fall_rect().position - position, get_fall_rect().size)
	var pulse := 0.55 + 0.45 * sin(anim_t * 26.0)
	var alpha := 0.035 + 0.11 * k + 0.035 * pulse * k
	draw_rect(local, Color(0.66, 0.08, 0.1, alpha))
	for i in range(0, 8):
		var x := local.position.x + 14.0 + i * 28.0
		draw_line(
			Vector2(x, local.position.y + 8.0),
			Vector2(x - 10.0, local.end.y - 8.0),
			Color(0.66, 0.08, 0.1, 0.10 + 0.18 * k),
			1.0,
		)
	var border := HOT if k > 0.7 and pulse > 0.5 else BLOOD
	draw_rect(local.grow(1.0 + 2.0 * k), border, false, 2.0)
	draw_rect(local.grow(5.0 + 3.0 * k), Color(1, 1, 1, 0.12 + 0.35 * k), false, 1.0)
	var top := Vector2(local.get_center().x, local.position.y)
	draw_line(top - Vector2(20.0, 0.0), top + Vector2(20.0, 0.0), WHITE, 1.0)


func _draw_bomb_window_fx(k: float) -> void:
	var target := _pull_target() - position
	var pulse := 0.5 + 0.5 * sin(anim_t * (14.0 + k * 16.0))
	draw_line(Vector2(0, 8), target, Color(0.66, 0.08, 0.1, 0.25 + 0.45 * k), 2.0)
	draw_circle(target, 18.0 - k * 7.0 + pulse * 2.0, Color(1.0, 0.13, 0.12, 0.12 + 0.18 * k))
	draw_arc(target, 28.0 - k * 10.0, 0.0, TAU, 20, Color(1, 1, 1, 0.35 + 0.45 * k), 1.0)
	for i in 4:
		var a := anim_t * 1.2 + i * TAU / 4.0
		var p := target + Vector2.from_angle(a) * (30.0 - k * 12.0)
		draw_line(p, p + Vector2.from_angle(a) * (10.0 + 18.0 * k), HOT, 2.0)


func _draw_windup_fx(k: float) -> void:
	var nail := Vector2(0, -92)
	var core := Vector2(0, -7)
	var pulse := 0.5 + 0.5 * sin(anim_t * 24.0)
	for i in 4:
		var a := anim_t * (1.2 + i * 0.18) + i * TAU / 4.0
		var inner := nail + Vector2.from_angle(a) * (13.0 + 5.0 * pulse)
		var outer := nail + Vector2.from_angle(a) * (25.0 + 24.0 * k + 5.0 * pulse)
		draw_line(inner, outer, Color(0.66, 0.08, 0.1, 0.45 + 0.45 * k), 2.0)
	draw_line(nail, core, Color(1, 1, 1, 0.16 + 0.34 * k), 1.0)
	var radius := 7.0 + 14.0 * k + pulse * 2.0
	draw_circle(nail, radius, Color(1.0, 0.13, 0.12, 0.16 + 0.22 * k))
	draw_circle(nail, radius * 0.45, HOT if k > 0.72 else BLOOD)


func _draw_bomb_hit_fx(k: float) -> void:
	var center := Vector2(0, 130)
	var fade := clampf(1.0 - k, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(anim_t * 41.0)
	for i in 3:
		var radius := 12.0 + k * (48.0 + i * 18.0)
		draw_circle(center, radius, Color(1.0, 0.13, 0.12, (0.22 - i * 0.055) * fade))
		draw_arc(center, radius, 0.0, TAU, 28, Color(1, 1, 1, 0.75 * fade), 2.0)
	for i in 16:
		var angle := float(i) * TAU / 16.0 + anim_t * 0.4
		var inner := center + Vector2.from_angle(angle) * (18.0 + k * 38.0)
		var outer := center + Vector2.from_angle(angle) * (42.0 + k * (74.0 + pulse * 16.0))
		draw_line(inner, outer, WHITE if i % 2 == 0 else HOT, 2.0)
	draw_circle(center, 10.0 + 16.0 * fade, WHITE)
	draw_circle(center, 18.0 * fade, Color(1.0, 0.32, 0.22, 0.9))
	draw_line(center - Vector2(44, 0), center + Vector2(44, 0), Color(1, 1, 1, 0.85 * fade), 2.0)
	draw_line(center - Vector2(0, 44), center + Vector2(0, 44), Color(1, 1, 1, 0.85 * fade), 2.0)


func _draw_chains() -> void:
	if state == State.LEFT_LOCKED:
		_draw_chain(Vector2(-66, -76), _left_anchor() - position, 2.0)
	if state == State.LEFT_LOCKED or state == State.LEFT_BROKEN:
		_draw_chain(Vector2(66, -76), _right_anchor() - position, 2.0)
	if state < State.DEFEATED:
		_draw_chain(Vector2(0, -122), Vector2(0, -190), 2.0)


func _draw_chain(a: Vector2, b: Vector2, width: float) -> void:
	draw_line(a, b, Color(1, 1, 1, 0.55), width)
	var length := a.distance_to(b)
	var steps := maxi(3, int(length / 10.0))
	for i in steps:
		var p := a.lerp(b, float(i) / float(steps))
		draw_rect(Rect2(p - Vector2(2, 1), Vector2(4, 2)), WHITE)


func _draw_reversal_fx(k: float) -> void:
	var core := Vector2(0, 10)
	var sources := [
		_left_anchor() - position,
		_right_anchor() - position,
		Vector2(0, -190),
	]
	for i in sources.size():
		var a: Vector2 = sources[i]
		var jitter := Vector2(sin(anim_t * 31.0 + i) * 3.0, cos(anim_t * 27.0 + i) * 2.0)
		draw_line(a, core + jitter, HOT, 5.0)
		draw_line(a, core + jitter, WHITE, 1.5)
	var r := 8.0 + 24.0 * k + sin(anim_t * 28.0) * 3.0
	draw_circle(core, r, Color(1, 0.13, 0.12, 0.32))
	draw_circle(core, r * 0.55, HOT)
	draw_rect(Rect2(-r, -1.5, r * 2.0, 3.0), WHITE)
	draw_rect(Rect2(-1.5, -r, 3.0, r * 2.0), WHITE)


func _draw_core_shards() -> void:
	var center := Vector2(0, 24)
	for i in 9:
		var a := float(i) * TAU / 9.0 + 0.18
		var d := 18.0 + (i % 4) * 9.0
		var p := center + Vector2.from_angle(a) * d
		var s := 3.0 + (i % 3)
		draw_colored_polygon(PackedVector2Array([
			p + Vector2(-s, -s * 0.4),
			p + Vector2(s * 0.8, 0),
			p + Vector2(-s, s * 0.7),
		]), BLOOD)
	draw_circle(center, 5.0, BLACK)
	draw_circle(center, 2.0, Color(0.3, 0.02, 0.03))


func _draw_nail(world_pos: Vector2, broken: bool) -> void:
	var p := world_pos - position
	if broken:
		if nail_flash > 0.0 or state == State.DEFEATED:
			draw_line(p + Vector2(-7, -7), p + Vector2(7, 7), BLOOD, 2.0)
			draw_line(p + Vector2(7, -7), p + Vector2(-7, 7), BLOOD, 2.0)
		return
	var pulse := 0.5 + 0.5 * sin(anim_t * 5.0)
	draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), WHITE)
	draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), BLOOD if pulse > 0.55 else BLACK)
	draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), WHITE)


func _draw_boss_body() -> void:
	var head := PackedVector2Array([
		Vector2(-41, -157), Vector2(-62, -184), Vector2(-23, -172),
		Vector2(0, -209), Vector2(23, -172), Vector2(62, -184),
		Vector2(41, -157), Vector2(-41, -157),
	])
	draw_colored_polygon(head, WHITE)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-22, -162), Vector2(0, -179), Vector2(22, -162),
		Vector2(15, -146), Vector2(-15, -146),
	]), WHITE)
	draw_rect(Rect2(-12, -171, 24, 23), BLACK)

	var body := PackedVector2Array([
		Vector2(-34, -146), Vector2(-66, -136), Vector2(-85, -114),
		Vector2(-91, -64), Vector2(-74, -42), Vector2(-81, -12),
		Vector2(-90, 45), Vector2(-73, 106), Vector2(-51, 87),
		Vector2(-48, 117), Vector2(-44, 151), Vector2(-20, 133),
		Vector2(0, 170), Vector2(20, 133), Vector2(44, 151),
		Vector2(48, 117), Vector2(51, 87), Vector2(73, 106),
		Vector2(90, 45), Vector2(81, -12), Vector2(74, -42),
		Vector2(91, -64), Vector2(85, -114), Vector2(66, -136),
		Vector2(34, -146),
	])
	draw_colored_polygon(body, WHITE)
	var chest := PackedVector2Array([
		Vector2(-25, -99), Vector2(0, -118), Vector2(25, -99),
		Vector2(32, -42), Vector2(20, 10), Vector2(0, 34),
		Vector2(-20, 10), Vector2(-32, -42),
	])
	draw_colored_polygon(chest, BLACK)
	var core_k := 0.78 + 0.22 * sin(anim_t * 7.0)
	if state == State.CHAIN_SNAP:
		core_k += 0.2 * pull_k
	elif state == State.SLAM_WINDUP:
		core_k += 0.12 + 0.24 * _windup_k()
	if health_flash > 0.0:
		core_k += 0.45
	var core_color := HOT if state >= State.PULLING or state == State.CHAIN_SNAP else BLOOD
	if health_flash > 0.3:
		core_color = WHITE
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -34) * core_k, Vector2(15, -7) * core_k,
		Vector2(0, 22) * core_k, Vector2(-15, -7) * core_k,
	]), core_color)

	if state == State.LEFT_LOCKED:
		_draw_left_arm(false)
	else:
		_draw_left_arm(true)
	if state == State.LEFT_LOCKED or state == State.LEFT_BROKEN:
		_draw_right_arm(false)
	else:
		_draw_right_arm(true)

	draw_rect(Rect2(-3, -112, 6, 10), BLACK)
	if state == State.DEFEATED:
		draw_line(Vector2(-51, -62), Vector2(48, 88), BLOOD, 5.0)
		draw_line(Vector2(51, -62), Vector2(-48, 88), BLOOD, 5.0)
		draw_line(Vector2(-30, -20), Vector2(34, 58), BLACK, 3.0)


func _draw_left_arm(dropped: bool) -> void:
	if dropped:
		draw_colored_polygon(PackedVector2Array([
			Vector2(-66, -122), Vector2(-102, -91), Vector2(-119, -54),
			Vector2(-111, -15), Vector2(-91, -1), Vector2(-73, -17),
			Vector2(-83, -47), Vector2(-72, -78),
		]), WHITE)
	else:
		draw_colored_polygon(PackedVector2Array([
			Vector2(19, -97), Vector2(-27, -85), Vector2(-57, -59),
			Vector2(-70, -22), Vector2(-58, 2), Vector2(-33, 4),
			Vector2(-12, -16), Vector2(15, -41), Vector2(32, -71),
		]), WHITE)


func _draw_right_arm(dropped: bool) -> void:
	if dropped:
		draw_colored_polygon(PackedVector2Array([
			Vector2(66, -122), Vector2(102, -91), Vector2(119, -54),
			Vector2(111, -15), Vector2(91, -1), Vector2(73, -17),
			Vector2(83, -47), Vector2(72, -78),
		]), WHITE)
	else:
		draw_colored_polygon(PackedVector2Array([
			Vector2(-19, -97), Vector2(27, -85), Vector2(57, -59),
			Vector2(70, -22), Vector2(58, 2), Vector2(33, 4),
			Vector2(12, -16), Vector2(-15, -41), Vector2(-32, -71),
		]), WHITE)


func _draw_fallen_arm(rect: Rect2) -> void:
	var local := rect.position - position
	var width := rect.size.x
	var a := local + Vector2(0, 5)
	var b := local + Vector2(width, 5)
	draw_line(a, b, BLACK, 15.0)
	draw_line(a, b, WHITE, 11.0)
	for i in 4:
		var x := local.x + 18.0 + i * (width - 36.0) / 3.0
		draw_rect(Rect2(x - 4.0, local.y - 2.0, 8.0, 14.0), WHITE)
	for i in 4:
		var x := local.x + 18.0 + i * (width - 36.0) / 3.0
		draw_line(Vector2(x, local.y - 3.0), Vector2(x + 8.0, local.y + 8.0), BLACK, 2.0)
