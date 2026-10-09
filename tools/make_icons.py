"""Рисует PNG-иконки HUD (256×256, прозрачный фон) без сторонних библиотек.

Фигуры задаются функциями расстояния (SDF) со сглаживанием краёв; заливка — градиент,
плюс мягкая тень, тёмная обводка и светлый блик. Результат: assets/icons/*.png.
Запуск: python tools/make_icons.py
"""

import math
import os
import struct
import zlib

S = 256
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "icons")


# ---------------------------------------------------------------- холст и PNG
class Canvas:
    def __init__(self):
        self.px = [[0.0, 0.0, 0.0, 0.0] for _ in range(S * S)]  # premultiplied

    def blend(self, x, y, r, g, b, a):
        if a <= 0:
            return
        p = self.px[y * S + x]
        inv = 1 - a
        p[0] = r * a + p[0] * inv
        p[1] = g * a + p[1] * inv
        p[2] = b * a + p[2] * inv
        p[3] = a + p[3] * inv

    def save(self, path):
        raw = bytearray()
        for y in range(S):
            raw.append(0)
            for x in range(S):
                r, g, b, a = self.px[y * S + x]
                if a > 0:
                    r, g, b = r / a, g / a, b / a
                raw += bytes(
                    (
                        max(0, min(255, int(r * 255 + 0.5))),
                        max(0, min(255, int(g * 255 + 0.5))),
                        max(0, min(255, int(b * 255 + 0.5))),
                        max(0, min(255, int(a * 255 + 0.5))),
                    )
                )

        def chunk(tag, data):
            c = struct.pack(">I", len(data)) + tag + data
            return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

        png = b"\x89PNG\r\n\x1a\n"
        png += chunk(b"IHDR", struct.pack(">IIBBBBB", S, S, 8, 6, 0, 0, 0))
        png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        png += chunk(b"IEND", b"")
        with open(path, "wb") as f:
            f.write(png)


def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) / 255 for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


# ---------------------------------------------------------------- фигуры (SDF)
def sd_circle(cx, cy, r):
    return (lambda x, y: math.hypot(x - cx, y - cy) - r), (cx - r, cy - r, cx + r, cy + r)


def sd_box(cx, cy, w, h, radius=0, angle=0):
    ca, sa = math.cos(math.radians(angle)), math.sin(math.radians(angle))
    hw, hh = w / 2, h / 2

    def f(x, y):
        dx, dy = x - cx, y - cy
        lx, ly = dx * ca + dy * sa, -dx * sa + dy * ca
        qx, qy = abs(lx) - hw + radius, abs(ly) - hh + radius
        return math.hypot(max(qx, 0), max(qy, 0)) + min(max(qx, qy), 0) - radius

    ext = math.hypot(hw, hh)
    return f, (cx - ext, cy - ext, cx + ext, cy + ext)


def sd_capsule(x1, y1, x2, y2, r):
    def f(x, y):
        px, py = x - x1, y - y1
        bx, by = x2 - x1, y2 - y1
        t = max(0, min(1, (px * bx + py * by) / (bx * bx + by * by)))
        return math.hypot(px - bx * t, py - by * t) - r

    return f, (min(x1, x2) - r, min(y1, y2) - r, max(x1, x2) + r, max(y1, y2) + r)


def sd_poly(points):
    """Выпуклый многоугольник (точки по часовой стрелке в экранных координатах)."""
    n = len(points)

    def f(x, y):
        d = math.inf
        inside = True
        for i in range(n):
            ax, ay = points[i]
            bx, by = points[(i + 1) % n]
            ex, ey = bx - ax, by - ay
            wx, wy = x - ax, y - ay
            t = max(0, min(1, (wx * ex + wy * ey) / (ex * ex + ey * ey)))
            d = min(d, math.hypot(wx - ex * t, wy - ey * t))
            if ex * wy - ey * wx < 0:
                inside = False
        return -d if inside else d

    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    return f, (min(xs), min(ys), max(xs), max(ys))


def sd_ring(cx, cy, r, w, a0=None, a1=None):
    """Кольцо; при a0/a1 — дуга с круглыми концами (углы в градусах по часовой от оси X)."""
    ends = None
    if a0 is not None:
        ends = [
            (cx + r * math.cos(math.radians(a0)), cy + r * math.sin(math.radians(a0))),
            (cx + r * math.cos(math.radians(a1)), cy + r * math.sin(math.radians(a1))),
        ]

    def f(x, y):
        if ends is not None:
            ang = math.degrees(math.atan2(y - cy, x - cx)) % 360
            lo, hi = a0 % 360, a1 % 360
            ok = lo <= ang <= hi if lo <= hi else (ang >= lo or ang <= hi)
            if not ok:
                return min(math.hypot(x - ex, y - ey) for ex, ey in ends) - w / 2
        return abs(math.hypot(x - cx, y - cy) - r) - w / 2

    e = r + w
    return f, (cx - e, cy - e, cx + e, cy + e)


def union(*shapes):
    fs = [s[0] for s in shapes]
    boxes = [s[1] for s in shapes]
    return (lambda x, y: min(f(x, y) for f in fs)), (
        min(b[0] for b in boxes),
        min(b[1] for b in boxes),
        max(b[2] for b in boxes),
        max(b[3] for b in boxes),
    )


def subtract(a, b):
    fa, fb = a[0], b[0]
    return (lambda x, y: max(fa(x, y), -fb(x, y))), a[1]


# ---------------------------------------------------------------- заливка
def paint(cv, shape, top, bottom=None, alpha=1.0, feather=1.2, grow=0.0, offset=(0, 0), angle=90):
    """Градиент сверху вниз (или по углу) внутри фигуры."""
    f, (x0, y0, x1, y1) = shape
    bottom = bottom or top
    ox, oy = offset
    pad = feather + grow + 2
    xa, ya = max(0, int(x0 - pad + ox)), max(0, int(y0 - pad + oy))
    xb, yb = min(S - 1, int(x1 + pad + ox) + 1), min(S - 1, int(y1 + pad + oy) + 1)
    span_y = max(1, y1 - y0)
    span_x = max(1, x1 - x0)
    ca, sa = math.cos(math.radians(angle)), math.sin(math.radians(angle))
    for y in range(ya, yb + 1):
        for x in range(xa, xb + 1):
            d = f(x + 0.5 - ox, y + 0.5 - oy) - grow
            cov = max(0.0, min(1.0, 0.5 - d / feather))
            if cov <= 0:
                continue
            t = ((x - x0) / span_x * ca + (y - y0) / span_y * sa)
            t = max(0, min(1, t if angle != 90 else (y - y0 - oy) / span_y))
            r, g, b = mix(top, bottom, t)
            cv.blend(x, y, r, g, b, cov * alpha)


def styled(cv, shape, top, bottom, outline=True, shadow=True, shine=True):
    """Фигура в фирменном стиле: тень, обводка, градиент, блик сверху."""
    if shadow:
        paint(cv, shape, (0, 0, 0), alpha=0.28, feather=10, grow=2, offset=(0, 7))
    if outline:
        paint(cv, shape, (0.06, 0.07, 0.1), alpha=0.85, grow=7)
    paint(cv, shape, top, bottom)
    if shine:
        f, box = shape
        x0, y0, x1, y1 = box
        cut = y0 + (y1 - y0) * 0.42

        def hi(x, y, f=f):
            return max(f(x, y) + 7, y - cut)

        paint(cv, (hi, box), (1, 1, 1), alpha=0.22, feather=6)


# ---------------------------------------------------------------- иконки
def icon_island(cv):
    rock = sd_poly([(34, 160), (222, 160), (170, 230), (86, 230)])
    styled(cv, rock, hexc("8a6a52"), hexc("4a3a32"))
    styled(cv, sd_box(128, 158, 196, 30, radius=14), hexc("8fe07a"), hexc("4fa85a"))
    styled(cv, sd_box(128, 118, 20, 62, radius=6), hexc("a87a54"), hexc("6e4c34"), shadow=False)
    crown = union(sd_circle(128, 64, 40), sd_circle(92, 86, 28), sd_circle(164, 86, 28))
    styled(cv, crown, hexc("9ef08a"), hexc("3f9a52"))
    paint(cv, sd_circle(114, 52, 9), hexc("ffffff"), alpha=0.35, feather=6)


def icon_odds(cv):
    leaves = union(
        sd_circle(98, 92, 34), sd_circle(158, 92, 34), sd_circle(98, 148, 34), sd_circle(158, 148, 34)
    )
    styled(cv, sd_capsule(128, 150, 112, 226, 9), hexc("6fcf6a"), hexc("2f8a44"), shine=False)
    styled(cv, leaves, hexc("b8f07a"), hexc("2f9a4a"))
    styled(cv, sd_circle(128, 120, 14), hexc("ffe8a0"), hexc("e0a640"), shadow=False)
    # искра удачи
    star = union(sd_box(204, 52, 8, 44, radius=4), sd_box(204, 52, 44, 8, radius=4))
    paint(cv, star, hexc("fff3c0"), alpha=0.95)


def icon_dungeon(cv):
    styled(cv, sd_capsule(62, 62, 150, 150, 17), hexc("f2f6ff"), hexc("8c98b4"))
    styled(cv, sd_capsule(132, 196, 196, 132, 12), hexc("ffd56a"), hexc("c88a2a"), shadow=False)
    styled(cv, sd_capsule(170, 170, 200, 200, 11), hexc("7a5642"), hexc("3a2820"), shadow=False)
    styled(cv, sd_circle(210, 210, 17), hexc("ffd56a"), hexc("c88a2a"), shadow=False)
    paint(cv, sd_capsule(70, 62, 140, 132, 4), hexc("ffffff"), alpha=0.6)


def icon_profile(cv):
    styled(cv, sd_box(128, 190, 150, 92, radius=44), hexc("9cc2ff"), hexc("4a6fd0"))
    styled(cv, sd_circle(128, 92, 50), hexc("b8d4ff"), hexc("5a80e0"))


def icon_menu(cv):
    teeth = union(*[sd_box(128, 128, 36, 196, radius=8, angle=a) for a in (0, 45, 90, 135)])
    gear = subtract(union(teeth, sd_circle(128, 128, 72)), sd_circle(128, 128, 30))
    styled(cv, gear, hexc("e6eaf2"), hexc("8a93a8"))


def icon_home(cv):
    styled(cv, sd_box(128, 168, 150, 104, radius=12), hexc("fff3dc"), hexc("d8c3a0"))
    roof = sd_poly([(128, 34), (226, 124), (30, 124)])
    styled(cv, roof, hexc("ff8a6a"), hexc("c8463a"))
    styled(cv, sd_box(128, 190, 40, 60, radius=10), hexc("9a6a48"), hexc("5e3e2a"), shadow=False)
    styled(cv, sd_box(82, 160, 30, 30, radius=6), hexc("bfe6ff"), hexc("6aa8e0"), shadow=False)


def icon_hub(cv):
    styled(cv, sd_ring(128, 128, 82, 28), hexc("c8a0ff"), hexc("6a3ad0"))
    paint(cv, sd_circle(128, 128, 64), hexc("7a4af0"), hexc("2a1060"), alpha=0.85)
    paint(cv, sd_ring(128, 128, 40, 8, 200, 470), hexc("e8d8ff"), alpha=0.8)
    paint(cv, sd_ring(128, 128, 22, 6, 20, 290), hexc("ffffff"), alpha=0.8)
    paint(cv, sd_circle(128, 128, 8), hexc("ffffff"))


def icon_shop(cv):
    gem = sd_poly([(78, 64), (178, 64), (226, 112), (128, 222), (30, 112)])
    styled(cv, gem, hexc("8ff0ff"), hexc("6a4ad8"))
    # грани
    paint(cv, sd_poly([(78, 64), (128, 64), (104, 112), (30, 112)]), hexc("ffffff"), alpha=0.35)
    paint(cv, sd_poly([(104, 112), (152, 112), (128, 222)]), hexc("ffffff"), alpha=0.18)
    paint(cv, sd_poly([(152, 112), (226, 112), (128, 222)]), hexc("000000"), alpha=0.12)


def icon_coin(cv):
    styled(cv, sd_circle(128, 128, 96), hexc("ffe27a"), hexc("d08a1e"))
    paint(cv, sd_ring(128, 128, 66, 10), hexc("fff4c8"), hexc("c87e1a"), alpha=0.9)
    # звезда из пяти выпуклых лучей
    for i in range(5):
        a = math.radians(-90 + i * 72)
        tip = (128 + 40 * math.cos(a), 128 + 40 * math.sin(a))
        l = (128 + 15 * math.cos(a - math.radians(36)), 128 + 15 * math.sin(a - math.radians(36)))
        r = (128 + 15 * math.cos(a + math.radians(36)), 128 + 15 * math.sin(a + math.radians(36)))
        paint(cv, sd_poly([(128, 128), l, tip, r]), hexc("fff8dc"), alpha=0.95)
    paint(cv, sd_circle(128, 128, 15), hexc("fff8dc"), alpha=0.95)


def icon_sprout(cv):
    styled(cv, sd_box(128, 214, 130, 30, radius=15), hexc("a87a54"), hexc("6e4c34"))
    styled(cv, sd_capsule(128, 206, 128, 118, 10), hexc("9ae07a"), hexc("3f9a52"), shine=False)
    styled(cv, sd_box(84, 104, 104, 56, radius=28, angle=28), hexc("b4f08a"), hexc("3f9a52"))
    styled(cv, sd_box(168, 82, 112, 60, radius=30, angle=-34), hexc("c6f59a"), hexc("4aa85a"))


def icon_auto(cv):
    styled(cv, sd_ring(128, 128, 78, 30, 40, 330), hexc("a6f0b0"), hexc("2f9a5a"))
    styled(cv, sd_poly([(196, 40), (226, 120), (150, 98)]), hexc("a6f0b0"), hexc("2f9a5a"), shadow=False)


ICONS = {
    "island": icon_island,
    "odds": icon_odds,
    "dungeon": icon_dungeon,
    "profile": icon_profile,
    "menu": icon_menu,
    "home": icon_home,
    "hub": icon_hub,
    "shop": icon_shop,
    "coin": icon_coin,
    "sprout": icon_sprout,
    "auto": icon_auto,
}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, fn in ICONS.items():
        cv = Canvas()
        fn(cv)
        path = os.path.join(OUT, f"{name}.png")
        cv.save(path)
        print("wrote", os.path.relpath(path))
