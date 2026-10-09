class_name BoatBody
extends RefCounted
## How a boat moves on the water (shared: the pilot's client steps its
## boat, the server checks it). The throttle (-1 astern .. 1) brings its
## speed towards ROW_SPEED with oars, ENGINE_SPEED with its engine running
## (Boat.powered), FULL_SPEED at full throttle (astern BACK_SHARE of it),
## at ROW_PUSH or ENGINE_PUSH tiles a second each second; let go, DRAG slows
## it. The helm turns it (TURN, slower the longer it is, little without way
## on; reversed astern). Flowing water carries it (CURRENT, downstream).
## It floats at the surface of the water it is on, and keeps to it: its
## hull (points along and across it, `fits`) must lie over water on its
## row, under nothing solid; land, ice, a fall of water stop it. Lava burns
## it (`step` says so). Positions in local units, speeds in tiles a second.

const ROW_SPEED := 2.0
const ENGINE_SPEED := 5.0
const FULL_SPEED := 7.5
const BACK_SHARE := 0.4
const ROW_PUSH := 1.6
const ENGINE_PUSH := 3.0
const DRAG := 0.9
const TURN := 1.9
const TURN_PER_SECTION := 0.2
const CURRENT := 1.2
## A move is cut into steps no longer than this (tiles).
const MOST_STEP := 0.2
## Its hull is looked at every SAMPLE tiles along it, an edge in from its
## sides.
const SAMPLE := 0.45
const EDGE := 0.12


## Moves a boat for `delta` seconds (see the class); `steer` -1 (left) to
## 1. Returns whether it touched lava.
static func step(
	boat: Boat, throttle: float, steer: float, full: bool, delta: float, voxel_at: Callable
) -> bool:
	var powered := boat.powered()
	var top := ROW_SPEED
	if powered:
		top = FULL_SPEED if full else ENGINE_SPEED
	if throttle == 0.0:
		boat.speed *= exp(-DRAG * delta)
		if absf(boat.speed) < 0.02:
			boat.speed = 0.0
	else:
		var target := throttle * top * (1.0 if throttle > 0.0 else BACK_SHARE)
		var push := ENGINE_PUSH if powered else ROW_PUSH
		boat.speed = move_toward(boat.speed, target, push * delta)
	var way := clampf(0.35 + absf(boat.speed) / ENGINE_SPEED, 0.0, 1.0)
	var backwards := -1.0 if boat.speed < -0.1 else 1.0
	var turn := TURN / (1.0 + TURN_PER_SECTION * boat.sections()) * steer * way * backwards
	var row := water_row(boat)
	var flow := current_at(boat.at, row, voxel_at)
	var yaw := boat.yaw - turn * delta
	if fits(boat, boat.at, yaw, row, voxel_at):
		boat.yaw = yaw
	var way_on := boat.forward() * boat.speed + flow * CURRENT
	var move := way_on * delta
	var steps := maxi(1, ceili(move.length() / MOST_STEP))
	for i in steps:
		var next := boat.at + Vector3(move.x, 0.0, move.y) / steps
		if not fits(boat, next, boat.yaw, row, voxel_at):
			boat.speed *= -0.2
			break
		boat.at = next
	boat.at.y = surface_at(boat.at, row, voxel_at)
	return touches_lava(boat, row, voxel_at)


## The water row a boat floats on.
static func water_row(boat: Boat) -> int:
	return floori(boat.at.y - 0.01) + GameConst.SEA_LEVEL


## Points of a hull at `at` turned `yaw` (on the ground): along it every
## SAMPLE tiles, on both sides and down its middle.
static func hull_points(boat: Boat, at: Vector3, yaw: float) -> Array[Vector2]:
	var way := Vector2(sin(yaw), cos(yaw))
	var side := Vector2(way.y, -way.x)
	var half := boat.length() * 0.5 - EDGE
	var across := Boat.WIDTH * Boat.VOXEL * 0.5 - EDGE
	var points: Array[Vector2] = [Vector2(at.x, at.z) + way * (half + EDGE * 0.5)]
	var count := ceili(half * 2.0 / SAMPLE)
	for i in count + 1:
		var along := -half + half * 2.0 * i / count
		for off: float in [-across, 0.0, across]:
			points.append(Vector2(at.x, at.z) + way * along + side * off)
	return points


## Whether the whole hull lies over water on `row`, nothing solid over it.
static func fits(boat: Boat, at: Vector3, yaw: float, row: int, voxel_at: Callable) -> bool:
	for point in hull_points(boat, at, yaw):
		var cell := Vector3i(floori(point.x), row, floori(point.y))
		if not Voxels.is_water(voxel_at.call(cell)):
			return false
		var over: int = voxel_at.call(cell + Vector3i.UP)
		if Voxels.is_solid(over) and not Voxels.is_liquid(over):
			return false
	return true


static func touches_lava(boat: Boat, row: int, voxel_at: Callable) -> bool:
	for point in hull_points(boat, boat.at, boat.yaw):
		for dy in [0, 1]:
			var cell := Vector3i(floori(point.x), row + dy, floori(point.y))
			if Voxels.is_lava(voxel_at.call(cell)):
				return true
		for side: Vector3i in Fluids.SIDES:
			var cell := Vector3i(floori(point.x), row, floori(point.y)) + side
			if Voxels.is_lava(voxel_at.call(cell)):
				return true
	return false


## The water's surface where the boat's middle is (local units).
static func surface_at(at: Vector3, row: int, voxel_at: Callable) -> float:
	var voxel: int = voxel_at.call(Vector3i(floori(at.x), row, floori(at.z)))
	var up := Fluids.surface(voxel) if Voxels.is_water(voxel) else 1.0
	return row - GameConst.SEA_LEVEL + up


## Which way flowing water carries what floats at `at` (towards its
## neighbors farther from the source; zero on still water).
static func current_at(at: Vector3, row: int, voxel_at: Callable) -> Vector2:
	var cell := Vector3i(floori(at.x), row, floori(at.z))
	var here: int = voxel_at.call(cell)
	var level := Fluids.level_of(here)
	if not Voxels.is_water(here) or level == 0 or level == Fluids.FALLING:
		return Vector2.ZERO
	var flow := Vector2.ZERO
	for side: Vector3i in Fluids.SIDES:
		var there: int = voxel_at.call(cell + side)
		if Voxels.is_water(there):
			var down := Fluids.level_of(there)
			if down == Fluids.FALLING:
				down = Fluids.WATER_REACH + 1
			flow += Vector2(side.x, side.z) * (down - level)
	return flow.normalized() if flow.length() > 0.01 else Vector2.ZERO
