"""Minimal binary FBX reader (nodes, properties, arrays, embedded media)."""
import struct, zlib
import numpy as np

class Node:
    __slots__ = ("name", "props", "children")
    def __init__(self, name, props, children):
        self.name, self.props, self.children = name, props, children
    def find(self, name):
        for c in self.children:
            if c.name == name:
                return c
    def findall(self, name):
        return [c for c in self.children if c.name == name]
    def __repr__(self):
        return f"<{self.name} {[p if not hasattr(p,'shape') else p.shape for p in self.props][:4]}>"

_ARR = {b"f": "<f4", b"d": "<f8", b"l": "<i8", b"i": "<i4", b"b": "u1"}

def _prop(data, o):
    t = data[o:o+1]; o += 1
    if t == b"Y": return struct.unpack_from("<h", data, o)[0], o + 2
    if t == b"C": return data[o] != 0, o + 1
    if t == b"I": return struct.unpack_from("<i", data, o)[0], o + 4
    if t == b"F": return struct.unpack_from("<f", data, o)[0], o + 4
    if t == b"D": return struct.unpack_from("<d", data, o)[0], o + 8
    if t == b"L": return struct.unpack_from("<q", data, o)[0], o + 8
    if t in (b"S", b"R"):
        n = struct.unpack_from("<I", data, o)[0]; o += 4
        v = data[o:o+n]
        return (v.decode("utf8", "replace") if t == b"S" else v), o + n
    if t in _ARR:
        n, enc, clen = struct.unpack_from("<III", data, o); o += 12
        raw = data[o:o+clen]
        if enc == 1: raw = zlib.decompress(raw)
        return np.frombuffer(raw, dtype=_ARR[t], count=n), o + clen
    raise ValueError(f"bad prop type {t!r} at {o}")

def _node(data, o, v64):
    if v64:
        end, nprops, plen = struct.unpack_from("<QQQ", data, o); o += 24
    else:
        end, nprops, plen = struct.unpack_from("<III", data, o); o += 12
    nl = data[o]; o += 1
    if end == 0: return None, o
    name = data[o:o+nl].decode(); o += nl
    props = []
    for _ in range(nprops):
        v, o = _prop(data, o); props.append(v)
    children = []
    sentinel = 25 if v64 else 13
    while o < end - sentinel or (o < end and end - o > sentinel):
        c, o = _node(data, o, v64)
        if c is None: break
        children.append(c)
    return Node(name, props, children), end

def load(path):
    data = open(path, "rb").read()
    assert data[:20] == b"Kaydara FBX Binary  ", "not a binary FBX"
    ver = struct.unpack_from("<I", data, 23)[0]
    v64 = ver >= 7500
    o, top = 27, []
    while o < len(data) - 200:
        n, o = _node(data, o, v64)
        if n is None: break
        top.append(n)
    return Node("root", [ver], top)
