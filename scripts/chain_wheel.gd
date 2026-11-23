extends Node2D
## The left-nail execution wheel. A charger dash spins the wheel, winds the
## chain and tears the left nail out of the boss's arm.

enum State { WAITING, SPINNING, DONE }

const SPIN_TIME := 0.9

var game = null
var boss = null
var bone_nail = null
var alive: bool = true
var killable: bool = false
var swappable: bool = false
var velocity := Vector2.ZERO
var half := Vector2(24, 24)
var gdir: float = 1.0
var state: int = State.WAITING
var timer: float = 0.0
var angle: float = 0.0
var trigger_radius: float = 34.0
var pinned_charger = null


func _ready() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 24.0
	shape.shape = circle
	body.add_child(shape)
	add_child(body)


func get_hit_rect() -> Rect2:
	return Rect2(position - half, half * 2.0)


func _physics_process(delta: float) -> void:
	if game == null or game.game_over:
		return
	match state:
		State.WAITING:
			for e in game.get_entities():
				if e == self or not e.alive:
					continue
				if e.get_script() == null:
					continue
				if e.get_script().resource_path.get_file() != "enemy_charger.gd":
					continue
				if not e.has_method("can_trigger_wheel") or not e.can_trigger_wheel():
					continue
				if e.position.distance_to(position) <= trigger_radius:
					_trigger(e)
					break
		State.SPINNING:
			timer -= delta
			angle += delta * 11.0
			if timer <= 0.0:
				state = State.DONE
				if bone_nail != null and is_instance_valid(bone_nail):
					bone_nail.pull_out()
	queue_redraw()


func _trigger(charger = null) -> void:
	if state != State.WAITING:
		return
	state = State.SPINNING
	timer = SPIN_TIME
	if charger != null and is_instance_valid(charger):
		pinned_charger = charger
		pinned_charger.pin_to_wheel(self, Vector2(-20, -2))
	if bone_nail != null and is_instance_valid(bone_nail):
		bone_nail.pull_out()
	game.play_sfx("slam", 0.02)
	game.add_shake(6.0)
	game.rings.append({"p": position, "t": 0.35, "max": 34.0})


func _draw() -> void:
	var pulse := 0.55 + 0.45 * sin(angle * 1.7)
	draw_line(Vector2(0, -8), Vector2(28, -92), Color(0.66, 0.08, 0.1, 0.8), 2.0)
	for i in 7:
		var p := Vector2(0, -8).lerp(Vector2(28, -92), float(i) / 7.0)
		draw_rect(Rect2(p - Vector2(2, 1), Vector2(4, 2)), Color.WHITE)

	draw_circle(Vector2.ZERO, 26.0, Color.BLACK)
	draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 24, Color.WHITE, 4.0)
	draw_circle(Vector2.ZERO, 7.0, Color.WHITE)
	for i in 8:
		var a := angle + float(i) * TAU / 8.0
		var p := Vector2.from_angle(a) * 18.0
		draw_line(p, p + Vector2.from_angle(a) * 9.0, Color.WHITE, 4.0)
	if state == State.WAITING:
		draw_circle(Vector2.ZERO, 5.0 + pulse * 2.0, Color(0.66, 0.08, 0.1, pulse))
	else:
		for i in 5:
			var a := angle * -2.0 + i * TAU / 5.0
			draw_rect(Rect2(Vector2.from_angle(a) * 31.0 - Vector2(2, 2), Vector2(4, 4)), Color.WHITE)
