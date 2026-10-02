class_name Growth
extends RefCounted
## What grows by itself, on the server (stateless, given the server):
## saplings become young trees, then trees; bare dirt next to grass turns
## into grass; crops grow and farmland gets wet or dries (Farming). The
## cells where something may grow are kept per chunk (ChunkData.growing:
## noted by WorldState.set_voxel, saved with the chunk). Every CHECK_TICKS
## each has a chance to go a stage further (on average after
## SAPLING_SECONDS, YOUNG_SECONDS, GRASS_SECONDS, paced by
## WorldClock.scale_duration), only in the light (Light.level from LIGHT:
## the night and the dark stop them, a torch or a lantern near makes them
## grow) and with room: a tree wants the rows over it free and no solid
## object on the tiles around (bodies always pass between trees, as
## WorldGenerator._spaced keeps them).

const CHECK_TICKS := GameConst.TICKS_PER_SECOND * 5
const LIGHT := 9
const SAPLING_SECONDS := 240.0
const YOUNG_SECONDS := 480.0
const GRASS_SECONDS := 60.0
## Rows over a young tree (over a tree's trunk) that must be free.
const CROWN_ROWS := 2

## What each sapling grows into, and each young tree.
const SAPLINGS := {
	Tiles.Block.OAK_SAPLING: Tiles.Block.YOUNG_OAK,
	Tiles.Block.BIRCH_SAPLING: Tiles.Block.YOUNG_BIRCH,
	Tiles.Block.SPRUCE_SAPLING: Tiles.Block.YOUNG_SPRUCE,
	Tiles.Block.DARK_OAK_SAPLING: Tiles.Block.YOUNG_DARK_OAK,
	Tiles.Block.JUNGLE_SAPLING: Tiles.Block.YOUNG_JUNGLE_TREE,
	Tiles.Block.ACACIA_SAPLING: Tiles.Block.YOUNG_ACACIA,
	Tiles.Block.SWAMP_OAK_SAPLING: Tiles.Block.YOUNG_SWAMP_OAK,
}
const YOUNG := {
	Tiles.Block.YOUNG_OAK: Tiles.Block.OAK,
	Tiles.Block.YOUNG_BIRCH: Tiles.Block.BIRCH,
	Tiles.Block.YOUNG_SPRUCE: Tiles.Block.SPRUCE,
	Tiles.Block.YOUNG_DARK_OAK: Tiles.Block.DARK_OAK,
	Tiles.Block.YOUNG_JUNGLE_TREE: Tiles.Block.JUNGLE_TREE,
	Tiles.Block.YOUNG_ACACIA: Tiles.Block.ACACIA,
	Tiles.Block.YOUNG_SWAMP_OAK: Tiles.Block.SWAMP_OAK,
}
## Where a spruce grows snowy.
const SNOWY_BIOMES := {
	Biomes.Id.SNOWY_PLAINS: true,
	Biomes.Id.SNOWY_TAIGA: true,
	Biomes.Id.SNOWY_BEACH: true,
	Biomes.Id.SNOWY_SLOPES: true,
	Biomes.Id.GROVE: true,
}
## What grass spreads onto bare dirt (each its own kind).
const GRASSES := {
	Tiles.Ground.GRASS: true,
	Tiles.Ground.FOREST_GRASS: true,
	Tiles.Ground.MEADOW_GRASS: true,
	Tiles.Ground.TAIGA_GRASS: true,
	Tiles.Ground.JUNGLE_GRASS: true,
	Tiles.Ground.SWAMP_GRASS: true,
	Tiles.Ground.DRY_GRASS: true,
}
## What saplings are planted in: grasses and these.
const SOILS := {
	Tiles.Ground.DIRT: true,
	Tiles.Ground.PODZOL: true,
	Tiles.Ground.MUD: true,
	Tiles.Ground.MYCELIUM: true,
}
const AROUND: Array[Vector2i] = [
	Vector2i(-1, -1),
	Vector2i(0, -1),
	Vector2i(1, -1),
	Vector2i(-1, 0),
	Vector2i(1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
	Vector2i(1, 1),
]


## Whether a sapling can be planted on a voxel.
static func is_soil(voxel: int) -> bool:
	return voxel < Voxels.BLOCK_BASE and (SOILS.has(voxel) or GRASSES.has(voxel))


## Whether something set in a cell may grow: a sapling, a young tree, an
## unripe crop, dirt, farmland, a full composter (rotting).
static func may_grow(voxel: int) -> bool:
	var block := Voxels.block_of(voxel)
	return (
		SAPLINGS.has(block)
		or YOUNG.has(block)
		or Farming.STAGES.has(block)
		or voxel == Voxels.of_ground(Tiles.Ground.DIRT)
		or Farming.is_farmland(voxel)
		or block == Tiles.Block.COMPOSTER_FULL
	)


## A voxel of a chunk changed (WorldState.set_voxel): what may grow there,
## and the dirt under it laid bare; what is no farmland any more forgets
## its water.
static func note(chunk: ChunkData, cell: Vector3i, voxel: int) -> void:
	if may_grow(voxel):
		chunk.growing[cell] = true
	else:
		chunk.growing.erase(cell)
	if not Farming.is_farmland(voxel):
		chunk.watered.erase(cell)
	if cell.y > 0 and not Voxels.is_cube(voxel) and not Voxels.is_liquid(voxel):
		var local := Coords.tile_to_local(Vector2i(cell.x, cell.z))
		var under := chunk.get_voxel(Vector3i(local.x, cell.y - 1, local.y))
		if under == Voxels.of_ground(Tiles.Ground.DIRT):
			chunk.growing[cell + Vector3i.DOWN] = true


## Lets everything that may grow in the loaded chunks have its chance
## (every CHECK_TICKS; `chance` instead of the odds of the durations: tests).
static func update(server: GameServer, chance := -1.0) -> void:
	var seconds := CHECK_TICKS * GameConst.TICK_DELTA
	for chunk: ChunkData in server.world.chunks.values():
		if chunk.growing.is_empty():
			continue
		for cell: Vector3i in chunk.growing.keys():
			_grow(server, chunk, cell, chance, seconds)


static func _grow(
	server: GameServer, chunk: ChunkData, cell: Vector3i, chance: float, seconds: float
) -> void:
	var world := server.world
	var voxel := world.loaded_voxel_at(cell)
	var block := Voxels.block_of(voxel)
	var dirt := voxel == Voxels.of_ground(Tiles.Ground.DIRT)
	if Farming.is_farmland(voxel):
		var fallow := seconds / server.clock.scale_duration(Farming.FALLOW_SECONDS)
		var watered := Watering.dry_out(server, chunk, cell, seconds)
		Farming.settle_farmland(server, cell, voxel, chance if chance >= 0.0 else fallow, watered)
		return
	if block == Tiles.Block.COMPOSTER_FULL:
		var rot := seconds / server.clock.scale_duration(Composting.ROT_SECONDS)
		if server.rng.randf() < (chance if chance >= 0.0 else rot):
			server.change_voxel(cell, Voxels.of_block(Tiles.Block.COMPOSTER_READY))
		return
	var mean := GRASS_SECONDS
	if SAPLINGS.has(block):
		mean = SAPLING_SECONDS
	elif YOUNG.has(block):
		mean = YOUNG_SECONDS
	elif Farming.STAGES.has(block):
		if not Farming.is_farmland(world.loaded_voxel_at(cell + Vector3i.DOWN)):
			return
		mean = Farming.stage_seconds(world, cell)
	elif not dirt or not _bare(world, cell):
		chunk.growing.erase(cell)
		return
	var odds := chance if chance >= 0.0 else seconds / server.clock.scale_duration(mean)
	if server.rng.randf() >= odds:
		return
	var lit_at := cell + Vector3i.UP if dirt else cell
	if Light.level(world, lit_at, server.clock) < LIGHT:
		return
	var next := next_stage(world, chunk, cell, voxel)
	if next != voxel:
		server.change_voxel(cell, next)


## What a cell grows into now (itself: not yet, no room).
static func next_stage(world: WorldState, chunk: ChunkData, cell: Vector3i, voxel: int) -> int:
	var block := Voxels.block_of(voxel)
	if voxel == Voxels.of_ground(Tiles.Ground.DIRT):
		for side in AROUND:
			for dy in range(-1, 2):
				var other := world.loaded_voxel_at(cell + Vector3i(side.x, dy, side.y))
				if GRASSES.has(other) and _bare(world, cell + Vector3i(side.x, dy, side.y)):
					return other
		return voxel
	if Farming.STAGES.has(block):
		return Voxels.of_block(Farming.STAGES[block])
	if not _spaced(world, cell):
		return voxel
	if SAPLINGS.has(block):
		var young: int = SAPLINGS[block]
		return Voxels.of_block(young) if _room(world, cell, CROWN_ROWS) else voxel
	var tree := tree_for(block, chunk.get_biome(Coords.tile_to_local(Vector2i(cell.x, cell.z))))
	var variant := ObjectShapes.variant_at(tree, Vector2i(cell.x, cell.z))
	var rows := ObjectShapes.blocking_levels(tree, variant) + CROWN_ROWS
	return Voxels.of_block(tree) if _room(world, cell, rows) else voxel


## The tree a young one becomes in a biome (a spruce in the snow: snowy).
static func tree_for(young: int, biome: int) -> int:
	var tree: int = YOUNG[young]
	if tree == Tiles.Block.SPRUCE and SNOWY_BIOMES.has(biome):
		return Tiles.Block.SNOWY_SPRUCE
	return tree


## Nothing lies on a cell but air or a plant (no cube, no liquid): dirt
## under a flower still turns green.
static func _bare(world: WorldState, cell: Vector3i) -> bool:
	var above := world.loaded_voxel_at(cell + Vector3i.UP)
	return not Voxels.is_cube(above) and not Voxels.is_liquid(above) and above != Voxels.UNKNOWN


## The `rows` rows over a cell let a tree grow through (air, plants).
static func _room(world: WorldState, cell: Vector3i, rows: int) -> bool:
	for up in range(1, rows + 1):
		var voxel := world.loaded_voxel_at(cell + Vector3i(0, up, 0))
		if voxel == Voxels.UNKNOWN or Voxels.is_solid(voxel) or Voxels.is_liquid(voxel):
			return false
	return true


## No solid object stands on the tiles around (nor anything unknown).
static func _spaced(world: WorldState, cell: Vector3i) -> bool:
	for side in AROUND:
		var voxel := world.loaded_voxel_at(cell + Vector3i(side.x, 0, side.y))
		if voxel == Voxels.UNKNOWN or (Voxels.is_object(voxel) and Voxels.is_solid(voxel)):
			return false
	return true
