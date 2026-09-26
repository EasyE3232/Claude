"""Meshy (or any static textured FBX) -> Gym Wars mesh character.

  python3 tools/meshy/import.py tools/meshy/<Name>.json [--preview]

Writes src/ReplicatedStorage/MeshAssets/<Name>/Mesh.luau (+ Tex*.luau):
an R15-compatible rig built from the landmarks in the JSON, the mesh cut into
the 15 R15 body parts (rigid chunks, each centered on its part), and the base
color texture as RGB bytes. The client assembles it with EditableMesh /
EditableImage (see StarterPlayerScripts/MeshCharacters.client.luau).
"""
import base64, io, json, os, sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import fbx

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

def layer(g, name, key, idxkey):
    el = g.find(name)
    data = el.find(key).props[0]
    idx = el.find(idxkey)
    mapping = el.find("MappingInformationType").props[0]
    assert mapping == "ByPolygonVertex", mapping
    return data, (idx.props[0] if idx is not None else None)

def main(cfg_path, preview=False):
    cfg = json.load(open(cfg_path))
    name = os.path.splitext(os.path.basename(cfg_path))[0]
    r = fbx.load(cfg["fbx"])
    objs = r.find("Objects")
    g = objs.find("Geometry")
    V = g.find("Vertices").props[0].reshape(-1, 3).astype(np.float64)
    pvi = g.find("PolygonVertexIndex").props[0].astype(np.int64)
    ends = np.where(pvi < 0)[0]
    assert np.all(np.diff(np.concatenate([[-1], ends])) == 3), "mesh must be triangulated"
    tri = pvi.reshape(-1, 3).copy(); tri[:, 2] = -tri[:, 2] - 1
    uv, uvi = layer(g, "LayerElementUV", "UV", "UVIndex")
    uv = uv.reshape(-1, 2); uvi = (uvi if uvi is not None else np.arange(len(pvi))).reshape(-1, 3)
    nrm, nri = layer(g, "LayerElementNormal", "Normals", "NormalsIndex")
    nrm = nrm.reshape(-1, 3); nri = (nri if nri is not None else np.arange(len(pvi))).reshape(-1, 3)

    # FBX model is Z-up (Lcl Rotation -90 X): (x, y, z) -> (x, z, -y), then turn
    # to face Roblox's -Z when the model faces +Z.
    def conv(a):
        w = np.stack([a[:, 0], a[:, 2], -a[:, 1]], 1)
        if cfg.get("faces", "+Z") == "+Z":
            w = np.stack([-w[:, 0], w[:, 1], -w[:, 2]], 1)
        return w
    W = conv(V); N = conv(nrm)
    y0, y1 = W[:, 1].min(), W[:, 1].max()
    s = cfg["height"] / (y1 - y0)
    zc = (W[:, 2].min() + W[:, 2].max()) / 2
    P = np.stack([W[:, 0] * s, (W[:, 1] - y0) * s, (W[:, 2] - zc) * s], 1)
    Wn = np.stack([W[:, 0], W[:, 1]], 1)  # normalized xy for landmark refinement

    def lm(x, y, side=0):
        """landmark (|x|, y) in normalized space -> rig space; z from nearby verts"""
        px = abs(x) * side  # Roblox Left = -X
        d = np.hypot(Wn[:, 0] - px, Wn[:, 1] - y)
        near = P[d < 0.09]
        z = float(near[:, 2].mean()) if len(near) else 0.0
        return np.array([px * s, (y - y0) * s, z])

    J = {}
    J["Neck"] = lm(0, cfg["neck"]); J["Neck"][2] = lm(0, cfg["neck"])[2]
    J["Waist"] = lm(0, cfg["waist"])
    J["Root"] = lm(0, cfg["hip"][1])
    top = np.array([0, P[:, 1].max(), J["Neck"][2]])
    for side, sg in (("Left", -1), ("Right", 1)):
        J[side + "Shoulder"] = lm(*cfg["shoulder"], sg)
        J[side + "Elbow"] = lm(*cfg["elbow"], sg)
        J[side + "Wrist"] = lm(*cfg["wrist"], sg)
        J[side + "HandTip"] = lm(*cfg["handTip"], sg)
        J[side + "Hip"] = lm(*cfg["hip"], sg)
        J[side + "Knee"] = lm(*cfg["knee"], sg)
        J[side + "Ankle"] = lm(*cfg["ankle"], sg)
        J[side + "Toe"] = np.array([J[side + "Ankle"][0], 0.0, P[:, 2].min() * 0.8])

    R = cfg["radius"]
    bones = {"Head": (J["Neck"], top, R["Head"]),
             "UpperTorso": (J["Waist"], J["Neck"], R["UpperTorso"]),
             "LowerTorso": (J["Root"], J["Waist"], R["LowerTorso"])}
    for side in ("Left", "Right"):
        bones[side + "UpperArm"] = (J[side + "Shoulder"], J[side + "Elbow"], R["UpperArm"])
        bones[side + "LowerArm"] = (J[side + "Elbow"], J[side + "Wrist"], R["LowerArm"])
        bones[side + "Hand"] = (J[side + "Wrist"], J[side + "HandTip"], R["Hand"])
        bones[side + "UpperLeg"] = (J[side + "Hip"], J[side + "Knee"], R["UpperLeg"])
        bones[side + "LowerLeg"] = (J[side + "Knee"], J[side + "Ankle"], R["LowerLeg"])
        bones[side + "Foot"] = (J[side + "Ankle"], J[side + "Toe"], R["Foot"])
    names = list(bones)

    # assign each triangle to the body part whose bone it sits closest to
    # (distance normalized by that part's thickness)
    def scores(C):
        score = np.zeros((len(C), len(names)))
        for k, n in enumerate(names):
            score_part(C, score, k, n)
        return score

    def score_part(C, score, k, n):
            a, b, rad = bones[n]
            ab = b - a
            L2 = max(ab @ ab, 1e-9)
            t = ((C - a) @ ab) / L2
            perp = np.linalg.norm(C - (a + t[:, None] * ab), axis=1)
            # reaching past a joint into the neighbouring part costs extra; the
            # free ends of the chains (head top, hands, toes) are open
            free_end = n in ("Head",) or n.endswith("Hand") or n.endswith("Foot")
            over = np.maximum(-t, 0) + (0 if free_end else np.maximum(t - 1, 0))
            score[:, k] = (perp + 2.5 * over * np.sqrt(L2)) / (rad * s)
            # the torso can't claim skin outside its own silhouette (inner arms)
            if n in ("UpperTorso", "LowerTorso") and "torsoHalfWidth" in cfg:
                tw = cfg["torsoHalfWidth"]
                yn = C[:, 1] / s + y0  # back to normalized height
                f = np.clip((yn - cfg["waist"]) / (cfg["shoulder"][1] - cfg["waist"]), 0, 1)
                limit = (tw["waist"] + (tw["chest"] - tw["waist"]) * f) * s
                score[np.abs(C[:, 0]) > limit, k] += 5
            # hands hang beside the thighs: legs can't reach out to them
            if n.endswith("UpperLeg") and "legMaxX" in cfg:
                score[np.abs(C[:, 0]) > cfg["legMaxX"] * s, k] += 5
            # keep limbs on their own side of the body
            if n.startswith("Left"):
                score[C[:, 0] > 0.05 * s, k] = 1e9
            elif n.startswith("Right"):
                score[C[:, 0] < -0.05 * s, k] = 1e9
    C = P[tri].mean(1)
    score = scores(C)
    owner = score.argmin(1)
    # drop faces the generator stretched across limbs (e.g. fist fused to thigh)
    vown = scores(P).argmin(1)
    arm = np.array([("Arm" in n or "Hand" in n) for n in names])
    leg = np.array([("Leg" in n or "Foot" in n) for n in names])
    tv = vown[tri]
    bridge = arm[tv].any(1) & leg[tv].any(1)
    if bridge.any():
        print(f"dropping {bridge.sum()} arm-leg bridge triangle(s)")
        owner[bridge] = -1

    # Skirts: each child part also carries the parent's skin around its joint,
    # pulled in slightly so the parent's copy wins at rest (no z-fighting) and
    # the flap covers the gap when the joint bends.
    PARENT = {"Head": ("UpperTorso", "Neck"), "UpperTorso": ("LowerTorso", "Waist")}
    for side in ("Left", "Right"):
        PARENT[side + "UpperArm"] = ("UpperTorso", side + "Shoulder")
        PARENT[side + "LowerArm"] = (side + "UpperArm", side + "Elbow")
        PARENT[side + "Hand"] = (side + "LowerArm", side + "Wrist")
        PARENT[side + "UpperLeg"] = ("LowerTorso", side + "Hip")
        PARENT[side + "LowerLeg"] = (side + "UpperLeg", side + "Knee")
        PARENT[side + "Foot"] = (side + "LowerLeg", side + "Ankle")
    SKIRT = cfg.get("skirt", 1.25)
    SHRINK = cfg.get("skirtShrink", 0.96)

    parts, chunks = {}, {}
    for k, n in enumerate(names):
        fi = np.where(owner == k)[0]
        assert len(fi), f"no triangles for {n}"
        own = [(int(f), False) for f in fi]
        skirt = []
        if n in PARENT:
            pn, jn = PARENT[n]
            pk = names.index(pn)
            reach = bones[n][2] * s * SKIRT
            cand = np.where(owner == pk)[0]
            d = np.linalg.norm(C[cand] - J[jn], axis=1)
            skirt = [(int(f), True) for f in cand[d < reach]]
        a, b, _ = bones[n]
        ab = b - a
        def pulled(v):
            t = np.clip(((v - a) @ ab) / max(ab @ ab, 1e-9), 0, 1)
            axis = a + t * ab
            return axis + (v - axis) * SHRINK
        vkeys, vpos = {}, []
        umap, nmap = {}, {}
        F = []
        for f, sk in own + skirt:
            tv = []
            for v in tri[f]:
                key = (int(v), sk)
                if key not in vkeys:
                    vkeys[key] = len(vpos) + 1
                    vpos.append(pulled(P[v]) if sk else P[v])
                tv.append(vkeys[key])
            tu = [umap.setdefault(int(u), len(umap) + 1) for u in uvi[f]]
            tn = [nmap.setdefault(int(x), len(nmap) + 1) for x in nri[f]]
            F += tv + tu + tn
        vpos = np.array(vpos)
        lo, hi = vpos.min(0), vpos.max(0)
        center = (lo + hi) / 2
        size = np.maximum(hi - lo, 0.05)
        parts[n] = (center, size)
        Pl = vpos - center
        U = uv[list(umap.keys())].copy(); U[:, 1] = 1 - U[:, 1]  # Roblox UV origin is top-left
        Nl = N[list(nmap.keys())]
        Nl = Nl / np.maximum(np.linalg.norm(Nl, axis=1, keepdims=True), 1e-9)
        chunks[n] = dict(P=Pl.ravel(), T=U.ravel(), N=Nl.ravel(), F=F, skirt=len(skirt))

    # humanoid root + hip height (feet on the ground when standing)
    k = cfg["height"] / 5.95
    hrp_c = np.array([0, J["Root"][1] + 0.25 * k, 0])
    parts["HumanoidRootPart"] = (hrp_c, np.array([2, 2, 1]) * k)
    joints = [("Root", "LowerTorso", "HumanoidRootPart", J["Root"]), ("Waist", "UpperTorso", "LowerTorso", J["Waist"]),
              ("Neck", "Head", "UpperTorso", J["Neck"])]
    for side in ("Left", "Right"):
        joints += [(side + "Shoulder", side + "UpperArm", "UpperTorso", J[side + "Shoulder"]),
                   (side + "Elbow", side + "LowerArm", side + "UpperArm", J[side + "Elbow"]),
                   (side + "Wrist", side + "Hand", side + "LowerArm", J[side + "Wrist"]),
                   (side + "Hip", side + "UpperLeg", "LowerTorso", J[side + "Hip"]),
                   (side + "Knee", side + "LowerLeg", side + "UpperLeg", J[side + "Knee"]),
                   (side + "Ankle", side + "Foot", side + "LowerLeg", J[side + "Ankle"])]

    # texture: base color, RGB bytes
    tex = None
    for vid in objs.findall("Video"):
        if "Image_0" in vid.props[1] or "base" in vid.props[1].lower():
            tex = Image.open(io.BytesIO(vid.find("Content").props[0])).convert("RGB")
            break
    if tex is None:
        vids_ = objs.findall("Video")
        tex = Image.open(io.BytesIO(vids_[0].find("Content").props[0])).convert("RGB")
    ts = cfg.get("texture", 1024)
    tex = tex.resize((ts, ts), Image.LANCZOS)
    b64 = base64.b64encode(tex.tobytes()).decode()
    CH = 900_000
    tex_parts = [b64[i:i + CH] for i in range(0, len(b64), CH)]

    out = os.path.join(ROOT, "src", "ReplicatedStorage", "MeshAssets", name)
    os.makedirs(out, exist_ok=True)
    for f in os.listdir(out):
        os.remove(os.path.join(out, f))

    def nums(a, fmt="%.4f"):
        return ",".join((fmt % v).rstrip("0").rstrip(".") if fmt != "%d" else str(int(v)) for v in a)
    def v3(a):
        return "{%s}" % nums(a)
    L = ["-- Generated by tools/meshy/import.py from a Meshy FBX. Do not edit by hand.",
         "return {", f'\tName = "{name}",', f"\tHeight = {cfg['height']},",
         f"\tHipHeight = {hrp_c[1] - 1 * k:.4f},", "\tParts = {"]
    for n, (c, sz) in parts.items():
        L.append(f"\t\t{n} = {{ Center = {v3(c)}, Size = {v3(sz)} }},")
    L.append("\t},"); L.append("\tJoints = {")
    for jn, p1, p0, piv in joints:
        L.append(f'\t\t{{ "{jn}", "{p1}", "{p0}", {v3(piv)} }},')
    L.append("\t},"); L.append("\tChunks = {")
    for n, c in chunks.items():
        L.append(f"\t\t{n} = {{")
        L.append(f"\t\t\tP = {{{nums(c['P'])}}},")
        L.append(f"\t\t\tT = {{{nums(c['T'], '%.5f')}}},")
        L.append(f"\t\t\tN = {{{nums(c['N'], '%.3f')}}},")
        L.append(f"\t\t\tF = {{{nums(c['F'], '%d')}}},")
        L.append("\t\t},")
    L.append("\t},")
    L.append(f"\tTexture = {{ Width = {ts}, Height = {ts}, Format = \"RGB\", Modules = {{{', '.join(repr(f'Tex{i + 1}') for i in range(len(tex_parts)))}}} }},")
    L.append("}")
    open(os.path.join(out, "Mesh.luau"), "w").write("\n".join(L) + "\n")
    for i, p in enumerate(tex_parts):
        open(os.path.join(out, f"Tex{i + 1}.luau"), "w").write(
            "-- Generated texture data (base64 RGB). Do not edit.\nreturn \"" + p + "\"\n")
    tris = {n: f'{len(c["F"]) // 9}(+{c["skirt"]})' for n, c in chunks.items()}
    print(f"{name}: {len(tri)} tris -> {tris}")
    print(f"texture {ts}x{ts}: {len(tex_parts)} module(s), mesh module {os.path.getsize(os.path.join(out, 'Mesh.luau')) // 1024} KB")

    if preview:
        render_preview(P, tri, owner, names, J, os.path.join(ROOT, "build", f"meshy_{name}.png"))

def render_preview(P, tri, owner, names, J, path):
    import matplotlib; matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.collections import PolyCollection
    cmap = plt.get_cmap("tab20")
    fig, axes = plt.subplots(1, 2, figsize=(12, 8))
    for ax, (ix, iz, sign, title) in zip(axes, [(0, 2, -1, "front (from -Z)"), (2, 0, 1, "side (from +X)")]):
        polys, cols, dep = [], [], []
        for f in range(len(tri)):
            p = P[tri[f]]
            n = np.cross(p[1] - p[0], p[2] - p[0])
            facing = -n[2] if ix == 0 else n[0]
            if facing <= 0: continue
            xs = p[:, ix] * (1 if ix == 0 else -1)
            polys.append(np.stack([xs, p[:, 1]], 1)); cols.append(cmap(owner[f] % 20))
            dep.append(-p[:, 2].mean() if ix == 0 else p[:, 0].mean())
        o = np.argsort(dep)
        ax.add_collection(PolyCollection([polys[i] for i in o], facecolors=[cols[i] for i in o], edgecolors=(0, 0, 0, 0.2), linewidths=0.2))
        for jn, p in J.items():
            ax.plot(p[ix] * (1 if ix == 0 else -1), p[1], "k.", ms=6)
        ax.autoscale(); ax.set_aspect("equal"); ax.set_title(title)
    fig.savefig(path, dpi=70)
    print("preview ->", path)

if __name__ == "__main__":
    main(sys.argv[1], "--preview" in sys.argv)
