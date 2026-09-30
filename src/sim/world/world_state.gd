class_name WorldState
extends RefCounted
## Authoritative world content: the chunks currently loaded on the server,
## keyed by Vector3i(chunk_x, chunk_y, layer).

var generator: WorldGenerator
var chunks: Dictionary[Vector3i, ChunkData] = {}


func _init(world_generator: WorldGenerator) -> void:
	generator = world_generator


static func key_of(tile: Vector2i, layer: int) -> Vector3i:
	var chunk := Coords.tile_to_chunk(tile)
	return Vector3i(chunk.x, chunk.y, layer)


## Synchronous access (generates on the calling thread if needed).
func get_or_create_chunk(key: Vector3i) -> ChunkData:
	var chunk: ChunkData = chunks.get(key)
	if chunk == null:
		chunk = generator.generate_chunk(Vector2i(key.x, key.y), key.z)
		chunks[key] = chunk
	return chunk


func store(chunk: ChunkData) -> void:
	# A chunk generated twice (sync + async) keeps its first, maybe edited, copy.
	if not chunks.has(chunk.key()):
		chunks[chunk.key()] = chunk


func has_chunk(key: Vector3i) -> bool:
	return chunks.has(key)


func get_ground(tile: Vector2i, layer: int) -> int:
	var chunk: ChunkData = chunks.get(key_of(tile, layer))
	if chunk == null:
		return Tiles.Ground.NONE
	return chunk.get_ground(Coords.tile_to_local(tile))


func get_block(tile: Vector2i, layer: int) -> int:
	var chunk: ChunkData = chunks.get(key_of(tile, layer))
	if chunk == null:
		return Tiles.Block.AIR
	return chunk.get_block(Coords.tile_to_local(tile))


func is_solid(tile: Vector2i, layer: int) -> bool:
	return get_or_create_chunk(key_of(tile, layer)).is_solid(Coords.tile_to_local(tile))


## Closest walkable tile to `around` on a layer (spiral search), or `around`
## itself if none is found within `radius`.
func find_open_tile(around: Vector2i, layer: int, radius := 48) -> Vector2i:
	for r in radius:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var tile := around + Vector2i(dx, dy)
				if not is_solid(tile, layer) and not _is_liquid(tile, layer):
					return tile
	return around


## Drops unmodified chunks that no player needs. Modified chunks stay in
## memory until persistence exists (Phase 8 saves them to disk).
func unload_unused(needed: Dictionary) -> void:
	for key: Vector3i in chunks.keys():
		if not needed.has(key) and not chunks[key].modified:
			chunks.erase(key)


func _is_liquid(tile: Vector2i, layer: int) -> bool:
	var ground := get_or_create_chunk(key_of(tile, layer)).get_ground(Coords.tile_to_local(tile))
	return Tiles.is_water(ground) or ground == Tiles.Ground.LAVA
