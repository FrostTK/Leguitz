#!/usr/bin/env python3
"""Generates the placeholder pixel art (phases 0-1).

These sprites make the world readable until phase 2 replaces them with the
full art pipeline (autotile transitions, normal and emission maps, animated
water and wind).

Usage: python3 tools/gen_placeholder_art.py
Outputs (layouts must match src/client/tile_atlas.gd):
  assets/textures/tiles/ground_atlas.png  4 variants x one 16px row per ground id
  assets/textures/tiles/block_atlas.png   16 columns of 16x32 cells, cell = block id
  assets/textures/tiles/cliff_atlas.png   row 0: cliff faces & ramps, row 1: edge overlays
  assets/textures/entities/player_placeholder.png
"""

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
TILE = 16
VARIANTS = 4
BLOCK_COLUMNS = 16

# Must match the enums in src/sim/world/tiles.gd (order = id).
GROUNDS = [
    "NONE", "DEEP_WATER", "WATER", "SAND", "GRASS", "FOREST_GRASS", "STONE_FLOOR", "SNOW",
    "DIRT", "PODZOL", "DRY_GRASS", "JUNGLE_GRASS", "SWAMP_GRASS", "MEADOW_GRASS", "TAIGA_GRASS",
    "RED_SAND", "TERRACOTTA", "TERRACOTTA_LIGHT", "GRAVEL", "ICE", "MUD", "MYCELIUM",
    "DEEPSLATE_FLOOR", "LAVA", "SWAMP_WATER", "WARM_WATER",
]
BLOCKS = [
    "AIR", "OAK", "ROCK", "BUSH", "SPRUCE", "STONE", "DEEPSLATE", "COAL_ORE", "COPPER_ORE",
    "IRON_ORE", "GOLD_ORE", "LAPIS_ORE", "RUBY_ORE", "DIAMOND_ORE", "EMERALD_ORE", "BIRCH",
    "DARK_OAK", "JUNGLE_TREE", "ACACIA", "SNOWY_SPRUCE", "CACTUS", "DEAD_BUSH", "TALL_GRASS",
    "FERN", "FLOWER_RED", "FLOWER_YELLOW", "FLOWER_BLUE", "FLOWER_WHITE", "FLOWER_PINK",
    "MUSHROOM_RED", "MUSHROOM_BROWN", "BIG_MUSHROOM", "SUGAR_CANE", "LILY_PAD", "MOSSY_ROCK",
    "SANDSTONE", "BERRY_BUSH", "PACKED_ICE", "SWAMP_OAK",
]


def rgba(value, alpha=255):
    value = value.lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), alpha)


class Canvas:
    def __init__(self, width, height):
        self.img = np.zeros((height, width, 4), dtype=np.uint8)

    @property
    def w(self):
        return self.img.shape[1]

    @property
    def h(self):
        return self.img.shape[0]

    def put(self, x, y, color):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.img[y, x] = rgba(color) if isinstance(color, str) else color

    def fill(self, x0, y0, w, h, color):
        c = rgba(color) if isinstance(color, str) else color
        self.img[max(0, y0):max(0, y0 + h), max(0, x0):max(0, x0 + w)] = c

    def blit(self, other, x, y):
        h, w = other.img.shape[:2]
        region = self.img[y:y + h, x:x + w]
        mask = other.img[:, :, 3] > 0
        region[mask] = other.img[mask]

    def outline(self, color, threshold=200):
        solid = self.img[:, :, 3] >= threshold
        edge = rgba(color)
        for y in range(self.h):
            for x in range(self.w):
                if solid[y, x]:
                    continue
                for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + ox, y + oy
                    if 0 <= nx < self.w and 0 <= ny < self.h and solid[ny, nx]:
                        self.img[y, x] = edge
                        break

    def save(self, path):
        path.parent.mkdir(parents=True, exist_ok=True)
        Image.fromarray(self.img, "RGBA").save(path)


# ------------------------------------------------------------------ grounds

def speckled(rng, base, dark, light, dark_density, light_density):
    tile = Canvas(TILE, TILE)
    tile.fill(0, 0, TILE, TILE, base)
    for y in range(TILE):
        for x in range(TILE):
            roll = rng.random()
            if roll < dark_density:
                tile.put(x, y, dark)
            elif roll > 1.0 - light_density:
                tile.put(x, y, light)
    return tile


def grass(base, dark, light, tufts=6):
    def make(rng):
        tile = speckled(rng, base, base, light, 0.0, 0.03)
        for _ in range(tufts):
            x, y = int(rng.integers(1, TILE - 1)), int(rng.integers(2, TILE))
            tile.put(x, y, dark)
            tile.put(x - 1, y - 1, dark)
            tile.put(x + 1, y - 1, dark)
            if rng.random() < 0.5:
                tile.put(x, y - 2, light)
        return tile
    return make


def water(base, dark, light):
    def make(rng):
        tile = speckled(rng, base, dark, base, 0.05, 0.0)
        for _ in range(2):
            x, y = int(rng.integers(0, TILE - 4)), int(rng.integers(1, TILE - 1))
            for i in range(int(rng.integers(3, 6))):
                tile.put((x + i) % TILE, y, light)
        return tile
    return make


def pebbles(base, dark, light, count=7):
    def make(rng):
        tile = speckled(rng, base, dark, light, 0.06, 0.05)
        for _ in range(count):
            x, y = int(rng.integers(0, TILE - 1)), int(rng.integers(0, TILE - 1))
            tile.put(x, y, light)
            tile.put(x + 1, y, light)
            tile.put(x, y + 1, dark)
            tile.put(x + 1, y + 1, dark)
        return tile
    return make


def cracked(base, dark, light, crack):
    def make(rng):
        tile = speckled(rng, base, dark, light, 0.08, 0.06)
        x, y = int(rng.integers(2, 12)), int(rng.integers(2, 12))
        for i in range(int(rng.integers(3, 6))):
            tile.put(x + i, y + (i // 2), crack)
        return tile
    return make


def ice(rng):
    tile = speckled(rng, "#a9d3f2", "#93c3e8", "#d6ecfb", 0.05, 0.06)
    x, y = int(rng.integers(0, 8)), int(rng.integers(0, 8))
    for i in range(7):
        tile.put(x + i, y + i // 2, "#ffffff")
    return tile


def lava(rng):
    tile = speckled(rng, "#e8552a", "#b83a1c", "#ff9a3c", 0.12, 0.1)
    for _ in range(3):
        x, y = int(rng.integers(0, TILE - 5)), int(rng.integers(0, TILE))
        for i in range(int(rng.integers(3, 6))):
            tile.put(x + i, y, "#ffd24a")
    return tile


def terracotta(base, band):
    def make(rng):
        tile = speckled(rng, base, band, base, 0.04, 0.0)
        tile.fill(0, 5, TILE, 2, band)
        tile.fill(0, 12, TILE, 1, band)
        return tile
    return make


GROUND_MAKERS = {
    "DEEP_WATER": water("#2d63ad", "#264f94", "#4a86cc"),
    "WATER": water("#3f90d8", "#3780c4", "#7cc0f0"),
    "WARM_WATER": water("#35b3c9", "#2c9db3", "#7fdcea"),
    "SWAMP_WATER": water("#4d7a5e", "#3f6650", "#76a080"),
    "SAND": lambda rng: speckled(rng, "#ead38e", "#d5b86d", "#f6e7b2", 0.08, 0.06),
    "RED_SAND": lambda rng: speckled(rng, "#d98a4a", "#bf713a", "#eba56a", 0.08, 0.06),
    "GRASS": grass("#67ae3f", "#4b8f33", "#93cf55", 5),
    "FOREST_GRASS": grass("#4a8c37", "#35702c", "#6fae45", 7),
    "DRY_GRASS": grass("#b5ad55", "#958e40", "#d4ca70", 6),
    "JUNGLE_GRASS": grass("#3f9c3a", "#2b7c2c", "#6cc44a", 8),
    "SWAMP_GRASS": grass("#62763a", "#4b5c2c", "#839a4c", 6),
    "MEADOW_GRASS": grass("#83c754", "#63a640", "#abdf74", 5),
    "TAIGA_GRASS": grass("#4f8a5a", "#3a6d46", "#6ea878", 6),
    "STONE_FLOOR": cracked("#a8a39a", "#948f86", "#bcb7ad", "#7f7a72"),
    "DEEPSLATE_FLOOR": cracked("#77737f", "#67636f", "#8a8692", "#55515d"),
    "SNOW": lambda rng: speckled(rng, "#eef3fa", "#d3deeb", "#ffffff", 0.07, 0.05),
    "ICE": ice,
    "DIRT": pebbles("#8a5d3b", "#6f4a2f", "#a5764f"),
    "PODZOL": grass("#6b4a2b", "#4f3520", "#8a6a3e", 7),
    "TERRACOTTA": terracotta("#c46a3a", "#a95a31"),
    "TERRACOTTA_LIGHT": terracotta("#dfb189", "#c79a74"),
    "GRAVEL": pebbles("#8f8c8a", "#6e6b6a", "#b0adab", 10),
    "MUD": pebbles("#5a4636", "#4a392c", "#6f5846", 4),
    "MYCELIUM": lambda rng: speckled(rng, "#8a7590", "#6d5a73", "#a88fb0", 0.1, 0.08),
    "LAVA": lava,
}


# ------------------------------------------------------------------ blocks

def shaded_blob(canvas, cx, cy, rx, ry, colors, outline=None):
    """Filled ellipse lit from the top-left, with an optional outline."""
    dark, mid, light, highlight = colors
    inside = np.zeros((canvas.h, canvas.w), dtype=bool)
    for y in range(canvas.h):
        for x in range(canvas.w):
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
    if outline:
        for y in range(canvas.h):
            for x in range(canvas.w):
                if inside[y, x]:
                    continue
                for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + ox, y + oy
                    if 0 <= nx < canvas.w and 0 <= ny < canvas.h and inside[ny, nx]:
                        canvas.put(x, y, outline)
                        break


def ground_shadow(canvas, cx, cy, rx, ry):
    for y in range(canvas.h):
        for x in range(canvas.w):
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            if dx * dx + dy * dy <= 1.0 and canvas.img[y, x, 3] == 0:
                canvas.put(x, y, (20, 30, 25, 70))


def trunk(c, color, light, dark, top=20, width=4):
    x0 = 8 - width // 2
    c.fill(x0, top, width, 31 - top, color)
    c.fill(x0, top, 1, 31 - top, light)
    c.fill(x0 + width - 1, top, 1, 31 - top, dark)
    c.put(x0 - 1, 30, dark)
    c.put(x0 + width, 30, dark)


def round_tree(canopy, bark=("#6e4326", "#8a5a33", "#4f2f1a"), outline="#1c4221", ry=9.5):
    def make():
        c = Canvas(TILE, TILE * 2)
        ground_shadow(c, 8, 29.5, 7, 2.5)
        trunk(c, *bark)
        shaded_blob(c, 8, 12, 7.5, ry, canopy, outline)
        return c
    return make


def birch():
    c = Canvas(TILE, TILE * 2)
    ground_shadow(c, 8, 29.5, 6.5, 2.5)
    trunk(c, "#e9e4d8", "#ffffff", "#bdb6a6", top=18, width=3)
    for y in (20, 23, 27):
        c.put(7, y, "#2e2a26")
        c.put(8, y + 1, "#2e2a26")
    shaded_blob(c, 8, 11, 6.5, 8.5, ("#5a8f3a", "#76ad48", "#95c95a", "#bde27e"), "#2f5a24")
    return c


def dark_oak():
    c = Canvas(TILE, TILE * 2)
    ground_shadow(c, 8, 29.5, 8, 2.5)
    trunk(c, "#4a3121", "#5e3f2a", "#33221a", top=21, width=6)
    shaded_blob(c, 8, 12.5, 8.0, 10.5, ("#1f4520", "#2c5d29", "#3b7435", "#5b944a"), "#12301a")
    return c


def jungle_tree():
    c = Canvas(TILE, TILE * 2)
    ground_shadow(c, 8, 29.5, 7, 2.5)
    trunk(c, "#7a5a33", "#957246", "#584023", top=17, width=4)
    for y in (19, 23, 26):
        c.put(6, y, "#3f8a2a")
        c.put(9, y + 1, "#3f8a2a")
    shaded_blob(c, 8, 10, 8.0, 8.5, ("#1f6e28", "#2d8f34", "#46b045", "#7fd35e"), "#11451a")
    return c


def acacia():
    c = Canvas(TILE, TILE * 2)
    ground_shadow(c, 8, 29.5, 7, 2.5)
    trunk(c, "#8a7a6a", "#a39382", "#6b5d50", top=15, width=2)
    c.fill(9, 13, 1, 4, "#8a7a6a")
    shaded_blob(c, 7, 10, 7.8, 4.5, ("#5e7d24", "#7a9a30", "#98b642", "#bcd364"), "#3a4f18")
    return c


def spruce(snowy=False):
    def make():
        c = Canvas(TILE, TILE * 2)
        ground_shadow(c, 8, 29.5, 6, 2.5)
        c.fill(7, 24, 2, 7, "#5a3620")
        for top, half in ((4, 3), (9, 5), (14, 6), (19, 7)):
            for row in range(6):
                span = int(half * (row + 1) / 6)
                for x in range(8 - span, 8 + span):
                    shade = "#2b6a45" if x < 8 else "#1f5236"
                    if row == 0 or x in (8 - span, 8 + span - 1):
                        shade = "#163a28"
                    if snowy and row <= 1 and shade != "#163a28":
                        shade = "#f2f6fb"
                    c.put(x, top + row, shade)
        c.put(8, 3, "#f2f6fb" if snowy else "#163a28")
        return c
    return make


def rock(colors=("#5c5b66", "#7c7b87", "#9d9ca7", "#c3c2cb"), outline="#393843", moss=False):
    def make():
        c = Canvas(TILE, TILE * 2)
        ground_shadow(c, 8, 29.5, 7, 2.5)
        blob = Canvas(TILE, TILE)
        shaded_blob(blob, 8, 9.5, 6.5, 5.5, colors, outline)
        if moss:
            for x, y in ((5, 5), (6, 5), (7, 5), (8, 4), (9, 5), (4, 6), (6, 6), (10, 6)):
                blob.put(x, y, "#5e9a3a")
        c.blit(blob, 0, 16)
        return c
    return make


def wall(top, face, dark, light, speck=None, speck_light=None, rng=None):
    """Solid block seen from above: lit rim, textured top, dark front face."""
    def make():
        r = rng or np.random.default_rng(7)
        c = Canvas(TILE, TILE * 2)
        block = speckled(r, top, dark, light, 0.1, 0.06)
        block.fill(0, 0, TILE, 1, light)
        block.fill(0, 0, 1, 11, light)
        block.fill(0, 11, TILE, 5, face)
        block.fill(0, 11, TILE, 1, dark)
        for x in range(0, TILE, 5):
            block.fill(x, 12, 1, 4, dark)
        if speck:
            for x, y in ((3, 3), (9, 2), (6, 7), (12, 6)):
                block.fill(x, y, 2, 2, speck)
                block.put(x, y, speck_light or speck)
        c.blit(block, 0, 16)
        return c
    return make


def ore(speck, speck_light):
    return wall("#63616c", "#34333b", "#4c4b55", "#85838f", speck, speck_light)


def bush(colors=("#2f6e2d", "#43903a", "#62b149", "#9ad766"), berries=("#e0566b",)):
    def make():
        c = Canvas(TILE, TILE * 2)
        ground_shadow(c, 8, 29.5, 6.5, 2.5)
        blob = Canvas(TILE, TILE)
        shaded_blob(blob, 8, 9.5, 6.0, 5.0, colors, "#1c4221")
        for i, (x, y) in enumerate(((5, 8), (10, 10), (7, 11), (11, 7))):
            blob.put(x, y, berries[i % len(berries)])
        c.blit(blob, 0, 16)
        return c
    return make


def plant(draw):
    def make():
        c = Canvas(TILE, TILE * 2)
        draw(c)
        return c
    return make


def draw_tall_grass(c):
    for x, h, color in ((4, 7, "#4b8f33"), (6, 9, "#5fa83d"), (8, 6, "#4b8f33"),
                        (10, 10, "#6fbd48"), (12, 7, "#5fa83d")):
        for y in range(h):
            c.put(x + (1 if y > h - 3 else 0), 31 - y, color)


def draw_fern(c):
    for side in (-1, 1):
        for i in range(6):
            c.put(8 + side * i, 30 - i, "#3f7f3a")
            c.put(8 + side * i, 29 - i, "#5a9f48")
    c.fill(8, 22, 1, 9, "#3f7f3a")


def draw_dead_bush(c):
    for x, y in ((8, 30), (8, 29), (7, 28), (6, 27), (9, 28), (10, 27), (11, 26), (5, 26), (8, 27),
                 (8, 26), (9, 25)):
        c.put(x, y, "#8a6a3e")


def flower(petal, center="#f7d74a"):
    def draw(c):
        c.fill(8, 25, 1, 6, "#4b8f33")
        c.put(7, 28, "#5fa83d")
        for x, y in ((7, 23), (9, 23), (8, 22), (8, 24), (7, 24), (9, 22)):
            c.put(x, y, petal)
        c.put(8, 23, center)
    return plant(draw)


def small_mushroom(cap, dots):
    def draw(c):
        c.fill(7, 27, 2, 4, "#efe6d4")
        c.fill(5, 24, 6, 3, cap)
        c.fill(6, 23, 4, 1, cap)
        c.put(6, 24, dots)
        c.put(9, 25, dots)
    return plant(draw)


def big_mushroom():
    c = Canvas(TILE, TILE * 2)
    ground_shadow(c, 8, 29.5, 6, 2.5)
    c.fill(6, 18, 4, 13, "#efe6d4")
    c.fill(6, 18, 1, 13, "#ffffff")
    c.fill(9, 18, 1, 13, "#cfc3ad")
    shaded_blob(c, 8, 13, 8.0, 6.0, ("#9c1f24", "#c7302f", "#e0483f", "#f07a6a"), "#5a1014")
    for x, y in ((4, 11), (8, 9), (11, 12), (6, 15), (10, 15)):
        c.put(x, y, "#ffffff")
        c.put(x + 1, y, "#ffffff")
    return c


def cactus():
    c = Canvas(TILE, TILE * 2)
    ground_shadow(c, 8, 29.5, 5, 2)
    c.fill(5, 12, 6, 19, "#4f9a3a")
    c.fill(5, 12, 1, 19, "#6fbd4c")
    c.fill(10, 12, 1, 19, "#357028")
    c.fill(1, 17, 3, 2, "#4f9a3a")
    c.fill(1, 14, 2, 4, "#4f9a3a")
    c.fill(12, 19, 3, 2, "#4f9a3a")
    c.fill(13, 16, 2, 4, "#4f9a3a")
    for y in range(13, 30, 3):
        c.put(4, y, "#e8e2b0")
        c.put(11, y + 1, "#e8e2b0")
    c.outline("#244f1c")
    return c


def sugar_cane():
    c = Canvas(TILE, TILE * 2)
    for x, top in ((5, 8), (9, 5), (12, 11)):
        c.fill(x, top, 2, 31 - top, "#7fc45a")
        c.fill(x, top, 1, 31 - top, "#a5dc7a")
        for y in range(top + 3, 31, 5):
            c.fill(x, y, 2, 1, "#5a9a3f")
        c.put(x + 2, top + 4, "#7fc45a")
        c.put(x + 3, top + 3, "#7fc45a")
    return c


def lily_pad():
    c = Canvas(TILE, TILE * 2)
    blob = Canvas(TILE, TILE)
    shaded_blob(blob, 8, 8, 6, 5, ("#2f7a2f", "#3f9a3a", "#5fb84a", "#8fd66a"), "#1f5222")
    blob.put(8, 8, (0, 0, 0, 0))
    blob.put(9, 7, (0, 0, 0, 0))
    blob.put(10, 6, (0, 0, 0, 0))
    blob.put(5, 7, "#f2a0c0")
    c.blit(blob, 0, 16)
    return c


BLOCK_MAKERS = {
    "OAK": round_tree(("#2d6a2b", "#3f8a36", "#5aa843", "#8bcf5c")),
    "SWAMP_OAK": round_tree(("#34502a", "#465f30", "#5b7a3c", "#7a9a52"), outline="#1f3219"),
    "BIRCH": birch,
    "DARK_OAK": dark_oak,
    "JUNGLE_TREE": jungle_tree,
    "ACACIA": acacia,
    "SPRUCE": spruce(False),
    "SNOWY_SPRUCE": spruce(True),
    "ROCK": rock(),
    "MOSSY_ROCK": rock(moss=True),
    "SANDSTONE": wall("#e2c886", "#c9a865", "#cdb070", "#f0dca6"),
    "PACKED_ICE": wall("#9ecbee", "#7fb3de", "#8cbde6", "#cfe8fb"),
    "STONE": wall("#63616c", "#34333b", "#4c4b55", "#85838f"),
    "DEEPSLATE": wall("#43424f", "#23222b", "#35343f", "#5d5c6b"),
    "COAL_ORE": ore("#26262b", "#45454d"),
    "COPPER_ORE": ore("#d5824a", "#5fb89a"),
    "IRON_ORE": ore("#d8b59a", "#f0d6c0"),
    "GOLD_ORE": ore("#f2cf3a", "#fff08a"),
    "LAPIS_ORE": ore("#2f56c7", "#5f85ea"),
    "RUBY_ORE": ore("#d8283f", "#ff6b7d"),
    "DIAMOND_ORE": ore("#5fe3e0", "#c8fffd"),
    "EMERALD_ORE": ore("#2fcf6a", "#8cf5ae"),
    "BUSH": bush(),
    "BERRY_BUSH": bush(("#2a5a3a", "#3a7048", "#4f8a58", "#78b07a"), ("#c7304a", "#3f52c7")),
    "CACTUS": cactus,
    "DEAD_BUSH": plant(draw_dead_bush),
    "TALL_GRASS": plant(draw_tall_grass),
    "FERN": plant(draw_fern),
    "FLOWER_RED": flower("#e0404f"),
    "FLOWER_YELLOW": flower("#f7d74a", "#e08a2a"),
    "FLOWER_BLUE": flower("#5a7ae8"),
    "FLOWER_WHITE": flower("#f4f4f4"),
    "FLOWER_PINK": flower("#f29ac0"),
    "MUSHROOM_RED": small_mushroom("#d23a36", "#ffffff"),
    "MUSHROOM_BROWN": small_mushroom("#9a6a45", "#c79a70"),
    "BIG_MUSHROOM": big_mushroom,
    "SUGAR_CANE": sugar_cane,
    "LILY_PAD": lily_pad,
}


# ------------------------------------------------------------------ cliffs

CLIFF_MATERIALS = [
    # lip, lip_dark, face, face_dark, face_light
    ("#67ae3f", "#3f7f2e", "#8a5d3b", "#6a452b", "#a5764f"),  # dirt
    ("#9d9ca6", "#6f6e78", "#7c7b87", "#5c5b66", "#9d9ca7"),  # stone
    ("#ead38e", "#c9ad68", "#d4a860", "#b38a48", "#e8c07a"),  # sand
    ("#f4f8fc", "#c9d6e4", "#8f9fb4", "#6d7c92", "#b3c2d6"),  # snow
]


def cliff_face(material, ramp):
    lip, lip_dark, face, face_dark, face_light = CLIFF_MATERIALS[material]
    rng = np.random.default_rng(100 + material)
    c = Canvas(TILE, TILE)
    c.fill(0, 0, TILE, TILE, face)
    for y in range(4, TILE):
        for x in range(TILE):
            roll = rng.random()
            if roll < 0.1:
                c.put(x, y, face_dark)
            elif roll > 0.93:
                c.put(x, y, face_light)
    for y in (7, 11):
        for x in range(TILE):
            if rng.random() < 0.7:
                c.put(x, y, face_dark)
    c.fill(0, TILE - 2, TILE, 2, face_dark)
    c.fill(0, 0, TILE, 3, lip)
    c.fill(0, 3, TILE, 1, lip_dark)
    if ramp:
        for step in range(3):
            y = 4 + step * 4
            c.fill(2, y, 12, 3, lip if step == 0 else face_light)
            c.fill(2, y + 3, 12, 1, face_dark)
    return c


def edge_overlay(bits):
    """bits: 1 = north edge, 2 = east edge, 4 = west edge, 8 = cliff shadow."""
    c = Canvas(TILE, TILE)
    dark = (40, 32, 28, 170)
    soft = (40, 32, 28, 80)
    if bits & 8:
        for y in range(6):
            alpha = int(95 * (1 - y / 6))
            c.fill(0, y, TILE, 1, (10, 12, 30, alpha))
    if bits & 1:
        c.fill(0, 0, TILE, 1, dark)
        c.fill(0, 1, TILE, 1, soft)
    if bits & 2:
        c.fill(TILE - 1, 0, 1, TILE, dark)
        c.fill(TILE - 2, 0, 1, TILE, soft)
    if bits & 4:
        c.fill(0, 0, 1, TILE, dark)
        c.fill(1, 0, 1, TILE, soft)
    return c


# ------------------------------------------------------------------ player

SKIN, SKIN_SHADE = "#f3c49b", "#d99c77"
HAIR, HAIR_SHADE = "#7a4524", "#56301a"
SHIRT, SHIRT_SHADE = "#d6524a", "#a63a37"
PANTS, PANTS_SHADE = "#3f5f9e", "#2d467a"
SHOES = "#3b2a22"
OUTLINE = "#2a1b17"


def player_frame(direction):
    c = Canvas(TILE, 24)
    ground_shadow(c, 8, 22.5, 5, 1.8)
    c.fill(5, 17, 6, 4, PANTS)
    c.fill(8, 17, 3, 4, PANTS_SHADE)
    c.fill(7, 18, 2, 3, PANTS_SHADE)
    c.fill(5, 21, 2, 1, SHOES)
    c.fill(9, 21, 2, 1, SHOES)
    c.fill(4, 11, 8, 6, SHIRT)
    c.fill(4, 15, 8, 2, SHIRT_SHADE)
    if direction in ("down", "up"):
        c.fill(3, 12, 1, 4, SHIRT_SHADE)
        c.fill(12, 12, 1, 4, SHIRT_SHADE)
        c.put(3, 16, SKIN)
        c.put(12, 16, SKIN)
    c.fill(4, 3, 8, 8, SKIN)
    c.fill(4, 9, 8, 2, SKIN_SHADE)
    c.fill(4, 2, 8, 3, HAIR)
    c.fill(3, 3, 1, 5, HAIR)
    c.fill(12, 3, 1, 5, HAIR)
    if direction == "down":
        c.fill(5, 5, 6, 1, HAIR_SHADE)
        c.put(6, 7, OUTLINE)
        c.put(9, 7, OUTLINE)
        c.put(7, 9, "#c9776a")
        c.put(8, 9, "#c9776a")
    elif direction == "up":
        c.fill(4, 3, 8, 7, HAIR)
        c.fill(4, 8, 8, 2, HAIR_SHADE)
    else:
        c.fill(4, 3, 8, 4, HAIR)
        c.fill(4, 3, 4, 7, HAIR)
        c.fill(4, 8, 4, 2, HAIR_SHADE)
        c.put(10, 7, OUTLINE)
        c.fill(12, 12, 1, 4, SHIRT_SHADE)
        c.put(12, 16, SKIN)
        if direction == "left":
            c.img = c.img[:, ::-1].copy()
    c.outline(OUTLINE)
    return c


# ------------------------------------------------------------------ main

def main():
    rng = np.random.default_rng(1234)

    ground_atlas = Canvas(TILE * VARIANTS, TILE * len(GROUNDS))
    for row, name in enumerate(GROUNDS):
        if name == "NONE":
            continue
        make = GROUND_MAKERS[name]
        for variant in range(VARIANTS):
            ground_atlas.blit(make(rng), variant * TILE, row * TILE)
    ground_atlas.save(ROOT / "assets/textures/tiles/ground_atlas.png")

    rows = (len(BLOCKS) + BLOCK_COLUMNS - 1) // BLOCK_COLUMNS
    block_atlas = Canvas(TILE * BLOCK_COLUMNS, TILE * 2 * rows)
    for block_id, name in enumerate(BLOCKS):
        if name == "AIR":
            continue
        sprite = BLOCK_MAKERS[name]()
        x = (block_id % BLOCK_COLUMNS) * TILE
        y = (block_id // BLOCK_COLUMNS) * TILE * 2
        block_atlas.blit(sprite, x, y)
    block_atlas.save(ROOT / "assets/textures/tiles/block_atlas.png")

    cliff_atlas = Canvas(TILE * 16, TILE * 2)
    for material in range(len(CLIFF_MATERIALS)):
        cliff_atlas.blit(cliff_face(material, False), material * TILE, 0)
        cliff_atlas.blit(cliff_face(material, True), (4 + material) * TILE, 0)
    for bits in range(1, 16):
        cliff_atlas.blit(edge_overlay(bits), bits * TILE, TILE)
    cliff_atlas.save(ROOT / "assets/textures/tiles/cliff_atlas.png")

    sheet = Canvas(TILE * 4, 24)
    for i, direction in enumerate(("down", "left", "right", "up")):
        sheet.blit(player_frame(direction), i * TILE, 0)
    sheet.save(ROOT / "assets/textures/entities/player_placeholder.png")
    print("Placeholder art generated.")


if __name__ == "__main__":
    main()
