class_name Openings
extends RefCounted
## Doors, trapdoors, ladders, bars and railings (phase 8, step 4; static
## tables and rules, shared).
##
## A door stands two levels tall in two cells: its own (a facing kind of
## DOORS, which holds the model) and the cell over it, its top (TOPS: no
## model; shut it keeps the daylight out, LightField.SHUT_BLOCKS, but for
## a glazed door's). It opens and shuts as a gate (ObjectShapes.OPENS;
## Mining.swings): its top follows (`top_of`). Shut, it keeps bodies out
## of its whole tile up two levels (a barrier); open, they walk through.
## Doors side by side facing the same way make a double door: the one
## with a door on its left hangs on its right (`hinge_right`), and using
## either opens both (`partner`). A trapdoor hangs on the side of a cube
## (wall-mounted) at the top of its cell: shut, one walks on it; open, it
## stands against that cube and one climbs through. A ladder hangs on a
## wall: bodies in its cell climb it (PlayerBody). Bars and railings join
## their neighbors as fences do (`joins`).

## Each door (its shut kind) and the top it puts over itself.
const DOORS := {
	Tiles.Block.OAK_DOOR: Tiles.Block.DOOR_TOP,
	Tiles.Block.BIRCH_DOOR: Tiles.Block.DOOR_TOP,
	Tiles.Block.SPRUCE_DOOR: Tiles.Block.DOOR_TOP,
	Tiles.Block.DARK_OAK_DOOR: Tiles.Block.DOOR_TOP,
	Tiles.Block.JUNGLE_DOOR: Tiles.Block.DOOR_TOP,
	Tiles.Block.ACACIA_DOOR: Tiles.Block.DOOR_TOP,
	Tiles.Block.GLAZED_DOOR: Tiles.Block.DOOR_TOP_GLAZED,
	Tiles.Block.IRON_DOOR: Tiles.Block.DOOR_TOP,
}
const TOPS := {
	Tiles.Block.DOOR_TOP: true,
	Tiles.Block.DOOR_TOP_GLAZED: true,
	Tiles.Block.DOOR_TOP_OPEN: true,
}
## The trapdoors (their shut kind).
const TRAPDOORS := {Tiles.Block.OAK_TRAPDOOR: true, Tiles.Block.IRON_TRAPDOOR: true}
const RAILINGS := {Tiles.Block.WOOD_RAILING: true, Tiles.Block.IRON_RAILING: true}
## How thick a door or a trapdoor is (tiles).
const THICKNESS := 3.0 / 16.0


## A door's bottom, shut or open, any way it faces.
static func is_door(block: int) -> bool:
	return DOORS.has(ObjectShapes.pair_of(ObjectShapes.base_kind(block)))


## The top of a door (it has no model, its door below does).
static func is_top(block: int) -> bool:
	return TOPS.has(block)


static func is_trapdoor(block: int) -> bool:
	return TRAPDOORS.has(ObjectShapes.pair_of(ObjectShapes.base_kind(block)))


static func is_ladder(block: int) -> bool:
	return ObjectShapes.kind_of(block) == Tiles.Block.LADDER


## The top a door puts over itself, shut or open.
static func top_of(door: int) -> int:
	if ObjectShapes.is_open(door):
		return Tiles.Block.DOOR_TOP_OPEN
	return DOORS.get(ObjectShapes.pair_of(ObjectShapes.base_kind(door)), Tiles.Block.DOOR_TOP)


## Which way is a facing object's left (seen from its front; its model's
## -x), on the ground.
static func left_of(block: int) -> Vector2i:
	var front := ObjectShapes.front_of(block)
	return Vector2i(-front.y, front.x)


## Whether the door in `cell` hangs on its right: a door facing the same
## way stands on its left (they make a double door).
static func hinge_right(block: int, cell: Vector3i, voxel_at: Callable) -> bool:
	var left := left_of(block)
	return _same_way(block, voxel_at.call(cell + Vector3i(left.x, 0, left.y)))


## The cell of the other half of a double door (Vector3i.MAX: none).
static func partner(block: int, cell: Vector3i, voxel_at: Callable) -> Vector3i:
	var left := left_of(block)
	var side := Vector3i(left.x, 0, left.y)
	if hinge_right(block, cell, voxel_at):
		return cell + side
	if _same_way(block, voxel_at.call(cell - side)):
		return cell - side
	return Vector3i.MAX


## Whether bars or a railing (`block`) join a neighbor voxel: cubes, the
## same; bars also panes, railings any railing.
static func joins(block: int, voxel: int) -> bool:
	if Voxels.is_cube(voxel):
		return true
	var other := Voxels.block_of(voxel)
	if block == Tiles.Block.IRON_BARS:
		return other == block or Glass.is_pane(other)
	return RAILINGS.has(other)


## The body (local units) of a door or a trapdoor in `cell`, for aiming:
## a shut door a board at its front, two levels tall; an open one its
## whole tile; a shut trapdoor a board at the top of its cell, an open one
## a board against its cube (at its back).
static func box_of(block: int, cell: Vector3i) -> AABB:
	var low := Vector3(cell.x, cell.y - GameConst.SEA_LEVEL, cell.z)
	if is_door(block) and ObjectShapes.is_open(block):
		return AABB(low, Vector3(1.0, 2.0, 1.0))
	if is_trapdoor(block) and not ObjectShapes.is_open(block):
		return AABB(low + Vector3(0.0, 1.0 - THICKNESS, 0.0), Vector3(1.0, THICKNESS, 1.0))
	# A board at a door's front, at an open trapdoor's back.
	var back := -ObjectShapes.front_of(block)
	if is_door(block):
		back = -back
	var size := Vector3(1.0, 2.0 if is_door(block) else 1.0, 1.0)
	if back.x != 0:
		size.x = THICKNESS
		low.x += 1.0 - THICKNESS if back.x > 0 else 0.0
	else:
		size.z = THICKNESS
		low.z += 1.0 - THICKNESS if back.y > 0 else 0.0
	return AABB(low, size)


static func _same_way(block: int, voxel: int) -> bool:
	var other := Voxels.block_of(voxel)
	return is_door(other) and ObjectShapes.front_of(other) == ObjectShapes.front_of(block)
