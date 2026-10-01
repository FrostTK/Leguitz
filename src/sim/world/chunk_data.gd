class_name ChunkData
extends RefCounted
## One 16 x 16 column of the world, WORLD_HEIGHT voxels tall (see Voxels).
##
## Voxels are stored column by column: index = (z * 16 + x) * HEIGHT + y,
## y being the row (SEA_LEVEL = level 0). Per column it also keeps the
## biome and the top of its terrain (highest cube or liquid voxel), which
## physics, rendering and spawning read without scanning.

const FORMAT_VERSION := 3
const SIZE := GameConst.CHUNK_SIZE
const HEIGHT := GameConst.WORLD_HEIGHT
## Water surfaces sit this far (levels) below the top of their voxel.
const WATER_DROP := 0.15

var coord := Vector2i.ZERO
var voxels := PackedByteArray()
var biome := PackedByteArray()
## Per column: 1 + row of the highest cube or liquid voxel (0 = none).
var tops := PackedByteArray()
## Set when a player changed the chunk (it must be saved, not regenerated).
var modified := false
## Server side: the chests standing in the chunk, by cell (their own
## Inventory; see WorldState.chest_at), saved with it, never sent.
var chests: Dictionary[Vector3i, Inventory] = {}


func _init(chunk_coord := Vector2i.ZERO) -> void:
	coord = chunk_coord
	# Packed arrays are values: resize each member directly.
	voxels.resize(GameConst.CHUNK_AREA * HEIGHT)
	biome.resize(GameConst.CHUNK_AREA)
	tops.resize(GameConst.CHUNK_AREA)


static func voxel_index(lx: int, y: int, lz: int) -> int:
	return (lz * SIZE + lx) * HEIGHT + y


func get_voxel(local: Vector3i) -> int:
	return voxels[voxel_index(local.x, local.y, local.z)]


func set_voxel(local: Vector3i, voxel: int) -> void:
	voxels[voxel_index(local.x, local.y, local.z)] = voxel
	var column := local.z * SIZE + local.x
	if Voxels.is_cube(voxel) or Voxels.is_liquid(voxel):
		tops[column] = maxi(tops[column], local.y + 1)
	elif local.y + 1 == tops[column]:
		tops[column] = _scan_top(local.x, local.z, local.y)


## Row just above the terrain of a column (0 if the column is empty).
func top_row(local: Vector2i) -> int:
	return tops[local.y * SIZE + local.x]


## Height (levels) of the terrain surface of a column (water: a little
## lower than its voxel).
func surface_height(local: Vector2i) -> float:
	var row := top_row(local)
	var height := float(row - GameConst.SEA_LEVEL)
	if row > 0 and Voxels.is_liquid(voxels[voxel_index(local.x, row - 1, local.y)]):
		height -= WATER_DROP
	return height


## The voxel at the top of a column's terrain (grass, sand, water...).
func surface_voxel(local: Vector2i) -> int:
	var row := top_row(local)
	return voxels[voxel_index(local.x, row - 1, local.y)] if row > 0 else Voxels.AIR


## The voxel standing on a column's terrain (tree, plant...) or air.
func object_on_surface(local: Vector2i) -> int:
	var row := top_row(local)
	return voxels[voxel_index(local.x, row, local.y)] if row < HEIGHT else Voxels.AIR


func get_biome(local: Vector2i) -> int:
	return biome[local.y * SIZE + local.x]


## Recomputes every column top (after filling the voxels directly).
func recompute_tops() -> void:
	var flags := Voxels.flag_table()
	var terrain := Voxels.FLAG_CUBE | Voxels.FLAG_LIQUID
	for column in GameConst.CHUNK_AREA:
		var base := column * HEIGHT
		var top := 0
		for y in range(HEIGHT - 1, -1, -1):
			if flags[voxels[base + y]] & terrain != 0:
				top = y + 1
				break
		tops[column] = top


func duplicate_chunk() -> ChunkData:
	var copy := ChunkData.new(coord)
	copy.voxels = voxels.duplicate()
	copy.biome = biome.duplicate()
	copy.tops = tops.duplicate()
	copy.modified = modified
	return copy


func to_dict() -> Dictionary:
	return {
		"v": FORMAT_VERSION,
		"x": coord.x,
		"y": coord.y,
		"voxels": voxels,
		"biome": biome,
		"tops": tops,
	}


static func from_dict(data: Dictionary) -> ChunkData:
	var chunk := ChunkData.new(Vector2i(data.get("x", 0), data.get("y", 0)))
	var voxels: PackedByteArray = data.get("voxels", PackedByteArray())
	if voxels.size() == chunk.voxels.size():
		chunk.voxels = voxels
	var biome: PackedByteArray = data.get("biome", PackedByteArray())
	if biome.size() == GameConst.CHUNK_AREA:
		chunk.biome = biome
	var tops: PackedByteArray = data.get("tops", PackedByteArray())
	if tops.size() == GameConst.CHUNK_AREA:
		chunk.tops = tops
	else:
		chunk.recompute_tops()
	return chunk


## 1 + the highest cube or liquid row below `below` in a column (0 = none).
func _scan_top(lx: int, lz: int, below: int) -> int:
	var base := (lz * SIZE + lx) * HEIGHT
	for y in range(below - 1, -1, -1):
		var voxel := voxels[base + y]
		if Voxels.is_cube(voxel) or Voxels.is_liquid(voxel):
			return y + 1
	return 0
