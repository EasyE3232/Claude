"""Render build/pose_<Exercise>.json (from tools/posecheck.luau) to a PNG.

Painter's-algorithm software renderer: boxes, 8-sided cylinders, and balls,
shaded by face normal. Three views per frame: side, front, three-quarter.
"""
import json
import math
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.collections import PolyCollection
import numpy as np


def part_faces(p):
    cf = p["cf"]
    pos = np.array(cf[0:3])
    rot = np.array(cf[3:12]).reshape(3, 3)
    sx, sy, sz = [v / 2 for v in p["s"]]
    shape = p.get("shape", "")
    faces = []
    if "Cylinder" in shape:
        n = 10
        r = sy
        ring = [(math.cos(2 * math.pi * k / n) * r, math.sin(2 * math.pi * k / n) * r) for k in range(n)]
        a = [np.array([-sx, y, z]) for y, z in ring]
        b = [np.array([sx, y, z]) for y, z in ring]
        faces.append(a[::-1])
        faces.append(b)
        for k in range(n):
            faces.append([a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]])
    else:
        if "Ball" in shape:
            sx = sy = sz = min(sx, sy, sz)
        c = [np.array([x, y, z]) for x in (-sx, sx) for y in (-sy, sy) for z in (-sz, sz)]
        idx = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
        faces = [[c[i] for i in f] for f in idx]
    out = []
    for f in faces:
        out.append([pos + rot @ v for v in f])
    return out


def render(ax, parts, view, title):
    # view: rotation matrix mapping world -> camera (x right, y up, z toward viewer)
    polys, depths, cols = [], [], []
    light = np.array([0.4, 0.8, 0.45])
    light /= np.linalg.norm(light)
    for p in parts:
        if p.get("t", 0) >= 0.99:
            continue
        base = np.array(p["c"])
        for f in part_faces(p):
            f = np.array(f)
            if len(f) < 3:
                continue
            n = np.cross(f[1] - f[0], f[2] - f[0])
            nn = np.linalg.norm(n)
            if nn < 1e-9:
                continue
            n /= nn
            cam = f @ view.T
            if (view @ n)[2] <= 0:  # back-face cull
                continue
            shade = 0.35 + 0.65 * max(0.0, float(n @ light))
            polys.append(cam[:, :2])
            area = np.linalg.norm(np.cross(f[1] - f[0], f[-1] - f[0]))
            depths.append(cam[:, 2].mean() - (1e5 if area > 150 else 0))
            cols.append(np.clip(base * shade + 0.04, 0, 1))
    order = np.argsort(depths)
    pc = PolyCollection([polys[i] for i in order], facecolors=[cols[i] for i in order], edgecolors=(0, 0, 0, 0.25), linewidths=0.3)
    ax.add_collection(pc)
    ax.autoscale()
    ax.set_aspect("equal")
    ax.set_title(title, fontsize=8)
    ax.set_facecolor((0.93, 0.94, 0.96))
    ax.tick_params(labelsize=5)
    ax.grid(True, lw=0.2)


def rot_y(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, -s], [0, 1, 0], [s, 0, c]])


def rot_x(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, s], [0, -s, c]])


VIEWS = [
    ("side (from +X)", rot_y(math.radians(-90))),
    ("front (from -Z)", rot_y(math.radians(180))),
    ("top", rot_x(math.radians(90))),
    ("3/4", rot_x(math.radians(-18)) @ rot_y(math.radians(-140))),
]


def main():
    kind = sys.argv[1]
    data = json.load(open(f"build/pose_{kind}.json"))
    frames = data["frames"]
    fig, axes = plt.subplots(len(frames), 4, figsize=(16, 3.6 * len(frames)))
    if len(frames) == 1:
        axes = [axes]
    for row, fr in zip(axes, frames):
        for ax, (name, view) in zip(row, VIEWS):
            render(ax, fr["parts"], view, f"{kind} t={fr['t']}  {name}")
    fig.tight_layout()
    out = f"build/pose_{kind}.png"
    fig.savefig(out, dpi=90)
    print(out)


if __name__ == "__main__":
    main()
