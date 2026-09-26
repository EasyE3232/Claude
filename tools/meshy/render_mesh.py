"""Render build/mesh_poses.json with the baked mesh + texture (front view).
Back faces are drawn darker, like MeshPart.DoubleSided."""
import json, re, sys, base64
import numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.collections import PolyCollection

name = sys.argv[1] if len(sys.argv) > 1 else "RonnieCurlman"
base = f"src/ReplicatedStorage/MeshAssets/{name}/"
src = open(base + "Mesh.luau").read()
chunks = {}
for m in re.finditer(r'\t\t(\w+) = \{\n\t\t\tP = \{([^}]*)\},\n\t\t\tT = \{([^}]*)\},\n\t\t\tN = \{([^}]*)\},\n\t\t\tF = \{([^}]*)\}', src):
    chunks[m.group(1)] = [np.array([float(v) for v in m.group(k).split(",")]) for k in (2, 3, 4, 5)]
mods = re.search(r"Modules = \{([^}]*)\}", src).group(1)
tex = b"".join(base64.b64decode(re.search(r'"(.*)"', open(base + t.strip(" '\"") + ".luau").read()).group(1)) for t in mods.split(","))
size = int(round((len(tex) / 3) ** 0.5))
T = np.frombuffer(tex, np.uint8).reshape(size, size, 3) / 255.0
frames = json.load(open("build/mesh_poses.json"))
fig, axes = plt.subplots(1, len(frames), figsize=(4.2 * len(frames), 7))
for ax, fr in zip(axes, frames):
    polys, cols, dep = [], [], []
    for part, (P, U, N, F) in chunks.items():
        cf = np.array(fr["parts"][part]); pos = cf[:3]; rot = cf[3:].reshape(3, 3)
        Pw = P.reshape(-1, 3) @ rot.T + pos; U2 = U.reshape(-1, 2); F = F.astype(int).reshape(-1, 9)
        for f in F:
            p = Pw[f[:3] - 1]
            n = np.cross(p[1] - p[0], p[2] - p[0]); nn = np.linalg.norm(n) + 1e-9
            uv = U2[f[3:6] - 1].mean(0)
            c = T[int(uv[1] * (size - 1)) % size, int(uv[0] * (size - 1)) % size]
            front = n[2] < 0
            shade = (0.5 + 0.5 * abs(n[2]) / nn) * (1.3 if front else 0.45)
            polys.append(np.stack([-p[:, 0], p[:, 1]], 1)); cols.append(np.clip(c * shade, 0, 1)); dep.append(p[:, 2].mean())
    o = np.argsort(dep)[::-1]
    ax.add_collection(PolyCollection([polys[i] for i in o], facecolors=[cols[i] for i in o], edgecolors="none"))
    ax.autoscale(); ax.set_aspect("equal"); ax.set_title(fr["t"]); ax.set_facecolor((0.85, 0.87, 0.9))
fig.savefig(f"build/mesh_poses_{name}.png", dpi=60)
print("->", f"build/mesh_poses_{name}.png")
