class_name Render3D
extends RefCounted
## How the tile world maps to the 3D scene.
##
## Terrain, sprites and clouds are built in *local* units: one tile is one
## unit in X (east) and Z (south), one terrace level is one unit in Y (up).
## They live under a world root whose basis (root_basis) stretches that
## space for the camera, which looks down at DEFAULT_PITCH:
## - depth is stretched by 1 / sin(pitch) along the camera's horizontal
##   forward axis, so a tile top shows 16x16 px,
## - height is stretched by 1 / cos(pitch), so a level shows a 16 px face
##   and upright sprites keep their pixel height.
## At the default angle every art pixel lands on exactly one screen pixel
## (at 1x). The stretch turns with the camera, so tiles stay square when
## the player orbits around; tilting the camera changes the look like in
## any 3D game.

const DEFAULT_PITCH := 60.0
const MIN_PITCH := 38.0
const MAX_PITCH := 78.0
const PIXELS_PER_UNIT := 16.0
## Local height of one terrace level, of rock walls and placed blocks.
const LEVEL_HEIGHT := 1.0
const WALL_HEIGHT := ChunkData.CUBE_HEIGHT
## Water surface sits a little below the ground of its level.
const WATER_DEPTH := ChunkData.WATER_DROP

static var depth_stretch := 1.0 / sin(deg_to_rad(DEFAULT_PITCH))
static var vertical_scale := 1.0 / cos(deg_to_rad(DEFAULT_PITCH))


## Basis of the world root for a camera turned by `yaw` (radians) around
## the vertical axis.
static func root_basis(yaw: float) -> Basis:
	var turn := Basis(Vector3.UP, yaw)
	var stretch := Basis.from_scale(Vector3(1.0, vertical_scale, depth_stretch))
	return turn * stretch * turn.transposed()


## Local position of a point given in world pixels (2D) at a height.
static func world_px_to_local(world_px: Vector2, height: float) -> Vector3:
	var tiles := world_px / GameConst.TILE_SIZE
	return Vector3(tiles.x, height, tiles.y)


## Local position of a tile's center at a height.
static func tile_center_local(tile: Vector2i, height: float) -> Vector3:
	return Vector3(tile.x + 0.5, height, tile.y + 0.5)


## Local height of the walkable surface of a tile (water: just below).
static func surface_height(ground: int, level: int) -> float:
	var height := level * LEVEL_HEIGHT
	if Tiles.is_water(ground):
		height -= WATER_DEPTH
	return height


## Ground direction (tiles) of a screen direction (x right, y down) for a
## camera turned by `yaw`.
static func screen_to_ground(direction: Vector2, yaw: float) -> Vector2:
	var right := Vector2(cos(yaw), -sin(yaw))
	var down := Vector2(sin(yaw), cos(yaw))
	return right * direction.x + down * direction.y


## Screen direction of a ground direction (inverse of screen_to_ground).
static func ground_to_screen(direction: Vector2, yaw: float) -> Vector2:
	var right := Vector2(cos(yaw), -sin(yaw))
	var down := Vector2(sin(yaw), cos(yaw))
	return Vector2(direction.dot(right), direction.dot(down))
