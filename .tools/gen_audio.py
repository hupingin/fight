"""Procedurally generate all sound effects + a looping ambient BGM for the game.

Output: assets/audio/*.wav (mono, 44100 Hz, 16-bit PCM)
"""
import math
import os
import random
import struct
import wave

SR = 44100
OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "audio")

random.seed(20261112)


def write_wav(name, samples):
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, name)
    peak = max(1e-6, max(abs(s) for s in samples))
    norm = 0.92 / peak if peak > 0.92 else 1.0
    data = bytearray()
    for s in samples:
        v = int(max(-1.0, min(1.0, s * norm)) * 32767)
        data += struct.pack("<h", v)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(bytes(data))
    print("wrote", name, len(samples) / SR, "s")


def n_of(sec):
    return int(SR * sec)


def env(t, attack=0.002, decay=8.0):
    a = min(1.0, t / attack) if attack > 0 else 1.0
    return a * math.exp(-t * decay)


def lowpass(samples, cutoff):
    rc = 1.0 / (2 * math.pi * cutoff)
    dt = 1.0 / SR
    alpha = dt / (rc + dt)
    out = []
    prev = 0.0
    for s in samples:
        prev = prev + alpha * (s - prev)
        out.append(prev)
    return out


def highpass(samples, cutoff):
    lp = lowpass(samples, cutoff)
    return [s - l for s, l in zip(samples, lp)]


def square(t, f, duty=0.5):
    return 1.0 if (t * f) % 1.0 < duty else -1.0


def saw(t, f):
    return 2.0 * ((t * f) % 1.0) - 1.0


def sine(t, f):
    return math.sin(2 * math.pi * f * t)


def noise():
    return random.uniform(-1, 1)


# ---------------------------------------------------------------- shoot
def gen_shoot():
    dur = 0.11
    out = []
    for i in range(n_of(dur)):
        t = i / SR
        f = 1350 * math.exp(-t * 16) + 320
        v = 0.55 * math.sin(2 * math.pi * f * t) + 0.30 * square(t, f * 0.5, 0.35)
        v += 0.25 * noise() * math.exp(-t * 90)
        out.append(v * env(t, 0.001, 34))
    return lowpass(out, 6500)


# ---------------------------------------------------------------- enemy shot
def gen_enemy_shot():
    dur = 0.20
    out = []
    for i in range(n_of(dur)):
        t = i / SR
        f = 760 * math.exp(-t * 7) + 150
        v = 0.5 * saw(t, f) + 0.3 * sine(t, f * 0.5)
        out.append(v * env(t, 0.004, 13))
    return lowpass(out, 3200)


def gen_laser():
    dur = 0.34
    out = []
    for i in range(n_of(dur)):
        t = i / SR
        f = 1400 * math.exp(-t * 3.2) + 220
        v = 0.42 * math.sin(2 * math.pi * f * t) + 0.22 * noise() * 0.5
        v *= 0.7 + 0.3 * math.sin(2 * math.pi * 34 * t)
        out.append(v * env(t, 0.01, 6.5))
    return lowpass(out, 4200)


# ---------------------------------------------------------------- hit
def gen_hit():
    dur = 0.075
    out = []
    for i in range(n_of(dur)):
        t = i / SR
        v = 0.8 * noise() + 0.35 * sine(t, 2200 * math.exp(-t * 30))
        out.append(v * env(t, 0.001, 55))
    return highpass(lowpass(out, 7000), 700)


# ---------------------------------------------------------------- explosion
def gen_explode():
    dur = 0.75
    out = []
    for i in range(n_of(dur)):
        t = i / SR
        env_v = env(t, 0.004, 7.0)
        rumble = sine(t, 95 * math.exp(-t * 2.2) + 34) * 0.55
        burst = noise() * 0.65 * math.exp(-t * 9)
        crack = noise() * 0.25 * math.exp(-t * 45)
        out.append((rumble + burst + crack) * env_v)
    out = lowpass(out, 2600)
    return out


def gen_big_explode():
    dur = 1.4
    out = []
    for i in range(n_of(dur)):
        t = i / SR
        env_v = env(t, 0.01, 3.2)
        rumble = sine(t, 70 * math.exp(-t * 1.4) + 26) * 0.7
        burst = noise() * 0.55 * math.exp(-t * 4)
        out.append((rumble + burst) * env_v)
    return lowpass(out, 1800)


# ---------------------------------------------------------------- player hurt
def gen_hurt():
    dur = 0.42
    out = []
    for i in range(n_of(dur)):
        t = i / SR
        f = 380 * math.exp(-t * 4.5) + 70
        v = 0.45 * saw(t, f) + 0.3 * noise() * math.exp(-t * 8)
        out.append(v * env(t, 0.003, 6.5))
    return lowpass(out, 3000)


# ---------------------------------------------------------------- warning
def gen_warn():
    dur = 0.55
    out = []
    for i in range(n_of(dur)):
        t = i / SR
        gate = 1.0 if (int(t * 14) % 2 == 0) else 0.15
        v = 0.35 * square(t, 880, 0.5) + 0.18 * sine(t, 440)
        out.append(v * gate * env(t, 0.01, 2.4))
    return lowpass(out, 2600)


# ---------------------------------------------------------------- ui click
def gen_click():
    dur = 0.06
    out = []
    for i in range(n_of(dur)):
        t = i / SR
        v = 0.5 * sine(t, 1500) + 0.2 * noise()
        out.append(v * env(t, 0.001, 80))
    return highpass(out, 500)


# ---------------------------------------------------------------- level clear
def gen_clear():
    dur = 1.5
    notes = [523.25, 659.25, 783.99, 1046.5]
    out = []
    for i in range(n_of(dur)):
        t = i / SR
        v = 0.0
        for k, f in enumerate(notes):
            start = k * 0.13
            if t >= start:
                lt = t - start
                v += 0.3 * (sine(lt, f) + 0.5 * sine(lt, f * 2)) * math.exp(-lt * 3.2)
        out.append(v * min(1.0, t / 0.02))
    return lowpass(out, 7000)


def gen_gameover():
    dur = 1.8
    notes = [440.0, 349.23, 261.63, 196.0]
    out = []
    for i in range(n_of(dur)):
        t = i / SR
        v = 0.0
        for k, f in enumerate(notes):
            start = k * 0.28
            if t >= start:
                lt = t - start
                v += 0.34 * saw(lt, f) * math.exp(-lt * 2.0)
        out.append(v * min(1.0, t / 0.03))
    return lowpass(out, 2400)


# ---------------------------------------------------------------- bgm
def gen_bgm():
    dur = 16.0
    total = n_of(dur)
    base = 0.0625  # 1/16 Hz grid so every component loops seamlessly
    pad_freqs = [110.0, 130.8125, 164.8125, 220.0]
    pad_amps = [0.30, 0.22, 0.18, 0.12]
    out = []
    for i in range(total):
        t = i / SR
        v = 0.0
        # slow evolving pad with detune shimmer
        for f, a in zip(pad_freqs, pad_amps):
            lfo = 0.65 + 0.35 * math.sin(2 * math.pi * 0.0625 * 4 * t + f)
            v += a * lfo * (sine(t, f) + 0.45 * sine(t, f + 0.25) + 0.35 * sine(t, f - 0.25))
        # deep drone
        v += 0.16 * sine(t, 55.0) * (0.7 + 0.3 * math.sin(2 * math.pi * 0.125 * t))
        # airy shimmer, 3 tones slowly fading in and out
        for k, f in enumerate([880.0, 1108.75, 1318.75]):
            lfo = 0.5 + 0.5 * math.sin(2 * math.pi * 0.0625 * (k + 1) * t + k)
            v += 0.02 * lfo * sine(t, f)
        # heartbeat pulse every 2 s
        phase = t % 2.0
        if phase < 0.5:
            v += 0.42 * sine(phase, 58.0) * math.exp(-phase * 9.0)
        out.append(v * 0.55)
    out = lowpass(out, 3000)
    # gentle edge crossfade (overlaps the loop boundary cleanly)
    fade = n_of(0.02)
    for i in range(fade):
        g = i / fade
        out[i] *= g
        out[total - 1 - i] *= g
    return out


def shimmer_last(x):
    return min(1.0, x)


if __name__ == "__main__":
    write_wav("shoot.wav", gen_shoot())
    write_wav("enemy_shoot.wav", gen_enemy_shot())
    write_wav("laser.wav", gen_laser())
    write_wav("hit.wav", gen_hit())
    write_wav("explode.wav", gen_explode())
    write_wav("big_explode.wav", gen_big_explode())
    write_wav("hurt.wav", gen_hurt())
    write_wav("warn.wav", gen_warn())
    write_wav("click.wav", gen_click())
    write_wav("clear.wav", gen_clear())
    write_wav("gameover.wav", gen_gameover())
    write_wav("bgm_loop.wav", gen_bgm())
