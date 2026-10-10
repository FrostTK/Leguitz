class_name ShapedBlocks
extends RefCounted
## Stairs and slabs: blocks filling part of their cell, in the material of
## a cube (MATERIALS: the planks, stones, bricks and sandstones). A shape
## is a set of the cell's eight octants (`mask`: bit x + 2 z + 4 y, the
## halves of the cell along x east, z south, y up), shared by physics
## (PlayerBody: what bodies bump into and stand on; half a level is walked
## up), aiming (VoxelRay) and the meshes (ChunkMesher: the octants' open
## faces in the material's textures). Stairs face the player placing them
## (ObjectShapes facing kinds: the low step in front, the high part at the
## back), upside down (STAIRS_TOP) placed under a ceiling or aimed at the
## upper half of a side; stairs side by side turn their corners as in
## Minecraft (`mask` looks at the neighbors: inner and outer corners). A
## slab fills the low or the high half of its cell (SLAB, SLAB_TOP), a side
## slab its back half (SIDE_SLAB: against a wall, facing away from it);
## two halves of one material make its cube. Each material gives stairs, a
## slab and a side slab (items, recipes: Recipes).

enum Shape { STAIRS, STAIRS_TOP, SLAB, SLAB_TOP, SIDE_SLAB }

## [block name prefix, the cube block, its item] of each material.
const MATERIALS := [
	["OAK", Tiles.Block.OAK_PLANKS, Items.Id.OAK_PLANKS],
	["BIRCH", Tiles.Block.BIRCH_PLANKS, Items.Id.BIRCH_PLANKS],
	["SPRUCE", Tiles.Block.SPRUCE_PLANKS, Items.Id.SPRUCE_PLANKS],
	["DARK_OAK", Tiles.Block.DARK_OAK_PLANKS, Items.Id.DARK_OAK_PLANKS],
	["JUNGLE", Tiles.Block.JUNGLE_PLANKS, Items.Id.JUNGLE_PLANKS],
	["ACACIA", Tiles.Block.ACACIA_PLANKS, Items.Id.ACACIA_PLANKS],
	["STONE", Tiles.Block.STONE, Items.Id.STONE],
	["SMOOTH_STONE", Tiles.Block.SMOOTH_STONE, Items.Id.SMOOTH_STONE],
	["STONE_BRICK", Tiles.Block.STONE_BRICKS, Items.Id.STONE_BRICKS],
	["BRICK", Tiles.Block.BRICKS, Items.Id.BRICKS],
	["DEEPSLATE_BRICK", Tiles.Block.DEEPSLATE_BRICKS, Items.Id.DEEPSLATE_BRICKS],
	["SANDSTONE", Tiles.Block.SANDSTONE, Items.Id.SANDSTONE],
	["CUT_SANDSTONE", Tiles.Block.CUT_SANDSTONE, Items.Id.CUT_SANDSTONE],
]
## The ways a block faces (ObjectShapes.WAYS: south, west, north, east;
## kept here, ObjectShapes' tables are built from this class's).
const WAYS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0)]
## The octants of the low and the high half, and of the whole cell.
const LOW := 0x0F
const HIGH := 0xF0
const ALL := 0xFF
## Each shape's blocks (name suffixes): facing ones in ObjectShapes.WAYS
## order (south, west, north, east).
const STAIRS := ["STAIRS", "STAIRS_WEST", "STAIRS_NORTH", "STAIRS_EAST"]
const STAIRS_TOP := ["STAIRS_TOP", "STAIRS_TOP_WEST", "STAIRS_TOP_NORTH", "STAIRS_TOP_EAST"]
const SIDE_SLABS := ["SIDE_SLAB", "SIDE_SLAB_WEST", "SIDE_SLAB_NORTH", "SIDE_SLAB_EAST"]
## The items' shapes (by name suffix).
const ITEMS := {"STAIRS": Shape.STAIRS, "SLAB": Shape.SLAB, "SIDE_SLAB": Shape.SIDE_SLAB}

## block -> its shape, its material's cube, its item, which way it faces;
## item -> [the block it places, its material's item, its shape]; facing
## kind -> its blocks (ObjectShapes takes them).
static var _shapes: Dictionary[int, int] = {}
static var _materials: Dictionary[int, int] = {}
static var _items: Dictionary[int, int] = {}
static var _fronts: Dictionary[int, Vector2i] = {}
static var _placing: Dictionary[int, Array] = {}
static var _prefixes: Dictionary[int, String] = {}
static var _facings: Dictionary[int, Array] = {}
static var _built := _build()


static func is_shaped(block: int) -> bool:
	return Tiles.is_shaped(block)


## A shaped block's Shape (-1: none).
static func shape_of(block: int) -> int:
	return _shapes.get(block, -1)


## The cube a shaped block is made of.
static func material_of(block: int) -> int:
	return _materials.get(block, Tiles.Block.AIR)


## The item a shaped block gives back.
static func item_of(block: int) -> int:
	return _items.get(block, Items.Id.NONE)


## The block an item of stairs or slabs places (AIR: none).
static func placed_by(item: int) -> int:
	return _placing[item][0] if _placing.has(item) else Tiles.Block.AIR


## An item's shape (Shape.STAIRS, SLAB or SIDE_SLAB; -1: none).
static func item_shape(item: int) -> int:
	return _placing[item][2] if _placing.has(item) else -1


## The items of stairs and slabs: [item, its material's item, its shape].
static func items() -> Array:
	return _placing.keys().map(func(item: int) -> Array: return [item] + _placing[item].slice(1))


## The facing kinds (their first block -> their blocks, south, west,
## north, east), for ObjectShapes.
static func facing_kinds() -> Dictionary[int, Array]:
	return _facings


## Which way a shaped block faces (ZERO: a slab).
static func front_of(block: int) -> Vector2i:
	return _fronts.get(block, Vector2i.ZERO)


## The octants a shaped block fills in `cell`; stairs turn their corners
## after the stairs around (`voxel_at`: Callable(cell) -> int; an invalid
## one: straight).
static func mask(block: int, cell: Vector3i, voxel_at: Callable) -> int:
	match shape_of(block):
		Shape.SLAB:
			return LOW
		Shape.SLAB_TOP:
			return HIGH
		Shape.SIDE_SLAB:
			return side(-front_of(block))
		Shape.STAIRS, Shape.STAIRS_TOP:
			return _stairs(block, cell, voxel_at)
	return 0


## The octants on one side of the cell (a unit step on the ground).
static func side(way: Vector2i) -> int:
	if way.x > 0:
		return 0xAA
	if way.x < 0:
		return 0x55
	return 0xCC if way.y > 0 else 0x33


## The boxes (local units: tiles across, levels up) of the octants of
## `filled` in `cell`, the halves joined where they can.
static func boxes(filled: int, cell: Vector3i) -> Array[AABB]:
	var result: Array[AABB] = []
	var corner := Vector3(cell.x, cell.y - GameConst.SEA_LEVEL, cell.z)
	for y in 2:
		for z in 2:
			var row := 3 << (z * 2 + y * 4)
			if filled & row == row:
				result.append(AABB(corner + Vector3(0.0, y, z) * 0.5, Vector3(1.0, 0.5, 0.5)))
				continue
			for x in 2:
				if filled & (1 << (x + z * 2 + y * 4)):
					result.append(AABB(corner + Vector3(x, y, z) * 0.5, Vector3.ONE * 0.5))
	return result


## The box around a shaped block (local units; stairs: the whole cell).
static func bounds(block: int, cell: Vector3i) -> AABB:
	var box := AABB()
	var first := true
	for part in boxes(mask(block, cell, Callable()), cell):
		box = part if first else box.merge(part)
		first = false
	return box


## How high (levels, over its cell's floor) a shaped block's top is.
static func top_of(block: int) -> float:
	return 0.5 if shape_of(block) == Shape.SLAB else 1.0


## Where an item of stairs or slabs placed in `cell` goes ({} : nowhere):
## `front` towards the player, `face` the side of what was aimed at,
## `upper` aimed at the upper half of a side (or Shift). Stairs upside down
## under a ceiling or aimed high; a slab high so too; a side slab against
## the side aimed at (on a floor: facing the player). Its other half
## already there (the same material): the whole cube.
static func placement(
	cell: Vector3i, block: int, front: Vector2i, face: Vector3i, upper: bool, voxel_at: Callable
) -> Dictionary:
	var there: int = voxel_at.call(cell)
	var other := Voxels.block_of(there)
	var material := material_of(block)
	var high := face == Vector3i.DOWN or upper
	var placed := block
	match shape_of(block):
		Shape.STAIRS:
			var kind := _named(block, "STAIRS_TOP" if high else "STAIRS")
			placed = _facings[kind][maxi(WAYS.find(front), 0)]
		Shape.SLAB:
			var slab := shape_of(other) in [Shape.SLAB, Shape.SLAB_TOP]
			if slab and material_of(other) == material:
				return {cell: Voxels.of_block(material)}
			placed = _named(block, "SLAB_TOP") if high else block
		Shape.SIDE_SLAB:
			var facing := Vector2i(face.x, face.z) if face.y == 0 else front
			if shape_of(other) == Shape.SIDE_SLAB and material_of(other) == material:
				if front_of(other) != facing:
					return {cell: Voxels.of_block(material)}
				return {}
			placed = _facings[block][maxi(WAYS.find(facing), 0)]
	if not Mining.is_replaceable(there):
		return {}
	return {cell: Voxels.of_block(placed)}


## Whether placing `item` aimed at `voxel` (its side `normal`) fills the
## other half of that very cell (a slab on a slab of its material).
static func completes(voxel: int, normal: Vector3i, item: int) -> bool:
	var block := Voxels.block_of(voxel)
	var placing := placed_by(item)
	if placing == Tiles.Block.AIR or material_of(block) != material_of(placing):
		return false
	match shape_of(block):
		Shape.SLAB:
			return item_shape(item) == Shape.SLAB and normal == Vector3i.UP
		Shape.SLAB_TOP:
			return item_shape(item) == Shape.SLAB and normal == Vector3i.DOWN
		Shape.SIDE_SLAB:
			var front := front_of(block)
			return item_shape(item) == Shape.SIDE_SLAB and normal == Vector3i(front.x, 0, front.y)
	return false


## Stairs: their base half, and the half of the other layer at their back;
## an outer corner keeps a quarter of it, an inner one adds a quarter.
static func _stairs(block: int, cell: Vector3i, voxel_at: Callable) -> int:
	var top := shape_of(block) == Shape.STAIRS_TOP
	var layer := LOW if top else HIGH
	var back := -front_of(block)
	var part := side(back) & layer
	if voxel_at.is_valid():
		var ahead := _stair_back(voxel_at.call(cell + _step(back)), top)
		var behind := _stair_back(voxel_at.call(cell - _step(back)), top)
		if _across(ahead, back) and not _same(voxel_at.call(cell - _step(ahead)), back, top):
			part = side(back) & side(ahead) & layer
		elif _across(behind, back) and not _same(voxel_at.call(cell + _step(behind)), back, top):
			part = (side(back) | (side(-back) & side(behind))) & layer
	return (HIGH if top else LOW) | part


## The back of the stairs in a voxel, upside down or not as `top` (ZERO:
## not such stairs).
static func _stair_back(voxel: int, top: bool) -> Vector2i:
	var shape := shape_of(Voxels.block_of(voxel))
	if shape != (Shape.STAIRS_TOP if top else Shape.STAIRS):
		return Vector2i.ZERO
	return -front_of(Voxels.block_of(voxel))


static func _across(way: Vector2i, back: Vector2i) -> bool:
	return way != Vector2i.ZERO and way.x * back.x + way.y * back.y == 0


static func _same(voxel: int, back: Vector2i, top: bool) -> bool:
	return _stair_back(voxel, top) == back


static func _step(way: Vector2i) -> Vector3i:
	return Vector3i(way.x, 0, way.y)


## The block of the same material as `block` named with `suffix`.
static func _named(block: int, suffix: String) -> int:
	return Tiles.Block[_prefixes[block] + "_" + suffix]


static func _build() -> bool:
	for material: Array in MATERIALS:
		var prefix: String = material[0]
		var groups := [
			[STAIRS, Shape.STAIRS, "STAIRS"],
			[STAIRS_TOP, Shape.STAIRS_TOP, "STAIRS"],
			[["SLAB"], Shape.SLAB, "SLAB"],
			[["SLAB_TOP"], Shape.SLAB_TOP, "SLAB"],
			[SIDE_SLABS, Shape.SIDE_SLAB, "SIDE_SLAB"],
		]
		for group: Array in groups:
			var blocks: Array[int] = []
			var item: int = Items.Id[prefix + "_" + group[2]]
			for way in group[0].size():
				var block: int = Tiles.Block[prefix + "_" + group[0][way]]
				blocks.append(block)
				_shapes[block] = group[1]
				_materials[block] = material[1]
				_items[block] = item
				_prefixes[block] = prefix
				if group[0].size() > 1:
					_fronts[block] = WAYS[way]
			if blocks.size() > 1:
				_facings[blocks[0]] = blocks
		for suffix: String in ITEMS:
			var item: int = Items.Id[prefix + "_" + suffix]
			_placing[item] = [Tiles.Block[prefix + "_" + suffix], material[2], ITEMS[suffix]]
	return true
