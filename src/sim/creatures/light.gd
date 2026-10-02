class_name Light
extends RefCounted
## Light as monsters feel it, on the server: daylight under the open sky,
## and the light of lava and of furnaces burning nearby (players' lanterns
## do not count: they draw monsters). Monsters come out where it is dark;
## the shade lurker freezes in the light and melts in daylight.

## Lava and fire light this far around them (tiles, a cube).
const REACH := 4


## Whether a cell (tile x, row, tile y) is lit: daylight from an open sky
## above it, or lava or a burning furnace within REACH.
static func is_lit(world: WorldState, cell: Vector3i, clock: WorldClock) -> bool:
	if not clock.is_night() and sky_open(world, cell):
		return true
	return near_fire(world.loaded_voxel_at, cell)


## Whether nothing of the terrain stands over a cell (rain and sun reach it).
static func sky_open(world: WorldState, cell: Vector3i) -> bool:
	var tile := Vector2i(cell.x, cell.z)
	var chunk: ChunkData = world.chunks.get(Coords.tile_to_chunk(tile))
	return chunk != null and chunk.top_row(Coords.tile_to_local(tile)) <= cell.y


## Whether lava or a burning furnace lies within REACH of a cell.
static func near_fire(voxel_at: Callable, cell: Vector3i) -> bool:
	var lava := Voxels.of_ground(Tiles.Ground.LAVA)
	for dy in range(-REACH, REACH + 1):
		for dz in range(-REACH, REACH + 1):
			for dx in range(-REACH, REACH + 1):
				var voxel: int = voxel_at.call(cell + Vector3i(dx, dy, dz))
				if voxel == lava:
					return true
				if voxel >= Voxels.BLOCK_BASE and ObjectShapes.is_lit(Voxels.block_of(voxel)):
					return true
	return false
