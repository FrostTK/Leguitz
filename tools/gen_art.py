#!/usr/bin/env python3
"""Leguitz art pipeline (phase 2).

Generates every sprite atlas procedurally, plus a normal map for each
atlas (so 2D lights reveal the relief) and emission maps for glowing
pixels. The layouts must match src/client/tile_atlas.gd and the terrain
shader (src/client/shaders/terrain.gdshader).

Usage: python3 tools/gen_art.py
Outputs in assets/textures/:
  tiles/ground_atlas.png (+ _n)   4 variants x one 16 px row per ground id
  tiles/wall_atlas.png (+ _n, _e) one row per wall kind: top A, top B, face A, face B
  tiles/cliff_atlas.png (+ _n)    row 0: faces (material * 2 + variant), row 1: ramps
  tiles/block_atlas.png (+ _n)    16 columns of 32x48 cells, cell index = block id
  entities/player.png (+ _n)      4 frames of 16x24 (down, left, right, up)
"""

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "textures"
TILE = 16
VARIANTS = 4
BLOCK_W, BLOCK_H = 32, 48
BLOCK_COLUMNS = 16
# Godot 2D normal maps use the OpenGL convention (green = up).
FLIP_NORMAL_Y = False

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
# Solid terrain blocks drawn by the terrain shader (order = wall atlas row).
WALLS = [
    "STONE", "DEEPSLATE", "COAL_ORE", "COPPER_ORE", "IRON_ORE", "GOLD_ORE", "LAPIS_ORE",
    "RUBY_ORE", "DIAMOND_ORE", "EMERALD_ORE", "SANDSTONE", "PACKED_ICE",
]


def rgba(value, alpha=255):
    if not isinstance(value, str):
        return value
    value = value.lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), alpha)


def shade(color, amount):
    """Lighten (amount > 0) or darken (amount < 0) a hex color."""
    r, g, b, a = rgba(color)
    if amount >= 0:
        r, g, b = (int(c + (255 - c) * amount) for c in (r, g, b))
    else:
        r, g, b = (int(c * (1 + amount)) for c in (r, g, b))
    return (r, g, b, a)


class Canvas:
    def __init__(self, width, height):
        self.img = np.zeros((height, width, 4), dtype=np.uint8)
        # Optional explicit height map (0..1) used for the normal map.
        self.height = None

    @property
    def w(self):
        return self.img.shape[1]

    @property
    def h(self):
        return self.img.shape[0]

    def put(self, x, y, color):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.img[y, x] = rgba(color)

    def fill(self, x0, y0, w, h, color):
        x1, y1 = max(0, x0), max(0, y0)
        self.img[y1:max(y1, y0 + h), x1:max(x1, x0 + w)] = rgba(color)

    def blit(self, other, x, y):
        h, w = other.img.shape[:2]
        region = self.img[y:y + h, x:x + w]
        mask = other.img[:, :, 3] > 0
        region[mask] = other.img[mask]

    def outline(self, color, threshold=200):
        solid = self.img[:, :, 3] >= threshold
        edge = rgba(color)
        grown = np.zeros_like(solid)
        grown[1:, :] |= solid[:-1, :]
        grown[:-1, :] |= solid[1:, :]
        grown[:, 1:] |= solid[:, :-1]
        grown[:, :-1] |= solid[:, 1:]
        self.img[grown & ~solid] = edge

    def disc(self, cx, cy, rx, ry, colors, light=(-0.6, -0.8)):
        """Filled ellipse lit from `light`, colors = (dark, mid, light, highlight)."""
        dark, mid, lit, highlight = (rgba(c) for c in colors)
        ys, xs = np.mgrid[0:self.h, 0:self.w]
        dx = (xs + 0.5 - cx) / rx
        dy = (ys + 0.5 - cy) / ry
        d = dx * dx + dy * dy
        inside = d <= 1.0
        term = dx * light[0] + dy * light[1]
        layers = [
            (inside, mid),
            (inside & (term < -0.45), dark),
            (inside & (term > 0.1), lit),
            (inside & (term > 0.55) & (d < 0.5), highlight),
        ]
        for mask, color in layers:
            self.img[mask] = color
        return inside


def speckle(rng, canvas, colors, density, rect=None):
    x0, y0, w, h = rect or (0, 0, canvas.w, canvas.h)
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            if rng.random() < density:
                canvas.put(x, y, colors[int(rng.integers(0, len(colors)))])


# ------------------------------------------------------------------ normal maps

def luminance(img):
    rgb = img[:, :, :3].astype(np.float32) / 255.0
    return rgb @ np.array([0.3, 0.59, 0.11], dtype=np.float32)


def distance_inside(mask):
    """Chamfer distance (in px) from each opaque pixel to the nearest transparent one."""
    big = 1e4
    d = np.where(mask, big, 0.0).astype(np.float32)
    h, w = d.shape
    for _ in range(2):
        for y in range(h):
            for x in range(w):
                if d[y, x] == 0:
                    continue
                best = d[y, x]
                if x > 0:
                    best = min(best, d[y, x - 1] + 1)
                if y > 0:
                    best = min(best, d[y - 1, x] + 1)
                    if x > 0:
                        best = min(best, d[y - 1, x - 1] + 1.41)
                    if x < w - 1:
                        best = min(best, d[y - 1, x + 1] + 1.41)
                d[y, x] = best
        for y in range(h - 1, -1, -1):
            for x in range(w - 1, -1, -1):
                if d[y, x] == 0:
                    continue
                best = d[y, x]
                if x < w - 1:
                    best = min(best, d[y, x + 1] + 1)
                if y < h - 1:
                    best = min(best, d[y + 1, x] + 1)
                    if x < w - 1:
                        best = min(best, d[y + 1, x + 1] + 1.41)
                    if x > 0:
                        best = min(best, d[y + 1, x - 1] + 1.41)
                d[y, x] = best
    # Pixels touching the image border count as edges too.
    return np.minimum(d, big)


def normals_from_height(height, strength):
    gy, gx = np.gradient(height.astype(np.float32))
    nx = -gx * strength
    ny = gy * strength
    if FLIP_NORMAL_Y:
        ny = -ny
    nz = np.ones_like(nx)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    normal = np.stack([nx / length, ny / length, nz / length], axis=-1)
    return ((normal * 0.5 + 0.5) * 255).astype(np.uint8)


def normal_image(img, mode, strength=2.5, dome_radius=5.0, height=None):
    """mode: 'flat' (luminance bumps), 'dome' (rounded sprites)."""
    alpha = img[:, :, 3] > 0
    lum = luminance(img)
    if height is None:
        if mode == "dome":
            dist = distance_inside(alpha)
            dome = np.clip(dist / dome_radius, 0.0, 1.0)
            dome = np.sqrt(1.0 - (1.0 - dome) ** 2)
            height = dome * 0.75 + lum * 0.25
        else:
            height = lum
    out = np.zeros(img.shape, dtype=np.uint8)
    out[:, :, :3] = normals_from_height(height, strength)
    out[:, :, 3] = np.where(alpha, 255, 0)
    # Transparent pixels: flat normal so filtering never pulls odd values.
    out[~alpha, 0:3] = (128, 128, 255)
    return out


def save(img, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(img, "RGBA").save(path)


# ------------------------------------------------------------------ grounds

def base_tile(rng, base, specks, density):
    c = Canvas(TILE, TILE)
    c.fill(0, 0, TILE, TILE, base)
    speckle(rng, c, specks, density)
    return c


def grass(base, dark, light, extra=None, blades=9):
    def make(rng):
        c = base_tile(rng, base, [shade(base, -0.06), shade(base, 0.05)], 0.25)
        for _ in range(blades):
            x, y = int(rng.integers(1, TILE - 1)), int(rng.integers(2, TILE))
            c.put(x, y, dark)
            c.put(x - 1, y - 1, dark)
            c.put(x + 1, y - 1, dark)
            if rng.random() < 0.6:
                c.put(x, y - 2, light)
        for _ in range(4):
            c.put(int(rng.integers(0, TILE)), int(rng.integers(0, TILE)), light)
        if extra and rng.random() < 0.5:
            x, y = int(rng.integers(2, TILE - 2)), int(rng.integers(2, TILE - 2))
            c.put(x, y, extra)
        return c
    return make


def sandy(base, dark, light):
    def make(rng):
        c = base_tile(rng, base, [dark, light, shade(base, -0.04)], 0.22)
        for _ in range(2):
            x, y = int(rng.integers(0, TILE - 3)), int(rng.integers(0, TILE))
            for i in range(3):
                c.put(x + i, y, shade(base, 0.12))
        return c
    return make


def pebbly(base, dark, light, count=6):
    def make(rng):
        c = base_tile(rng, base, [shade(base, -0.08), shade(base, 0.06)], 0.3)
        for _ in range(count):
            x, y = int(rng.integers(0, TILE - 2)), int(rng.integers(0, TILE - 2))
            c.put(x, y, light)
            c.put(x + 1, y, light)
            c.put(x, y + 1, dark)
            c.put(x + 1, y + 1, dark)
        return c
    return make


def stone_floor(base, dark, light):
    def make(rng):
        c = base_tile(rng, base, [shade(base, -0.07), shade(base, 0.05)], 0.3)
        x, y = int(rng.integers(1, 10)), int(rng.integers(1, 12))
        for i in range(int(rng.integers(3, 7))):
            c.put(x + i, y + (i // 3), dark)
        for _ in range(3):
            c.put(int(rng.integers(0, TILE)), int(rng.integers(0, TILE)), light)
        return c
    return make


def snow(rng):
    c = base_tile(rng, "#eef3fa", ["#dfe8f3", "#ffffff"], 0.25)
    for _ in range(3):
        x, y = int(rng.integers(0, TILE - 3)), int(rng.integers(0, TILE))
        for i in range(3):
            c.put(x + i, y, "#d3deeb")
    return c


def ice(rng):
    c = base_tile(rng, "#a9d3f2", ["#9ccbee", "#b7dcf5"], 0.3)
    x, y = int(rng.integers(0, 8)), int(rng.integers(0, 8))
    for i in range(8):
        c.put(x + i, y + i // 2, "#e8f5fe")
    return c


def terracotta(base, band):
    def make(rng):
        c = base_tile(rng, base, [shade(base, -0.05), shade(base, 0.04)], 0.25)
        c.fill(0, 5, TILE, 2, band)
        c.fill(0, 12, TILE, 1, band)
        return c
    return make


def flat(color):
    def make(rng):
        return base_tile(rng, color, [shade(color, -0.05), shade(color, 0.05)], 0.3)
    return make


GROUND_MAKERS = {
    # Water and lava are animated by the terrain shader; these are fallbacks.
    "DEEP_WATER": flat("#2d63ad"),
    "WATER": flat("#3f90d8"),
    "WARM_WATER": flat("#35b3c9"),
    "SWAMP_WATER": flat("#4d7a5e"),
    "LAVA": flat("#e8552a"),
    "SAND": sandy("#ecd592", "#d6b970", "#f7e9b8"),
    "RED_SAND": sandy("#d98a4a", "#bf713a", "#eba56a"),
    "GRASS": grass("#6aae3f", "#4d9034", "#94cf57", "#b8e07a"),
    "FOREST_GRASS": grass("#4e8f38", "#37722c", "#72b047", blades=12),
    "DRY_GRASS": grass("#b6ae56", "#958e40", "#d6cc72", "#e3d88c"),
    "JUNGLE_GRASS": grass("#40a03b", "#2b7e2c", "#6dc64b", "#9be06e", blades=12),
    "SWAMP_GRASS": grass("#63773b", "#4b5c2c", "#849b4d"),
    "MEADOW_GRASS": grass("#86c956", "#66a842", "#ade176", "#d6f09a"),
    "TAIGA_GRASS": grass("#528d5c", "#3a6d46", "#70aa7a"),
    "PODZOL": grass("#6d4c2c", "#4f3520", "#8c6c40", blades=10),
    "MYCELIUM": grass("#8b7692", "#6d5a73", "#aa91b2", "#c9b3cf"),
    "STONE_FLOOR": stone_floor("#a9a49b", "#857f76", "#c0bbb1"),
    "DEEPSLATE_FLOOR": stone_floor("#78747f", "#5a5663", "#8c8894"),
    "SNOW": snow,
    "ICE": ice,
    "DIRT": pebbly("#8c5f3c", "#6f4a2f", "#a8794f"),
    "GRAVEL": pebbly("#918e8b", "#6e6b6a", "#b3b0ad", 10),
    "MUD": pebbly("#5c4838", "#4a392c", "#735c49", 4),
    "TERRACOTTA": terracotta("#c46a3a", "#a95a31"),
    "TERRACOTTA_LIGHT": terracotta("#dfb189", "#c79a74"),
}


def build_grounds(rng):
    atlas = Canvas(TILE * VARIANTS, TILE * len(GROUNDS))
    for row, name in enumerate(GROUNDS):
        if name == "NONE":
            continue
        for variant in range(VARIANTS):
            atlas.blit(GROUND_MAKERS[name](rng), variant * TILE, row * TILE)
    save(atlas.img, OUT / "tiles/ground_atlas.png")
    save(normal_image(atlas.img, "flat", strength=1.6), OUT / "tiles/ground_atlas_n.png")


# ------------------------------------------------------------------ walls

WALL_BASES = {
    # name: (top, top_dark, top_light, face, face_dark, face_light)
    "stone": ("#6d6b76", "#56545f", "#86848f", "#4c4a55", "#393741", "#5f5d69"),
    "deep": ("#4b4958", "#3a3846", "#5f5d6d", "#33313f", "#26242f", "#43414f"),
    "sandstone": ("#e2c886", "#c9a865", "#f0dca6", "#c49a52", "#a8813f", "#d8b36a"),
    "ice": ("#a3cff0", "#86b8e2", "#d0e9fb", "#7fb3de", "#6698c6", "#a9d0ef"),
}
ORE_GEMS = {
    # name: (base, gem, gem_light, emission or None)
    "COAL_ORE": ("stone", "#232328", "#44444c", None),
    "COPPER_ORE": ("stone", "#d5824a", "#6fc8a4", None),
    "IRON_ORE": ("stone", "#d8b59a", "#f3dcc8", None),
    "GOLD_ORE": ("stone", "#f2cf3a", "#fff29a", "#8a6a10"),
    "LAPIS_ORE": ("stone", "#2f56c7", "#6a90f0", "#102a70"),
    "RUBY_ORE": ("deep", "#d8283f", "#ff7486", "#801020"),
    "DIAMOND_ORE": ("deep", "#5fe3e0", "#d8fffe", "#1a8a88"),
    "EMERALD_ORE": ("stone", "#2fcf6a", "#96f7b8", "#107a38"),
}


def wall_top(rng, base):
    top, dark, light = WALL_BASES[base][:3]
    c = Canvas(TILE, TILE)
    c.fill(0, 0, TILE, TILE, top)
    speckle(rng, c, [dark, light, shade(top, -0.04)], 0.28)
    for _ in range(2):
        x, y = int(rng.integers(1, 12)), int(rng.integers(1, 13))
        for i in range(int(rng.integers(2, 5))):
            c.put(x + i, y + (i // 2), dark)
    height = np.full((TILE, TILE), 0.6, dtype=np.float32)
    height += luminance(c.img) * 0.3
    return c, height


def wall_face(rng, base):
    face, dark, light = WALL_BASES[base][3:]
    c = Canvas(TILE, TILE)
    c.fill(0, 0, TILE, TILE, face)
    speckle(rng, c, [dark, light], 0.22)
    for y in (4, 9, 13):
        for x in range(TILE):
            if rng.random() < 0.75:
                c.put(x, y, dark)
    for x in range(0, TILE, int(rng.integers(4, 7))):
        c.fill(x, 0, 1, TILE, shade(face, -0.12))
    c.fill(0, TILE - 2, TILE, 2, shade(face, -0.3))
    # Faces lean towards the viewer: a vertical height ramp gives a
    # normal pointing down-screen (towards the camera side).
    height = np.tile(np.linspace(1.0, 0.0, TILE, dtype=np.float32)[:, None], (1, TILE)) * 0.8
    height += luminance(c.img) * 0.2
    return c, height


def gems(rng, canvas, emission, gem, gem_light, glow, top):
    spots = [(3, 3), (9, 2), (6, 8), (11, 7), (2, 11)] if top else [(3, 2), (10, 5), (5, 10)]
    for x, y in spots:
        if rng.random() < 0.2:
            continue
        canvas.fill(x, y, 2, 2, gem)
        canvas.put(x, y, gem_light)
        if glow:
            emission.fill(x, y, 2, 2, glow)
            emission.put(x, y, shade(glow, 0.4))


def build_walls(rng):
    atlas = Canvas(TILE * 4, TILE * len(WALLS))
    heights = np.zeros((TILE * len(WALLS), TILE * 4), dtype=np.float32)
    emission = Canvas(TILE * 4, TILE * len(WALLS))
    for row, name in enumerate(WALLS):
        if name in ORE_GEMS:
            base, gem, gem_light, glow = ORE_GEMS[name]
        else:
            base = {"STONE": "stone", "DEEPSLATE": "deep", "SANDSTONE": "sandstone",
                    "PACKED_ICE": "ice"}[name]
            gem = None
        for column in range(4):
            is_top = column < 2
            tile, height = wall_top(rng, base) if is_top else wall_face(rng, base)
            glow_tile = Canvas(TILE, TILE)
            if gem:
                gems(rng, tile, glow_tile, gem, gem_light, glow, is_top)
            atlas.blit(tile, column * TILE, row * TILE)
            emission.blit(glow_tile, column * TILE, row * TILE)
            heights[row * TILE:(row + 1) * TILE, column * TILE:(column + 1) * TILE] = height
    save(atlas.img, OUT / "tiles/wall_atlas.png")
    save(normal_image(atlas.img, "flat", strength=3.0, height=heights), OUT / "tiles/wall_atlas_n.png")
    emission.img[:, :, 3] = 255
    save(emission.img, OUT / "tiles/wall_atlas_e.png")


# ------------------------------------------------------------------ cliffs

CLIFF_MATERIALS = [
    # face, dark, light, detail
    ("#8a5d3b", "#65432a", "#a8784f", "#4e7a34"),  # dirt (roots/moss)
    ("#7c7a86", "#5a5864", "#9d9ba6", "#6b6975"),  # stone
    ("#d4a860", "#b08644", "#e8c07a", "#c49a52"),  # sand(stone)
    ("#8f9fb4", "#6d7c92", "#b8c7da", "#e8f0f8"),  # snow / ice
]


def cliff_face(rng, material, ramp):
    face, dark, light, detail = CLIFF_MATERIALS[material]
    c = Canvas(TILE, TILE)
    c.fill(0, 0, TILE, TILE, face)
    speckle(rng, c, [dark, light, shade(face, -0.06)], 0.25)
    for y in (6, 10):
        for x in range(TILE):
            if rng.random() < 0.7:
                c.put(x, y, dark)
    for _ in range(3):
        x, y = int(rng.integers(1, 14)), int(rng.integers(4, 13))
        c.fill(x, y, 2, 2, light)
        c.put(x + 1, y + 1, dark)
    for _ in range(2):
        x = int(rng.integers(1, 15))
        for y in range(3, 3 + int(rng.integers(2, 5))):
            c.put(x, y, detail)
    c.fill(0, TILE - 2, TILE, 2, shade(face, -0.35))
    height = np.tile(np.linspace(1.0, 0.0, TILE, dtype=np.float32)[:, None], (1, TILE)) * 0.8
    if ramp:
        for step in range(3):
            y = 3 + step * 4
            c.fill(1, y, 14, 3, shade(face, 0.18))
            c.fill(1, y + 3, 14, 1, shade(face, -0.25))
            height[y:y + 3, 1:15] = 0.9 - step * 0.25
    height += luminance(c.img) * 0.2
    return c, height


def build_cliffs(rng):
    atlas = Canvas(TILE * 8, TILE * 2)
    heights = np.full((TILE * 2, TILE * 8), 0.5, dtype=np.float32)
    for material in range(4):
        for variant in range(2):
            tile, height = cliff_face(rng, material, False)
            x = (material * 2 + variant) * TILE
            atlas.blit(tile, x, 0)
            heights[0:TILE, x:x + TILE] = height
        tile, height = cliff_face(rng, material, True)
        atlas.blit(tile, material * TILE, TILE)
        heights[TILE:2 * TILE, material * TILE:(material + 1) * TILE] = height
    save(atlas.img, OUT / "tiles/cliff_atlas.png")
    save(normal_image(atlas.img, "flat", strength=3.0, height=heights), OUT / "tiles/cliff_atlas_n.png")


# ------------------------------------------------------------------ blocks (32x48 cells)

LEAVES = {
    "oak": ("#24542c", "#31733a", "#46963f", "#7cc255", "#1a3d22"),
    "birch": ("#4a7d2c", "#63a03b", "#86c24f", "#b8e27a", "#2f5a24"),
    "dark": ("#15341e", "#1d4a28", "#2a6331", "#3f7f3a", "#0e2414"),
    "jungle": ("#175a28", "#227a36", "#34a046", "#6ccc5a", "#0f4020"),
    "acacia": ("#50682a", "#6a8a32", "#8aab44", "#b8cf66", "#33451a"),
    "swamp": ("#2c4526", "#3b5a30", "#50753c", "#779652", "#1c2e19"),
}


def contact_shadow(c, cx, cy, rx, ry):
    ys, xs = np.mgrid[0:c.h, 0:c.w]
    d = ((xs + 0.5 - cx) / rx) ** 2 + ((ys + 0.5 - cy) / ry) ** 2
    mask = (d <= 1.0) & (c.img[:, :, 3] == 0)
    c.img[mask] = (15, 25, 20, 60)


def canopy(rng, c, cx, cy, rx, ry, palette, clusters=7):
    """Leafy canopy: overlapping lit clusters with a dark rim."""
    dark, mid, lit, highlight, rim = palette
    mask = np.zeros((c.h, c.w), dtype=bool)
    blobs = [(cx, cy, rx * 0.95, ry * 0.95)]
    for _ in range(clusters):
        a = rng.uniform(0, 2 * np.pi)
        r = rng.uniform(0.35, 0.6)
        blobs.append((cx + np.cos(a) * rx * r, cy + np.sin(a) * ry * r, rx * rng.uniform(0.4, 0.55),
                      ry * rng.uniform(0.4, 0.55)))
    # Bottom clusters first so upper ones overlap them (depth).
    blobs.sort(key=lambda b: b[1] + b[3], reverse=True)
    for bx, by, brx, bry in blobs:
        mask |= c.disc(bx, by, brx, bry, (dark, mid, lit, highlight))
    ys, xs = np.nonzero(mask)
    for y, x in zip(ys, xs):
        if rng.random() < 0.12:
            c.put(int(x), int(y), shade(lit, 0.15) if y < cy else shade(mid, -0.15))
    c.outline(rim)


def trunk(c, x0, top, width, bark, bottom=46):
    color, light, dark = bark
    c.fill(x0, top, width, bottom - top, color)
    c.fill(x0, top, 1, bottom - top, light)
    c.fill(x0 + width - 1, top, 1, bottom - top, dark)
    c.put(x0 - 1, bottom - 1, dark)
    c.put(x0 + width, bottom - 1, dark)


BARK = ("#6e4326", "#8e5c35", "#4a2d1a")


def tree(kind, rx, ry, cy, trunk_top, trunk_w=4, clusters=7, bark=BARK, extra=None):
    def make(rng):
        c = Canvas(BLOCK_W, BLOCK_H)
        contact_shadow(c, 16, 45.5, 8, 2.5)
        trunk(c, 16 - trunk_w // 2, trunk_top, trunk_w, bark)
        canopy(rng, c, 16, cy, rx, ry, LEAVES[kind], clusters)
        if extra:
            extra(rng, c)
        return c, "dome"
    return make


def birch_marks(rng, c):
    for y in range(33, 45, 3):
        c.put(15, y, "#2e2a26")
        c.put(16, y + 1, "#2e2a26")


def vines(rng, c):
    for x in (9, 13, 20, 23):
        length = int(rng.integers(5, 11))
        for y in range(24, 24 + length):
            c.put(x, y, "#3f7a2a" if y % 2 else "#2c5a1e")


def spruce(snowy):
    def make(rng):
        c = Canvas(BLOCK_W, BLOCK_H)
        contact_shadow(c, 16, 45.5, 7, 2.5)
        trunk(c, 15, 38, 3, ("#5a3620", "#744a2c", "#3d2414"))
        tiers = [(4, 4), (10, 7), (17, 9), (24, 11), (31, 12)]
        for top, half in tiers:
            for row in range(8):
                span = max(1, int(half * (row + 1) / 8))
                for x in range(16 - span, 16 + span):
                    left = x < 16
                    color = "#2f6f48" if left else "#1f5236"
                    if row >= 6:
                        color = "#1a4630" if left else "#143a28"
                    if snowy and row <= 2:
                        color = "#f4f8fc" if left else "#d8e4f0"
                    c.put(x, top + row, color)
        c.put(16, 3, "#f4f8fc" if snowy else "#2f6f48")
        c.outline("#0e2a1c")
        return c, "dome"
    return make


def acacia(rng):
    c = Canvas(BLOCK_W, BLOCK_H)
    contact_shadow(c, 16, 45.5, 8, 2.5)
    trunk(c, 15, 26, 3, ("#8a7a6a", "#a89886", "#65584a"))
    for i in range(8):
        c.fill(18 + i // 2, 26 - i, 2, 1, "#8a7a6a")
    canopy(rng, c, 14, 17, 14, 6.5, LEAVES["acacia"], 6)
    return c, "dome"


def rock(colors=("#5c5b66", "#7c7b87", "#9d9ca7", "#c3c2cb"), rim="#393843", moss=False):
    def make(rng):
        c = Canvas(BLOCK_W, BLOCK_H)
        contact_shadow(c, 16, 45.5, 8, 2.5)
        c.disc(16, 40, 7.5, 6.5, colors)
        c.disc(12, 42, 4, 3.5, colors)
        if moss:
            for x in range(10, 22):
                if rng.random() < 0.6:
                    c.put(x, 34 + int(rng.integers(0, 2)), "#5e9a3a")
        c.outline(rim)
        return c, "dome"
    return make


def bush(colors=("#2c6a2c", "#3f8c38", "#5daf48", "#95d566"), berries=None, rim="#173d1c"):
    def make(rng):
        c = Canvas(BLOCK_W, BLOCK_H)
        contact_shadow(c, 16, 45.5, 8, 2.5)
        c.disc(12, 39, 6, 5.5, colors)
        c.disc(20, 39, 6, 5.5, colors)
        c.disc(16, 36, 6.5, 6, colors)
        if berries:
            for i, (x, y) in enumerate(((12, 37), (19, 35), (16, 40), (22, 40), (14, 33))):
                c.put(x, y, berries[i % len(berries)])
        c.outline(rim)
        return c, "dome"
    return make


def plant(draw):
    def make(rng):
        c = Canvas(BLOCK_W, BLOCK_H)
        draw(rng, c)
        return c, "flat"
    return make


def draw_tall_grass(rng, c):
    for x, h, color in ((11, 8, "#4b8f33"), (13, 11, "#5fa83d"), (15, 7, "#4b8f33"),
                        (17, 12, "#6fbd48"), (19, 9, "#5fa83d"), (21, 7, "#4b8f33")):
        for y in range(h):
            c.put(x + (1 if y > h - 3 else 0), 46 - y, color)


def draw_fern(rng, c):
    for side in (-1, 1):
        for i in range(8):
            c.put(16 + side * i, 45 - i // 1, "#3f7f3a")
            c.put(16 + side * i, 44 - i, "#5a9f48")
    c.fill(16, 34, 1, 12, "#3f7f3a")


def draw_dead_bush(rng, c):
    for x, y in ((16, 46), (16, 45), (15, 44), (14, 43), (17, 44), (18, 43), (19, 42), (13, 42),
                 (16, 43), (16, 42), (17, 41), (12, 41), (20, 41)):
        c.put(x, y, "#8a6a3e")


def flower(petal, center="#f7d74a"):
    def draw(rng, c):
        for cx, cy in ((14, 38), (19, 40)):
            c.fill(cx, cy + 2, 1, 46 - cy - 2, "#4b8f33")
            c.put(cx - 1, cy + 5, "#5fa83d")
            for x, y in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
                c.put(x, y, petal)
            c.put(cx, cy, center)
    return plant(draw)


def small_mushroom(cap, dots):
    def draw(rng, c):
        c.fill(15, 42, 2, 4, "#efe6d4")
        c.fill(13, 39, 6, 3, cap)
        c.fill(14, 38, 4, 1, cap)
        c.put(14, 39, dots)
        c.put(17, 40, dots)
    return plant(draw)


def big_mushroom(rng):
    c = Canvas(BLOCK_W, BLOCK_H)
    contact_shadow(c, 16, 45.5, 7, 2.5)
    c.fill(13, 28, 6, 18, "#efe6d4")
    c.fill(13, 28, 1, 18, "#ffffff")
    c.fill(18, 28, 1, 18, "#cfc3ad")
    c.disc(16, 22, 13, 9, ("#9c1f24", "#c7302f", "#e0483f", "#f07a6a"))
    for x, y in ((8, 20), (15, 16), (21, 19), (11, 25), (19, 25), (25, 23)):
        c.fill(x, y, 2, 2, "#ffffff")
    c.outline("#5a1014")
    return c, "dome"


def cactus(rng):
    c = Canvas(BLOCK_W, BLOCK_H)
    contact_shadow(c, 16, 45.5, 6, 2)
    c.fill(13, 20, 6, 26, "#4f9a3a")
    c.fill(13, 20, 1, 26, "#6fbd4c")
    c.fill(18, 20, 1, 26, "#357028")
    c.fill(9, 27, 4, 2, "#4f9a3a")
    c.fill(9, 23, 2, 5, "#4f9a3a")
    c.fill(19, 30, 4, 2, "#4f9a3a")
    c.fill(21, 26, 2, 5, "#4f9a3a")
    for y in range(21, 45, 3):
        c.put(12, y, "#e8e2b0")
        c.put(19, y + 1, "#e8e2b0")
    c.put(15, 19, "#f07aa0")
    c.put(16, 19, "#f07aa0")
    c.outline("#244f1c")
    return c, "dome"


def sugar_cane(rng):
    c = Canvas(BLOCK_W, BLOCK_H)
    for x, top in ((12, 20), (16, 16), (20, 23)):
        c.fill(x, top, 2, 46 - top, "#7fc45a")
        c.fill(x, top, 1, 46 - top, "#a5dc7a")
        for y in range(top + 3, 46, 5):
            c.fill(x, y, 2, 1, "#5a9a3f")
        c.put(x + 2, top + 4, "#7fc45a")
        c.put(x + 3, top + 3, "#7fc45a")
    return c, "flat"


def lily_pad(rng):
    c = Canvas(BLOCK_W, BLOCK_H)
    c.disc(16, 40, 7, 5, ("#2f7a2f", "#3f9a3a", "#5fb84a", "#8fd66a"))
    for x, y in ((16, 40), (17, 39), (18, 38), (19, 37)):
        c.put(x, y, (0, 0, 0, 0))
    c.put(12, 39, "#f2a0c0")
    c.put(13, 38, "#f7c6da")
    c.outline("#1f5222")
    return c, "dome"


BLOCK_MAKERS = {
    "OAK": tree("oak", 13, 12, 17, 26),
    "SWAMP_OAK": tree("swamp", 13, 11, 18, 26, extra=vines),
    "BIRCH": tree("birch", 10, 13, 16, 26, trunk_w=3, bark=("#e9e4d8", "#ffffff", "#bdb6a6"),
                  extra=birch_marks),
    "DARK_OAK": tree("dark", 15, 14, 17, 28, trunk_w=6, clusters=9,
                     bark=("#4a3121", "#5e3f2a", "#33221a")),
    "JUNGLE_TREE": tree("jungle", 14, 12, 14, 22, bark=("#7a5a33", "#957246", "#584023"),
                        extra=vines),
    "ACACIA": acacia,
    "SPRUCE": spruce(False),
    "SNOWY_SPRUCE": spruce(True),
    "ROCK": rock(),
    "MOSSY_ROCK": rock(moss=True),
    "BUSH": bush(),
    "BERRY_BUSH": bush(("#2a5a3a", "#3a7048", "#4f8a58", "#78b07a"), ("#d8304a", "#4f62d8")),
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


def build_blocks(rng):
    rows = (len(BLOCKS) + BLOCK_COLUMNS - 1) // BLOCK_COLUMNS
    atlas = Canvas(BLOCK_W * BLOCK_COLUMNS, BLOCK_H * rows)
    normals = np.zeros_like(atlas.img)
    normals[:, :, 0:3] = (128, 128, 255)
    for block_id, name in enumerate(BLOCKS):
        if name not in BLOCK_MAKERS:
            continue  # air and walls (walls are drawn by the terrain shader)
        sprite, mode = BLOCK_MAKERS[name](rng)
        x = (block_id % BLOCK_COLUMNS) * BLOCK_W
        y = (block_id // BLOCK_COLUMNS) * BLOCK_H
        atlas.blit(sprite, x, y)
        normals[y:y + BLOCK_H, x:x + BLOCK_W] = normal_image(sprite.img, mode, strength=2.2)
    save(atlas.img, OUT / "tiles/block_atlas.png")
    save(normals, OUT / "tiles/block_atlas_n.png")


# ------------------------------------------------------------------ player

SKIN, SKIN_SHADE = "#f3c49b", "#d99c77"
HAIR, HAIR_SHADE = "#7a4524", "#56301a"
SHIRT, SHIRT_SHADE = "#d6524a", "#a63a37"
PANTS, PANTS_SHADE = "#3f5f9e", "#2d467a"
SHOES = "#3b2a22"
OUTLINE = "#2a1b17"


def player_frame(direction):
    c = Canvas(TILE, 24)
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


def build_player():
    sheet = Canvas(TILE * 4, 24)
    normals = np.zeros_like(sheet.img)
    for i, direction in enumerate(("down", "left", "right", "up")):
        frame = player_frame(direction)
        sheet.blit(frame, i * TILE, 0)
        normals[:, i * TILE:(i + 1) * TILE] = normal_image(frame.img, "dome", 2.0, dome_radius=3.0)
    save(sheet.img, OUT / "entities/player.png")
    save(normals, OUT / "entities/player_n.png")


def main():
    rng = np.random.default_rng(1234)
    build_grounds(rng)
    build_walls(rng)
    build_cliffs(rng)
    build_blocks(rng)
    build_player()
    print("Art generated in", OUT)


if __name__ == "__main__":
    main()
