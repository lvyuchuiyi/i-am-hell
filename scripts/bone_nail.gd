extends Node2D
## Physical left boss nail. The execution wheel yanks it out, then it arms a
## visible blast that kills the charger and nearby enemies before the arm falls.

enum State { LOCKED, PULLING, ARMED, SPENT }

const PULL_TIME := 0.72
const BLAST_DELAY := 0.24
const BLAST_RADIUS := 92.0

var game = null
var boss = null
var alive: bool = true
var killable: bool = false
var swappable: bool = false
var velocity := Vector2.ZERO
var half := Vector2(10, 16.5)
var hit_offset := Vector2(0, 3.5)
var gdir: float = 1.0
var state: int = State.LOCKED
var timer: float = 0.0
var shake: Vector2 = Vector2.ZERO
var chain_tension: float = 0.0


func get_hit_rect() -> Rect2:
	var center := position + hit_offset
	return Rect2(center - half, half * 2.0)


func _ready() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = hit_offset
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = half * 2.0
	shape.shape = rect
	body.add_child(shape)
	add_child(body)


func _physics_process(delta: float) -> void:
	if game == null or game.game_over:
		return
	shake = Vector2.ZERO
	match state:
		State.LOCKED:
			chain_tension = 0.15 + 0.08 * sin(Time.get_ticks_msec() * 0.007)
		State.PULLING:
			timer -= delta
			shake = Vector2(randf_range(-2.0, 2.0), randf_range(-1.0, 1.0))
			chain_tension = 1.0
			if timer <= 0.0:
				state = State.ARMED
				timer = BLAST_DELAY
				game.spawn_blast(position, BLAST_RADIUS, BLAST_DELAY, "a bone nail")
				game.add_shake(7.0)
				game.play_sfx("windup", 0.0)
		State.ARMED:
			timer -= delta
			chain_tension = 1.0
			if timer <= 0.0:
				state = State.SPENT
				if boss != null and is_instance_valid(boss):
					boss.break_left_chain()
				queue_free()
				return
	queue_redraw()


func pull_out() -> void:
	if state != State.LOCKED:
		return
	state = State.PULLING
	timer = PULL_TIME
	game.play_sfx("slam", 0.04)
	game.add_shake(3.0)
	game.rings.append({"p": position, "t": 0.22, "max": 18.0})


func _draw() -> void:
	draw_set_transform(shake, 0.0, Vector2.ONE)
	var flash := state != State.LOCKED and int(Time.get_ticks_msec() * 0.03) % 2 == 0
	var ink := Color.WHITE
	var red := Color(1.0, 0.32, 0.22) if state == State.ARMED else Color(0.66, 0.08, 0.1)

	# Heavy bone-iron head and long shaft driven into the wall.
	draw_rect(Rect2(-10, -13, 20, 8), Color.BLACK)
	draw_rect(Rect2(-8, -12, 16, 6), ink)
	draw_rect(Rect2(-5, -10, 10, 2), Color(0.66, 0.66, 0.66))
	draw_rect(Rect2(-3, -5, 6, 25), Color.BLACK)
	draw_rect(Rect2(-2, -5, 4, 23), ink)
	draw_rect(Rect2(-1, -2, 2, 12), Color(0.66, 0.66, 0.66))
	draw_rect(Rect2(-4, 17, 8, 3), Color.BLACK)
	draw_rect(Rect2(-3, 17, 6, 2), Color(0.66, 0.66, 0.66))

	# Red core and chain tension marks.
	draw_rect(Rect2(-2, -10, 4, 3), red)
	if flash:
		draw_rect(Rect2(-13, -16, 26, 1), Color.WHITE)
		draw_rect(Rect2(-13, -16, 1, 32), Color.WHITE)
		draw_rect(Rect2(12, -16, 1, 32), Color.WHITE)
		draw_rect(Rect2(-13, 15, 26, 1), Color.WHITE)
	for i in 3:
		var y := -2.0 + i * 6.0
		var w := 9.0 + chain_tension * 8.0
		draw_line(Vector2(-w, y), Vector2(-8, y), Color(0.66, 0.08, 0.1, 0.35 + chain_tension * 0.45), 1.0)
		draw_line(Vector2(8, y), Vector2(w, y), Color(0.66, 0.08, 0.1, 0.35 + chain_tension * 0.45), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
