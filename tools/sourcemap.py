"""Write sourcemap.json (Rojo format) for src/ so luau-lsp can resolve requires."""
import json, os

def node(name, cls, children=None, path=None):
    n = {"name": name, "className": cls}
    if path:
        n["filePaths"] = [path]
    if children:
        n["children"] = children
    return n

def scan(dirpath):
    out = []
    for entry in sorted(os.listdir(dirpath)):
        p = os.path.join(dirpath, entry)
        if os.path.isdir(p):
            out.append(node(entry, "Folder", scan(p)))
        elif entry.endswith(".luau"):
            base = entry[:-5]
            cls = "ModuleScript"
            if base.endswith(".server"):
                cls, base = "Script", base[:-7]
            elif base.endswith(".client"):
                cls, base = "LocalScript", base[:-7]
            out.append(node(base, cls, path=p))
    return out

rs = scan("src/ReplicatedStorage")
rs.append(node("Remotes", "Folder", [node(n, c) for n, c in [
    ("Equip", "RemoteFunction"), ("Notify", "RemoteEvent"), ("Purchase", "RemoteFunction"),
    ("Rebirth", "RemoteFunction"), ("SetGymColor", "RemoteEvent"), ("DismissFollower", "RemoteEvent")]]))
tree = node("Game", "DataModel", [
    node("ReplicatedStorage", "ReplicatedStorage", rs),
    node("ServerScriptService", "ServerScriptService", scan("src/ServerScriptService")),
    node("StarterPlayer", "StarterPlayer", [node("StarterPlayerScripts", "StarterPlayerScripts", scan("src/StarterPlayerScripts"))]),
])
json.dump(tree, open("sourcemap.json", "w"), indent=1)
print("sourcemap.json written")
