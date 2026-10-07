# AMEEN: adds the UAE Dirham currency sign (U+20C3, Unicode 17) to the bundled
# Inter fonts (budget/assets/fonts/Inter-*.ttf). Inter is the global
# fontFamilyFallback, so every font choice in the app can render the sign
# without code changes.
#
# Safe to re-run (replaces the glyph if present). If upstream ever updates the
# Inter files, take their version and run this script again:
#   pip install fonttools
#   python scripts/add_dirham_glyph.py
import os

from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

FONTS_DIR = os.path.join(os.path.dirname(__file__), "..", "budget", "assets", "fonts")
CODEPOINT = 0x20C3
GLYPH_NAME = "uni20C3"

# Design space: cap height 700, left side bearing 30
CAP = 700
BOWL_FLAT_X = 330
BOWL_RIGHT = 640
BAR_LEFT, BAR_RIGHT = 30, 730
ADVANCE = 760
STEM_LEFT = 140


def cubic(p0, p1, p2, p3, steps=24):
    pts = []
    for i in range(1, steps + 1):
        t = i / steps
        mt = 1 - t
        pts.append((
            mt**3 * p0[0] + 3 * mt**2 * t * p1[0] + 3 * mt * t**2 * p2[0] + t**3 * p3[0],
            mt**3 * p0[1] + 3 * mt**2 * t * p1[1] + 3 * mt * t**2 * p2[1] + t**3 * p3[1],
        ))
    return pts


def bowl(left, right, top, bottom, flat):
    """Outline of a D from (left, top) clockwise round to (left, bottom)."""
    mid = (top + bottom) / 2
    k = 0.62
    pts = [(left, top), (flat, top)]
    pts += cubic((flat, top), (flat + (right - flat) * k, top), (right, mid + (top - mid) * k), (right, mid))
    pts += cubic((right, mid), (right, mid - (mid - bottom) * k), (flat + (right - flat) * k, bottom), (flat, bottom))
    pts.append((left, bottom))
    return pts


def contours_for(stem, bar):
    """stem: vertical stroke width, bar: horizontal stroke thickness."""
    stem_right = STEM_LEFT + stem
    inner_top, inner_bottom = CAP - stem, stem
    inner_right = BOWL_RIGHT - stem * 1.05
    bar_gap = 90
    upper = (CAP / 2 + bar_gap / 2, CAP / 2 + bar_gap / 2 + bar)
    lower = (CAP / 2 - bar_gap / 2 - bar, CAP / 2 - bar_gap / 2)
    bars = [lower, upper]

    inner = bowl(stem_right, inner_right, inner_top, inner_bottom, BOWL_FLAT_X)[1:-1]

    def inner_x_at(y):
        return min(inner, key=lambda p: abs(p[1] - y))[0]

    def counter_band(y_bottom, y_top):
        side = [p for p in inner if y_bottom < p[1] < y_top]
        pts = [(stem_right, y_top), (inner_x_at(y_top), y_top)] + side + \
              [(inner_x_at(y_bottom), y_bottom), (stem_right, y_bottom)]
        return list(reversed(pts))  # counter-clockwise: a hole

    result = [bowl(STEM_LEFT, BOWL_RIGHT, CAP, 0, BOWL_FLAT_X)]
    # The counter is split around the bars so the strokes stay solid across it
    edges = [inner_bottom, lower[0], lower[1], upper[0], upper[1], inner_top]
    for i in range(0, len(edges), 2):
        result.append(counter_band(edges[i], edges[i + 1]))
    for (b, t) in bars:
        result.append([(BAR_LEFT, b), (BAR_LEFT, t), (BAR_RIGHT, t), (BAR_RIGHT, b)])
    return result


def build_glyph(contours, scale):
    pen = TTGlyphPen(None)
    for c in contours:
        pts = [(round(x * scale), round(y * scale)) for x, y in c]
        dedup = [pts[0]] + [p for i, p in enumerate(pts[1:], 1) if p != pts[i - 1]]
        if dedup[0] == dedup[-1]:
            dedup = dedup[:-1]
        pen.moveTo(dedup[0])
        for p in dedup[1:]:
            pen.lineTo(p)
        pen.closePath()
    return pen.glyph()


def patch(file_name, stem, bar):
    path = os.path.join(FONTS_DIR, file_name)
    font = TTFont(path)
    scale = font["OS/2"].sCapHeight / CAP
    glyph = build_glyph(contours_for(stem, bar), scale)

    order = font.getGlyphOrder()
    if GLYPH_NAME not in order:
        font.setGlyphOrder(order + [GLYPH_NAME])
    font["glyf"][GLYPH_NAME] = glyph
    glyph.recalcBounds(font["glyf"])
    font["hmtx"][GLYPH_NAME] = (round(ADVANCE * scale), glyph.xMin)
    for table in font["cmap"].tables:
        if table.isUnicode():
            table.cmap[CODEPOINT] = GLYPH_NAME
    font["maxp"].numGlyphs = len(font.getGlyphOrder())
    font.save(path)
    print("Added U+20C3 to", os.path.abspath(path))


patch("Inter-Regular.ttf", stem=78, bar=48)
patch("Inter-Bold.ttf", stem=112, bar=66)
