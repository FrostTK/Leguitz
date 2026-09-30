#!/usr/bin/env python3
"""Generates the Phase 0 placeholder pixel art.

These sprites only exist to make the foundations testable. Phase 2 replaces
them with the full art pipeline (palettes, variants, autotile transitions,
normal and emission maps).

Usage: python3 tools/gen_placeholder_art.py
Output:
  assets/textures/tiles/terrain_atlas.png   (16 px grid, see TileAtlas.gd)
  assets/textures/entities/player_placeholder.png (4 frames of 16x24)
"""

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
TILE = 16
VARIANTS = 4


def hex_rgba(value, alpha=255):
    value = value.lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), alpha)


class Canvas:
    def __init__(self, width, height):
        self.img = np.zeros((height, width, 4), dtype=np.uint8)

    def put(self, x, y, color):
        h, w = self.img.shape[:2]
        if 0 <= x < w and 0 <= y < h:
            self.img[y, x] = color

    def fill(self, x0, y0, w, h, color):
        self.img[y0:y0 + h, x0:x0 + w] = color

    def blit(self, other, x, y):
        h, w = other.img.shape[:2]
        region = self.img[y:y + h, x:x + w]
        mask = other.img[:, :, 3] > 0
        region[mask] = other.img[mask]

    def save(self, path):
        path.parent.mkdir(parents=True, exist_ok=True)
        Image.fromarray(self.img, "RGBA").save(path)


# ---------------------------------------------------------------- ground tiles

def speckled(rng, base, dark, light, dark_density, light_density):
    tile = Canvas(TILE, TILE)
    tile.fill(0, 0, TILE, TILE, hex_rgba(base))
    for y in range(TILE):
        for x in range(TILE):
            roll = rng.random()
            if roll < dark_density:
                tile.put(x, y, hex_rgba(dark))
            elif roll > 1.0 - light_density:
                tile.put(x, y, hex_rgba(light))
    return tile


def grass(rng, base, dark, light, tufts):
    tile = speckled(rng, base, base, light, 0.0, 0.03)
    for _ in range(tufts):
        x, y = int(rng.integers(1, TILE - 1)), int(rng.integers(2, TILE))
        tile.put(x, y, hex_rgba(dark))
        tile.put(x - 1, y - 1, hex_rgba(dark))
        tile.put(x + 1, y - 1, hex_rgba(dark))
        if rng.random() < 0.5:
            tile.put(x, y - 2, hex_rgba(light))
    return tile


def water(rng, base, dark, light):
    tile = speckled(rng, base, dark, base, 0.05, 0.0)
    for _ in range(2):
        x, y = int(rng.integers(0, TILE - 4)), int(rng.integers(1, TILE - 1))
        for i in range(int(rng.integers(3, 6))):
            tile.put((x + i) % TILE, y, hex_rgba(light))
    return tile


def stone_floor(rng):
    tile = speckled(rng, "#8b8a93", "#74737e", "#a3a2ab", 0.08, 0.06)
    x, y = int(rng.integers(2, 12)), int(rng.integers(2, 12))
    for i in range(int(rng.integers(3, 6))):
        tile.put(x + i, y + (i // 2), hex_rgba("#5f5e69"))
    return tile


def snow(rng):
    tile = speckled(rng, "#eef3fa", "#d3deeb", "#ffffff", 0.07, 0.05)
    return tile


GROUND_ROWS = [
    # Order must match Tiles.Ground (id - 1 = row).
    lambda rng: water(rng, "#2d63ad", "#264f94", "#4a86cc"),        # DEEP_WATER
    lambda rng: water(rng, "#3f90d8", "#3780c4", "#7cc0f0"),        # WATER
    lambda rng: speckled(rng, "#ead38e", "#d5b86d", "#f6e7b2", 0.08, 0.06),  # SAND
    lambda rng: grass(rng, "#67ae3f", "#4b8f33", "#93cf55", 5),     # GRASS
    lambda rng: grass(rng, "#4a8c37", "#35702c", "#6fae45", 7),     # FOREST_GRASS
    stone_floor,                                                      # STONE_FLOOR
    snow,                                                             # SNOW
]


# ---------------------------------------------------------------- blocks

def shaded_blob(canvas, cx, cy, rx, ry, colors, outline):
    """Filled ellipse lit from the top-left, with a dark outline."""
    dark, mid, light, highlight = (hex_rgba(c) for c in colors)
    h, w = canvas.img.shape[:2]
    inside = np.zeros((h, w), dtype=bool)
    for y in range(h):
        for x in range(w):
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            d = dx * dx + dy * dy
            if d <= 1.0:
                inside[y, x] = True
                light_term = -(dx * 0.6 + dy * 0.8)
                if light_term > 0.55 and d < 0.5:
                    color = highlight
                elif light_term > 0.1:
                    color = light
                elif light_term > -0.45:
                    color = mid
                else:
                    color = dark
                canvas.put(x, y, color)
    edge = hex_rgba(outline)
    for y in range(h):
        for x in range(w):
            if inside[y, x]:
                continue
            for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + ox, y + oy
                if 0 <= nx < w and 0 <= ny < h and inside[ny, nx]:
                    canvas.put(x, y, edge)
                    break


def ground_shadow(canvas, cx, cy, rx, ry):
    h, w = canvas.img.shape[:2]
    for y in range(h):
        for x in range(w):
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            if dx * dx + dy * dy <= 1.0 and canvas.img[y, x, 3] == 0:
                canvas.put(x, y, (20, 30, 25, 70))


def tree():
    c = Canvas(TILE, TILE * 2)
    ground_shadow(c, 8, 29.5, 7, 2.5)
    c.fill(6, 20, 4, 11, hex_rgba("#6e4326"))
    c.fill(6, 20, 1, 11, hex_rgba("#8a5a33"))
    c.fill(9, 20, 1, 11, hex_rgba("#4f2f1a"))
    c.put(5, 30, hex_rgba("#4f2f1a"))
    c.put(10, 30, hex_rgba("#4f2f1a"))
    shaded_blob(c, 8, 12, 7.5, 9.5, ("#2d6a2b", "#3f8a36", "#5aa843", "#8bcf5c"), "#1c4221")
    return c


def pine():
    c = Canvas(TILE, TILE * 2)
    ground_shadow(c, 8, 29.5, 6, 2.5)
    c.fill(7, 24, 2, 7, hex_rgba("#5a3620"))
    tiers = [(4, 3), (9, 5), (14, 6), (19, 7)]
    for top, half in tiers:
        for row in range(6):
            span = int(half * (row + 1) / 6)
            y = top + row
            for x in range(8 - span, 8 + span):
                shade = "#2b6a45" if x < 8 else "#1f5236"
                if row == 0 or x in (8 - span, 8 + span - 1):
                    shade = "#163a28"
                c.put(x, y, hex_rgba(shade))
    c.put(8, 2, hex_rgba("#163a28"))
    c.put(7, 3, hex_rgba("#2b6a45"))
    return c


def rock():
    c = Canvas(TILE, TILE)
    ground_shadow(c, 8, 13.5, 7, 2.5)
    shaded_blob(c, 8, 9.5, 6.5, 5.5, ("#5c5b66", "#7c7b87", "#9d9ca7", "#c3c2cb"), "#393843")
    return c


def bush():
    c = Canvas(TILE, TILE)
    ground_shadow(c, 8, 13.5, 6.5, 2.5)
    shaded_blob(c, 8, 9.5, 6.0, 5.0, ("#2f6e2d", "#43903a", "#62b149", "#9ad766"), "#1c4221")
    c.put(5, 8, hex_rgba("#e0566b"))
    c.put(10, 10, hex_rgba("#e0566b"))
    return c


# ---------------------------------------------------------------- player

SKIN, SKIN_SHADE = "#f3c49b", "#d99c77"
HAIR, HAIR_SHADE = "#7a4524", "#56301a"
SHIRT, SHIRT_SHADE = "#d6524a", "#a63a37"
PANTS, PANTS_SHADE = "#3f5f9e", "#2d467a"
SHOES = "#3b2a22"
OUTLINE = "#2a1b17"


def player_frame(direction):
    c = Canvas(TILE, 24)
    ground_shadow(c, 8, 22.5, 5, 1.8)
    # legs & shoes
    c.fill(5, 17, 6, 4, hex_rgba(PANTS))
    c.fill(8, 17, 3, 4, hex_rgba(PANTS_SHADE))
    c.fill(7, 18, 2, 3, hex_rgba(PANTS_SHADE))
    c.fill(5, 21, 2, 1, hex_rgba(SHOES))
    c.fill(9, 21, 2, 1, hex_rgba(SHOES))
    # torso & arms
    c.fill(4, 11, 8, 6, hex_rgba(SHIRT))
    c.fill(4, 15, 8, 2, hex_rgba(SHIRT_SHADE))
    if direction in ("down", "up"):
        c.fill(3, 12, 1, 4, hex_rgba(SHIRT_SHADE))
        c.fill(12, 12, 1, 4, hex_rgba(SHIRT_SHADE))
        c.put(3, 16, hex_rgba(SKIN))
        c.put(12, 16, hex_rgba(SKIN))
    # head
    c.fill(4, 3, 8, 8, hex_rgba(SKIN))
    c.fill(4, 9, 8, 2, hex_rgba(SKIN_SHADE))
    c.fill(4, 2, 8, 3, hex_rgba(HAIR))
    c.fill(3, 3, 1, 5, hex_rgba(HAIR))
    c.fill(12, 3, 1, 5, hex_rgba(HAIR))
    if direction == "down":
        c.fill(5, 5, 6, 1, hex_rgba(HAIR_SHADE))
        c.put(6, 7, hex_rgba(OUTLINE))
        c.put(9, 7, hex_rgba(OUTLINE))
        c.put(7, 9, hex_rgba("#c9776a"))
        c.put(8, 9, hex_rgba("#c9776a"))
    elif direction == "up":
        c.fill(4, 3, 8, 7, hex_rgba(HAIR))
        c.fill(4, 8, 8, 2, hex_rgba(HAIR_SHADE))
    else:
        c.fill(4, 3, 8, 4, hex_rgba(HAIR))
        c.fill(4, 3, 4, 7, hex_rgba(HAIR))
        c.fill(4, 8, 4, 2, hex_rgba(HAIR_SHADE))
        c.put(10, 7, hex_rgba(OUTLINE))
        c.fill(12, 12, 1, 4, hex_rgba(SHIRT_SHADE))
        c.put(12, 16, hex_rgba(SKIN))
        if direction == "left":
            c.img = c.img[:, ::-1].copy()
    # outline around the whole character
    alpha = c.img[:, :, 3] >= 200
    h, w = alpha.shape
    edge = hex_rgba(OUTLINE)
    for y in range(h):
        for x in range(w):
            if alpha[y, x]:
                continue
            for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + ox, y + oy
                if 0 <= nx < w and 0 <= ny < h and alpha[ny, nx]:
                    c.put(x, y, edge)
                    break
    return c


# ---------------------------------------------------------------- main

def main():
    rng = np.random.default_rng(1234)
    atlas = Canvas(TILE * 8, TILE * 8)
    for row, make in enumerate(GROUND_ROWS):
        for variant in range(VARIANTS):
            atlas.blit(make(rng), variant * TILE, row * TILE)
    atlas.blit(tree(), 4 * TILE, 0)
    atlas.blit(pine(), 5 * TILE, 0)
    atlas.blit(rock(), 4 * TILE, 2 * TILE)
    atlas.blit(bush(), 5 * TILE, 2 * TILE)
    atlas.save(ROOT / "assets/textures/tiles/terrain_atlas.png")

    sheet = Canvas(TILE * 4, 24)
    for i, direction in enumerate(("down", "left", "right", "up")):
        sheet.blit(player_frame(direction), i * TILE, 0)
    sheet.save(ROOT / "assets/textures/entities/player_placeholder.png")
    print("Placeholder art generated.")


if __name__ == "__main__":
    main()
