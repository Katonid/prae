#!/usr/bin/env python3
"""Generate the alarm tones for app/src/main/res/raw.

Pure standard library on purpose - no numpy, no sample library, no licence
question, and every alarm type gets a sound of its own so that a colleague can
tell a fire drill from an intruder alert before reading a single word.

Run from anywhere:  python3 scripts/alarmtoene.py
"""

from __future__ import annotations

import math
import os
import struct
import wave

RATE = 22050
AMPLITUDE = 0.92  # leaves a little headroom before the soft clipper


def sine(freq: float, t: float) -> float:
    return math.sin(2.0 * math.pi * freq * t)


def soft_clip(x: float) -> float:
    """Gentle saturation. Adds odd harmonics, which is exactly what makes a tone
    carry through a closed classroom door - a pure sine sounds far quieter at the
    same peak level."""
    return math.tanh(1.8 * x) / math.tanh(1.8)


def envelope(i: int, total: int, attack: float, release: float) -> float:
    """Linear attack/release in samples, to keep every segment click-free."""
    a = max(1, int(attack * RATE))
    r = max(1, int(release * RATE))
    if i < a:
        return i / a
    if i > total - r:
        return max(0.0, (total - i) / r)
    return 1.0


def write_wave(path: str, samples: list[float]) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        frames = bytearray()
        for value in samples:
            clipped = max(-1.0, min(1.0, value))
            frames += struct.pack("<h", int(clipped * 32767))
        out.writeframes(bytes(frames))
    print(f"{path}  {len(samples) / RATE:.2f} s  {os.path.getsize(path) // 1024} KB")


def tone(freq: float, seconds: float, attack: float = 0.006, release: float = 0.006,
         gain: float = 1.0, second: float | None = None) -> list[float]:
    """One steady tone, optionally with a second partial for more bite."""
    total = int(seconds * RATE)
    out = []
    for i in range(total):
        t = i / RATE
        value = sine(freq, t)
        if second is not None:
            value += 0.45 * sine(second, t)
            value /= 1.45
        out.append(soft_clip(value) * AMPLITUDE * gain * envelope(i, total, attack, release))
    return out


def sweep(low: float, high: float, seconds: float, gain: float = 1.0) -> list[float]:
    """Rising sweep. The phase is integrated rather than computed per sample, so the
    waveform stays continuous - computing sin(2*pi*f(t)*t) directly produces a
    discontinuity you can hear as a rattle."""
    total = int(seconds * RATE)
    out = []
    phase = 0.0
    for i in range(total):
        frac = i / total
        freq = low + (high - low) * frac
        phase += 2.0 * math.pi * freq / RATE
        out.append(soft_clip(math.sin(phase)) * AMPLITUDE * gain * envelope(i, total, 0.01, 0.01))
    return out


def silence(seconds: float) -> list[float]:
    return [0.0] * int(seconds * RATE)


def amok() -> list[float]:
    """Fast two-tone hi-lo, the signal everyone reads as "danger, now". Four seconds
    loop seamlessly because the pattern ends where it starts."""
    out: list[float] = []
    for _ in range(8):
        out += tone(1180.0, 0.25, second=2360.0)
        out += tone(880.0, 0.25, second=1760.0)
    return out


def fire() -> list[float]:
    """Rising sweeps, the classic evacuation sound: urgent, but not the same as amok."""
    out: list[float] = []
    for _ in range(4):
        out += sweep(520.0, 1250.0, 0.85)
        out += silence(0.15)
    return out


def medical() -> list[float]:
    """Calmer double beep. A medical emergency needs attention, not panic."""
    out: list[float] = []
    for _ in range(5):
        out += tone(740.0, 0.16, gain=0.85)
        out += silence(0.09)
        out += tone(740.0, 0.16, gain=0.85)
        out += silence(0.39)
    return out


def test() -> list[float]:
    """Shorter and friendlier - a drill must never be mistaken for the real thing."""
    out: list[float] = []
    for _ in range(3):
        out += tone(660.0, 0.12, gain=0.7)
        out += silence(0.08)
        out += tone(990.0, 0.12, gain=0.7)
        out += silence(0.35)
    return out


def all_clear() -> list[float]:
    """Rising major triad, decaying. Unmistakably the end of something."""
    out: list[float] = []
    for freq in (523.25, 659.25, 783.99):
        out += tone(freq, 0.28, attack=0.01, release=0.12, gain=0.75)
    out += tone(1046.50, 0.75, attack=0.01, release=0.6, gain=0.75)
    return out


TRACKS = {
    "alarm_amok": amok,
    "alarm_fire": fire,
    "alarm_medical": medical,
    "alarm_test": test,
    "all_clear": all_clear,
}


def main() -> None:
    here = os.path.dirname(os.path.abspath(__file__))
    raw_dir = os.path.join(here, "..", "app", "src", "main", "res", "raw")
    for name, builder in TRACKS.items():
        write_wave(os.path.normpath(os.path.join(raw_dir, name + ".wav")), builder())


if __name__ == "__main__":
    main()
