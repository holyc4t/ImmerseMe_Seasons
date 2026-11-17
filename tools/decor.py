"""Painted seasonal decorations for the ImmerseMe: Seasons rim, in the Warcraft hand-painted style.

Each season is one 512x512 RGBA texture in the same polar frame as ring.tga: the texture's centre
is the minimap's centre and the rim band runs from RING_INNER to 1.0 of the half size.

The style follows the stock WoW Forever minimap frame: a bold dark outline, a painted body lit
from the top-left (a light inner bevel, a darker shadow side, a bright rim light on the upper
edge), saturated but warm colours, and chunky shapes that still read at minimap size.

Used by make_textures.py; not run on its own.
"""
import math

N = 512
H = N / 2
# The decor texture is larger than the rim so accents can lie on the frame's outer edge without
# being cut off: radius 1.0 (the frame's outer edge) is at 1/DECOR_SCALE of the texture's half size.
DECOR_SCALE = 1.15     # must match UI.lua

# Where the siblings and stock buttons sit (degrees, counter-clockwise from the right).
# Nothing is anchored inside these sectors.
BLOCKED = [(30, 60, "Weather's orb"), (82, 98, "the compass N"), (165, 195, "Geography's orb"),
           (195, 235, "Weather's readout"), (298, 334, "the zoom buttons")]

LIGHT = (-0.62, -0.78)        # light comes from the top-left (screen coordinates, y down)
OUTLINE = (0.11, 0.06, 0.02)
OUTLINE_PX = 3.0


def clamp(v, lo=0.0, hi=1.0):
    return lo if v < lo else hi if v > hi else v


def smoothstep(e0, e1, x):
    t = clamp((x - e0) / (e1 - e0))
    return t * t * (3 - 2 * t)


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def polar(r, ang):
    """Texture pixel for radius r (fraction of the half size) at a game angle in degrees."""
    a = math.radians(ang)
    rr = r * H / DECOR_SCALE
    return H + rr * math.cos(a), H - rr * math.sin(a)


def check_sector(ang, what):
    a = ang % 360
    for lo, hi, name in BLOCKED:
        if lo <= a < hi:
            raise ValueError(f"{what} at {a:.0f} degrees would sit on {name}")


# ---------------------------------------------------------------------------------- distance fields
def seg_dist(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    t = clamp(((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy or 1e-9))
    return math.hypot(px - ax - t * dx, py - ay - t * dy)


class Poly:
    """Signed distance to a polygon (negative inside)."""

    def __init__(self, pts):
        self.pts = pts
        xs, ys = [p[0] for p in pts], [p[1] for p in pts]
        self.bbox = (min(xs), min(ys), max(xs), max(ys))

    def __call__(self, x, y):
        pts, n = self.pts, len(self.pts)
        d, inside = 1e9, False
        j = n - 1
        for i in range(n):
            (xi, yi), (xj, yj) = pts[i], pts[j]
            d = min(d, seg_dist(x, y, xi, yi, xj, yj))
            if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
                inside = not inside
            j = i
        return -d if inside else d


class Union:
    def __init__(self, *shapes):
        self.shapes = shapes
        bs = [s.bbox for s in shapes]
        self.bbox = (min(b[0] for b in bs), min(b[1] for b in bs), max(b[2] for b in bs), max(b[3] for b in bs))

    def __call__(self, x, y):
        return min(s(x, y) for s in self.shapes)


class Circle:
    def __init__(self, cx, cy, r):
        self.cx, self.cy, self.r = cx, cy, r
        self.bbox = (cx - r, cy - r, cx + r, cy + r)

    def __call__(self, x, y):
        return math.hypot(x - self.cx, y - self.cy) - self.r


class Capsule:
    def __init__(self, ax, ay, bx, by, r):
        self.a, self.b, self.r = (ax, ay), (bx, by), r
        self.bbox = (min(ax, bx) - r, min(ay, by) - r, max(ax, bx) + r, max(ay, by) + r)

    def __call__(self, x, y):
        return seg_dist(x, y, *self.a, *self.b) - self.r


def transform(pts, cx, cy, rot, scale):
    """Local points (y up) -> texture points, rotated by rot degrees CCW and scaled."""
    c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    return [(cx + scale * (x * c - y * s), cy - scale * (x * s + y * c)) for x, y in pts]


# ------------------------------------------------------------------------------------ the painter
class Painter:
    def __init__(self, canvas):
        self.c = canvas

    def paint(self, sdf, light, dark, alpha=1.0, outline=OUTLINE, bevel=6.0, rim=0.55, gloss=None):
        """Fill an SDF shape: dark outline, body shaded from `dark` to `light` towards the top-left,
        an inner bevel, a rim light along the lit edge, and an optional glossy highlight."""
        x0, y0, x1, y1 = sdf.bbox
        pad = OUTLINE_PX + 2
        size = max(x1 - x0, y1 - y0) or 1
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        for py in range(max(0, int(y0 - pad)), min(N, int(y1 + pad) + 1)):
            for px in range(max(0, int(x0 - pad)), min(N, int(x1 + pad) + 1)):
                x, y = px + .5, py + .5
                d = sdf(x, y)
                if d > OUTLINE_PX + 1:
                    continue
                cover = 1 - smoothstep(OUTLINE_PX - .7, OUTLINE_PX + .7, d)
                if cover <= 0:
                    continue
                # directional light across the shape (top-left bright, bottom-right dark)
                t = clamp(.5 - ((x - cx) * LIGHT[0] + (y - cy) * LIGHT[1]) / size * -1.1)
                body = mix(dark, light, t)
                # inner bevel: the edge darkens, the middle lifts
                depth = clamp(-d / bevel)
                body = mix(mix(dark, body, .55), body, depth)
                # rim light on the lit edge, just inside the outline
                ex, ey = sdf(x + 1.5, y) - sdf(x - 1.5, y), sdf(x, y + 1.5) - sdf(x, y - 1.5)
                el = math.hypot(ex, ey) or 1
                facing = clamp(((ex / el) * LIGHT[0] + (ey / el) * LIGHT[1]))
                edge = 1 - smoothstep(0, 2.5, -d)
                body = mix(body, (1, 1, .92), rim * facing * edge * (d < 0))
                if gloss and d < 0:
                    gx, gy, gr = gloss
                    g = 1 - smoothstep(0, gr, math.hypot(x - gx, y - gy))
                    body = mix(body, (1, 1, 1), .55 * g)
                inner = 1 - smoothstep(-.7, .7, d)
                col = mix(outline, body, inner)
                self.c.blend(px, py, col, alpha * cover)

    def line(self, pts, width, color, alpha=1.0):
        """A painted stroke (veins, stems): capsule segments, softly anti-aliased."""
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            cap = Capsule(ax, ay, bx, by, width / 2)
            x0, y0, x1, y1 = cap.bbox
            for py in range(max(0, int(y0 - 1)), min(N, int(y1 + 2))):
                for px in range(max(0, int(x0 - 1)), min(N, int(x1 + 2))):
                    a = 1 - smoothstep(-.6, .6, cap(px + .5, py + .5))
                    if a > 0:
                        self.c.blend(px, py, color, alpha * a)

    def glow(self, cx, cy, r, color, alpha):
        for py in range(max(0, int(cy - r)), min(N, int(cy + r) + 1)):
            for px in range(max(0, int(cx - r)), min(N, int(cx + r) + 1)):
                a = clamp(1 - math.hypot(px + .5 - cx, py + .5 - cy) / r) ** 2
                if a > 0:
                    self.c.blend(px, py, color, alpha * a)


# ------------------------------------------------------------------------------------- the motifs
def leaf_pts(length=1.0, width=.42, steps=14):
    """A pointed oval leaf from (0,0) along +x, y up."""
    top = [(length * i / steps, width * length * math.sin(math.pi * i / steps) ** .8) for i in range(steps + 1)]
    bottom = [(x, -y * .92) for x, y in reversed(top[1:-1])]
    return top + bottom


def maple_pts():
    """A five-lobed maple leaf, stem at (0,0), pointing up (+y), size about 1."""
    lobes = [(90, 1.0), (140, .78), (200, .62), (340, .62), (40, .78)]
    pts = []
    for i, (a, r) in enumerate(sorted(lobes)):
        a2, r2 = sorted(lobes)[(i + 1) % 5]
        gap = (a2 - a) % 360
        for k in range(4):                       # a toothed lobe
            aa = a - 9 + k * 6
            rr = r * (1 if k in (1, 2) else .86)
            pts.append((rr * math.cos(math.radians(aa)), .25 + rr * math.sin(math.radians(aa))))
        mid = a + gap / 2
        pts.append((.32 * math.cos(math.radians(mid)), .25 + .32 * math.sin(math.radians(mid))))
    return pts


def leaf(p, cx, cy, rot, size, light, dark, vein=(.25, .12, .03)):
    pts = transform(leaf_pts(), cx, cy, rot, size)
    p.paint(Poly(pts), light, dark, bevel=size * .22)
    tip = transform([(0, 0), (.85, .02)], cx, cy, rot, size)
    p.line(tip, max(1.2, size * .045), vein, .55)
    for t in (.3, .5, .7):
        side = transform([(t * .85, 0), (t * .85 + .14, .16), ], cx, cy, rot, size)
        p.line(side, max(1, size * .03), vein, .35)
        side = transform([(t * .85, 0), (t * .85 + .14, -.15)], cx, cy, rot, size)
        p.line(side, max(1, size * .03), vein, .35)


def maple(p, cx, cy, rot, size, light, dark):
    stem = transform([(0, .25), (0, -.25)], cx, cy, rot, size)
    p.line(stem, max(2, size * .07), (.25, .12, .04), 1)
    pts = transform(maple_pts(), cx, cy, rot, size)
    p.paint(Poly(pts), light, dark, bevel=size * .2)
    for a in (90, 140, 40, 200, 340):
        v = transform([(0, .25), (.7 * math.cos(math.radians(a)), .25 + .7 * math.sin(math.radians(a)))], cx, cy, rot, size)
        p.line(v, max(1, size * .035), (.35, .1, .02), .45)


def blossom(p, cx, cy, size, rot=0, petal=((1, .88, .93), (.82, .38, .58))):
    petals = []
    for k in range(5):
        a = math.radians(rot + k * 72)
        petals.append(Circle(cx + size * .5 * math.cos(a), cy - size * .5 * math.sin(a), size * .42))
    p.paint(Union(*petals), *petal, bevel=size * .25, rim=.4)
    p.paint(Circle(cx, cy, size * .26), (1, .9, .35), (.85, .5, .08), bevel=3, rim=.3)


def wheat(p, cx, cy, rot, size):
    a = math.radians(rot)
    ux, uy = math.cos(a), -math.sin(a)          # along the ear, screen coords
    stem = [(cx - ux * size * .9, cy - uy * size * .9), (cx + ux * size * 1.05, cy + uy * size * 1.05)]
    p.line(stem, max(2, size * .08), (.45, .3, .08), 1)
    grains = []
    for i in range(6):
        t = -.15 + i * .2
        gx, gy = cx + ux * size * t, cy + uy * size * t
        for side in (-1, 1):
            b = a + side * .55
            ex, ey = gx + math.cos(b) * size * .14, gy - math.sin(b) * size * .14
            pts = transform(leaf_pts(1, .55, 8), ex - math.cos(b) * size * .14, ey + math.sin(b) * size * .14,
                            math.degrees(b), size * .3)
            grains.append(Poly(pts))
    tip = transform(leaf_pts(1, .5, 8), cx + ux * size * 1.0, cy + uy * size * 1.0, rot, size * .28)
    grains.append(Poly(tip))
    p.paint(Union(*grains), (1, .9, .52), (.72, .45, .1), bevel=4, rim=.6)
    for i in range(3):                           # awns
        t = 1.15 + i * .02
        sx, sy = cx + ux * size * .9, cy + uy * size * .9
        b = a + (i - 1) * .25
        p.line([(sx, sy), (sx + math.cos(b) * size * .5, sy - math.sin(b) * size * .5)], 1.2, (.6, .42, .12), .8)


def sun(p, cx, cy, size):
    p.glow(cx, cy, size * 1.9, (1, .85, .4), .45)
    rays = []
    for k in range(12):
        a = math.radians(k * 30 + 15)
        long = 1.0 if k % 2 == 0 else .74
        tip = (cx + size * long * math.cos(a), cy - size * long * math.sin(a))
        bl = (cx + size * .45 * math.cos(a - .24), cy - size * .45 * math.sin(a - .24))
        br = (cx + size * .45 * math.cos(a + .24), cy - size * .45 * math.sin(a + .24))
        rays.append(Poly([bl, tip, br]))
    p.paint(Union(*rays), (1, .86, .38), (.82, .45, .06), bevel=3, rim=.5)
    p.paint(Circle(cx, cy, size * .5), (1, .97, .75), (.95, .6, .1), bevel=size * .3, rim=.7,
            gloss=(cx - size * .17, cy - size * .17, size * .2))


def snowflake(p, cx, cy, size, rot=0):
    p.glow(cx, cy, size * 1.5, (.65, .85, 1), .55)
    arms = []
    for k in range(6):
        a = math.radians(rot + k * 60)
        ex, ey = cx + size * math.cos(a), cy - size * math.sin(a)
        arms.append(Capsule(cx, cy, ex, ey, size * .11))
        for t, l in ((.55, .32), (.8, .22)):
            bx, by = cx + size * t * math.cos(a), cy - size * t * math.sin(a)
            for side in (-1, 1):
                b = a + side * math.radians(55)
                arms.append(Capsule(bx, by, bx + size * l * math.cos(b), by - size * l * math.sin(b), size * .07))
    arms.append(Circle(cx, cy, size * .2))
    p.paint(Union(*arms), (1, 1, 1), (.62, .8, .96), outline=(.12, .22, .38), bevel=3, rim=.3)


def snowcap(p, a0, a1, seed=3, depth=1.0, icicles=(.045, .07, .04, .06), drips=False):
    """A drift of snow lying on the rim from angle a0 to a1, lumpy on top, with icicles under it.
    depth scales how high it piles (1 = reaching just past the frame); drips adds meltwater drops."""
    outer, inner = [], []
    steps = 64
    for i in range(steps + 1):
        ang = a0 + (a1 - a0) * i / steps
        edge = math.sin(math.pi * i / steps) ** .6          # thickest in the middle
        lump = .014 * abs(math.sin(i * .42 + seed)) + .004 * math.sin(i * .9)
        outer.append(polar(.91 + (.085 + .03 * edge + lump * edge) * depth, ang))
        inner.append(polar(.91 - .012 * edge, ang))
    p.paint(Poly(outer + inner[::-1]), (1, 1, 1), (.62, .78, .94), outline=(.14, .22, .34), bevel=7, rim=.6)
    # icicles hanging inward, under the drift
    for k, length in enumerate(icicles or ()):
        t = .22 + .54 * k / max(1, len(icicles) - 1)
        ang = a0 + (a1 - a0) * t
        base_l, base_r = polar(.905, ang + 1.6), polar(.905, ang - 1.6)
        tip = polar(.905 - length, ang)
        p.paint(Poly([base_l, tip, base_r]), (.95, .99, 1), (.5, .72, .95), outline=(.16, .3, .46),
                alpha=.92, bevel=2, rim=.5)
        if drips:                                       # meltwater: a drop under each icicle
            p.paint(Circle(*polar(.905 - length - .022, ang), 3.2), (.85, .95, 1), (.35, .6, .9),
                    outline=(.16, .3, .46), alpha=.85, bevel=2, rim=.6)


def oak_leaf_pts():
    pts = []
    for i in range(29):
        t = i / 28
        w = .38 * math.sin(math.pi * t) ** .7 * (1 + .28 * math.sin(t * math.pi * 7))
        pts.append((t, w))
    return pts + [(x, -y) for x, y in reversed(pts[1:-1])]


def oak(p, cx, cy, rot, size, light, dark):
    pts = transform(oak_leaf_pts(), cx, cy, rot, size)
    p.paint(Poly(pts), light, dark, bevel=size * .2)
    p.line(transform([(-.1, 0), (.9, 0)], cx, cy, rot, size), max(1.2, size * .045), (.3, .12, .02), .55)


# ------------------------------------------------------------------------------- the four seasons
GREEN = ((.55, .80, .25), (.08, .30, .04))
GREEN_D = ((.40, .68, .18), (.05, .22, .03))
ORANGE = ((1, .62, .12), (.50, .12, .02))
RED = ((.92, .26, .12), (.32, .03, .02))
YELLOW = ((1, .82, .25), (.58, .30, .02))
BROWN = ((.74, .42, .16), (.28, .11, .03))

# Decorations lie along the band (radius about .90 to 1.0) and may poke past the frame's outer
# edge by at most about .03 (4 px on screen). Inward they may overlap the map's edge a little.
MID = .95


def tangent_leaf(p, a, size, tilt, colours, r=MID, kind="leaf"):
    """A leaf centred on the rim at angle a, lying along it (tilted by `tilt` degrees)."""
    check_sector(a, kind)
    cx, cy = polar(r, a)
    rot = a + 90 + tilt
    ux, uy = math.cos(math.radians(rot)), -math.sin(math.radians(rot))
    sx, sy = cx - ux * size / 2, cy - uy * size / 2
    if kind == "oak":
        oak(p, sx, sy, rot, size, *colours)
    else:
        leaf(p, sx, sy, rot, size, *colours)


def rim_maple(p, a, size, tilt, colours, r=MID - .01):
    check_sector(a, "maple")
    maple(p, *polar(r, a), a + tilt - 90, size, *colours)


def spring(p):
    # a sprig lying along the right-hand rim, with leaves either side and blossoms on it
    stem = [polar(MID, a) for a in range(334, 384, 3)]
    p.line(stem, 5, (.32, .2, .06), 1)
    for i, a in enumerate((337, 346, 355, 4, 13, 21)):
        tangent_leaf(p, a, 44, 38 if i % 2 else -38, GREEN if i % 2 else GREEN_D, r=MID + (.012 if i % 2 else -.012))
    for a, sz in ((341, 17), (359, 20), (17, 16)):
        check_sector(a, "blossom")
        blossom(p, *polar(MID + .005, a), sz, rot=a)
    # a small sprig with a bud on the top-left
    tangent_leaf(p, 128, 38, 30, GREEN)
    tangent_leaf(p, 122, 34, -30, GREEN_D)
    check_sector(125, "bud")
    p.paint(Circle(*polar(MID + .01, 125), 9), (1, .84, .92), (.8, .32, .52), bevel=4)


def summer(p):
    check_sector(4, "sun")
    sun(p, *polar(MID, 4), 40)
    for a, tilt in ((336, -25), (343, 0), (350, 25)):
        check_sector(a, "wheat")
        # ears point outward-ish along the rim, heads overlapping the band
        wheat(p, *polar(MID - .045, a), a + tilt, 34)


def autumn(p):
    rim_maple(p, 336, 25, -30, RED)
    tangent_leaf(p, 346, 54, 25, ORANGE, kind="oak")
    rim_maple(p, 356, 23, 20, YELLOW)
    rim_maple(p, 12, 22, -15, ORANGE)
    tangent_leaf(p, 22, 48, -30, BROWN, kind="oak")


def winter(p):
    for a in (104, 126, 148):
        check_sector(a, "snow cap")
    snowcap(p, 102, 152)
    for a, r, sz, rot in ((337, MID + .01, 21, 8), (351, MID - .02, 14, 30), (5, MID + .012, 18, 18)):
        check_sector(a, "snowflake")
        snowflake(p, *polar(r, a), sz, rot)


SEASONS = {"spring": spring, "summer": summer, "autumn": autumn, "winter": winter}


# ---------------------------------------------------------------------- snowbound lands (alpine)
PINE = ((.32, .58, .40), (.03, .17, .10))
SNOW = ((1, 1, 1), (.62, .78, .94))
SNOW_LINE = (.14, .22, .34)


def pine(p, a, size, tilt=0, snow=0.0, cones=0, r=MID):
    """A needled pine sprig lying along the rim at angle a, with snow on its upper side and
    optional cones hanging under it."""
    check_sector(a, "pine")
    cx, cy = polar(r, a)
    rot = math.radians(a + 90 + tilt)
    ux, uy = math.cos(rot), -math.sin(rot)          # along the sprig, screen coords
    nx, ny = -uy, ux
    if ny > 0 or (ny == 0 and nx > 0):              # n points up the screen: snow sits there
        nx, ny = -nx, -ny
    sx, sy = cx - ux * size / 2, cy - uy * size / 2
    ex, ey = cx + ux * size / 2, cy + uy * size / 2
    for k in range(cones):                          # cones hanging under the sprig
        t = .3 + .35 * k
        bx, by = sx + ux * size * t - nx * size * .1, sy + uy * size * t - ny * size * .1
        down = math.degrees(math.atan2(ny, -nx))    # local y-up angle of -n
        pts = transform(leaf_pts(1, .55, 10), bx, by, down, size * .22)
        p.paint(Poly(pts), (.72, .46, .22), (.26, .12, .04), bevel=3, rim=.4)
    p.line([(sx - ux * 4, sy - uy * 4), (ex, ey)], max(3, size * .055), (.30, .16, .06), 1)
    # chunky needle tufts in pairs, base to tip, each with its own outline so they read apart
    base_ang = math.degrees(math.atan2(-uy, ux))    # local y-up angle along the sprig
    pairs = 5
    for i in range(pairs):
        t = .06 + .78 * i / (pairs - 1)
        bx, by = sx + ux * size * t, sy + uy * size * t
        length = size * .42 * (1 - .45 * t)
        for side in (-1, 1):
            ang = base_ang + side * 52
            p.paint(Poly(transform(leaf_pts(1, .3, 10), bx, by, ang, length)), *PINE, bevel=3, rim=.4)
            if snow > 0:                            # a cap of snow on each tuft's upper edge
                a = math.radians(ang)
                mx, my = bx + math.cos(a) * length * .5, by - math.sin(a) * length * .5
                px_, py_ = -math.sin(a), -math.cos(a)  # perpendicular, screen coords
                if py_ > 0:
                    px_, py_ = -px_, -py_
                rr = length * .2 * snow
                p.paint(Union(Circle(mx + px_ * rr * .6, my + py_ * rr * .6, rr),
                              Circle(mx + px_ * rr * .5 - math.cos(a) * rr, my + py_ * rr * .5 + math.sin(a) * rr, rr * .75)),
                        *SNOW, outline=SNOW_LINE, bevel=3, rim=.6)
    p.paint(Poly(transform(leaf_pts(1, .3, 10), ex - ux * size * .08, ey - uy * size * .08, base_ang,
                           size * .2)), *PINE, bevel=3, rim=.4)          # the leading tip


def alpine_flower(p, a, size, white=False, r=MID + .01):
    check_sector(a, "flower")
    petal = ((1, 1, 1), (.66, .72, .86)) if white else ((.72, .84, 1), (.20, .32, .82))
    blossom(p, *polar(r, a), size, rot=a, petal=petal)


def snow_spring(p):
    snowcap(p, 104, 146, depth=.7, icicles=(.025, .04, .02), drips=True)
    pine(p, 352, 84, tilt=6)
    for a, sz, w in ((338, 13, False), (4, 15, True), (14, 12, False)):
        alpine_flower(p, a, sz, white=w)


def snow_summer(p):
    snowcap(p, 106, 140, depth=.35, icicles=None, seed=5)
    pine(p, 354, 88, tilt=4, cones=2)


def snow_autumn(p):
    snowcap(p, 102, 150, depth=.85, icicles=(.03, .05, .03, .04), seed=7)
    pine(p, 354, 88, tilt=4, snow=.6, cones=1)
    for a, r, sz, rot in ((338, MID + .02, 13, 12), (16, MID - .01, 11, 30)):
        check_sector(a, "snowflake")
        snowflake(p, *polar(r, a), sz, rot)


def snow_winter(p):
    snowcap(p, 100, 154, depth=1.2, icicles=(.05, .08, .045, .07, .055), seed=2)
    pine(p, 350, 90, tilt=6, snow=1.0)
    pine(p, 14, 52, tilt=-18, snow=.9, r=MID - .015)
    for a, r, sz, rot in ((338, MID + .02, 17, 8), (25, MID + .012, 14, 18)):
        check_sector(a, "snowflake")
        snowflake(p, *polar(r, a), sz, rot)


SNOWBOUND = {"spring": snow_spring, "summer": snow_summer, "autumn": snow_autumn, "winter": snow_winter}


# ---------------------------------------------------------------------------------- drift sprites
DRIFT_N = 64     # Media/drift.tga: 2x2 cells of 32 px: flake, leaf | petal, spare


def drift_atlas(p):
    """The drifting sprites. The leaf is painted in greys so the game can tint it each colour."""
    snowflake(p, 16, 16, 9, rot=15)                                              # cell 1
    oak(p, 32 + 6, 26, 42, 28, (1, 1, 1), (.5, .5, .5))                          # cell 2
    pts = transform(leaf_pts(1, .62, 12), 5, 32 + 25, 35, 23)                   # cell 3
    p.paint(Poly(pts), (1, .88, .93), (.82, .38, .58), bevel=4, rim=.45)
