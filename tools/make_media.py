"""Generate the addon's textures (white glyphs on transparent, tinted in game).

Usage: python3 -I tools/make_media.py <addon-folder>

Every glyph is drawn at 8x on a large canvas and downsampled with Lanczos, so
the strokes stay crisp at the sizes the UI shows them (glyphs 32 px, shown at
14-16; the mark 64 px, shown at 18-30). Output is uncompressed 32-bit TGA,
which every WoW client reads.
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

SS = 8  # supersampling factor


def canvas(size):
    return Image.new("L", (size * SS, size * SS), 0)


def finish(mask, size):
    small = mask.resize((size, size), Image.LANCZOS)
    out = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    out.putalpha(small)
    return out


def S(v):
    """Design units (px at final size) -> canvas units."""
    return v * SS


def line(d, pts, w):
    d.line([(S(x), S(y)) for x, y in pts], fill=255, width=int(S(w)), joint="curve")
    # round caps
    r = S(w) / 2
    for x, y in (pts[0], pts[-1]):
        d.ellipse([S(x) - r, S(y) - r, S(x) + r, S(y) + r], fill=255)


def circle(d, cx, cy, r, w=None):
    box = [S(cx - r), S(cy - r), S(cx + r), S(cy + r)]
    if w is None:
        d.ellipse(box, fill=255)
    else:
        d.ellipse(box, outline=255, width=int(S(w)))


def star4(d, cx, cy, R, r):
    pts = []
    for i in range(8):
        a = -math.pi / 2 + i * math.pi / 4
        rad = R if i % 2 == 0 else r
        pts.append((S(cx + rad * math.cos(a)), S(cy + rad * math.sin(a))))
    d.polygon(pts, fill=255)


# ---------------------------------------------------------------- glyphs (32)
def g_mark(size=64):
    m = canvas(size)
    d = ImageDraw.Draw(m)
    u = size / 18.0  # mockup viewBox is 18 units
    w = 1.35 * u
    # speech bubble: rounded rectangle with a tail at the bottom left
    x0, y0, x1, y1 = 2.5 * u, 3.0 * u, 15.5 * u, 12.2 * u
    rad = 1.6 * u
    d.rounded_rectangle([S(x0), S(y0), S(x1), S(y1)], radius=S(rad), outline=255, width=int(S(w)))
    # tail: erase a gap in the bottom edge, then draw the tail stroke
    gap = [S(4.6 * u), S(y1 - w), S(7.6 * u), S(y1 + w)]
    d.rectangle(gap, fill=0)
    line(d, [(4.6 * u + w / 2, y1 - w / 2), (4.6 * u + w / 2, 15.0 * u), (7.9 * u, y1 - w / 2)], w)
    star4(d, 9.0 * u, 7.6 * u, 3.0 * u, 0.95 * u)
    return finish(m, size)


def g_gear(size=32):
    """Solid gear silhouette: a disc with eight square teeth and a round hole."""
    m = canvas(size)
    d = ImageDraw.Draw(m)
    c = size / 2
    circle(d, c, c, 8.6)
    for i in range(8):
        a = i * math.pi / 4 + math.pi / 8
        ca, sa = math.cos(a), math.sin(a)
        hw = 2.3  # half tooth width
        pts = []
        for r, side in ((6.5, -1), (12.6, -1), (12.6, 1), (6.5, 1)):
            x = c + r * ca - side * hw * sa
            y = c + r * sa + side * hw * ca
            pts.append((S(x), S(y)))
        d.polygon(pts, fill=255)
    hole = S(3.7)
    d.ellipse([S(c) - hole, S(c) - hole, S(c) + hole, S(c) + hole], fill=0)
    return finish(m, size)


def g_plus(size=32):
    m = canvas(size)
    d = ImageDraw.Draw(m)
    line(d, [(16, 6.5), (16, 25.5)], 2.6)
    line(d, [(6.5, 16), (25.5, 16)], 2.6)
    return finish(m, size)


def g_invite(size=32):
    m = canvas(size)
    d = ImageDraw.Draw(m)
    circle(d, 12.5, 10.5, 4.8, 2.4)
    d.arc([S(3.6), S(18.0), S(21.4), S(34.0)], 200, 340, fill=255, width=int(S(2.4)))
    line(d, [(25.5, 6.5), (25.5, 15.5)], 2.4)
    line(d, [(21.0, 11.0), (30.0, 11.0)], 2.4)
    return finish(m, size)


def g_more(size=32):
    m = canvas(size)
    d = ImageDraw.Draw(m)
    for x in (7, 16, 25):
        circle(d, x, 16, 2.5)
    return finish(m, size)


def g_close(size=32):
    m = canvas(size)
    d = ImageDraw.Draw(m)
    line(d, [(8.5, 8.5), (23.5, 23.5)], 2.6)
    line(d, [(23.5, 8.5), (8.5, 23.5)], 2.6)
    return finish(m, size)


def g_back(size=32):
    m = canvas(size)
    d = ImageDraw.Draw(m)
    line(d, [(19.5, 7.0), (10.5, 16.0), (19.5, 25.0)], 2.6)
    return finish(m, size)


def g_chevron(size=32):
    m = canvas(size)
    d = ImageDraw.Draw(m)
    line(d, [(8.5, 12.0), (16.0, 19.5), (23.5, 12.0)], 2.8)
    return finish(m, size)


def g_down(size=32):
    m = canvas(size)
    d = ImageDraw.Draw(m)
    line(d, [(16, 6.5), (16, 24.0)], 2.6)
    line(d, [(9.0, 17.5), (16.0, 24.5), (23.0, 17.5)], 2.6)
    return finish(m, size)


def g_warn(size=32):
    m = canvas(size)
    d = ImageDraw.Draw(m)
    tri = [(16, 4.5), (28.5, 26.5), (3.5, 26.5), (16, 4.5)]
    line(d, tri, 2.3)
    line(d, [(16, 12.5), (16, 19.0)], 2.5)
    circle(d, 16, 22.6, 1.5)
    return finish(m, size)


def g_moon(size=32):
    m = canvas(size)
    d = ImageDraw.Draw(m)
    circle(d, 15.0, 16.5, 10.5)
    cut = Image.new("L", m.size, 0)
    ImageDraw.Draw(cut).ellipse([S(18.5 - 9.5), S(10.0 - 9.5), S(18.5 + 9.5), S(10.0 + 9.5)], fill=255)
    m = Image.composite(Image.new("L", m.size, 0), m, cut)
    return finish(m, size)


def g_check(size=32):
    m = canvas(size)
    d = ImageDraw.Draw(m)
    line(d, [(7.5, 16.5), (13.5, 22.5), (24.5, 10.0)], 2.8)
    return finish(m, size)


def g_copy(size=32):
    m = canvas(size)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([S(11), S(5), S(26), S(21)], radius=S(2), outline=255, width=int(S(2.3)))
    d.rounded_rectangle([S(6), S(11), S(21), S(27)], radius=S(2), fill=0)
    d.rounded_rectangle([S(6), S(11), S(21), S(27)], radius=S(2), outline=255, width=int(S(2.3)))
    return finish(m, size)


def g_offline(size=32):
    m = canvas(size)
    d = ImageDraw.Draw(m)
    circle(d, 16, 16, 9.5, 2.4)
    line(d, [(10.5, 21.5), (21.5, 10.5)], 2.4)
    return finish(m, size)


# ---------------------------------------------------------------- shapes
def circle_tex(size=64):
    m = canvas(size)
    d = ImageDraw.Draw(m)
    circle(d, size / 2, size / 2, size / 2 - 0.5)
    return finish(m, size)


def pill_tex(w=64, h=32):
    """Stadium shape for switch tracks (white, tinted in game)."""
    m = Image.new("L", (w * SS, h * SS), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, w * SS - 1, h * SS - 1], radius=h * SS // 2, fill=255)
    small = m.resize((w, h), Image.LANCZOS)
    out = Image.new("RGBA", (w, h), (255, 255, 255, 0))
    out.putalpha(small)
    return out


def haze_tex(size=128):
    img = Image.new("L", (size, size), 0)
    px = img.load()
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            r = math.hypot(x - c, y - c) / c
            v = max(0.0, 1.0 - r)
            v = v * v * (3 - 2 * v)  # smoothstep falloff
            px[x, y] = int(round(255 * v))
    out = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    out.putalpha(img)
    return out


def shadow_tex(size=64, edge=16):
    """Black soft square for a 9-slice drop shadow (corners `edge` px)."""
    img = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(img)
    d.rectangle([edge, edge, size - edge - 1, size - edge - 1], fill=255)
    img = img.filter(ImageFilter.GaussianBlur(edge / 2.6))
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.putalpha(img)
    return out


def grip_tex(size=16):
    m = canvas(size)
    d = ImageDraw.Draw(m)
    line(d, [(14.0, 5.5), (5.5, 14.0)], 1.4)
    line(d, [(14.0, 10.0), (10.0, 14.0)], 1.4)
    return finish(m, size)


def minimap_tex(size=64):
    """Round minimap button face: dark disc, faint ring; the mark sits on top in Lua."""
    disc = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    m = canvas(size)
    d = ImageDraw.Draw(m)
    circle(d, size / 2, size / 2, size / 2 - 1)
    a = m.resize((size, size), Image.LANCZOS)
    body = Image.new("RGBA", (size, size), (16, 16, 16, 255))
    disc.paste(body, (0, 0), a)
    ring = canvas(size)
    ImageDraw.Draw(ring).ellipse([S(1.5), S(1.5), S(size - 1.5), S(size - 1.5)], outline=255, width=int(S(1.5)))
    ra = ring.resize((size, size), Image.LANCZOS)
    rl = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    rl.putalpha(ra.point(lambda v: int(v * 0.16)))
    disc.alpha_composite(rl)
    return disc


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "."
    media = os.path.join(root, "Media")
    icons = os.path.join(media, "Icons")
    os.makedirs(icons, exist_ok=True)
    glyphs = {
        "gear": g_gear, "plus": g_plus, "invite": g_invite, "more": g_more, "close": g_close,
        "back": g_back, "chevron": g_chevron, "down": g_down, "warn": g_warn, "moon": g_moon,
        "check": g_check, "copy": g_copy, "offline": g_offline,
    }
    for name, fn in glyphs.items():
        fn().save(os.path.join(icons, name + ".tga"))
    g_mark(64).save(os.path.join(media, "mark.tga"))
    circle_tex().save(os.path.join(media, "circle.tga"))
    pill_tex().save(os.path.join(media, "pill.tga"))
    haze_tex().save(os.path.join(media, "haze.tga"))
    shadow_tex().save(os.path.join(media, "shadow.tga"))
    grip_tex().save(os.path.join(media, "grip.tga"))
    minimap_tex().save(os.path.join(media, "minimap.tga"))
    print("media written to", media)


if __name__ == "__main__":
    main()
