class_name Render3D
extends RefCounted
## How the tile world maps to the 3D scene.
##
## Terrain, voxel models and clouds are built in *local* units: one tile is one
## unit in X (east) and Z (south), one level (voxel row) is one unit in Y
## (up), level 0 being sea level.
## They live under a world root whose basis (root_basis) stretches that
## space for the camera. At DEFAULT_PITCH:
## - depth is stretched by 1 / sin(pitch) along the camera's horizontal
##   forward axis, so a tile top shows 16x16 px,
## - height is stretched by 1 / cos(pitch), so a level shows a 16 px face
##   and a voxel (1/16 unit) shows as one art pixel.
## At the default angle every art pixel lands on exactly one screen pixel
## (at 1x). Lower, the height stretch stays 1 / cos(pitch): things keep
## their height on screen while the ground flattens, and both stretches
## fade out towards the horizon, where a cube looks like a cube (nothing
## gets taller when the camera goes down). The stretch turns with the
## camera, so tiles stay square when the player orbits around.

const DEFAULT_PITCH := 60.0
const MIN_PITCH := 15.0
const MAX_PITCH := 78.0
const PIXELS_PER_UNIT := 16.0
## Local height of one level (one voxel).
const LEVEL_HEIGHT := 1.0

static var _default_vertical := 1.0 / cos(deg_to_rad(DEFAULT_PITCH))
static var _default_depth := 1.0 / sin(deg_to_rad(DEFAULT_PITCH))


## Height stretch for a camera tilted at `pitch` (radians): 1 / cos(pitch)
## up to the default angle (a level always shows 16 px tall), the default
## stretch when looking down more steeply.
static func vertical_scale(pitch: float) -> float:
	return 1.0 / cos(minf(pitch, deg_to_rad(DEFAULT_PITCH)))


## Depth stretch for a camera tilted at `pitch` (radians): the default one
## (a tile top shows 16 px at the default angle), fading out along with the
## height stretch when the camera goes down.
static func depth_stretch(pitch: float) -> float:
	var fade := (vertical_scale(pitch) - 1.0) / (_default_vertical - 1.0)
	return lerpf(1.0, _default_depth, fade)


## Basis of the world root for a camera turned by `yaw` around the vertical
## axis and tilted at `pitch` (radians). `amount` fades the stretch out (0:
## true proportions, for the first-person view).
static func root_basis(yaw: float, pitch: float, amount := 1.0) -> Basis:
	var turn := Basis(Vector3.UP, yaw)
	var vertical := lerpf(1.0, vertical_scale(pitch), amount)
	var depth := lerpf(1.0, depth_stretch(pitch), amount)
	var stretch := Basis.from_scale(Vector3(1.0, vertical, depth))
	return turn * stretch * turn.transposed()


## Local position of a point given in world pixels (2D) at a height.
static func world_px_to_local(world_px: Vector2, height: float) -> Vector3:
	var tiles := world_px / GameConst.TILE_SIZE
	return Vector3(tiles.x, height, tiles.y)


## Local position of a tile's center at a height.
static func tile_center_local(tile: Vector2i, height: float) -> Vector3:
	return Vector3(tile.x + 0.5, height, tile.y + 0.5)


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
