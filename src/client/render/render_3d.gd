class_name Render3D
extends RefCounted
## How the 2D tile world maps to the 3D scene.
##
## The camera is orthographic, pitched PITCH_DEGREES below the horizon and
## looking north, like Stardew Valley's view. Distances are chosen so that
## every art pixel lands on exactly one screen pixel (at 1x):
## - a tile is 1 unit wide (X) and Z_STRETCH units deep (Z), so its top
##   face shows 16x16 px,
## - vertical faces are foreshortened by cos(pitch), so one terrace level
##   is LEVEL_HEIGHT units tall and shows a 16 px tall cliff face,
## - upright sprites (trees, player) are scaled by SPRITE_Y_SCALE.
## World axes: +X east, +Z south (tile y), +Y up.

const PITCH_DEGREES := 60.0
const PIXELS_PER_UNIT := 16.0
## Height of one terrace level (a 16 px tall face on screen).
const LEVEL_HEIGHT := 2.0
## Rock walls and placed blocks are one level tall.
const WALL_HEIGHT := LEVEL_HEIGHT
## Water surface sits a little below the ground of its level.
const WATER_DEPTH := 0.3

static var z_stretch := 1.0 / sin(deg_to_rad(PITCH_DEGREES))
static var sprite_y_scale := 1.0 / cos(deg_to_rad(PITCH_DEGREES))


static func level_height(level: int) -> float:
	return level * LEVEL_HEIGHT


## 3D position of a point given in world pixels (2D) at a height.
static func world_px_to_3d(world_px: Vector2, height: float) -> Vector3:
	var tiles := world_px / GameConst.TILE_SIZE
	return Vector3(tiles.x, height, tiles.y * z_stretch)


## 3D position of a tile's center at a height.
static func tile_center_3d(tile: Vector2i, height: float) -> Vector3:
	return Vector3(tile.x + 0.5, height, (tile.y + 0.5) * z_stretch)


## Height of the walkable surface of a tile (0 for water: its bed).
static func surface_height(ground: int, level: int) -> float:
	var height := level_height(level)
	if Tiles.is_water(ground):
		height -= WATER_DEPTH
	return height
