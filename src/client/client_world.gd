class_name ClientWorld
extends RefCounted
## The client's copy of the chunks the server sent. Used for rendering and
## for movement prediction. Missing chunks are treated as solid so the
## player can never walk into terrain that is not loaded yet.

var chunks: Dictionary[Vector2i, ChunkData] = {}


func store(chunk: ChunkData) -> void:
	chunks[chunk.coord] = chunk


func remove(coord: Vector2i) -> void:
	chunks.erase(coord)


func has_chunk(coord: Vector2i) -> bool:
	return chunks.has(coord)


func is_solid(tile: Vector2i) -> bool:
	var chunk: ChunkData = chunks.get(Coords.tile_to_chunk(tile))
	if chunk == null:
		return true
	return Tiles.is_block_solid(chunk.get_block(Coords.tile_to_local(tile)))


func ground_at(tile: Vector2i) -> int:
	var chunk: ChunkData = chunks.get(Coords.tile_to_chunk(tile))
	if chunk == null:
		return Tiles.Ground.NONE
	return chunk.get_ground(Coords.tile_to_local(tile))


func block_at(tile: Vector2i) -> int:
	var chunk: ChunkData = chunks.get(Coords.tile_to_chunk(tile))
	if chunk == null:
		return Tiles.Block.AIR
	return chunk.get_block(Coords.tile_to_local(tile))
