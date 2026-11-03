#!/usr/bin/env python3
"""Regenerates the umpire cue sounds as CAF files in ChairKit.

Run from the repo root: python3 tools/cues/make_cues.py
"""

import math
import os
import struct
import subprocess
import tempfile
import wave

RATE = 44100
OUT = "ios/Packages/ChairKit/Sources/ChairKit/Announcements/Cues"


def envelope(t, length, attack=0.005, decay=6.0):
    rise = min(1.0, t / attack)
    fall = min(1.0, (length - t) / 0.02)
    return rise * fall * math.exp(-decay * t)


def whistle(t, length):
    trill = 1 + 0.03 * math.sin(2 * math.pi * 28 * t)
    tone = math.sin(2 * math.pi * 2600 * trill * t) + 0.25 * math.sin(2 * math.pi * 5200 * trill * t)
    return 0.45 * tone * envelope(t, length, attack=0.01, decay=2.0)


def bell(t, pitch, length):
    partials = [(1.0, 1.0), (2.0, 0.4), (2.76, 0.25), (5.4, 0.1)]
    tone = sum(level * math.sin(2 * math.pi * pitch * ratio * t) for ratio, level in partials)
    return 0.35 * tone * envelope(t, length, decay=7.0)


def chime(t, length):
    return bell(t, 880, length)


def double_chime(t, length):
    second = 0.14
    first = bell(t, 660, length)
    later = bell(t - second, 990, length - second) if t >= second else 0.0
    return 0.7 * (first + later)


def write(name, voice, length):
    frames = int(RATE * length)
    samples = [max(-1.0, min(1.0, voice(i / RATE, length))) for i in range(frames)]
    with tempfile.TemporaryDirectory() as tmp:
        path = os.path.join(tmp, f"{name}.wav")
        with wave.open(path, "wb") as out:
            out.setnchannels(1)
            out.setsampwidth(2)
            out.setframerate(RATE)
            out.writeframes(b"".join(struct.pack("<h", int(s * 32767)) for s in samples))
        target = os.path.join(OUT, f"{name}.caf")
        subprocess.run(["afconvert", "-f", "caff", "-d", "LEI16", path, target], check=True)
    print(f"{target}: {length * 1000:.0f} ms")


def main():
    os.makedirs(OUT, exist_ok=True)
    write("point", whistle, 0.25)
    write("game", chime, 0.35)
    write("set", double_chime, 0.38)
    write("silence", lambda t, length: 0.0, 1.0)


if __name__ == "__main__":
    main()
