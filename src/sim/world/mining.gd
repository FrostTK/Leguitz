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
	Tiles.Block.OAK_PLANKS: 2.0,
	Tiles.Block.BIRCH_PLANKS: 2.0,
	Tiles.Block.SPRUCE_PLANKS: 2.0,
	Tiles.Block.DARK_OAK_PLANKS: 2.0,
	Tiles.Block.JUNGLE_PLANKS: 2.0,
	Tiles.Block.ACACIA_PLANKS: 2.0,
	Tiles.Block.WORKBENCH: 2.5,
	Tiles.Block.WORKBENCH_WEST: 2.5,
	Tiles.Block.WORKBENCH_NORTH: 2.5,
	Tiles.Block.WORKBENCH_EAST: 2.5,
	Tiles.Block.WORKBENCH_END_X: 2.5,
	Tiles.Block.WORKBENCH_END_Z: 2.5,
	Tiles.Block.CHEST: 2.5,
	Tiles.Block.CHEST_WEST: 2.5,
	Tiles.Block.CHEST_NORTH: 2.5,
	Tiles.Block.CHEST_EAST: 2.5,
	Tiles.Block.FOOD_FURNACE: 3.5,
	Tiles.Block.FOOD_FURNACE_WEST: 3.5,
	Tiles.Block.FOOD_FURNACE_NORTH: 3.5,
	Tiles.Block.FOOD_FURNACE_EAST: 3.5,
	Tiles.Block.FOOD_FURNACE_LIT: 3.5,
	Tiles.Block.FOOD_FURNACE_LIT_WEST: 3.5,
	Tiles.Block.FOOD_FURNACE_LIT_NORTH: 3.5,
	Tiles.Block.FOOD_FURNACE_LIT_EAST: 3.5,
	Tiles.Block.FACTORY_FURNACE: 3.5,
	Tiles.Block.FACTORY_FURNACE_WEST: 3.5,
	Tiles.Block.FACTORY_FURNACE_NORTH: 3.5,
	Tiles.Block.FACTORY_FURNACE_EAST: 3.5,
	Tiles.Block.FACTORY_FURNACE_LIT: 3.5,
	Tiles.Block.FACTORY_FURNACE_LIT_WEST: 3.5,
	Tiles.Block.FACTORY_FURNACE_LIT_NORTH: 3.5,
	Tiles.Block.FACTORY_FURNACE_LIT_EAST: 3.5,
	Tiles.Block.BROKEN_FURNACE: 3.5,
	Tiles.Block.BROKEN_FURNACE_WEST: 3.5,
	Tiles.Block.BROKEN_FURNACE_NORTH: 3.5,
	Tiles.Block.BROKEN_FURNACE_EAST: 3.5,
	Tiles.Block.STONE_BRICKS: 3.5,
	Tiles.Block.SMOOTH_STONE: 3.5,
	Tiles.Block.BRICKS: 4.0,
	Tiles.Block.DEEPSLATE_BRICKS: 5.0,
	Tiles.Block.CUT_SANDSTONE: 2.5,
	Tiles.Block.GLASS: 0.5,
	Tiles.Block.WOOL: 0.8,
	Tiles.Block.WINDOW: 0.8,
	# What players place, by kind (any way it faces, open or shut).
	Tiles.Block.TORCH_BRACKET: 1.5,
	Tiles.Block.CURTAINS: 0.6,
	Tiles.Block.GLASS_PANE: 0.4,
	Tiles.Block.SINK: 2.5,
	Tiles.Block.TOILET: 2.5,
	Tiles.Block.TABLE: 2.0,
	Tiles.Block.CHAIR: 1.5,
	Tiles.Block.FENCE: 2.0,
	Tiles.Block.GATE: 2.0,
	Tiles.Block.GATE_OPEN: 2.0,
	Tiles.Block.BIG_GATE: 2.5,
	Tiles.Block.BIG_GATE_OPEN: 2.5,
	Tiles.Block.CAMPFIRE: 1.0,
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
## Blocks an axe breaks faster besides trees (wood), and blocks a pickaxe
## breaks faster besides the other cubes (stone, ores...); nothing helps
## with plants.
const AXE_BLOCKS := {
	Tiles.Block.BIG_MUSHROOM: true,
	Tiles.Block.OAK_PLANKS: true,
	Tiles.Block.BIRCH_PLANKS: true,
	Tiles.Block.SPRUCE_PLANKS: true,
	Tiles.Block.DARK_OAK_PLANKS: true,
	Tiles.Block.JUNGLE_PLANKS: true,
	Tiles.Block.ACACIA_PLANKS: true,
	Tiles.Block.WORKBENCH: true,
	Tiles.Block.WORKBENCH_WEST: true,
	Tiles.Block.WORKBENCH_NORTH: true,
	Tiles.Block.WORKBENCH_EAST: true,
	Tiles.Block.WORKBENCH_END_X: true,
	Tiles.Block.WORKBENCH_END_Z: true,
	Tiles.Block.CHEST: true,
	Tiles.Block.CHEST_WEST: true,
	Tiles.Block.CHEST_NORTH: true,
	Tiles.Block.CHEST_EAST: true,
	Tiles.Block.WINDOW: true,
	Tiles.Block.TABLE: true,
	Tiles.Block.CHAIR: true,
	Tiles.Block.FENCE: true,
	Tiles.Block.GATE: true,
	Tiles.Block.GATE_OPEN: true,
	Tiles.Block.BIG_GATE: true,
	Tiles.Block.BIG_GATE_OPEN: true,
	Tiles.Block.CAMPFIRE: true,
}
const PICKAXE_BLOCKS := {
	Tiles.Block.ROCK: true,
	Tiles.Block.MOSSY_ROCK: true,
	Tiles.Block.FOOD_FURNACE: true,
	Tiles.Block.FOOD_FURNACE_WEST: true,
	Tiles.Block.FOOD_FURNACE_NORTH: true,
	Tiles.Block.FOOD_FURNACE_EAST: true,
	Tiles.Block.FOOD_FURNACE_LIT: true,
	Tiles.Block.FOOD_FURNACE_LIT_WEST: true,
	Tiles.Block.FOOD_FURNACE_LIT_NORTH: true,
	Tiles.Block.FOOD_FURNACE_LIT_EAST: true,
	Tiles.Block.FACTORY_FURNACE: true,
	Tiles.Block.FACTORY_FURNACE_WEST: true,
	Tiles.Block.FACTORY_FURNACE_NORTH: true,
	Tiles.Block.FACTORY_FURNACE_EAST: true,
	Tiles.Block.FACTORY_FURNACE_LIT: true,
	Tiles.Block.FACTORY_FURNACE_LIT_WEST: true,
	Tiles.Block.FACTORY_FURNACE_LIT_NORTH: true,
	Tiles.Block.FACTORY_FURNACE_LIT_EAST: true,
	Tiles.Block.BROKEN_FURNACE: true,
	Tiles.Block.BROKEN_FURNACE_WEST: true,
	Tiles.Block.BROKEN_FURNACE_NORTH: true,
	Tiles.Block.BROKEN_FURNACE_EAST: true,
	Tiles.Block.TORCH_BRACKET: true,
	Tiles.Block.SINK: true,
	Tiles.Block.TOILET: true,
}
## Objects placed as they are (no way to face), standing on a cube.
const FLOOR_OBJECTS := {
	Tiles.Block.TABLE: true,
	Tiles.Block.FENCE: true,
	Tiles.Block.CAMPFIRE: true,
}


static func can_break(voxel: int, row: int) -> bool:
	return (
		row >= LOWEST_ROW
		and voxel != Voxels.AIR
		and voxel != Voxels.UNKNOWN
		and not Voxels.is_liquid(voxel)
	)


## Voxels a player can place: cubes (grounds and blocks), the objects
## placed facing the player (workbench, chest, furnaces, furniture...) and
## the others players make (a table, a fence, a campfire).
static func can_place(voxel: int) -> bool:
	if voxel == Voxels.UNKNOWN:
		return false
	var block := Voxels.block_of(voxel)
	return (
		Voxels.is_cube(voxel)
		or ObjectShapes.front_of(block) != Vector2i.ZERO
		or FLOOR_OBJECTS.has(block)
	)


## The cells a placed voxel takes ({cell: voxel}; empty: no room). A cube
## takes the cell aimed at; a wide object (workbench, big gate) faces
## `front` and takes the cell aimed at and the one on its right (or else
## the one on its left); other furniture faces `front` in the cell aimed
## at, the objects placed as they are stand there, all free of anything
## solid or liquid and standing on cubes. What hangs on a wall faces
## `front` (away from the side of the cube aimed at, behind it).
static func placement(
	cell: Vector3i, voxel: int, front: Vector2i, voxel_at: Callable
) -> Dictionary:
	var block := Voxels.block_of(voxel)
	var kind := ObjectShapes.kind_of(block)
	if ObjectShapes.WALL_MOUNTED.has(kind):
		var there: int = voxel_at.call(cell)
		var behind: int = voxel_at.call(cell - Vector3i(front.x, 0, front.y))
		if not is_replaceable(there) or Voxels.is_liquid(there) or not Voxels.is_cube(behind):
			return {}
		return {cell: Voxels.of_block(ObjectShapes.facing(kind, front))}
	if ObjectShapes.WIDE_KINDS.has(kind):
		var left := ObjectShapes.facing(kind, front)
		var right := ObjectShapes.wide_right(left)
		var step := Vector3i(right.x, 0, right.y)
		var end := Voxels.of_block(ObjectShapes.wide_end(kind, right))
		for start: Vector3i in [cell, cell - step]:
			if _bench_room(start, voxel_at) and _bench_room(start + step, voxel_at):
				return {start: Voxels.of_block(left), start + step: end}
		return {}
	if kind != -1:
		if not _bench_room(cell, voxel_at):
			return {}
		return {cell: Voxels.of_block(ObjectShapes.facing(kind, front))}
	if FLOOR_OBJECTS.has(block):
		return {cell: voxel} if _bench_room(cell, voxel_at) else {}
	return {cell: voxel} if is_replaceable(voxel_at.call(cell)) else {}


## Whether breaking a voxel wears the tool in hand (not what breaks at
## once: small plants).
static func wears(voxel: int) -> bool:
	return hand_seconds(voxel) > INSTANT_SECONDS


## Whether a voxel swings when used: a gate (see swung_cells).
static func swings(voxel: int) -> bool:
	return voxel != Voxels.UNKNOWN and ObjectShapes.is_gate(Voxels.block_of(voxel))


## A gate in `cell` swung open or shut: its cells and their new voxels.
static func swung_cells(cell: Vector3i, voxel: int, voxel_at: Callable) -> Dictionary:
	var cells := {}
	for part in object_cells(cell, voxel, voxel_at):
		var block := Voxels.block_of(voxel_at.call(part))
		cells[part] = Voxels.of_block(ObjectShapes.swung(block))
	return cells


## What hangs on the sides of the cube in `cell` (it falls with it).
static func hung_on(cell: Vector3i, voxel_at: Callable) -> Array[Vector3i]:
	var hung: Array[Vector3i] = []
	for side: Vector2i in ObjectShapes.WAYS:
		var at := cell + Vector3i(side.x, 0, side.y)
		var block := Voxels.block_of(voxel_at.call(at))
		if ObjectShapes.is_wall_mounted(block) and ObjectShapes.front_of(block) == side:
			hung.append(at)
	return hung


## Whether a voxel opens something when used (right click): a workbench,
## a chest or a furnace (not a broken one).
static func opens(voxel: int) -> bool:
	var block := Voxels.block_of(voxel)
	return (
		ObjectShapes.is_bench(block)
		or ObjectShapes.is_chest(block)
		or ObjectShapes.furnace_kind(block) != -1
	)


## Which way a workbench placed at `cell` faces: towards the player's feet
## (world pixels), along the nearer axis.
static func front_towards(cell: Vector3i, feet: Vector2) -> Vector2i:
	var away := feet / GameConst.TILE_SIZE - Vector2(cell.x + 0.5, cell.z + 0.5)
	if absf(away.x) > absf(away.y):
		return Vector2i(1 if away.x > 0.0 else -1, 0)
	return Vector2i(0, 1 if away.y >= 0.0 else -1)


## The cells of the object standing in `cell` (its left end first): both
## ends of a wide object (a workbench, a big gate), else the cell alone.
static func object_cells(cell: Vector3i, voxel: int, voxel_at: Callable) -> Array[Vector3i]:
	var block := Voxels.block_of(voxel)
	var kind := ObjectShapes.wide_kind(block)
	if kind == -1:
		return [cell]
	if ObjectShapes.is_wide_left(block):
		var right := ObjectShapes.wide_right(block)
		var other := cell + Vector3i(right.x, 0, right.y)
		var other_block := Voxels.block_of(voxel_at.call(other))
		if ObjectShapes.is_wide_end(other_block) and ObjectShapes.wide_kind(other_block) == kind:
			return [cell, other]
		return [cell]
	var along := ObjectShapes.end_axis(block)
	for side: int in [-1, 1]:
		var left := cell + Vector3i(along.x, 0, along.y) * side
		var left_block := Voxels.block_of(voxel_at.call(left))
		if ObjectShapes.is_wide_left(left_block) and ObjectShapes.wide_kind(left_block) == kind:
			var right := ObjectShapes.wide_right(left_block)
			if left + Vector3i(right.x, 0, right.y) == cell:
				return [left, cell]
	return [cell]


static func _bench_room(cell: Vector3i, voxel_at: Callable) -> bool:
	var there: int = voxel_at.call(cell)
	return (
		is_replaceable(there)
		and not Voxels.is_liquid(there)
		and Voxels.is_cube(voxel_at.call(cell + Vector3i.DOWN))
	)


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


## Objects stand on the voxel under them: breaking it breaks them too
## (not what hangs on a wall: see hung_on).
static func needs_support(voxel: int) -> bool:
	return Voxels.is_object(voxel) and not ObjectShapes.is_wall_mounted(Voxels.block_of(voxel))


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
	var kind := ObjectShapes.base_kind(block)
	if ObjectShapes.is_tree(block) or AXE_BLOCKS.has(block) or AXE_BLOCKS.has(kind):
		return Items.Tool.AXE
	if Tiles.is_cube(block) or PICKAXE_BLOCKS.has(block) or PICKAXE_BLOCKS.has(kind):
		return Items.Tool.PICKAXE
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
	var kind := ObjectShapes.base_kind(block)
	if BLOCK_SECONDS.has(kind):
		return BLOCK_SECONDS[kind]
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
## its feet at `feet` (world pixels) and `height` (levels): a player's, or
## one `box` wide and `tall` high (an animal's).
static func overlaps_body(
	cell: Vector3i,
	feet: Vector2,
	height: float,
	box := PlayerBody.BOX,
	tall := PlayerBody.BODY_HEIGHT
) -> bool:
	var level := float(cell.y - GameConst.SEA_LEVEL)
	if level >= height + tall or level + 1.0 <= height:
		return false
	var cell_rect := Rect2(
		Vector2(cell.x, cell.z) * GameConst.TILE_SIZE, Vector2.ONE * GameConst.TILE_SIZE
	)
	return cell_rect.intersects(TileCollider.body_rect(feet, box))
