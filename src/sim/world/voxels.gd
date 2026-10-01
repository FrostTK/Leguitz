class_name Voxels
extends RefCounted
## Voxel ids stored in chunks (one byte per voxel).
##
## Grounds keep their own ids (Tiles.Ground, below BLOCK_BASE): a voxel of
## grass is a cube whose top shows the grass ground. Blocks follow at
## BLOCK_BASE + Tiles.Block: cubes (stone, ores...) and objects drawn as 3D
## models (trees, plants, rocks...), which stand in their voxel without
## filling it. Ids are stored in saves: only append to the enums.

const AIR := 0
## Block voxels start here; grounds stay below.
const BLOCK_BASE := 64
## Returned for voxels of chunks that are not loaded: solid, so nobody
## walks into unknown terrain.
const UNKNOWN := 255

const FLAG_CUBE := 1
const FLAG_SOLID := 2
const FLAG_LIQUID := 4

static var _flags := _build_flags()


static func of_ground(ground: int) -> int:
	return ground


static func of_block(block: int) -> int:
	return AIR if block == Tiles.Block.AIR else BLOCK_BASE + block


## Ground of a ground voxel (Tiles.Ground.NONE for air and blocks).
static func ground_of(voxel: int) -> int:
	return voxel if voxel < BLOCK_BASE else Tiles.Ground.NONE


## Block of a block voxel (Tiles.Block.AIR for air and grounds).
static func block_of(voxel: int) -> int:
	return voxel - BLOCK_BASE if voxel >= BLOCK_BASE and voxel != UNKNOWN else Tiles.Block.AIR


## A full cube: hides the faces next to it, and bodies stand on it.
static func is_cube(voxel: int) -> bool:
	return _flags[voxel] & FLAG_CUBE != 0


## Bodies cannot move through it (cubes, trees, rocks, lava...).
static func is_solid(voxel: int) -> bool:
	return _flags[voxel] & FLAG_SOLID != 0


static func is_liquid(voxel: int) -> bool:
	return _flags[voxel] & FLAG_LIQUID != 0


## Flags (FLAG_*) of every voxel id, for tight loops: read it once into a
## local variable (calls and shared statics are slow in loops, more so on
## several threads).
static func flag_table() -> PackedByteArray:
	return _flags.duplicate()


## 1 for cube voxels, 0 otherwise, by id (see flag_table).
static func cube_table() -> PackedByteArray:
	var table := PackedByteArray()
	table.resize(256)
	for voxel in 256:
		table[voxel] = 1 if _flags[voxel] & FLAG_CUBE != 0 else 0
	return table


## Something drawn as a 3D model in its voxel (tree, plant, rock...).
static func is_object(voxel: int) -> bool:
	return voxel >= BLOCK_BASE and voxel != UNKNOWN and _flags[voxel] & FLAG_CUBE == 0


static func _build_flags() -> PackedByteArray:
	var flags := PackedByteArray()
	flags.resize(256)
	for ground: int in Tiles.Ground.values():
		if ground == Tiles.Ground.NONE:
			continue
		if Tiles.is_water(ground):
			flags[ground] = FLAG_LIQUID
		elif ground == Tiles.Ground.LAVA:
			flags[ground] = FLAG_LIQUID | FLAG_SOLID
		else:
			flags[ground] = FLAG_CUBE | FLAG_SOLID
	for block: int in Tiles.Block.values():
		if block == Tiles.Block.AIR:
			continue
		var voxel := of_block(block)
		if Tiles.is_cube(block):
			flags[voxel] = FLAG_CUBE | FLAG_SOLID
		elif Tiles.is_block_solid(block):
			flags[voxel] = FLAG_SOLID
	flags[UNKNOWN] = FLAG_CUBE | FLAG_SOLID
	return flags
