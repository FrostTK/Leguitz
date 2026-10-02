class_name PlayerBody
extends RefCounted
## A player's body among the voxels: feet position on the map (world
## pixels), height (levels) and vertical speed. Like in Minecraft it walks
## up rises of STEP_UP, falls off edges, bumps its head on ceilings and
## jumps 1.25 levels, so it climbs one voxel at a time; it stands on cubes
## and on the furniture under it (a workbench, a chest, a furnace:
## ObjectShapes.stand_height). In water or lava it swims: it sinks slowly,
## rises while jump is held up to float with its head out, leaps out
## against a bank; falls end there (they never hurt). In creative it flies
## (fly; a spectator's ghost flies through everything).
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
## Swimming (levels, per second): rising while jump is held, sinking, how
## fast the speed eases towards those (per second); the feet float this
## far under the surface; a leap out against a bank rises this high.
const SWIM_UP := 2.6
const SINK_SPEED := 1.2
const LIQUID_DRAG := 6.0
const FLOAT_DEPTH := 0.45
const LEAP_HEIGHT := 1.45
## The eye, over the feet (levels): under the surface, the body has no air.
const EYE_HEIGHT := 1.35
## Flying (levels per second up or down, see fly), how fast the speed eases
## towards that (per second), and how far out of the world a ghost goes.
const FLY_SPEED := 7.0
const FLY_DRAG := 10.0
const GHOST_ABOVE := 24.0

var feet := Vector2.ZERO
var height := 0.0
var vertical_speed := 0.0
var on_ground := true
## Set when placed somewhere new: the body lands on the ground as soon as
## the ground there is known (its chunk may still be on its way).
var needs_landing := true
## The feet are in water or lava (`liquid`: which voxel; under its surface).
var in_liquid := false
var liquid := Voxels.AIR
## Flying (creative, see fly): no gravity until it lands.
var flying := false

## The highest point since the body left the ground, and how far it fell
## from there when it last landed (see take_fall).
var _fall_peak := 0.0
var _fallen := 0.0


static func jump_speed() -> float:
	return sqrt(2.0 * GRAVITY * JUMP_HEIGHT)


## The liquid voxel (water, lava) the feet of a body are in, under its
## surface (Voxels.AIR: none).
static func liquid_at(at: Vector2, at_height: float, voxel_at: Callable) -> int:
	var tile := Coords.world_to_tile(at)
	var row := floori(at_height + 0.05) + GameConst.SEA_LEVEL
	var voxel: int = voxel_at.call(Vector3i(tile.x, row, tile.y))
	if not Voxels.is_liquid(voxel):
		return Voxels.AIR
	return voxel if at_height < _surface(tile, row, voxel_at) else Voxels.AIR


## Whether the eye of a body is under water (it has no air).
static func eye_in_water(at: Vector2, at_height: float, voxel_at: Callable) -> bool:
	var eye := liquid_at(at, at_height + EYE_HEIGHT, voxel_at)
	return eye != Voxels.AIR and Tiles.is_water(Voxels.ground_of(eye))


## The surface (levels) of the liquid in a column, from one of its voxels.
static func _surface(tile: Vector2i, row: int, voxel_at: Callable) -> float:
	var top := row
	while Voxels.is_liquid(voxel_at.call(Vector3i(tile.x, top + 1, tile.y))):
		top += 1
	return float(top + 1 - GameConst.SEA_LEVEL) - ChunkData.WATER_DROP


## Highest place to stand at or below `limit` (levels) under a box: the
## top of a cube, or the top of furniture the box is over (liquids are
## swum in). -INF while unknown voxels are in the way (or nothing at all
## is below).
static func support(at: Vector2, limit: float, voxel_at: Callable) -> float:
	var best := -INF
	var body := TileCollider.body_rect(at, BOX)
	var area := TileCollider.covered_tiles(at, BOX)
	for ty in range(area.position.y, area.end.y):
		for tx in range(area.position.x, area.end.x):
			best = maxf(best, _ground_below(Vector2i(tx, ty), limit, voxel_at, body))
	return best


## The box (world pixels) keeping a body standing at `height` out of a
## tile: the whole tile (something solid between its knees, above STEP_UP,
## and the top of its head), the foot of an object
## rising into it (a trunk, a rock, furniture up to its top: ObjectShapes),
## or nothing (an empty Rect2). Bodies walk between trees and under their
## crowns, and onto furniture once they are as high as its top.
static func obstacle(tile: Vector2i, height: float, voxel_at: Callable) -> Rect2:
	var low := floori(height + STEP_UP + EPSILON) + GameConst.SEA_LEVEL
	var high := ceili(height + BODY_HEIGHT - EPSILON) + GameConst.SEA_LEVEL
	var whole := Rect2(Vector2(tile * GameConst.TILE_SIZE), Vector2.ONE * GameConst.TILE_SIZE)
	for row in range(low - MAX_OBJECT_LEVELS, high):
		var voxel: int = voxel_at.call(Vector3i(tile.x, row, tile.y))
		if not Voxels.is_solid(voxel) or Voxels.is_liquid(voxel):
			continue
		if Voxels.is_object(voxel):
			var block := Voxels.block_of(voxel)
			var variant := ObjectShapes.variant_at(block, tile)
			var top := row - GameConst.SEA_LEVEL + ObjectShapes.blocking_height(block, variant)
			if top > height + STEP_UP + EPSILON:
				return ObjectShapes.footprint_rect(block, tile)
		elif row >= low:
			return whole
	return Rect2()


## Height of the first voxel to stand on below `limit` in a column (under
## `body`, world pixels, for furniture, which does not fill its tile).
static func _ground_below(tile: Vector2i, limit: float, voxel_at: Callable, body: Rect2) -> float:
	var row := mini(floori(limit) + GameConst.SEA_LEVEL, GameConst.WORLD_HEIGHT) - 1
	# Furniture tops out inside its voxel: in the row of `limit` too.
	if row + 1 < GameConst.WORLD_HEIGHT:
		var in_limit: int = voxel_at.call(Vector3i(tile.x, row + 1, tile.y))
		var top := _furniture_top(tile, row + 1, in_limit, body)
		if top != -INF and top <= limit:
			return top
	while row >= 0:
		var voxel: int = voxel_at.call(Vector3i(tile.x, row, tile.y))
		if voxel == Voxels.UNKNOWN:
			return -INF
		if Voxels.is_cube(voxel):
			return float(row + 1 - GameConst.SEA_LEVEL)
		var top := _furniture_top(tile, row, voxel, body)
		if top != -INF:
			return top
		row -= 1
	return -INF


## The top (levels) of the furniture in a voxel when `body` (world pixels)
## is over its foot, else -INF.
static func _furniture_top(tile: Vector2i, row: int, voxel: int, body: Rect2) -> float:
	if not Voxels.is_object(voxel):
		return -INF
	var block := Voxels.block_of(voxel)
	var stand := ObjectShapes.stand_height(block)
	if stand <= 0.0 or not ObjectShapes.footprint_rect(block, tile).intersects(body):
		return -INF
	return float(row - GameConst.SEA_LEVEL) + stand


## Puts the body somewhere new (spawn, teleport, server correction).
func place(at: Vector2, at_height: float) -> void:
	feet = at
	height = at_height
	vertical_speed = 0.0
	needs_landing = true
	flying = false
	_fall_peak = at_height
	_fallen = 0.0


## How far (levels) the body fell before landing since the last call, from
## the highest point of its jump or of the edge it walked off.
func take_fall() -> float:
	var fallen := _fallen
	_fallen = 0.0
	return fallen


## One frame of movement: `motion` on the map (world pixels), `jump` held.
func step(motion: Vector2, jump: bool, delta: float, voxel_at: Callable) -> void:
	if needs_landing:
		var ground := support(feet, height + STEP_UP, voxel_at)
		if ground == -INF:
			return
		height = ground
		on_ground = true
		needs_landing = false
	var blocked := false
	if motion != Vector2.ZERO:
		var current := height
		var obstacle_at := func(tile: Vector2i) -> Rect2: return obstacle(tile, current, voxel_at)
		var before := feet
		feet = TileCollider.move(feet, motion, BOX, obstacle_at)
		blocked = feet.distance_to(before) < motion.length() * 0.5
	var below := support(feet, height + STEP_UP, voxel_at)
	if below == -INF:
		return
	var was_airborne := not on_ground
	var start_height := height
	liquid = liquid_at(feet, height, voxel_at)
	in_liquid = liquid != Voxels.AIR
	if in_liquid and not (on_ground and not jump and height <= below + EPSILON):
		_swim(jump, blocked, below, delta, voxel_at)
		# A fall ends in the liquid (it never hurts).
		_fall_peak = height
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
	if not on_ground:
		_fall_peak = maxf(_fall_peak if was_airborne else start_height, height)
	elif was_airborne:
		_fallen = maxf(_fallen, _fall_peak - height)


## Moves in water or lava: sinking slowly, rising while `jump` is held up
## to float FLOAT_DEPTH under the surface, leaping out when held against a
## bank (`blocked`) near the surface; lands on the ground `below`.
func _swim(jump: bool, blocked: bool, below: float, delta: float, voxel_at: Callable) -> void:
	on_ground = false
	var tile := Coords.world_to_tile(feet)
	var row := floori(height + 0.05) + GameConst.SEA_LEVEL
	var floating := _surface(tile, row, voxel_at) - FLOAT_DEPTH
	var leaping := vertical_speed > SWIM_UP + 0.01
	if jump and blocked and height >= floating - 0.25 and not leaping:
		vertical_speed = sqrt(2.0 * GRAVITY * LEAP_HEIGHT)
		leaping = true
	if leaping:
		vertical_speed -= GRAVITY * delta
	else:
		var target := -SINK_SPEED
		if jump:
			target = SWIM_UP if height < floating else 0.0
		vertical_speed += (target - vertical_speed) * (1.0 - exp(-LIQUID_DRAG * delta))
	var next_height := height + vertical_speed * delta
	if jump and not leaping and next_height > floating and vertical_speed > 0.0:
		next_height = maxf(floating, height)
		vertical_speed = 0.0
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


## One frame of flight: `motion` on the map, rising while `up` is held,
## sinking while `down` is (FLY_SPEED, eased), no gravity. It bumps into
## walls and ceilings and lands on the ground, which ends the flight; a
## fall only counts from where the flight ended (take_fall). A `ghost` (a
## spectator) flies through everything and never lands.
func fly(
	motion: Vector2, up: bool, down: bool, delta: float, voxel_at: Callable, ghost := false
) -> void:
	var target := (FLY_SPEED if up else 0.0) - (FLY_SPEED if down else 0.0)
	vertical_speed += (target - vertical_speed) * (1.0 - exp(-FLY_DRAG * delta))
	on_ground = false
	needs_landing = false
	_fall_peak = height
	if ghost:
		feet += motion
		var top := GameConst.WORLD_HEIGHT - GameConst.SEA_LEVEL + GHOST_ABOVE
		height = clampf(height + vertical_speed * delta, -GameConst.SEA_LEVEL, top)
		in_liquid = false
		liquid = Voxels.AIR
		return
	if motion != Vector2.ZERO:
		var current := height
		var obstacle_at := func(tile: Vector2i) -> Rect2: return obstacle(tile, current, voxel_at)
		feet = TileCollider.move(feet, motion, BOX, obstacle_at)
	var below := support(feet, height + STEP_UP, voxel_at)
	var next_height := height + vertical_speed * delta
	if vertical_speed > 0.0:
		var ceiling := _ceiling_above(next_height, voxel_at)
		if next_height > ceiling:
			next_height = ceiling
			vertical_speed = 0.0
	if below != -INF and next_height <= below:
		next_height = below
		vertical_speed = 0.0
		on_ground = true
		flying = false
	height = next_height
	_fall_peak = height
	liquid = liquid_at(feet, height, voxel_at)
	in_liquid = liquid != Voxels.AIR


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
