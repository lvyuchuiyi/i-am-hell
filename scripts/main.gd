extends Node2D
## 游戏总管：读关卡、换位、命中判定、机关、出口、镜头、子弹时间、特效。
## 主角不能攻击——所有击杀都来自敌人、机关和地形。

const Levels := preload("res://scripts/levels.gd")
const PlayerScript := preload("res://scripts/player.gd")
const ShooterScript := preload("res://scripts/enemy_shooter.gd")
const ChargerScript := preload("res://scripts/enemy_charger.gd")
const BomberScript := preload("res://scripts/enemy_bomber.gd")
const CrateScript := preload("res://scripts/crate.gd")
const BarrelScript := preload("res://scripts/barrel.gd")
const BulletScript := preload("res://scripts/bullet.gd")
const BlastScript := preload("res://scripts/blast.gd")
const SawScript := preload("res://scripts/saw.gd")
const TurretScript := preload("res://scripts/turret.gd")
const CrusherScript := preload("res://scripts/crusher.gd")
const LaserScript := preload("res://scripts/laser.gd")
const MirrorScript := preload("res://scripts/enemy_mirror.gd")
const SwapperScript := preload("res://scripts/enemy_swapper.gd")
const HeavyScript := preload("res://scripts/enemy_heavy.gd")
const MimicScript := preload("res://scripts/enemy_mimic.gd")
const PlumbScript := preload("res://scripts/enemy_plumb.gd")
const WeightedLiftPairScript := preload("res://scripts/weighted_lift_pair.gd")
const BossLiftScript := preload("res://scripts/boss_lift.gd")
const ThirdNailScript := preload("res://scripts/enemy_third_nail.gd")
const ChainGripScript := preload("res://scripts/chain_grip.gd")
const ChainWheelScript := preload("res://scripts/chain_wheel.gd")
const ChainPendulumScript := preload("res://scripts/chain_pendulum.gd")
const StoneWingScript := preload("res://scripts/enemy_stone_wing.gd")
const HookPenitentScript := preload("res://scripts/enemy_hook_penitent.gd")
const BoneNailScript := preload("res://scripts/bone_nail.gd")
const LiftLatchScript := preload("res://scripts/lift_latch.gd")
const BossBombScript := preload("res://scripts/boss_bomb.gd")
const HudScript := preload("res://scripts/hud.gd")
const TerrainScript := preload("res://scripts/terrain.gd")
const BackgroundScript := preload("res://scripts/background.gd")
const PF := preload("res://scripts/pixel_font.gd")
const SfxScript := preload("res://scripts/sfx.gd")

const C_BLOOD := Color(0.66, 0.08, 0.1)   # 地狱红：危险、血

const TILE := 16
const SCREEN_CENTER := Vector2(240, 137)   # 地图 272 高、画面 270 高：镜头下移 2 像素，最底下一行（坑在这里）完整露出来
const SWAP_COOLDOWN := 0.18
const SWAP_INVULN := 0.12
const TARGET_RADIUS := 40.0
const COMBO_WINDOW := 2.5
const VOID_Y := 300.0
const SKY_Y := -30.0
const PERFECT_BONUS := 300
const BARREL_BLAST := 30.0

# ---- 换位规则（防止“跳到刺上随便换”一招通吃）
const SWAP_RANGE := 0.0           # 换位距离上限（像素），0 = 不限距离；墙始终会挡住
const MAX_SHIFT := 3              # 换位能量上限
const SHIFT_REGEN := 2.5          # 每多少秒自动回 1 格
const NEW_STYLE_BONUS := 200      # 本关第一次用某种杀法的奖励

# 死因 -> 杀法名字（屏幕上飘出来的字）
const KILL_STYLES := {
	"a bullet": "FRIENDLY FIRE",
	"a charger": "TRAMPLED",
	"a bomb": "BOMBED",
	"a heavy": "CRUSHED",
	"a plumb": "PLUMBED",
	"spikes": "SPIKED",
	"the void": "INTO THE VOID",
	"the sky": "SKYFALL",
	"the third nail": "THIRD NAIL",
	"a saw": "SLICED",
	"a crusher": "FLATTENED",
	"a laser": "FRIED",
	"a stone impact": "WALL SHATTER",
	"a giant hook": "HOOKED",
	"a hook penitent": "HOOK DRAGGED",
	"a chain impact": "ANCHOR IMPACT",
	"a bone nail": "NAIL BLAST",
	"a barrel": "KABOOM",
	"the lava": "MELTED",
}
# 被“敌人的攻击”杀死时才回能量：鼓励让它们互相残杀，而不是全靠地形
const REFUND_CAUSES := ["a bullet", "a charger", "a bomb", "a heavy", "a plumb"]

# ---- 镜头 / 子弹时间参数（调手感就改这里）
const SLOWMO_SCALE := 0.35        # 危险时刻的时间流速
const DANGER_ZOOM := 0.10         # 危险时刻镜头额外推近
const SWAP_PUNCH := 0.14          # 普通换位镜头冲击
const PERFECT_PUNCH := 0.28       # 完美换位镜头冲击
const SWAP_ROLL := 0.035          # 换位镜头侧倾（弧度）
const DEATH_ZOOM := 1.45

# 调色板 + 有序抖动（GBA 质感的核心）：
# 整个画面最后换成 4 阶灰 + 3 阶红。半透明、渐变的地方会变成一格一格的网点。
# 想换整体色调，改下面 c0~c3（灰阶）和 r1~r3（红）就行。
const PALETTE_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float invert = 0.0;
uniform float wave = 0.0;          // 子弹时间强度：扫描线横向波动 + 暗角
uniform float impact = 0.0;        // 冲击帧：只剩黑白红
uniform vec2 iris_center = vec2(240.0, 135.0);
uniform float iris_r = 4000.0;     // 圆形转场半径（像素）
uniform vec3 c0 = vec3(0.063, 0.043, 0.078);
uniform vec3 c1 = vec3(0.235, 0.188, 0.259);
uniform vec3 c2 = vec3(0.580, 0.533, 0.553);
uniform vec3 c3 = vec3(0.949, 0.918, 0.847);
uniform vec3 r1 = vec3(0.400, 0.075, 0.110);
uniform vec3 r2 = vec3(0.784, 0.157, 0.196);
uniform vec3 r3 = vec3(1.000, 0.478, 0.353);

// 4x4 有序抖动阈值（-0.5 ~ 0.5），用位运算算出来
float bayer4(vec2 p) {
	ivec2 i = ivec2(mod(p, 4.0));
	int x0 = i.x & 1;
	int y0 = i.y & 1;
	int x1 = (i.x >> 1) & 1;
	int y1 = (i.y >> 1) & 1;
	int v = 4 * ((((x0 ^ y0) << 1) | y0) & 3) + ((((x1 ^ y1) << 1) | y1) & 3);
	return (float(v) + 0.5) / 16.0 - 0.5;
}

vec3 pick(int k, vec3 a, vec3 b, vec3 c, vec3 d) {
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
	vec2 px = SCREEN_UV / SCREEN_PIXEL_SIZE;
	vec2 uv = SCREEN_UV;
	// GBA 式扫描线波动：每一行左右错开一点
	uv.x += sin(px.y * 0.35 + TIME * 10.0) * wave * 1.5 * SCREEN_PIXEL_SIZE.x;
	vec3 c = texture(screen_tex, uv).rgb;
	if (invert > 0.5) {
		c = vec3(1.0) - c;
	}
	// 子弹时间暗角
	vec2 q = (SCREEN_UV - vec2(0.5)) * vec2(1.6, 1.0);
	c *= 1.0 - wave * smoothstep(0.35, 0.8, length(q)) * 0.85;
	float th = bayer4(FRAGCOORD.xy);
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	bool is_red = mx > 0.04 && c.r >= mx - 0.001 && (mx - mn) / mx > 0.5;
	vec3 o;
	if (is_red) {
		int k = int(clamp(floor(mx * 3.0 + th + 0.5), 0.0, 3.0));
		o = pick(k, c0, r1, r2, r3);
	} else {
		float l = dot(c, vec3(0.299, 0.587, 0.114));
		int k = int(clamp(floor(l * 3.0 + th + 0.5), 0.0, 3.0));
		o = pick(k, c0, c1, c2, c3);
	}
	// 冲击帧：整个画面只剩纯黑、纯白、红
	if (impact > 0.5) {
		float l2 = dot(c, vec3(0.299, 0.587, 0.114));
		if (is_red) {
			o = r2;
		} else if (l2 > 0.45) {
			o = c3;
		} else {
			o = c0;
		}
	}
	// 圆形转场：圈外全黑，圈边是一圈抖动网点
	float dist = length(px - iris_center);
	if (dist > iris_r) {
		o = c0;
	} else if (dist > iris_r - 4.0 && th > -0.1) {
		o = c0;
	}
	COLOR = vec4(o, 1.0);
}
"""

# ---- 跨关卡保存的进度（重载场景时不会丢）
static var level_index: int = 0
const DEBUG_LEVEL_SELECT := true   # 临时选关（按 Tab 打开）。发布前改成 false
var select_open: bool = false
var select_idx: int = 0
static var total_deaths: int = 0
static var total_score: int = 0
static var run_time: float = 0.0
static var run_perfects: int = 0
static var run_best_combo: int = 0
static var run_total_kills: int = 0

# ---- 当前关卡
var level_no: int = 1          # 给 HUD 读（从 1 开始）
var level_count: int = 1
var level_name: String = ""
var level_hint: String = ""
var deaths: int = 0            # 给 HUD 读：总死亡数
var grid: Array = []           # 每行一个字符串
var cols: int = 30
var rows: int = 17
var solids: Array = []         # Rect2：墙和地面（画图 + 子弹判定）
var platforms: Array = []      # Rect2：单向平台
var spikes: Array = []         # Rect2：所有地刺（命中判定）
var spikes_up: Array = []      # 朝上的地刺（画图）
var spikes_down: Array = []    # 天花板上朝下的刺（画图）
var zone_cells: Array = []     # 重力反转区的格子（画图）
var lava_speed: float = 0.0     # 地狱从下往上涨的速度（像素/秒），0 = 这一关没有
var lava_y: float = 1.0e9       # 岩浆表面的高度（世界坐标）
var lava_wait: float = 0.0      # 开局多久以后开始涨
var lava_t: float = 0.0         # 已经涨了多久
const LAVA_ACCEL := 0.5         # 岩浆每秒加速多少（像素/秒²）
const LAVA_MAX := 42.0          # 岩浆最快多快
var void_y: float = VOID_Y      # 掉出地图多深算掉进深渊（高关卡会更深）
var cam_y: float = 135.0        # 高关卡里镜头跟着主角上下走
var always_open: bool = false  # 这一关的出口一直开着（不用杀光敌人）
var flip_level: bool = false    # 这一关每次 SHIFT 都会把整个世界的重力翻过来
var world_flip: bool = false    # 现在世界是不是倒过来的
var zone_set: Dictionary = {}  # 同上，查询用；站在反转区里的角色字符也算反转区
var door_rect := Rect2()
var door_open: bool = false
var level_time: float = 0.0
var boss_mode: bool = false
var boss_defeated: bool = false
var boss_node = null
var boss_lift = null
var progress_crates: Array = []
var weighted_lift = null
var chain_wheel = null
var chain_pendulum = null
var bone_nail = null
var hook_nail := Vector2.ZERO
var lift_min_row: int = 3
var lift_max_row: int = 0

var player = null
var target = null
var camera: Camera2D
var hud = null
var invert_rect: ColorRect      # 全屏调色板（顺便负责反色闪光）
var terrain = null
var sfx = null
var level_root: Node2D
var entities_root: Node2D
var fx_root: Node2D

var swap_cd: float = 0.0
var hitstop_until: int = 0
var shift_energy: int = MAX_SHIFT
var max_shift_shown: int = MAX_SHIFT   # 给 HUD 读
var shift_regen_shown: float = SHIFT_REGEN
var regen_t: float = 0.0
var reach_fail = null            # 鼠标指着、但够不着的目标（太远或被墙挡住）
var danger_kind: int = 0         # 0 没危险，1 地形（刺/深渊），2 攻击或机关（能算完美换位）
var methods_used := {}           # 本关用过的杀法 -> 次数
var rank: String = ""
var clogged: Array = []          # 被尸体堵住的地刺 {rect, up}
var labels: Array = []           # 飘字 {p, text, t, big}
var decals: Array = []           # 血迹 {x, y, w, dir, drops}（整关都留着）
var decor: Array = []            # 装饰 {kind, p}：骷髅、骨头、蜡烛
var impact_t: float = 0.0        # 冲击帧剩余时间（真实时间）
var kick := Vector2.ZERO         # 定向镜头冲击：顺着换位方向一顶，再弹回来
var sparks: Array = []           # 打击火花 {p, t, big, seed}
var burst_t: float = 0.0         # 集中线剩余时间（给 HUD 读）
var burst_pos := Vector2(240, 135)   # 集中线中心（屏幕坐标）
var heat: float = 0.0            # 连杀热度 0~1（给 HUD 画火焰）
var fx_time: float = 0.0

# 镜头状态（全部用真实时间更新，不受子弹时间影响）
var last_us: int = 0
var shake: float = 0.0
var punch: float = 0.0
var roll: float = 0.0
var focus := SCREEN_CENTER
var focus_w: float = 0.0
var danger: bool = false
var danger_amt: float = 0.0
var invert_t: float = 0.0
var perfect_t: float = 0.0
var death_t: float = 0.0

var score: int = 0
var kills: int = 0
var perfects: int = 0
var perfect_bonus: int = PERFECT_BONUS   # 给 HUD 读
var combo: int = 0
var combo_timer: float = 0.0
var best_combo: int = 0
var game_over: bool = false    # 为 true 时所有东西停止行动（死亡或过关）
var cleared: bool = false      # 过关
var all_clear: bool = false    # 通关
var clear_t: float = 0.0
var death_cause: String = ""

var swap_bolts: Array = []       # {a, b, t, w}
var ghosts: Array = []           # {p, half, t}
var rings: Array = []            # {p, t, max}
var debris: Array = []           # {p, v, t, g}
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	# [START PAGE] Deleting res://start_page/ disables this hook automatically.
	if ResourceLoader.exists("res://start_page/start_screen.tscn") and not Engine.has_meta("iamhell_game_started"):
		set_process(false)
		set_physics_process(false)
		get_tree().call_deferred("change_scene_to_file", "res://start_page/start_screen.tscn")
		return

	rng.randomize()
	Engine.time_scale = 1.0

	level_root = Node2D.new()
	add_child(level_root)
	entities_root = Node2D.new()
	add_child(entities_root)
	fx_root = Node2D.new()
	add_child(fx_root)

	sfx = SfxScript.new()
	sfx.game = self
	add_child(sfx)

	# 地形画在主节点的特效下面
	terrain = TerrainScript.new()
	terrain.game = self
	terrain.z_index = -1
	level_root.add_child(terrain)

	# 背景：单独一层，在所有东西后面
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -1
	add_child(bg_layer)
	var bg = BackgroundScript.new()
	bg.game = self
	bg_layer.add_child(bg)

	camera = Camera2D.new()
	camera.position = SCREEN_CENTER
	camera.ignore_rotation = false
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = 480
	camera.limit_bottom = 272
	add_child(camera)
	camera.make_current()

	var layer := CanvasLayer.new()
	add_child(layer)
	hud = HudScript.new()
	hud.game = self
	layer.add_child(hud)

	# 全屏调色板 + 抖动（最上层，HUD 也一起换色）；反色闪光也在这里做
	var fx_layer := CanvasLayer.new()
	fx_layer.layer = 10
	add_child(fx_layer)
	invert_rect = ColorRect.new()
	invert_rect.position = Vector2.ZERO
	invert_rect.size = Vector2(480, 270)
	invert_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = PALETTE_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	invert_rect.material = mat
	fx_layer.add_child(invert_rect)

	_load_level(level_index)
	camera.limit_bottom = rows * TILE
	if player != null:
		cam_y = _cam_target_y()


# ---------------------------------------------------------------- 关卡读取

func _load_level(idx: int) -> void:
	var all: Array = Levels.LEVELS
	level_count = all.size()
	idx = clampi(idx, 0, level_count - 1)
	level_index = idx
	level_no = idx + 1
	deaths = total_deaths
	var data: Dictionary = all[idx]
	level_name = data["name"]
	level_hint = data["hint"]
	flip_level = data.get("flip", false)
	always_open = data.get("door_open", false)
	boss_mode = data.get("boss", "") == "third_nail"
	boss_defeated = false
	boss_node = null
	boss_lift = null
	progress_crates.clear()
	weighted_lift = null
	chain_wheel = null
	chain_pendulum = null
	bone_nail = null
	hook_nail = Vector2.ZERO
	lift_min_row = int(data.get("lift_min", 3))
	lift_max_row = int(data.get("lift_max", 0))
	lava_speed = data.get("lava", 0.0)
	lava_wait = data.get("lava_delay", 2.5)
	grid = data["map"]
	rows = grid.size()
	cols = (grid[0] as String).length()
	# 这两个要等 rows 算出来以后再设（之前放在前面，rows 还是 0，所有东西一出生就算掉进深渊）
	lava_y = rows * TILE + 8.0 if lava_speed > 0.0 else 1.0e9
	void_y = rows * TILE + 28.0
	hook_nail = _find_marker("N")

	for r in rows:
		var line: String = grid[r]
		var c := 0
		while c < cols:
			var ch := line[c]
			# 把同一行连续的同类格子合并成一个矩形
			if _is_solid_char(ch) or ch == "-" or ch == "^" or ch == "v":
				var kind := "#" if _is_solid_char(ch) else ch
				var start := c
				while c < cols and _same_kind(line[c], kind):
					c += 1
				var run := c - start
				if kind == "#":
					var rect := Rect2(start * TILE, r * TILE, run * TILE, TILE)
					solids.append(rect)
					_add_static_rect(rect, false)
				elif kind == "-":
					var prect := Rect2(start * TILE, r * TILE, run * TILE, 6)
					platforms.append(prect)
					_add_static_rect(prect, true)
				elif kind == "^":
					for k in run:
						var srect := Rect2((start + k) * TILE, r * TILE + 10, TILE, 6)
						spikes.append(srect)
						spikes_up.append(srect)
				else:
					for k in run:
						var drect := Rect2((start + k) * TILE, r * TILE, TILE, 6)
						spikes.append(drect)
						spikes_down.append(drect)
				continue
			if ch == "g":
				zone_cells.append(Vector2i(c, r))
				zone_set[Vector2i(c, r)] = true
			_spawn_from_char(ch, c, r)
			c += 1
	# 角色字符左右挨着反转区时，它站的那格也算反转区（这样角色可以生在天花板上）
	for r in rows:
		var zl: String = grid[r]
		for c in cols:
			if "PCSBXEWHRrM".contains(zl[c]):
				var left_g := c > 0 and zl[c - 1] == "g"
				var right_g := c < cols - 1 and zl[c + 1] == "g"
				if left_g or right_g:
					zone_cells.append(Vector2i(c, r))
					zone_set[Vector2i(c, r)] = true
			# 反转区顶上的倒刺格也算反转区：倒刺被尸体堵住以后，东西会贴在那里，不会上下抽搐
			elif zl[c] == "v" and r < rows - 1 and (grid[r + 1] as String)[c] == "g":
				zone_set[Vector2i(c, r)] = true
	_build_decor()
	_spawn_weighted_lift_pair()
	# 炮塔要在墙矩形建好之后再放（画在墙上面）
	for r in rows:
		var line2: String = grid[r]
		for c2 in cols:
			if line2[c2] == "T":
				var t = TurretScript.new()
				t.game = self
				t.position = _tile_center(c2, r)
				fx_root.add_child(t)
			elif line2[c2] == "L":
				_spawn_laser(c2, r)


func _is_solid_char(ch: String) -> bool:
	return ch == "#" or ch == "T" or ch == "L"


func _same_kind(ch: String, kind: String) -> bool:
	if kind == "#":
		return _is_solid_char(ch)
	return ch == kind


func _tile_center(c: int, r: int) -> Vector2:
	return Vector2(c * TILE + TILE * 0.5, r * TILE + TILE * 0.5)


func _find_marker(marker: String) -> Vector2:
	for r in rows:
		var line: String = grid[r]
		var c := line.find(marker)
		if c >= 0:
			return _tile_center(c, r)
	return Vector2.ZERO


func _spawn_from_char(ch: String, c: int, r: int) -> void:
	var pos := _tile_center(c, r)
	match ch:
		"P":
			player = PlayerScript.new()
			player.position = pos
			_add_entity(player)
		"C":
			_spawn_entity(ChargerScript, pos)
		"c":
			var execution_charger = ChargerScript.new()
			execution_charger.execution_variant = true
			execution_charger.position = pos
			_add_entity(execution_charger)
		"S":
			var shooter = ShooterScript.new()
			shooter.position = pos
			if boss_mode:
				shooter.aggro_range = 160.0
				shooter.requires_los = true
				shooter.require_on_screen = true
			_add_entity(shooter)
		"B":
			_spawn_entity(BomberScript, pos)
		"X":
			var crate = CrateScript.new()
			crate.position = pos
			if boss_mode:
				crate.progress_locked = true
				crate.swappable = false
				progress_crates.append(crate)
			_add_entity(crate)
		"E":
			_spawn_entity(BarrelScript, pos)
		"O", "Q":
			var saw = SawScript.new()
			saw.game = self
			if ch == "O":
				saw.position = Vector2(pos.x, (r + 1) * TILE - 7.0)
			else:
				saw.position = pos
				saw.speed = 0.0
			fx_root.add_child(saw)
		"D":
			door_rect = Rect2(c * TILE, (r + 1) * TILE - 24, TILE, 24)
		"R", "r":
			var m = MirrorScript.new()
			m.position = pos
			m.facing = 1.0 if ch == "R" else -1.0
			_add_entity(m)
		"A":
			chain_wheel = ChainWheelScript.new()
			chain_wheel.game = self
			chain_wheel.boss = boss_node
			chain_wheel.bone_nail = bone_nail
			chain_wheel.position = pos
			_add_entity(chain_wheel)
		"I":
			bone_nail = BoneNailScript.new()
			bone_nail.game = self
			bone_nail.boss = boss_node
			bone_nail.position = pos
			_add_entity(bone_nail)
		"J":
			var grip = ChainGripScript.new()
			grip.position = pos
			_add_entity(grip)
		"Y":
			chain_pendulum = ChainPendulumScript.new()
			chain_pendulum.game = self
			chain_pendulum.pivot = pos
			chain_pendulum.chain_length = 136.0
			chain_pendulum.position = pos + Vector2(0, chain_pendulum.chain_length)
			chain_pendulum.nail_position = hook_nail
			_add_entity(chain_pendulum)
		"N":
			pass
		"V":
			_spawn_entity(StoneWingScript, pos)
		"U":
			_spawn_entity(HookPenitentScript, pos)
		"F":
			var latch = LiftLatchScript.new()
			latch.game = self
			latch.position = pos
			fx_root.add_child(latch)
		"Z":
			boss_node = ThirdNailScript.new()
			boss_node.game = self
			boss_node.position = pos
			level_root.add_child(boss_node)
		"3":
			boss_lift = BossLiftScript.new()
			boss_lift.game = self
			boss_lift.position = pos
			boss_lift.stops = [
				pos.y,
				35.0 * TILE + 3.0,
				31.0 * TILE + 3.0,
				28.0 * TILE + 3.0,
				23.0 * TILE + 3.0,
				19.0 * TILE + 3.0,
				15.0 * TILE + 3.0,
			]
			fx_root.add_child(boss_lift)
		"W":
			_spawn_entity(SwapperScript, pos)
		"H":
			_spawn_entity(HeavyScript, pos)
		"M":
			_spawn_entity(MimicScript, pos)
		"b":
			_spawn_entity(PlumbScript, pos)
		"K":
			var k = CrusherScript.new()
			k.game = self
			k.position = pos
			var rr := r + 1
			while rr < rows and not is_ground(_tile_center(c, rr)):
				rr += 1
			k.drop = float(rr - r - 1) * TILE
			fx_root.add_child(k)


func _spawn_laser(c: int, r: int) -> void:
	var l = LaserScript.new()
	l.game = self
	l.position = _tile_center(c, r)
	# 朝没有墙的一侧发射，一直打到对面的墙
	l.dir = 1.0 if not _is_solid_char(tile_at(_tile_center(c + 1, r))) else -1.0
	var x: float = l.position.x + l.dir * TILE
	while not solid_at(Vector2(x, l.position.y)) and x > 0.0 and x < cols * TILE:
		x += l.dir * 4.0
	l.end_x = x
	l.timer = 1.0 + float((r * 7) % 5) * 0.4   # 错开节奏
	fx_root.add_child(l)


func _spawn_weighted_lift_pair() -> void:
	var left_pos := Vector2.ZERO
	var right_pos := Vector2.ZERO
	for r in rows:
		var line: String = grid[r]
		for c in cols:
			if line[c] == "1":
				left_pos = _tile_center(c, r)
			elif line[c] == "2":
				right_pos = _tile_center(c, r)
	if left_pos == Vector2.ZERO or right_pos == Vector2.ZERO:
		return
	var pair = WeightedLiftPairScript.new()
	pair.game = self
	pair.left_position = left_pos
	pair.right_position = right_pos
	pair.min_y = lift_min_row * TILE + 8.0
	if lift_max_row > 0:
		pair.max_y = lift_max_row * TILE + 8.0
	else:
		pair.max_y = left_pos.y
	fx_root.add_child(pair)
	weighted_lift = pair


func _spawn_entity(scr: Script, pos: Vector2) -> void:
	var e = scr.new()
	e.position = pos
	_add_entity(e)


func _add_static_rect(r: Rect2, one_way: bool) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = r.get_center()
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	cs.shape = shape
	cs.one_way_collision = one_way
	body.add_child(cs)
	level_root.add_child(body)


# ---------------------------------------------------------------- 格子查询

func tile_at(p: Vector2) -> String:
	var c := floori(p.x / TILE)
	var r := floori(p.y / TILE)
	if r >= rows:
		return "."
	if r < 0 or c < 0 or c >= cols:
		return "#"
	var line: String = grid[r]
	return line[c]


## 地形绘制用：格子 (c, r) 是不是实心（地图外面当作实心）
func is_solid_tile(c: int, r: int) -> bool:
	if r < 0 or r >= rows or c < 0 or c >= cols:
		return true
	var line: String = grid[r]
	return _is_solid_char(line[c])


func solid_at(p: Vector2) -> bool:
	return _is_solid_char(tile_at(p))


func has_line_of_sight(a: Vector2, b: Vector2) -> bool:
	var steps := int(a.distance_to(b) / 4.0)
	for i in range(1, steps):
		if solid_at(a.lerp(b, float(i) / float(steps))):
			return false
	return true


func is_world_on_screen(p: Vector2, margin: float = 16.0) -> bool:
	var screen := world_to_screen(p)
	return (
		screen.x >= -margin and screen.x <= 480.0 + margin
		and screen.y >= -margin and screen.y <= 270.0 + margin
	)


func is_ground(p: Vector2) -> bool:
	var ch := tile_at(p)
	return _is_solid_char(ch) or ch == "-"


func is_spike_at(p: Vector2) -> bool:
	var ch := tile_at(p)
	return ch == "^" or ch == "v"


## 重力方向：在 g 格子里是 -1（向上掉）
func gravity_dir_at(p: Vector2) -> float:
	var d := -1.0 if zone_set.has(Vector2i(floori(p.x / TILE), floori(p.y / TILE))) else 1.0
	return -d if world_flip else d


## 敌人往 dir 方向走一步是否安全（不会走下平台、不会走进地刺）
func safe_step(e, dir: float) -> bool:
	if dir == 0.0:
		return true
	var g: float = e.gdir
	var fx: float = e.position.x + dir * (e.half.x + 3.0)
	var foot_y: float = e.position.y + g * (e.half.y + 4.0)
	var body_y: float = e.position.y + g * (e.half.y - 2.0)
	if solid_at(Vector2(fx, e.position.y)):
		return true   # 前面是墙，move_and_slide 自己会停
	if gravity_dir_at(Vector2(fx, e.position.y)) != g:
		return false  # 不会自己走进重力不同的区域
	var ground := solid_at(Vector2(fx, foot_y)) if g < 0.0 else is_ground(Vector2(fx, foot_y))
	return ground and not is_spike_at(Vector2(fx, body_y))


# ---------------------------------------------------------------- 主循环

func _process(_delta: float) -> void:
	# 真实时间步长（不受 time_scale 影响）
	var now := Time.get_ticks_usec()
	var rdt := 0.0
	if last_us > 0:
		rdt = minf(float(now - last_us) / 1000000.0, 0.1)
	last_us = now

	var want_danger := danger and not game_over
	danger_amt = move_toward(danger_amt, 1.0 if want_danger else 0.0, rdt * 7.0)

	# 时间流速：顿帧 > 死亡慢放 > 子弹时间 > 正常
	var stopping := hitstop_until > 0 and Time.get_ticks_msec() < hitstop_until
	if not stopping:
		hitstop_until = 0
	if select_open:
		Engine.time_scale = 0.0   # 选关时整个游戏定住
	elif stopping:
		Engine.time_scale = 0.05
	elif cleared:
		Engine.time_scale = 1.0
	elif game_over:
		Engine.time_scale = 0.35
	else:
		Engine.time_scale = lerpf(1.0, SLOWMO_SCALE, danger_amt)

	if not game_over and not select_open:
		level_time += rdt
		run_time += rdt
	if cleared and not all_clear:
		clear_t += rdt
		if clear_t > 1.1:
			_go_to_level(level_index + 1)
			return

	invert_t = maxf(invert_t - rdt, 0.0)
	impact_t = maxf(impact_t - rdt, 0.0)
	burst_t = maxf(burst_t - rdt, 0.0)
	perfect_t = maxf(perfect_t - rdt, 0.0)
	fx_time += rdt
	var want_heat := clampf(float(combo - 1) / 5.0, 0.0, 1.0) if not game_over else 0.0
	heat = move_toward(heat, want_heat, rdt * (3.0 if want_heat > heat else 0.8))
	_update_camera(rdt)

	var mat := invert_rect.material as ShaderMaterial
	mat.set_shader_parameter("invert", 1.0 if invert_t > 0.0 else 0.0)
	mat.set_shader_parameter("impact", 1.0 if impact_t > 0.0 else 0.0)
	mat.set_shader_parameter("wave", danger_amt)
	_update_iris(mat)


## 所有脚本都通过这里放音效
func play_sfx(id: String, pitch_var: float = 0.06) -> void:
	if sfx != null:
		sfx.play(id, pitch_var)


## 圆形转场：开场从主角身上张开；过关时收向出口门
func _update_iris(mat: ShaderMaterial) -> void:
	var r := 4000.0
	var c := SCREEN_CENTER
	if player != null and level_time < 0.5 and not game_over:
		c = world_to_screen(player.position)
		r = 520.0 * ease(level_time / 0.5, 0.4)
	elif cleared and not all_clear:
		c = world_to_screen(door_rect.get_center())
		r = 520.0 * (1.0 - ease(clampf((clear_t - 0.55) / 0.5, 0.0, 1.0), 2.0))
	mat.set_shader_parameter("iris_center", c)
	mat.set_shader_parameter("iris_r", r)


## 世界坐标 -> 屏幕像素坐标（考虑镜头缩放、旋转、震动）
func world_to_screen(p: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * p


func _physics_process(delta: float) -> void:
	swap_cd = maxf(swap_cd - delta, 0.0)
	_update_effects(delta)
	if not game_over:
		if combo_timer > 0.0:
			combo_timer -= delta
			if combo_timer <= 0.0:
				combo = 0
		if shift_energy < MAX_SHIFT:
			regen_t += delta
			if regen_t >= SHIFT_REGEN:
				regen_t = 0.0
				shift_energy += 1
				play_sfx("tick", 0.0)
		else:
			regen_t = 0.0
		_update_lava(delta)
		_check_hazards()
		_update_target()
		_check_door()
		var prev_kind := danger_kind
		danger_kind = _compute_danger()
		if prev_kind == 0 and danger_kind > 0:
			play_sfx("slowmo", 0.02)
		danger = danger_kind > 0
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if DEBUG_LEVEL_SELECT and _select_input(event):
		if is_inside_tree():   # 选了关会重载场景，这时节点已经不在场景树里了
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode
		if all_clear:
			if key == KEY_R:
				level_index = 0
				total_deaths = 0
				total_score = 0
				run_time = 0.0
				run_perfects = 0
				run_best_combo = 0
				run_total_kills = 0
				_restart()
			return
		if key == KEY_R:
			_restart()
		elif DEBUG_LEVEL_SELECT and key == KEY_N:
			_go_to_level(level_index + 1)    # 调试：下一关
		elif DEBUG_LEVEL_SELECT and key == KEY_B:
			_go_to_level(level_index - 1)    # 调试：上一关
		elif event.keycode == KEY_SHIFT:
			if _can_quick_retry():
				_restart()
			else:
				try_swap()
		elif key == KEY_SPACE and _can_quick_retry():
			_restart()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _can_quick_retry():
			_restart()
		else:
			try_swap()


## 临时选关：Tab 开关；W/S 上下、A/D 换列、回车/空格/Shift 进入；也可以直接用鼠标点。
## 返回 true 表示这个输入被选关吃掉了
func _select_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed:
		var key: int = event.physical_keycode
		if key == KEY_TAB and not event.echo:
			select_open = not select_open
			select_idx = level_index
			return true
		if not select_open:
			return false
		var n: int = Levels.LEVELS.size()
		match key:
			KEY_W, KEY_UP:
				select_idx = (select_idx - 1 + n) % n
			KEY_S, KEY_DOWN:
				select_idx = (select_idx + 1) % n
			KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT:
				select_idx = (select_idx + n / 2) % n
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_SHIFT:
				_pick_level(select_idx)
			KEY_ESCAPE:
				select_open = false
		return true
	if not select_open:
		return false
	if event is InputEventMouseMotion or (event is InputEventMouseButton and event.pressed):
		var mp: Vector2 = get_viewport().get_mouse_position()
		for i in Levels.LEVELS.size():
			if select_item_rect(i).has_point(mp):
				select_idx = i
				if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
					_pick_level(i)
				break
	return true


func _pick_level(i: int) -> void:
	select_open = false
	call_deferred("_go_to_level", i)   # 等这次输入处理完再换关


func level_names() -> Array:
	var out: Array = []
	for d in Levels.LEVELS:
		out.append((d as Dictionary)["name"])
	return out


## 选关面板里第 i 关那一行的位置（画面坐标，480x270）
func select_item_rect(i: int) -> Rect2:
	var half: int = (Levels.LEVELS.size() + 1) / 2
	var col := i / half
	var row := i % half
	return Rect2(78.0 + col * 166.0, 52.0 + row * 19.0, 158.0, 15.0)


func _can_quick_retry() -> bool:
	return game_over and not cleared and death_t > 0.45


# ---------------------------------------------------------------- 换位

func try_swap() -> void:
	if game_over or swap_cd > 0.0:
		return
	if flip_level and (target == null or not is_instance_valid(target) or not target.alive):
		# 翻转关：没有目标时按 SHIFT 只翻世界
		if shift_energy <= 0:
			_swap_refused("NO SHIFT")
			return
		shift_energy -= 1
		swap_cd = SWAP_COOLDOWN
		_flip_world()
		return
	if target == null or not is_instance_valid(target) or not target.alive:
		if reach_fail != null and is_instance_valid(reach_fail):
			var too_far: bool = SWAP_RANGE > 0.0 and player.position.distance_to(reach_fail.position) > SWAP_RANGE
			_swap_refused("TOO FAR" if too_far else "BLOCKED")
		return
	if shift_energy <= 0:
		_swap_refused("NO SHIFT")
		return
	shift_energy -= 1
	var perfect := danger_kind == 2
	var a: Vector2 = player.position
	var b: Vector2 = target.position

	_swap_bodies(player, target)
	target.on_swapped()
	swap_cd = SWAP_COOLDOWN
	player.invuln = SWAP_INVULN
	_swap_fx(a, b, player, target, perfect)
	play_sfx("perfect" if perfect else "swap")

	if perfect:
		perfects += 1
		perfect_t = 0.9
		impact_t = 0.07
		burst_t = 0.35
		burst_pos = world_to_screen((a + b) * 0.5)
		score += PERFECT_BONUS
		_refund("+SHIFT")   # 完美换位不花能量
	if flip_level:
		_flip_world()


## 整个世界的重力上下翻转：所有东西（包括你）都往另一边掉
func _flip_world() -> void:
	world_flip = not world_flip
	add_shake(5.0)
	invert_t = maxf(invert_t, 0.08)
	play_sfx("slam", 0.05)
	labels.append({"p": player.position + Vector2(0, -22), "text": "FLIP", "t": 0.7, "big": true})


func _swap_refused(why: String) -> void:
	play_sfx("fail", 0.02)
	swap_cd = 0.1
	add_shake(1.0)
	labels.append({"p": player.position + Vector2(0, -20), "text": why, "t": 0.6, "big": false})


func _refund(text: String) -> void:
	if shift_energy < MAX_SHIFT:
		shift_energy += 1
		play_sfx("tick", 0.0)
		labels.append({"p": player.position + Vector2(0, -24), "text": text, "t": 0.8, "big": false})


## 能不能和 e 换位：中间没有墙（单向平台不挡）；设了距离上限的话还要够近
func can_reach(e) -> bool:
	if player == null:
		return false
	var a: Vector2 = player.position
	var b: Vector2 = e.position
	if SWAP_RANGE > 0.0 and a.distance_to(b) > SWAP_RANGE:
		return false
	var steps := int(a.distance_to(b) / 4.0)
	for i in range(1, steps):
		if solid_at(a.lerp(b, float(i) / float(steps))):
			return false
	return true


## 位置和速度一起交换：你下落中换位，对方就带着你的下落速度掉下去
func _swap_bodies(e1, e2) -> void:
	ghosts.append({"p": e1.position, "half": e1.half, "t": 0.35})
	ghosts.append({"p": e2.position, "half": e2.half, "t": 0.35})
	var p1: Vector2 = e1.position
	var p2: Vector2 = e2.position
	var v1: Vector2 = e1.velocity
	# 两个身体高度不一样（主角 12 像素高、冲锋者只有 10）：换位后脚底对齐，
	# 不然高个子的脚会陷进单向平台里，Godot 就让它从平台上掉下去
	e1.position = p2 + Vector2(0, gravity_dir_at(p2) * (e2.half.y - e1.half.y))
	e1.velocity = e2.velocity
	e2.position = p1 + Vector2(0, gravity_dir_at(p1) * (e1.half.y - e2.half.y))
	e2.velocity = v1


func _swap_fx(a: Vector2, b: Vector2, e1, e2, big: bool) -> void:
	var strength := 1.0 if big else 0.6
	e1.play_swap_fx(strength)
	e2.play_swap_fx(strength)
	# 闪电 + 冲击波 + 沿连线飞散的粒子
	swap_bolts.append({"a": a, "b": b, "t": 0.22, "w": 2.0 if big else 1.0})
	rings.append({"p": a, "t": 0.3, "max": 26.0 if big else 18.0})
	rings.append({"p": b, "t": 0.3, "max": 26.0 if big else 18.0})
	_spawn_streaks(a, b, 18 if big else 10)
	# 镜头：推近冲击 + 朝换位方向侧倾 + 看向两人中点 + 反色一帧
	punch = maxf(punch, PERFECT_PUNCH if big else SWAP_PUNCH)
	var dir_x := signf(b.x - a.x)
	if dir_x == 0.0:
		dir_x = 1.0
	roll = SWAP_ROLL * dir_x * (1.6 if big else 1.0)
	focus = (a + b) * 0.5
	focus_w = 0.5
	# 打击感：冲击帧（每次都有）+ 反色（只有完美换位）+ 定向镜头冲击 + 打击火花 + 集中线 + 顿帧
	impact_t = maxf(impact_t, 0.07 if big else 0.035)
	if big:
		invert_t = 0.07
	var d := b - a
	if d.length() > 0.5:
		kick = d.normalized() * (7.0 if big else 4.5)
	sparks.append({"p": a, "t": 0.16, "big": big, "seed": rng.randi() % 1000})
	sparks.append({"p": b, "t": 0.16, "big": big, "seed": rng.randi() % 1000})
	burst_t = maxf(burst_t, 0.35 if big else 0.15)
	burst_pos = world_to_screen((a + b) * 0.5)
	add_shake(4.0 if big else 2.5)
	hitstop(0.14 if big else 0.08)
	if Input.get_connected_joypads().size() > 0:
		Input.start_joy_vibration(Input.get_connected_joypads()[0], 0.5, 0.9 if big else 0.6, 0.15 if big else 0.1)


## 换位者强行和主角换位
func enemy_swap(swapper) -> void:
	if game_over or player == null or not player.alive or not swapper.alive:
		return
	var a: Vector2 = swapper.position
	var b: Vector2 = player.position
	_swap_bodies(swapper, player)
	play_sfx("enemy_swap")
	player.invuln = SWAP_INVULN
	_swap_fx(a, b, swapper, player, false)


func _update_target() -> void:
	target = null
	reach_fail = null
	var m := get_global_mouse_position()
	var best := TARGET_RADIUS
	var cand = null
	for e in get_entities():
		if e == player or not e.swappable:
			continue
		var d: float = m.distance_to(e.position) - e.half.x
		if d < best:
			best = d
			cand = e
	if cand != null:
		if can_reach(cand):
			target = cand
		else:
			reach_fail = cand


## 有没有什么东西马上要打到主角（触发子弹时间 / 判定完美换位）
## 返回 2：敌人攻击或机关（躲开算完美换位）；1：只是往刺上/深渊里掉（不算完美）；0：安全
func _compute_danger() -> int:
	if player == null or not player.alive:
		return 0
	var pc: Vector2 = player.position
	var fx: Array = fx_root.get_children()
	for f in fx:
		if f.has_method("threatens") and f.threatens(pc):
			return 2
	for e in get_entities():
		if e.has_method("threatens") and e.threatens(pc):
			return 2
	var g: float = player.gdir
	if player.velocity.y * g > 40.0:
		# 正在往刺上掉（重力反转时是往天花板上的刺“掉”）
		var pr: Rect2 = player.get_hit_rect()
		var probe := Rect2(pr.position, pr.size + Vector2(0, 28))
		if g < 0.0:
			probe = Rect2(pr.position - Vector2(0, 28), pr.size + Vector2(0, 28))
		for s in spikes:
			if probe.intersects(s):
				return 1
		# 正在掉进深渊 / 掉向天空
		if g > 0.0 and pc.y > 200.0 and _nothing_below(pc):
			return 1
		if g < 0.0 and pc.y < 70.0 and _nothing_above(pc):
			return 1
	return 0


func _nothing_above(p: Vector2) -> bool:
	var y := p.y - TILE
	while y > 0.0:
		if solid_at(Vector2(p.x, y)):
			return false
		y -= TILE
	return true


func _nothing_below(p: Vector2) -> bool:
	var y := p.y + TILE
	while y < rows * TILE:
		if is_ground(Vector2(p.x, y)):
			return false
		y += TILE
	return true


# ---------------------------------------------------------------- 实体与命中

func _add_entity(e) -> void:
	e.game = self
	entities_root.add_child(e)


func get_entities() -> Array:
	var out: Array = []
	var kids: Array = entities_root.get_children()
	for c in kids:
		if c.alive:
			out.append(c)
	return out


func count_enemies() -> int:
	var n := 0
	for e in get_entities():
		if e.is_in_group("enemy"):
			n += 1
	return n


func first_entity_hit(pos: Vector2, r: float, ignore):
	for e in get_entities():
		if e == ignore:
			continue
		var rect: Rect2 = e.get_hit_rect()
		if rect.grow(r).has_point(pos):
			return e
	return null


## 返回 true 表示这次攻击被 e 吃掉了（子弹应该消失）
func hit_entity(e, cause: String) -> bool:
	if e == null or not is_instance_valid(e) or not e.alive:
		return false
	if e == player:
		if player.invuln > 0.0:
			return false
		_player_die(cause)
		return true
	if not e.killable:
		return true
	if e.has_method("immune_to") and e.immune_to(cause):
		return true
	e.alive = false
	if e.is_in_group("barrel"):
		# 爆炸桶：几乎立刻爆炸，会连锁
		spawn_blast(e.position, BARREL_BLAST, 0.06, "a barrel")
		_spawn_debris(e.position, 16, 0.3)
		add_shake(5.0)
		e.queue_free()
		return true
	_spawn_debris(e.position, 12, 0.5)
	_spawn_gibs(e.position, 4)
	_splat(e.position, e.gdir)
	rings.append({"p": e.position, "t": 0.2, "max": 14.0})
	kills += 1
	combo += 1
	best_combo = maxi(best_combo, combo)
	combo_timer = COMBO_WINDOW
	_score_kill(e.position, cause)
	add_shake(4.0)
	punch = maxf(punch, 0.05)
	hitstop(0.06)
	if e.has_method("on_killed"):
		e.on_killed(cause)
	e.queue_free()
	return true


## 同一关里：第一次用某种杀法 +奖励；同一招用第二次起分数减半
func _score_kill(pos: Vector2, cause: String) -> void:
	var style: String = KILL_STYLES.get(cause, "KILL")
	var uses: int = methods_used.get(style, 0)
	methods_used[style] = uses + 1
	var pts := 100 * combo
	var text := style
	if uses == 0:
		pts += NEW_STYLE_BONUS
		text = style + "  NEW!"
	else:
		pts = pts / 2
		text = "%s x%d" % [style, uses + 1]
	score += pts
	play_sfx("kill", 0.1)
	if uses == 0:
		play_sfx("new_style", 0.0)
	labels.append({"p": pos + Vector2(0, -12), "text": text, "t": 1.1, "big": uses == 0})
	if cause in REFUND_CAUSES:
		_refund("+SHIFT")


func damage_circle(center: Vector2, r: float, cause: String) -> void:
	for e in get_entities():
		var rect: Rect2 = e.get_hit_rect()
		var cp := Vector2(
			clampf(center.x, rect.position.x, rect.end.x),
			clampf(center.y, rect.position.y, rect.end.y))
		if center.distance_to(cp) <= r:
			hit_entity(e, cause)


func damage_rect(rect: Rect2, cause: String, ignore = null) -> int:
	var killed := 0
	for e in get_entities():
		if e == ignore:
			continue
		if rect.intersects(e.get_hit_rect()):
			var was_alive: bool = e.alive
			hit_entity(e, cause)
			if was_alive and not e.alive:
				killed += 1
	return killed


## 重装：碰到的一切都被压死
func contact_kill(heavy, cause: String) -> void:
	var hr: Rect2 = heavy.get_hit_rect().grow(1.0)
	for e in get_entities():
		if e == heavy or not e.killable:
			continue
		if hr.intersects(e.get_hit_rect()):
			hit_entity(e, cause)


func dash_hit(charger) -> void:
	var cr: Rect2 = charger.get_hit_rect().grow(2.0)
	for e in get_entities():
		if e == charger or not e.killable:
			continue
		if cr.intersects(e.get_hit_rect()):
			hit_entity(e, "a charger")


func _check_hazards() -> void:
	for e in get_entities():
		var out_bottom: bool = e.position.y > void_y
		if lava_speed > 0.0 and e.position.y + e.half.y > lava_y + 2.0:
			if e.killable:
				hit_entity(e, "the lava")
			else:
				e.queue_free()
			continue
		var out_top: bool = e.position.y < SKY_Y
		if not e.killable:
			if out_bottom or out_top:
				e.queue_free()
			continue
		if out_bottom:
			hit_entity(e, "the void")
			continue
		if out_top:
			hit_entity(e, "the sky")
			continue
		var rect: Rect2 = e.get_hit_rect()
		var on_spike := false
		for s in spikes:
			if rect.intersects(s):
				on_spike = true
				break
		if on_spike and hit_entity(e, "spikes") and e != player:
			_clog_spikes(rect)


## 地狱上涨：开局等一会儿再涨；主角爬得太远时涨得更快，压力不会断
func _update_lava(delta: float) -> void:
	if lava_speed <= 0.0 or cleared:
		return
	if lava_wait > 0.0:
		lava_wait -= delta
		return
	# 越涨越快：每过一秒速度加 LAVA_ACCEL，最多到 LAVA_MAX
	lava_t += delta
	var spd := minf(lava_speed + lava_t * LAVA_ACCEL, LAVA_MAX)
	if player != null:
		var gap: float = lava_y - player.position.y
		if gap > 170.0:
			spd *= 2.2   # 你甩得太远，它就猛追上来
		# 离你很近时：屏幕一直轻微震动 + 冒更多火星
		if gap < 90.0:
			add_shake(1.2 * (1.0 - gap / 90.0))
			if rng.randf() < delta * 30.0:
				spawn_ember(Vector2(player.position.x + rng.randf_range(-30.0, 30.0), lava_y - 2.0))
	lava_y -= spd * delta
	if rng.randf() < delta * 14.0:
		spawn_ember(Vector2(rng.randf_range(16.0, cols * TILE - 16.0), lava_y - 2.0))


## 尸体把它压住的那几格地刺堵死，之后那里就是安全的地面
func _clog_spikes(rect: Rect2) -> void:
	for i in range(spikes.size() - 1, -1, -1):
		var sr: Rect2 = spikes[i]
		if rect.intersects(sr):
			# 地板上的“刺窗”（地刺正下方是反转区）永远不会被堵：堵了就成了上下抽搐的洞
			var sc := Vector2i(floori(sr.position.x / TILE), floori(sr.position.y / TILE))
			if spikes_up.has(sr) and zone_set.has(sc + Vector2i(0, 1)):
				continue
			spikes.remove_at(i)
			var up := spikes_up.has(sr)
			spikes_up.erase(sr)
			spikes_down.erase(sr)
			clogged.append({"rect": sr, "up": up})
	terrain.queue_redraw()


func spawn_bullet(pos: Vector2, vel: Vector2, shooter) -> void:
	var b = BulletScript.new()
	b.game = self
	b.position = pos
	b.velocity = vel
	b.shooter = shooter
	fx_root.add_child(b)
	play_sfx("shoot")


func spawn_blast(pos: Vector2, r: float, fuse: float, cause: String = "a bomb") -> void:
	var bl = BlastScript.new()
	bl.game = self
	bl.cause = cause
	bl.position = pos
	bl.radius = r
	bl.fuse = fuse
	bl.total = fuse
	fx_root.add_child(bl)


func spawn_boss_bomb(pos: Vector2):
	var bomb = BossBombScript.new()
	bomb.game = self
	bomb.position = pos
	_add_entity(bomb)
	return bomb


func _player_die(cause: String) -> void:
	play_sfx("death", 0.0)
	game_over = true
	death_cause = cause
	player.alive = false
	total_deaths += 1
	deaths = total_deaths
	_spawn_debris(player.position, 28, 0.8)
	_spawn_gibs(player.position, 5)
	_splat(player.position, player.gdir)
	impact_t = 0.1
	rings.append({"p": player.position, "t": 0.4, "max": 30.0})
	add_shake(8.0)
	invert_t = 0.1
	focus = player.position
	hitstop(0.35)


# ---------------------------------------------------------------- 出口与关卡切换

func _check_door() -> void:
	var was_open := door_open
	if boss_mode:
		door_open = always_open or boss_defeated
		if boss_defeated:
			_unlock_progress_crates()
	else:
		door_open = always_open or count_enemies() == 0
	if door_open and not was_open:
		# 门打开的瞬间给个提示
		rings.append({"p": door_rect.get_center(), "t": 0.3, "max": 24.0})
		play_sfx("door", 0.0)
		add_shake(2.0)
	if door_open and player != null and player.alive and player.get_hit_rect().intersects(door_rect):
		_level_clear()


func _unlock_progress_crates() -> void:
	for crate in progress_crates:
		if crate != null and is_instance_valid(crate):
			crate.progress_locked = false
			crate.swappable = true
			crate.queue_redraw()


func _level_clear() -> void:
	play_sfx("clear", 0.0)
	game_over = true
	cleared = true
	clear_t = 0.0
	total_score += score
	run_perfects += perfects
	run_best_combo = maxi(run_best_combo, best_combo)
	run_total_kills += kills
	# 评级：杀法越多样越高；S 还要求至少一次完美换位
	var distinct := methods_used.size()
	if distinct >= mini(3, kills) and perfects >= 1:
		rank = "S"
	elif distinct >= mini(2, kills):
		rank = "A"
	else:
		rank = "B"
	punch = maxf(punch, 0.2)
	invert_t = 0.05
	if level_index + 1 >= level_count:
		all_clear = true


func get_run_time() -> float:
	return run_time


func get_total_score() -> int:
	return total_score


func get_run_perfects() -> int:
	return run_perfects


func get_run_best_combo() -> int:
	return run_best_combo


func get_run_total_kills() -> int:
	return run_total_kills


func _go_to_level(idx: int) -> void:
	level_index = clampi(idx, 0, level_count - 1)
	_restart()


func _restart() -> void:
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


# ---------------------------------------------------------------- 镜头

func hitstop(sec: float) -> void:
	hitstop_until = maxi(hitstop_until, Time.get_ticks_msec() + int(sec * 1000.0))
	Engine.time_scale = 0.05


func add_shake(amount: float) -> void:
	shake = maxf(shake, amount)


## 高关卡：镜头中心跟着主角（主角略偏下，多看上面一点）
func _cam_target_y() -> float:
	return clampf(player.position.y - 24.0, 135.0, rows * TILE - 135.0)


func _update_camera(rdt: float) -> void:
	shake = move_toward(shake, 0.0, 30.0 * rdt)
	kick *= exp(-16.0 * rdt)
	punch *= exp(-9.0 * rdt)
	roll *= exp(-8.0 * rdt)
	focus_w *= exp(-5.0 * rdt)

	var zoom_amt := 1.0 + punch + danger_amt * DANGER_ZOOM
	var base := SCREEN_CENTER
	if rows > 17 and player != null:
		cam_y = lerpf(cam_y, _cam_target_y(), 1.0 - exp(-6.0 * rdt))
		base = Vector2(SCREEN_CENTER.x, cam_y)

	# Start from the current follow position. Swaps may pull toward their
	# midpoint, then danger may pull further toward the player without ever
	# mixing a screen-space default into a world-space camera coordinate.
	var look := base
	if focus_w > 0.0:
		look = base.lerp(focus, focus_w)
	if danger_amt > 0.0 and player != null:
		look = look.lerp(player.position, danger_amt * 0.6)
	if game_over and not cleared:
		death_t = minf(death_t + rdt, 1.0)
		zoom_amt = lerpf(zoom_amt, DEATH_ZOOM, ease(death_t, 0.4))
		look = base.lerp(focus, 0.9)

	camera.zoom = Vector2(zoom_amt, zoom_amt)
	camera.position = look
	camera.rotation = roll
	camera.offset = Vector2(rng.randf_range(-shake, shake), rng.randf_range(-shake, shake)) + kick


# ---------------------------------------------------------------- 特效

func _spawn_debris(pos: Vector2, count: int, blood: float = 0.0) -> void:
	for i in count:
		var ang := rng.randf_range(-PI, 0.0)   # 向上半圈飞散
		var spd := rng.randf_range(60.0, 180.0)
		var col := C_BLOOD if rng.randf() < blood else Color.WHITE
		debris.append({"p": pos, "v": Vector2.from_angle(ang) * spd, "t": rng.randf_range(0.4, 0.8), "g": 500.0, "c": col})


## 落地扬尘：往两边贴地飞
## 主角身上冒的火星：往上飘，很快熄灭
func spawn_ember(pos: Vector2) -> void:
	var col := Color(1.0, 0.35, 0.2) if rng.randf() < 0.7 else Color(0.66, 0.08, 0.1)
	debris.append({"p": pos, "v": Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-35.0, -20.0)), "t": rng.randf_range(0.35, 0.6), "g": -20.0, "c": col, "s": 1})


## 肉块：比碎片大，会落地弹跳、滚一会儿再消失
func _spawn_gibs(pos: Vector2, count: int) -> void:
	for i in count:
		var ang := rng.randf_range(-PI * 0.9, -PI * 0.1)
		var spd := rng.randf_range(80.0, 170.0)
		var col := C_BLOOD if i % 2 == 0 else Color.WHITE
		debris.append({"p": pos, "v": Vector2.from_angle(ang) * spd, "t": rng.randf_range(1.6, 2.4), "g": 520.0, "c": col, "s": 3, "bounce": true})


## 血迹：顺着重力方向找到最近的地面（或天花板），留下一摊血和几滴血点
func _splat(pos: Vector2, g: float) -> void:
	var y := pos.y
	var found := false
	for i in 40:
		y += 2.0 * g
		var hit := solid_at(Vector2(pos.x, y)) if g < 0.0 else is_ground(Vector2(pos.x, y))
		if hit:
			found = true
			break
	if not found:
		return
	var surface := floorf(y / TILE) * TILE if g > 0.0 else (floorf(y / TILE) + 1.0) * TILE
	var w := rng.randf_range(8.0, 16.0)
	var drops: Array = []
	for i in 5:
		drops.append(Vector2(rng.randf_range(-w, w), rng.randf_range(1.0, 4.0)))
	decals.append({"x": pos.x, "y": surface, "w": w, "dir": g, "drops": drops})
	if decals.size() > 60:
		decals.pop_front()


func _build_decor() -> void:
	# 在露天的地面上随机摆骷髅、骨头、蜡烛（同一关每次都一样）
	for r in range(1, rows):
		var line: String = grid[r]
		var above: String = grid[r - 1]
		for c in cols:
			if not _is_solid_char(line[c]) or above[c] != ".":
				continue
			var h := absi((c * 92821) ^ (r * 68917) ^ (level_index * 131)) % 100
			var px := float(c * TILE) + 3.0 + float(h % 9)
			var p := Vector2(px, float(r * TILE))
			if h < 9:
				decor.append({"kind": "skull", "p": p})
			elif h < 17:
				decor.append({"kind": "candle", "p": p})
			elif h < 23:
				decor.append({"kind": "bones", "p": p})


func spawn_dust(pos: Vector2, count: int) -> void:
	for i in count:
		var side := -1.0 if i % 2 == 0 else 1.0
		var v := Vector2(side * rng.randf_range(30.0, 80.0), rng.randf_range(-30.0, -5.0))
		debris.append({"p": pos, "v": v, "t": rng.randf_range(0.15, 0.3), "g": 60.0, "c": Color(0.66, 0.66, 0.66)})


func _spawn_streaks(a: Vector2, b: Vector2, count: int) -> void:
	var d := b - a
	var perp := Vector2(-d.y, d.x).normalized()
	if perp == Vector2.ZERO:
		perp = Vector2.UP
	for i in count:
		var p := a.lerp(b, rng.randf())
		var v := perp * rng.randf_range(-90.0, 90.0) + d.normalized() * rng.randf_range(-30.0, 30.0)
		debris.append({"p": p, "v": v, "t": rng.randf_range(0.15, 0.35), "g": 0.0})


func _tick_list(list: Array, delta: float) -> void:
	for i in range(list.size() - 1, -1, -1):
		var it: Dictionary = list[i]
		it["t"] -= delta
		if it["t"] <= 0.0:
			list.remove_at(i)


func _update_effects(delta: float) -> void:
	_tick_list(swap_bolts, delta)
	_tick_list(ghosts, delta)
	_tick_list(sparks, delta)
	_tick_list(rings, delta)
	for d in debris:
		d["v"] += Vector2(0, d["g"] * delta)
		var np: Vector2 = d["p"] + d["v"] * delta
		if d.get("bounce", false):
			var v: Vector2 = d["v"]
			if v.y > 0.0 and is_ground(np):
				# 落地：弹起来一点，越弹越低，最后停在地上
				v = Vector2(v.x * 0.6, -v.y * 0.35)
				if absf(v.y) < 30.0:
					v = Vector2(v.x * 0.5, 0.0)
					d["g"] = 0.0
				d["v"] = v
				np = d["p"]
			elif solid_at(np):
				d["v"] = Vector2(-v.x * 0.4, v.y)
				np = d["p"]
		d["p"] = np
	_tick_list(debris, delta)
	_tick_list(labels, delta)


func _draw_bolt(a: Vector2, b: Vector2, alpha: float, width: float) -> void:
	var seg := 9
	var d := b - a
	var perp := Vector2(-d.y, d.x).normalized()
	var pts := PackedVector2Array()
	for i in seg + 1:
		var t := float(i) / float(seg)
		var p := a.lerp(b, t)
		if i != 0 and i != seg:
			p += perp * rng.randf_range(-7.0, 7.0)
		pts.append(p)
	draw_polyline(pts, Color(1, 1, 1, alpha), width)


func _draw() -> void:
	# 地形在 terrain.gd 里画，背景在 background.gd 里画

	# 地面装饰：骷髅、骨头、蜡烛（蜡烛火苗会晃，周围一圈红色光晕）
	for dc in decor:
		var p: Vector2 = dc["p"]
		match dc["kind"]:
			"skull":
				draw_rect(Rect2(p.x, p.y - 4.0, 5, 3), Color.WHITE)
				draw_rect(Rect2(p.x + 1.0, p.y - 1.0, 3, 1), Color.WHITE)
				draw_rect(Rect2(p.x + 1.0, p.y - 3.0, 1, 1), Color.BLACK)
				draw_rect(Rect2(p.x + 3.0, p.y - 3.0, 1, 1), Color.BLACK)
			"bones":
				draw_rect(Rect2(p.x, p.y - 1.0, 6, 1), Color(0.66, 0.66, 0.66))
				draw_rect(Rect2(p.x, p.y - 2.0, 1, 1), Color(0.66, 0.66, 0.66))
				draw_rect(Rect2(p.x + 5.0, p.y - 2.0, 1, 1), Color(0.66, 0.66, 0.66))
			"candle":
				var fl := sin(fx_time * 17.0 + p.x) * 0.5 + sin(fx_time * 29.0 + p.x * 3.0) * 0.5
				draw_circle(Vector2(p.x + 1.0, p.y - 8.0), 9.0 + fl, Color(C_BLOOD.r, C_BLOOD.g, C_BLOOD.b, 0.12))
				draw_rect(Rect2(p.x, p.y - 5.0, 2, 5), Color.WHITE)
				var fh := 3.0 + fl
				draw_rect(Rect2(p.x, p.y - 5.0 - fh, 2, fh), Color(1.0, 0.35, 0.2))
				draw_rect(Rect2(p.x + (1.0 if fl > 0.0 else 0.0), p.y - 6.0 - fh, 1, 1), Color(1.0, 0.35, 0.2))

	# 血迹：地上一摊 + 周围溅开的血点（天花板上的会往下滴）
	for dl in decals:
		var dx: float = dl["x"]
		var dy: float = dl["y"]
		var dw: float = dl["w"]
		var g: float = dl["dir"]
		var top := dy - 2.0 if g > 0.0 else dy
		draw_rect(Rect2(dx - dw * 0.5, top, dw, 2), C_BLOOD)
		draw_rect(Rect2(dx - dw * 0.3, top - g, dw * 0.6, 1), Color(0.4, 0.04, 0.06))
		for dp in dl["drops"]:
			var v: Vector2 = dp
			draw_rect(Rect2(dx + v.x, dy - v.y * g, 1, 1), C_BLOOD)

	# 重力反转区：稀疏点阵 + 往上飘的小箭头
	var t_up := fmod(Time.get_ticks_msec() * 0.02, 16.0)
	for zc in zone_cells:
		var zp := Vector2(zc.x * TILE, zc.y * TILE)
		# 整格淡淡铺一层（调色板着色器会把它变成网点），一眼能看出区域范围
		draw_rect(Rect2(zp, Vector2(TILE, TILE)), Color(1, 1, 1, 0.07))
		draw_rect(Rect2(zp + Vector2(2, 2), Vector2(1, 1)), Color(1, 1, 1, 0.5))
		draw_rect(Rect2(zp + Vector2(10, 10), Vector2(1, 1)), Color(1, 1, 1, 0.5))
		# 区域左右边缘画一条竖虚线
		if not zone_set.has(Vector2i(zc.x - 1, zc.y)):
			for k in range(0, TILE, 4):
				draw_rect(Rect2(zp + Vector2(0, k), Vector2(1, 2)), Color(1, 1, 1, 0.45))
		if not zone_set.has(Vector2i(zc.x + 1, zc.y)):
			for k in range(0, TILE, 4):
				draw_rect(Rect2(zp + Vector2(TILE - 1, k), Vector2(1, 2)), Color(1, 1, 1, 0.45))
		if (zc.x + zc.y) % 2 == 0:
			var ay := zp.y + 16.0 - t_up
			draw_line(Vector2(zp.x + 8, ay), Vector2(zp.x + 5, ay + 3), Color(1, 1, 1, 0.65), 1.0)
			draw_line(Vector2(zp.x + 8, ay), Vector2(zp.x + 11, ay + 3), Color(1, 1, 1, 0.65), 1.0)

	# 地狱岩浆：暗红底 + 起伏的亮边
	if lava_speed > 0.0 and lava_y < rows * TILE + 8.0:
		var w := float(cols * TILE)
		draw_rect(Rect2(-16.0, lava_y, w + 32.0, rows * TILE + 200.0 - lava_y), Color(0.3, 0.02, 0.04))
		var x := 0.0
		while x < w:
			var wave := sin(x * 0.09 + fx_time * 3.0) * 2.0 + sin(x * 0.23 - fx_time * 5.0)
			draw_rect(Rect2(x, lava_y + wave - 1.0, 4.0, 4.0), C_BLOOD)
			draw_rect(Rect2(x, lava_y + wave - 1.0, 4.0, 1.0), Color(1.0, 0.35, 0.2))
			x += 4.0
		draw_rect(Rect2(-16.0, lava_y + 6.0, w + 32.0, 2.0), Color(0.5, 0.05, 0.08))

	# 出口门：石头门框。关着是铁栏 + 红锁，开了里面透出闪烁的白光
	if door_rect.size != Vector2.ZERO:
		var dr := door_rect
		draw_rect(dr.grow(2.0), Color(0.66, 0.66, 0.66))
		draw_rect(Rect2(dr.position - Vector2(2, 2), Vector2(dr.size.x + 4.0, 2)), Color.WHITE)
		draw_rect(Rect2(dr.position - Vector2(2, 2), Vector2(1, dr.size.y + 2.0)), Color.WHITE)
		if door_open:
			var blink := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.01)
			draw_rect(dr, Color(1, 1, 1, blink))
			var ft := Time.get_ticks_msec() * 0.03
			for k in 3:
				var fy := dr.end.y - fmod(ft + k * 8.0, dr.size.y)
				draw_rect(Rect2(dr.position.x + 3.0 + k * 4.0, fy, 1, 2), Color.BLACK)
			var by := 2.0 * sin(Time.get_ticks_msec() * 0.008)
			PF.draw(self, Vector2(dr.get_center().x, dr.position.y - 12.0 + by), "EXIT", 1, Color.WHITE, 1, Color.BLACK)
		else:
			draw_rect(dr, Color.BLACK)
			for k in 3:
				draw_rect(Rect2(dr.position.x + 3.0 + k * 4.0, dr.position.y + 1.0, 2, dr.size.y - 1.0), Color(0.33, 0.33, 0.33))
			draw_rect(Rect2(dr.get_center() - Vector2(2, 2), Vector2(4, 5)), C_BLOOD)

	# 关卡开头：主角头顶的箭头，告诉玩家“这是你”
	if player != null and player.alive and level_time < 2.0:
		var bob := 2.0 * sin(Time.get_ticks_msec() * 0.012)
		var ap: Vector2 = player.position + Vector2(0, -22.0 + bob)
		var aa := clampf((2.0 - level_time) * 2.0, 0.0, 1.0)
		draw_colored_polygon(PackedVector2Array([
			ap + Vector2(-4, -4), ap + Vector2(4, -4), ap + Vector2(0, 1)]), Color(1, 1, 1, aa))

	if not game_over and player != null and player.alive:
		# 换位范围：设了距离上限才画（主角周围一圈很淡的虚线圈）
		if SWAP_RANGE > 0.0:
			var ra := Time.get_ticks_msec() * 0.0004
			for i in 16:
				var a0 := ra + float(i) * TAU / 16.0
				draw_arc(player.position, SWAP_RANGE, a0, a0 + 0.18, 4, Color(1, 1, 1, 0.09), 1.0)
		# 能量格：头顶三个小菱形，下一格回复中的那个慢慢变亮
		for i in MAX_SHIFT:
			var pp: Vector2 = player.position + Vector2((i - 1) * 6.0, -17.0 * player.gdir)
			var dm := PackedVector2Array([pp + Vector2(0, -2.5), pp + Vector2(2.5, 0), pp + Vector2(0, 2.5), pp + Vector2(-2.5, 0)])
			if i < shift_energy:
				draw_colored_polygon(dm, Color.WHITE)
			else:
				var k := regen_t / SHIFT_REGEN if i == shift_energy else 0.0
				dm.append(dm[0])
				draw_polyline(dm, Color(1, 1, 1, 0.3 + 0.5 * k), 1.0)

	# 够不着的目标：虚线只画到被挡住的地方，目标上打个叉
	if not game_over and reach_fail != null and is_instance_valid(reach_fail) and player != null:
		var fp: Vector2 = reach_fail.position
		var a: Vector2 = player.position
		var end := fp
		var steps := int(a.distance_to(fp) / 4.0)
		for i in range(1, steps):
			var q := a.lerp(fp, float(i) / float(steps))
			if solid_at(q) or (SWAP_RANGE > 0.0 and a.distance_to(q) > SWAP_RANGE):
				end = q
				break
		draw_dashed_line(a, end, Color(1, 1, 1, 0.15), 1.0, 2.0)
		draw_line(fp + Vector2(-4, -4), fp + Vector2(4, 4), Color(1, 1, 1, 0.5), 1.0)
		draw_line(fp + Vector2(4, -4), fp + Vector2(-4, 4), Color(1, 1, 1, 0.5), 1.0)

	# 换位目标：牵引虚线 + 跳动的准星框
	if not game_over and target != null and is_instance_valid(target) and player != null:
		var cd_ready := swap_cd <= 0.0 and shift_energy > 0
		var c := Color.WHITE if cd_ready else Color(1, 1, 1, 0.35)
		var tp: Vector2 = target.position
		draw_dashed_line(player.position, tp, Color(1, 1, 1, 0.22 + 0.3 * danger_amt), 1.0, 3.0)
		var pulse := 1.5 * sin(Time.get_ticks_msec() * 0.015)
		var hx: float = target.half.x + 4.0 + pulse
		var hy: float = target.half.y + 4.0 + pulse
		var l := 3.0
		for kx in [-1.0, 1.0]:
			for ky in [-1.0, 1.0]:
				var corner := tp + Vector2(kx * hx, ky * hy)
				draw_line(corner, corner - Vector2(kx * l, 0), c, 1.0)
				draw_line(corner, corner - Vector2(0, ky * l), c, 1.0)

	# 打击火花：放射状的星形尖刺，白色外刺 + 红色内刺；顿帧时定格在画面上
	for sp in sparks:
		var k: float = sp["t"] / 0.16
		var sc: float = 1.5 if sp["big"] else 1.0
		var spikes := 12 if sp["big"] else 8
		var sp_p: Vector2 = sp["p"]
		var sseed: int = sp["seed"]
		for i in spikes:
			var ang := float(i) * TAU / float(spikes) + float(sseed) * 0.01
			var dir := Vector2.from_angle(ang)
			var side := Vector2(-dir.y, dir.x)
			var ln := (10.0 + float((sseed + i * 37) % 9)) * sc * (0.5 + 0.5 * k)
			var w := 2.0 * sc * k
			draw_colored_polygon(PackedVector2Array([sp_p + side * w, sp_p + dir * ln, sp_p - side * w]), Color(1, 1, 1, k))
			draw_colored_polygon(PackedVector2Array([sp_p + side * w * 0.5, sp_p + dir * ln * 0.55, sp_p - side * w * 0.5]), Color(C_BLOOD.r, C_BLOOD.g, C_BLOOD.b, k))
		draw_circle(sp_p, 4.0 * sc * k, Color(1, 1, 1, k))

	# 残影：原位置留下的空心轮廓，向外扩散并淡出
	for g in ghosts:
		var k: float = g["t"] / 0.35
		var gh: Vector2 = g["half"] * (1.0 + (1.0 - k) * 0.6)
		var gp: Vector2 = g["p"]
		draw_rect(Rect2(gp - gh, gh * 2.0), Color(1, 1, 1, k), false, 1.0)

	# 冲击波
	for r in rings:
		var k: float = 1.0 - r["t"] / 0.3
		k = clampf(k, 0.0, 1.0)
		var rad: float = r["max"] * ease(k, 0.3)
		draw_arc(r["p"], maxf(rad, 1.0), 0.0, TAU, 24, Color(1, 1, 1, 1.0 - k), 2.0 - k)

	# 闪电
	for bo in swap_bolts:
		var alpha: float = bo["t"] / 0.22
		_draw_bolt(bo["a"], bo["b"], alpha, bo["w"])
		_draw_bolt(bo["a"], bo["b"], alpha * 0.5, 1.0)

	# 飘字：杀法名字、+SHIFT、TOO FAR 等（像素字体，NEW! 带红色投影）
	for lb in labels:
		var lt: float = lb["t"]
		var rise := (1.1 - lt) * 10.0
		var lp: Vector2 = lb["p"] - Vector2(0, rise + 4.0)
		var la := clampf(lt * 3.0, 0.0, 1.0)
		var shadow := Color(C_BLOOD.r, C_BLOOD.g, C_BLOOD.b, la) if lb["big"] else Color(0, 0, 0, la)
		PF.draw(self, lp, lb["text"], 1, Color(1, 1, 1, la), 1, shadow)

	# 碎片 / 粒子
	for d in debris:
		var dp: Vector2 = d["p"]
		var dc: Color = d.get("c", Color.WHITE)
		dc.a = clampf(d["t"] * 3.0, 0.0, 1.0)
		var sz: float = float(d.get("s", 2))
		draw_rect(Rect2((dp - Vector2(sz, sz) * 0.5).floor(), Vector2(sz, sz)), dc)
