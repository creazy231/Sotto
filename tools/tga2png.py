"""Converts Sotto's Media/*.tga to PNG for tools/render_ui.lua.
Usage: python3 -I tools/tga2png.py <render-dir>   (writes <render-dir>/media/...)
"""
import os
import sys

from PIL import Image

out_root = os.path.join(sys.argv[1] if len(sys.argv) > 1 else "render", "media")
for folder, _, files in os.walk("Media"):
    for name in files:
        if not name.endswith(".tga"):
            continue
        rel = os.path.relpath(os.path.join(folder, name), "Media")
        dest = os.path.join(out_root, rel[:-4] + ".png")
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        Image.open(os.path.join(folder, name)).convert("RGBA").save(dest)
print("converted to", out_root)
