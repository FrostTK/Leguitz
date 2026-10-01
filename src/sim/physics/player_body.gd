class_name PlayerBody
extends RefCounted
## A player's body among the voxels: feet position on the map (world
## pixels), height (levels) and vertical speed. Like in Minecraft it walks
## up rises of STEP_UP, falls off edges, bumps its head on ceilings and
## jumps 1.25 levels, so it climbs one voxel at a time.
## Shared by the client (prediction) and the server (validation).
##
## `voxel_at` is a Callable(cell: Vector3i) -> int giving the voxel at
## (tile x, row, tile y), Voxels.UNKNOWN where the world is not loaded.

## Collision box (width, depth) at the feet, in world pixels.
const BOX := Vector2(10.0, 6.0)
## Height of the body (levels): it fits through two-voxel gaps.
const BODY_HEIGHT := 1.7
## Small rises (a water bank) are walked up without jumping.
const STEP_UP := 0.2
## Tallest object (levels, see ObjectShapes.blocking_levels): how far down
## to look for a trunk rising into the body.
const MAX_OBJECT_LEVELS := 8
## Minecraft's numbers, in levels: gravity 32 /s^2, jumps 1.25 high.
const GRAVITY := 32.0
const JUMP_HEIGHT := 1.25
const MAX_FALL_SPEED := 60.0
const EPSILON := 0.001

var feet := Vector2.ZERO
var height := 0.0
var vertical_speed := 0.0
var on_ground := true
## Set when placed somewhere new: the body lands on the ground as soon as
## the ground there is known (its chunk may still be on its way).
var needs_landing := true


static func jump_speed() -> float:
	return sqrt(2.0 * GRAVITY * JUMP_HEIGHT)


## Highest place to stand at or below `limit` (levels) under a box: the
## top of a cube, or the surface of water. -INF while unknown voxels are
## in the way (or nothing at all is below).
static func support(at: Vector2, limit: float, voxel_at: Callable) -> float:
	var best := -INF
	var area := TileCollider.covered_tiles(at, BOX)
	for ty in range(area.position.y, area.end.y):
		for tx in range(area.position.x, area.end.x):
			best = maxf(best, _ground_below(Vector2i(tx, ty), limit, voxel_at))
	return best


## The box (world pixels) keeping a body standing at `height` out of a
## tile: the whole tile (something solid between its knees, above STEP_UP,
## and the top of its head, or lava under its feet), the foot of an object
## rising into it (a trunk, a rock: ObjectShapes), or nothing (an empty
## Rect2). Bodies walk between trees and under their crowns.
static func obstacle(tile: Vector2i, height: float, voxel_at: Callable) -> Rect2:
	var low := floori(height + STEP_UP + EPSILON) + GameConst.SEA_LEVEL
	var high := ceili(height + BODY_HEIGHT - EPSILON) + GameConst.SEA_LEVEL
	var whole := Rect2(Vector2(tile * GameConst.TILE_SIZE), Vector2.ONE * GameConst.TILE_SIZE)
	var under: int = voxel_at.call(Vector3i(tile.x, low - 1, tile.y))
	if Voxels.is_liquid(under) and Voxels.is_solid(under):
		return whole
	for row in range(low - MAX_OBJECT_LEVELS, high):
		var voxel: int = voxel_at.call(Vector3i(tile.x, row, tile.y))
		if not Voxels.is_solid(voxel):
			continue
		if Voxels.is_object(voxel):
			var block := Voxels.block_of(voxel)
			var levels := ObjectShapes.blocking_levels(block, ObjectShapes.variant_at(block, tile))
			if row + levels > low:
				return ObjectShapes.footprint_rect(block, tile)
		elif row >= low:
			return whole
	return Rect2()


## Height of the first voxel to stand on below `limit` in a column.
static func _ground_below(tile: Vector2i, limit: float, voxel_at: Callable) -> float:
	var row := mini(floori(limit) + GameConst.SEA_LEVEL, GameConst.WORLD_HEIGHT) - 1
	var above := Voxels.AIR
	while row >= 0:
		var voxel: int = voxel_at.call(Vector3i(tile.x, row, tile.y))
		if voxel == Voxels.UNKNOWN:
			return -INF
		if Voxels.is_cube(voxel):
			return float(row + 1 - GameConst.SEA_LEVEL)
		if Voxels.is_liquid(voxel) and not Voxels.is_liquid(above):
			# Water is walked on for now (wading); swimming comes later.
			return float(row + 1 - GameConst.SEA_LEVEL) - ChunkData.WATER_DROP
		above = voxel
		row -= 1
	return -INF


## Puts the body somewhere new (spawn, teleport, server correction).
func place(at: Vector2, at_height: float) -> void:
	feet = at
	height = at_height
	vertical_speed = 0.0
	needs_landing = true


## One frame of movement: `motion` on the map (world pixels), `jump` held.
func step(motion: Vector2, jump: bool, delta: float, voxel_at: Callable) -> void:
	if needs_landing:
		var ground := support(feet, height + STEP_UP, voxel_at)
		if ground == -INF:
			return
		height = ground
		on_ground = true
		needs_landing = false
	if motion != Vector2.ZERO:
		var current := height
		var obstacle_at := func(tile: Vector2i) -> Rect2: return obstacle(tile, current, voxel_at)
		feet = TileCollider.move(feet, motion, BOX, obstacle_at)
	var below := support(feet, height + STEP_UP, voxel_at)
	if below == -INF:
		return
	if on_ground and jump:
		vertical_speed = jump_speed()
		on_ground = false
	if not on_ground or height > below + EPSILON:
		on_ground = false
		# Exact under constant gravity: same jump whatever the frame rate.
		var next_speed := maxf(vertical_speed - GRAVITY * delta, -MAX_FALL_SPEED)
		var next_height := height + (vertical_speed + next_speed) * 0.5 * delta
		vertical_speed = next_speed
		if vertical_speed > 0.0:
			var ceiling := _ceiling_above(next_height, voxel_at)
			if next_height > ceiling:
				next_height = ceiling
				vertical_speed = 0.0
		height = next_height
		if height <= below:
			height = below
			vertical_speed = 0.0
			on_ground = true
	else:
		# Standing: follow small rises of the ground.
		height = below


## Ghost movement (debug): through everything, onto the highest ground.
func glide(motion: Vector2, voxel_at: Callable) -> void:
	feet += motion
	var ground := support(feet, GameConst.WORLD_HEIGHT, voxel_at)
	if ground != -INF:
		height = ground
	vertical_speed = 0.0
	on_ground = true
	needs_landing = false


## Highest feet height under the voxels above the head (INF if clear).
func _ceiling_above(next_height: float, voxel_at: Callable) -> float:
	var row := floori(next_height + BODY_HEIGHT) + GameConst.SEA_LEVEL
	var area := TileCollider.covered_tiles(feet, BOX)
	for ty in range(area.position.y, area.end.y):
		for tx in range(area.position.x, area.end.x):
			if Voxels.is_cube(voxel_at.call(Vector3i(tx, row, ty))):
				return float(row - GameConst.SEA_LEVEL) - BODY_HEIGHT
	return INF
