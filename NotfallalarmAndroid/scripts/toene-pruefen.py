#!/usr/bin/env python3
"""Check that the WAV files in res/raw still match what alarmtoene.py computes.

Not a byte comparison: sin() and tanh() may differ in the last bit between C
libraries, and after the conversion to 16 bit that can flip a single sample by
one. A byte comparison would therefore fail on a different machine for no real
reason. One step of the 16-bit scale is inaudible; anything larger means the
files and the script have genuinely drifted apart.

    python3 scripts/toene-pruefen.py
"""

from __future__ import annotations

import os
import struct
import sys
import wave

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from alarmtoene import RATE, TRACKS  # noqa: E402

TOLERANCE = 1


def stored(path: str) -> list[int]:
    with wave.open(path, "rb") as handle:
        if handle.getnchannels() != 1 or handle.getsampwidth() != 2 or handle.getframerate() != RATE:
            raise ValueError(f"{path}: unerwartetes Format")
        frames = handle.readframes(handle.getnframes())
    return list(struct.unpack("<%dh" % (len(frames) // 2), frames))


def main() -> int:
    raw_dir = os.path.normpath(
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "app", "src", "main", "res", "raw")
    )
    failures = 0

    for name, builder in TRACKS.items():
        path = os.path.join(raw_dir, name + ".wav")
        if not os.path.exists(path):
            print(f"FEHLER {name}.wav fehlt.")
            failures += 1
            continue

        expected = [int(max(-1.0, min(1.0, value)) * 32767) for value in builder()]
        actual = stored(path)

        if len(expected) != len(actual):
            print(f"FEHLER {name}.wav: {len(actual)} Werte statt {len(expected)}.")
            failures += 1
            continue

        worst = max((abs(a - b) for a, b in zip(expected, actual)), default=0)
        if worst > TOLERANCE:
            print(f"FEHLER {name}.wav weicht um bis zu {worst} ab (erlaubt: {TOLERANCE}).")
            failures += 1
        else:
            print(f"{name}.wav in Ordnung (groesste Abweichung {worst}).")

    if failures:
        print(f"\n{failures} Datei(en) passen nicht zu scripts/alarmtoene.py.")
        return 1
    print("\nAlle Alarmtöne passen zum Skript.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
