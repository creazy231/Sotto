"""Checks the generated media: every texture the code uses exists, is a 32-bit
TGA with power-of-two sides, and the chime is a real Ogg Vorbis file.
Run from the addon folder: python3 -I tests/test_media.py
"""
import os
import re
import sys

from PIL import Image

ROOT = "."
problems = []

# Every Media path the Lua code references.
used = set()
for folder in ("Core", "UI"):
    for name in os.listdir(os.path.join(ROOT, folder)):
        if not name.endswith(".lua"):
            continue
        text = open(os.path.join(ROOT, folder, name), encoding="utf-8").read()
        for m in re.finditer(r'MEDIA \.\. "([^"]+)"', text):
            used.add(m.group(1).replace("\\\\", "/"))
        for m in re.finditer(r'W\.Icon\([^,]+, "([a-z]+)"', text):
            used.add("Icons/" + m.group(1))
        for m in re.finditer(r'IconButton\([^,]+, "([a-z]+)"', text):
            used.add("Icons/" + m.group(1))

for rel in sorted(used):
    if rel.endswith("/"):
        continue
    path = os.path.join(ROOT, "Media", rel + ("" if rel.endswith(".ogg") else ".tga"))
    if not os.path.exists(path):
        problems.append("missing " + path)
        continue
    if path.endswith(".tga"):
        im = Image.open(path)
        w, h = im.size
        if im.mode != "RGBA":
            problems.append(f"{path}: mode {im.mode}, want RGBA")
        if w & (w - 1) or h & (h - 1):
            problems.append(f"{path}: {w}x{h} is not a power of two")

ogg = os.path.join(ROOT, "Media", "Sounds", "chime.ogg")
if not os.path.exists(ogg):
    problems.append("missing " + ogg)
else:
    head = open(ogg, "rb").read(64)
    if not head.startswith(b"OggS") or b"vorbis" not in open(ogg, "rb").read(200):
        problems.append(ogg + " is not Ogg Vorbis")

for p in problems:
    print("MEDIA " + p)
print(f"media ok ({len(used)} references)" if not problems else f"{len(problems)} media problem(s)")
sys.exit(1 if problems else 0)
