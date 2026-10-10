#!/usr/bin/env python3
"""Leguitz art pipeline: terrain textures.

Generates the terrain texture atlases procedurally, plus a normal map for
each atlas (so lights reveal the relief) and emission maps for glowing
pixels. The layouts must match src/client/tile_atlas.gd and the terrain
shaders (src/client/shaders/terrain3d_*.gdshader). Trees, plants, rocks
and the player are 3D voxel models instead (tools/gen_models.gd).

Usage: python3 tools/gen_art.py
Outputs in assets/textures/:
  tiles/ground_atlas.png (+ _n)   4 variants x one 16 px row per ground id
  tiles/wall_atlas.png (+ _n, _e) one row per wall kind: top A, top B, face A, face B
  tiles/face_atlas.png (+ _n, _e) vertical faces: rows 0-3 cliff materials (dirt,
                                  stone, sand, snow), then the wall kinds; 2 variants
"""

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "textures"
TILE = 16
VARIANTS = 4
# Godot 2D normal maps use the OpenGL convention (green = up).
FLIP_NORMAL_Y = False

# Must match the enums in src/sim/world/tiles.gd (order = id).
GROUNDS = [
    "NONE", "DEEP_WATER", "WATER", "SAND", "GRASS", "FOREST_GRASS", "STONE_FLOOR", "SNOW",
    "DIRT", "PODZOL", "DRY_GRASS", "JUNGLE_GRASS", "SWAMP_GRASS", "MEADOW_GRASS", "TAIGA_GRASS",
    "RED_SAND", "TERRACOTTA", "TERRACOTTA_LIGHT", "GRAVEL", "ICE", "MUD", "MYCELIUM",
    "DEEPSLATE_FLOOR", "LAVA", "SWAMP_WATER", "WARM_WATER",
    "WATER_FLOW_1", "WATER_FLOW_2", "WATER_FLOW_3", "WATER_FLOW_4", "WATER_FALLING",
    "LAVA_FLOW_1", "LAVA_FLOW_2", "LAVA_FALLING",
    "FARMLAND", "FARMLAND_WET",
]
# Grounds from this row on draw from random generators of their own, so the
# textures made before them (and the walls after) stay the same.
FIRST_OWN_SEED_GROUND = 26
# Solid terrain blocks drawn by the terrain shader (order = wall atlas row).
WALLS = [
    "STONE", "DEEPSLATE", "COAL_ORE", "COPPER_ORE", "IRON_ORE", "GOLD_ORE", "LAPIS_ORE",
    "RUBY_ORE", "DIAMOND_ORE", "EMERALD_ORE", "SANDSTONE", "PACKED_ICE",
    "OAK_PLANKS", "BIRCH_PLANKS", "SPRUCE_PLANKS", "DARK_OAK_PLANKS", "JUNGLE_PLANKS",
    "ACACIA_PLANKS", "STONE_BRICKS", "SMOOTH_STONE", "BRICKS", "DEEPSLATE_BRICKS",
    "CUT_SANDSTONE", "GLASS", "WOOL", "WINDOW",
    "OLD_GLASS",
    "LEADED_GLASS",
    "OAK_WINDOW_SMALL",
    "OAK_WINDOW_SASH",
    "OAK_WINDOW_ROUND",
    "BIRCH_WINDOW",
    "BIRCH_WINDOW_SMALL",
    "BIRCH_WINDOW_SASH",
    "BIRCH_WINDOW_ROUND",
    "SPRUCE_WINDOW",
    "SPRUCE_WINDOW_SMALL",
    "SPRUCE_WINDOW_SASH",
    "SPRUCE_WINDOW_ROUND",
    "DARK_OAK_WINDOW",
    "DARK_OAK_WINDOW_SMALL",
    "DARK_OAK_WINDOW_SASH",
    "DARK_OAK_WINDOW_ROUND",
    "JUNGLE_WINDOW",
    "JUNGLE_WINDOW_SMALL",
    "JUNGLE_WINDOW_SASH",
    "JUNGLE_WINDOW_ROUND",
    "ACACIA_WINDOW",
    "ACACIA_WINDOW_SMALL",
    "ACACIA_WINDOW_SASH",
    "ACACIA_WINDOW_ROUND",
    "IRON_WINDOW",
    "IRON_WINDOW_SMALL",
    "IRON_WINDOW_SASH",
    "IRON_WINDOW_ROUND",
]
# Walls from this row on draw from random generators of their own, so the
# textures made before them (and the cliffs after) stay the same.
FIRST_OWN_SEED_WALL = 12


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


def farmland(base, furrow, ridge):
    """Tilled soil: furrows across the tile, a ridge of loose earth along
    each, a few clods."""
    def make(rng):
        c = base_tile(rng, base, [shade(base, -0.06), shade(base, 0.05)], 0.25)
        for y in (2, 6, 10, 14):
            for x in range(TILE):
                if rng.random() < 0.9:
                    c.put(x, y, furrow)
                if rng.random() < 0.55:
                    c.put(x, y - 1, ridge)
        for _ in range(3):
            x, y = int(rng.integers(0, TILE - 1)), int(rng.integers(0, TILE))
            c.put(x, y, ridge)
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
    # Flowing liquids are drawn as what they flow from (ChunkMesher).
    "WATER_FLOW_1": flat("#3f90d8"),
    "WATER_FLOW_2": flat("#3f90d8"),
    "WATER_FLOW_3": flat("#3f90d8"),
    "WATER_FLOW_4": flat("#3f90d8"),
    "WATER_FALLING": flat("#3f90d8"),
    "LAVA_FLOW_1": flat("#e8552a"),
    "LAVA_FLOW_2": flat("#e8552a"),
    "LAVA_FALLING": flat("#e8552a"),
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
    "FARMLAND": farmland("#86593a", "#5f3d26", "#a5764d"),
    "FARMLAND_WET": farmland("#5e3e28", "#3f2819", "#77513a"),
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
        own = np.random.default_rng(7000 + row) if row >= FIRST_OWN_SEED_GROUND else rng
        for variant in range(VARIANTS):
            atlas.blit(GROUND_MAKERS[name](own), variant * TILE, row * TILE)
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


PLANKS = {
    # name: (base, dark, light)
    "OAK_PLANKS": ("#b8874f", "#8a6034", "#d3a56c"),
    "BIRCH_PLANKS": ("#dcc68f", "#b39a62", "#efdcab"),
    "SPRUCE_PLANKS": ("#9c6e42", "#714c29", "#b98a5b"),
    "DARK_OAK_PLANKS": ("#6e4a2b", "#4a2f19", "#87603b"),
    "JUNGLE_PLANKS": ("#b9825a", "#8a5c39", "#d29d74"),
    "ACACIA_PLANKS": ("#c0663a", "#924522", "#d9845a"),
}


def planks(rng, base, dark, light, face):
    """Four boards across the tile, grained, butted end to end here and there."""
    c = Canvas(TILE, TILE)
    height = np.full((TILE, TILE), 0.7, dtype=np.float32)
    for board in range(4):
        y0 = board * 4
        tone = shade(base, float(rng.uniform(-0.07, 0.07)))
        c.fill(0, y0, TILE, 4, tone)
        for _ in range(4):
            x, y = int(rng.integers(0, TILE - 3)), y0 + int(rng.integers(0, 3))
            streak = shade(tone, -0.12) if rng.random() < 0.65 else shade(tone, 0.1)
            c.fill(x, y, int(rng.integers(3, 8)), 1, streak)
        c.fill(0, y0, TILE, 1, shade(tone, 0.08))
        c.fill(0, y0 + 3, TILE, 1, dark)
        height[y0 + 3, :] = 0.25
        joint = (board * 6 + int(rng.integers(2, 6))) % TILE
        c.fill(joint, y0, 1, 3, dark)
        height[y0:y0 + 3, joint] = 0.3
        for nail_x in (joint - 2, joint + 2):
            if 0 <= nail_x < TILE and rng.random() < 0.7:
                c.put(nail_x, y0 + 1, shade(dark, -0.25))
    if face:
        c.fill(0, TILE - 1, TILE, 1, shade(dark, -0.25))
    height += luminance(c.img) * 0.15
    return c, height


BRICKS = {
    # name: (brick, dark, light, mortar, brick width, brick height)
    "STONE_BRICKS": ("#7a7884", "#605e6a", "#93919c", "#45434e", 8, 4),
    "DEEPSLATE_BRICKS": ("#4c4a59", "#3a3846", "#605e70", "#262430", 4, 4),
    "BRICKS": ("#a24e38", "#823b2a", "#bd6a4f", "#c9bba8", 8, 4),
}


def bricks(rng, base, dark, light, mortar, width, height_px, face):
    """Bricks in staggered courses, a pixel of mortar under and after each."""
    c = Canvas(TILE, TILE)
    c.fill(0, 0, TILE, TILE, mortar)
    height = np.full((TILE, TILE), 0.25, dtype=np.float32)
    for course in range(TILE // height_px):
        y0 = course * height_px
        offset = width // 2 if course % 2 else 0
        for x0 in range(-offset, TILE, width):
            x1, x2 = max(x0, 0), min(x0 + width - 1, TILE)
            if x2 <= x1:
                continue
            tone = shade(base, float(rng.uniform(-0.09, 0.09)))
            if face:
                tone = shade(tone, -0.12)
            c.fill(x1, y0, x2 - x1, height_px - 1, tone)
            c.fill(x1, y0, x2 - x1, 1, shade(tone, 0.14))
            speckle(rng, c, [dark, light], 0.12, (x1, y0 + 1, x2 - x1, height_px - 2))
            height[y0:y0 + height_px - 1, x1:x2] = 0.85
    if face:
        c.fill(0, TILE - 1, TILE, 1, shade(mortar, -0.35))
    height += luminance(c.img) * 0.15
    return c, height


def smooth_stone(rng, face):
    """Smooth stone: one pale slab, bevelled; its sides show the seam of two."""
    base = "#a3a1ab" if not face else "#8d8b96"
    c = Canvas(TILE, TILE)
    c.fill(0, 0, TILE, TILE, base)
    speckle(rng, c, [shade(base, -0.05), shade(base, 0.05)], 0.25)
    c.fill(0, 0, TILE, 1, shade(base, 0.15))
    c.fill(0, 0, 1, TILE, shade(base, 0.1))
    c.fill(0, TILE - 1, TILE, 1, shade(base, -0.25))
    c.fill(TILE - 1, 0, 1, TILE, shade(base, -0.18))
    height = np.full((TILE, TILE), 0.75, dtype=np.float32)
    if face:
        c.fill(1, 7, TILE - 2, 1, shade(base, -0.3))
        c.fill(1, 8, TILE - 2, 1, shade(base, 0.1))
        height[7, :] = 0.3
    height[TILE - 1, :] = 0.4
    height += luminance(c.img) * 0.1
    return c, height


def cut_sandstone(rng, face):
    """Sandstone cut in blocks: a framed top, sides in smooth bands."""
    base, dark, light = ("#e2c886", "#c4a061", "#f1dda8") if not face else (
        "#cfae6c", "#ad8a4a", "#e2c486")
    c = Canvas(TILE, TILE)
    c.fill(0, 0, TILE, TILE, base)
    speckle(rng, c, [shade(base, -0.04), shade(base, 0.04)], 0.3)
    height = np.full((TILE, TILE), 0.75, dtype=np.float32)
    if face:
        for y, color in ((0, light), (1, light), (2, dark), (TILE - 3, dark), (TILE - 1, dark)):
            c.fill(0, y, TILE, 1, color)
        height[2, :] = 0.35
        height[TILE - 3, :] = 0.35
    else:
        c.fill(0, 0, TILE, 1, dark)
        c.fill(0, 0, 1, TILE, dark)
        c.fill(0, TILE - 1, TILE, 1, dark)
        c.fill(TILE - 1, 0, 1, TILE, dark)
        c.fill(2, 2, TILE - 4, 1, light)
        c.fill(2, 2, 1, TILE - 4, light)
        c.fill(2, TILE - 3, TILE - 4, 1, dark)
        c.fill(TILE - 3, 2, 1, TILE - 4, dark)
        height[0, :] = height[:, 0] = height[TILE - 1, :] = height[:, TILE - 1] = 0.35
    height += luminance(c.img) * 0.1
    return c, height


def glass(rng, variant):
    """Clear glass: a thin pale border, clear inside (transparent pixels: the
    glass shader shows what lies behind and its sheen). Side by side, the
    border goes where the glass goes on (GlassFaces)."""
    edge, corner = "#d6e6ec", "#eef6f8"
    c = Canvas(TILE, TILE)
    c.fill(0, 0, TILE, 1, edge)
    c.fill(0, TILE - 1, TILE, 1, edge)
    c.fill(0, 0, 1, TILE, edge)
    c.fill(TILE - 1, 0, 1, TILE, edge)
    for x, y in ((0, 0), (TILE - 1, 0), (0, TILE - 1), (TILE - 1, TILE - 1)):
        c.put(x, y, corner)
    height = np.full((TILE, TILE), 0.8, dtype=np.float32)
    return c, height


def old_glass(rng, variant):
    """Old blown glass: a greenish border, a few bubbles caught in it (the
    shader makes it wavy and greenish)."""
    edge, bubble = "#9fbb98", "#d2e4c8"
    c = Canvas(TILE, TILE)
    c.fill(0, 0, TILE, 1, edge)
    c.fill(0, TILE - 1, TILE, 1, edge)
    c.fill(0, 0, 1, TILE, edge)
    c.fill(TILE - 1, 0, 1, TILE, edge)
    for x, y in ((4, 3), (11, 5), (6, 10), (12, 12), (3, 13), (9, 8)):
        c.put(x, y, bubble)
    height = np.full((TILE, TILE), 0.8, dtype=np.float32)
    return c, height


def leaded_glass(rng, variant):
    """Leaded glass: diamonds set in lead, a lead border (which goes where the
    glass goes on)."""
    lead, light = "#3a3b40", "#55565c"
    c = Canvas(TILE, TILE)
    for y in range(TILE):
        for x in range(TILE):
            if (x + y) % 8 == 0 or (x - y + TILE) % 8 == 0:
                c.put(x, y, lead if (x + y) % 16 else light)
    c.fill(0, 0, TILE, 1, lead)
    c.fill(0, TILE - 1, TILE, 1, lead)
    c.fill(0, 0, 1, TILE, lead)
    c.fill(TILE - 1, 0, 1, TILE, lead)
    height = np.full((TILE, TILE), 0.7, dtype=np.float32)
    return c, height


# Window frames: (base, dark, light) of each wood (PLANKS), and wrought iron.
FRAME_COLORS = {
    "OAK": PLANKS["OAK_PLANKS"],
    "BIRCH": PLANKS["BIRCH_PLANKS"],
    "SPRUCE": PLANKS["SPRUCE_PLANKS"],
    "DARK_OAK": PLANKS["DARK_OAK_PLANKS"],
    "JUNGLE": PLANKS["JUNGLE_PLANKS"],
    "ACACIA": PLANKS["ACACIA_PLANKS"],
    "IRON": ("#3e3e46", "#26262c", "#5e5e68"),
}


def window(rng, variant, frame="OAK", design=""):
    """A window: its frame (a wood or wrought iron) and its bars, clear
    between (transparent, like glass): four panes, small panes, a sash, or a
    round eye."""
    base, dark, light = FRAME_COLORS[frame]
    c = Canvas(TILE, TILE)
    height = np.full((TILE, TILE), 0.5, dtype=np.float32)

    def bar(x, y, w, h):
        c.fill(x, y, w, h, base)
        height[y:y + h, x:x + w] = 0.8

    if design == "_ROUND":
        # A round eye in a square of the frame.
        for y in range(TILE):
            for x in range(TILE):
                d = ((x - 7.5) ** 2 + (y - 7.5) ** 2) ** 0.5
                if d > 6.3:
                    c.put(x, y, base)
                    height[y, x] = 0.8
                elif d > 5.3:
                    c.put(x, y, dark if y > 7 else light)
                    height[y, x] = 0.7
        c.fill(0, 0, TILE, 1, light)
        c.fill(0, 0, 1, TILE, light)
        c.fill(0, TILE - 1, TILE, 1, dark)
        c.fill(TILE - 1, 0, 1, TILE, dark)
        return c, height
    bar(0, 0, TILE, 2)
    bar(0, TILE - 2, TILE, 2)
    bar(0, 0, 2, TILE)
    bar(TILE - 2, 0, 2, TILE)
    if design == "":
        bar(2, 7, TILE - 4, 2)
        bar(7, 2, 2, TILE - 4)
        c.fill(2, 8, TILE - 4, 1, dark)
        c.fill(8, 2, 1, TILE - 4, dark)
    elif design == "_SMALL":
        bar(7, 2, 2, TILE - 4)
        bar(2, 5, TILE - 4, 1)
        bar(2, 10, TILE - 4, 1)
        c.fill(8, 2, 1, TILE - 4, dark)
    elif design == "_SASH":
        # The meeting rail, the upper sash in small panes.
        bar(1, 7, TILE - 2, 2)
        c.fill(1, 8, TILE - 2, 1, dark)
        bar(5, 2, 1, 5)
        bar(10, 2, 1, 5)
    c.fill(0, 0, TILE, 1, light)
    c.fill(0, 0, 1, TILE, light)
    c.fill(0, TILE - 1, TILE, 1, dark)
    c.fill(TILE - 1, 0, 1, TILE, dark)
    c.put(1, 1, light)
    return c, height


def wool(rng, face):
    """Wool: soft cream fleece in little curls, a shade darker on the sides."""
    base = "#ece6d6" if not face else "#ddd5c2"
    dark, light = shade(base, -0.12), shade(base, 0.06)
    c = Canvas(TILE, TILE)
    c.fill(0, 0, TILE, TILE, base)
    height = np.full((TILE, TILE), 0.6, dtype=np.float32)
    # Curls: a light crescent over a dark one, in a loose grid.
    for gy in range(0, TILE, 4):
        for gx in range(0, TILE, 4):
            x = (gx + int(rng.integers(0, 3)) + (2 if (gy // 4) % 2 else 0)) % TILE
            y = gy + int(rng.integers(0, 2))
            c.fill(x, y, 2, 1, light)
            c.put((x + 2) % TILE, y + 1, dark)
            c.put(x, y + 1, dark)
            height[y % TILE, x] = 0.85
            height[y % TILE, (x + 1) % TILE] = 0.85
    speckle(rng, c, [shade(base, -0.05), shade(base, 0.03)], 0.15)
    if face:
        c.fill(0, TILE - 1, TILE, 1, shade(base, -0.22))
    height += luminance(c.img) * 0.1
    return c, height


def wall_tile(rng, name, is_top, variant):
    """The tile of a wall added after the first ones (own generator)."""
    if name in PLANKS:
        return planks(rng, *PLANKS[name], not is_top)
    if name in BRICKS:
        return bricks(rng, *BRICKS[name], not is_top)
    if name == "SMOOTH_STONE":
        return smooth_stone(rng, not is_top)
    if name == "CUT_SANDSTONE":
        return cut_sandstone(rng, not is_top)
    if name == "WOOL":
        return wool(rng, not is_top)
    if name == "OLD_GLASS":
        return old_glass(rng, variant)
    if name == "LEADED_GLASS":
        return leaded_glass(rng, variant)
    if name == "WINDOW":
        return window(rng, variant)
    if "_WINDOW" in name:
        frame, design = name.split("_WINDOW")
        return window(rng, variant, frame, design)
    return glass(rng, variant)


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
        if row >= FIRST_OWN_SEED_WALL:
            own = np.random.default_rng(9000 + row)
            for column in range(4):
                tile, height = wall_tile(own, name, column < 2, column % 2)
                atlas.blit(tile, column * TILE, row * TILE)
                heights[row * TILE:(row + 1) * TILE, column * TILE:(column + 1) * TILE] = height
            continue
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


def build_faces(rng):
    """Every vertical face of the 3D world in one atlas (2 variants per row)."""
    rows = len(CLIFF_MATERIALS) + len(WALLS)
    atlas = Canvas(TILE * 2, TILE * rows)
    heights = np.zeros((TILE * rows, TILE * 2), dtype=np.float32)
    emission = Canvas(TILE * 2, TILE * rows)
    for material in range(len(CLIFF_MATERIALS)):
        for variant in range(2):
            tile, height = cliff_face(rng, material, False)
            atlas.blit(tile, variant * TILE, material * TILE)
            heights[material * TILE:(material + 1) * TILE, variant * TILE:(variant + 1) * TILE] = height
    for index, name in enumerate(WALLS):
        row = len(CLIFF_MATERIALS) + index
        if index >= FIRST_OWN_SEED_WALL:
            own = np.random.default_rng(9500 + index)
            for variant in range(2):
                tile, height = wall_tile(own, name, False, variant)
                atlas.blit(tile, variant * TILE, row * TILE)
                heights[row * TILE:(row + 1) * TILE, variant * TILE:(variant + 1) * TILE] = height
            continue
        if name in ORE_GEMS:
            base, gem, gem_light, glow = ORE_GEMS[name]
        else:
            base = {"STONE": "stone", "DEEPSLATE": "deep", "SANDSTONE": "sandstone",
                    "PACKED_ICE": "ice"}[name]
            gem = None
        for variant in range(2):
            tile, height = wall_face(rng, base)
            glow_tile = Canvas(TILE, TILE)
            if gem:
                gems(rng, tile, glow_tile, gem, gem_light, glow, False)
            atlas.blit(tile, variant * TILE, row * TILE)
            emission.blit(glow_tile, variant * TILE, row * TILE)
            heights[row * TILE:(row + 1) * TILE, variant * TILE:(variant + 1) * TILE] = height
    save(atlas.img, OUT / "tiles/face_atlas.png")
    save(normal_image(atlas.img, "flat", strength=3.0, height=heights), OUT / "tiles/face_atlas_n.png")
    emission.img[:, :, 3] = 255
    save(emission.img, OUT / "tiles/face_atlas_e.png")


def main():
    rng = np.random.default_rng(1234)
    build_grounds(rng)
    build_walls(rng)
    build_faces(rng)
    print("Art generated in", OUT)


if __name__ == "__main__":
    main()
