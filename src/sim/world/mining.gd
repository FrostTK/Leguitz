class_name Mining
extends RefCounted
## What players can break and place, how far they reach and how long
## breaking takes: by hand, or faster with the tool made for it (a pickaxe
## for stone, ores and ice, a shovel for soils, sands and snow, an axe for
## trees). Shared by the client (progress, cracks, prediction) and the
## server (which checks reach and what is really there).

## How far a player reaches from the eye (local units: tiles across,
## levels up), and the eye's height above the feet.
const REACH := 5.0
const EYE_HEIGHT := 1.35
## The bottom row of the world cannot be broken.
const LOWEST_ROW := 1
## Seconds to break by hand: soil (dirt, grasses...), small plants, and
## what else differs.
const SOIL_SECONDS := 0.8
const PLANT_SECONDS := 0.05
const OTHER_SECONDS := 1.5
const GROUND_SECONDS := {
	Tiles.Ground.SAND: 0.7,
	Tiles.Ground.RED_SAND: 0.7,
	Tiles.Ground.SNOW: 0.5,
	Tiles.Ground.GRAVEL: 0.9,
	Tiles.Ground.ICE: 1.2,
	Tiles.Ground.TERRACOTTA: 2.5,
	Tiles.Ground.TERRACOTTA_LIGHT: 2.5,
	Tiles.Ground.STONE_FLOOR: 3.5,
	Tiles.Ground.DEEPSLATE_FLOOR: 5.0,
}
const BLOCK_SECONDS := {
	Tiles.Block.STONE: 3.5,
	Tiles.Block.DEEPSLATE: 5.0,
	Tiles.Block.COAL_ORE: 4.0,
	Tiles.Block.COPPER_ORE: 4.0,
	Tiles.Block.IRON_ORE: 4.5,
	Tiles.Block.GOLD_ORE: 4.5,
	Tiles.Block.LAPIS_ORE: 4.5,
	Tiles.Block.RUBY_ORE: 5.0,
	Tiles.Block.DIAMOND_ORE: 5.0,
	Tiles.Block.EMERALD_ORE: 5.0,
	Tiles.Block.SANDSTONE: 2.5,
	Tiles.Block.PACKED_ICE: 2.0,
	Tiles.Block.ROCK: 3.0,
	Tiles.Block.MOSSY_ROCK: 3.0,
	Tiles.Block.CACTUS: 0.8,
	Tiles.Block.BIG_MUSHROOM: 1.2,
	Tiles.Block.BUSH: 0.4,
	Tiles.Block.BERRY_BUSH: 0.4,
	Tiles.Block.SUGAR_CANE: 0.2,
}
## Trees by hand: chopping a trunk takes a while.
const TREE_SECONDS := 3.5
## After a break, the next one waits this long (Minecraft's quarter of a
## second) unless the block went at once (small plants).
const BREAK_PAUSE := 0.25
const INSTANT_SECONDS := 0.1
## Grounds a pickaxe breaks faster; the other grounds (soils, sands,
## snow, mud) are for shovels.
const PICKAXE_GROUNDS := {
	Tiles.Ground.STONE_FLOOR: true,
	Tiles.Ground.DEEPSLATE_FLOOR: true,
	Tiles.Ground.TERRACOTTA: true,
	Tiles.Ground.TERRACOTTA_LIGHT: true,
	Tiles.Ground.ICE: true,
}
## Blocks a pickaxe breaks faster besides the cubes (stone, ores...), and
## blocks an axe breaks faster besides trees; nothing helps with plants.
const PICKAXE_BLOCKS := {Tiles.Block.ROCK: true, Tiles.Block.MOSSY_ROCK: true}
const AXE_BLOCKS := {Tiles.Block.BIG_MUSHROOM: true}


static func can_break(voxel: int, row: int) -> bool:
	return (
		row >= LOWEST_ROW
		and voxel != Voxels.AIR
		and voxel != Voxels.UNKNOWN
		and not Voxels.is_liquid(voxel)
	)


## Voxels a player can place: cubes (grounds and blocks).
static func can_place(voxel: int) -> bool:
	return voxel != Voxels.UNKNOWN and Voxels.is_cube(voxel)


## Whether a block can be placed into a voxel: air, liquids, small plants.
static func is_replaceable(voxel: int) -> bool:
	if voxel == Voxels.AIR or Voxels.is_liquid(voxel):
		return true
	return Voxels.is_object(voxel) and not Voxels.is_solid(voxel)


## What a broken voxel leaves: the water touching it from above or the
## side fills the hole (water does not flow yet), else air.
static func left_after_break(cell: Vector3i, voxel_at: Callable) -> int:
	for side: Vector3i in [
		Vector3i.UP, Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK
	]:
		var voxel: int = voxel_at.call(cell + side)
		if Voxels.is_liquid(voxel) and Tiles.is_water(Voxels.ground_of(voxel)):
			return voxel
	return Voxels.AIR


## Objects stand on the voxel under them: breaking it breaks them too.
static func needs_support(voxel: int) -> bool:
	return Voxels.is_object(voxel)


## Seconds to break a voxel with an item in hand: the tool made for it
## divides the hand's time by its tier's speed, anything else breaks it
## like a bare hand. Real seconds: not paced by the day's length.
static func break_seconds(voxel: int, held: int) -> float:
	var seconds := hand_seconds(voxel)
	var tool := Items.tool_of(held)
	if tool != Items.Tool.NONE and tool == tool_for(voxel):
		seconds /= Items.tool_speed(held)
	return seconds


## The tool a voxel breaks faster with (Items.Tool.NONE: only the hand).
static func tool_for(voxel: int) -> int:
	var block := Voxels.block_of(voxel)
	if block == Tiles.Block.AIR:
		var ground := Voxels.ground_of(voxel)
		if ground == Tiles.Ground.NONE or Voxels.is_liquid(voxel):
			return Items.Tool.NONE
		return Items.Tool.PICKAXE if PICKAXE_GROUNDS.has(ground) else Items.Tool.SHOVEL
	if Tiles.is_cube(block) or PICKAXE_BLOCKS.has(block):
		return Items.Tool.PICKAXE
	if ObjectShapes.is_tree(block) or AXE_BLOCKS.has(block):
		return Items.Tool.AXE
	return Items.Tool.NONE


## Seconds to break a voxel by hand: how hard it is.
static func hand_seconds(voxel: int) -> float:
	var block := Voxels.block_of(voxel)
	if block == Tiles.Block.AIR:
		return GROUND_SECONDS.get(Voxels.ground_of(voxel), SOIL_SECONDS)
	if ObjectShapes.is_tree(block):
		return TREE_SECONDS
	if BLOCK_SECONDS.has(block):
		return BLOCK_SECONDS[block]
	return OTHER_SECONDS if Tiles.is_block_solid(block) else PLANT_SECONDS


## Distance from a player's eye (feet in world pixels, height in levels)
## to the nearest point of a voxel cell, in local units.
static func reach_to(feet: Vector2, height: float, cell: Vector3i) -> float:
	var eye := Vector3(
		feet.x / GameConst.TILE_SIZE, height + EYE_HEIGHT, feet.y / GameConst.TILE_SIZE
	)
	var low := Vector3(cell.x, cell.y - GameConst.SEA_LEVEL, cell.z)
	return eye.distance_to(eye.clamp(low, low + Vector3.ONE))


## Whether a voxel cell (one level tall) overlaps a body standing with
## its feet at `feet` (world pixels) and `height` (levels).
static func overlaps_body(cell: Vector3i, feet: Vector2, height: float) -> bool:
	var level := float(cell.y - GameConst.SEA_LEVEL)
	if level >= height + PlayerBody.BODY_HEIGHT or level + 1.0 <= height:
		return false
	var cell_rect := Rect2(
		Vector2(cell.x, cell.z) * GameConst.TILE_SIZE, Vector2.ONE * GameConst.TILE_SIZE
	)
	return cell_rect.intersects(TileCollider.body_rect(feet, PlayerBody.BOX))
