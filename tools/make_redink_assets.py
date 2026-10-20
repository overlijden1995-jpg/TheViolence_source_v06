#!/usr/bin/env python3
"""Generate the RED INK asset pack for "The Violence" (Godot 4, top-down 90 deg).

Everything here follows the house art direction:

  * base art is neutral only: ink, stepped greys, near-white paper;
  * red is never painted into base art. It lives in assets/redink/masks/ as
    white-on-transparent shapes, applied at runtime through
    shaders/red_mask.gdshader or Ink.accent();
  * every red mark has a second cue (number, ring, dash, hatch, label) so the
    monochrome proof survives;
  * print feel: flat fills, sparse deterministic grain, halftone patches and
    short cross-hatching -- no gradients, no filters, no <text> (Godot drops it,
    so lettering is a 5x7 bitmap built from rects).

Scale: 80 px per metre in every file (manifest "px_per_metre": 80); the game
places sprites at SVG_SCALE = 0.5 against its own 40 px/m world.
Facing: actors face +x (east), which is Godot rotation 0.

    python3 tools/make_redink_assets.py                 # write the pack
    python3 tools/make_redink_assets.py --check         # palette / layer audit
    python3 tools/make_redink_assets.py --list          # print every asset path
    python3 tools/make_redink_assets.py --sheets        # sheets + demo_room.json

The pack is deliberately generated: geometry is reviewable in source, and the
same script produces the contact sheet used for the monochrome proof.
"""
import argparse
import json
import math
import os
import random

PPM = 80

# ------------------------------------------------------------------ palette
# House tokens. Base art may use the neutral set only. Nothing here is red
# except RED, which appears solely in preview/legend swatches and in masks
# (masks are white; the shader supplies the hue).
PAPER = "#EDEDE8"
FLOOR = "#D4D4CF"
LIGHT = "#BFBFBA"
MID = "#737370"
DARK = "#2B2B2B"
INK = "#121212"
RED = "#B31F26"
WHITE = "#FFFFFF"
NEUTRAL = (PAPER, FLOOR, LIGHT, MID, DARK, INK, WHITE)

FONT_5x7 = {
    "A": ".###.|#...#|#...#|#####|#...#|#...#|#...#",
    "B": "####.|#...#|#...#|####.|#...#|#...#|####.",
    "C": ".###.|#...#|#....|#....|#....|#...#|.###.",
    "D": "####.|#...#|#...#|#...#|#...#|#...#|####.",
    "E": "#####|#....|#....|####.|#....|#....|#####",
    "F": "#####|#....|#....|####.|#....|#....|#....",
    "G": ".###.|#...#|#....|#.###|#...#|#...#|.###.",
    "H": "#...#|#...#|#...#|#####|#...#|#...#|#...#",
    "I": ".###.|..#..|..#..|..#..|..#..|..#..|.###.",
    "J": "..###|...#.|...#.|...#.|...#.|#..#.|.##..",
    "K": "#...#|#..#.|#.#..|##...|#.#..|#..#.|#...#",
    "L": "#....|#....|#....|#....|#....|#....|#####",
    "M": "#...#|##.##|#.#.#|#.#.#|#...#|#...#|#...#",
    "N": "#...#|##..#|#.#.#|#.#.#|#..##|#...#|#...#",
    "O": ".###.|#...#|#...#|#...#|#...#|#...#|.###.",
    "P": "####.|#...#|#...#|####.|#....|#....|#....",
    "Q": ".###.|#...#|#...#|#...#|#.#.#|#..#.|.##.#",
    "R": "####.|#...#|#...#|####.|#.#..|#..#.|#...#",
    "S": ".####|#....|#....|.###.|....#|....#|####.",
    "T": "#####|..#..|..#..|..#..|..#..|..#..|..#..",
    "U": "#...#|#...#|#...#|#...#|#...#|#...#|.###.",
    "V": "#...#|#...#|#...#|#...#|#...#|.#.#.|..#..",
    "W": "#...#|#...#|#...#|#.#.#|#.#.#|#.#.#|.#.#.",
    "X": "#...#|#...#|.#.#.|..#..|.#.#.|#...#|#...#",
    "Y": "#...#|#...#|.#.#.|..#..|..#..|..#..|..#..",
    "Z": "#####|....#|...#.|..#..|.#...|#....|#####",
    "0": ".###.|#...#|#..##|#.#.#|##..#|#...#|.###.",
    "1": "..#..|.##..|..#..|..#..|..#..|..#..|.###.",
    "2": ".###.|#...#|....#|...#.|..#..|.#...|#####",
    "3": "####.|....#|....#|.###.|....#|....#|####.",
    "4": "...#.|..##.|.#.#.|#..#.|#####|...#.|...#.",
    "5": "#####|#....|####.|....#|....#|#...#|.###.",
    "6": ".###.|#....|#....|####.|#...#|#...#|.###.",
    "7": "#####|....#|...#.|..#..|.#...|.#...|.#...",
    "8": ".###.|#...#|#...#|.###.|#...#|#...#|.###.",
    "9": ".###.|#...#|#...#|.####|....#|....#|.###.",
    ":": ".....|..#..|..#..|.....|..#..|..#..|.....",
    "/": "....#|...#.|...#.|..#..|.#...|.#...|#....",
    ".": ".....|.....|.....|.....|.....|..##.|..##.",
    "-": ".....|.....|.....|#####|.....|.....|.....",
    " ": ".....|.....|.....|.....|.....|.....|.....",
}


# ------------------------------------------------------------------ drawing
def _f(v):
    s = f"{v:.2f}".rstrip("0").rstrip(".")
    return s if s else "0"


def _attrs(**kw):
    out = []
    for k, v in kw.items():
        if v is None:
            continue
        key = k.replace("_", "-")
        out.append(f'{key}="{v}"')
    return (" " + " ".join(out)) if out else ""


def svg(w, h, body, unit="px"):
    if unit == "m":
        w, h = w * PPM, h * PPM
    w, h = int(round(w)), int(round(h))
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" '
            f'viewBox="0 0 {w} {h}">{body}</svg>\n')


def rect(x, y, w, h, fill="none", stroke=None, sw=2.0, rx=0, op=None, sop=None, dash=None):
    st = _attrs(stroke=stroke, stroke_width=_f(sw) if stroke else None,
                stroke_linejoin="round" if stroke else None,
                stroke_linecap="round" if stroke else None,
                stroke_dasharray=dash, stroke_opacity=sop)
    return (f'<rect x="{_f(x)}" y="{_f(y)}" width="{_f(w)}" height="{_f(h)}" rx="{rx}" '
            f'fill="{fill}"{_attrs(fill_opacity=op)}{st}/>')


def circle(cx, cy, r, fill="none", stroke=None, sw=2.0, op=None, dash=None, sop=None):
    st = _attrs(stroke=stroke, stroke_width=_f(sw) if stroke else None,
                stroke_linejoin="round" if stroke else None,
                stroke_linecap="round" if stroke else None,
                stroke_dasharray=dash, stroke_opacity=sop)
    return (f'<circle cx="{_f(cx)}" cy="{_f(cy)}" r="{_f(r)}" fill="{fill}"'
            f'{_attrs(fill_opacity=op)}{st}/>')


def ellipse(cx, cy, rx, ry, fill="none", stroke=None, sw=2.0, op=None):
    st = _attrs(stroke=stroke, stroke_width=_f(sw) if stroke else None,
                stroke_linejoin="round" if stroke else None,
                stroke_linecap="round" if stroke else None)
    return (f'<ellipse cx="{_f(cx)}" cy="{_f(cy)}" rx="{_f(rx)}" ry="{_f(ry)}" '
            f'fill="{fill}"{_attrs(fill_opacity=op)}{st}/>')


def line(x1, y1, x2, y2, stroke=MID, sw=2.0, dash=None, op=None):
    return (f'<line x1="{_f(x1)}" y1="{_f(y1)}" x2="{_f(x2)}" y2="{_f(y2)}"'
            f'{_attrs(stroke=stroke, stroke_width=_f(sw), stroke_linecap="round", stroke_dasharray=dash, stroke_opacity=op)}/>')


def poly(points, fill="none", stroke=None, sw=2.0, op=None, close=True):
    d = " ".join(f"{_f(x)},{_f(y)}" for x, y in points)
    tag = "polygon" if close else "polyline"
    st = _attrs(stroke=stroke, stroke_width=_f(sw) if stroke else None,
                stroke_linejoin="round" if stroke else None,
                stroke_linecap="round" if stroke else None)
    return f'<{tag} points="{d}" fill="{fill}"{_attrs(fill_opacity=op)}{st}/>'


def path(d, fill="none", stroke=None, sw=2.0, op=None, dash=None, sop=None, close=False):
    st = _attrs(stroke=stroke, stroke_width=_f(sw) if stroke else None,
                stroke_linejoin="round" if stroke else None,
                stroke_linecap="round" if stroke else None,
                stroke_dasharray=dash, stroke_opacity=sop)
    z = "Z" if close else ""
    return f'<path d="{d}{z}" fill="{fill}"{_attrs(fill_opacity=op)}{st}/>'


def _bitmap(ch, x, y, px, color, op=None):
    rows = FONT_5x7.get(ch, FONT_5x7[" "]).split("|")
    out = []
    for ry, row in enumerate(rows):
        run = 0
        for rx in range(6):
            on = rx < 5 and row[rx] == "#"
            if on:
                run += 1
                continue
            if run:
                out.append(rect(x + (rx - run) * px, y + ry * px, run * px, px, color, op=op))
                run = 0
    return "".join(out)


def bmp_text(text, x, y, px=2, color=INK, op=None, tracking=1):
    """5x7 bitmap lettering, drawn as rects so Godot keeps it. Returns (svg, width)."""
    out = []
    cx = x
    for ch in text.upper():
        out.append(_bitmap(ch, cx, y, px, color, op))
        cx += (5 + tracking) * px
    return "".join(out), cx - x


def bmp_width(text, px=2, tracking=1):
    return len(text) * (5 + tracking) * px - tracking * px


def diag_hatch(x, y, w, h, step=9.0, color=MID, sw=1.0, op=0.45, rising=True):
    """45 degree lines clipped exactly to a box. rising=True draws '/', else '\\'."""
    out = []
    if rising:
        c = math.floor((x - (y + h)) / step) * step
        while c <= x + w:
            x0 = max(x, y + c)
            x1 = min(x + w, y + h + c)
            if x1 > x0:
                out.append(line(x0, x0 - c, x1, x1 - c, color, sw, op=op))
            c += step
    else:
        c = math.floor((x + y) / step) * step
        while c <= x + y + w + h:
            x0 = max(x, c - (y + h))
            x1 = min(x + w, c - y)
            if x1 > x0:
                out.append(line(x0, c - x0, x1, c - x1, color, sw, op=op))
            c += step
    return "".join(out)


def halftone(x, y, w, h, step=7.0, r=1.1, color=MID, op=0.22, seed=1):
    out = []
    row = 0
    yy = y
    while yy <= y + h:
        xx = x + (step * 0.5 if row % 2 else 0.0)
        while xx <= x + w:
            out.append(circle(xx, yy, r, color, op=op))
            xx += step
        yy += step * 0.9
        row += 1
    return "".join(out)


def grain(x, y, w, h, n=14, seed=1, color=MID, op=0.22, rmax=1.0):
    rng = random.Random(seed)
    out = []
    for _ in range(n):
        px = x + rng.uniform(0, w)
        py = y + rng.uniform(0, h)
        out.append(circle(px, py, rng.uniform(0.5, rmax), color, op=op))
    return "".join(out)


def corner_hatch(x, y, w, h, size=18, step=5, color=MID, op=0.25, sw=0.8):
    """Short cross-hatch in the underside / corner of an object."""
    out = []
    for k in range(0, size, step):
        out.append(line(x + w - size + k, y + h, x + w, y + h - size + k, color, sw, op=op))
    return "".join(out)


def shadow_rect(x, y, w, h, dx=3, dy=4, rx=0, op=0.16):
    return rect(x + dx, y + dy, w, h, DARK, rx=rx, op=op)


def shadow_ellipse(cx, cy, rx, ry, dx=3, dy=4, op=0.16):
    return ellipse(cx + dx, cy + dy, rx, ry, DARK, op=op)


# ------------------------------------------------------------------ tiles
def floor_plain():
    b = [rect(0, 0, 80, 80, FLOOR),
         grain(0, 0, 80, 80, 12, 4, MID, 0.16, 0.8)]
    return svg(80, 80, "".join(b))


def floor_plank():
    """Wide boards: two per metre, staggered joints. Quiet base, grain subordinate."""
    b = [rect(0, 0, 80, 80, FLOOR)]
    for row in range(2):
        y = row * 40
        b.append(rect(0, y, 80, 40, FLOOR))
        b.append(line(0, y + 0.5, 80, y + 0.5, MID, 1.0, op=0.34))
        joint = (26 + row * 41) % 80
        b.append(line(joint, y + 2, joint, y + 38, MID, 1.0, op=0.26))
        for k in range(2):
            gy = y + 12 + k * 15
            b.append(path(f"M4,{gy} Q22,{gy - 1.5} 40,{gy} T76,{gy - 1}",
                          stroke=MID, sw=0.7, op=0.14))
    return svg(80, 80, "".join(b))


def floor_tile():
    b = [rect(0, 0, 80, 80, FLOOR)]
    for gy in range(2):
        for gx in range(2):
            fill = FLOOR if (gx + gy) % 2 == 0 else "#C9C9C4"
            b.append(rect(gx * 40, gy * 40, 40, 40, fill))
            b.append(grain(gx * 40 + 2, gy * 40 + 2, 36, 36, 6, gx * 7 + gy * 13 + 2, MID, 0.14, 0.7))
    for g in range(3):
        b.append(line(g * 40, 0, g * 40, 80, "#9E9E99", 1.4, op=0.7))
        b.append(line(0, g * 40, 80, g * 40, "#9E9E99", 1.4, op=0.7))
    return svg(80, 80, "".join(b))


def floor_lino():
    b = [rect(0, 0, 80, 80, "#D8D8D3")]
    for g in (0, 40):
        b.append(line(g, 0, g, 80, MID, 0.8, op=0.18))
        b.append(line(0, g, 80, g, MID, 0.8, op=0.18))
    b.append(grain(0, 0, 80, 80, 26, 9, MID, 0.12, 0.7))
    return svg(80, 80, "".join(b))


def floor_carpet():
    b = [rect(0, 0, 80, 80, "#DCDCD7"),
         halftone(0, 0, 80, 80, 5.0, 0.7, MID, 0.13),
         grain(0, 0, 80, 80, 30, 12, MID, 0.1, 1.2)]
    return svg(80, 80, "".join(b))


def floor_deck():
    b = [rect(0, 0, 80, 80, PAPER)]
    for g in range(5):
        x = g * 16
        b.append(rect(x, 0, 16, 80, "#E6E6E1"))
        b.append(line(x + 0.5, 0, x + 0.5, 80, "#9E9E99", 1.0, op=0.55))
        b.append(circle(x + 8, 10, 1.0, MID, op=0.5))
        b.append(circle(x + 8, 70, 1.0, MID, op=0.5))
    b.append(grain(0, 0, 80, 80, 12, 21, MID, 0.15, 0.8))
    return svg(80, 80, "".join(b))


def floor_yard():
    """Exterior ground: paper, sparse deterministic tufts and a gravel tick."""
    b = [rect(0, 0, 80, 80, "#E4E4DE")]
    rng = random.Random(77)
    for _ in range(26):
        x, y = rng.uniform(4, 76), rng.uniform(4, 76)
        a = rng.uniform(0, math.tau)
        d = rng.uniform(1.6, 3.0)
        b.append(line(x, y, x + math.cos(a) * d, y + math.sin(a) * d, MID, 0.9, op=0.28))
    for _ in range(10):
        b.append(circle(rng.uniform(0, 80), rng.uniform(0, 80), rng.uniform(0.5, 1.0), MID, op=0.22))
    return svg(80, 80, "".join(b))


def floor_studs():
    """Stud walls drawn as a plan notation (for theory sheets / cutaways)."""
    b = [rect(0, 0, 80, 80, FLOOR)]
    for k in range(0, 81, 10):
        b.append(line(k, 0, k, 80, MID, 1.0, op=0.22))
    return svg(80, 80, "".join(b))


def print_grain():
    """Layer 4: the optional neutral print pass that sits behind UI, never under
    walkable floor plan marks. Tileable, deterministic, low contrast."""
    b = [rect(0, 0, 80, 80, WHITE, op=0.0)]
    rng = random.Random(19)
    for _ in range(44):
        b.append(circle(rng.uniform(0, 80), rng.uniform(0, 80), rng.uniform(0.6, 1.4),
                        MID, op=round(rng.uniform(0.06, 0.16), 2)))
    return svg(80, 80, "".join(b))


def wall_straight():
    """1 m of wall, horizontal, 0.2 m thick: poche ink with a lit top edge."""
    b = [shadow_rect(0, 4, 80, 12, 0, 4, 0, 0.16),
         rect(0, 4, 80, 12, INK),
         rect(0, 4, 80, 1.4, "#4A4A4A"),
         grain(0, 5, 80, 10, 8, 31, "#5C5C5C", 0.4, 0.7)]
    return svg(80, 20, "".join(b))


def wall_window():
    """Glazing inside a solid wall: the wall keeps its poche on one face, the
    glass sits in the middle with the sill and head lines drawn."""
    b = [shadow_rect(0, 4, 80, 12, 0, 4, 0, 0.16),
         rect(0, 4, 80, 12, INK),
         rect(0, 6.5, 80, 7, LIGHT),
         line(0, 6.5, 80, 6.5, INK, 1.4),
         line(0, 13.5, 80, 13.5, INK, 1.4),
         line(0, 10, 80, 10, MID, 1.0, op=0.8),
         line(26, 6.5, 26, 13.5, MID, 1.0),
         line(54, 6.5, 54, 13.5, MID, 1.0),
         rect(0, 4, 4, 12, INK), rect(76, 4, 4, 12, INK)]
    return svg(80, 20, "".join(b))


def wall_doorway():
    """Door opening with the leaf and its swing: theory notation."""
    b = [rect(0, 4, 10, 12, INK),
         rect(70, 4, 10, 12, INK),
         rect(10, 4, 60, 12, FLOOR, op=0.9),
         line(10, 4, 10, 16, INK, 1.2),
         line(70, 4, 70, 16, INK, 1.2),
         path("M12,8 A44,44 0 0 1 52,16", stroke=MID, sw=1.2, dash="4 4", op=0.75),
         line(12, 8, 12.5, 16, INK, 2.4),
         line(12, 8, 52, 11, MID, 1.0, op=0.5)]
    return svg(80, 80, "".join(b))


def wall_half():
    """Low wall / waist-high cover: Mid fill plus hatch (the project's cover cue)."""
    b = [shadow_rect(0, 6, 80, 8, 0, 3, 0, 0.12),
         rect(0, 6, 80, 8, MID),
         diag_hatch(0, 6, 80, 8, 7, DARK, 0.9, 0.45, False),
         line(0, 6, 80, 6, INK, 1.2, op=0.8),
         line(0, 13, 80, 13, INK, 1.2, op=0.8)]
    return svg(80, 20, "".join(b))


def wall_corner():
    b = [shadow_rect(2, 2, 18, 18, 3, 4, 0, 0.16),
         rect(2, 2, 18, 18, INK)]
    return svg(22, 22, "".join(b))


def fence():
    b = [line(0, 4, 80, 4, MID, 1.6),
         line(0, 12, 80, 12, MID, 1.6),
         rect(6, 2, 4, 14, DARK, rx=0),
         rect(40, 2, 4, 14, DARK, rx=0),
         rect(74, 2, 4, 14, DARK, rx=0)]
    return svg(80, 20, "".join(b))


def stairs():
    b = [rect(0, 0, 80, 80, FLOOR),
         rect(6, 4, 68, 72, LIGHT, INK, 1.6)]
    for k in range(6):
        b.append(line(6, 10 + k * 11, 74, 10 + k * 11, INK, 1.0))
    b.append(path("M40,66 L40,26", stroke=INK, sw=1.8))
    b.append(poly([(40, 18), (34, 30), (46, 30)], INK))
    b.append(path("M40,70 L40,74", stroke=INK, sw=1.8))
    return svg(80, 80, "".join(b))


def wall_stack():
    """0.25 m wall strip: full width, opaque, so butted wall tiles never overlap."""
    b = [shadow_rect(0, 4, 80, 12, 0, 4, 0, 0.16),
         rect(0, 4, 80, 12, INK)]
    return svg(80, 20, "".join(b))


def breach():
    """Application state of a doorway: the leaf is off its hinges and lying on the
    floor, frame splintered, scuffs where the ram met the wall."""
    b = [rect(0, 4, 9, 12, INK),
         rect(71, 4, 9, 12, INK),
         rect(9, 4, 62, 12, FLOOR),
         path("M9,4 L9,16 M71,4 L71,16", stroke=INK, sw=1.2, op=0.9),
         # the leaf: a pale slab with a Mid outline, angled
         poly([(26, 52), (70, 40), (72, 47), (28, 59)], LIGHT, MID, 1.2),
         line(30, 53, 68, 42, MID, 0.8, op=0.5),
         circle(67, 44, 1.6, MID),
         # splinters and scuffs
         path("M14,17 L22,26 L17,31 M62,18 L56,27 L63,32", stroke=INK, sw=1.1, op=0.75),
         line(10, 20, 20, 30, MID, 0.9, op=0.4),
         circle(24, 36, 1.1, MID, op=0.45),
         circle(58, 40, 0.9, MID, op=0.4)]
    return svg(80, 80, "".join(b))


# ------------------------------------------------------------------ props
def prop_desk():
    b = [shadow_rect(4, 6, 104, 44, 3, 5, 2, 0.16),
         rect(4, 6, 104, 44, LIGHT, INK, 2.0, rx=2),
         rect(4, 6, 104, 6, "#ADADA8", INK, 1.0, rx=2),
         rect(16, 16, 34, 24, PAPER, MID, 1.0),
         line(20, 22, 44, 22, MID, 0.9, op=0.55),
         line(20, 27, 46, 27, MID, 0.9, op=0.55),
         line(20, 32, 38, 32, MID, 0.9, op=0.55),
         rect(58, 12, 24, 18, DARK, INK, 1.4, rx=1),
         rect(61, 15, 18, 12, "#4A4A4A"),
         rect(84, 36, 18, 10, "#ADADA8", MID, 1.0, rx=1),
         line(88, 41, 98, 41, MID, 1.2),
         corner_hatch(4, 6, 104, 44, 16, 5, INK, 0.18, 0.8)]
    return svg(112, 56, "".join(b))


def prop_chair():
    b = [shadow_rect(4, 6, 34, 34, 2, 3, 8, 0.16),
         rect(4, 6, 34, 34, LIGHT, INK, 1.8, rx=8),
         rect(10, 26, 22, 6, "#ADADA8", MID, 1.0, rx=2),
         line(21, 8, 21, 12, MID, 1.2)]
    return svg(44, 44, "".join(b))


def prop_table():
    b = [shadow_rect(4, 8, 120, 56, 3, 5, 3, 0.16),
         rect(4, 8, 120, 56, LIGHT, INK, 2.0, rx=3),
         rect(12, 16, 104, 40, "none", MID, 1.0),
         rect(14, 14, 10, 10, DARK),
         rect(104, 48, 10, 10, DARK),
         path("M28,54 Q46,44 62,52", stroke=MID, sw=0.9, op=0.3),
         corner_hatch(4, 8, 120, 56, 20, 6, INK, 0.14, 0.8)]
    return svg(128, 72, "".join(b))


def prop_bed():
    b = [shadow_rect(4, 6, 152, 60, 3, 5, 2, 0.16),
         rect(4, 6, 152, 60, LIGHT, INK, 2.0, rx=2),
         rect(10, 10, 140, 52, PAPER, MID, 1.2),
         rect(12, 12, 26, 48, "#DCDCD7", MID, 1.0, rx=4),
         line(42, 12, 42, 60, MID, 1.0, op=0.5),
         path("M52,14 L146,14 L146,58 L52,58", fill="none", stroke=MID, sw=1.0, dash="5 4", op=0.55),
         corner_hatch(4, 6, 152, 60, 18, 6, INK, 0.14, 0.8)]
    return svg(160, 72, "".join(b))


def prop_bunk():
    b = [shadow_rect(4, 6, 152, 60, 3, 5, 2, 0.16),
         rect(10, 12, 140, 48, "#ADADA8", INK, 1.4),
         rect(4, 6, 140, 48, LIGHT, INK, 2.0),
         rect(10, 10, 128, 40, PAPER, MID, 1.0),
         rect(12, 12, 22, 36, "#DCDCD7", MID, 1.0, rx=3),
         line(38, 12, 38, 48, MID, 1.0, op=0.5),
         line(42, 28, 136, 28, MID, 0.9, dash="3 3", op=0.5)]
    return svg(160, 72, "".join(b))


def prop_sofa():
    b = [shadow_rect(4, 6, 152, 56, 3, 5, 6, 0.16),
         rect(4, 6, 152, 56, LIGHT, INK, 2.0, rx=6),
         rect(4, 6, 152, 14, "#ADADA8", INK, 1.2, rx=6),
         rect(4, 6, 20, 56, "#ADADA8", INK, 1.2, rx=6),
         rect(136, 6, 20, 56, "#ADADA8", INK, 1.2, rx=6)]
    for i in range(3):
        b.append(rect(26 + i * 36, 22, 32, 36, PAPER, MID, 1.0, rx=3))
    return svg(160, 68, "".join(b))


def prop_cabinet():
    b = [shadow_rect(4, 6, 64, 34, 2, 3, 1, 0.16),
         rect(4, 6, 64, 34, LIGHT, INK, 1.8, rx=1),
         line(36, 6, 36, 40, INK, 1.2),
         rect(28, 20, 4, 8, INK),
         rect(44, 20, 4, 8, INK)]
    return svg(72, 44, "".join(b))


def prop_lockers():
    b = [shadow_rect(4, 6, 88, 32, 2, 3, 1, 0.16),
         rect(4, 6, 88, 32, LIGHT, INK, 1.8, rx=1)]
    for i in range(3):
        x = 4 + i * 29.3
        b.append(line(x + 29.3, 6, x + 29.3, 38, INK, 1.2))
        for k in range(3):
            b.append(line(x + 8, 12 + k * 3, x + 22, 12 + k * 3, MID, 0.9, op=0.7))
        b.append(rect(x + 24, 22, 2.4, 6, INK))
    return svg(96, 44, "".join(b))


def prop_shelving():
    b = [shadow_rect(4, 6, 136, 30, 2, 3, 1, 0.16),
         rect(4, 6, 136, 30, LIGHT, INK, 1.8, rx=1)]
    for i in range(1, 5):
        b.append(line(4 + i * 27.2, 6, 4 + i * 27.2, 36, MID, 1.0, op=0.65))
    b.append(rect(12, 14, 22, 14, PAPER, MID, 0.9))
    b.append(rect(48, 10, 18, 18, "#ADADA8", MID, 0.9))
    b.append(rect(88, 16, 26, 12, PAPER, MID, 0.9))
    b.append(diag_hatch(4, 6, 136, 30, 10, INK, 0.7, 0.16, True))
    return svg(144, 40, "".join(b))


def prop_fridge():
    b = [shadow_rect(4, 6, 48, 44, 2, 3, 2, 0.16),
         rect(4, 6, 48, 44, LIGHT, INK, 1.8, rx=2),
         line(4, 18, 52, 18, INK, 1.2),
         rect(44, 22, 3, 10, INK),
         rect(10, 10, 20, 4, "#ADADA8", MID, 0.8)]
    return svg(56, 56, "".join(b))


def prop_counter():
    b = [shadow_rect(4, 6, 136, 38, 3, 4, 1, 0.16),
         rect(4, 6, 136, 38, LIGHT, INK, 1.8, rx=1),
         rect(12, 10, 34, 30, PAPER, MID, 1.0),
         circle(29, 25, 4, "none", MID, 1.2),
         rect(58, 12, 24, 22, "#ADADA8", MID, 1.0),
         rect(66, 16, 8, 14, MID, INK, 0.8),
         rect(96, 14, 32, 22, "#ADADA8", MID, 1.0),
         line(96, 24, 128, 24, MID, 0.9, op=0.6),
         corner_hatch(4, 6, 136, 38, 16, 5, INK, 0.14, 0.8)]
    return svg(144, 48, "".join(b))


def prop_crate():
    b = [shadow_rect(4, 4, 40, 40, 2, 3, 1, 0.16),
         rect(4, 4, 40, 40, LIGHT, INK, 1.8, rx=1),
         diag_hatch(4, 4, 40, 40, 9, MID, 0.9, 0.35, True),
         diag_hatch(4, 4, 40, 40, 9, MID, 0.9, 0.35, False)]
    return svg(48, 48, "".join(b))


def prop_pallet():
    b = [shadow_rect(4, 4, 88, 72, 2, 3, 0, 0.14),
         rect(4, 4, 88, 72, "#DCDCD7", MID, 1.0)]
    for i in range(5):
        b.append(rect(4, 8 + i * 14, 88, 8, LIGHT, MID, 0.9))
    b.append(rect(4, 4, 88, 72, "none", MID, 1.2))
    return svg(96, 80, "".join(b))


def prop_dumpster():
    b = [shadow_rect(4, 6, 152, 84, 4, 6, 3, 0.18),
         rect(4, 6, 152, 84, DARK, INK, 2.0, rx=3),
         rect(10, 12, 140, 72, "#3A3A3A", MID, 1.2),
         line(80, 14, 80, 82, INK, 1.4),
         diag_hatch(10, 12, 140, 72, 12, "#6A6A6A", 0.8, 0.3, True),
         rect(16, 86, 10, 6, MID), rect(134, 86, 10, 6, MID)]
    return svg(160, 96, "".join(b))


def prop_car(police=False):
    b = [ellipse(176, 82, 168, 66, DARK, op=0.14)]
    if police:
        b += [rect(4, 4, 344, 144, PAPER, INK, 2.2, rx=34),
              rect(104, 6, 140, 140, DARK, rx=6),
              rect(114, 14, 120, 124, "#DCDCD7", MID, 1.4, rx=12),
              rect(160, 12, 12, 128, INK),
              rect(180, 62, 56, 28, WHITE, INK, 1.4, rx=3),
              line(188, 70, 228, 70, MID, 1.0),
              line(188, 78, 220, 78, MID, 1.0),
              rect(250, 18, 46, 116, "none", MID, 1.2, rx=8),
              rect(60, 0, 30, 6, MID), rect(252, 0, 30, 6, MID),
              rect(60, 146, 30, 6, MID), rect(252, 146, 30, 6, MID)]
    else:
        b += [rect(4, 4, 344, 144, PAPER, INK, 2.2, rx=30),
              rect(96, 8, 132, 136, "#DCDCD7", MID, 1.4, rx=14),
              rect(160, 10, 8, 132, MID, op=0.6),
              rect(246, 14, 44, 124, "none", MID, 1.2, rx=8),
              rect(58, 0, 28, 6, MID), rect(246, 0, 28, 6, MID),
              rect(58, 146, 28, 6, MID), rect(246, 146, 28, 6, MID)]
    return svg(352, 152, "".join(b))


def prop_ac():
    b = [shadow_rect(4, 4, 72, 72, 3, 4, 2, 0.16),
         rect(4, 4, 72, 72, LIGHT, INK, 1.8, rx=2),
         circle(40, 40, 26, PAPER, INK, 1.4),
         circle(40, 40, 5, INK),
         circle(40, 40, 20, "none", MID, 0.9)]
    for a in range(0, 360, 45):
        r = math.radians(a)
        b.append(line(40 + math.cos(r) * 8, 40 + math.sin(r) * 8,
                      40 + math.cos(r) * 19, 40 + math.sin(r) * 19, MID, 1.0))
    b.append(rect(10, 10, 6, 6, INK))
    b.append(rect(64, 64, 6, 6, INK))
    return svg(80, 80, "".join(b))


def prop_tree():
    b = [ellipse(62, 64, 50, 46, DARK, op=0.12)]
    pts = []
    for i in range(16):
        a = i / 16 * math.tau
        rr = 46 + (7 if i % 2 else -5) + (3 if i % 3 == 0 else 0)
        pts.append((62 + math.cos(a) * rr, 62 + math.sin(a) * rr))
    b.append(poly(pts, "#DCDCD7", MID, 1.4))
    for k in range(3):
        pts2 = []
        for i in range(14):
            a = i / 14 * math.tau
            rr = (40 - k * 11) + (4 if i % 2 else -3)
            pts2.append((62 + math.cos(a + k) * rr, 62 + math.sin(a + k) * rr))
        b.append(poly(pts2, "none", MID, 0.9, close=True))
    b.append(rect(56, 56, 12, 12, INK, rx=1))
    return svg(124, 124, "".join(b))


def prop_planter():
    b = [shadow_rect(4, 6, 72, 28, 2, 3, 2, 0.14),
         rect(4, 6, 72, 28, LIGHT, INK, 1.4, rx=2),
         rect(10, 10, 60, 20, "#9E9E99", MID, 1.0)]
    for k in range(5):
        b.append(line(14 + k * 13, 22, 18 + k * 13, 14, MID, 1.0, op=0.6))
    return svg(80, 40, "".join(b))


def prop_rack():
    b = [shadow_rect(4, 6, 112, 32, 2, 3, 1, 0.16),
         rect(4, 6, 112, 32, LIGHT, INK, 1.6, rx=1),
         line(4, 22, 116, 22, MID, 1.0)]
    for i in range(4):
        x = 12 + i * 26
        b.append(rect(x, 11, 22, 5, DARK, rx=1))
        b.append(rect(x + 4, 9, 8, 3, MID))
        b.append(line(x + 2, 16, x + 20, 16, INK, 1.2))
    return svg(120, 40, "".join(b))


def prop_basin():
    b = [shadow_rect(4, 6, 56, 32, 2, 3, 2, 0.14),
         rect(4, 6, 56, 32, PAPER, INK, 1.4, rx=2),
         rect(12, 12, 40, 20, "none", MID, 1.4, rx=6),
         circle(32, 22, 2.4, MID),
         rect(28, 4, 8, 6, MID)]
    return svg(64, 44, "".join(b))


def prop_toilet():
    b = [shadow_rect(4, 4, 40, 52, 2, 3, 3, 0.14),
         rect(12, 4, 24, 12, LIGHT, INK, 1.2, rx=2),
         ellipse(24, 34, 16, 20, PAPER, INK, 1.4)]
    return svg(48, 60, "".join(b))


def prop_stove():
    b = [shadow_rect(4, 4, 48, 48, 2, 3, 1, 0.16),
         rect(4, 4, 48, 48, LIGHT, INK, 1.6)]
    for (dx, dy) in ((0, 0), (24, 0), (0, 24), (24, 24)):
        b.append(circle(16 + dx, 16 + dy, 8, "none", MID, 1.2))
    return svg(56, 56, "".join(b))


def prop_sink():
    b = [shadow_rect(4, 6, 72, 34, 2, 3, 2, 0.14),
         rect(4, 6, 72, 34, LIGHT, INK, 1.6, rx=1),
         rect(10, 12, 36, 22, PAPER, MID, 1.2),
         circle(28, 23, 3, MID),
         rect(48, 16, 22, 14, "#ADADA8", MID, 0.9)]
    return svg(80, 46, "".join(b))


def prop_washer():
    b = [shadow_rect(4, 4, 48, 48, 2, 3, 1, 0.16),
         rect(4, 4, 48, 48, LIGHT, INK, 1.6, rx=2),
         circle(28, 28, 16, PAPER, MID, 1.2),
         circle(28, 28, 5, "none", MID, 1.0),
         rect(10, 8, 12, 4, MID)]
    return svg(56, 56, "".join(b))


def prop_dresser():
    b = [shadow_rect(4, 6, 56, 32, 2, 3, 1, 0.16),
         rect(4, 6, 56, 32, LIGHT, INK, 1.6, rx=1),
         line(4, 22, 60, 22, MID, 1.0),
         rect(26, 14, 12, 3, MID),
         rect(26, 27, 12, 3, MID)]
    return svg(64, 44, "".join(b))


def prop_wardrobe():
    b = [shadow_rect(4, 4, 40, 80, 2, 3, 1, 0.16),
         rect(4, 4, 40, 80, LIGHT, INK, 1.8, rx=1),
         line(4, 44, 44, 44, INK, 1.2),
         rect(34, 22, 3, 10, INK),
         rect(34, 52, 3, 10, INK)]
    return svg(48, 88, "".join(b))


def prop_stretcher():
    b = [shadow_rect(4, 6, 152, 40, 2, 3, 3, 0.14),
         rect(10, 10, 140, 32, PAPER, INK, 1.4, rx=3),
         line(0, 6, 160, 6, INK, 2.6),
         line(0, 46, 160, 46, INK, 2.6),
         line(20, 10, 20, 42, MID, 1.0, op=0.5),
         line(140, 10, 140, 42, MID, 1.0, op=0.5)]
    return svg(160, 52, "".join(b))
PYEOF_MARKER = True


# ------------------------------------------------------------------ actors
# 0.8 m canvas (64 px), centre = body centre, facing +x. Flat ink silhouettes:
# no faces, no gear detail, no skin tones. Roles differ by silhouette and mark.
def actor_stand(kind):
    """Plan-view figure, facing +x. Boxy torso, short arms, hands at the grip, head
    clear of the shoulders. Roles differ by silhouette and mark only."""
    if kind == "officer":
        body, outline, osw, head = PAPER, INK, 2.4, PAPER
    elif kind == "qrf":
        body, outline, osw, head = LIGHT, INK, 2.6, LIGHT
    elif kind == "medic":
        body, outline, osw, head = PAPER, INK, 2.2, PAPER
    elif kind == "suspect":
        body, outline, osw, head = LIGHT, MID, 2.0, LIGHT
    else:
        body, outline, osw, head = PAPER, MID, 1.8, PAPER
    b = []
    # arms first, so the torso and head sit over the shoulder joints
    armed = kind in ("officer", "qrf", "medic")
    aw = 4.4 if armed else 3.4
    b.append(line(30, 20, 45, 26, outline, aw + 1.2))
    b.append(line(30, 44, 43, 38, outline, aw + 1.2))
    b.append(line(30, 20, 45, 26, body, aw))
    b.append(line(30, 44, 43, 38, body, aw))
    if armed:
        b.append(circle(46, 26, 2.8, body, outline, 1.2))
        b.append(circle(44, 38, 2.8, body, outline, 1.2))
    # torso: a vest block, narrower front to back than across the shoulders
    b.append(rect(10, 14, 26, 36, body, outline, osw, rx=7))
    if kind == "qrf":
        b.append(diag_hatch(13, 17, 20, 30, 6.5, INK, 0.8, 0.42, True))
        b.append(rect(10, 14, 26, 36, "none", outline, osw, rx=7))
    elif kind == "medic":
        b.append(rect(16, 29, 14, 6, INK))
        b.append(rect(20, 23, 6, 18, INK))
    elif kind == "officer":
        b.append(rect(12, 20, 5, 24, LIGHT, INK, 0.8))        # the one pale mark
        b.append(rect(13, 46, 5, 5, "#DCDCD7", INK, 0.6))     # pouch
        b.append(line(20, 32, 31, 32, MID, 0.9, op=0.45))
    elif kind == "suspect":
        b.append(line(20, 32, 31, 32, MID, 0.9, op=0.5))
    # head, in front of the torso with a visible neck gap
    b.append(circle(41, 32, 8.4, head, outline, osw))
    if kind == "officer":
        b.append(path("M41,23.6 A8.4 8.4 0 0 1 41,40.4 L49,37 L49,27 Z",
                      fill=INK, stroke=INK, sw=0.8))
        b.append(line(48, 32, 51, 32, INK, 1.4))
    elif kind == "qrf":
        b.append(circle(41, 32, 10.6, "none", INK, 2.6))
        b.append(line(51, 29, 53, 29, INK, 1.2))
        b.append(line(51, 35, 53, 35, INK, 1.2))
    elif kind == "medic":
        b.append(path("M41,23.6 A8.4 8.4 0 0 1 41,40.4 L48,37 L48,27 Z",
                      fill=PAPER, stroke=INK, sw=1.0))
    elif kind == "suspect":
        b.append(line(48, 32, 51, 32, outline, 1.4))
    if armed:
        b.append(line(46, 27, 58, 31, INK, 1.5))               # weapon line
        b.append(line(44, 37, 52, 34, INK, 1.2))
    return svg(64, 64, "".join(b))


def actor_surrender(kind="suspect"):
    """Kneeling, hands behind the head: folded legs, a shorter footprint than a
    standing figure, and two hands drawn as blocks on the nape (the second cue)."""
    body = LIGHT if kind == "suspect" else PAPER
    outline = MID if kind == "suspect" else INK
    osw = 2.0 if outline == INK else 1.7
    b = []
    # folded legs, tucked under and behind
    b.append(rect(14, 16, 22, 12, body, outline, osw, rx=6))
    b.append(rect(14, 36, 22, 12, body, outline, osw, rx=6))
    # torso, smaller than standing
    b.append(rect(22, 20, 22, 24, body, outline, osw, rx=6))
    # hands clasped on the nape
    b.append(rect(30, 25, 8, 5, INK if kind != "suspect" else MID))
    b.append(rect(30, 34, 8, 5, INK if kind != "suspect" else MID))
    # head tipped forward
    b.append(circle(42, 32, 8.0, body, outline, osw))
    if kind != "suspect":
        b.append(path("M42,24 A8 8 0 0 1 42,40 L49,37 L49,27 Z", fill=PAPER, stroke=INK, sw=0.9))
    b.append(line(49, 32, 52, 32, outline, 1.4))
    return svg(64, 64, "".join(b))


def actor_cuffed(kind="suspect"):
    """Standing, hands behind the back: the arms are gone from the silhouette and
    an ink cuff bar sits across the lower back."""
    body = LIGHT if kind == "suspect" else PAPER
    outline = MID if kind == "suspect" else INK
    osw = 2.0 if outline == INK else 1.7
    b = [line(29, 24, 37, 29, outline, 3.2),
         line(29, 40, 37, 35, outline, 3.2),
         rect(10, 14, 24, 36, body, outline, osw, rx=7),
         rect(18, 29, 10, 6, INK, rx=1),
         line(18, 32, 28, 32, PAPER, 1.0),
         circle(40, 32, 8.2, body, outline, osw),
         line(47, 32, 50, 32, outline, 1.4)]
    if kind != "suspect":
        b.append(path("M40,23.8 A8.2 8.2 0 0 1 40,40.2 L47,37 L47,27 Z",
                      fill=PAPER, stroke=INK, sw=0.9))
    return svg(64, 64, "".join(b))


def actor_down(kind):
    """Lying on their back, long axis +x. 1.9 x 0.9 m (152 x 72 px)."""
    body = PAPER if kind in ("officer", "medic", "civilian") else LIGHT
    outline = INK if kind in ("officer", "qrf", "medic") else MID
    osw = 2.2 if outline == INK else 1.8
    b = []
    for (y0, y1) in ((26, 29), (46, 43)):
        b.append(line(22, y0, 63, y1, outline, 7.4))
        b.append(line(22, y0, 63, y1, body, 4.4))
        b.append(circle(21, y0, 3.4, body, outline, 1.4))
    b.append(rect(58, 16, 54, 40, body, outline, osw, rx=10))
    if kind == "officer":
        b.append(rect(70, 26, 8, 20, LIGHT, INK, 0.9, rx=2))
        b.append(line(84, 26, 84, 46, MID, 0.9, op=0.5))
    elif kind == "qrf":
        b.append(diag_hatch(62, 20, 46, 32, 9, INK, 0.8, 0.35, True))
    elif kind == "medic":
        b.append(rect(76, 30, 18, 6, INK))
        b.append(rect(82, 24, 6, 18, INK))
    b.append(rect(58, 16, 54, 40, "none", outline, osw, rx=10))
    b.append(path("M100,18 Q112,4 96,6", stroke=outline, sw=2.2))
    b.append(path("M100,54 Q120,68 108,70", stroke=outline, sw=2.2))
    b.append(circle(124, 32, 10, body, outline, osw))
    if kind == "officer":
        b.append(path("M127,22 A10 10 0 0 1 127,42 L137,39 L137,25 Z", fill=INK, stroke=INK, sw=0.8))
    elif kind == "qrf":
        b.append(circle(124, 32, 12, "none", INK, 2.4))
    elif kind == "medic":
        b.append(path("M127,22 A10 10 0 0 1 127,42 L137,39 L137,25 Z", fill=PAPER, stroke=INK, sw=0.9))
    return svg(152, 72, "".join(b))


def actor_shadow(pose="stand"):
    if pose == "stand":
        b = [shadow_ellipse(25, 32, 12, 19, 3.0, 3.5, 0.12),
             shadow_ellipse(41, 32, 9.5, 9.5, 3.0, 3.5, 0.10)]
        return svg(64, 64, "".join(b))
    b = [shadow_ellipse(76, 34, 66, 30, 4, 4, 0.10)]
    return svg(152, 72, "".join(b))


def weapon_rifle():
    b = [rect(2, 4.5, 22, 7, "#6B6B6B", INK, 1.4, rx=2),
         rect(22, 3.5, 30, 9, "#4A4A4A", INK, 1.4, rx=2),
         rect(30, 1.5, 10, 5, DARK, INK, 1.0),
         rect(52, 4, 14, 6, "#6B6B6B", INK, 1.2, rx=2),
         line(66, 8, 75, 8, INK, 2.6)]
    return svg(76, 16, "".join(b))


def weapon_pistol():
    b = [rect(10, 4, 20, 8, "#3A3A3A", INK, 1.4, rx=2),
         rect(10, 8, 6, 4, "#3A3A3A", INK, 1.2),
         line(30, 8, 33, 8, INK, 2.0)]
    return svg(34, 14, "".join(b))


# ------------------------------------------------------------------ marks (neutral)
def mark_evidence(n):
    """Folded evidence card, top-down, with a bitmap number: the second cue."""
    b = [shadow_rect(6, 8, 36, 32, 2, 3, 2, 0.14),
         poly([(24, 4), (44, 24), (24, 44), (4, 24)], PAPER, INK, 1.8),
         line(24, 4, 24, 12, MID, 0.9, op=0.5)]
    txt, tw = bmp_text(str(n), 0, 0, 3, INK)
    b.append(f'<g transform="translate({_f(24 - tw / 2)},{_f(24 - 10.5)})">{txt}</g>')
    return svg(48, 48, "".join(b))


def mark_paper(seed=1, torn=True):
    rng = random.Random(seed)
    pts = [(6, 6), (44, 5), (45, 52)]
    if torn:
        pts += [(34 + rng.uniform(-3, 3), 56), (20, 53), (6, 55)]
    else:
        pts += [(44, 56), (6, 56)]
    b = [shadow_rect(6, 6, 38, 50, 2, 2, 1, 0.10),
         poly(pts, PAPER, "#9E9E99", 1.0)]
    for k in range(5):
        y = 16 + k * 7
        b.append(line(12, y, 12 + rng.uniform(16, 28), y, MID, 0.8, op=0.5))
    b.append(line(12, 46, 26, 46, MID, 0.8, op=0.35))
    return svg(52, 62, "".join(b))


def mark_form():
    b = [shadow_rect(4, 4, 56, 80, 2, 3, 1, 0.12),
         rect(4, 4, 56, 80, PAPER, "#9E9E99", 1.2),
         rect(10, 10, 44, 12, "none", MID, 1.0),
         line(10, 16, 54, 16, MID, 0.8, op=0.4)]
    txt, tw = bmp_text("PD 12", 0, 0, 1, INK)
    b.append(f'<g transform="translate(13,12)">{txt}</g>')
    for k in range(7):
        y = 30 + k * 7
        b.append(line(10, y, 54, y, MID, 0.9, op=0.45))
    b.append(rect(10, 74, 6, 6, "none", MID, 0.9))
    b.append(rect(28, 74, 6, 6, "none", MID, 0.9))
    return svg(64, 88, "".join(b))


def mark_casing():
    b = [rect(2, 2, 7, 4, LIGHT, INK, 0.8, rx=1),
         line(3, 4, 7, 4, MID, 0.6, op=0.6)]
    return svg(11, 8, "".join(b))


def mark_scuff(seed=1):
    b = [path("M4,20 Q18,10 34,16 T58,10", stroke=MID, sw=1.0, op=0.35),
         path("M8,26 Q24,18 40,24", stroke=MID, sw=0.8, op=0.25)]
    rng = random.Random(seed)
    for _ in range(6):
        x = rng.uniform(6, 58)
        y = rng.uniform(8, 26)
        b.append(line(x, y, x + rng.uniform(2, 5), y + rng.uniform(-2, 2), MID, 0.7, op=0.3))
    return svg(64, 32, "".join(b))


def mark_glass(seed=2):
    rng = random.Random(seed)
    b = []
    for _ in range(7):
        x, y = rng.uniform(6, 38), rng.uniform(6, 38)
        s = rng.uniform(3, 8)
        b.append(poly([(x, y), (x + s, y + rng.uniform(-2, 2)), (x + rng.uniform(0, s), y + s)],
                      "none", MID, 0.8))
    return svg(48, 48, "".join(b))


def mark_tag():
    b = [line(11, 3, 11, 10, MID, 0.9),
         rect(4, 10, 14, 18, PAPER, "#9E9E99", 1.0, rx=1),
         line(7, 15, 15, 15, MID, 0.8, op=0.6),
         line(7, 19, 15, 19, MID, 0.8, op=0.6),
         line(7, 23, 12, 23, MID, 0.8, op=0.6)]
    return svg(22, 32, "".join(b))


def mark_stretcher():
    return prop_stretcher()


# ------------------------------------------------------------------ masks (white only)
def mask_blob(cx, cy, r, seed, lobes=9, jitter=0.32):
    rng = random.Random(seed)
    pts = []
    n = lobes * 2
    for i in range(n):
        a = i / n * math.tau
        rr = r * (1 + rng.uniform(-jitter, jitter) * (0.65 if i % 2 else 1.0))
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    return pts


def blood_pool(seed=5, size=128):
    """One hard-edged irregular pool: outer polygon ~0.68 alpha, inner ~0.90 at
    ~0.58 scale, a few dry rim flecks. Reads first as a spilled printing plate."""
    c = size / 2
    r = size * 0.42
    b = [poly(mask_blob(c, c, r, seed, 12, 0.24), WHITE, op=0.68),
         poly(mask_blob(c + 3, c - 2, r * 0.58, seed + 1, 10, 0.28), WHITE, op=0.90)]
    rng = random.Random(seed + 7)
    for _ in range(14):
        a = rng.uniform(0, math.tau)
        rad = r * rng.uniform(0.86, 1.24)
        b.append(circle(c + math.cos(a) * rad, c + math.sin(a) * rad,
                        rng.uniform(0.8, 3.0), WHITE, op=round(rng.uniform(0.22, 0.5), 2)))
    # a couple of drying streaks pulling out of the pool
    for k in range(3):
        a = rng.uniform(0, math.tau)
        x0 = c + math.cos(a) * r * 0.8
        y0 = c + math.sin(a) * r * 0.8
        x1 = c + math.cos(a) * r * 1.3
        y1 = c + math.sin(a) * r * 1.3
        b.append(line(x0, y0, x1, y1, WHITE, rng.uniform(2.0, 4.5), op=0.28))
    return svg(size, size, "".join(b))


def blood_trail():
    """A broken drag trail: width 26 -> 12 px, alpha 0.46 -> 0.20, with gaps."""
    w, h = 320, 64
    b = []
    segs = [(0, 34, 96, 27, 0.46), (104, 26, 190, 21, 0.36), (198, 20, 264, 15, 0.28),
            (270, 14, 316, 10, 0.20)]
    for (x0, w0, x1, w1, op) in segs:
        b.append(poly([(x0, 32 - w0 / 2), (x1, 32 - w1 / 2 - 3), (x1, 32 + w1 / 2 - 3),
                       (x0, 32 + w0 / 2)], WHITE, op=op))
        b.append(circle(x0 + 2, 32 + w0 * 0.18, w0 * 0.22, WHITE, op=op))
        b.append(circle(x1 - 2, 32 - 2, w1 * 0.30, WHITE, op=op))
    rng = random.Random(41)
    for _ in range(16):
        x = rng.uniform(6, 314)
        y = 32 + rng.uniform(-16, 18)
        b.append(circle(x, y, rng.uniform(1.0, 2.6), WHITE, op=round(rng.uniform(0.18, 0.42), 2)))
    return svg(w, h, "".join(b))


def blood_smear():
    """Contact smear at a door frame: a short arc of drag, not a spray."""
    b = [path("M8,44 Q30,10 88,8", stroke=WHITE, sw=13, op=0.34, sop=0.34),
         path("M20,46 Q40,20 84,18", stroke=WHITE, sw=6, op=0.46, sop=0.46),
         circle(88, 8, 4.4, WHITE, op=0.5),
         circle(12, 46, 3.4, WHITE, op=0.35)]
    return svg(96, 56, "".join(b))


def blood_flecks(seed=3):
    rng = random.Random(seed)
    b = []
    for _ in range(9):
        b.append(circle(rng.uniform(8, 56), rng.uniform(8, 56), rng.uniform(1.0, 3.0),
                        WHITE, op=round(rng.uniform(0.22, 0.46), 2)))
    return svg(64, 64, "".join(b))


def spill_wash():
    """Broad translucent wash: 12 concentric discs, alpha 0.008-0.05 (prototype
    stand-in for a painted radial texture)."""
    c = 80
    b = []
    for k in range(12):
        r = 72 - k * 5.4
        b.append(circle(c, c, r, WHITE, op=round(0.008 + 0.0035 * k, 3)))
    return svg(160, 160, "".join(b))


def mask_ring(n):
    """Numbered route ring: white ring plus a bitmap digit knocked out of the
    band with a second, offset white tick so it reads without red."""
    b = [circle(36, 36, 22, "none", WHITE, 5.0, sop=0.75)]
    txt, tw = bmp_text(str(n), 0, 0, 3, WHITE)
    b.append(f'<g transform="translate({_f(36 - tw / 2)},{_f(36 - 10.5)})">{txt}</g>')
    return svg(72, 72, "".join(b))


def mask_route_arrow():
    b = [poly([(4, 12), (44, 12), (44, 4), (68, 18), (44, 32), (44, 24), (4, 24)], WHITE, op=0.85),
         line(4, 18, 4, 18, WHITE, 3, op=0.85)]
    return svg(72, 40, "".join(b))


def mask_beacon():
    """Alarm ticks: eight dashes around a room corner, plus corner bracket."""
    b = [path("M8,8 L8,40 M8,8 L40,8", stroke=WHITE, sw=3.0, sop=0.8)]
    for a in range(0, 360, 45):
        r = math.radians(a)
        b.append(line(52 + math.cos(r) * 12, 52 + math.sin(r) * 12,
                      52 + math.cos(r) * 20, 52 + math.sin(r) * 20, WHITE, 3.0, op=0.7))
    return svg(80, 80, "".join(b))


def mask_stamp(text):
    txt, tw = bmp_text(text, 0, 0, 2, WHITE)
    b = [rect(2, 2, tw + 12, 22, "none", WHITE, 2.0, op=0.8, sop=0.8)]
    b.append(f'<g transform="translate(8,7)">{txt}</g>')
    return svg(tw + 16, 26, "".join(b))


# ------------------------------------------------------------------ ui (neutral)
def ui_north():
    b = [circle(36, 68, 32, "none", INK, 1.6),
         path("M36,6 L48,68 L36,58 Z", fill=INK, stroke=INK, sw=1.2),
         path("M36,6 L24,68 L36,58 Z", fill=PAPER, stroke=INK, sw=1.2)]
    txt, tw = bmp_text("N", 0, 0, 2, INK)
    b.append(f'<g transform="translate({_f(36 - tw / 2)},{_f(80)})">{txt}</g>')
    return svg(72, 104, "".join(b))


def ui_scale():
    b = []
    for k in range(6):
        b.append(rect(4 + k * 24, 4, 24, 10, INK if k % 2 == 0 else WHITE, INK, 1.0))
    for k, lab in ((0, "0"), (2, "1"), (4, "2")):
        txt, tw = bmp_text(lab, 0, 0, 1, INK)
        b.append(f'<g transform="translate({_f(4 + k * 24 + 12 - tw / 2)},18)">{txt}</g>')
    txt, tw = bmp_text("M", 0, 0, 1, MID)
    b.append(f'<g transform="translate(152,18)">{txt}</g>')
    return svg(170, 30, "".join(b))


def ui_stamp_theory():
    txt, tw = bmp_text("MODEL: COMPLETE", 0, 0, 2, INK)
    b = [rect(1, 1, tw + 14, 24, "none", INK, 1.6),
         f'<g transform="translate(8,7)">{txt}</g>']
    return svg(tw + 18, 26, "".join(b))


def ui_stamp_application():
    txt, tw = bmp_text("ACTUAL: 04:12", 0, 0, 2, INK)
    b = [rect(1, 1, tw + 14, 24, "none", INK, 1.6),
         rect(1, 1, 5, 24, INK),
         f'<g transform="translate(12,7)">{txt}</g>']
    return svg(tw + 18, 26, "".join(b))


def ui_title_plate():
    b = [rect(1, 1, 250, 54, WHITE, INK, 1.6),
         rect(6, 6, 238, 12, INK)]
    t1, _ = bmp_text("RED INK", 0, 0, 2, INK)
    b.append(f'<g transform="translate(8,26)">{t1}</g>')
    t2, _ = bmp_text("FIELD KIT V1", 0, 0, 1, MID)
    b.append(f'<g transform="translate(9,46)">{t2}</g>')
    t3, tw3 = bmp_text("SHEET 1/1", 0, 0, 1, MID)
    b.append(f'<g transform="translate({_f(244 - tw3)},{_f(9)})">{t3}</g>')
    return svg(252, 56, "".join(b))


# ------------------------------------------------------------------ registry
FILES = []


def add(path, fn, category, tags=(), anchor="centre", states=("theory", "application"),
        layer="base", note=""):
    FILES.append({"path": path, "fn": fn, "category": category, "tags": list(tags),
                  "anchor": anchor, "states": list(states), "layer": layer, "note": note})


for _name, _fn, _tag in (
        ("floor_plain", floor_plain, "concrete"),
        ("floor_plank", floor_plank, "board"),
        ("floor_tile", floor_tile, "checker"),
        ("floor_lino", floor_lino, "institutional"),
        ("floor_carpet", floor_carpet, "office"),
        ("floor_deck", floor_deck, "exterior"),
        ("floor_yard", floor_yard, "exterior"),
        ("floor_studs", floor_studs, "notation"),
        ("print_grain", print_grain, "print")):
    add(f"tiles/{_name}.svg", _fn, "tiles", (_tag, "1m"), anchor="top-left")

for _name, _fn, _tag in (
        ("wall_straight", wall_straight, "solid cover"),
        ("wall_stack", wall_stack, "solid cover"),
        ("wall_window", wall_window, "window"),
        ("wall_doorway", wall_doorway, "door swing"),
        ("wall_half", wall_half, "half cover"),
        ("wall_corner", wall_corner, "corner"),
        ("fence", fence, "concealment"),
        ("stairs", stairs, "vertical"),
        ("breach", breach, "aftermath")):
    add(f"tiles/{_name}.svg", _fn, "tiles", (_tag, "1m"), anchor="top-left",
        states=("theory",) if _name in ("wall_doorway",) else
               ("application",) if _name == "breach" else ("theory", "application"))

for _name, _fn, _tag in (
        ("desk", prop_desk, "office"), ("chair", prop_chair, "seating"),
        ("table", prop_table, "table"), ("bed", prop_bed, "bedroom"),
        ("bunk", prop_bunk, "bedroom"), ("sofa", prop_sofa, "lounge"),
        ("cabinet", prop_cabinet, "storage"), ("lockers", prop_lockers, "storage"),
        ("shelving", prop_shelving, "storage"), ("fridge", prop_fridge, "kitchen"),
        ("counter", prop_counter, "kitchen"), ("crate", prop_crate, "storage"),
        ("pallet", prop_pallet, "storage"), ("dumpster", prop_dumpster, "yard"),
        ("ac_unit", prop_ac, "roof"), ("tree", prop_tree, "yard"),
        ("planter", prop_planter, "yard"), ("rack", prop_rack, "armoury"),
        ("basin", prop_basin, "wet"), ("toilet", prop_toilet, "wet"),
        ("stove", prop_stove, "kitchen"), ("sink", prop_sink, "wet"),
        ("washer", prop_washer, "utility"), ("dresser", prop_dresser, "bedroom"),
        ("wardrobe", prop_wardrobe, "bedroom"), ("stretcher", prop_stretcher, "medical")):
    add(f"props/{_name}.svg", _fn, "props", (_tag, "cover" if _tag in
        ("office", "storage", "kitchen", "table", "bedroom") else "prop"))

add("props/car.svg", lambda: prop_car(False), "props", ("vehicle", "yard"))
add("props/police_car.svg", lambda: prop_car(True), "props", ("vehicle", "police"))

for _name, _kind in (("officer", "officer"), ("qrf", "qrf"), ("medic", "medic"),
                     ("suspect", "suspect"), ("civilian", "civilian")):
    add(f"actors/{_name}_stand.svg", lambda k=_kind: actor_stand(k), "actors",
        (_kind, "0.8m"), note="faces +x")
    add(f"actors/{_name}_down.svg", lambda k=_kind: actor_down(k), "actors",
        (_kind, "1.9m"), states=("application",), note="lying, long axis +x")
add("actors/suspect_surrender.svg", actor_surrender, "actors", ("suspect", "surrender"))
add("actors/civilian_surrender.svg", lambda: actor_surrender("civilian"), "actors",
    ("civilian", "surrender"))
add("actors/suspect_cuffed.svg", actor_cuffed, "actors", ("suspect", "arrest"))
add("actors/civilian_cuffed.svg", lambda: actor_cuffed("civilian"), "actors",
    ("civilian", "arrest"))
add("actors/shadow_stand.svg", lambda: actor_shadow("stand"), "actors", ("shadow",),
    layer="ink")
add("actors/shadow_down.svg", lambda: actor_shadow("down"), "actors", ("shadow",),
    layer="ink", states=("application",))
add("actors/rifle.svg", weapon_rifle, "actors", ("weapon",))
add("actors/pistol.svg", weapon_pistol, "actors", ("weapon",))

for _n in range(1, 5):
    add(f"marks/evidence_{_n}.svg", lambda n=_n: mark_evidence(n), "marks",
        ("evidence", "numbered"), states=("application",))
for _n in (1, 2, 3):
    add(f"marks/paper_{_n}.svg", lambda n=_n: mark_paper(n), "marks",
        ("paperwork",), states=("application",))
add("marks/form.svg", mark_form, "marks", ("paperwork", "form"), states=("application",))
add("marks/casing.svg", mark_casing, "marks", ("brass",), states=("application",))
add("marks/glass.svg", mark_glass, "marks", ("aftermath",), states=("application",))
add("marks/scuff_1.svg", lambda: mark_scuff(1), "marks", ("aftermath",), states=("application",))
add("marks/scuff_2.svg", lambda: mark_scuff(2), "marks", ("aftermath",), states=("application",))
add("marks/body_tag.svg", mark_tag, "marks", ("medical",), states=("application",))

for _name, _fn in (("blood_pool_1", lambda: blood_pool(5)),
                   ("blood_pool_2", lambda: blood_pool(9)),
                   ("blood_trail", blood_trail),
                   ("blood_smear", blood_smear),
                   ("blood_flecks_1", lambda: blood_flecks(3)),
                   ("blood_flecks_2", lambda: blood_flecks(8)),
                   ("spill_wash", spill_wash)):
    add(f"masks/{_name}.svg", _fn, "masks", ("gore", "white-mask"), layer="red_mask",
        states=("application",), note="white on transparent; hue from shader")
for _n in range(1, 6):
    add(f"masks/ring_{_n}.svg", lambda n=_n: mask_ring(n), "masks",
        ("route", "numbered"), layer="red_mask")
add("masks/route_arrow.svg", mask_route_arrow, "masks", ("route",), layer="red_mask")
add("masks/beacon.svg", mask_beacon, "masks", ("alarm",), layer="red_mask")
add("masks/stamp_filed.svg", lambda: mask_stamp("FILED"), "masks", ("stamp",),
    layer="red_mask", states=("application",))
add("masks/stamp_open.svg", lambda: mask_stamp("NOT RESOLVED"), "masks", ("stamp",),
    layer="red_mask", states=("application",))

add("ui/north.svg", ui_north, "ui", ("compass",))
add("ui/scale.svg", ui_scale, "ui", ("scale",))
add("ui/stamp_theory.svg", ui_stamp_theory, "ui", ("stamp",), states=("theory",))
add("ui/stamp_application.svg", ui_stamp_application, "ui", ("stamp",),
    states=("application",))
add("ui/title_plate.svg", ui_title_plate, "ui", ("plate",))


def build_all():
    """Return {relative path: svg text} for every asset."""
    return {f["path"]: f["fn"]() for f in FILES}


# ------------------------------------------------------------------ demo room
def demo_room():
    """A 12 x 8 m back-of-store: same topology in both states, different rendering.
    Authored once here, consumed by the Godot gallery and by the state sheet.

    Positions are in metres from the room's top-left. Annotations are in pixels
    below the room, in the sheet margin, so nothing covers the plan."""
    def wall_h(x, y, n, kind="wall"):
        return {"x": x, "y": y, "len": n, "o": "h", "kind": kind}

    def wall_v(x, y, n, kind="wall"):
        return {"x": x, "y": y, "len": n, "o": "v", "kind": kind}

    walls = [
        # top (exterior): two windows, both on the office side
        wall_h(0, 0, 4, "wall"), wall_h(4, 0, 1, "window"), wall_h(5, 0, 2, "wall"),
        wall_h(7, 0, 1, "window"), wall_h(8, 0, 4, "wall"),
        # bottom (exterior): the back door
        wall_h(0, 8, 2, "wall"), wall_h(2, 8, 1, "door"), wall_h(3, 8, 9, "wall"),
        # left and right
        wall_v(0, 0, 7, "wall"), wall_v(0, 7, 1, "wall"),
        wall_v(12, 0, 8, "wall"),
        # the partition between the back room and the office, with its door
        wall_v(7, 1, 1, "door"), wall_v(7, 2, 6, "wall"),
        # office store-room partition
        wall_h(8, 5.4, 1, "wall"), wall_h(9, 5.4, 1, "door"), wall_h(10, 5.4, 2, "wall"),
    ]
    floors = [
        {"x": 0, "y": 0, "w": 7, "h": 8, "tile": "floor_plank"},
        {"x": 7, "y": 0, "w": 5, "h": 5.4, "tile": "floor_lino"},
        {"x": 7, "y": 5.4, "w": 5, "h": 2.6, "tile": "floor_carpet"},
    ]
    props = [
        {"name": "counter", "x": 1.5, "y": 1.5, "rot": 0},
        {"name": "shelving", "x": 1.05, "y": 3.1, "rot": 90},
        {"name": "shelving", "x": 1.05, "y": 4.5, "rot": 90},
        {"name": "rack", "x": 5.4, "y": 0.45, "rot": 0},
        {"name": "table", "x": 4.3, "y": 2.6, "rot": 0},
        {"name": "chair", "x": 4.3, "y": 3.4, "rot": 180},
        {"name": "crate", "x": 5.7, "y": 5.9, "rot": 0},
        {"name": "crate", "x": 6.35, "y": 6.45, "rot": 0},
        {"name": "pallet", "x": 4.9, "y": 7.0, "rot": 0},
        {"name": "cabinet", "x": 0.6, "y": 5.7, "rot": 90},
        {"name": "fridge", "x": 0.5, "y": 6.7, "rot": 0},
        {"name": "stove", "x": 0.5, "y": 7.5, "rot": 0},
        {"name": "lockers", "x": 7.8, "y": 0.45, "rot": 0},
        {"name": "desk", "x": 10.6, "y": 1.3, "rot": 0},
        {"name": "chair", "x": 10.6, "y": 2.15, "rot": 180},
        {"name": "cabinet", "x": 11.4, "y": 3.5, "rot": 90},
        {"name": "fridge", "x": 7.6, "y": 4.7, "rot": 0},
        {"name": "desk", "x": 9.5, "y": 6.6, "rot": 0},
        {"name": "chair", "x": 9.5, "y": 7.4, "rot": 180},
        {"name": "cabinet", "x": 11.5, "y": 6.0, "rot": 90},
    ]
    actors = [
        {"name": "officer_stand", "x": 2.4, "y": 6.7, "rot": -90},
        {"name": "officer_stand", "x": 4.3, "y": 7.3, "rot": -50},
        {"name": "officer_stand", "x": 6.3, "y": 4.0, "rot": -15},
        {"name": "suspect_stand", "x": 9.0, "y": 3.1, "rot": 180},
        {"name": "civilian_stand", "x": 10.5, "y": 4.4, "rot": 200},
    ]
    # theory: straight, axis-aligned, four corners and no doubt about any of them
    route = [[2.4, 7.3], [2.4, 5.6], [6.2, 5.6], [6.2, 1.5], [9.7, 1.5]]
    theory = {
        "stamp": "ui/stamp_theory.svg",
        "route": route,
        "rings": [[2.4, 7.3], [2.4, 5.6], [6.2, 1.5], [9.7, 1.5]],
        "labels": [["MODEL: COMPLETE", 8, 6], ["UNKNOWN: NONE", 8, 30],
                   ["RISK: APPROVED", 8, 54]],
        "stamps": [],
        "notes": ["ENTRY 01  ·  MAIN FLOOR  ·  BACK ROOM  ·  OFFICE",
                  "ROUTE 14.6 m  ·  4 NODES  ·  NO CONTACT MODELLED"],
    }
    application = {
        "stamp": "ui/stamp_application.svg",
        "breach": {"x": 7, "y": 1},
        # application: same topology, walked -- corners cut, walls grazed, late
        "route": [[2.4, 7.3], [2.5, 6.4], [2.35, 5.5], [4.2, 5.62], [5.9, 5.45],
                  [6.35, 5.3], [6.3, 3.6], [6.1, 2.4], [6.5, 1.45], [7.4, 1.5],
                  [8.6, 1.55], [9.6, 1.7]],
        "rings": [[2.4, 7.3], [2.35, 5.5], [6.5, 1.45], [9.6, 1.7]],
        "labels": [["ACTUAL: 04:12", 8, 6], ["FRICTION: ALL", 8, 30],
                   ["MOP: REQUESTED", 8, 54]],
        "stamps": [["masks/stamp_filed.svg", 300, 4, 0.8],
                   ["masks/stamp_open.svg", 300, 32, 0.8]],
        "notes": ["PAPERWORK: 03 FORMS  ·  ONE DOOR BREACHED  ·  ONE DETAINEE",
                  "EVIDENCE 01-04  ·  FILE NOT RESOLVED"],
        "blood": [
            {"mask": "spill_wash", "x": 9.0, "y": 3.05, "scale": 1.0, "alpha": 0.38},
            {"mask": "blood_pool_1", "x": 9.0, "y": 3.05, "scale": 0.75, "alpha": 0.92},
            {"mask": "blood_trail", "x": 8.2, "y": 2.2, "rot": -28, "scale": 0.62,
             "alpha": 0.8},
            {"mask": "blood_smear", "x": 7.15, "y": 2.0, "rot": 96, "scale": 0.42,
             "alpha": 0.7},
            {"mask": "blood_flecks_1", "x": 8.4, "y": 3.8, "scale": 0.8, "alpha": 0.6},
            {"mask": "blood_flecks_2", "x": 7.65, "y": 2.4, "scale": 0.6, "alpha": 0.5},
            {"mask": "blood_smear", "x": 10.45, "y": 6.85, "rot": -20, "scale": 0.26,
             "alpha": 0.6},
        ],
        "marks": [
            {"name": "evidence_1", "x": 7.3, "y": 0.85, "rot": 0, "scale": 0.8},
            {"name": "evidence_2", "x": 8.35, "y": 3.95, "rot": 18, "scale": 0.8},
            {"name": "evidence_3", "x": 7.5, "y": 3.3, "rot": -12, "scale": 0.8},
            {"name": "evidence_4", "x": 10.15, "y": 3.45, "rot": 8, "scale": 0.8},
            {"name": "paper_1", "x": 9.2, "y": 6.15, "rot": -14},
            {"name": "paper_2", "x": 10.2, "y": 5.8, "rot": 22},
            {"name": "form", "x": 10.5, "y": 6.98, "rot": -6},
            {"name": "scuff_1", "x": 6.7, "y": 4.65, "rot": 90},
            {"name": "scuff_2", "x": 9.9, "y": 2.75, "rot": 0},
            {"name": "casing", "x": 8.6, "y": 4.3, "rot": 30},
            {"name": "casing", "x": 8.75, "y": 4.45, "rot": -20},
            {"name": "glass", "x": 11.15, "y": 2.85, "rot": 0},
            {"name": "body_tag", "x": 8.35, "y": 5.15, "rot": 12},
        ],
        "actor_state": {"suspect_stand": "suspect_down",
                        "civilian_stand": "civilian_surrender"},
    }
    return {
        "name": "BACK OF STORE",
        "size_m": [12, 8],
        "px_per_metre": PPM,
        "grid_m": 1,
        "margin_px": 178,
        "walls": walls,
        "floors": floors,
        "props": props,
        "actors": actors,
        "theory": theory,
        "application": application,
        "notes": [
            "MAP TOPOLOGY IS IDENTICAL IN BOTH STATES.",
            "THEORY NEVER CONTAINS BLOOD.",
            "SPACE: RED OFF  ·  G: GORE OFF  ·  1/2: STATE",
        ],
    }


# ------------------------------------------------------------------ sheets
def inner(svgtext):
    i = svgtext.index(">") + 1
    j = svgtext.rindex("</svg>")
    return svgtext[i:j]


def dims(svgtext):
    header = svgtext[:svgtext.index(">")]
    w = int(header.split('width="')[1].split('"')[0])
    h = int(header.split('height="')[1].split('"')[0])
    return w, h


def tint(svgtext, color):
    """Preview-only: masks are authored white so the runtime shader supplies the
    hue. Recolouring the source keeps the sheet honest about shape and alpha."""
    return svgtext.replace(WHITE, color)


def place(content, key, cx, cy, rot=0.0, scale=1.0, ppm=PPM, alpha=1.0, color=None):
    s = content[key]
    if color:
        s = tint(s, color)
    w, h = dims(s)
    body = inner(s)
    op = f' opacity="{alpha}"' if alpha < 1.0 else ""
    return (f'<g transform="translate({_f(cx * ppm)},{_f(cy * ppm)}) rotate({_f(rot)}) '
            f'scale({_f(scale)}) translate({_f(-w / 2)},{_f(-h / 2)})"{op}>{body}</g>')


def place_corner(content, key, x, y, rot=0.0, scale=1.0, ppm=PPM, color=None):
    s = content[key]
    if color:
        s = tint(s, color)
    w, h = dims(s)
    body = inner(s)
    return (f'<g transform="translate({_f(x * ppm)},{_f(y * ppm)}) rotate({_f(rot)}) '
            f'scale({_f(scale)})">{body}</g>')


def bt(text, x, y, px=1.5, color=INK, op=None):
    s, _ = bmp_text(text, x, y, px, color, op)
    return s


def wall_piece(content, tile, x, y, vertical, ppm):
    """Place a 1 x 0.25 m wall tile. Horizontal tiles hang below their line;
    vertical tiles are the same tile rotated 90 deg about the wall line."""
    body = inner(content[tile])
    if not vertical:
        return (f'<g transform="translate({_f(x * ppm)},{_f(y * ppm)})">{body}</g>')
    # rotate: local (a,b) -> (-b, a); translate by (10,0) to centre the poche on the line
    return (f'<g transform="translate({_f(x * ppm)},{_f(y * ppm)}) rotate(90) '
            f'translate(10,0)">{body}</g>')


def room_svg(content, room, state, ppm=70, red=RED):
    """Render the demo room in one state. Topology comes from the shared JSON;
    only the rendering changes between theory and application."""
    W, H = (room["size_m"][0] * ppm, room["size_m"][1] * ppm)
    b = [rect(0, 0, W, H, PAPER),
         rect(0, H + 22, W, room.get("margin_px", 156), PAPER)]
    for f in room["floors"]:
        for gy in range(int(f["h"])):
            for gx in range(int(f["w"])):
                b.append(place_corner(content, f"tiles/{f['tile']}.svg",
                                      f["x"] + gx, f["y"] + gy, 0, 1, ppm))
    # walls: solid strips first, openings cut over them, so butted tiles never
    # double-ink the poche
    breach = room["application"].get("breach") if state == "application" else None
    for wl in room["walls"]:
        if wl["kind"] != "wall":
            continue
        for k in range(int(math.ceil(wl["len"]))):
            if wl["o"] == "h":
                b.append(wall_piece(content, "tiles/wall_stack.svg", wl["x"] + k, wl["y"],
                                    False, ppm))
            else:
                b.append(wall_piece(content, "tiles/wall_stack.svg", wl["x"], wl["y"] + k,
                                    True, ppm))
    for wl in room["walls"]:
        kind = wl["kind"]
        if kind == "wall":
            continue
        if kind == "window":
            tile = "tiles/wall_window.svg"
        else:
            tile = ("tiles/breach.svg" if breach == {"x": wl["x"], "y": wl["y"]}
                    else "tiles/wall_doorway.svg")
        for k in range(int(math.ceil(wl["len"]))):
            if wl["o"] == "h":
                b.append(wall_piece(content, tile, wl["x"] + k, wl["y"], False, ppm))
            else:
                b.append(wall_piece(content, tile, wl["x"], wl["y"] + k, True, ppm))
    # props
    for p in room["props"]:
        b.append(place(content, f"props/{p['name']}.svg", p["x"], p["y"],
                       p.get("rot", 0), 1.0, ppm))
    # actors: shadow, then silhouette
    swapped = room["application"].get("actor_state", {}) if state == "application" else {}
    for a in room["actors"]:
        name = swapped.get(a["name"], a["name"])
        pose = "down" if name.endswith("_down") else "stand"
        b.append(place(content, f"actors/shadow_{pose}.svg", a["x"], a["y"], a["rot"], 1.0, ppm))
        b.append(place(content, f"actors/{name}.svg", a["x"], a["y"], a["rot"], 1.0, ppm))
    st = room[state]
    # blood layer: masks tinted by the accent, under the marks and the markers
    if state == "application":
        for bl in st["blood"]:
            b.append(place(content, f"masks/{bl['mask']}.svg", bl["x"], bl["y"],
                           bl.get("rot", 0), bl.get("scale", 1.0), ppm,
                           bl.get("alpha", 0.8), red))
        for m in st["marks"]:
            b.append(place(content, f"marks/{m['name']}.svg", m["x"], m["y"],
                           m.get("rot", 0), m.get("scale", 1.0), ppm))
    # route: one clean line in theory; a wider line with a faint offset duplicate
    # (the plan as drawn vs. the plan as walked) in application
    pts = [(x * ppm, y * ppm) for (x, y) in st["route"]]
    if state == "application":
        b.append(poly([(x + 4, y + 5) for (x, y) in pts], "none", red, 4.0, op=0.16,
                      close=False))
        b.append(poly(pts, "none", red, 6.0, op=0.9, close=False))
    else:
        b.append(poly(pts, "none", red, 4.0, close=False))
    for i, (rx, ry) in enumerate(st["rings"], start=1):
        b.append(place(content, f"masks/ring_{((i - 1) % 5) + 1}.svg", rx, ry, 0, 0.62, ppm, 1.0, red))
    (x0, y0), (x1, y1) = st["route"][-2], st["route"][-1]
    ang = math.degrees(math.atan2(y1 - y0, x1 - x0))
    b.append(place(content, "masks/route_arrow.svg", (x0 + x1) / 2, (y0 + y1) / 2, ang,
                   0.55, ppm, 0.9, red))
    # institutional labels, on chips, in the margin below the plan
    for (text, lx, ly) in st["labels"]:
        tw = bmp_width(text, 1.5)
        b.append(rect(lx, H + 32 + ly, tw + 10, 17, WHITE, INK, 1.0))
        b.append(bt(text, lx + 5, H + 37 + ly, 1.5, INK))
    for (path_, sx, sy, sc) in st.get("stamps", []):
        b.append(place(content, path_, (sx) / ppm, (H + 32 + sy) / ppm, 0, sc, ppm, 1.0, red))
    return "".join(b), W, H


def state_sheet(content, room):
    ppm = 70
    W = room["size_m"][0] * ppm
    H = room["size_m"][1] * ppm
    margin = room.get("margin_px", 96)
    pad = 52
    top = 150
    foot = 200
    sheet_w = pad * 2 + W * 2 + 52
    sheet_h = top + H + margin + 40 + foot
    b = [rect(0, 0, sheet_w, sheet_h, PAPER),
         rect(14, 14, sheet_w - 28, sheet_h - 28, "none", INK, 1.6),
         rect(22, 22, sheet_w - 44, sheet_h - 44, "none", MID, 0.8)]
    b.append(bt("THE VIOLENCE", pad, 44, 4.5, INK))
    b.append(bt("RED INK  ·  ASSET PACK 01  ·  TOP-DOWN 90 DEG  ·  80 PX PER METRE", pad, 84, 1.6, MID))
    b.append(bt("DEMO ROOM  ·  12 x 8 m  ·  ONE TOPOLOGY, TWO RENDERINGS", pad, 104, 1.6, INK))
    b.append(bt("MAP 11  ·  SHEET 1 OF 1  ·  ORIGINAL, PROJECT-OWNED", pad, 122, 1.3, MID))
    b.append(f'<g transform="translate({_f(sheet_w - pad - 46)},{_f(34)})">'
             f'{inner(content["ui/north.svg"])}</g>')
    b.append(f'<g transform="translate({_f(sheet_w - pad - 190)},{_f(112)})">'
             f'{inner(content["ui/scale.svg"])}</g>')
    for idx, (state, title) in enumerate((("theory", "01  THEORY  ·  BRIEFING"),
                                          ("application", "02  APPLICATION  ·  AFTERMATH"))):
        x = pad + idx * (W + 52)
        panel_h = H + margin + 16
        b.append(rect(x - 12, top - 34, W + 24, panel_h + 34, WHITE))
        b.append(rect(x - 12, top - 34, W + 24, panel_h + 34, INK, "none", 1.2))
        b.append(bt(title, x, top - 22, 1.8, INK))
        body, _, _ = room_svg(content, room, state, ppm)
        b.append(f'<g transform="translate({_f(x)},{_f(top)})">{body}</g>')
        b.append(rect(x, top, W, H, "none", MID, 0.8))
        # stamp sits under the plan, right-aligned
        b.append(f'<g transform="translate({_f(x + W - 186)},{_f(top + H + 112)})">'
                 f'{inner(content[room[state]["stamp"]])}</g>')
        notes = room[state]["notes"]
        for k, note in enumerate(notes):
            b.append(bt(note, x, top + H + 112 + k * 15, 1.5, MID if k else INK))
    # footer: palette, layers, monochrome proof
    fy = top + H + margin + 44
    b.append(line(pad, fy - 18, sheet_w - pad, fy - 18, MID, 0.8, op=0.5))
    b.append(bt("PALETTE", pad, fy, 1.5, MID))
    for i, (name, hexv) in enumerate((("PAPER", PAPER), ("FLOOR", FLOOR), ("LIGHT", LIGHT),
                                      ("MID", MID), ("DARK", DARK), ("INK", INK), ("RED", RED))):
        sw = 44
        b.append(rect(pad + i * (sw + 62), fy + 14, sw, 26, hexv, INK, 0.8))
        b.append(bt(hexv, pad + i * (sw + 62), fy + 45, 1.0, MID))
        b.append(bt(name, pad + i * (sw + 62), fy + 57, 1.2, INK))
    b.append(bt("LAYERS", pad, fy + 84, 1.5, MID))
    b.append(bt("1 BASE: NEUTRAL FLOOR, WALLS, FURNITURE, SILHOUETTES", pad, fy + 100, 1.2, INK))
    b.append(bt("2 INK: OUTLINES, HARD SHADOWS, SPARSE HATCH", pad, fy + 112, 1.2, INK))
    b.append(bt("3 RED MASK: ROUTE, ALARM, SPILL, BLOOD -- WHITE FILES, ONE HUE", pad, fy + 124, 1.2, INK))
    b.append(bt("4 PRINT: NEUTRAL GRAIN AND HALFTONE, LOW CONTRAST", pad, fy + 136, 1.2, INK))
    # monochrome proof inset
    mx = sheet_w - pad - 318
    b.append(rect(mx - 12, fy - 4, 318, 104, WHITE, INK, 1.0))
    b.append(bt("MONOCHROME PROOF  ·  RED OFF", mx, fy + 8, 1.2, MID))
    b.append(place(content, "masks/blood_pool_2.svg", (mx + 46) / ppm, (fy + 52) / ppm, 0, 0.34, ppm, 0.9, "#5C5C5C"))
    b.append(place(content, "masks/blood_trail.svg", (mx + 172) / ppm, (fy + 52) / ppm, -6, 0.34, ppm, 0.8, "#5C5C5C"))
    b.append(bt("SHAPE, NUMBER AND DASH CARRY THE MEANING", mx + 16, fy + 84, 1.0, MID))
    b.append(bt("GENERATED BY tools/make_redink_assets.py  ·  MASKS ARE WHITE; "
                "HUE FROM shaders/red_mask.gdshader", pad, sheet_h - 32, 1.2, MID))
    return svg(sheet_w, sheet_h, "".join(b))


CATEGORY_TITLES = (("tiles", "TILES  ·  1 m MODULAR"), ("props", "PROPS  ·  PLAN SYMBOLS"),
                   ("actors", "ACTORS  ·  FLAT INK SILHOUETTES"),
                   ("marks", "MARKS  ·  AFTERMATH, NEUTRAL"),
                   ("masks", "RED MASK  ·  WHITE ON TRANSPARENT"),
                   ("ui", "UI  ·  INSTITUTIONAL"))


def contact_sheet(content):
    """Every asset, at native scale, on the paper it will live on."""
    pad = 40
    sheet_w = 1780
    y = 132
    cells = []
    for cat, title in CATEGORY_TITLES:
        group = [f for f in FILES if f["category"] == cat]
        cells.append(("header", title, y))
        y += 30
        x = pad
        row_h = 0
        for f in group:
            s = content[f["path"]]
            w, h = dims(s)
            cap = 196
            sc = min(1.0, cap / max(w, h))
            cw, ch = w * sc, h * sc
            label_px = len(os.path.basename(f["path"])[:-4].replace("_", " ")) * 7.2 + 12
            cell_w = max(cw, 96, label_px) + 16
            if x + cell_w > sheet_w - pad:
                x = pad
                y += row_h + 40
                row_h = 0
            cells.append(("cell", f, x, y, sc, cw, ch))
            x += cell_w
            row_h = max(row_h, ch + (42 if f["category"] == "masks" else 30))
        y += row_h + 26
    sheet_h = y + 96
    b = [rect(0, 0, sheet_w, sheet_h, PAPER),
         rect(10, 10, sheet_w - 20, sheet_h - 20, "none", INK, 1.6)]
    b.append(bt("THE VIOLENCE", pad, 26, 4.0, INK))
    b.append(bt("RED INK  ·  ASSET PACK 01  ·  TOP-DOWN 90 DEG  ·  80 PX PER METRE", pad, 64, 1.6, MID))
    b.append(bt("PAPER, FLOOR, LIGHT, MID, DARK, INK -- AND ONE RED, ONLY WHERE PLAN MEETS ROOM", pad, 84, 1.4, INK))
    px = sheet_w - pad - 7 * 76
    for i, (name, hexv) in enumerate((("PAPER", PAPER), ("FLOOR", FLOOR), ("LIGHT", LIGHT),
                                      ("MID", MID), ("DARK", DARK), ("INK", INK), ("RED", RED))):
        b.append(rect(px + i * 76, 30, 52, 30, hexv, INK, 0.8))
        b.append(bt(name, px + i * 76, 66, 1.1, MID))
    for item in cells:
        if item[0] == "header":
            _, title, yy = item
            b.append(line(pad, yy + 12, sheet_w - pad, yy + 12, MID, 0.8, op=0.45))
            b.append(bt(title, pad, yy, 1.7, INK))
            continue
        _, f, x, yy, sc, cw, ch = item
        is_mask = f["category"] == "masks"
        caption_y = yy + ch + (20 if is_mask else 12)
        if is_mask:
            b.append(rect(x, yy, max(cw, 90) + 6, ch + 8, DARK))
        body = inner(content[f["path"]])
        b.append(f'<g transform="translate({_f(x + (max(cw, 90) - cw) / 2 + 3)},{_f(yy + 4)}) '
                 f'scale({_f(sc)})">{body}</g>')
        label = os.path.basename(f["path"])[:-4].replace("_", " ")
        wpx, hpx = dims(content[f["path"]])
        room_px = max(cw, 96)
        if bmp_width(label, 1.2) > room_px:
            label = label[:max(4, int(room_px / 7.2))]
        b.append(bt(label, x, caption_y, 1.2, INK))
        b.append(bt(f"{wpx / PPM:.2f} x {hpx / PPM:.2f} m", x, caption_y + 10, 1.0, MID))
    b.append(bt("GENERATED BY tools/make_redink_assets.py  ·  ORIGINAL, PROJECT-OWNED  ·  "
                "MASKS ARE WHITE; HUE COMES FROM shaders/red_mask.gdshader", pad, sheet_h - 34, 1.2, MID))
    return svg(sheet_w, sheet_h, "".join(b))


# ------------------------------------------------------------------ audit
def audit(content):
    import re
    problems = []
    stats = {"files": len(content), "neutral": 0, "masks": 0}
    hexre = re.compile(r"#([0-9A-Fa-f]{6})")
    for f in FILES:
        path = f["path"]
        s = content[path]
        if "<text" in s or "<image" in s:
            problems.append(f"{path}: raster or live text in SVG")
        if "Gradient" in s or "<filter" in s:
            problems.append(f"{path}: gradient/filter (Godot's SVG import is unreliable)")
        cols = set(hexre.findall(s))
        if f["category"] == "masks":
            stats["masks"] += 1
            bad = [c for c in cols if c.upper() != "FFFFFF"]
            if bad:
                problems.append(f"{path}: mask uses non-white colour(s) {bad}")
            if f["layer"] != "red_mask":
                problems.append(f"{path}: mask not on the red_mask layer")
        else:
            stats["neutral"] += 1
            # "neutral, or nearly neutral": the house greys drift by a few points
            # per channel (D4D4CF), but nothing saturated may appear before the mask.
            bad = []
            for c in cols:
                rgb = [int(c[i:i + 2], 16) for i in (0, 2, 4)]
                if max(rgb) - min(rgb) > 12 or c.upper() == RED[1:].upper():
                    bad.append(c)
            if bad:
                problems.append(f"{path}: chromatic colour(s) north of the mask layer: {bad}")
            if f["layer"] == "red_mask":
                problems.append(f"{path}: red_mask layer declared on base art")
        if not path.startswith(f["category"] + "/"):
            problems.append(f"{path}: file is outside its category folder")
    return problems, stats


# ------------------------------------------------------------------ main
def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default="assets/redink")
    ap.add_argument("--docs", default="docs/redink")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--sheets", action="store_true", help="also write the review sheets")
    a = ap.parse_args()

    if a.list:
        for f in FILES:
            print(f["path"])
        return

    content = build_all()
    problems, stats = audit(content)
    print(f"pack: {stats['files']} files ({stats['neutral']} neutral, {stats['masks']} masks)")
    if problems:
        print("AUDIT FAILED")
        for p in problems:
            print("  -", p)
        raise SystemExit(1)
    print("audit: neutral base art, white-only masks, no text/filters -- ok")

    if a.check:
        for f in FILES:
            w, h = dims(content[f["path"]])
            print(f"  {f['path']:<34} {w / PPM:5.2f} x {h / PPM:4.2f} m  {f['category']}")
        return

    for f in FILES:
        dst = os.path.join(a.out, f["path"])
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        with open(dst, "w", encoding="utf-8") as fh:
            fh.write(content[f["path"]])

    files = []
    for f in FILES:
        w, h = dims(content[f["path"]])
        files.append({"path": f["path"], "name": os.path.basename(f["path"])[:-4],
                      "category": f["category"], "layer": f["layer"], "anchor": f["anchor"],
                      "size_px": [w, h], "metres": [round(w / PPM, 3), round(h / PPM, 3)],
                      "states": f["states"], "tags": f["tags"], "note": f["note"]})
    manifest = {
        "pack": "red-ink",
        "version": 1,
        "generator": "tools/make_redink_assets.py",
        "license": "original, project-owned",
        "px_per_metre": PPM,
        "facing": "+x",
        "palette": {"paper": PAPER, "floor": FLOOR, "light": LIGHT, "mid": MID,
                    "dark": DARK, "ink": INK, "red": RED},
        "layers": ["base", "ink", "red_mask", "print"],
        "masks": "white on transparent; tint with shaders/red_mask.gdshader or Ink.accent()",
        "files": files,
    }
    os.makedirs(a.out, exist_ok=True)
    with open(os.path.join(a.out, "manifest.json"), "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=1)
    with open(os.path.join(a.out, "demo_room.json"), "w", encoding="utf-8") as fh:
        json.dump(demo_room(), fh, indent=1)

    if a.sheets or a.out == 'assets/redink':
        os.makedirs(a.docs, exist_ok=True)
        with open(os.path.join(a.docs, "contact_sheet.svg"), "w", encoding="utf-8") as fh:
            fh.write(contact_sheet(content))
        with open(os.path.join(a.docs, "state_sheet.svg"), "w", encoding="utf-8") as fh:
            fh.write(state_sheet(content, demo_room()))
    print(f"wrote {len(FILES)} assets, manifest, demo_room.json to {a.out}")
    print(f"wrote review sheets to {a.docs}")


if __name__ == "__main__":
    main()
