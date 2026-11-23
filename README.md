# 我即是地狱 / I Am Hell

GitHub Game Off 2026 参赛作品，主题 **SHIFT**。

2D 横版平台动作。你没有任何攻击手段，唯一的能力是和敌人或物品**互换位置**。
主动送死，诱敌出手，在攻击落到身上的前一刻按下 Shift 换位，让敌人替你挨这一下。

## English Quick Start

**I Am Hell** is a single-screen 2D action platformer made for
[GitHub Game Off 2026](https://itch.io/jam/game-off-2026). The theme is **SHIFT**.
You have no direct attack. Your only power is swapping places with enemies and objects.
Make enemies shoot, charge, crush, or blast each other instead.

- Engine: Godot 4.7
- Renderer: GL Compatibility
- Input: keyboard and mouse
- Main scene: `scenes/main.tscn`
- Web export preset: `Web`

Controls: `A/D` move, `W/Space` jump, mouse aim, `Shift/Left Click` swap,
`R` retry.

Run with `godot --path .`, or export the `Web` preset with
`godot --headless --path . --export-release Web exports/web/index.html`.

## AI Use Disclosure

OpenAI Codex was used as a development assistant for documentation and
itch.io copy drafting, code review, bug diagnosis, and applied fixes.
The game concept, core mechanics, enemy design, level design, visual direction,
playtesting, and final creative decisions were created and directed by the developer.

## 操作
| 按键 | 作用 |
|---|---|
| A / D / ←→ | 移动 |
| W / 空格 / ↑ | 跳跃（松开早一点跳得矮） |
| 鼠标 | 选择换位目标（准星框） |
| Shift / 鼠标左键 | 换位 |
| R | 重开本关（死亡后按 Shift / 左键 也能立刻重来） |
| N / B | 调试用：跳到下一关 / 上一关 |
| Tab | 调试用：临时选关面板（发布前在 main.gd 把 DEBUG_LEVEL_SELECT 改成 false） |

## 换位规则
- **能量**：头顶三个小菱形。每次换位花 1 格，每 2.5 秒自动回 1 格。
- **让它们互相残杀才回能量**：敌人被子弹、冲锋、炸弹、重装杀死时，回 1 格。被地刺、深渊、锯片、激光等地形杀死不回。
- **完美换位**：在敌人的攻击或机关（子弹、冲锋、炸弹、锯片、压路机、激光、换位者）打到你前一刻换位，不花能量，额外加分。光是往刺上或深渊里掉，不算完美。
- **视线**：不限距离，但中间隔着墙就换不了（单向平台不挡）。
- **地刺会被尸体堵住**：杀过一次的那几格地刺就废了，变成安全的地面。
- **杀法评级**：每次击杀会飘出杀法名字。本关第一次用某种杀法有奖励，同一招重复用分数减半。过关时按杀法种类评 S / A / B（S 还要至少一次完美换位）。

## 敌人
- **冲锋者（带角方块）**：同一高度时抖动蓄力，沿虚线水平冲刺，撞死路上的任何东西。
- **射手（带枪管方块）**：闪烁瞄准后沿虚线开枪，子弹打中谁算谁。
- **投弹手（圆环）**：在你脚下扔延时炸弹，圈内全灭。从第 3 波开始出现。
- **石翼**：在空中盘旋的无面石像鬼。锁定玩家后像冲锋兽一样沿直线高速冲刺，能穿过单向平台；撞到墙、箱子、重装，或被其他攻击命中时才会石化碎裂。
- **钩链苦修者**：把实体铁钩穿过平台钉进墙或箱子，再沿锁链把自己拽向锚点。玩家离开锁定线后，它会撞死在自己的锚点上；空钩会收回并进入硬直。
- **箱子（X 方块）**：受重力、能踩，挡子弹、挡冲锋，杀不死，可以拿来换位瞬移。
- **地刺**：碰到就死，敌人也一样。换位时连速度一起交换——下落中换位，敌人会带着你的下落速度摔下去。

## 关卡
16 个主线房间，外加 3 个挑战关 `DEAD LIFT`、`THE SCALE` 和最终 Boss 关 `THE THIRD NAIL`。普通关杀光敌人后出口门打开；最终关还要先让 Boss 的三根锁链全部反噬。
关卡在 `scripts/levels.gd` 里，用字符画写成，直接改字符就能改关卡（文件开头有图例）。

| # | 名字 | 教的东西 |
|---|---|---|
| 1 | SHIFT | 子弹打谁都算；往地刺上跳再换位 |
| 2 | BAIT | 引冲锋者冲过地刺 |
| 3 | CROSSFIRE | 让敌人互相挡枪；地上有坑 |
| 4 | BOOM | 爆炸桶连锁、投弹手的炸弹圈 |
| 5 | SAWMILL | 移动锯片 |
| 6 | TURRETS | 炮塔只瞄你——借它的子弹 |
| 7 | FREEFALL | 主动跳进深渊，落下前换位 |
| 8 | I AM HELL | 全部混在一起 |
| 9 | SKYLIGHT | 屋顶开了天窗，下面一整条往上掉的区域。引冲锋者冲进天窗撞墙，它就掉进天空；或者自己跳进去，在飞出屋顶前换位 |
| 10 | UNDERSIDE | 地板有反面：地板下面是倒挂的世界。地板上开着几扇“刺窗”，两边都能透过它换位、开枪，谁掉进去都会死。把敌人换到另一面，或者引它冲过刺窗 |
| 11 | PISTONS | 压路机：卡准砸下的时机 |
| 12 | LASER GRID | 激光：站进光束里引它充能，及时换走 |
| 13 | REFLECTION | 三个倒影各在右边一层，中间隔着墙。它们左右反着照抄你。每层的墙、柱子、倒刺、压路机位置不同：要先把它撞墙“错开”，再走过去或跳起来。左边还有炮塔一直打你、射手要靠换位解决 |
| 14 | IT SHIFTS BACK | 换位者会强行和你换位。它换的那一刻，站到压路机底下、激光里或天窗里 |
| 15 | HEAVY | 重装一直跟着你的横坐标走，不看路。带它走下平台压死别人，或者走进“倒刺口”（往上掉进天花板上的刺） |
| 16 | HELL RISES | 本体最终关：五屏高的塔，岩浆从下往上涨，越涨越快。出口一直开着，不用杀光敌人——活着爬到顶就赢。一路经过：之字形起步、两墙夹住的烟囱、头顶压路机的长廊、把你一口气吸上去的上升气流柱、重装往下追的塔顶。和上面的敌人换位能抄近路；换位者只会在你下面时出手，把你往岩浆里拽 |
| 17 | DEAD LIFT | 新关测试：左右两个重力井充当电梯，两道横贯房间的激光充当楼层闸门。新的吊砣人沿右井坠落，玩家要靠换位改变它的落砣位置 |
| 18 | THE SCALE | 新机制测试：左右升降笼共用一条吊链，玩家、敌人和箱子的重量决定两边升降方向。需要换位重新分配配重，再借中央窗口和上层平台到出口 |
| 19 | THE THIRD NAIL | 最终挑战：六屏高的无头圣骸正墙。左钉是实体骨钉，要把冲锋者引进刑轮；链条拔出骨钉后它会爆炸，并炸死撞轮者。右钉要在巨型摆链低点换位，把自己的动量交给链钩；登顶后让 Boss 的下砸拔掉颈钉。最后三根断链反向收紧，把 Boss 拖进自己的绞环并撞碎红核。全程只有终墙一个射手 |

## 机关
- **锯片**：沿地面来回，切开一切。
- **炮塔**：嵌在墙里，打不死，只瞄准主角，但子弹打中谁算谁。
- **吊砣人**：坐在巨大铁砣上的小刽子手。锁定后连人带砣沿竖井砸下；换位会改变下一次坠落的位置。只有铁砣实际下落并接近主角时才触发子弹时间。
- **爆炸桶**：被任何攻击打中就爆炸，能连锁。
- **深渊**：地面上的缺口，掉下去就没了。
- **重力反转区**（点阵 + 上飘箭头）：在里面会往上掉；天花板上可能有倒刺，顶上没墙就掉进天空。冲锋者冲刺时不看路，会冲进反转区。
- **倒刺口**：地面上的一小段反转区，正上方是倒刺。走进去就往上掉到刺上。
- **压路机**：挂在上方，抖动预警后砸下，压扁下面的一切。
- **激光**：嵌在墙里，闪烁充能后横向烧穿整行。
- **相连升降笼**：左右两个平台共用一套配重，站在上面的身体会改变两边的升降方向。玩家重量为 1，普通敌人为 1，箱子为 2。

## 第二世界的敌人
- **镜子**：不动，盾牌朝一个方向，正面挨子弹会原路弹回。背面和其他攻击能杀死它。可以换位挪位置。
- **换位者**：它也会 SHIFT——蓄力后强行和你换位。
- **重装**：子弹打不动、不能换位、碰到就死；但不看路，会自己走进地刺和深渊。
- **倒影**（白色的你）：没有自己的脑子，左右反着照抄你的动作，跳的高度也一样。碰到不会死。它撞墙会停，你却还能走——靠墙能调整两边的相对位置。

## 画面风格（GBA 质感）
- **真低分辨率**：游戏按 480x270 渲染，再整数倍放大（`project.godot` 里 stretch mode = viewport），所有线条、旋转、缩放都是一格一格的像素。
- **调色板 + 网点抖动**：`main.gd` 的 `PALETTE_SHADER` 把整个画面换成 4 阶灰（带一点紫）+ 3 阶红。半透明和渐变会变成 GBA 式网点。改 `c0~c3`、`r1~r3` 就能换整体色调。
- **红色只表示危险和血**：所有攻击预警线、激光、炸弹圈、主角的恶魔眼睛、刺尖上的血。
- **地形**：`terrain.gd` 画砖块（外露的边有高光和阴影）、钢梁平台、带血的地刺。
- **背景**：`background.gd` 画远近两层石笋剪影（随镜头视差）、摇晃的铁链、岩浆红光、上飘的火星。
- **像素字体**：`pixel_font.gd`，5x7 点阵，用方块直接画，不需要字体文件。
- **主角**：Q 版地狱小鬼——黑色大头、弯角、红色怒眼、獠牙、破斗篷、红围巾、身上冒火星。
- **刺激的特效**：完美换位时冲击帧（全屏只剩黑白红）+ 集中线；子弹时间里 GBA 式扫描线波动 + 暗角；敌人死后血迹留在地上、肉块落地弹跳；连杀越多屏幕底部地狱火越高；开场和过关有圆形转场。
- **场景装饰**：地面上随机出现骷髅、骨头、蜡烛（火苗会晃，周围有红色光晕）。

## 音效
- `assets/sfx/`：**SubspaceAudio（Juhani Junkala）** 的 CC0 音效包 [512 Sound Effects (8-bit style)](https://opengameart.org/content/512-sound-effects-8-bit-style) 里挑选的 18 个音效，用 `tools/import_sfx_pack.py` 导入（改名 + 统一响度）。哪个事件用哪个文件，写在脚本开头的 `PICKS` 里。
- `assets/sfx/swap.wav`、`perfect.wav`、`death.wav`：`tools/make_impact_sfx.py` 从零合成的分层重击音效（瞬态 + 胸腔重击 + 超低音 + 立体声失谐低吼带磁带急停 + 混响 + 压缩），不来自音效包。
- `assets/sfx_synth/`：`tools/make_sfx.py` 从零合成的备用音效（模拟 GBA 发声芯片）。`assets/sfx` 里没有的事件会自动用这里的。
- 改音量：`scripts/sfx.gd` 的 `VOLUME`。
- 规律：所有敌人攻击前都会响同一个上扬的“警告音”，听到就该准备换位了。

## 致谢
- Sound effects: SubspaceAudio (Juhani Junkala) — "The Essential Retro Video Game Sound Effects Collection [512 sounds]", CC0. https://opengameart.org/content/512-sound-effects-8-bit-style

## 引擎
Godot 4.7（Compatibility 渲染器，可导出网页版）。

## 项目结构
- `scenes/main.tscn`：唯一的场景，其余内容全部由代码生成
- `scripts/main.gd`：游戏总管（波次、换位、命中、连杀、顿帧、震屏）
- `scripts/entity.gd`：实体基类
- `scripts/player.gd`、`enemy_*.gd`、`crate.gd`、`bullet.gd`、`blast.gd`、`hud.gd`
