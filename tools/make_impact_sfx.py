# 用法：在项目根目录运行  python tools/make_impact_sfx.py
# 生成换位音效 assets/sfx/swap.wav 和完美换位 assets/sfx/perfect.wav（44100Hz 立体声）。
# 全部从零合成，没有使用采样或 AI 生成的音频。
#
# 分层设计：
#   瞬态（高频“咔” + 3kHz“啪”）→ 胸腔重击（600→150Hz）→ 超低音下潜（带失真泛音）
#   → 立体声失谐低吼（共振峰滤波，尾巴像磁带急停一样往下坠）→ 左右不同的短混响
#   → 去低频总线 + 重压缩 + 饱和（让冲击感落在小喇叭也听得到的中频，并且够“实”）
# 主角死亡 assets/sfx/death.wav：同一套引擎，但切掉 3kHz 以上的高频、压得更轻，沉闷不刺耳。
#   DEATH_STYLE 选 1 / 2 / 3：1 沉闷倒地，2 心跳停止，3 闷碎下坠。
# 想调手感：改 swap_sound() / perfect_sound() / d1_fall() 等函数里的参数，重新运行。

import math
import os
import random
import struct
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sfx")


def n_samples(d): return int(d * SR)


def zeros(d): return [0.0] * n_samples(d)


def env_exp(t, decay):           # 指数衰减，decay = 衰减到 1/e 的时间
    return math.exp(-t / decay)


def osc_sine(f_fn, dur, amp_fn):
    out, ph = [], 0.0
    for i in range(n_samples(dur)):
        t = i / SR
        ph += 2 * math.pi * f_fn(t) / SR
        out.append(math.sin(ph) * amp_fn(t))
    return out


def osc_saw(f_fn, dur, amp_fn, detune=0.0):
    out, p1, p2 = [], 0.0, 0.3
    for i in range(n_samples(dur)):
        t = i / SR
        f = f_fn(t)
        p1 = (p1 + f / SR) % 1.0
        p2 = (p2 + f * (1 + detune) / SR) % 1.0
        out.append(((2 * p1 - 1) + (2 * p2 - 1)) * 0.5 * amp_fn(t))
    return out


def white(dur, amp_fn):
    return [random.uniform(-1, 1) * amp_fn(i / SR) for i in range(n_samples(dur))]


def biquad(x, kind, f_fn, q=0.707):
    out = []
    x1 = x2 = y1 = y2 = 0.0
    for i, v in enumerate(x):
        f = max(20.0, min(SR * 0.45, f_fn(i / SR)))
        w0 = 2 * math.pi * f / SR
        cw, sw = math.cos(w0), math.sin(w0)
        al = sw / (2 * q)
        if kind == "lp":
            b0, b1, b2 = (1 - cw) / 2, 1 - cw, (1 - cw) / 2
        elif kind == "hp":
            b0, b1, b2 = (1 + cw) / 2, -(1 + cw), (1 + cw) / 2
        else:  # bp
            b0, b1, b2 = al, 0.0, -al
        a0, a1, a2 = 1 + al, -2 * cw, 1 - al
        y = (b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0
        x2, x1, y2, y1 = x1, v, y1, y
        out.append(y)
    return out


def drive(x, k):                  # tanh 失真
    return [math.tanh(v * k) / math.tanh(k) for v in x]


def mix(*tr, gains=None):
    n = max(len(t) for t in tr); g = gains or [1.0] * len(tr)
    out = [0.0] * n
    for t, gg in zip(tr, g):
        for i, v in enumerate(t): out[i] += v * gg
    return out


def delay(x, d):
    return [0.0] * n_samples(d) + x


def reverb(x, wet=0.25, size=1.0, tail=0.35):
    # 简化的 Schroeder 混响：4 个梳状 + 2 个全通
    n = len(x) + n_samples(tail)
    src = x + [0.0] * (n - len(x))
    combs = [int(SR * d * size) for d in (0.0297, 0.0371, 0.0411, 0.0437)]
    acc = [0.0] * n
    for d in combs:
        buf = [0.0] * n
        for i in range(n):
            buf[i] = src[i] + (buf[i - d] * 0.72 if i >= d else 0.0)
            acc[i] += buf[i] * 0.25
    for d, g in ((int(SR * 0.005), 0.7), (int(SR * 0.0017), 0.7)):
        out = [0.0] * n
        for i in range(n):
            xd = acc[i - d] if i >= d else 0.0
            yd = out[i - d] if i >= d else 0.0
            out[i] = -g * acc[i] + xd + g * yd
        acc = out
    return [src[i] * (1 - wet) + acc[i] * wet for i in range(n)]


def crack(dur=0.03, bright=6000):
    n = white(dur, lambda t: env_exp(t, 0.006))
    return biquad(n, "hp", lambda t: bright)


def sub_drop(f0=150, f1=40, dur=0.35, decay=0.12):
    return osc_sine(lambda t: f1 + (f0 - f1) * math.exp(-t / 0.05), dur, lambda t: env_exp(t, decay))


def punch(f0=480, f1=140, decay=0.045, k=4.0):
    """200~500Hz 的胸腔冲击：小喇叭也听得见的“咚”"""
    body = osc_sine(lambda t: f1 + (f0 - f1) * math.exp(-t / 0.02), 0.2, lambda t: env_exp(t, decay))
    return drive(body, k)


def sub_heavy(f0=150, f1=40, dur=0.3, decay=0.07):
    """超低音 + 失真泛音（2、3 次谐波落在 100~400Hz，笔记本喇叭也能听到）"""
    return drive(sub_drop(f0, f1, dur, min(decay, 0.07)), 2.6)


def whoosh(dur, f0, f1, q=1.2, decay=None, rise=False):
    def amp(t):
        if rise: return (t / dur) ** 2
        return env_exp(t, decay or dur / 3)
    n = white(dur, amp)
    return biquad(n, "bp", lambda t: f0 * (f1 / f0) ** (t / dur), q)


def click(freq=3200, decay=0.004):
    return osc_sine(lambda t: freq, 0.02, lambda t: env_exp(t, decay))


def roar(dur=0.42, base=72.0, detune=0.013, dive=0.5, seed_off=0.0):
    # 失谐锯齿低吼：开头音高猛冲，尾巴像磁带急停一样往下坠
    def f(t):
        tape = 1.0 - dive * min(1.0, t / dur) ** 1.6
        return base * (1 + 0.45 * math.exp(-t / 0.035)) * tape
    g = osc_saw(f, dur, lambda t: min(1.0, t / 0.004) * env_exp(t, 0.16), detune=detune)
    f1 = biquad(g, "bp", lambda t: 700 - 380 * t / dur, 2.4)
    f2 = biquad(g, "bp", lambda t: 1150 - 500 * t / dur, 3.0)
    f3 = biquad(g, "bp", lambda t: 2500, 5.0)
    return drive(mix(f1, f2, f3, gains=[1.0, 0.75, 0.3]), 7.0)


def compress(x, thr_db=-16.0, ratio=4.0, att=0.001, rel=0.06):
    thr = 10 ** (thr_db / 20)
    a_att, a_rel = math.exp(-1 / (att * SR)), math.exp(-1 / (rel * SR))
    env, out = 0.0, []
    for v in x:
        lv = abs(v)
        env = a_att * env + (1 - a_att) * lv if lv > env else a_rel * env + (1 - a_rel) * lv
        gain = 1.0
        if env > thr:
            gain = (thr * (env / thr) ** (1 / ratio)) / env
        out.append(v * gain)
    return out


def master(L, R, peak=0.98):
    n = max(len(L), len(R)); L = L + [0.0] * (n - len(L)); R = R + [0.0] * (n - len(R))
    out = []
    for ch in (L, R):
        hp = biquad(ch, "hp", lambda t: 85.0)
        out.append([h + 0.38 * v for h, v in zip(hp, ch)])
    # 先把音量对齐到峰值 1，再狠压：尖峰被压住，身体部分被顶上来
    m = max(max(abs(v) for v in out[0]), max(abs(v) for v in out[1])) or 1e-9
    out = [[v / m for v in ch] for ch in out]
    out = [compress(ch, -26.0, 6.0, att=0.0005, rel=0.05) for ch in out]
    m = max(max(abs(v) for v in out[0]), max(abs(v) for v in out[1])) or 1e-9
    out = [[math.tanh(3.6 * v / m) for v in ch] for ch in out]
    # 先做首尾淡入淡出，再归一化（否则开头的尖峰被淡入削掉，整体音量会被算低）
    for ch in out:
        for i in range(min(30, n)): ch[i] *= i / 30
        f = n_samples(0.012)
        for i in range(min(f, n)): ch[-1 - i] *= i / f
    m = max(max(abs(v) for v in out[0]), max(abs(v) for v in out[1]))
    out = [[v / m * peak for v in ch] for ch in out]
    last = n - 1
    while last > 0 and max(abs(out[0][last]), abs(out[1][last])) < 0.004: last -= 1
    return out[0][:last + 1], out[1][:last + 1]


def core():
    """共用的冲击核心（两个声道一样）：双层瞬态 + 胸腔重击 + 超低音"""
    return mix(crack(0.03, 5500), click(3200), punch(620, 150, 0.05, 5.0), sub_heavy(140, 38, 0.3, 0.07),
               gains=[0.9, 0.55, 0.95, 0.5])


def wide_roar(dive=0.5):
    """左右各一条略微跑调的低吼 = 立体声宽度"""
    l = roar(base=72.0, detune=0.013, dive=dive)
    r = roar(base=73.2, detune=-0.011, dive=dive)
    return l, r



def reverb_mono(x, size, wet, tail):
    return reverb(x, wet=wet, size=size, tail=tail)


def stereo_verb(L, R, wet=0.24, tail=0.4):
    return reverb_mono(L, 1.25, wet, tail), reverb_mono(R, 1.38, wet, tail)


def swap_sound():
    """普通换位：冲击核心 + 立体声低吼（磁带急停）"""
    random.seed(13)
    c = core()
    l, r = wide_roar()
    L, R = stereo_verb(mix(c, l, gains=[1.0, 0.85]), mix(c, r, gains=[1.0, 0.85]))
    return master(L, R)


def perfect_sound():
    """完美换位：更深的低音 + 第二下回响重击 + 更长更狠的磁带急停 + 金属钟鸣"""
    random.seed(21)
    c = mix(crack(0.03, 5500), click(3200), punch(680, 140, 0.06, 6.0), sub_heavy(170, 32, 0.32, 0.07),
            gains=[0.95, 0.6, 1.0, 0.6])
    echo_hit = delay(mix(crack(0.02, 4500), punch(520, 120, 0.05, 5.0), gains=[0.5, 0.7]), 0.085)
    l = roar(dur=0.55, base=66.0, detune=0.014, dive=0.65)
    r = roar(dur=0.55, base=67.3, detune=-0.012, dive=0.65)
    bell = [0.0] * n_samples(0.7)
    for ratio, a, dec in ((1.0, 1.0, 0.25), (2.0, 0.4, 0.18), (2.76, 0.35, 0.12), (5.4, 0.15, 0.06)):
        bell = mix(bell, osc_sine(lambda t, rr=ratio: 660 * rr, 0.7, lambda t, d=dec: env_exp(t, d)), gains=[1.0, a])
    bell = delay(bell, 0.03)
    L, R = stereo_verb(mix(c, echo_hit, l, bell, gains=[1.0, 0.8, 0.85, 0.3]),
                       mix(c, delay(echo_hit, 0.01), r, delay(bell, 0.008), gains=[1.0, 0.8, 0.85, 0.3]),
                       wet=0.3, tail=0.55)
    return master(L, R)


# ------------------------------------------------------------------ 主角死亡

DEATH_STYLE = 1

def lowpass_all(L, R, f):
    return biquad(L, "lp", lambda t: f, 0.7), biquad(R, "lp", lambda t: f, 0.7)

def gentle_master(L, R, peak=0.85):
    # 和换位共用的母带处理，但压得轻一些、峰值低一些，不刺耳
    n = max(len(L), len(R)); L = L + [0.0] * (n - len(L)); R = R + [0.0] * (n - len(R))
    out = []
    for ch in (L, R):
        hp = biquad(ch, "hp", lambda t: 60.0)
        out.append([h + 0.5 * v for h, v in zip(hp, ch)])
    mx = max(max(abs(v) for v in out[0]), max(abs(v) for v in out[1])) or 1e-9
    out = [[v / mx for v in ch] for ch in out]
    out = [compress(ch, -20.0, 3.0, att=0.002, rel=0.08) for ch in out]
    mx = max(max(abs(v) for v in out[0]), max(abs(v) for v in out[1])) or 1e-9
    out = [[math.tanh(1.6 * v / mx) for v in ch] for ch in out]
    for ch in out:
        for i in range(min(60, n)): ch[i] *= i / 60
        f = n_samples(0.03)
        for i in range(min(f, n)): ch[-1 - i] *= i / f
    mx = max(max(abs(v) for v in out[0]), max(abs(v) for v in out[1]))
    out = [[v / mx * peak for v in ch] for ch in out]
    last = n - 1
    while last > 0 and max(abs(out[0][last]), abs(out[1][last])) < 0.003: last -= 1
    return out[0][:last + 1], out[1][:last + 1]

def thud(f0=260, f1=45, decay=0.09):
    # 闷响：没有高频脆响，只有胸腔 + 超低音
    return mix(punch(f0, 90, 0.06, 2.5), sub_heavy(140, f1, 0.4, decay), gains=[0.8, 0.8])

def d1_fall():
    random.seed(31)
    t = thud()
    l = roar(dur=0.7, base=60.0, detune=0.012, dive=0.75)
    r = roar(dur=0.7, base=61.0, detune=-0.010, dive=0.75)
    L, R = stereo_verb(mix(t, l, gains=[1.0, 0.55]), mix(t, r, gains=[1.0, 0.55]), wet=0.32, tail=0.6)
    L, R = lowpass_all(L, R, 1800)
    return gentle_master(L, R)

def d2_heartbeat():
    random.seed(32)
    t = thud(240, 40, 0.1)
    beats = [0.0] * n_samples(1.3)
    for at, g in ((0.32, 0.75), (0.47, 0.55), (0.85, 0.4), (1.0, 0.28)):
        b = delay(mix(punch(110, 50, 0.05, 1.8), sub_drop(70, 40, 0.15, 0.05), gains=[0.7, 0.8]), at)
        beats = mix(beats, b, gains=[1.0, g])
    L, R = stereo_verb(mix(t, beats, gains=[1.0, 0.9]), mix(t, delay(beats, 0.006), gains=[1.0, 0.9]), wet=0.35, tail=0.7)
    L, R = lowpass_all(L, R, 1400)
    return gentle_master(L, R)

def d3_shatter_fall():
    random.seed(33)
    t = thud(300, 50, 0.07)
    # 被捂住的碎裂：一串很短的噪声颗粒，越来越稀
    grains = [0.0] * n_samples(0.4)
    for k in range(18):
        at = 0.005 + (k ** 1.6) * 0.004
        g = delay(biquad(white(0.02, lambda tt: env_exp(tt, 0.004)), "bp", lambda tt: 1800 - k * 60, 2.0), at)
        grains = mix(grains, g, gains=[1.0, 0.9 * (1 - k / 20)])
    fall = whoosh(0.6, 1600, 180, q=1.3, decay=0.25)
    L, R = stereo_verb(mix(t, grains, fall, gains=[1.0, 0.6, 0.7]), mix(t, delay(grains, 0.009), fall, gains=[1.0, 0.6, 0.7]), wet=0.3, tail=0.5)
    L, R = lowpass_all(L, R, 2600)
    return gentle_master(L, R)


def death_sound():
    return {1: d1_fall, 2: d2_heartbeat, 3: d3_shatter_fall}[DEATH_STYLE]()


def save(path, L, R):
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<hh", int(a * 32767), int(b * 32767)) for a, b in zip(L, R)))


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, fn in (("swap", swap_sound), ("perfect", perfect_sound), ("death", death_sound)):
        L, R = fn()
        save(os.path.join(OUT, name + ".wav"), L, R)
        print(f"{name:8s} {len(L) / SR:.2f}s")


if __name__ == "__main__":
    main()
