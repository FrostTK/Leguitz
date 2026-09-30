class_name ChunkData
extends RefCounted
## Raw content of a 16x16 chunk of one layer (0 = surface, < 0 underground).
##
## Per tile: ground id, block id, terrace level (surface height step),
## shape flags (cliff edges, ramps) and biome id.

const FORMAT_VERSION := 2

## Shape flags: which 4-neighbors are on a lower terrace level. A tile with
## any of these is a cliff edge (solid) unless it is a ramp.
const SHAPE_LOWER_N := 1
const SHAPE_LOWER_E := 2
const SHAPE_LOWER_S := 4
const SHAPE_LOWER_W := 8
const SHAPE_EDGE_MASK := 15
## Walkable slope through a cliff edge.
const SHAPE_RAMP := 16
## The tile right under a south-facing cliff face (drawn in its shadow).
const SHAPE_SHADOW := 32

var coord := Vector2i.ZERO
var layer := 0
var ground := PackedByteArray()
var blocks := PackedByteArray()
var levels := PackedByteArray()
var shapes := PackedByteArray()
var biome := PackedByteArray()
## Set when a player changed the chunk (it must be saved, not regenerated).
var modified := false


func _init(chunk_coord := Vector2i.ZERO, chunk_layer := 0) -> void:
	coord = chunk_coord
	layer = chunk_layer
	# Packed arrays are values: resize each member directly.
	ground.resize(GameConst.CHUNK_AREA)
	blocks.resize(GameConst.CHUNK_AREA)
	levels.resize(GameConst.CHUNK_AREA)
	shapes.resize(GameConst.CHUNK_AREA)
	biome.resize(GameConst.CHUNK_AREA)


func key() -> Vector3i:
	return Vector3i(coord.x, coord.y, layer)


func get_ground(local: Vector2i) -> int:
	return ground[Coords.local_index(local)]


func get_block(local: Vector2i) -> int:
	return blocks[Coords.local_index(local)]


func get_level(local: Vector2i) -> int:
	return levels[Coords.local_index(local)]


func get_shape(local: Vector2i) -> int:
	return shapes[Coords.local_index(local)]


func get_biome(local: Vector2i) -> int:
	return biome[Coords.local_index(local)]


func set_ground(local: Vector2i, id: int) -> void:
	ground[Coords.local_index(local)] = id


func set_block(local: Vector2i, id: int) -> void:
	blocks[Coords.local_index(local)] = id


## True if the tile blocks movement (solid block, solid ground or cliff).
func is_solid(local: Vector2i) -> bool:
	var index := Coords.local_index(local)
	if Tiles.is_block_solid(blocks[index]) or Tiles.is_ground_solid(ground[index]):
		return true
	var shape := shapes[index]
	return shape & SHAPE_EDGE_MASK != 0 and shape & SHAPE_RAMP == 0


func duplicate_chunk() -> ChunkData:
	var copy := ChunkData.new(coord, layer)
	copy.ground = ground.duplicate()
	copy.blocks = blocks.duplicate()
	copy.levels = levels.duplicate()
	copy.shapes = shapes.duplicate()
	copy.biome = biome.duplicate()
	copy.modified = modified
	return copy


func to_dict() -> Dictionary:
	return {
		"v": FORMAT_VERSION,
		"x": coord.x,
		"y": coord.y,
		"layer": layer,
		"ground": ground,
		"blocks": blocks,
		"levels": levels,
		"shapes": shapes,
		"biome": biome,
	}


static func from_dict(data: Dictionary) -> ChunkData:
	var chunk := ChunkData.new(Vector2i(data.get("x", 0), data.get("y", 0)), data.get("layer", 0))
	for field in ["ground", "blocks", "levels", "shapes", "biome"]:
		var array: PackedByteArray = data.get(field, PackedByteArray())
		if array.size() == GameConst.CHUNK_AREA:
			chunk.set(field, array)
	return chunk
