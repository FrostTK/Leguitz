class_name WorldState
extends RefCounted
## Authoritative world content: the chunks currently loaded on the server,
## keyed by chunk coordinate.

## Clear rows a body needs above the voxel it stands on.
const HEADROOM := 2

var generator: WorldGenerator
var chunks: Dictionary[Vector2i, ChunkData] = {}


func _init(world_generator: WorldGenerator) -> void:
	generator = world_generator


## Synchronous access (generates on the calling thread if needed).
func get_or_create_chunk(coord: Vector2i) -> ChunkData:
	var chunk: ChunkData = chunks.get(coord)
	if chunk == null:
		chunk = generator.generate_chunk(coord)
		chunks[coord] = chunk
	return chunk


func store(chunk: ChunkData) -> void:
	# A chunk generated twice (sync + async) keeps its first, maybe edited, copy.
	if not chunks.has(chunk.coord):
		chunks[chunk.coord] = chunk


func has_chunk(coord: Vector2i) -> bool:
	return chunks.has(coord)


## Voxel at a cell (tile x, row, tile y), generating its chunk if needed.
func voxel_at(cell: Vector3i) -> int:
	if cell.y < 0:
		return Voxels.UNKNOWN
	if cell.y >= GameConst.WORLD_HEIGHT:
		return Voxels.AIR
	var tile := Vector2i(cell.x, cell.z)
	var local := Coords.tile_to_local(tile)
	return get_or_create_chunk(Coords.tile_to_chunk(tile)).get_voxel(
		Vector3i(local.x, cell.y, local.y)
	)


## Height (levels) of the terrain surface of a column.
func surface_height(tile: Vector2i) -> float:
	var chunk := get_or_create_chunk(Coords.tile_to_chunk(tile))
	return chunk.surface_height(Coords.tile_to_local(tile))


## True if a body can stand on the voxel under `row` in a column: a dry
## cube with room above it.
func can_stand(tile: Vector2i, row: int) -> bool:
	if row < 1 or row + HEADROOM > GameConst.WORLD_HEIGHT:
		return false
	if not Voxels.is_cube(voxel_at(Vector3i(tile.x, row - 1, tile.y))):
		return false
	for y in range(row, row + HEADROOM):
		if Voxels.is_solid(voxel_at(Vector3i(tile.x, y, tile.y))):
			return false
	return true


## Height (levels) of the next place to stand under (direction -1) or
## above (+1) a body standing at `height` in a column, beyond the voxel it
## stands on (down) or the ceiling over its head (up); NAN if none.
func next_floor(tile: Vector2i, height: float, direction: int) -> float:
	var row := floori(height + 0.01) + GameConst.SEA_LEVEL
	if direction < 0:
		for y in range(row - 1 - HEADROOM, 0, -1):
			if can_stand(tile, y):
				return float(y - GameConst.SEA_LEVEL)
	else:
		for y in range(row + HEADROOM + 1, GameConst.WORLD_HEIGHT - HEADROOM + 1):
			if can_stand(tile, y):
				return float(y - GameConst.SEA_LEVEL)
	return NAN


## The closest column around `around` (spiral search) with a place to
## stand under (direction -1) or above (+1) `height`: [tile, height], or
## an empty array if none is found within `radius`.
func find_floor(around: Vector2i, height: float, direction: int, radius := 24) -> Array:
	for r in radius:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var tile := around + Vector2i(dx, dy)
				var floor_height := next_floor(tile, height, direction)
				if not is_nan(floor_height):
					return [tile, floor_height]
	return []


## Drops unmodified chunks that no player needs. Modified chunks stay in
## memory until persistence exists.
func unload_unused(needed: Dictionary) -> void:
	for coord: Vector2i in chunks.keys():
		if not needed.has(coord) and not chunks[coord].modified:
			chunks.erase(coord)
