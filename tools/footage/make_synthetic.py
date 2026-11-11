#!/usr/bin/env python3
"""Renders the synthetic footage fixtures: 2 s 1080p60 clips of an ITF court
seen by known pinhole cameras (behind the baseline, and at the net post with an
ultra-wide lens), with their manifest entries and ground truth.

Run from the repo root: python3 tools/footage/make_synthetic.py
"""

import json
import math
import os
import subprocess
import tempfile

OUT = "ios/Packages/ChairKit/Tests/ChairKitTests/Fixtures/Footage"
WIDTH, HEIGHT = 1920, 1080
CAMERAS = [
    ("synthetic-baseline", "baseline", (0.0, -19.0, 4.0), (0.0, -2.0, 0.0), 1100.0),
    ("synthetic-netPost", "netPost", (-6.4, 0.0, 1.3), (3.0, 0.0, 0.0), 697.0),
]
FPS = 60
SECONDS = 2

HALF_DOUBLES = 5.485
HALF_SINGLES = 4.115
HALF_LENGTH = 11.885
SERVICE = 6.40
LINE = 0.05
CENTRE_MARK = 0.10

SUBPIXELS = (1 / 6, 1 / 2, 5 / 6)

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


CX, CY = WIDTH / 2, HEIGHT / 2


class Camera:
    def __init__(self, position, target, focal):
        self.position = position
        self.focal = focal
        self.forward = normalise(sub(target, position))
        self.right = normalise(cross(self.forward, (0.0, 0.0, 1.0)))
        self.down = cross(self.forward, self.right)

    def project(self, x, y):
        p = sub((x, y, 0.0), self.position)
        depth = dot(p, self.forward)
        if depth <= 0:
            return None
        return (CX + self.focal * dot(p, self.right) / depth, CY + self.focal * dot(p, self.down) / depth)

    def sees(self, x, y):
        p = self.project(x, y)
        return p is not None and 0 <= p[0] < WIDTH and 0 <= p[1] < HEIGHT


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


def colour(camera, u, v):
    du = (u - CX) / camera.focal
    dv = (v - CY) / camera.focal
    ray = tuple(f + du * r + dv * d for f, r, d in zip(camera.forward, camera.right, camera.down))
    if ray[2] >= 0:
        return SKY
    t = -camera.position[2] / ray[2]
    x, y = camera.position[0] + t * ray[0], camera.position[1] + t * ray[1]
    if on_line(x, y):
        return WHITE
    if abs(x) <= HALF_DOUBLES and abs(y) <= HALF_LENGTH:
        return COURT
    return SURROUND


def render(camera, path):
    pixels = bytearray()
    for v in range(HEIGHT):
        for u in range(WIDTH):
            samples = [colour(camera, u + du, v + dv) for du in SUBPIXELS for dv in SUBPIXELS]
            pixels.extend(round(sum(c[i] for c in samples) / len(samples)) for i in range(3))
    with open(path, "wb") as f:
        f.write(f"P6 {WIDTH} {HEIGHT} 255\n".encode())
        f.write(pixels)


def point(x, y):
    return {"x": round(x, 2), "y": round(y, 2)}


ACROSS = [
    ("doublesLeft", -HALF_DOUBLES),
    ("singlesLeft", -HALF_SINGLES),
    ("centre", 0.0),
    ("singlesRight", HALF_SINGLES),
    ("doublesRight", HALF_DOUBLES),
]
ALONG = [
    ("farBaseline", HALF_LENGTH),
    ("farService", SERVICE),
    ("nearService", -SERVICE),
    ("nearBaseline", -HALF_LENGTH),
]
EXTRA_GROUND_POINTS = [
    ("left doubles sideline at the net", -HALF_DOUBLES, 0.0),
    ("right doubles sideline at the net", HALF_DOUBLES, 0.0),
    ("right singles sideline at the net", HALF_SINGLES, 0.0),
    ("centre of the court", 0.0, 0.0),
    ("right doubles sideline, far service line level", HALF_DOUBLES, SERVICE),
    ("right doubles sideline, near service line level", HALF_DOUBLES, -SERVICE),
]


def keypoints():
    for along, y in ALONG:
        baseline = along.endswith("Baseline")
        for across, x in ACROSS:
            if baseline and across == "centre":
                continue
            if not baseline and across.startswith("doubles"):
                continue
            yield f"{across}-{along}", x, y


def clip(clip_id, placement, camera):
    visible = [(name, x, y) for name, x, y in keypoints() if camera.sees(x, y)]
    extras = [(name, x, y) for name, x, y in EXTRA_GROUND_POINTS if camera.sees(x, y)]
    marks = [{"keypoint": name, "pixel": point(*camera.project(x, y))} for name, x, y in visible]
    ground = [
        {"name": name, "pixel": point(*camera.project(x, y)), "court": {"x": x, "y": y}}
        for name, x, y in visible + extras
    ]
    entry = {
        "id": clip_id,
        "file": f"{clip_id}.mp4",
        "court": "Synthetic",
        "surface": "hard",
        "placement": placement,
        "light": "bright",
        "duration": SECONDS,
        "frameRate": FPS,
        "device": "Synthetic pinhole camera",
    }
    truth = {
        "clip": clip_id,
        "frameSize": {"width": WIDTH, "height": HEIGHT},
        "keypoints": [{"frame": 0, "points": marks}],
        "groundPoints": ground,
    }
    return entry, truth


def main():
    os.makedirs(f"{OUT}/ground_truth", exist_ok=True)
    entries = []
    for clip_id, placement, position, target, focal in CAMERAS:
        camera = Camera(position, target, focal)
        entry, truth = clip(clip_id, placement, camera)
        entries.append(entry)
        with open(f"{OUT}/ground_truth/{clip_id}.json", "w") as f:
            json.dump(truth, f, indent=2)
            f.write("\n")
        with tempfile.TemporaryDirectory() as tmp:
            frame = os.path.join(tmp, "frame.ppm")
            render(camera, frame)
            subprocess.run(
                [
                    "ffmpeg", "-y", "-loglevel", "error", "-loop", "1", "-framerate", str(FPS), "-i", frame,
                    "-t", str(SECONDS), "-r", str(FPS), "-c:v", "libx264", "-pix_fmt", "yuv420p",
                    "-tune", "stillimage", "-crf", "23", "-movflags", "+faststart",
                    f"{OUT}/{clip_id}.mp4",
                ],
                check=True,
            )
    with open(f"{OUT}/manifest.json", "w") as f:
        json.dump({"clips": entries}, f, indent=2)
        f.write("\n")


if __name__ == "__main__":
    main()
