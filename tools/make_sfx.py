# 用法：在项目根目录运行  python tools/make_sfx.py
# 生成 assets/sfx_synth/*.wav（备用音效：assets/sfx 里没有的事件会用这里的）。所有音效都是从零合成的，没有用任何采样或 AI 生成的音频。
#
# 模拟 GBA 的 PSG 发声芯片：
#   - 方波通道：占空比 12.5% / 25% / 50%（GBA 方波就这几档）
#   - 波表通道：32 个采样、每个 4 位的波形
#   - 噪声通道：15 位 / 7 位 LFSR（7 位的听起来更“金属”）
#   - 音量包络：0~15 共 16 级台阶，不是平滑衰减——这是老掌机声音“颗粒感”的来源
#   - 最后整体量化到 8 位、22050Hz
# 想改某个声音，改下面 SOUNDS 里对应函数的参数，重新运行即可。

import math
import os
import random
import struct
import wave

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sfx_synth")


# ------------------------------------------------------------------ 基础发声器

def env_steps(t, length, start=15, end=0):
    """GBA 式音量包络：在 length 秒内从 start 级一格一格降到 end 级（0~15）"""
    if t >= length:
        return end / 15.0
    level = round(start + (end - start) * (t / length))
    return max(0, min(15, level)) / 15.0


def pulse(freq_fn, dur, duty=0.5, vol_fn=None, vibrato=0.0, vib_rate=6.0):
    out = []
    phase = 0.0
    for i in range(int(dur * SR)):
        t = i / SR
        f = freq_fn(t)
        if vibrato:
            f *= 1.0 + vibrato * math.sin(2 * math.pi * vib_rate * t)
        phase = (phase + f / SR) % 1.0
        v = 1.0 if phase < duty else -1.0
        out.append(v * (vol_fn(t) if vol_fn else 1.0))
    return out


def noise(freq_fn, dur, vol_fn=None, short=False, seed=1):
    """LFSR 噪声：freq 越高越“嘶”，越低越“轰”。short=True 用 7 位 LFSR，带音高感"""
    out = []
    lfsr = 0x7FFF if not short else 0x7F
    acc = 0.0
    bit = 1.0
    random.seed(seed)
    for i in range(int(dur * SR)):
        t = i / SR
        acc += freq_fn(t) / SR
        while acc >= 1.0:
            acc -= 1.0
            b = (lfsr ^ (lfsr >> 1)) & 1
            lfsr = (lfsr >> 1) | (b << (6 if short else 14))
            bit = 1.0 if (lfsr & 1) else -1.0
        out.append(bit * (vol_fn(t) if vol_fn else 1.0))
    return out


# 4 位波表：一个带“咬劲”的锯齿 + 方波混合，接近 GBA 波表通道常用的音色
WAVETABLE = [15, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1,
             0, 0, 1, 2, 4, 6, 8, 10, 12, 14, 15, 15, 12, 8, 4, 0]


def wavech(freq_fn, dur, vol_fn=None):
    out = []
    phase = 0.0
    for i in range(int(dur * SR)):
        t = i / SR
        phase = (phase + freq_fn(t) / SR) % 1.0
        s = WAVETABLE[int(phase * 32) % 32] / 7.5 - 1.0
        out.append(s * (vol_fn(t) if vol_fn else 1.0))
    return out


# ------------------------------------------------------------------ 混音工具

def silence(dur):
    return [0.0] * int(dur * SR)


def mix(*tracks, gains=None):
    n = max(len(tr) for tr in tracks)
    gains = gains or [1.0] * len(tracks)
    out = [0.0] * n
    for tr, g in zip(tracks, gains):
        for i, v in enumerate(tr):
            out[i] += v * g
    return out


def seq(*parts):
    out = []
    for p in parts:
        out.extend(p)
    return out


def lowpass(x, k):
    """一阶低通，k 越小越闷（0~1）"""
    out, y = [], 0.0
    for v in x:
        y += k * (v - y)
        out.append(y)
    return out


def echo(x, delay, fb, times=3):
    n = len(x) + int(delay * SR) * times
    out = x + [0.0] * (n - len(x))
    d = int(delay * SR)
    g = fb
    for k in range(1, times + 1):
        for i, v in enumerate(x):
            out[i + d * k] += v * g
        g *= fb
    return out


def slide(f0, f1, dur, curve=1.0):
    return lambda t: f0 + (f1 - f0) * min(1.0, t / dur) ** curve


def const(f):
    return lambda t: f


def note(n):
    """MIDI 音高 -> 频率"""
    return 440.0 * 2 ** ((n - 69) / 12.0)


# ------------------------------------------------------------------ 音效设计

def sfx_swap():
    # 换位：方波快速上扫 + 一声短促的下落回音 + 一缕噪声“咻”
    a = pulse(slide(260, 1300, 0.06, 0.7), 0.07, 0.25, lambda t: env_steps(t, 0.07, 13, 6))
    b = pulse(slide(900, 500, 0.06), 0.06, 0.125, lambda t: env_steps(t, 0.06, 8, 0))
    n = noise(slide(9000, 3000, 0.1), 0.1, lambda t: env_steps(t, 0.1, 6, 0))
    return mix(seq(a, b), n, gains=[0.6, 0.35])


def sfx_perfect():
    # 完美换位：换位声 + 小调琶音（地狱味）+ 回声
    base = sfx_swap()
    arp = []
    for n_ in (69, 72, 76, 81):  # A C E A
        arp += pulse(const(note(n_ + 12)), 0.035, 0.125, lambda t: env_steps(t, 0.035, 12, 7))
    arp += pulse(const(note(93)), 0.12, 0.125, lambda t: env_steps(t, 0.12, 10, 0), vibrato=0.01, vib_rate=12)
    return echo(mix(base, silence(0.05) + arp, gains=[0.8, 0.45]), 0.07, 0.35, 2)


def sfx_fail():
    # 换位失败：低沉的“嗡”，占空比来回抖
    out = []
    for k in range(3):
        out += pulse(const(92), 0.025, 0.5 if k % 2 == 0 else 0.125, lambda t: 0.7)
    return lowpass(out, 0.5)


def sfx_kill():
    # 击杀：噪声爆裂 + 音高急降的方波“咚”
    n = noise(slide(6000, 800, 0.12), 0.14, lambda t: env_steps(t, 0.14, 15, 0))
    p = pulse(slide(420, 55, 0.12, 0.5), 0.13, 0.5, lambda t: env_steps(t, 0.13, 14, 0))
    return mix(n, p, gains=[0.45, 0.55])


def sfx_new_style():
    # 第一次用某种杀法：两声上扬的小提示
    a = pulse(const(note(84)), 0.04, 0.25, lambda t: env_steps(t, 0.04, 10, 6))
    b = pulse(const(note(91)), 0.09, 0.25, lambda t: env_steps(t, 0.09, 10, 0))
    return seq(a, b)


def sfx_death():
    # 主角死亡：长长的下滑 + 颤音 + 最后一下噪声
    p = pulse(slide(700, 45, 0.7, 0.6), 0.75, 0.25, lambda t: env_steps(t, 0.75, 15, 0), vibrato=0.04, vib_rate=9)
    n = noise(const(1200), 0.3, lambda t: env_steps(t, 0.3, 12, 0))
    return mix(p, n, gains=[0.6, 0.4])


def sfx_jump():
    return pulse(slide(240, 480, 0.07), 0.08, 0.5, lambda t: env_steps(t, 0.08, 8, 0))


def sfx_land():
    n = noise(const(1800), 0.05, lambda t: env_steps(t, 0.05, 9, 0))
    return lowpass(n, 0.25)


def sfx_shoot():
    # 敌人开枪：细占空比的“啾”
    return pulse(slide(1500, 280, 0.09, 0.6), 0.1, 0.125, lambda t: env_steps(t, 0.1, 11, 0))


def sfx_windup():
    # 攻击前摇：短促上扬的警告音（所有敌人蓄力都用它，玩家一听就知道要来了）
    return pulse(slide(300, 620, 0.12), 0.13, 0.25, lambda t: env_steps(t, 0.13, 7, 3), vibrato=0.05, vib_rate=30)


def sfx_dash():
    n = noise(slide(2500, 9000, 0.18), 0.2, lambda t: env_steps(t, 0.2, 10, 0))
    return lowpass(n, 0.6)


def sfx_explode():
    # 爆炸：低频噪声 + 越来越闷 + 8 位碎裂感
    n = noise(slide(3000, 200, 0.5, 0.5), 0.55, lambda t: env_steps(t, 0.55, 15, 0))
    thump = pulse(slide(120, 35, 0.2), 0.22, 0.5, lambda t: env_steps(t, 0.22, 15, 0))
    return mix(lowpass(n, 0.45), thump, gains=[0.7, 0.5])


def sfx_laser_charge():
    return wavech(slide(110, 440, 0.7, 1.5), 0.75, lambda t: env_steps(t, 0.75, 4, 10))


def sfx_laser_fire():
    w = wavech(const(98), 0.45, lambda t: env_steps(t, 0.45, 15, 2))
    n = noise(const(5000), 0.45, lambda t: env_steps(t, 0.45, 6, 0), short=True)
    return mix(w, n, gains=[0.7, 0.3])


def sfx_slam():
    n = noise(const(900), 0.18, lambda t: env_steps(t, 0.18, 15, 0))
    p = pulse(slide(90, 40, 0.15), 0.2, 0.5, lambda t: env_steps(t, 0.2, 15, 0))
    return mix(lowpass(n, 0.3), p, gains=[0.6, 0.6])


def sfx_reflect():
    # 镜子弹回子弹：两个略微失谐的高音方波，金属“叮”
    a = pulse(const(1760), 0.18, 0.125, lambda t: env_steps(t, 0.18, 12, 0))
    b = pulse(const(1790), 0.18, 0.25, lambda t: env_steps(t, 0.18, 9, 0))
    return mix(a, b, gains=[0.4, 0.35])


def sfx_enemy_swap():
    # 换位者把你换走：换位声倒过来，往下沉
    a = pulse(slide(1300, 200, 0.12, 0.6), 0.13, 0.25, lambda t: env_steps(t, 0.13, 12, 0), vibrato=0.03, vib_rate=20)
    n = noise(slide(3000, 9000, 0.1), 0.1, lambda t: env_steps(t, 0.1, 6, 0))
    return mix(a, n, gains=[0.6, 0.3])


def sfx_door():
    # 出口打开：小调上行琶音
    out = []
    for n_ in (57, 60, 64, 69):
        out += pulse(const(note(n_ + 12)), 0.06, 0.5, lambda t: env_steps(t, 0.06, 11, 6))
    out += pulse(const(note(81)), 0.2, 0.5, lambda t: env_steps(t, 0.2, 10, 0))
    return echo(out, 0.09, 0.3, 2)


def sfx_clear():
    # 过关：两声部的短乐句（方波旋律 + 波表低音）
    mel = [(69, 0.09), (72, 0.09), (76, 0.09), (81, 0.18), (79, 0.09), (81, 0.3)]
    bass = [(45, 0.27), (52, 0.27), (45, 0.3)]
    lead = []
    for n_, d in mel:
        lead += pulse(const(note(n_)), d, 0.25, lambda t, d=d: env_steps(t, d, 12, 5))
    low = []
    for n_, d in bass:
        low += wavech(const(note(n_)), d, lambda t, d=d: env_steps(t, d, 12, 6))
    return mix(lead, low, gains=[0.5, 0.45])


def sfx_tick():
    # 能量回复一格
    return pulse(const(note(88)), 0.03, 0.125, lambda t: env_steps(t, 0.03, 6, 0))


def sfx_slowmo():
    # 进入子弹时间：低沉的“嗡——”往下坠
    return wavech(slide(180, 70, 0.3), 0.32, lambda t: env_steps(t, 0.32, 9, 0))


SOUNDS = {
    "swap": sfx_swap, "perfect": sfx_perfect, "fail": sfx_fail,
    "kill": sfx_kill, "new_style": sfx_new_style, "death": sfx_death,
    "jump": sfx_jump, "land": sfx_land, "shoot": sfx_shoot,
    "windup": sfx_windup, "dash": sfx_dash, "explode": sfx_explode,
    "laser_charge": sfx_laser_charge, "laser_fire": sfx_laser_fire, "slam": sfx_slam,
    "reflect": sfx_reflect, "enemy_swap": sfx_enemy_swap, "door": sfx_door,
    "clear": sfx_clear, "tick": sfx_tick, "slowmo": sfx_slowmo,
}


def dc_block(x, r=0.995):
    """去掉直流偏移（窄占空比方波会让波形整体偏向一边，开头结尾会“啪”一声）"""
    out, px, py = [], 0.0, 0.0
    for v in x:
        py = v - px + r * py
        px = v
        out.append(py)
    return out


def write_wav(path, samples, peak=0.85):
    samples = dc_block(samples)
    m = max(1e-6, max(abs(v) for v in samples))
    scale = peak / m
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(1)          # 8 位
        w.setframerate(SR)
        data = bytearray()
        for v in samples:
            q = int(round(v * scale * 127)) + 128
            data.append(max(0, min(255, q)))
        w.writeframes(bytes(data))


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, fn in SOUNDS.items():
        s = fn()
        # 开头 2 毫秒淡入、结尾 4 毫秒淡出，避免“啪”的爆音
        fin = int(0.002 * SR)
        for i in range(min(fin, len(s))):
            s[i] *= i / fin
        fade = int(0.004 * SR)
        for i in range(min(fade, len(s))):
            s[-1 - i] *= i / fade
        write_wav(os.path.join(OUT, name + ".wav"), s)
        print(f"{name:14s} {len(s) / SR:.2f}s")


if __name__ == "__main__":
    main()
