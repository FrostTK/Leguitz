class_name ClientWorld
extends RefCounted
## The client's copy of the chunks the server sent for the player's current
## layer. Used for rendering and for movement prediction. Missing chunks
## are treated as solid so the player can never walk into terrain that is
## not loaded yet.

var layer := WorldGenerator.SURFACE_LAYER
var chunks: Dictionary[Vector3i, ChunkData] = {}


func store(chunk: ChunkData) -> void:
	chunks[chunk.key()] = chunk


func remove(key: Vector3i) -> void:
	chunks.erase(key)


func clear() -> void:
	chunks.clear()


func has_tile_chunk(tile: Vector2i) -> bool:
	return chunks.has(WorldState.key_of(tile, layer))


func chunk_at(tile: Vector2i) -> ChunkData:
	return chunks.get(WorldState.key_of(tile, layer))


func is_solid(tile: Vector2i) -> bool:
	var chunk := chunk_at(tile)
	if chunk == null:
		return true
	return chunk.is_solid(Coords.tile_to_local(tile))


## Height a body stands at on a tile (INF: cannot go there, or unknown).
func top_at(tile: Vector2i) -> float:
	var chunk := chunk_at(tile)
	if chunk == null:
		return INF
	return chunk.top_height(Coords.tile_to_local(tile))


func ground_at(tile: Vector2i) -> int:
	var chunk := chunk_at(tile)
	return Tiles.Ground.NONE if chunk == null else chunk.get_ground(Coords.tile_to_local(tile))


func block_at(tile: Vector2i) -> int:
	var chunk := chunk_at(tile)
	return Tiles.Block.AIR if chunk == null else chunk.get_block(Coords.tile_to_local(tile))


func biome_at(tile: Vector2i) -> int:
	var chunk := chunk_at(tile)
	return Biomes.Id.NONE if chunk == null else chunk.get_biome(Coords.tile_to_local(tile))


func level_at(tile: Vector2i) -> int:
	var chunk := chunk_at(tile)
	return 0 if chunk == null else chunk.get_level(Coords.tile_to_local(tile))
