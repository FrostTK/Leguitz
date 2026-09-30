class_name WorldState
extends RefCounted
## Authoritative world content: the chunks currently loaded on the server.

var generator: TerrainGenerator
var chunks: Dictionary[Vector2i, ChunkData] = {}


func _init(world_generator: TerrainGenerator) -> void:
	generator = world_generator


func get_or_create_chunk(coord: Vector2i) -> ChunkData:
	var chunk: ChunkData = chunks.get(coord)
	if chunk == null:
		chunk = generator.generate_chunk(coord)
		chunks[coord] = chunk
	return chunk


func has_chunk(coord: Vector2i) -> bool:
	return chunks.has(coord)


func get_ground(tile: Vector2i) -> int:
	var chunk: ChunkData = chunks.get(Coords.tile_to_chunk(tile))
	if chunk == null:
		return Tiles.Ground.NONE
	return chunk.get_ground(Coords.tile_to_local(tile))


func get_block(tile: Vector2i) -> int:
	var chunk: ChunkData = chunks.get(Coords.tile_to_chunk(tile))
	if chunk == null:
		return Tiles.Block.AIR
	return chunk.get_block(Coords.tile_to_local(tile))


## Drops unmodified chunks that no player needs. Modified chunks stay in
## memory until persistence exists (Phase 8 saves them to disk).
func unload_unused(needed: Dictionary) -> void:
	for coord: Vector2i in chunks.keys():
		if not needed.has(coord) and not chunks[coord].modified:
			chunks.erase(coord)
