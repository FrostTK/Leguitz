class_name ChunkData
extends RefCounted
## Raw content of a 16x16 chunk. Packed arrays are copy-on-write, so copies
## sent to clients are cheap until one side modifies them.

const FORMAT_VERSION := 1

var coord := Vector2i.ZERO
var ground := PackedByteArray()
var blocks := PackedByteArray()
## Set when a player changed the chunk (it must be saved, not regenerated).
var modified := false


func _init(chunk_coord := Vector2i.ZERO) -> void:
	coord = chunk_coord
	ground.resize(GameConst.CHUNK_AREA)
	blocks.resize(GameConst.CHUNK_AREA)


func get_ground(local: Vector2i) -> int:
	return ground[Coords.local_index(local)]


func get_block(local: Vector2i) -> int:
	return blocks[Coords.local_index(local)]


func set_ground(local: Vector2i, id: int) -> void:
	ground[Coords.local_index(local)] = id


func set_block(local: Vector2i, id: int) -> void:
	blocks[Coords.local_index(local)] = id


func duplicate_chunk() -> ChunkData:
	var copy := ChunkData.new(coord)
	copy.ground = ground.duplicate()
	copy.blocks = blocks.duplicate()
	copy.modified = modified
	return copy


func to_dict() -> Dictionary:
	return {
		"v": FORMAT_VERSION,
		"x": coord.x,
		"y": coord.y,
		"ground": ground,
		"blocks": blocks,
	}


static func from_dict(data: Dictionary) -> ChunkData:
	var chunk := ChunkData.new(Vector2i(data.get("x", 0), data.get("y", 0)))
	var g: PackedByteArray = data.get("ground", PackedByteArray())
	var b: PackedByteArray = data.get("blocks", PackedByteArray())
	if g.size() == GameConst.CHUNK_AREA:
		chunk.ground = g
	if b.size() == GameConst.CHUNK_AREA:
		chunk.blocks = b
	return chunk
