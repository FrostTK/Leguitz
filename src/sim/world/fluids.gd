class_name Fluids
extends RefCounted
## Water and lava flowing (Minecraft's, simpler), on the server (held by
## GameServer). The world's water and lava stay still until something next
## to them changes (GameServer.change_voxel: `touch`): then they flow, a
## step every WATER_TICKS (lava: LAVA_TICKS). Still liquids are sources:
## they never move nor dry up. Flowing ones are grounds of their own
## (Tiles.Ground.WATER_FLOW_1...): a level a cell farther from what feeds
## them, up to WATER_REACH (LAVA_REACH) on flat ground, or FALLING down
## from a liquid above (full, spreading like a source where it lands on
## something solid, merging into a liquid). They fill air and small
## plants, never what players placed; cut from what fed them they dry up.
## Two water sources around a cell standing on something make it a source
## (Minecraft's endless water). Water and lava meeting turn the lava into
## stone.

## How far each liquid spreads over flat ground (cells).
const WATER_REACH := 4
const LAVA_REACH := 2
## The level of a liquid falling from above (0: a source, 1 to the reach:
## flowing).
const FALLING := 8
## How often each liquid moves (server ticks: real time, like a body).
const WATER_TICKS := 5
const LAVA_TICKS := 30
## At most this many cells settle at a step; the others wait for the next.
const MAX_PER_STEP := 512
const SIDES: Array[Vector3i] = [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]
const AROUND: Array[Vector3i] = [
	Vector3i.ZERO,
	Vector3i.UP,
	Vector3i.DOWN,
	Vector3i.LEFT,
	Vector3i.RIGHT,
	Vector3i.FORWARD,
	Vector3i.BACK
]
## Each flowing ground's level.
const LEVELS := {
	Tiles.Ground.WATER_FLOW_1: 1,
	Tiles.Ground.WATER_FLOW_2: 2,
	Tiles.Ground.WATER_FLOW_3: 3,
	Tiles.Ground.WATER_FLOW_4: 4,
	Tiles.Ground.WATER_FALLING: FALLING,
	Tiles.Ground.LAVA_FLOW_1: 1,
	Tiles.Ground.LAVA_FLOW_2: 2,
	Tiles.Ground.LAVA_FALLING: FALLING,
}
## Each liquid's grounds by level (0 to its reach), and falling.
const WATER_FLOWS: Array[int] = [
	Tiles.Ground.WATER,
	Tiles.Ground.WATER_FLOW_1,
	Tiles.Ground.WATER_FLOW_2,
	Tiles.Ground.WATER_FLOW_3,
	Tiles.Ground.WATER_FLOW_4,
]
const LAVA_FLOWS: Array[int] = [
	Tiles.Ground.LAVA, Tiles.Ground.LAVA_FLOW_1, Tiles.Ground.LAVA_FLOW_2
]

## Cells to settle at the next water and lava steps.
var _water: Dictionary[Vector3i, bool] = {}
var _lava: Dictionary[Vector3i, bool] = {}


## A liquid voxel's level: 0 for a source, 1 to its reach flowing, FALLING.
static func level_of(voxel: int) -> int:
	return LEVELS.get(voxel, 0)


## The voxel of water (lava) at a level (see level_of).
static func voxel_for(lava: bool, level: int) -> int:
	if level == FALLING:
		return Voxels.of_ground(Tiles.Ground.LAVA_FALLING if lava else Tiles.Ground.WATER_FALLING)
	return Voxels.of_ground(LAVA_FLOWS[level] if lava else WATER_FLOWS[level])


## How high a liquid voxel fills its cell (levels, from its bottom):
## sources and falling ones up to ChunkData.WATER_DROP under the top,
## flowing ones less the farther they are, by whole art pixels.
static func surface(voxel: int) -> float:
	var level := level_of(voxel)
	if level == 0 or level == FALLING:
		return 1.0 - ChunkData.WATER_DROP
	var reach := LAVA_REACH if Voxels.is_lava(voxel) else WATER_REACH
	return floorf(16.0 * (reach + 1 - level) / (reach + 1)) / 16.0


## Whether a voxel is the liquid (lava, else water).
static func _is(voxel: int, lava: bool) -> bool:
	return Voxels.is_lava(voxel) if lava else Voxels.is_water(voxel)


## What a liquid flows into: air and small plants.
static func fillable(voxel: int) -> bool:
	return voxel == Voxels.AIR or (Voxels.is_object(voxel) and Mining.is_replaceable(voxel))


## Whether there are cells waiting to settle.
func is_moving() -> bool:
	return not _water.is_empty() or not _lava.is_empty()


## A voxel changed (`before`: what it was): the liquids in and around the
## cell settle at their next steps.
func touch(voxel_at: Callable, cell: Vector3i, before: int) -> void:
	var water := Voxels.is_water(before)
	var lava := Voxels.is_lava(before)
	for side in AROUND:
		var voxel: int = voxel_at.call(cell + side)
		water = water or Voxels.is_water(voxel)
		lava = lava or Voxels.is_lava(voxel)
	for side in AROUND:
		if water:
			_water[cell + side] = true
		if lava:
			_lava[cell + side] = true


## A server tick: water (lava) moves a step every WATER_TICKS (LAVA_TICKS).
func update(server: GameServer) -> void:
	if server.tick_count % WATER_TICKS == 0 and not _water.is_empty():
		var cells := _water
		_water = {}
		_step(server, cells, false)
	if server.tick_count % LAVA_TICKS == 0 and not _lava.is_empty():
		var cells := _lava
		_lava = {}
		_step(server, cells, true)


func _step(server: GameServer, cells: Dictionary[Vector3i, bool], lava: bool) -> void:
	var done := 0
	for cell: Vector3i in cells:
		if done >= MAX_PER_STEP:
			if lava:
				_lava[cell] = true
			else:
				_water[cell] = true
			continue
		done += 1
		_settle(server, cell, lava)


## Works out what a cell holds of the liquid now (see the class).
func _settle(server: GameServer, cell: Vector3i, lava: bool) -> void:
	var voxel_at: Callable = server.world.loaded_voxel_at
	var voxel: int = voxel_at.call(cell)
	var mine := _is(voxel, lava)
	if voxel == Voxels.UNKNOWN or (not mine and not fillable(voxel)):
		return
	var wanted := 0 if mine and level_of(voxel) == 0 else _wanted(voxel_at, cell, lava)
	if wanted < 0:
		if mine:
			server.change_voxel(cell, Voxels.AIR)
		return
	if lava and _touches_water(voxel_at, cell):
		# Lava meeting water hardens.
		server.change_voxel(cell, Voxels.of_block(Tiles.Block.STONE))
		return
	var target := voxel if mine and level_of(voxel) == 0 else voxel_for(lava, wanted)
	if target != voxel:
		server.change_voxel(cell, target)
	var pending := _lava if lava else _water
	for side in AROUND:
		if side == Vector3i.ZERO:
			continue
		var other: int = voxel_at.call(cell + side)
		if not lava and Voxels.is_lava(other):
			server.change_voxel(cell + side, Voxels.of_block(Tiles.Block.STONE))
		elif side != Vector3i.UP and fillable(other):
			# It flows out into what is free around (a source never changes).
			pending[cell + side] = true


## The level the liquid wants in a cell from its neighbors (-1: none).
static func _wanted(voxel_at: Callable, cell: Vector3i, lava: bool) -> int:
	if _is(voxel_at.call(cell + Vector3i.UP), lava):
		return FALLING
	var reach := LAVA_REACH if lava else WATER_REACH
	var best := reach + 1
	var sources := 0
	for side in SIDES:
		var other: int = voxel_at.call(cell + side)
		if not _is(other, lava):
			continue
		var level := level_of(other)
		if level == 0:
			sources += 1
		if _spreads(voxel_at, cell + side, level, lava):
			best = mini(best, (0 if level == FALLING else level) + 1)
	if not lava and sources >= 2 and _spreads(voxel_at, cell, 0, false):
		return 0
	return best if best <= reach else -1


## Whether the liquid at a cell (its level) spreads sideways: it stands on
## something solid, or a still one on a source of its own (not falling into
## a pool: it merges).
static func _spreads(voxel_at: Callable, cell: Vector3i, level: int, lava: bool) -> bool:
	var below: int = voxel_at.call(cell + Vector3i.DOWN)
	if _is(below, lava):
		return level != FALLING and level_of(below) == 0
	return not fillable(below) and not Voxels.is_liquid(below)


static func _touches_water(voxel_at: Callable, cell: Vector3i) -> bool:
	for side in AROUND:
		if side != Vector3i.ZERO and Voxels.is_water(voxel_at.call(cell + side)):
			return true
	return false
