class_name Coords
extends RefCounted
## Conversions between world pixels, tiles and chunks.
## Arithmetic shifts are used so negative coordinates floor correctly.


static func tile_to_chunk(tile: Vector2i) -> Vector2i:
	return Vector2i(tile.x >> GameConst.CHUNK_SHIFT, tile.y >> GameConst.CHUNK_SHIFT)


static func tile_to_local(tile: Vector2i) -> Vector2i:
	return Vector2i(tile.x & GameConst.CHUNK_MASK, tile.y & GameConst.CHUNK_MASK)


static func chunk_origin_tile(chunk: Vector2i) -> Vector2i:
	return Vector2i(chunk.x << GameConst.CHUNK_SHIFT, chunk.y << GameConst.CHUNK_SHIFT)


static func local_index(local: Vector2i) -> int:
	return local.y * GameConst.CHUNK_SIZE + local.x


static func world_to_tile(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		floori(world_pos.x / GameConst.TILE_SIZE), floori(world_pos.y / GameConst.TILE_SIZE)
	)


static func world_to_chunk(world_pos: Vector2) -> Vector2i:
	return tile_to_chunk(world_to_tile(world_pos))


static func tile_to_world_center(tile: Vector2i) -> Vector2:
	return (Vector2(tile) + Vector2(0.5, 0.5)) * GameConst.TILE_SIZE


static func chunk_to_world(chunk: Vector2i) -> Vector2:
	return Vector2(chunk * GameConst.CHUNK_PIXELS)


## Chebyshev distance between two chunk coordinates (square view areas).
static func chunk_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))
