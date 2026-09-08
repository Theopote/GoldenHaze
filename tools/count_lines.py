import os

root = os.path.join(os.path.dirname(__file__), "..", "shaders")

def resolve_include(path, seen=None):
    if seen is None:
        seen = set()
    path = os.path.normpath(path)
    if path in seen:
        return []
    seen.add(path)
    lines = open(path, encoding="utf-8").read().splitlines()
    out = []
    for line in lines:
        s = line.strip()
        if s.startswith("#include"):
            inc = s.split('"')[1]
            incpath = os.path.join(root, inc.lstrip("/").replace("/", os.sep))
            out.extend(resolve_include(incpath, seen))
        else:
            out.append(line)
    return out

lines = resolve_include(os.path.join(root, "gbuffers_terrain.fsh"))
for i in range(286, 340):
    print(f"{i + 1}: {lines[i]}")
