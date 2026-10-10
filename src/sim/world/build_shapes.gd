class_name BuildShapes
extends RefCounted
## Walls, pillars and beams (phase 8, step 6; static tables and rules,
## shared). A wall (a low stone wall, a parapet) joins its neighbors as a
## fence does (ObjectShapes.JOINING: cubes, walls, gates, pillars), keeps
## bodies out (a barrier) and stacks on a wall. A pillar (a stone column, a
## brick pillar, a wooden post) stacks on a pillar of its kind: its base
## shows at the foot of the stack, its capital at its head (`pillar_bits`).
## A beam, square timber, lies along the axis of the side aimed at
## (`beam_for`: up a post, along x or z), needs nothing under it and stands
## as a block (furniture stood on). Models: BuildModels.

## Each wall and the cube it is made of.
const WALLS := {
	Tiles.Block.COBBLESTONE_WALL: Tiles.Block.COBBLESTONE,
	Tiles.Block.STONE_BRICK_WALL: Tiles.Block.STONE_BRICKS,
	Tiles.Block.BRICK_WALL: Tiles.Block.BRICKS,
	Tiles.Block.MOSSY_STONE_WALL: Tiles.Block.MOSSY_STONE,
	Tiles.Block.SANDSTONE_WALL: Tiles.Block.SANDSTONE_BRICKS,
}
## Each pillar and the cube it is made of.
const PILLARS := {
	Tiles.Block.STONE_COLUMN: Tiles.Block.SMOOTH_STONE,
	Tiles.Block.BRICK_PILLAR: Tiles.Block.BRICKS,
	Tiles.Block.WOOD_POST: Tiles.Block.OAK_PLANKS,
}
## Each beam (standing up) and its blocks along x and z, its wood.
const BEAMS := {
	Tiles.Block.OAK_BEAM: [Tiles.Block.OAK_BEAM_X, Tiles.Block.OAK_BEAM_Z, "OAK"],
	Tiles.Block.SPRUCE_BEAM: [Tiles.Block.SPRUCE_BEAM_X, Tiles.Block.SPRUCE_BEAM_Z, "SPRUCE"],
	Tiles.Block.DARK_OAK_BEAM:
	[Tiles.Block.DARK_OAK_BEAM_X, Tiles.Block.DARK_OAK_BEAM_Z, "DARK_OAK"],
}
## A pillar's version: its capital (nothing of it over it), its base
## (nothing of it under it).
const CAPITAL := 1
const BASE := 2
const PILLAR_VARIANTS := 4

## A beam lying along x or z -> [its standing kind, its axis].
static var _lying := _build_lying()


static func is_wall(block: int) -> bool:
	return WALLS.has(block)


static func is_pillar(block: int) -> bool:
	return PILLARS.has(block)


## A beam, any way it lies.
static func is_beam(block: int) -> bool:
	return BEAMS.has(block) or _lying.has(block)


## A beam's standing kind (its item's).
static func beam_kind(block: int) -> int:
	return _lying[block][0] if _lying.has(block) else block


## The axis a beam lies along (UP: standing).
static func beam_axis(block: int) -> Vector3i:
	return _lying[block][1] if _lying.has(block) else Vector3i.UP


## The beam of `kind` lying along the axis of the side aimed at (`face`).
static func beam_for(kind: int, face: Vector3i) -> int:
	if face.x != 0:
		return BEAMS[kind][0]
	if face.z != 0:
		return BEAMS[kind][1]
	return kind


## Whether a wall joins a neighbor voxel: cubes, walls, gates, pillars.
static func wall_joins(voxel: int) -> bool:
	if Voxels.is_cube(voxel):
		return true
	var block := Voxels.block_of(voxel)
	return is_wall(block) or is_pillar(block) or ObjectShapes.is_gate(block)


## A pillar's version from the voxels over and under it.
static func pillar_bits(voxel: int, over: int, under: int) -> int:
	return (CAPITAL if over != voxel else 0) | (BASE if under != voxel else 0)


## What a wall, a pillar or a beam is made of (its cube; AIR: none).
static func material_of(block: int) -> int:
	if is_beam(block):
		return Tiles.Block[BEAMS[beam_kind(block)][2] + "_PLANKS"]
	return WALLS.get(block, PILLARS.get(block, Tiles.Block.AIR))


static func _build_lying() -> Dictionary:
	var lying := {}
	for kind: int in BEAMS:
		lying[BEAMS[kind][0]] = [kind, Vector3i(1, 0, 0)]
		lying[BEAMS[kind][1]] = [kind, Vector3i(0, 0, 1)]
	return lying
