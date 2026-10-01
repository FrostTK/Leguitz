class_name ClientWorld
extends RefCounted
## The client's copy of the chunks the server sent. Used for rendering and
## for movement prediction. Missing chunks read as Voxels.UNKNOWN (solid)
## so the player can never walk into terrain that is not loaded yet.

## Above this much terrain over its head, the player is underground (or
## under a roof): the view cuts the world above them.
const COVER_ABOVE := 2.5

var chunks: Dictionary[Vector2i, ChunkData] = {}


func store(chunk: ChunkData) -> void:
	chunks[chunk.coord] = chunk


func remove(coord: Vector2i) -> void:
	chunks.erase(coord)


func clear() -> void:
	chunks.clear()


func chunk_at(tile: Vector2i) -> ChunkData:
	return chunks.get(Coords.tile_to_chunk(tile))


## Voxel at a cell (tile x, row, tile y); see PlayerBody.
func voxel_at(cell: Vector3i) -> int:
	if cell.y < 0:
		return Voxels.UNKNOWN
	if cell.y >= GameConst.WORLD_HEIGHT:
		return Voxels.AIR
	var tile := Vector2i(cell.x, cell.z)
	var chunk := chunk_at(tile)
	if chunk == null:
		return Voxels.UNKNOWN
	var local := Coords.tile_to_local(tile)
	return chunk.get_voxel(Vector3i(local.x, cell.y, local.y))


## Height (levels) of the terrain surface of a column (-INF if unknown).
func surface_height(tile: Vector2i) -> float:
	var chunk := chunk_at(tile)
	return -INF if chunk == null else chunk.surface_height(Coords.tile_to_local(tile))


## Ground under feet standing at `height` (Tiles.Ground.NONE on blocks).
func ground_under(tile: Vector2i, height: float) -> int:
	var row := floori(height + ChunkData.WATER_DROP + 0.01) + GameConst.SEA_LEVEL - 1
	return Voxels.ground_of(voxel_at(Vector3i(tile.x, row, tile.y)))


func biome_at(tile: Vector2i) -> int:
	var chunk := chunk_at(tile)
	return Biomes.Id.NONE if chunk == null else chunk.get_biome(Coords.tile_to_local(tile))


## True when terrain covers a body standing at `height`: in a cave, a dug
## tunnel, or under a roof.
func is_covered(tile: Vector2i, height: float) -> bool:
	var chunk := chunk_at(tile)
	if chunk == null:
		return false
	var top := chunk.top_row(Coords.tile_to_local(tile)) - GameConst.SEA_LEVEL
	return top > height + COVER_ABOVE
