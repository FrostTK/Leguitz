class_name Light
extends RefCounted
## Light as monsters feel it, on the server, in LightField's levels (0 to
## LightField.MAX): the sky's (MAX by day, NIGHT_SKY at night) coming down
## to the first cube and spreading into covered places, and that of what
## shines (lava, fires, torches, lanterns, lit furnaces; players' lanterns
## do not count: they draw monsters), a level less per cell (two through
## water). A cell is lit from LIT on: monsters come out where it is darker,
## the shade lurker freezes in the light, and those of the night melt in
## daylight under the open sky (sky_open).

## A cell is lit from this level on.
const LIT := 7
## The sky's light at night.
const NIGHT_SKY := 4
## Light from farther than this (cells) cannot reach LIT.
const REACH := LightField.MAX - LIT
const SIDES: Array[Vector3i] = [
	Vector3i.UP, Vector3i.DOWN, Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK
]


## Whether a cell (tile x, row, tile y) is lit (see the class).
static func is_lit(world: WorldState, cell: Vector3i, clock: WorldClock) -> bool:
	return level(world, cell, clock) >= LIT


## The light of a cell: exact from LIT up, lower levels may read lower.
static func level(world: WorldState, cell: Vector3i, clock: WorldClock) -> int:
	var sky := NIGHT_SKY if clock.is_night() else LightField.MAX
	var top_at := func(tile: Vector2i) -> int:
		var chunk: ChunkData = world.chunks.get(Coords.tile_to_chunk(tile))
		return chunk.top_row(Coords.tile_to_local(tile)) if chunk != null else ChunkData.HEIGHT
	return level_at(world.loaded_voxel_at, top_at, cell, sky)


## Whether lava or something burning lights a cell (LIT or more; no sky).
static func near_fire(voxel_at: Callable, cell: Vector3i) -> bool:
	return level_at(voxel_at, Callable(), cell, 0) >= LIT


## The light of a cell (see level) among voxels (`voxel_at`: cell -> voxel
## id), with the sky shining `sky` over the columns (`top_at`: tile -> the
## row over its highest voxel, see ChunkData.top_row; unused when `sky` is
## 0): from the cell, light is looked for REACH cells around.
static func level_at(voxel_at: Callable, top_at: Callable, cell: Vector3i, sky: int) -> int:
	var best := 0
	var distances := {cell: 0}
	var opens := {}
	var rings: Array[Array] = []
	rings.resize(REACH + 1)
	for d in rings.size():
		rings[d] = []
	rings[0].append(cell)
	for d in REACH + 1:
		for at: Vector3i in rings[d]:
			if distances[at] != d:
				continue
			var voxel: int = voxel_at.call(at)
			best = maxi(best, LightField.shine(voxel) - d)
			if sky - d > best and at.y >= _open_row(voxel_at, top_at, opens, at):
				best = sky - d
			if best >= LightField.MAX - d:
				return best
			# Light reaching this cell from a neighbor goes through it.
			var next := d + (2 if LightField.passing(voxel) == LightField.WATER else 1)
			if next > REACH:
				continue
			for side in SIDES:
				var other := at + side
				if distances.get(other, REACH + 1) <= next:
					continue
				var through: int = voxel_at.call(other)
				if LightField.passing(through) == LightField.OPAQUE:
					# Lava shines out of its opaque body.
					best = maxi(best, LightField.shine(through) - next)
					continue
				distances[other] = next
				rings[next].append(other)
	return best


## Whether nothing of the terrain stands over a cell (rain and sun reach it).
static func sky_open(world: WorldState, cell: Vector3i) -> bool:
	var tile := Vector2i(cell.x, cell.z)
	var chunk: ChunkData = world.chunks.get(Coords.tile_to_chunk(tile))
	return chunk != null and chunk.top_row(Coords.tile_to_local(tile)) <= cell.y


## The first row of a column from which the sky is fully seen (through
## what lets light by, see LightField.sky), kept in `opens`.
static func _open_row(voxel_at: Callable, top_at: Callable, opens: Dictionary, at: Vector3i) -> int:
	var tile := Vector2i(at.x, at.z)
	if not opens.has(tile):
		var y: int = top_at.call(tile) - 1
		while (
			y >= 0
			and LightField.passing(voxel_at.call(Vector3i(at.x, y, at.z))) == LightField.CLEAR
		):
			y -= 1
		opens[tile] = y + 1
	return opens[tile]
