# 用法：在项目根目录运行
#   python tools/import_sfx_pack.py "<512 音效包解压后的文件夹>"
#
# 把 Juhani Junkala（SubspaceAudio）的 CC0 音效包
# 《The Essential Retro Video Game Sound Effects Collection [512 sounds]》
# 里挑中的音效复制到 assets/sfx/，文件名改成游戏里的事件名，并统一响度。
# 来源：https://opengameart.org/content/512-sound-effects-8-bit-style （CC0）
#
# 想换某个声音：改下面 PICKS 里对应的文件名，重新运行。
# 某个事件不想用音效包：把它从 PICKS 里删掉，游戏会自动改用 assets/sfx_synth/ 里合成的版本。

import math
import os
import struct
import sys
import wave

PICKS = {
    # 事件名           音效包里的文件（相对路径）
    # swap / perfect 不从音效包里取：由 tools/make_impact_sfx.py 合成（分层重击 + 立体声低吼）
    "fail":         "General Sounds/Negative Sounds/sfx_sounds_error7.wav",      # 低沉的错误“嗡”
    "kill":         "Explosions/Shortest/sfx_exp_shortest_hard2.wav",            # 短促、亮转暗的碎裂
    "new_style":    "General Sounds/Coins/sfx_coin_single4.wav",                 # 清脆的“叮”
    # death 不从音效包里取：原来的怪物惨叫太刺耳，改由 tools/make_impact_sfx.py 合成
    "jump":         "Movement/Jumping and Landing/sfx_movement_jump1.wav",
    "land":         "Movement/Jumping and Landing/sfx_movement_jump19_landing.wav",
    "shoot":        "Weapons/Lasers/sfx_wpn_laser2.wav",                         # 短“啾”
    "windup":       "General Sounds/Alarms/Low health Alarms/sfx_lowhealth_alarmloop5.wav",  # 上扬的警告音
    "dash":         "Weapons/Melee/sfx_wpn_sword1.wav",                          # 破风声
    "explode":      "Explosions/Short/sfx_exp_short_hard1.wav",
    "laser_charge": "Weapons/Lasers/sfx_wpn_laser 10.wav",                       # 往上爬的充能
    "laser_fire":   "Weapons/Lasers/sfx_wpn_laser3.wav",
    "slam":         "Weapons/Cannon/sfx_wpn_cannon4.wav",                        # 低沉的重击
    "reflect":      "General Sounds/Impacts/sfx_sounds_impact10.wav",
    "enemy_swap":   "General Sounds/High Pitched Sounds/sfx_sounds_high5.wav",   # 往下掉的音
    "door":         "General Sounds/Positive Sounds/sfx_sounds_powerup5.wav",
    "clear":        "General Sounds/Fanfares/sfx_sounds_fanfare1.wav",
    "tick":         "General Sounds/Simple Bleeps/sfx_sounds_Blip8.wav",
    "slowmo":       "Movement/Falling Sounds/sfx_sounds_falling1.wav",           # 往下坠的“嗡——”
}

TARGET_RMS = 0.22    # 统一响度（原包里音量差得比较多）
MAX_PEAK = 0.95
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sfx")


def read_wav(path):
    with wave.open(path, "rb") as w:
        ch, sw, sr, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
        raw = w.readframes(n)
    if sw != 2:
        raise ValueError(f"{path}: 只支持 16 位 wav")
    v = struct.unpack("<%dh" % (len(raw) // 2), raw)
    if ch == 2:
        v = [(v[i] + v[i + 1]) // 2 for i in range(0, len(v), 2)]
    return [x / 32768.0 for x in v], sr


def trim_tail(a, rel=0.01):
    """去掉结尾的静音，让音效更紧凑"""
    peak = max((abs(x) for x in a), default=0.0) or 1e-9
    last = len(a) - 1
    while last > 0 and abs(a[last]) < peak * rel:
        last -= 1
    return a[: last + 1 + 200]


def write_wav(path, a, sr):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(b"".join(struct.pack("<h", max(-32767, min(32767, int(x * 32767)))) for x in a))


def main():
    if len(sys.argv) < 2:
        print(__doc__ or "需要音效包文件夹路径")
        sys.exit(1)
    pack = sys.argv[1]
    os.makedirs(OUT, exist_ok=True)
    for name, rel in PICKS.items():
        src = os.path.join(pack, *rel.split("/"))
        a, sr = read_wav(src)
        a = trim_tail(a)
        rms = math.sqrt(sum(x * x for x in a) / max(1, len(a)))
        peak = max(abs(x) for x in a) or 1e-9
        gain = min(TARGET_RMS / max(rms, 1e-6), MAX_PEAK / peak)
        a = [x * gain for x in a]
        # 结尾 5 毫秒淡出
        fade = int(0.005 * sr)
        for i in range(min(fade, len(a))):
            a[-1 - i] *= i / fade
        write_wav(os.path.join(OUT, name + ".wav"), a, sr)
        print(f"{name:14s} <- {rel}  ({len(a) / sr:.2f}s, gain {gain:.2f})")


if __name__ == "__main__":
    main()
