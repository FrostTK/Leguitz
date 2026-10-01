class_name ChunkData
extends RefCounted
## Raw content of a 16x16 chunk of one layer (0 = surface, < 0 underground).
##
## Per tile: ground id, block id, terrace level (surface height step),
## shape flags (cliff edges) and biome id.
##
## Heights are in levels: a tile's ground is at its level (water a little
## lower), a cube block adds one level. Players climb one level by jumping.

const FORMAT_VERSION := 2

## Shape flags: which 4-neighbors are on a lower terrace level (a cliff
## edge). Flag 16 is free (it marked generated ramps, now gone).
const SHAPE_LOWER_N := 1
const SHAPE_LOWER_E := 2
const SHAPE_LOWER_S := 4
const SHAPE_LOWER_W := 8
const SHAPE_EDGE_MASK := 15
## The tile right under a south-facing cliff face (drawn in its shadow).
const SHAPE_SHADOW := 32
## Water surfaces sit this far (levels) below the ground of their level.
const WATER_DROP := 0.15
## Height of a cube block (levels).
const CUBE_HEIGHT := 1.0

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


## True if something stands on the tile's ground (solid block or ground):
## nobody can stand there at ground level.
func is_solid(local: Vector2i) -> bool:
	var index := Coords.local_index(local)
	return Tiles.is_block_solid(blocks[index]) or Tiles.is_ground_solid(ground[index])


## Height (levels) of the ground surface of a tile.
func ground_height(local: Vector2i) -> float:
	var index := Coords.local_index(local)
	var height := float(levels[index])
	if Tiles.is_water(ground[index]):
		height -= WATER_DROP
	return height


## Height (levels) a body stands at on a tile: its ground, or the top of a
## cube block. INF where nobody can stand: obstacles (trees, boulders...),
## lava, and underground the rock mass (cube blocks fill the layer there).
func top_height(local: Vector2i) -> float:
	var index := Coords.local_index(local)
	var block := blocks[index]
	if Tiles.is_ground_solid(ground[index]):
		return INF
	if Tiles.is_cube(block):
		return INF if layer < WorldGenerator.SURFACE_LAYER else ground_height(local) + CUBE_HEIGHT
	if Tiles.is_block_solid(block):
		return INF
	return ground_height(local)


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
