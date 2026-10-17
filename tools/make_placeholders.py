#!/usr/bin/env python3
"""Generate ORIGINAL placeholder SVG art for "The Violence" vertical slice.

Stdlib only, deterministic. Everything is drawn in plan view (top-down, 90 deg),
in the visual language of an architectural floor plan: thin ink lines, white or
grey fills. The only colour anywhere is blood red.

Scale: 80 px per metre (2x the in-game 40 px/m), so sprites stay crisp when the
camera zooms in. Sprites are placed at scale 0.5 by the game.
Facing: every figure and weapon faces +x (east), which is Godot's rotation 0.

    python3 tools/make_placeholders.py            # writes assets/svg/
    python3 tools/make_placeholders.py --list

Godot drops <text> in SVGs, so there is no text in any file.
"""
import argparse
import json
import math
import os
import random

PPM = 80  # pixels per metre in the SVG files
INK = "#1c1c1c"
LINE = "#3a3a3a"
FAINT = "#8a8a8a"
WHITE = "#ffffff"
PAPER = "#f4f4f4"
GREY_L = "#d9d9d9"
GREY_M = "#a6a6a6"
GREY_D = "#6b6b6b"
BLOOD = "#7d0a0a"
BLOOD_D = "#560505"
BLOOD_L = "#a01212"


def svg(w_m, h_m, body, defs=""):
    w, h = round(w_m * PPM), round(h_m * PPM)
    d = f"<defs>{defs}</defs>" if defs else ""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" '
            f'viewBox="0 0 {w} {h}">{d}{body}</svg>\n')


def st(color=LINE, w=2.0, dash=None):
    s = f' stroke="{color}" stroke-width="{w}" stroke-linejoin="round" stroke-linecap="round"'
    if dash:
        s += f' stroke-dasharray="{dash}"'
    return s


def rect(x, y, w, h, fill="none", rx=0, stroke=LINE, sw=2.0, extra=""):
    s = st(stroke, sw) if stroke else ""
    return f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" rx="{rx}" fill="{fill}"{s}{extra}/>'


def circle(cx, cy, r, fill="none", stroke=LINE, sw=2.0, extra=""):
    s = st(stroke, sw) if stroke else ""
    return f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{r:.1f}" fill="{fill}"{s}{extra}/>'


def ellipse(cx, cy, rx, ry, fill="none", stroke=LINE, sw=2.0, extra=""):
    s = st(stroke, sw) if stroke else ""
    return f'<ellipse cx="{cx:.1f}" cy="{cy:.1f}" rx="{rx:.1f}" ry="{ry:.1f}" fill="{fill}"{s}{extra}/>'


def line(x1, y1, x2, y2, color=LINE, w=2.0, dash=None):
    return f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}"{st(color, w, dash)}/>'


def path(d, fill="none", stroke=LINE, sw=2.0, extra=""):
    s = st(stroke, sw) if stroke else ""
    return f'<path d="{d}" fill="{fill}"{s}{extra}/>'


def blob_path(cx, cy, r, rng, lobes=9, jitter=0.35):
    """Irregular closed blob, used for blood."""
    pts = []
    n = lobes * 2
    for i in range(n):
        a = i / n * math.tau
        rr = r * (1 + rng.uniform(-jitter, jitter) * (0.6 if i % 2 else 1.0))
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    d = f"M{pts[0][0]:.1f},{pts[0][1]:.1f} "
    for i in range(n):
        p1 = pts[(i + 1) % n]
        p0 = pts[i]
        mx, my = (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2
        d += f"Q{p0[0]:.1f},{p0[1]:.1f} {mx:.1f},{my:.1f} "
    return d + "Z"


# ------------------------------------------------------------- operators
def operator(team, pose="stand"):
    """Plan-view figure, facing +x. 0.8 x 0.8 m canvas, centre = body centre."""
    w = h = 0.8 * PPM
    cx, cy = w / 2, h / 2
    if team == "a":
        body, head, hatch = WHITE, WHITE, None
    else:
        body, head, hatch = GREY_M, GREY_L, True
    b = []
    # shoulders (wider across y because the figure faces +x)
    b.append(ellipse(cx - 2, cy, 11, 23, body, INK, 2.2))
    if hatch:
        for k in range(-3, 4):
            y = cy + k * 6
            b.append(line(cx - 9, y - 3, cx + 5, y + 3, GREY_D, 1.2))
        b.append(ellipse(cx - 2, cy, 11, 23, "none", INK, 2.2))
    # arms reaching forward to a weapon (both hands)
    b.append(path(f"M{cx - 2},{cy - 19} Q{cx + 12},{cy - 14} {cx + 22},{cy - 2}", "none", INK, 2.0))
    b.append(path(f"M{cx - 2},{cy + 19} Q{cx + 10},{cy + 12} {cx + 16},{cy + 2}", "none", INK, 2.0))
    # head
    b.append(circle(cx + 1, cy, 8.5, head, INK, 2.2))
    # nose tick showing facing
    b.append(line(cx + 9, cy, cx + 12, cy, INK, 2.0))
    return svg(0.8, 0.8, "".join(b))


def operator_down(team):
    """Figure lying on its back, long axis along x. 1.9 x 0.9 m."""
    w, h = 1.9 * PPM, 0.9 * PPM
    cy = h / 2
    fill = WHITE if team == "a" else GREY_M
    head = WHITE if team == "a" else GREY_L
    b = []
    # legs
    b.append(path(f"M{20},{cy - 9} L{62},{cy - 7} M{20},{cy + 9} L{62},{cy + 6}", "none", INK, 7))
    b.append(path(f"M{20},{cy - 9} L{62},{cy - 7} M{20},{cy + 9} L{62},{cy + 6}", "none", fill, 4))
    # torso
    b.append(rect(58, cy - 20, 54, 40, fill, 10, INK, 2.2))
    if team == "b":
        for k in range(0, 8):
            x = 62 + k * 6
            b.append(line(x, cy - 16, x + 6, cy + 16, GREY_D, 1.2))
        b.append(rect(58, cy - 20, 54, 40, "none", 10, INK, 2.2))
    # arms flung out
    b.append(path(f"M{100},{cy - 18} Q{112},{cy - 34} {96},{cy - 32}", "none", INK, 2.2))
    b.append(path(f"M{100},{cy + 18} Q{120},{cy + 30} {108},{cy + 34}", "none", INK, 2.2))
    # head
    b.append(circle(124, cy - 2, 10, head, INK, 2.2))
    return svg(1.9, 0.9, "".join(b))


def civilian(pose="stand"):
    """Civilian in plan, facing +x: no gear, arms at the sides, a thinner, lighter outline
    (people who were not dressed for this). 0.8 x 0.8 m canvas."""
    w = h = 0.8 * PPM
    cx, cy = w / 2, h / 2
    b = [ellipse(cx - 2, cy, 10, 21, WHITE, GREY_D, 1.6)]
    # arms hanging at the sides
    b.append(path(f"M{cx - 4},{cy - 20} Q{cx + 2},{cy - 24} {cx + 6},{cy - 21}", "none", GREY_D, 1.6))
    b.append(path(f"M{cx - 4},{cy + 20} Q{cx + 2},{cy + 24} {cx + 6},{cy + 21}", "none", GREY_D, 1.6))
    b.append(circle(cx + 1, cy, 8, WHITE, GREY_D, 1.6))
    b.append(line(cx + 8.5, cy, cx + 11, cy, GREY_D, 1.6))
    return svg(0.8, 0.8, "".join(b))


def civilian_down():
    """Civilian lying on their back, long axis along x. 1.9 x 0.9 m."""
    w, h = 1.9 * PPM, 0.9 * PPM
    cy = h / 2
    b = [path(f"M{20},{cy - 9} L{62},{cy - 7} M{20},{cy + 9} L{62},{cy + 6}", "none", GREY_D, 6),
         path(f"M{20},{cy - 9} L{62},{cy - 7} M{20},{cy + 9} L{62},{cy + 6}", "none", WHITE, 3.4),
         rect(58, cy - 18, 52, 36, WHITE, 10, GREY_D, 1.6),
         path(f"M{98},{cy - 16} Q{110},{cy - 32} {94},{cy - 30}", "none", GREY_D, 1.6),
         path(f"M{98},{cy + 16} Q{118},{cy + 28} {106},{cy + 32}", "none", GREY_D, 1.6),
         circle(122, cy - 2, 9.5, WHITE, GREY_D, 1.6)]
    return svg(1.9, 0.9, "".join(b))


def weapon(kind):
    """Weapon in plan, muzzle toward +x. Pivot (grip) is at the canvas left-centre."""
    if kind == "rifle":
        w_m, h_m = 0.95, 0.16
        w, h = w_m * PPM, h_m * PPM
        cy = h / 2
        b = [rect(2, cy - 3.5, 22, 7, GREY_D, 2, INK, 1.4),       # stock
             rect(22, cy - 4.5, 30, 9, "#4a4a4a", 2, INK, 1.4),    # receiver
             rect(30, cy - 2.5, 10, 5, "#2b2b2b", 1, None),         # optic
             rect(52, cy - 3, 14, 6, GREY_D, 2, INK, 1.2),         # handguard
             line(66, cy, 75, cy, INK, 2.6)]                        # barrel
        return svg(w_m, h_m, "".join(b))
    w_m, h_m = 0.42, 0.12
    w, h = w_m * PPM, h_m * PPM
    cy = h / 2
    b = [rect(14, cy - 4, 18, 8, "#3a3a3a", 2, INK, 1.4),
         line(32, cy, 33.5, cy, INK, 2)]
    return svg(w_m, h_m, "".join(b))


# ------------------------------------------------------------- furniture (plan symbols)
def bed(w_m=2.0, h_m=1.6):
    w, h = w_m * PPM, h_m * PPM
    b = [rect(2, 2, w - 4, h - 4, WHITE, 3),
         rect(4, 4, 18, h - 8, GREY_L, 2, LINE, 1.6),                       # headboard (left)
         rect(28, 10, 30, h / 2 - 16, PAPER, 6, LINE, 1.5),                # pillows
         rect(28, h / 2 + 6, 30, h / 2 - 16, PAPER, 6, LINE, 1.5),
         path(f"M{70},{4} L{70},{h - 4} M{70},{4} L{w - 4},{h * 0.55}", "none", FAINT, 1.4)]
    return svg(w_m, h_m, "".join(b))


def sofa(w_m=2.2, h_m=0.85):
    w, h = w_m * PPM, h_m * PPM
    b = [rect(2, 2, w - 4, h - 4, WHITE, 6),
         rect(2, 2, w - 4, 18, GREY_L, 6, LINE, 1.6),                        # back (top)
         rect(2, 2, 18, h - 4, GREY_L, 6, LINE, 1.6),                        # arms
         rect(w - 20, 2, 18, h - 4, GREY_L, 6, LINE, 1.6)]
    seat_w = (w - 44) / 3
    for i in range(3):
        b.append(rect(22 + i * seat_w, 22, seat_w - 2, h - 26, WHITE, 3, LINE, 1.2))
    return svg(w_m, h_m, "".join(b))


def armchair(s=0.85):
    w = s * PPM
    b = [rect(2, 2, w - 4, w - 4, WHITE, 6),
         rect(2, 2, w - 4, 16, GREY_L, 6, LINE, 1.5),
         rect(2, 2, 14, w - 4, GREY_L, 6, LINE, 1.5),
         rect(w - 16, 2, 14, w - 4, GREY_L, 6, LINE, 1.5)]
    return svg(s, s, "".join(b))


def coffee_table(w_m=1.2, h_m=0.6):
    w, h = w_m * PPM, h_m * PPM
    return svg(w_m, h_m, rect(2, 2, w - 4, h - 4, WHITE, 3) + rect(8, 8, w - 16, h - 16, "none", 2, FAINT, 1.2))


def bookshelf(w_m=1.6, h_m=0.4):
    w, h = w_m * PPM, h_m * PPM
    b = [rect(2, 2, w - 4, h - 4, WHITE, 0)]
    for i in range(1, 8):
        x = i * (w / 8)
        b.append(line(x, 4, x, h - 4, FAINT, 1.2))
    b.append(line(2, 2, w - 2, h - 2, FAINT, 1.0))
    return svg(w_m, h_m, "".join(b))


def counter(w_m=1.6, h_m=0.6):
    w, h = w_m * PPM, h_m * PPM
    b = [rect(2, 2, w - 4, h - 4, WHITE, 0),
         rect(10, 8, 34, h - 18, PAPER, 6, LINE, 1.6),                       # sink
         circle(27, h / 2 - 4, 3, "none", LINE, 1.2)]
    for (dx, dy) in ((0, 0), (22, 0), (0, 20), (22, 20)):                     # stove burners
        b.append(circle(w - 52 + dx, 14 + dy, 7, "none", LINE, 1.4))
    b.append(line(2, h - 6, w - 2, h - 6, FAINT, 1.0))
    return svg(w_m, h_m, "".join(b))


def fridge(w_m=0.7, h_m=0.7):
    w, h = w_m * PPM, h_m * PPM
    return svg(w_m, h_m, rect(2, 2, w - 4, h - 4, WHITE, 2) + line(2, 2, w - 2, h - 2, FAINT, 1.2)
               + line(w - 2, 2, 2, h - 2, FAINT, 1.2))


def dining(w_m=1.1, h_m=0.8):
    w, h = w_m * PPM, h_m * PPM
    b = [rect(14, 12, w - 28, h - 24, WHITE, 3)]
    for x in (w * 0.3, w * 0.7):
        b.append(rect(x - 9, 1, 18, 10, WHITE, 2, LINE, 1.3))
        b.append(rect(x - 9, h - 11, 18, 10, WHITE, 2, LINE, 1.3))
    return svg(w_m, h_m, "".join(b))


def tub(w_m=1.6, h_m=0.72):
    w, h = w_m * PPM, h_m * PPM
    return svg(w_m, h_m, rect(2, 2, w - 4, h - 4, WHITE, 6)
               + rect(10, 8, w - 20, h - 16, PAPER, 22, LINE, 1.5) + circle(w - 22, h / 2, 3, "none", LINE, 1.2))


def toilet(w_m=0.5, h_m=0.65):
    w, h = w_m * PPM, h_m * PPM
    return svg(w_m, h_m, rect(4, 2, w - 8, 14, WHITE, 2) + ellipse(w / 2, h * 0.58, w / 2 - 5, h * 0.36, WHITE))


def basin(w_m=0.55, h_m=0.42):
    w, h = w_m * PPM, h_m * PPM
    return svg(w_m, h_m, rect(2, 2, w - 4, h - 4, WHITE, 3) + ellipse(w / 2, h / 2 + 2, w / 2 - 9, h / 2 - 8, PAPER, LINE, 1.4))


def dresser(w_m=1.2, h_m=0.5):
    w, h = w_m * PPM, h_m * PPM
    b = [rect(2, 2, w - 4, h - 4, WHITE, 1)]
    for i in (1, 2):
        b.append(line(i * w / 3, 4, i * w / 3, h - 4, FAINT, 1.2))
    return svg(w_m, h_m, "".join(b))


def wardrobe(w_m=1.2, h_m=0.5):
    w, h = w_m * PPM, h_m * PPM
    return svg(w_m, h_m, rect(2, 2, w - 4, h - 4, WHITE, 1) + line(w / 2, 4, w / 2, h - 4, FAINT, 1.2)
               + line(8, h / 2, w - 8, h / 2, FAINT, 1.0, "4 4"))


# ------------------------------------------------------------- yard
def car(w_m=4.4, h_m=1.9):
    w, h = w_m * PPM, h_m * PPM
    b = [rect(4, 4, w - 8, h - 8, WHITE, 34, INK, 2.2),
         rect(w * 0.30, 12, w * 0.40, h - 24, GREY_L, 16, LINE, 1.6),      # cabin / roof
         path(f"M{w * 0.30},{18} L{w * 0.22},{14} M{w * 0.30},{h - 18} L{w * 0.22},{h - 14}", "none", LINE, 1.4),
         path(f"M{w * 0.70},{18} L{w * 0.80},{14} M{w * 0.70},{h - 18} L{w * 0.80},{h - 14}", "none", LINE, 1.4),
         line(w * 0.12, 20, w * 0.12, h - 20, FAINT, 1.2),                  # bonnet line
         rect(w * 0.18, 0, 30, 6, GREY_D, 2, None), rect(w * 0.70, 0, 30, 6, GREY_D, 2, None),
         rect(w * 0.18, h - 6, 30, 6, GREY_D, 2, None), rect(w * 0.70, h - 6, 30, 6, GREY_D, 2, None)]
    return svg(w_m, h_m, "".join(b))


def tree(d_m=3.6):
    w = d_m * PPM
    c = w / 2
    rng = random.Random(7)
    b = [path(blob_path(c, c, c - 6, rng, 11, 0.12), "none", FAINT, 1.6, ' stroke-dasharray="6 5"'),
         circle(c, c, 0.25 * PPM, GREY_L, INK, 2)]
    for k in range(6):
        a = k / 6 * math.tau + 0.3
        b.append(line(c + math.cos(a) * 24, c + math.sin(a) * 24, c + math.cos(a) * (c * 0.7), c + math.sin(a) * (c * 0.7), FAINT, 1.0))
    return svg(d_m, d_m, "".join(b))


def hedge(w_m=0.8, h_m=3.6):
    w, h = w_m * PPM, h_m * PPM
    rng = random.Random(11)
    b = []
    y = 6
    while y < h - 6:
        r = rng.uniform(12, 18)
        b.append(circle(w / 2 + rng.uniform(-6, 6), y + r * 0.6, r, PAPER, LINE, 1.4))
        y += r * 0.9
    return svg(w_m, h_m, "".join(b))


def drum(d_m=0.6):
    w = d_m * PPM
    c = w / 2
    return svg(d_m, d_m, circle(c, c, c - 2, WHITE, INK, 2) + circle(c, c, c - 8, "none", FAINT, 1.2)
               + circle(c * 0.62, c * 0.62, 3, GREY_D, None))


def low_wall(w_m=3.0, h_m=0.4):
    w, h = w_m * PPM, h_m * PPM
    defs = f'<clipPath id="c"><rect x="1" y="1" width="{w - 2:.1f}" height="{h - 2:.1f}"/></clipPath>'
    hatch = []
    x = -h
    while x < w:
        hatch.append(line(x, h, x + h, 0, GREY_D, 1.0))
        x += 9
    b = [rect(1, 1, w - 2, h - 2, GREY_L, 0, None), f'<g clip-path="url(#c)">{"".join(hatch)}</g>',
         rect(1, 1, w - 2, h - 2, "none", 0, INK, 2)]
    return svg(w_m, h_m, "".join(b), defs)


def woodpile(w_m=2.0, h_m=0.8):
    w, h = w_m * PPM, h_m * PPM
    b = [rect(1, 1, w - 2, h - 2, PAPER, 0, LINE, 1.2)]
    r = 7
    for row in range(int((h - 4) // (2 * r))):
        for col in range(int((w - 4) // (2 * r))):
            cx = 4 + r + col * 2 * r + (r if row % 2 else 0)
            if cx + r < w - 2:
                b.append(circle(cx, 4 + r + row * 2 * r, r - 1, WHITE, LINE, 1.2))
    return svg(w_m, h_m, "".join(b))


def picnic(w_m=1.8, h_m=1.6):
    w, h = w_m * PPM, h_m * PPM
    b = [rect(4, 6, w - 8, 22, WHITE, 2, LINE, 1.6),
         rect(4, h - 28, w - 8, 22, WHITE, 2, LINE, 1.6),
         rect(10, 40, w - 20, h - 80, WHITE, 2, INK, 2)]
    for i in range(1, 5):
        b.append(line(10 + i * (w - 20) / 5, 42, 10 + i * (w - 20) / 5, h - 42, FAINT, 1.0))
    return svg(w_m, h_m, "".join(b))


def ac_unit(w_m=0.8, h_m=0.6):
    w, h = w_m * PPM, h_m * PPM
    return svg(w_m, h_m, rect(2, 2, w - 4, h - 4, WHITE, 2, INK, 2) + circle(w / 2, h / 2, h / 2 - 7, "none", LINE, 1.5)
               + line(w / 2 - 12, h / 2, w / 2 + 12, h / 2, FAINT, 1.2) + line(w / 2, h / 2 - 12, w / 2, h / 2 + 12, FAINT, 1.2))


def bins(w_m=0.8, h_m=0.6):
    w, h = w_m * PPM, h_m * PPM
    return svg(w_m, h_m, rect(3, 3, w / 2 - 5, h - 6, PAPER, 4, LINE, 1.6) + rect(w / 2 + 2, 3, w / 2 - 5, h - 6, PAPER, 4, LINE, 1.6)
               + line(6, 10, w / 2 - 5, 10, FAINT, 1.0) + line(w / 2 + 5, 10, w - 6, 10, FAINT, 1.0))


def shed_roof(w_m=3.5, h_m=3.0):
    w, h = w_m * PPM, h_m * PPM
    b = [rect(1, 1, w - 2, h - 2, GREY_L, 0, INK, 3),
         line(1, 1, w - 1, h - 1, GREY_D, 1.4), line(w - 1, 1, 1, h - 1, GREY_D, 1.4)]
    return svg(w_m, h_m, "".join(b))


# ------------------------------------------------------------- furniture added for the ten maps
def bunk(w_m=2.0, h_m=0.9):
    w, h = w_m * PPM, h_m * PPM
    b = [rect(2, 2, w - 4, h - 4, WHITE, 2), rect(8, 8, w - 16, h - 16, "none", 2, FAINT, 1.2),
         rect(4, 4, 16, h - 8, GREY_L, 2, LINE, 1.4), rect(26, 12, 26, h - 24, PAPER, 5, LINE, 1.3),
         line(w - 6, 2, w - 6, h - 2, INK, 2.4), line(6, 2, 6, h - 2, INK, 2.4)]
    return svg(w_m, h_m, "".join(b))


def desk(w_m=1.4, h_m=0.7):
    w, h = w_m * PPM, h_m * PPM
    b = [rect(2, 2, w - 4, h * 0.62, WHITE, 1), rect(w - 34, 6, 26, h * 0.62 - 10, "none", 1, FAINT, 1.2),
         rect(w * 0.18, 10, w * 0.34, 8, PAPER, 1, LINE, 1.2),
         path(f"M{w * 0.32},{h * 0.66} A{h * 0.3},{h * 0.3} 0 0 0 {w * 0.62},{h * 0.66}", "none", LINE, 1.5),
         rect(w * 0.36, h * 0.66, w * 0.22, h * 0.26, PAPER, 6, LINE, 1.4)]
    return svg(w_m, h_m, "".join(b))


def chair(s=0.5):
    w = s * PPM
    return svg(s, s, rect(4, 4, w - 8, w - 8, WHITE, 6, LINE, 1.6) + rect(4, 4, w - 8, 9, GREY_L, 4, LINE, 1.4))


def table(w_m=2.4, h_m=1.0):
    w, h = w_m * PPM, h_m * PPM
    return svg(w_m, h_m, rect(2, 2, w - 4, h - 4, WHITE, 3) + rect(10, 10, w - 20, h - 20, "none", 2, FAINT, 1.0))


def shelving(w_m=4.0, h_m=1.0):
    """Store gondola: double-sided shelving seen from above."""
    w, h = w_m * PPM, h_m * PPM
    b = [rect(2, 2, w - 4, h - 4, WHITE, 1, INK, 2), line(2, h / 2, w - 2, h / 2, LINE, 1.6)]
    x = 2
    while x < w - 4:
        b.append(rect(x + 3, 6, 14, h / 2 - 10, PAPER, 1, FAINT, 1.0))
        b.append(rect(x + 3, h / 2 + 4, 14, h / 2 - 10, PAPER, 1, FAINT, 1.0))
        x += 20
    return svg(w_m, h_m, "".join(b))


def rack(w_m=6.0, h_m=1.1):
    """Pallet racking bay run: uprights, beams and loaded pallets with the X of an overhead."""
    w, h = w_m * PPM, h_m * PPM
    b = [rect(2, 2, w - 4, h - 4, GREY_L, 0, INK, 2.2)]
    bay = 2.7 * PPM / 1.0 * (w_m / max(1, round(w_m / 2.7))) / w_m
    nb = max(1, round(w_m / 2.7))
    bw = (w - 4) / nb
    for i in range(nb):
        x0 = 2 + i * bw
        b.append(rect(x0 + 6, 8, bw - 12, h - 16, WHITE, 1, LINE, 1.4))
        b.append(line(x0 + 6, 8, x0 + bw - 6, h - 8, FAINT, 1.0))
        b.append(line(x0 + bw - 6, 8, x0 + 6, h - 8, FAINT, 1.0))
        b.append(rect(x0 - 2, 2, 5, h - 4, INK, 0, None))
    b.append(rect(w - 6, 2, 5, h - 4, INK, 0, None))
    return svg(w_m, h_m, "".join(b))


def crate(s=1.2):
    w = s * PPM
    return svg(s, s, rect(3, 3, w - 6, w - 6, PAPER, 0, INK, 2) + rect(10, 10, w - 20, w - 20, "none", 0, LINE, 1.2)
               + line(10, 10, w - 10, w - 10, LINE, 1.2) + line(w - 10, 10, 10, w - 10, LINE, 1.2))


def pallet(w_m=1.2, h_m=1.0):
    w, h = w_m * PPM, h_m * PPM
    b = [rect(2, 2, w - 4, h - 4, "none", 0, LINE, 1.6)]
    for i in range(5):
        y = 4 + i * (h - 8) / 5
        b.append(rect(4, y + 1, w - 8, (h - 8) / 5 - 4, PAPER, 0, FAINT, 1.0))
    return svg(w_m, h_m, "".join(b))


def cabinet(w_m=0.5, h_m=0.6):
    w, h = w_m * PPM, h_m * PPM
    b = [rect(2, 2, w - 4, h - 4, WHITE, 1, INK, 1.8)]
    for i in range(1, 4):
        b.append(line(5, i * h / 4, w - 5, i * h / 4, FAINT, 1.1))
    return svg(w_m, h_m, "".join(b))


def stove(w_m=0.7, h_m=0.65):
    w, h = w_m * PPM, h_m * PPM
    b = [rect(2, 2, w - 4, h - 4, WHITE, 2, INK, 1.8)]
    for (fx, fy) in ((0.3, 0.32), (0.7, 0.32), (0.3, 0.72), (0.7, 0.72)):
        b.append(circle(w * fx, h * fy, 8, "none", LINE, 1.4))
    return svg(w_m, h_m, "".join(b))


def washer(s=0.65):
    w = s * PPM
    return svg(s, s, rect(2, 2, w - 4, w - 4, WHITE, 3, INK, 1.8) + circle(w / 2, w / 2 + 3, w * 0.3, PAPER, LINE, 1.5)
               + line(6, 9, w - 6, 9, FAINT, 1.1))


def stairs(w_m=1.2, h_m=3.0):
    """Stair run in plan: treads, a break line and the up arrow (runs toward +y)."""
    w, h = w_m * PPM, h_m * PPM
    b = [rect(2, 2, w - 4, h - 4, WHITE, 0, INK, 2)]
    n = int(h_m / 0.28)
    for i in range(1, n):
        y = 2 + i * (h - 4) / n
        b.append(line(2, y, w - 2, y, LINE, 1.2))
    b.append(line(w / 2, h - 10, w / 2, 16, INK, 1.6))
    b.append(path(f"M{w / 2 - 7},{28} L{w / 2},{14} L{w / 2 + 7},{28}", "none", INK, 1.6))
    b.append(line(2, h * 0.55, w - 2, h * 0.45, INK, 1.4))
    return svg(w_m, h_m, "".join(b))


def lockers(w_m=2.4, h_m=0.5):
    w, h = w_m * PPM, h_m * PPM
    b = [rect(2, 2, w - 4, h - 4, WHITE, 0, INK, 1.8)]
    n = int(w_m / 0.4)
    for i in range(1, n):
        b.append(line(2 + i * (w - 4) / n, 4, 2 + i * (w - 4) / n, h - 4, LINE, 1.1))
    return svg(w_m, h_m, "".join(b))


def checkout(w_m=2.0, h_m=0.8):
    w, h = w_m * PPM, h_m * PPM
    return svg(w_m, h_m, rect(2, 2, w - 4, h - 4, WHITE, 2, INK, 2) + rect(w - 46, 8, 34, 26, PAPER, 2, LINE, 1.4)
               + line(10, h - 12, w - 60, h - 12, FAINT, 1.1, "6 4"))


def cooler(w_m=3.0, h_m=0.8):
    w, h = w_m * PPM, h_m * PPM
    b = [rect(2, 2, w - 4, h - 4, WHITE, 1, INK, 2), line(2, h - 14, w - 2, h - 14, LINE, 1.2)]
    n = int(w_m / 0.75)
    for i in range(1, n):
        b.append(line(2 + i * (w - 4) / n, 4, 2 + i * (w - 4) / n, h - 4, FAINT, 1.1))
    return svg(w_m, h_m, "".join(b))


def dumpster(w_m=1.9, h_m=1.1):
    w, h = w_m * PPM, h_m * PPM
    return svg(w_m, h_m, rect(3, 3, w - 6, h - 6, GREY_L, 3, INK, 2.2) + line(w / 2, 4, w / 2, h - 4, LINE, 1.4)
               + rect(-1, h * 0.3, 6, h * 0.4, GREY_D, 1, None) + rect(w - 5, h * 0.3, 6, h * 0.4, GREY_D, 1, None))


def van(w_m=5.0, h_m=2.0):
    w, h = w_m * PPM, h_m * PPM
    b = [rect(4, 4, w - 8, h - 8, WHITE, 22, INK, 2.2), rect(w * 0.06, 12, w * 0.16, h - 24, GREY_L, 10, LINE, 1.5),
         rect(w * 0.26, 10, w * 0.68, h - 20, "none", 4, FAINT, 1.2), line(w * 0.6, 10, w * 0.6, h - 10, FAINT, 1.0),
         rect(w * 0.14, 0, 30, 6, GREY_D, 2, None), rect(w * 0.76, 0, 30, 6, GREY_D, 2, None),
         rect(w * 0.14, h - 6, 30, 6, GREY_D, 2, None), rect(w * 0.76, h - 6, 30, 6, GREY_D, 2, None)]
    return svg(w_m, h_m, "".join(b))


def truck(w_m=7.5, h_m=2.5):
    w, h = w_m * PPM, h_m * PPM
    cab = w * 0.24
    b = [rect(4, 6, cab - 8, h - 12, WHITE, 16, INK, 2.2), rect(16, 14, cab * 0.4, h - 28, GREY_L, 8, LINE, 1.4),
         rect(cab, 2, w - cab - 4, h - 4, PAPER, 2, INK, 2.4)]
    for i in range(1, 9):
        x = cab + i * (w - cab - 4) / 9
        b.append(line(x, 6, x, h - 6, FAINT, 1.0))
    return svg(w_m, h_m, "".join(b))


def container(w_m=6.1, h_m=2.44):
    w, h = w_m * PPM, h_m * PPM
    b = [rect(2, 2, w - 4, h - 4, GREY_L, 0, INK, 2.4)]
    x = 10
    while x < w - 10:
        b.append(line(x, 6, x, h - 6, GREY_D, 1.0))
        x += 10
    b.append(rect(w - 14, 4, 10, h - 8, WHITE, 0, LINE, 1.2))
    return svg(w_m, h_m, "".join(b))


def sandbags(w_m=2.4, h_m=0.6):
    w, h = w_m * PPM, h_m * PPM
    b = []
    rw = 0.55 * PPM
    for row in range(2):
        x = 2 + (rw / 2 if row else 0)
        while x + rw <= w - 2 + 1:
            b.append(rect(x, 2 + row * (h - 4) / 2, rw - 2, (h - 4) / 2 - 1, PAPER, 9, LINE, 1.4))
            x += rw
    return svg(w_m, h_m, "".join(b))


def tank(d_m=2.2):
    w = d_m * PPM
    c = w / 2
    return svg(d_m, d_m, circle(c, c, c - 3, WHITE, INK, 2.4) + circle(c, c, c * 0.62, "none", FAINT, 1.2)
               + circle(c, c, 6, GREY_D, None))


def generator(w_m=1.6, h_m=0.9):
    w, h = w_m * PPM, h_m * PPM
    b = [rect(3, 3, w - 6, h - 6, WHITE, 3, INK, 2), rect(10, 10, w * 0.3, h - 20, PAPER, 2, LINE, 1.2)]
    for i in range(5):
        b.append(line(w * 0.5 + i * 9, 10, w * 0.5 + i * 9, h - 10, FAINT, 1.1))
    return svg(w_m, h_m, "".join(b))


def bench(w_m=1.6, h_m=0.5):
    w, h = w_m * PPM, h_m * PPM
    return svg(w_m, h_m, rect(2, 4, w - 4, h - 8, WHITE, 2, LINE, 1.6) + line(6, h / 2, w - 6, h / 2, FAINT, 1.0))


def planter(s=1.2):
    w = s * PPM
    rng = random.Random(13)
    return svg(s, s, rect(3, 3, w - 6, w - 6, PAPER, 2, INK, 2) + path(blob_path(w / 2, w / 2, w * 0.3, rng, 7, 0.2), "none", FAINT, 1.4))


def barrier(w_m=3.0, h_m=0.6):
    w, h = w_m * PPM, h_m * PPM
    return svg(w_m, h_m, rect(2, 2, w - 4, h - 4, GREY_L, 4, INK, 2) + rect(10, h / 2 - 5, w - 20, 10, WHITE, 3, LINE, 1.2))


def forklift(w_m=2.6, h_m=1.2):
    w, h = w_m * PPM, h_m * PPM
    b = [rect(w * 0.3, 4, w * 0.68, h - 8, WHITE, 8, INK, 2.2), rect(w * 0.42, 14, w * 0.3, h - 28, GREY_L, 4, LINE, 1.4),
         rect(2, h * 0.2, w * 0.3, 7, GREY_D, 1, None), rect(2, h * 0.8 - 7, w * 0.3, 7, GREY_D, 1, None),
         rect(w * 0.28, 4, 6, h - 8, INK, 0, None)]
    return svg(w_m, h_m, "".join(b))


# ------------------------------------------------------------- blood and residue
def splat(seed, size_m=1.4):
    rng = random.Random(seed)
    w = size_m * PPM
    c = w / 2
    b = [path(blob_path(c, c, w * 0.16, rng, 8, 0.45), BLOOD, None, 0, ' opacity="0.92"')]
    for _ in range(26):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(w * 0.14, w * 0.46)
        r = max(1.2, rng.gauss(4.5, 2.5) * (1.2 - d / w))
        b.append(circle(c + math.cos(a) * d, c + math.sin(a) * d, r, BLOOD if rng.random() < 0.7 else BLOOD_D, None, 0,
                        f' opacity="{rng.uniform(0.6, 0.95):.2f}"'))
    return svg(size_m, size_m, "".join(b))


def spray(seed, len_m=2.2, wid_m=0.9):
    """Directional exit spray; the impact point is at the left, the spray runs toward +x."""
    rng = random.Random(seed)
    w, h = len_m * PPM, wid_m * PPM
    cy = h / 2
    b = [path(blob_path(18, cy, 14, rng, 6, 0.4), BLOOD, None, 0, ' opacity="0.9"')]
    for _ in range(60):
        t = rng.random() ** 1.6
        x = 18 + t * (w - 30)
        spread = (0.08 + 0.42 * t) * h / 2
        y = cy + rng.gauss(0, spread * 0.6)
        if abs(y - cy) > h / 2 - 4:
            continue
        r = max(1.0, (6.5 - 5 * t) * rng.uniform(0.4, 1.1))
        if rng.random() < 0.35:   # elongated droplet pointing along the spray
            b.append(ellipse(x, y, r * 2.2, r * 0.8, BLOOD, None, 0, f' opacity="{rng.uniform(0.6, 0.95):.2f}"'))
        else:
            b.append(circle(x, y, r, BLOOD if rng.random() < 0.75 else BLOOD_L, None, 0, f' opacity="{rng.uniform(0.55, 0.95):.2f}"'))
    return svg(len_m, wid_m, "".join(b))


def wall_smear(seed, len_m=1.0, wid_m=0.24):
    rng = random.Random(seed)
    w, h = len_m * PPM, wid_m * PPM
    b = []
    x = 4
    while x < w - 6:
        r = rng.uniform(2, 7) * (1 - x / w * 0.6)
        b.append(ellipse(x, h / 2 + rng.uniform(-3, 3), r * 1.6, r, BLOOD, None, 0, f' opacity="{rng.uniform(0.6, 0.95):.2f}"'))
        x += rng.uniform(3, 9)
    return svg(len_m, wid_m, "".join(b))


def pool(seed, size_m=1.6):
    rng = random.Random(seed)
    w = size_m * PPM
    c = w / 2
    return svg(size_m, size_m, path(blob_path(c, c, w * 0.40, rng, 7, 0.22), BLOOD_D, None, 0, ' opacity="0.88"')
               + path(blob_path(c - 6, c - 4, w * 0.26, rng, 6, 0.25), BLOOD, None, 0, ' opacity="0.7"'))


def stain(seed, size_m=0.3):
    rng = random.Random(seed)
    w = size_m * PPM
    c = w / 2
    b = [path(blob_path(c, c, w * 0.26, rng, 6, 0.4), BLOOD, None, 0, ' opacity="0.92"')]
    for _ in range(5):
        a = rng.uniform(0, math.tau)
        b.append(circle(c + math.cos(a) * w * 0.36, c + math.sin(a) * w * 0.36, rng.uniform(1, 2.5), BLOOD_D, None))
    return svg(size_m, size_m, "".join(b))


def drip(seed):
    rng = random.Random(seed)
    w = 0.12 * PPM
    return svg(0.12, 0.12, circle(w / 2, w / 2, rng.uniform(1.6, 3.2), BLOOD, None, 0, ' opacity="0.85"'))


def chip():
    w = 0.14 * PPM
    c = w / 2
    pts = " ".join(f"{c + math.cos(a) * r:.1f},{c + math.sin(a) * r:.1f}"
                   for a, r in zip([i * math.tau / 7 for i in range(7)], [4.5, 2.2, 5, 2.6, 4, 2, 4.8]))
    return svg(0.14, 0.14, f'<polygon points="{pts}" fill="#2a2a2a" opacity="0.9"/>')


def casing():
    return svg(0.08, 0.04, rect(0.5, 0.5, 5.4, 2.2, "#9a9a9a", 1, "#555555", 0.8))


def plate_scuff():
    w = 0.16 * PPM
    return svg(0.16, 0.16, circle(w / 2, w / 2, 4, "#cfcfcf", "#5a5a5a", 1.2))


def flash():
    w = 0.5 * PPM
    c = w / 2
    pts = []
    for i in range(10):
        a = i / 10 * math.tau
        r = c - 2 if i % 2 == 0 else c * 0.35
        pts.append(f"{c + math.cos(a) * r:.1f},{c + math.sin(a) * r:.1f}")
    return svg(0.5, 0.5, f'<polygon points="{" ".join(pts)}" fill="#ffffff" stroke="#1c1c1c" stroke-width="1.4"/>')


def north_arrow():
    w, h = 0.9 * PPM, 1.3 * PPM
    c = w / 2
    return svg(0.9, 1.3, circle(c, h - c, c - 4, "none", INK, 1.6)
               + path(f"M{c},{6} L{c + 12},{h - c} L{c},{h - c - 10} Z", INK, INK, 1.2)
               + path(f"M{c},{6} L{c - 12},{h - c} L{c},{h - c - 10} Z", WHITE, INK, 1.2))


def icon_app():
    # 128 px app icon: a plan-view figure with one red stain on paper
    body = (rect(0, 0, 128, 128, PAPER, 0, None) + rect(6, 6, 116, 116, "none", 0, INK, 6)
            + ellipse(60, 64, 22, 40, WHITE, INK, 4) + circle(64, 64, 16, WHITE, INK, 4)
            + path(blob_path(84, 82, 12, random.Random(3), 7, 0.4), BLOOD, None))
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">{body}</svg>\n'


# ------------------------------------------------------------- manifest
ASSETS = {
    "op/a_stand.svg": lambda: operator("a"),
    "op/b_stand.svg": lambda: operator("b"),
    "op/a_down.svg": lambda: operator_down("a"),
    "op/b_down.svg": lambda: operator_down("b"),
    "op/c_stand.svg": lambda: civilian(),
    "op/c_down.svg": civilian_down,
    "op/rifle.svg": lambda: weapon("rifle"),
    "op/pistol.svg": lambda: weapon("pistol"),
    "furn/bed.svg": bed, "furn/sofa.svg": sofa, "furn/armchair.svg": armchair,
    "furn/coffee_table.svg": coffee_table, "furn/bookshelf.svg": bookshelf, "furn/counter.svg": counter,
    "furn/fridge.svg": fridge, "furn/dining.svg": dining, "furn/tub.svg": tub, "furn/toilet.svg": toilet,
    "furn/basin.svg": basin, "furn/dresser.svg": dresser, "furn/wardrobe.svg": wardrobe,
    "yard/car.svg": car, "yard/tree.svg": tree, "yard/hedge.svg": hedge, "yard/drum.svg": drum,
    "yard/low_wall.svg": low_wall, "yard/woodpile.svg": woodpile, "yard/picnic.svg": picnic,
    "yard/ac_unit.svg": ac_unit, "yard/bins.svg": bins, "yard/shed.svg": shed_roof,
    "fx/chip.svg": chip, "fx/casing.svg": casing, "fx/scuff.svg": plate_scuff, "fx/flash.svg": flash,
    "fx/pool.svg": lambda: pool(5), "fx/pool2.svg": lambda: pool(9),
    "fx/drip1.svg": lambda: drip(1), "fx/drip2.svg": lambda: drip(2),
    "fx/stain1.svg": lambda: stain(21), "fx/stain2.svg": lambda: stain(22), "fx/stain3.svg": lambda: stain(23),
    "fx/smear1.svg": lambda: wall_smear(31), "fx/smear2.svg": lambda: wall_smear(32),
    "ui/north.svg": north_arrow,
    "furn/bunk.svg": bunk, "furn/desk.svg": desk, "furn/chair.svg": chair, "furn/table.svg": table,
    "furn/shelving.svg": shelving, "furn/rack.svg": rack, "furn/crate.svg": crate, "furn/pallet.svg": pallet,
    "furn/cabinet.svg": cabinet, "furn/stove.svg": stove, "furn/washer.svg": washer, "furn/stairs.svg": stairs,
    "furn/lockers.svg": lockers, "furn/checkout.svg": checkout, "furn/cooler.svg": cooler,
    "yard/dumpster.svg": dumpster, "yard/van.svg": van, "yard/truck.svg": truck, "yard/container.svg": container,
    "yard/sandbags.svg": sandbags, "yard/tank.svg": tank, "yard/generator.svg": generator, "yard/bench.svg": bench,
    "yard/planter.svg": planter, "yard/barrier.svg": barrier, "yard/forklift.svg": forklift,
}
for i in range(1, 5):
    ASSETS[f"fx/splat{i}.svg"] = (lambda i=i: splat(100 + i))
    ASSETS[f"fx/spray{i}.svg"] = (lambda i=i: spray(200 + i))


# ------------------------------------------------------------- city factions and vehicles
# Greyscale like everything else: factions differ by tone and by the mark on the
# shoulders (the same mark hatches their territory on the city plan).
FACTION_LOOK = {
    # body fill, head fill, mark
    "pd": ("#5c5c5c", WHITE, "cap"),
    "qrf": ("#2a2a2a", "#6a6a6a", "helmet"),
    "g1": ("#ececec", WHITE, "dots"),
    "g2": ("#c4c4c4", WHITE, "bands"),
    "g3": ("#a3a3a3", WHITE, "hatch"),
    "g4": ("#d6d6d6", WHITE, "check"),
    "med": (WHITE, WHITE, "cross"),
    "pmed": (GREY_L, WHITE, "cross"),
}


def _marks(mark, cx, cy):
    b = []
    if mark == "dots":
        for k in range(-2, 3):
            b.append(circle(cx - 3, cy + k * 8, 2.0, INK, None))
    elif mark == "bands":
        for k in (-12, 0, 12):
            b.append(line(cx - 11, cy + k, cx + 7, cy + k, INK, 2.0))
    elif mark == "hatch":
        for k in range(-3, 4):
            b.append(line(cx - 9, cy + k * 6 - 3, cx + 5, cy + k * 6 + 3, INK, 1.2))
    elif mark == "check":
        for k in range(-3, 4):
            b.append(line(cx - 9, cy + k * 6 - 3, cx + 5, cy + k * 6 + 3, INK, 1.0))
            b.append(line(cx - 9, cy + k * 6 + 3, cx + 5, cy + k * 6 - 3, INK, 1.0))
    elif mark == "cross":
        b.append(rect(cx - 10, cy - 3, 14, 6, INK, 0, None))
        b.append(rect(cx - 6, cy - 10, 6, 20, INK, 0, None))
    return b


def operator_f(key):
    """Faction figure, facing +x. 0.8 x 0.8 m canvas."""
    body, head, mark = FACTION_LOOK[key]
    w = h = 0.8 * PPM
    cx, cy = w / 2, h / 2
    b = [ellipse(cx - 2, cy, 11, 23, body, INK, 2.2)]
    b += _marks(mark, cx, cy)
    b.append(ellipse(cx - 2, cy, 11, 23, "none", INK, 2.2))
    b.append(path(f"M{cx - 2},{cy - 19} Q{cx + 12},{cy - 14} {cx + 22},{cy - 2}", "none", INK, 2.0))
    b.append(path(f"M{cx - 2},{cy + 19} Q{cx + 10},{cy + 12} {cx + 16},{cy + 2}", "none", INK, 2.0))
    b.append(circle(cx + 1, cy, 8.5, head, INK, 2.2))
    if mark == "cap":
        b.append(path(f"M{cx + 3},{cy - 8} A8.5 8.5 0 0 1 {cx + 3},{cy + 8} L{cx + 12},{cy + 5} L{cx + 12},{cy - 5} Z", INK, INK, 1.0))
    elif mark == "helmet":
        b.append(circle(cx + 1, cy, 10.5, "none", INK, 2.6))
    b.append(line(cx + 9, cy, cx + 12, cy, INK, 2.0))
    return svg(0.8, 0.8, "".join(b))


def operator_f_down(key):
    body, head, mark = FACTION_LOOK[key]
    w, h = 1.9 * PPM, 0.9 * PPM
    cy = h / 2
    b = [path(f"M{20},{cy - 9} L{62},{cy - 7} M{20},{cy + 9} L{62},{cy + 6}", "none", INK, 7),
         path(f"M{20},{cy - 9} L{62},{cy - 7} M{20},{cy + 9} L{62},{cy + 6}", "none", body, 4),
         rect(58, cy - 20, 54, 40, body, 10, INK, 2.2)]
    if mark == "cross":
        b.append(rect(76, cy - 4, 18, 8, INK, 0, None))
        b.append(rect(81, cy - 10, 8, 20, INK, 0, None))
    elif mark == "bands":
        for x in (68, 85, 102):
            b.append(line(x, cy - 18, x, cy + 18, INK, 2.0))
    elif mark == "dots":
        for x in range(66, 108, 9):
            b.append(circle(x, cy, 2.2, INK, None))
    elif mark in ("hatch", "check"):
        for k in range(0, 8):
            b.append(line(62 + k * 6, cy - 16, 68 + k * 6, cy + 16, INK, 1.0))
            if mark == "check":
                b.append(line(68 + k * 6, cy - 16, 62 + k * 6, cy + 16, INK, 1.0))
    b.append(rect(58, cy - 20, 54, 40, "none", 10, INK, 2.2))
    b.append(path(f"M{100},{cy - 18} Q{112},{cy - 34} {96},{cy - 32}", "none", INK, 2.2))
    b.append(path(f"M{100},{cy + 18} Q{120},{cy + 30} {108},{cy + 34}", "none", INK, 2.2))
    b.append(circle(124, cy - 2, 10, head, INK, 2.2))
    if mark == "helmet":
        b.append(circle(124, cy - 2, 12, "none", INK, 2.4))
    elif mark == "cap":
        b.append(path(f"M{126},{cy - 11} A10 10 0 0 1 {126},{cy + 7} L{136},{cy + 4} L{136},{cy - 8} Z", INK, INK, 1.0))
    return svg(1.9, 0.9, "".join(b))


def _wheels(w, h, f1, f2):
    return [rect(w * f1, 0, 30, 6, GREY_D, 2, None), rect(w * f2, 0, 30, 6, GREY_D, 2, None),
            rect(w * f1, h - 6, 30, 6, GREY_D, 2, None), rect(w * f2, h - 6, 30, 6, GREY_D, 2, None)]


def police_car(w_m=4.6, h_m=1.9):
    """Patrol car in plan, nose toward +x: white body, dark doors and roof bar."""
    w, h = w_m * PPM, h_m * PPM
    b = [rect(4, 4, w - 8, h - 8, WHITE, 34, INK, 2.2),
         rect(w * 0.30, 6, w * 0.34, h - 12, "#3a3a3a", 6, None),
         rect(w * 0.33, 14, w * 0.30, h - 28, GREY_L, 14, LINE, 1.6),
         rect(w * 0.45, 12, 12, h - 24, INK, 3, None),
         line(w * 0.12, 20, w * 0.12, h - 20, FAINT, 1.2),
         rect(w * 0.70, 18, w * 0.12, h - 36, "none", 8, LINE, 1.4)] + _wheels(w, h, 0.18, 0.70)
    return svg(w_m, h_m, "".join(b))


def police_van(w_m=5.6, h_m=2.1):
    """Tactical van: dark grey box, cab forward."""
    w, h = w_m * PPM, h_m * PPM
    b = [rect(4, 4, w - 8, h - 8, "#3e3e3e", 20, INK, 2.2), rect(w * 0.72, 12, w * 0.13, h - 24, GREY_L, 10, LINE, 1.5),
         rect(w * 0.06, 10, w * 0.6, h - 20, "none", 4, GREY_M, 1.2), rect(w * 0.64, 10, 12, h - 20, INK, 3, None),
         line(w * 0.10, h / 2, w * 0.58, h / 2, GREY_M, 1.2)] + _wheels(w, h, 0.14, 0.76)
    return svg(w_m, h_m, "".join(b))


def ambulance(police=False, w_m=6.0, h_m=2.2):
    w, h = w_m * PPM, h_m * PPM
    band = "#3e3e3e" if police else GREY_M
    b = [rect(4, 4, w - 8, h - 8, WHITE, 18, INK, 2.2), rect(w * 0.76, 12, w * 0.12, h - 24, GREY_L, 10, LINE, 1.5),
         rect(8, h * 0.5 - 5, w * 0.66, 10, band, 0, None),
         rect(w * 0.30 - 24, h * 0.5 - 8, 48, 16, INK, 0, None), rect(w * 0.30 - 8, h * 0.5 - 24, 16, 48, INK, 0, None),
         rect(w * 0.70, 10, 12, h - 20, INK, 3, None)] + _wheels(w, h, 0.14, 0.78)
    return svg(w_m, h_m, "".join(b))


def stretcher(w_m=2.0, h_m=0.6):
    w, h = w_m * PPM, h_m * PPM
    return svg(w_m, h_m, rect(6, 4, w - 12, h - 8, WHITE, 4, INK, 1.8) + line(0, 6, w, 6, INK, 2.4)
               + line(0, h - 6, w, h - 6, INK, 2.4))


for _k in FACTION_LOOK:
    ASSETS[f"op/{_k}_stand.svg"] = (lambda k=_k: operator_f(k))
    ASSETS[f"op/{_k}_down.svg"] = (lambda k=_k: operator_f_down(k))
ASSETS["veh/police_car.svg"] = police_car
ASSETS["veh/police_van.svg"] = police_van
ASSETS["veh/ambulance.svg"] = lambda: ambulance(False)
ASSETS["veh/police_ambulance.svg"] = lambda: ambulance(True, 5.6, 2.1)
ASSETS["fx/stretcher.svg"] = stretcher


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default="assets/svg")
    ap.add_argument("--list", action="store_true")
    a = ap.parse_args()
    for rel, fn in ASSETS.items():
        if a.list:
            print(rel)
            continue
        dst = os.path.join(a.out, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        with open(dst, "w", encoding="utf-8") as f:
            f.write(fn())
    if not a.list:
        with open("icon.svg", "w", encoding="utf-8") as f:
            f.write(icon_app())
        with open(os.path.join(a.out, "manifest.json"), "w", encoding="utf-8") as f:
            json.dump({"generator": "tools/make_placeholders.py", "license": "original, project-owned",
                       "px_per_metre": PPM, "files": list(ASSETS)}, f, indent=1)
        print(f"wrote {len(ASSETS)} files to {a.out}")


if __name__ == "__main__":
    main()
