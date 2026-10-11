class_name Furniture
extends RefCounted
## The bedroom's and the living room's furniture (phase 8, step 7; static
## tables and rules, shared; models: FurnitureModels). What stores things
## (STORAGES: the chest, a wardrobe, a dresser, a bookcase, a chest of
## drawers, a wall cupboard, a crate, a basket) opens as a chest
## (ObjectShapes.is_chest, Chests). The tall ones (TALL) stand two levels in
## two cells, the second a FURNITURE_TOP (no model, never aimed at nor
## broken itself: its furniture below is). A bed lies in two cells, its foot
## where it is placed and its head behind (`head_of`, `cells`); one sleeps
## in it (Beds). Seats (SEATS) are sat on (FurnitureUse), at their height;
## a shelf on a wall shows what is put on it (Shelves). A tablecloth goes on
## a table (TABLE_CLOTHED); beds, armchairs, sofas and tablecloths take a
## tint (Tints.dyed).

## What stores things, by kind.
const STORAGES := {
	Tiles.Block.CHEST: true,
	Tiles.Block.WARDROBE: true,
	Tiles.Block.DRESSER: true,
	Tiles.Block.BOOKCASE: true,
	Tiles.Block.COMMODE: true,
	Tiles.Block.WALL_CUPBOARD: true,
	Tiles.Block.CRATE: true,
	Tiles.Block.BASKET: true,
}
## Two levels tall (their second cell a FURNITURE_TOP), by kind.
const TALL := {
	Tiles.Block.WARDROBE: true,
	Tiles.Block.DRESSER: true,
	Tiles.Block.BOOKCASE: true,
}
## Seats, by kind: how high one sits (levels over the floor).
const SEATS := {
	Tiles.Block.CHAIR: 0.5,
	Tiles.Block.ARMCHAIR: 0.42,
	Tiles.Block.SOFA: 0.42,
	Tiles.Block.BENCH: 0.45,
	Tiles.Block.STOOL: 0.55,
	Tiles.Block.ROCKING_CHAIR: 0.45,
}
## The facing kinds (ObjectShapes builds them by name).
const FACING := [
	Tiles.Block.BED,
	Tiles.Block.BED_HEAD,
	Tiles.Block.WARDROBE,
	Tiles.Block.DRESSER,
	Tiles.Block.BOOKCASE,
	Tiles.Block.COMMODE,
	Tiles.Block.WALL_CUPBOARD,
	Tiles.Block.SHELF,
	Tiles.Block.ARMCHAIR,
	Tiles.Block.SOFA,
	Tiles.Block.BENCH,
	Tiles.Block.ROCKING_CHAIR,
	Tiles.Block.DESK,
	Tiles.Block.NIGHTSTAND,
]
## Cloth that takes a tint (Tints.dyed), by kind.
const DYED := {
	Tiles.Block.BED: true,
	Tiles.Block.BED_HEAD: true,
	Tiles.Block.ARMCHAIR: true,
	Tiles.Block.SOFA: true,
	Tiles.Block.TABLE_CLOTHED: true,
}


static func is_storage(block: int) -> bool:
	return STORAGES.has(ObjectShapes.base_kind(block))


static func is_tall(block: int) -> bool:
	return TALL.has(ObjectShapes.base_kind(block))


## The top of a tall piece of furniture (no model: the one below).
static func is_top(block: int) -> bool:
	return block == Tiles.Block.FURNITURE_TOP


## A bed's foot or head.
static func is_bed(block: int) -> bool:
	return ObjectShapes.kind_of(block) in [Tiles.Block.BED, Tiles.Block.BED_HEAD]


static func is_seat(block: int) -> bool:
	return SEATS.has(ObjectShapes.base_kind(block))


static func is_shelf(block: int) -> bool:
	return ObjectShapes.kind_of(block) == Tiles.Block.SHELF


## How high one sits on a seat (levels over its floor).
static func seat_height(block: int) -> float:
	return SEATS.get(ObjectShapes.base_kind(block), 0.5)


## The head a bed's foot (facing the player who placed it) has behind it.
static func head_of(foot: int) -> int:
	return ObjectShapes.facing(Tiles.Block.BED_HEAD, ObjectShapes.front_of(foot))


## The cell of a bed's foot, from its foot's or its head's.
static func foot_cell(cell: Vector3i, block: int) -> Vector3i:
	if ObjectShapes.kind_of(block) == Tiles.Block.BED_HEAD:
		var front := ObjectShapes.front_of(block)
		return cell + Vector3i(front.x, 0, front.y)
	return cell


## The cells of a bed or of tall furniture aimed at in `cell` (its model's
## cell first); empty: neither.
static func cells(cell: Vector3i, block: int, voxel_at: Callable) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	if is_top(block):
		if is_tall(Voxels.block_of(voxel_at.call(cell + Vector3i.DOWN))):
			result.append(cell + Vector3i.DOWN)
		result.append(cell)
	elif is_tall(block):
		result.append(cell)
		if is_top(Voxels.block_of(voxel_at.call(cell + Vector3i.UP))):
			result.append(cell + Vector3i.UP)
	elif is_bed(block):
		var foot := foot_cell(cell, block)
		var front := ObjectShapes.front_of(block)
		var head := foot - Vector3i(front.x, 0, front.y)
		var other: Vector3i = head if foot == cell else foot
		if is_bed(Voxels.block_of(voxel_at.call(other))):
			result.append_array([foot, head])
		else:
			result.append(cell)
	return result
