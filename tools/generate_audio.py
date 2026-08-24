#!/usr/bin/env python3
"""
Procedural audio asset generator.

Generates all game SFX and short music loops as original, deterministic,
license-clean WAV files (44.1 kHz, 16-bit mono). Nothing here is copied or
sampled — every sound is synthesized from oscillators and envelopes in a
single, consistent "soft synth pluck" instrument family, per the audio brand
in docs/research/02-ux-game-design.md.

Run:  python3 tools/generate_audio.py
Out:  assets/audio/*.wav

Deterministic: numpy is seeded so re-runs produce byte-identical files.
"""
import math
import os
import wave
import struct

import numpy as np

SR = 44100
SEED = 20260811
rng = np.random.default_rng(SEED)

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
os.makedirs(OUT, exist_ok=True)


# ---------------------------------------------------------------- synthesis
def env_ad(n, a=0.004, d=0.05):
    """Attack-decay envelope (exponential), no sustain/release — plucks."""
    t = np.arange(n) / SR
    atk = np.clip(t / a, 0, 1)
    dec = np.exp(-(t - a) / d)
    dec[: int(a * SR)] = 1.0
    return atk * dec


def osc(freq, n, kind="sine"):
    t = np.arange(n) / SR
    phase = 2 * np.pi * freq * t
    if kind == "sine":
        return np.sin(phase)
    if kind == "square":
        return np.sign(np.sin(phase))
    if kind == "saw":
        return 2 * (phase / (2 * np.pi) % 1.0) - 1
    if kind == "tri":
        return 2 / np.pi * np.arcsin(np.sin(phase))
    raise ValueError(kind)


def pluck(freq, dur, kind="sine", harmonics=None, gain=0.5, a=0.003, d=None):
    """A pitched pluck: base oscillator + optional harmonic stack, AD envelope."""
    n = int(dur * SR)
    d = d or max(0.05, dur * 0.6)
    s = np.zeros(n)
    if harmonics is None:
        harmonics = [(1.0, 1.0)]
    for mult, amp in harmonics:
        s += amp * osc(freq * mult, n, kind)
    s /= max(1, len(harmonics))
    s *= env_ad(n, a, d)
    s *= gain
    return s


def noise_burst(dur, gain=0.3, low=300, high=8000, a=0.002, d=None):
    """Filtered noise burst (band-ish: two-pole one-pole average)."""
    n = int(dur * SR)
    x = rng.standard_normal(n)
    # cheap low-pass via moving average of the (differentiated) signal
    x = np.diff(x, prepend=0.0)
    k = max(1, int(SR / high))
    x = np.convolve(x, np.ones(k) / k, mode="same")
    k2 = max(1, int(SR / low))
    x = np.convolve(x, np.ones(k2) / k2, mode="same")
    x *= env_ad(n, a, d or dur * 0.5)
    x *= gain
    return x


def tone_sequence(freqs, dur_per, kind="sine", gain=0.45, gap=0.012):
    """A short melodic sequence (used for level-up, gems, etc.)."""
    parts = []
    for i, f in enumerate(freqs):
        part = pluck(f, dur_per, kind=kind, gain=gain)
        pad = np.zeros(int(gap * SR))
        parts.append(part)
        if i < len(freqs) - 1:
            parts.append(pad)
    return np.concatenate(parts)


def normalize(s, peak=0.85):
    m = np.max(np.abs(s))
    if m > 1e-9:
        s = s * (peak / m)
    return np.clip(s, -1.0, 1.0)


def fade_edges(s, ms=6):
    n = int(ms * SR / 1000)
    if n < 1 or len(s) < 2 * n:
        return s
    f = np.linspace(0, 1, n)
    s[:n] *= f
    s[-n:] *= f[::-1]
    return s


def save(name, samples):
    s = normalize(fade_edges(samples))
    pcm = struct.pack("<%dh" % len(s), *(np.int16(s * 32767)))
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm)
    print(f"  {name:28s} {len(samples)/SR:5.2f}s  {len(pcm):7d} bytes")


def concat(*parts):
    return np.concatenate(parts)


# ------------------------------------------------------------------ sounds
def build():
    print(f"Generating SFX + music into {os.path.abspath(OUT)}")

    # UI
    save("ui_click.wav", pluck(900, 0.07, "sine", [(1, 1), (2, 0.3)], 0.5))
    save("ui_confirm.wav", tone_sequence([660, 880, 1320], 0.08, gain=0.45))
    save("ui_back.wav", tone_sequence([520, 390], 0.07, gain=0.4))
    save("ui_error.wav", concat(pluck(150, 0.18, "square", [(1, 1), (0.5, 0.5)], 0.4),
                                pluck(110, 0.22, "square", [(1, 1), (0.5, 0.5)], 0.4)))
    save("ui_open.wav", tone_sequence([440, 660], 0.06, gain=0.35))
    save("ui_page.wav", noise_burst(0.05, gain=0.2, low=2000, high=9000))

    # Rewards
    save("reward_coin.wav",
         pluck(1046, 0.18, "sine", [(1, 1), (2.0, 0.4), (3.0, 0.15)], 0.5, a=0.001, d=0.12))
    save("reward_gems.wav",
         tone_sequence([1568, 2093, 2637, 3136], 0.09, gain=0.42))
    save("reward_levelup.wav",
         tone_sequence([523, 659, 784, 1046, 1318], 0.1, gain=0.45))
    save("reward_achievement.wav",
         tone_sequence([784, 988, 1175], 0.12, kind="tri", gain=0.4))
    save("reward_calendar.wav",
         tone_sequence([659, 784, 1046], 0.11, gain=0.42))

    # Feedback
    save("feedback_success.wav", tone_sequence([880, 1175], 0.12, gain=0.45))
    save("feedback_fail.wav", concat(pluck(220, 0.15, "saw", [(1, 1), (0.5, 0.6)], 0.4),
                                     pluck(165, 0.2, "saw", [(1, 1), (0.5, 0.6)], 0.4)))
    save("feedback_perfect.wav", pluck(1568, 0.22, "sine", [(1, 1), (2, 0.5), (4, 0.2)], 0.5, a=0.001, d=0.15))
    save("feedback_good.wav", pluck(988, 0.12, "sine", [(1, 1), (2, 0.3)], 0.45))
    save("feedback_miss.wav", pluck(196, 0.1, "square", [(1, 1)], 0.3))
    save("feedback_countdown.wav", noise_burst(0.04, gain=0.25, low=1500, high=6000))
    save("feedback_tick.wav", pluck(1200, 0.03, "sine", [(1, 1), (2, 0.5)], 0.35))

    # Gameplay
    save("game_drop.wav", concat(noise_burst(0.05, gain=0.4, low=200, high=2000),
                                 pluck(180, 0.1, "sine", [(1, 1), (0.5, 0.8)], 0.35)))
    save("game_pop.wav", pluck(700, 0.09, "sine", [(1, 1), (1.5, 0.6)], 0.5, a=0.001, d=0.06))
    save("game_swish.wav", noise_burst(0.14, gain=0.3, low=500, high=7000, a=0.05, d=0.1))
    save("game_bump.wav", pluck(110, 0.12, "square", [(1, 1), (0.5, 0.7)], 0.35))
    save("game_combo.wav", tone_sequence([880, 1108, 1318, 1760], 0.07, gain=0.42))
    save("game_click.wav", noise_burst(0.03, gain=0.25, low=2500, high=9000))
    save("game_powerup.wav", tone_sequence([660, 990, 1320], 0.07, kind="tri", gain=0.4))
    save("game_break.wav", concat(noise_burst(0.08, gain=0.4, low=300, high=4000),
                                  pluck(320, 0.12, "saw", [(1, 1), (0.6, 0.5)], 0.3)))

    # Music: two short ambient loops (soft pad arpeggios)
    save("bgm_hub.wav", music_loop([261.6, 329.6, 392.0, 523.3], 8, 0.22))
    save("bgm_game.wav", music_loop([220.0, 261.6, 329.6, 440.0], 8, 0.2))
    print("done.")


def music_loop(chords, seconds, gain):
    """Gentle generative pad loop from a 4-chord root set (deterministic)."""
    beat = 0.5
    seq = []
    chord = chords[0]
    for i in range(int(seconds / beat)):
        chord = chords[i % len(chords)]
        f = chord * (1.0 if i % 2 == 0 else 0.5)
        s = pluck(f, beat * 0.9, "tri", [(1, 1), (2, 0.15)], gain=gain, a=0.05, d=beat * 0.8)
        # every 4th beat: add a fifth
        if i % 4 == 3:
            s = s + pluck(f * 1.5, beat * 0.9, "tri", [(1, 1), (2, 0.1)], gain=gain * 0.7, a=0.05, d=beat * 0.8)
        seq.append(s)
    out = np.concatenate(seq)
    # gentle global fade out at loop tail so looping is click-free
    fade = np.linspace(1.0, 0.9, len(out))
    return out * fade


if __name__ == "__main__":
    build()
