#!/usr/bin/env python3
"""Renders the synthetic footage fixture: a 2 s 1080p60 clip of an ITF court
seen by a known pinhole camera, with its manifest entry and ground truth.

Run from the repo root: python3 tools/footage/make_synthetic.py
"""

import json
import math
import os
import subprocess
import tempfile

OUT = "ios/Packages/ChairKit/Tests/ChairKitTests/Fixtures/Footage"
CLIP_ID = "synthetic-baseline"
WIDTH, HEIGHT = 1920, 1080
FOCAL = 1100.0
CAMERA = (0.0, -19.0, 4.0)
TARGET = (0.0, -2.0, 0.0)
FPS = 60
SECONDS = 2

HALF_DOUBLES = 5.485
HALF_SINGLES = 4.115
HALF_LENGTH = 11.885
SERVICE = 6.40
LINE = 0.05
CENTRE_MARK = 0.10

SKY = (150, 190, 230)
SURROUND = (60, 120, 70)
COURT = (40, 80, 140)
WHITE = (240, 240, 240)


def sub(a, b):
    return tuple(x - y for x, y in zip(a, b))


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def normalise(a):
    length = math.sqrt(dot(a, a))
    return tuple(x / length for x in a)


FORWARD = normalise(sub(TARGET, CAMERA))
RIGHT = normalise(cross(FORWARD, (0.0, 0.0, 1.0)))
DOWN = cross(FORWARD, RIGHT)
CX, CY = WIDTH / 2, HEIGHT / 2


def project(x, y):
    p = sub((x, y, 0.0), CAMERA)
    depth = dot(p, FORWARD)
    return (CX + FOCAL * dot(p, RIGHT) / depth, CY + FOCAL * dot(p, DOWN) / depth)


SEGMENTS = [
    (-HALF_DOUBLES, HALF_LENGTH, HALF_DOUBLES, HALF_LENGTH),
    (-HALF_DOUBLES, -HALF_LENGTH, HALF_DOUBLES, -HALF_LENGTH),
    (-HALF_DOUBLES, -HALF_LENGTH, -HALF_DOUBLES, HALF_LENGTH),
    (HALF_DOUBLES, -HALF_LENGTH, HALF_DOUBLES, HALF_LENGTH),
    (-HALF_SINGLES, -HALF_LENGTH, -HALF_SINGLES, HALF_LENGTH),
    (HALF_SINGLES, -HALF_LENGTH, HALF_SINGLES, HALF_LENGTH),
    (-HALF_SINGLES, SERVICE, HALF_SINGLES, SERVICE),
    (-HALF_SINGLES, -SERVICE, HALF_SINGLES, -SERVICE),
    (0.0, -SERVICE, 0.0, SERVICE),
    (0.0, HALF_LENGTH - CENTRE_MARK, 0.0, HALF_LENGTH),
    (0.0, -HALF_LENGTH, 0.0, -HALF_LENGTH + CENTRE_MARK),
]


def on_line(x, y):
    half = LINE / 2
    for x0, y0, x1, y1 in SEGMENTS:
        if min(x0, x1) - half <= x <= max(x0, x1) + half and min(y0, y1) - half <= y <= max(y0, y1) + half:
            return True
    return False


def colour(u, v):
    du = (u + 0.5 - CX) / FOCAL
    dv = (v + 0.5 - CY) / FOCAL
    ray = tuple(f + du * r + dv * d for f, r, d in zip(FORWARD, RIGHT, DOWN))
    if ray[2] >= 0:
        return SKY
    t = -CAMERA[2] / ray[2]
    x, y = CAMERA[0] + t * ray[0], CAMERA[1] + t * ray[1]
    if on_line(x, y):
        return WHITE
    if abs(x) <= HALF_DOUBLES and abs(y) <= HALF_LENGTH:
        return COURT
    return SURROUND


def render(path):
    pixels = bytearray()
    for v in range(HEIGHT):
        for u in range(WIDTH):
            pixels.extend(colour(u, v))
    with open(path, "wb") as f:
        f.write(f"P6 {WIDTH} {HEIGHT} 255\n".encode())
        f.write(pixels)


def point(x, y):
    return {"x": round(x, 2), "y": round(y, 2)}


def ground_points():
    named = [
        ("far baseline, left doubles sideline", -HALF_DOUBLES, HALF_LENGTH),
        ("far baseline, right doubles sideline", HALF_DOUBLES, HALF_LENGTH),
        ("far baseline, left singles sideline", -HALF_SINGLES, HALF_LENGTH),
        ("far baseline, right singles sideline", HALF_SINGLES, HALF_LENGTH),
        ("far service line, left singles sideline", -HALF_SINGLES, SERVICE),
        ("far service line, right singles sideline", HALF_SINGLES, SERVICE),
        ("far service line, centre service line", 0.0, SERVICE),
        ("near service line, centre service line", 0.0, -SERVICE),
        ("near service line, left singles sideline", -HALF_SINGLES, -SERVICE),
        ("near service line, right singles sideline", HALF_SINGLES, -SERVICE),
        ("near baseline, left singles sideline", -HALF_SINGLES, -HALF_LENGTH),
        ("near baseline, right singles sideline", HALF_SINGLES, -HALF_LENGTH),
    ]
    return [
        {"name": name, "pixel": point(*project(x, y)), "court": {"x": x, "y": y}}
        for name, x, y in named
    ]


def main():
    os.makedirs(f"{OUT}/ground_truth", exist_ok=True)
    corners = [
        project(-HALF_DOUBLES, HALF_LENGTH),
        project(HALF_DOUBLES, HALF_LENGTH),
        project(HALF_DOUBLES, -HALF_LENGTH),
        project(-HALF_DOUBLES, -HALF_LENGTH),
    ]
    for u, v in corners:
        assert 0 <= u < WIDTH and 0 <= v < HEIGHT, (u, v)
    manifest = {
        "clips": [
            {
                "id": CLIP_ID,
                "file": f"{CLIP_ID}.mp4",
                "court": "Synthetic",
                "surface": "hard",
                "placement": "baseline",
                "light": "bright",
                "duration": SECONDS,
                "frameRate": FPS,
                "device": "Synthetic pinhole camera",
            }
        ]
    }
    truth = {
        "clip": CLIP_ID,
        "frameSize": {"width": WIDTH, "height": HEIGHT},
        "corners": [{"frame": 0, "points": [point(u, v) for u, v in corners]}],
        "groundPoints": ground_points(),
    }
    with open(f"{OUT}/manifest.json", "w") as f:
        json.dump(manifest, f, indent=2)
        f.write("\n")
    with open(f"{OUT}/ground_truth/{CLIP_ID}.json", "w") as f:
        json.dump(truth, f, indent=2)
        f.write("\n")
    with tempfile.TemporaryDirectory() as tmp:
        frame = os.path.join(tmp, "frame.ppm")
        render(frame)
        subprocess.run(
            [
                "ffmpeg", "-y", "-loglevel", "error", "-loop", "1", "-framerate", str(FPS), "-i", frame,
                "-t", str(SECONDS), "-r", str(FPS), "-c:v", "libx264", "-pix_fmt", "yuv420p",
                "-tune", "stillimage", "-crf", "23", "-movflags", "+faststart",
                f"{OUT}/{CLIP_ID}.mp4",
            ],
            check=True,
        )


if __name__ == "__main__":
    main()
