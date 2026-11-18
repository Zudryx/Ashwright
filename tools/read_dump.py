#!/usr/bin/env python3
# Copyright (C) 2026 Zudryx. Part of Ashwright, licensed under the GNU GPL v3 or later.
# SPDX-License-Identifier: GPL-3.0-or-later
"""Read the /ash dump out of a SavedVariables Ashwright.lua.

  python3 tools/read_dump.py Ashwright.lua                 # summary
  python3 tools/read_dump.py Ashwright.lua --grep Aura     # frames whose line mentions Aura (with their art)
  python3 tools/read_dump.py Ashwright.lua --below TargetFrame --px 80
        # every frame whose top is within 80 px under TargetFrame's bottom,
        # inside its left/right edges (+-30 px)
"""
import argparse, re, sys

def load(path):
    text = open(path, encoding="utf-8", errors="replace").read()
    start = text.find('["dump"]')
    if start < 0:
        sys.exit("no dump in this file: type /ash dump in game, then log out")
    block = text[start:]
    lines_at = block.find('["lines"]')
    body = block[lines_at:]
    out = []
    for m in re.finditer(r'"((?:[^"\\]|\\.)*)",?\n', body):
        s = m.group(1).encode().decode("unicode_escape")
        if not (s[:1] in ("F", "H", "A", "C", "P", "#") or s.startswith("  ")):
            break
        out.append(s)
    return out

def frames(lines):
    cur = None
    for s in lines:
        if s.startswith("F ") or s.startswith("F? ") or s.startswith("H ") or s.startswith("C ") or s.startswith("P "):
            cur = {"line": s, "art": []}
            parts = s.split(" ", 1)[1].split(" | ")
            cur["name"] = parts[0]
            m = re.match(r"(-?[\d.]+|secret|-),(-?[\d.]+|secret|-) (-?[\d.]+|secret|-)x(-?[\d.]+|secret|-)", parts[4] if len(parts) > 4 else "")
            cur["rect"] = tuple(float(v) if re.match(r"-?[\d.]+$", v) else None for v in m.groups()) if m else None
            yield cur
        elif cur is not None:
            cur["art"].append(s)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("file")
    ap.add_argument("--grep")
    ap.add_argument("--below")
    ap.add_argument("--px", type=float, default=80)
    a = ap.parse_args()
    lines = load(a.file)
    fs = list(frames(lines))
    if a.grep:
        for f in fs:
            if a.grep.lower() in f["line"].lower() or any(a.grep.lower() in x.lower() for x in f["art"]):
                print(f["line"]); [print(x) for x in f["art"]]
        return
    if a.below:
        ref = next((f for f in fs if f["name"] == a.below), None)
        if not ref or not ref["rect"] or None in ref["rect"]:
            sys.exit("no usable position for " + a.below)
        l, b, w, h = ref["rect"]
        for f in fs:
            r = f["rect"]
            if not r or None in r or f is ref:
                continue
            top = r[1] + r[3]
            if l - 30 <= r[0] <= l + w + 30 and b - a.px <= top <= b + 10 and r[2] < 400:
                print(f["line"]); [print(x) for x in f["art"]]
        return
    print(len(fs), "frames,", len(lines), "lines")

if __name__ == "__main__":
    main()
