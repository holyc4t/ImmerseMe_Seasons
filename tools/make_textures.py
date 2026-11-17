"""Generates the art for ImmerseMe: Seasons as 32-bit TGA files.

Everything except the icon is white or grey so the game can tint it (SetVertexColor).
The canvas and the shared ImmerseMe icon frame are adapted from ImmerseMe_Weather/tools/make_icons.py.

Pure Python 3, no dependencies.  Re-run after tweaking:

    python tools/make_textures.py

Files (Media/):
  ring.tga   256x256  the rim band (radius 0.90..1.0 of the half size), tinted with the season
  frost.tga  256x256  rime on the same band: ragged silvery edge and ~20 sparkles
  yeararc.tga 512x512 the season arc under the minimap: a bronze-gold line concentric with it, from
                      1 January (left) to 31 December (right), ticks where the seasons start
                      (full colour)
  seasonicons.tga 256x128  the season icons for the arc, 64 px cells, 4 across: winter, spring,
                      summer, autumn. Top row most lands (snowflake, blossom, sun, maple leaf);
                      bottom row snowbound lands (snowflake, blue mountain flower, sun, frosted leaf)
  notch.tga   16x16   small tick for a festival (tinted gold in game)
  icon.tga   128x128  addon-list icon in the shared ImmerseMe frame: an autumn maple leaf and a snowflake
  decor_spring|summer|autumn|winter.tga  512x512  painted seasonal accents on the rim (full colour,
                      drawn untinted); painted by tools/decor.py

Preview (not shipped): docs/images/seasons.png, the rim in all four seasons with the sibling
addons' orbs and Weather's readout drawn in, to check the look and the clearances; and
docs/images/seasonarc.png, the season arc under a minimap on 17 November.
"""
import math
import os
import struct
import sys
import zlib

sys.path.insert(0, os.path.dirname(__file__))
import decor  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "Media")
SS = 3                      # supersampling for hard-edged shapes

# Must match UI.lua
RING_INNER, RING_OUTER = 0.90, 1.0
# The season arc under the minimap: radius YEAR_R x the minimap's radius, in a square texture whose
# half size is YEAR_TEX x the minimap's radius; from YEAR_FROM degrees (1 January, lower left) over
# YEAR_SPAN degrees (counter-clockwise from the right), between Weather's readout and the zoom buttons.
YEAR_R, YEAR_TEX = 1.36, 1.45
YEAR_FROM, YEAR_SPAN = 240, 56
DECOR_SCALE = decor.DECOR_SCALE   # decor texture size / rim size
# The ring and frost leave the stock north arrow uncovered (degrees CCW from the right).
NORTH_GAP = (84.0, 96.0)


def clamp(v, lo=0.0, hi=1.0):
    return lo if v < lo else hi if v > hi else v


def smoothstep(e0, e1, x):
    t = clamp((x - e0) / (e1 - e0))
    return t * t * (3 - 2 * t)


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def b8(v):
    return int(clamp(v) * 255 + 0.5)


def hash01(*k):
    h = 2166136261
    for v in k:
        h = ((h ^ (int(v) & 0xffffffff)) * 16777619) & 0xffffffff
    return (h % 100003) / 100003.0


def noise1(x, seed):
    """Smooth 1-D value noise in [0,1)."""
    i = math.floor(x)
    f = x - i
    f = f * f * (3 - 2 * f)
    a, b = hash01(seed, i), hash01(seed, i + 1)
    return a + (b - a) * f


class Canvas:
    def __init__(self, size, height=None):
        self.n = size                       # width
        self.h = height or size
        self.px = [[0.0, 0.0, 0.0, 0.0] for _ in range(size * self.h)]

    def blend(self, px, py, c, a):
        if a <= 0 or not (0 <= px < self.n and 0 <= py < self.h):
            return
        d = self.px[py * self.n + px]
        da = d[3]
        oa = a + da * (1 - a)
        for i in range(3):
            d[i] = (c[i] * a + d[i] * da * (1 - a)) / oa
        d[3] = oa

    def each(self, fn):
        """fn(x, y) -> (color, alpha) or None, for every pixel centre."""
        for py in range(self.h):
            for px in range(self.n):
                r = fn(px + .5, py + .5)
                if r:
                    self.blend(px, py, r[0], r[1])

    def fill(self, inside, color, alpha=1.0, bbox=None):
        x0, y0, x1, y1 = bbox or (0, 0, self.n, self.h)
        st = 1.0 / SS
        for py in range(max(0, int(y0)), min(self.h, int(y1) + 1)):
            for px in range(max(0, int(x0)), min(self.n, int(x1) + 1)):
                hits = sum(1 for sy in range(SS) for sx in range(SS)
                           if inside(px + (sx + .5) * st, py + (sy + .5) * st))
                if hits:
                    c = color(px + .5, py + .5) if callable(color) else color
                    self.blend(px, py, c, alpha * hits / (SS * SS))

    def save(self, name):
        n = self.n
        data = bytearray(struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, n, self.h, 32, 8))
        for row in range(self.h - 1, -1, -1):   # bottom-left origin
            for col in range(n):
                r, g, b, a = self.px[row * n + col]
                data += bytes((b8(b), b8(g), b8(r), b8(a)))
        os.makedirs(OUT, exist_ok=True)
        with open(os.path.join(OUT, name + ".tga"), "wb") as f:
            f.write(data)


def polar(c, x, y):
    """Radius as a fraction of the half size, and the game angle in degrees (0 = right, CCW)."""
    h = c.n / 2
    dx, dy = (x - h) / h, (h - y) / h
    return math.hypot(dx, dy), math.degrees(math.atan2(dy, dx)) % 360


def north_open(ang):
    """0 over the north arrow, 1 elsewhere, with soft edges."""
    lo, hi = NORTH_GAP
    return max(1 - smoothstep(lo - 3, lo, ang) * (1 - smoothstep(hi, hi + 3, ang)), 0.0)


def ring():
    c = Canvas(256)
    soft = 1.5 / 128

    def px(x, y):
        r, ang = polar(c, x, y)
        a = smoothstep(RING_INNER - soft, RING_INNER + soft, r) * (1 - smoothstep(RING_OUTER - 2 * soft, RING_OUTER, r))
        a *= north_open(ang)
        if a <= 0:
            return None
        # a little bevel: brighter on the outer edge so the tint reads as a material, not paint
        t = (r - RING_INNER) / (RING_OUTER - RING_INNER)
        g = 0.78 + 0.22 * math.sin(t * math.pi)
        return (g, g, g), a
    c.each(px)
    c.save("ring")


def sparkle(c, x, y, size, alpha):
    for py in range(int(y - size - 1), int(y + size + 2)):
        for px in range(int(x - size - 1), int(x + size + 2)):
            dx, dy = abs(px + .5 - x), abs(py + .5 - y)
            star = max(0.0, 1 - (dx * dy) ** 0.5 / (size * 0.18) - (dx + dy) / (size * 1.6))
            core = max(0.0, 1 - math.hypot(dx, dy) / (size * 0.35))
            a = clamp(max(star, core)) * alpha
            if a > 0.01:
                c.blend(px, py, (1.0, 1.0, 1.0), a)


def frost():
    c = Canvas(256)

    def px(x, y):
        r, ang = polar(c, x, y)
        # the rime creeps inward unevenly from the outer edge
        reach = RING_INNER - 0.03 + 0.06 * noise1(ang / 9.0, 7) + 0.02 * noise1(ang / 2.3, 11)
        a = smoothstep(reach - 0.012, reach + 0.02, r) * (1 - smoothstep(RING_OUTER - 0.012, RING_OUTER, r))
        a *= north_open(ang)
        if a <= 0:
            return None
        crystal = 0.55 + 0.45 * noise1(ang * 1.7 + r * 90, 3)
        return mix((0.80, 0.90, 1.0), (1.0, 1.0, 1.0), crystal), a * (0.55 + 0.35 * crystal)
    c.each(px)
    for i in range(20):
        ang = math.radians(hash01(i, 1) * 360)
        r = (RING_INNER + 0.02 + hash01(i, 2) * (RING_OUTER - RING_INNER - 0.04)) * 128
        if north_open(math.degrees(ang)) < 1:
            continue
        sparkle(c, 128 + r * math.cos(ang), 128 - r * math.sin(ang), 3 + hash01(i, 3) * 4, 0.6 + 0.4 * hash01(i, 4))
    c.save("frost")


def arc_point(f, h, r=None):
    """Texture pixel of the season arc at year fraction f, in a texture of half size h."""
    a = math.radians(YEAR_FROM + f * YEAR_SPAN)
    rr = (r or YEAR_R) / YEAR_TEX * h
    return h + rr * math.cos(a), h - rr * math.sin(a)


def yeararc():
    """The season arc: a line under the minimap, concentric with it, from 1 January (left) to
    31 December (right), with a tick where each season starts and a bead at each end. Square, the
    minimap's centre in the middle, half size = YEAR_TEX x the minimap's radius. Painted in greys
    (dark outline, light body) so the game tints it per land: gold, or frost in snowy lands."""
    n = 512
    h = n / 2
    c = Canvas(n)
    p = decor.Painter(c)
    pts = [arc_point(i / 120, h) for i in range(121)]
    p.line(pts, 14, (1, 1, 1), .16)                        # glow
    p.line(pts, 7, (.1, .1, .1), .95)                      # outline
    p.line(pts, 3.6, (.86, .86, .86), 1)                   # body
    p.line([(x, y - .8) for x, y in pts], 1.4, (1, 1, 1), .5)       # rim light on top
    import datetime
    for month, day in ((3, 20), (6, 21), (9, 22), (12, 21)):   # where each season starts
        f = (datetime.date(2026, month, day).timetuple().tm_yday - 1) / 364
        a, b = arc_point(f, h, YEAR_R - .045), arc_point(f, h, YEAR_R + .045)
        p.line([a, b], 7, (.1, .1, .1), 1)
        p.line([a, b], 3.2, (1, 1, 1), 1)
    for f in (0, 1):                                       # finials at both ends
        x, y = arc_point(f, h)
        p.paint(decor.Circle(x, y, 4.5), (1, 1, 1), (.6, .6, .6), outline=(.1, .1, .1), bevel=3, rim=.5)
    c.save("yeararc")
    return c


SEASON_CELLS = ("winter", "spring", "summer", "autumn")   # seasonicons.tga columns


def seasonicons():
    """The season icons for the arc, 64 px cells, 4 across. Row 0: most lands. Row 1: snowbound
    lands, where the art stays wintry: a blue mountain flower for spring, a frosted leaf for autumn."""
    c = Canvas(256, 128)
    p = decor.Painter(c)
    for row, snowy in ((0, False), (1, True)):
        y = 32 + 64 * row
        decor.snowflake(p, 32, y, 21, rot=15)
        decor.blossom(p, 96, y, 21, rot=90,
                      petal=((.72, .84, 1), (.20, .32, .82)) if snowy else ((1, .88, .93), (.82, .38, .58)))
        decor.sun(p, 160, y, 19)
        leaf = ((.96, .99, 1), (.52, .70, .92)) if snowy else ((1, .74, .26), (.78, .26, .04))
        decor.maple(p, 224, y + 16, 8, 36, *leaf)
    c.save("seasonicons")
    return c


def seasonarc_preview(arc, icons):
    """docs/images/seasonarc.png: the bottom of a minimap with the season arc on 17 November, most
    lands on top, a snowbound land below."""
    n, h = arc.n, arc.n / 2
    rm = h / YEAR_TEX                                       # the minimap's radius in this texture
    today = (datetime_yday(11, 17) - 1) / 364
    marks = {"winter": 39.5 / 364, "spring": 125 / 364, "summer": 217 / 364, "autumn": 309 / 364}
    rows = []
    # the arc's tint per land, from Data.lua's ns.ArcTints
    for row_i, mapcol, tint in ((0, (.27, .38, .2), (1, .80, .36)), (1, (.82, .86, .9), (.80, .92, 1))):
        c = Canvas(n)
        c.each(lambda x, y: ((.07, .15, .22), 1.0))
        c.fill(lambda x, y: math.hypot(x - h, y - h) < rm * 1.11, (.55, .38, .16))     # the rim
        c.fill(lambda x, y: math.hypot(x - h, y - h) < rm, mapcol)                      # the map
        for i, q in enumerate(arc.px):
            if q[3] > 0:
                c.blend(i % n, i // n, [q[k] * tint[k] for k in range(3)], q[3])
        for k, season in enumerate(SEASON_CELLS):
            current = season == "autumn"
            f = today if current else marks[season]
            size = rm * (.26 if current else .19)
            x0, y0 = arc_point(f, h)
            cx, cy = k * 64, row_i * 64
            for y in range(int(y0 - size / 2), int(y0 + size / 2) + 1):
                for x in range(int(x0 - size / 2), int(x0 + size / 2) + 1):
                    u, v = (x - x0) / size + .5, (y - y0) / size + .5
                    if 0 <= u < 1 and 0 <= v < 1:
                        q = icons.px[(cy + int(v * 64)) * 256 + cx + int(u * 64)]
                        grey = sum(q[:3]) / 3
                        col = q[:3] if current else [(v + grey) / 2 * .8 for v in q[:3]]   # dimmed
                        c.blend(x, y, col, q[3] * (1 if current else .85))
        for y in range(int(h), n):
            row = bytearray([0])
            for x in range(n):
                q = c.px[y * n + x]
                row += bytes(b8(v) for v in q[:3])
            rows.append(bytes(row))
    write_png(os.path.join(os.path.dirname(__file__), "..", "docs", "images", "seasonarc.png"), n, n, rows)


def datetime_yday(month, day):
    import datetime
    return datetime.date(2026, month, day).timetuple().tm_yday


def notch():
    c = Canvas(16)
    c.fill(lambda x, y: abs(x - 8) <= 1.6 and 2 <= y <= 14, (1.0, 1.0, 1.0))
    c.save("notch")


def icon():
    """128x128 in the shared ImmerseMe frame (gold bevelled square, gold-ringed medallion)."""
    c = Canvas(128)
    K = 2.0

    def rrect(x0, y0, x1, y1, rad):
        X0, Y0, X1, Y1, R = x0 * K, y0 * K, x1 * K, y1 * K, rad * K
        cx, cy, hx, hy = (X0 + X1) / 2, (Y0 + Y1) / 2, (X1 - X0) / 2 - R, (Y1 - Y0) / 2 - R

        def inside(x, y):
            dx, dy = abs(x - cx) - hx, abs(y - cy) - hy
            return math.hypot(max(dx, 0), max(dy, 0)) + min(max(dx, dy), 0) - R <= 0
        return inside

    def disc(cx, cy, r):
        return lambda x, y: (x - cx * K) ** 2 + (y - cy * K) ** 2 <= (r * K) ** 2

    gold_light, gold_dark = (1.0, 0.86, 0.48), (0.55, 0.35, 0.12)
    c.fill(rrect(0.5, 0.5, 63.5, 63.5, 7), (0.10, 0.06, 0.03))
    c.fill(rrect(1.6, 1.6, 62.4, 62.4, 6), lambda x, y: mix(gold_light, gold_dark, clamp((x + y) / 256)))
    c.fill(rrect(4.2, 4.2, 59.8, 59.8, 4), (0.12, 0.08, 0.04))
    c.fill(rrect(5.2, 5.2, 58.8, 58.8, 3.4),
           lambda x, y: mix((0.30, 0.24, 0.18), (0.10, 0.07, 0.05), clamp(math.hypot(x - 40, y - 36) / 104)))
    c.fill(disc(32, 32, 25.5), (0.12, 0.07, 0.02))
    c.fill(disc(32, 32, 24.4), lambda x, y: mix(gold_light, gold_dark, clamp((x * 0.4 + y) / 179)))
    c.fill(disc(32, 32, 21.6), (0.10, 0.06, 0.02))
    # the medallion's sky: a clear autumn day, cool blue above, warm haze low down
    sky_top, sky_bottom = (0.30, 0.52, 0.78), (0.98, 0.78, 0.50)
    c.fill(disc(32, 32, 20.8), lambda x, y: mix(sky_top, sky_bottom, clamp((y - 22) / 84)))
    # the emblem, painted like the season icons on the arc and clipped to the medallion: a turning
    # maple leaf, the year on its way from autumn into winter, with the first snowflake beside it
    emblem = Canvas(128)
    p = decor.Painter(emblem)
    decor.maple(p, 58, 90, 14, 46, (1, .74, .26), (.78, .26, .04))
    decor.snowflake(p, 90, 88, 15, rot=15)
    for i, q in enumerate(emblem.px):
        if q[3] > 0 and math.hypot(i % 128 + .5 - 64, i // 128 + .5 - 64) <= 41.6:
            c.blend(i % 128, i // 128, q[:3], q[3])
    # glassy highlight, as on the siblings' medallions
    c.each(lambda x, y: ((1, 1, 1), 0.10 * (1 - smoothstep(0, 32, math.hypot(x - 52, y - 44) - 12)))
           if math.hypot(x - 64, y - 64) <= 41.6 else None)
    c.save("icon")


def decorations():
    """Paints both sets; returns {"temperate": {season: canvas}, "snowbound": {...}}."""
    out = {"temperate": {}, "snowbound": {}}
    for style, prefix, painters in (("temperate", "decor_", decor.SEASONS),
                                    ("snowbound", "decor_snowbound_", decor.SNOWBOUND)):
        for season, paint in painters.items():
            c = Canvas(decor.N)
            paint(decor.Painter(c))
            c.save(prefix + season)
            out[style][season] = c
    return out


def drift():
    c = Canvas(decor.DRIFT_N)
    decor.drift_atlas(decor.Painter(c))
    c.save("drift")
    return c


# Rim colours for the preview (from Data.lua's ns.Tints).
PREVIEW_TINT = {
    "temperate": {"spring": (0.42, 0.60, 0.22), "summer": (0.96, 0.72, 0.22),
                  "autumn": (0.80, 0.36, 0.12), "winter": (0.50, 0.68, 0.92)},
    "snowbound": {"spring": (0.50, 0.68, 0.58), "summer": (0.68, 0.70, 0.50),
                  "autumn": (0.56, 0.66, 0.80), "winter": (0.66, 0.84, 1.00)},
}


def preview(decors):
    """docs/images/seasons.png: the rims over a stand-in map, temperate lands on the top row and
    snowbound below, with Weather's and Geography's orbs and Weather's readout drawn in."""
    n, h = decor.N, decor.N / 2
    tiles = []
    for style, season in [(st, se) for st in ("temperate", "snowbound")
                          for se in ("spring", "summer", "autumn", "winter")]:
        c = Canvas(n)
        tint = PREVIEW_TINT[style][season]
        snowy = season == "winter" or (style == "snowbound" and season != "summer")
        mapcol = (0.82, 0.86, 0.9) if snowy else (0.27, 0.38, 0.2)

        # the tile uses the decor texture's frame: the rim's outer edge is at 1/DECOR_SCALE
        def bg(x, y):
            r, ang = polar(c, x, y)
            r *= DECOR_SCALE
            if r < RING_INNER:
                return mix(mapcol, (0, 0, 0), 0.25 * r), 1.0
            if r < RING_OUTER:
                t = (r - RING_INNER) / (RING_OUTER - RING_INNER)
                metal = mix((0.55, 0.36, 0.14), (0.98, 0.84, 0.5), 0.5 + 0.5 * math.sin(t * math.pi))
                return mix(metal, tint, 0.5), 1.0
            return (0.07, 0.15, 0.22), 1.0
        c.each(bg)
        # siblings: Weather orb 45 deg, Geography orb 180 deg, readout bars 200-232 deg
        for ang, col in ((45, (0.23, 0.31, 0.62)), (180, (0.36, 0.24, 0.55))):
            a = math.radians(ang)
            ox, oy = h + 1.08 * h / DECOR_SCALE * math.cos(a), h - 1.08 * h / DECOR_SCALE * math.sin(a)
            c.fill(lambda x, y, ox=ox, oy=oy: math.hypot(x - ox, y - oy) < 30, (0.88, 0.74, 0.4))
            c.fill(lambda x, y, ox=ox, oy=oy: math.hypot(x - ox, y - oy) < 24, col)
        for ang in range(200, 236, 8):
            a = math.radians(ang)
            bx, by = h + 1.2 * h / DECOR_SCALE * math.cos(a), h - 1.2 * h / DECOR_SCALE * math.sin(a)
            c.fill(lambda x, y, bx=bx, by=by: abs(x - bx) < 40 and abs(y - by) < 7, (1, 1, 1), 0.55)
        # the painted accents
        for i, p in enumerate(decors[style][season].px):
            if p[3] > 0:
                c.blend(i % n, i // n, p[:3], p[3])
        tiles.append(c)
    # 2x downsample, four tiles a row: temperate on top, snowbound below
    th = n // 2
    w, hgt = th * 4, th * 2
    rows = []
    for y in range(hgt):
        row = bytearray([0])
        for tile in tiles[(y // th) * 4:(y // th) * 4 + 4]:
            for x in range(th):
                acc = [0.0, 0.0, 0.0]
                for dy in (0, 1):
                    for dx in (0, 1):
                        p = tile.px[(2 * (y % th) + dy) * n + 2 * x + dx]
                        for k in range(3):
                            acc[k] += p[k] * p[3] / 4
                row += bytes(b8(v) for v in acc)
        rows.append(bytes(row))

    write_png(os.path.join(os.path.dirname(__file__), "..", "docs", "images", "seasons.png"), w, hgt, rows)
    # `python tools/make_textures.py <dir>` also writes a full-size close-up of each rim's right
    # half (and winter's top-left) to <dir>/seasons_zoom.png, for judging the painting.
    if len(sys.argv) > 1:
        crops = [(t, 240, 0) for t in tiles] + [(tiles[3], 40, 0), (tiles[7], 40, 0)]
        cw, ch = 272, 512
        zrows = []
        for y in range(ch):
            row = bytearray([0])
            for tile, x0, y0 in crops:
                for x in range(cw):
                    p = tile.px[(y0 + y) * n + x0 + x]
                    row += bytes(b8(v * p[3]) for v in p[:3])
            zrows.append(bytes(row))
        write_png(os.path.join(sys.argv[1], "seasons_zoom.png"), cw * len(crops), ch, zrows)


def write_png(path, w, h, rows):
    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(b"".join(rows), 9)) + chunk(b"IEND", b""))


def main():
    ring()
    frost()
    seasonarc_preview(yeararc(), seasonicons())
    notch()
    icon()
    drift()
    preview(decorations())
    print("wrote", ", ".join(sorted(f for f in os.listdir(OUT) if f.endswith(".tga"))), "+ docs/images/seasons.png, seasonarc.png")


if __name__ == "__main__":
    main()
