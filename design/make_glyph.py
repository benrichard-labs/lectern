"""Generates the Lectern glyph SVG used by the app icon and the watch launcher icon.

Run: python3 -I design/make_glyph.py > mac/Lectern/AppIcon.icon/Assets/lectern.svg
"""

import math

CANVAS = 1024


def rounded_polygon(points, radius):
    """SVG path for a closed polygon whose corners are rounded with quadratic curves."""
    parts = []
    count = len(points)
    for i in range(count):
        prev_pt, vertex, next_pt = points[i - 1], points[i], points[(i + 1) % count]

        def toward(target):
            dx, dy = target[0] - vertex[0], target[1] - vertex[1]
            length = math.hypot(dx, dy)
            r = min(radius, length / 2)
            return vertex[0] + dx / length * r, vertex[1] + dy / length * r

        start, end = toward(prev_pt), toward(next_pt)
        parts.append(f"{'M' if i == 0 else 'L'} {start[0]:.1f} {start[1]:.1f}")
        parts.append(f"Q {vertex[0]:.1f} {vertex[1]:.1f} {end[0]:.1f} {end[1]:.1f}")
    parts.append("Z")
    return " ".join(parts)


def shifted(points, dy):
    return [(x, y + dy) for x, y in points]


# Shapes are drawn on a 1024 canvas, then shifted so the glyph's bounding box
# (gooseneck mic at the top, base at the bottom) sits on the canvas center.
TOP, BOTTOM = 186, 800
DY = CANVAS / 2 - (TOP + BOTTOM) / 2

desk = shifted([(272, 300), (752, 300), (712, 384), (312, 384)], DY)
body = shifted([(370, 408), (654, 408), (654, 724), (370, 724)], DY)
base = shifted([(318, 744), (706, 744), (706, 800), (318, 800)], DY)
# "Next" triangle cut out of the lectern's front panel.
arrow = shifted([(476, 508), (476, 624), (576, 566)], DY)

body_path = rounded_polygon(body, 26) + " " + rounded_polygon(arrow, 14)


def y(value):
    return value + DY


print(f"""<svg xmlns="http://www.w3.org/2000/svg" width="{CANVAS}" height="{CANVAS}" viewBox="0 0 {CANVAS} {CANVAS}">
  <g fill="#FFFFFF">
    <path d="M 640 {y(300):.1f} C 640 {y(250):.1f} 612 {y(232):.1f} 584 {y(222):.1f}" fill="none" stroke="#FFFFFF" stroke-width="18" stroke-linecap="round"/>
    <rect x="530" y="{y(186):.1f}" width="66" height="40" rx="20" transform="rotate(-20 563 {y(206):.1f})"/>
    <path d="{rounded_polygon(desk, 24)}"/>
    <path fill-rule="evenodd" d="{body_path}"/>
    <path d="{rounded_polygon(base, 28)}"/>
  </g>
</svg>""")
