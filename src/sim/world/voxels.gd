class_name Voxels
extends RefCounted
## Voxel ids stored in chunks (16 bits: ID_COUNT of them; one int per
## voxel in ChunkData.voxels).
##
## Grounds keep their own ids (Tiles.Ground, below BLOCK_BASE): a voxel of
## grass is a cube whose top shows the grass ground. Blocks follow at
## BLOCK_BASE + Tiles.Block: cubes (stone, ores...) and objects drawn as 3D
## models (trees, plants, rocks...), which stand in their voxel without
## filling it, up to UNKNOWN. Ids are stored in saves: only append to the
## enums.

const AIR := 0
## Block voxels start here; grounds stay below (the shaders read a ground
## in 6 bits).
const BLOCK_BASE := 64
## Every voxel id is below this: tables by voxel id are this long.
const ID_COUNT := 65536
## Returned for voxels of chunks that are not loaded: solid, so nobody
## walks into unknown terrain. Never stored in a chunk.
const UNKNOWN := ID_COUNT - 1

const FLAG_CUBE := 1
const FLAG_SOLID := 2
const FLAG_LIQUID := 4
## Stairs and slabs (ShapedBlocks): solid in part of their cell. (8 and 16
## are ChunkMesher's.)
const FLAG_SHAPED := 32

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


## Stairs or a slab (ShapedBlocks).
static func is_shaped(voxel: int) -> bool:
	return _flags[voxel] & FLAG_SHAPED != 0


## Water, still or flowing.
static func is_water(voxel: int) -> bool:
	return voxel < BLOCK_BASE and Tiles.is_water(voxel)


## Lava, still or flowing.
static func is_lava(voxel: int) -> bool:
	return voxel < BLOCK_BASE and Tiles.is_lava(voxel)


## Flags (FLAG_*) of every voxel id, for tight loops: read it once into a
## local variable (calls and shared statics are slow in loops, more so on
## several threads).
static func flag_table() -> PackedByteArray:
	return _flags.duplicate()


## 1 for cube voxels, 0 otherwise, by id (see flag_table).
static func cube_table() -> PackedByteArray:
	var table := PackedByteArray()
	table.resize(ID_COUNT)
	for voxel in used_ids():
		table[voxel] = 1 if _flags[voxel] & FLAG_CUBE != 0 else 0
	table[UNKNOWN] = 1
	return table


## How many ids the grounds and blocks there are use (0 to this, less
## one): tables that never meet UNKNOWN (the voxels of loaded chunks) need
## no more.
static func used_ids() -> int:
	return BLOCK_BASE + Tiles.Block.size()


## Something drawn as a 3D model in its voxel (tree, plant, rock...).
static func is_object(voxel: int) -> bool:
	return voxel >= BLOCK_BASE and voxel != UNKNOWN and _flags[voxel] & FLAG_CUBE == 0


static func _build_flags() -> PackedByteArray:
	var flags := PackedByteArray()
	flags.resize(ID_COUNT)
	for ground: int in Tiles.Ground.values():
		if ground == Tiles.Ground.NONE:
			continue
		if Tiles.is_water(ground):
			flags[ground] = FLAG_LIQUID
		elif Tiles.is_lava(ground):
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
			if Tiles.is_shaped(block):
				flags[voxel] |= FLAG_SHAPED
	flags[UNKNOWN] = FLAG_CUBE | FLAG_SOLID
	return flags
