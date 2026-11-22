extends Control
## Kinetic arcade title card. All content is contained under res://start_page/.

const PF := preload("res://scripts/pixel_font.gd")

const W := 480.0
const H := 270.0
const GAME_SCENE := "res://scenes/main.tscn"
const START_META := "iamhell_game_started"
const CYCLE := 4.8
const AUTHOR_CREDIT := "由缕雨吹衣制作"

const C_BLACK := Color(0.045, 0.030, 0.055)
const C_DARK := Color(0.15, 0.085, 0.115)
const C_MID := Color(0.48, 0.42, 0.46)
const C_LIGHT := Color(0.84, 0.79, 0.72)
const C_WHITE := Color(1.0, 0.97, 0.88)
const C_RED_DARK := Color(0.38, 0.035, 0.065)
const C_RED := Color(0.88, 0.075, 0.10)
const C_EMBER := Color(1.0, 0.40, 0.18)

const TITLE_SHADER := """
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec2 iris_center = vec2(240.0, 135.0);
uniform float iris_r = 4000.0;
uniform float impact = 0.0;
uniform float flash = 0.0;
uniform float pulse = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 34.5);
	return fract(p.x * p.y);
}

float bayer4(vec2 p) {
	ivec2 i = ivec2(mod(p, 4.0));
	int x0 = i.x & 1;
	int y0 = i.y & 1;
	int x1 = (i.x >> 1) & 1;
	int y1 = (i.y >> 1) & 1;
	int v = 4 * ((((x0 ^ y0) << 1) | y0) & 3) + ((((x1 ^ y1) << 1) | y1) & 3);
	return (float(v) + 0.5) / 16.0 - 0.5;
}

vec3 choose_color(int k, vec3 a, vec3 b, vec3 c, vec3 d) {
	if (k <= 0) {
		return a;
	}
	if (k == 1) {
		return b;
	}
	if (k == 2) {
		return c;
	}
	return d;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float hit = clamp(impact, 0.0, 1.0);
	float row = floor(uv.y * 270.0);
	float cut = step(0.80, hash21(vec2(row, floor(TIME * 24.0)))) * hit;
	uv.x += (hash21(vec2(row, 7.0)) - 0.5) * 0.055 * cut;

	float split = 0.0005 + hit * 0.005 + pulse * 0.0008;
	vec3 c = vec3(
		texture(screen_tex, uv + vec2(split, 0.0)).r,
		texture(screen_tex, uv).g,
		texture(screen_tex, uv - vec2(split, 0.0)).b
	);
	vec2 q = (uv - vec2(0.5)) * vec2(1.55, 1.0);
	c *= 1.0 - smoothstep(0.35, 0.80, length(q)) * (0.10 + hit * 0.16);
	c *= 0.96 + 0.04 * sin(FRAGCOORD.y * 3.14159);
	c = mix(c, vec3(1.0), clamp(flash * 0.82, 0.0, 0.9));

	float th = bayer4(FRAGCOORD.xy);
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	bool is_red = mx > 0.035 && c.r >= mx - 0.001 && (mx - mn) / mx > 0.37;
	vec3 result;
	if (is_red) {
		int k = int(clamp(floor(mx * 3.0 + th + 0.5), 0.0, 3.0));
		result = choose_color(k,
			vec3(0.045, 0.030, 0.055),
			vec3(0.380, 0.035, 0.065),
			vec3(0.880, 0.075, 0.100),
			vec3(1.000, 0.400, 0.180));
	} else {
		float l = dot(c, vec3(0.299, 0.587, 0.114));
		int k = int(clamp(floor(l * 3.0 + th + 0.5), 0.0, 3.0));
		result = choose_color(k,
			vec3(0.045, 0.030, 0.055),
			vec3(0.150, 0.085, 0.115),
			vec3(0.840, 0.790, 0.720),
			vec3(1.000, 0.970, 0.880));
	}

	if (impact > 0.56) {
		float l2 = dot(c, vec3(0.299, 0.587, 0.114));
		if (is_red) {
			result = vec3(0.880, 0.075, 0.100);
		} else if (l2 > 0.34) {
			result = vec3(1.000, 0.970, 0.880);
		} else {
			result = vec3(0.045, 0.030, 0.055);
		}
	}

	vec2 px = SCREEN_UV / SCREEN_PIXEL_SIZE;
	float dist = length(px - iris_center);
	if (dist > iris_r) {
		result = vec3(0.045, 0.030, 0.055);
	} else if (dist > iris_r - 6.0 && th > -0.15) {
		result = vec3(0.045, 0.030, 0.055);
	}

	COLOR = vec4(result, 1.0);
}
"""

var t: float = 0.0
var intro_t: float = 0.0
var entering: bool = false
var enter_t: float = 0.0
var shader_rect: ColorRect
var shader_mat: ShaderMaterial
var start_sound: AudioStreamPlayer
var author_font: SystemFont


func _ready() -> void:
	Engine.time_scale = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_author_font()
	_build_audio()
	_build_overlay()
	queue_redraw()


func _build_author_font() -> void:
	author_font = SystemFont.new()
	author_font.font_names = PackedStringArray([
		"Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "SimHei", "sans-serif"
	])
	author_font.allow_system_fallback = true


func _build_audio() -> void:
	start_sound = AudioStreamPlayer.new()
	start_sound.stream = load("res://assets/sfx/perfect.wav")
	start_sound.volume_db = -9.0
	add_child(start_sound)


func _build_overlay() -> void:
	var shader := Shader.new()
	shader.code = TITLE_SHADER
	shader_mat = ShaderMaterial.new()
	shader_mat.shader = shader
	shader_rect = ColorRect.new()
	shader_rect.position = Vector2.ZERO
	shader_rect.size = Vector2(W, H)
	shader_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shader_rect.material = shader_mat
	shader_rect.z_index = 100
	add_child(shader_rect)


func _process(delta: float) -> void:
	t += delta
	intro_t += delta
	if entering:
		enter_t += delta
		if enter_t >= 0.32:
			Engine.set_meta(START_META, true)
			get_tree().change_scene_to_file(GAME_SCENE)
			return
	_update_shader()
	queue_redraw()


func _cycle() -> float:
	return fmod(t, CYCLE)


func _impact() -> float:
	var cycle := _cycle()
	var repeat := clampf(1.0 - absf(cycle - 2.12) / 0.11, 0.0, 1.0)
	var intro := clampf(1.0 - absf(intro_t - 0.52) / 0.08, 0.0, 1.0)
	return maxf(repeat, intro)


func _sweep() -> float:
	var cycle := _cycle()
	return clampf((cycle - 1.72) / 0.55, 0.0, 1.0)


func _update_shader() -> void:
	var iris := 560.0 * ease(clampf(intro_t / 0.5, 0.0, 1.0), 0.45)
	if entering:
		iris = 560.0 * (1.0 - ease(clampf(enter_t / 0.28, 0.0, 1.0), 2.0))
	var hit := _impact()
	if entering and enter_t < 0.08:
		hit = 1.0
	shader_mat.set_shader_parameter("iris_center", Vector2(W * 0.5, H * 0.5))
	shader_mat.set_shader_parameter("iris_r", iris)
	shader_mat.set_shader_parameter("impact", hit)
	shader_mat.set_shader_parameter("flash",
		clampf(hit * 0.52 + (0.66 if entering and enter_t < 0.11 else 0.0), 0.0, 0.9))
	shader_mat.set_shader_parameter("pulse", 0.5 + 0.5 * sin(t * 5.0))


func _unhandled_input(event: InputEvent) -> void:
	if entering:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.keycode if event.keycode != 0 else event.physical_keycode
		if key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_SHIFT]:
			_enter_game()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_enter_game()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index in [JOY_BUTTON_A, JOY_BUTTON_START]:
			_enter_game()
			get_viewport().set_input_as_handled()


func _enter_game() -> void:
	if entering:
		return
	entering = true
	enter_t = 0.0
	if start_sound != null:
		start_sound.play()


func _draw() -> void:
	var shake_amt := _impact() * 6.0 + (5.0 if entering and enter_t < 0.08 else 0.0)
	var shake := Vector2(sin(t * 103.0) * shake_amt, cos(t * 79.0) * shake_amt * 0.45)
	draw_set_transform(shake, 0.0, Vector2.ONE)
	_draw_canvas()
	_draw_title()
	_draw_shift_graphic()
	_draw_prompt()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_canvas() -> void:
	draw_rect(Rect2(-12, -12, W + 24, H + 24), C_BLACK)

	# Broad red diagonal field.
	draw_colored_polygon(PackedVector2Array([
		Vector2(302, -8), Vector2(W + 12, -8), Vector2(W + 12, 221),
		Vector2(430, 172), Vector2(362, 78)
	]), C_RED_DARK)
	draw_colored_polygon(PackedVector2Array([
		Vector2(W + 12, -8), Vector2(W + 12, 70), Vector2(408, -8)
	]), C_RED)
	draw_line(Vector2(302, -8), Vector2(430, 172), C_RED, 2.0)
	draw_line(Vector2(310, -8), Vector2(438, 172), Color(1, 1, 1, 0.45), 1.0)

	# Hard black cuts across the field.
	for i in 9:
		var y := -8.0 + i * 27.0
		draw_line(Vector2(292 + i * 9, y), Vector2(W + 12, y - 94),
			Color(C_BLACK.r, C_BLACK.g, C_BLACK.b, 0.8), 3.0)

	# Thin grid and micro-labels produce an arcade poster texture.
	for x in range(18, 460, 24):
		draw_rect(Rect2(x, 0, 1, 224), Color(1, 1, 1, 0.025))
	for y in range(18, 224, 24):
		draw_rect(Rect2(0, y, W, 1), Color(1, 1, 1, 0.025))
	PF.draw(self, Vector2(16, 28), "I", 1, C_RED)
	PF.draw(self, Vector2(W - 16, 28), "SHIFT//01", 1, C_MID, 2)
	_draw_author_credit()
	PF.draw(self, Vector2(16, 216), "NO ATTACK", 1, C_MID)
	PF.draw(self, Vector2(W - 16, 216), "ONLY TIMING", 1, C_RED, 2)

	# Sweeping diagonal slash.
	var sweep := _sweep()
	if sweep > 0.0 and sweep < 1.0:
		var sx := lerpf(-90.0, W + 90.0, sweep)
		draw_line(Vector2(sx - 42, -10), Vector2(sx + 42, H + 10),
			Color(1, 1, 1, 0.16), 20.0)
		draw_line(Vector2(sx - 42, -10), Vector2(sx + 42, H + 10),
			Color(C_RED.r, C_RED.g, C_RED.b, 0.70), 5.0)
		draw_line(Vector2(sx - 38, -10), Vector2(sx + 46, H + 10),
			Color(1, 1, 1, 0.80), 1.0)


func _draw_author_credit() -> void:
	var text_width := 132.0
	var panel := Rect2(W - 16.0 - text_width, 3.0, text_width, 15.0)
	draw_rect(panel, Color(0, 0, 0, 0.68))
	draw_rect(panel, Color(C_RED.r, C_RED.g, C_RED.b, 0.72), false, 1.0)
	var pos := Vector2(panel.position.x, 14.0)
	var color := Color(C_WHITE.r, C_WHITE.g, C_WHITE.b, 0.96)
	draw_string_outline(author_font, pos, AUTHOR_CREDIT,
		HORIZONTAL_ALIGNMENT_RIGHT, text_width - 6.0, 10, 2, Color(0, 0, 0, 0.96))
	draw_string(author_font, pos, AUTHOR_CREDIT,
		HORIZONTAL_ALIGNMENT_RIGHT, text_width - 6.0, 10, color)


func _draw_title() -> void:
	var reveal := clampf(intro_t / 0.46, 0.0, 1.0)
	var slam := (1.0 - ease(reveal, 0.32)) * -68.0
	var hit := _impact()
	var offset := Vector2(sin(t * 95.0) * hit * 2.2, slam)
	var glitch := hit > 0.2 or fmod(t, 3.4) < 0.05
	if glitch:
		offset.x += -3.0 if int(t * 54.0) % 2 == 0 else 3.0

	var label := Rect2(22 + offset.x, 49 + offset.y, 78, 20)
	draw_rect(label, C_RED)
	draw_rect(Rect2(label.position + Vector2(3, 3), label.size), Color(1, 1, 1, 0.16))
	PF.draw(self, Vector2(label.position.x + 8, label.position.y + 5),
		"I AM", 2, C_BLACK)

	if glitch:
		PF.draw(self, Vector2(26 + offset.x, 77 + offset.y), "HELL", 9,
			Color(C_RED.r, C_RED.g, C_RED.b, 0.72))
		PF.draw(self, Vector2(34 + offset.x, 77 + offset.y), "HELL", 9,
			Color(1, 1, 1, 0.26))
		for i in 4:
			var gx := 22.0 + float((int(t * 58.0) + i * 61) % 226)
			draw_rect(Rect2(gx + offset.x, 84 + offset.y + i * 15,
				34.0 + i * 29, 1), Color(C_RED.r, C_RED.g, C_RED.b, 0.76))
	_draw_big_word(Vector2(26 + offset.x, 77 + offset.y), "HELL", 9)

	draw_rect(Rect2(23 + offset.x, 148 + offset.y, 188, 24), C_WHITE)
	draw_rect(Rect2(23 + offset.x, 148 + offset.y, 188, 2), C_BLACK)
	PF.draw(self, Vector2(34 + offset.x, 152 + offset.y),
		"SHIFT IS YOUR ONLY WEAPON", 1, C_BLACK)
	PF.draw(self, Vector2(24 + offset.x, 178 + offset.y),
		"THEY ATTACK. YOU SWAP. THEY DIE.", 1, C_RED)


func _draw_big_word(pos: Vector2, text: String, scale: int) -> void:
	for off in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
		PF.draw(self, pos + off, text, scale, C_BLACK)
	PF.draw(self, pos + Vector2(7, 7), text, scale, C_RED)
	PF.draw(self, pos, text, scale, C_WHITE)


func _draw_shift_graphic() -> void:
	var cycle := _cycle()
	var k := 0.0
	if cycle >= 1.82 and cycle < 2.18:
		k = ease((cycle - 1.82) / 0.36, 2.0)
	elif cycle >= 2.18 and cycle < 3.88:
		k = 1.0
	elif cycle >= 3.88 and cycle < 4.24:
		k = 1.0 - ease((cycle - 3.88) / 0.36, 2.0)

	var y_a := lerpf(194.0, 170.0, k)
	var y_b := lerpf(170.0, 194.0, k)
	_draw_arrow(Vector2(55, y_a), Vector2(205, y_a), C_WHITE, 4.0)
	_draw_arrow(Vector2(W - 55, y_b), Vector2(W - 205, y_b), C_RED, 4.0)

	var hit := _impact()
	var energy := 4.0 + sin(t * 7.0) * 2.0 + hit * 6.0
	for i in 3:
		var dx := (i - 1) * 13.0
		var diamond := PackedVector2Array([
			Vector2(240 + dx, 174 - energy), Vector2(240 + dx + energy * 0.55, 174),
			Vector2(240 + dx, 174 + energy), Vector2(240 + dx - energy * 0.55, 174)
		])
		draw_polyline(PackedVector2Array([
			diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]
		]), Color(C_EMBER.r, C_EMBER.g, C_EMBER.b, 0.44 + hit * 0.46), 1.0)
	PF.draw(self, Vector2(240, 197), "SHIFT", 2, C_WHITE, 1, C_RED)

	if hit > 0.02:
		draw_rect(Rect2(0, 160, W, 3), Color(1, 1, 1, hit * 0.62))
		draw_rect(Rect2(0, 165, W, 1), Color(C_RED.r, C_RED.g, C_RED.b, hit))
		for i in 12:
			var x := 20.0 + i * 40.0
			draw_line(Vector2(x, 162), Vector2(x + 28, 162),
				Color(1, 1, 1, hit * 0.34), 1.0)


func _draw_arrow(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	draw_line(a, b, color, width)
	var d := (b - a).normalized()
	var side := Vector2(-d.y, d.x)
	draw_colored_polygon(PackedVector2Array([
		b + d * 6.0, b + side * 10.0, b - side * 10.0
	]), color)


func _draw_prompt() -> void:
	draw_rect(Rect2(-12, 228, W + 24, 42), C_BLACK)
	draw_rect(Rect2(-12, 228, W + 24, 2), C_RED)
	var blink := 0.72 + 0.28 * sin(t * 5.2)
	var text := "OPENING THE GATES" if entering else "PRESS SHIFT OR CLICK TO ENTER"
	PF.draw(self, Vector2(W * 0.5, 236), text, 2,
		Color(C_WHITE.r, C_WHITE.g, C_WHITE.b, blink), 1,
		Color(C_RED.r, C_RED.g, C_RED.b, blink))
	PF.draw(self, Vector2(W * 0.5, 257),
		"A/D MOVE   W/SPACE JUMP   MOUSE AIM   SHIFT SWAP", 1, C_MID, 1)
