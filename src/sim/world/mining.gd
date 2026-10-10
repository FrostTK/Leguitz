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
	Tiles.Block.CURTAINS_LONG: 0.7,
	Tiles.Block.CURTAINS_IRON: 0.9,
	Tiles.Block.CURTAINS_LONG_IRON: 1.0,
	Tiles.Block.RUG: 0.3,
	Tiles.Block.OAK_DOOR: 1.5,
	Tiles.Block.BIRCH_DOOR: 1.5,
	Tiles.Block.SPRUCE_DOOR: 1.5,
	Tiles.Block.DARK_OAK_DOOR: 1.5,
	Tiles.Block.JUNGLE_DOOR: 1.5,
	Tiles.Block.ACACIA_DOOR: 1.5,
	Tiles.Block.GLAZED_DOOR: 1.5,
	Tiles.Block.IRON_DOOR: 4.0,
	Tiles.Block.OAK_TRAPDOOR: 1.2,
	Tiles.Block.IRON_TRAPDOOR: 4.0,
	Tiles.Block.LADDER: 0.6,
	Tiles.Block.SHUTTERS: 0.8,
	Tiles.Block.IRON_BARS: 3.0,
	Tiles.Block.WOOD_RAILING: 1.2,
	Tiles.Block.IRON_RAILING: 3.0,
	Tiles.Block.CURTAINS_CLOSED: 0.6,
	Tiles.Block.CURTAINS_LONG_CLOSED: 0.7,
	Tiles.Block.CURTAINS_IRON_CLOSED: 0.9,
	Tiles.Block.CURTAINS_LONG_IRON_CLOSED: 1.0,
	Tiles.Block.GLASS_PANE: 0.4,
	Tiles.Block.OLD_GLASS_PANE: 0.4,
	Tiles.Block.LEADED_GLASS_PANE: 0.4,
	Tiles.Block.OLD_GLASS: 0.5,
	Tiles.Block.LEADED_GLASS: 0.5,
	Tiles.Block.OAK_WINDOW_SMALL: 0.8,
	Tiles.Block.OAK_WINDOW_SASH: 0.8,
	Tiles.Block.OAK_WINDOW_ROUND: 0.8,
	Tiles.Block.BIRCH_WINDOW: 0.8,
	Tiles.Block.BIRCH_WINDOW_SMALL: 0.8,
	Tiles.Block.BIRCH_WINDOW_SASH: 0.8,
	Tiles.Block.BIRCH_WINDOW_ROUND: 0.8,
	Tiles.Block.SPRUCE_WINDOW: 0.8,
	Tiles.Block.SPRUCE_WINDOW_SMALL: 0.8,
	Tiles.Block.SPRUCE_WINDOW_SASH: 0.8,
	Tiles.Block.SPRUCE_WINDOW_ROUND: 0.8,
	Tiles.Block.DARK_OAK_WINDOW: 0.8,
	Tiles.Block.DARK_OAK_WINDOW_SMALL: 0.8,
	Tiles.Block.DARK_OAK_WINDOW_SASH: 0.8,
	Tiles.Block.DARK_OAK_WINDOW_ROUND: 0.8,
	Tiles.Block.JUNGLE_WINDOW: 0.8,
	Tiles.Block.JUNGLE_WINDOW_SMALL: 0.8,
	Tiles.Block.JUNGLE_WINDOW_SASH: 0.8,
	Tiles.Block.JUNGLE_WINDOW_ROUND: 0.8,
	Tiles.Block.ACACIA_WINDOW: 0.8,
	Tiles.Block.ACACIA_WINDOW_SMALL: 0.8,
	Tiles.Block.ACACIA_WINDOW_SASH: 0.8,
	Tiles.Block.ACACIA_WINDOW_ROUND: 0.8,
	Tiles.Block.IRON_WINDOW: 2.5,
	Tiles.Block.IRON_WINDOW_SMALL: 2.5,
	Tiles.Block.IRON_WINDOW_SASH: 2.5,
	Tiles.Block.IRON_WINDOW_ROUND: 2.5,
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
	Tiles.Block.TORCH: PLANT_SECONDS,
	Tiles.Block.TORCH_BRACKET_LIT: 1.5,
	Tiles.Block.LANTERN: 1.0,
	Tiles.Block.LANTERN_HANGING: 1.0,
	Tiles.Block.LANTERN_WALL: 1.0,
	Tiles.Block.COMPOSTER: 1.5,
	Tiles.Block.PUMPKIN: 1.0,
	Tiles.Block.MELON: 1.0,
	Tiles.Block.TRELLIS: 0.5,
	Tiles.Block.NEST_BOX: 1.0,
	Tiles.Block.BEEHIVE: 1.5,
	Tiles.Block.BEE_NEST: 1.0,
	Tiles.Block.SCARECROW: 1.0,
	Tiles.Block.MOLEHILL: 0.4,
	Tiles.Block.BEAVER_DAM: 1.2,
	Tiles.Block.TURTLE_EGGS: 0.1,
	Tiles.Block.KITCHEN: 2.0,
	Tiles.Block.KITCHEN_WEST: 2.0,
	Tiles.Block.KITCHEN_NORTH: 2.0,
	Tiles.Block.KITCHEN_EAST: 2.0,
	Tiles.Block.MILL: 2.5,
	Tiles.Block.BUTTER_CHURN: 1.5,
	Tiles.Block.BARREL: 2.0,
	Tiles.Block.CHEESE_CELLAR: 2.0,
	Tiles.Block.FISH_TRAP: 0.6,
	Tiles.Block.SHIPYARD: 3.0,
}
## Trees by hand: chopping a trunk takes a while (a young one less).
const TREE_SECONDS := 3.5
const YOUNG_TREE_SECONDS := 1.2
## How far up (rows) a lantern placed with Shift looks for a ceiling.
const CEILING_SEARCH := 3
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
	Tiles.Block.OAK_WINDOW_SMALL: true,
	Tiles.Block.OAK_WINDOW_SASH: true,
	Tiles.Block.OAK_WINDOW_ROUND: true,
	Tiles.Block.BIRCH_WINDOW: true,
	Tiles.Block.BIRCH_WINDOW_SMALL: true,
	Tiles.Block.BIRCH_WINDOW_SASH: true,
	Tiles.Block.BIRCH_WINDOW_ROUND: true,
	Tiles.Block.SPRUCE_WINDOW: true,
	Tiles.Block.SPRUCE_WINDOW_SMALL: true,
	Tiles.Block.SPRUCE_WINDOW_SASH: true,
	Tiles.Block.SPRUCE_WINDOW_ROUND: true,
	Tiles.Block.DARK_OAK_WINDOW: true,
	Tiles.Block.DARK_OAK_WINDOW_SMALL: true,
	Tiles.Block.DARK_OAK_WINDOW_SASH: true,
	Tiles.Block.DARK_OAK_WINDOW_ROUND: true,
	Tiles.Block.JUNGLE_WINDOW: true,
	Tiles.Block.JUNGLE_WINDOW_SMALL: true,
	Tiles.Block.JUNGLE_WINDOW_SASH: true,
	Tiles.Block.JUNGLE_WINDOW_ROUND: true,
	Tiles.Block.ACACIA_WINDOW: true,
	Tiles.Block.ACACIA_WINDOW_SMALL: true,
	Tiles.Block.ACACIA_WINDOW_SASH: true,
	Tiles.Block.ACACIA_WINDOW_ROUND: true,
	Tiles.Block.TABLE: true,
	Tiles.Block.CHAIR: true,
	Tiles.Block.OAK_DOOR: true,
	Tiles.Block.BIRCH_DOOR: true,
	Tiles.Block.SPRUCE_DOOR: true,
	Tiles.Block.DARK_OAK_DOOR: true,
	Tiles.Block.JUNGLE_DOOR: true,
	Tiles.Block.ACACIA_DOOR: true,
	Tiles.Block.GLAZED_DOOR: true,
	Tiles.Block.OAK_TRAPDOOR: true,
	Tiles.Block.LADDER: true,
	Tiles.Block.SHUTTERS: true,
	Tiles.Block.WOOD_RAILING: true,
	Tiles.Block.FENCE: true,
	Tiles.Block.GATE: true,
	Tiles.Block.GATE_OPEN: true,
	Tiles.Block.BIG_GATE: true,
	Tiles.Block.BIG_GATE_OPEN: true,
	Tiles.Block.CAMPFIRE: true,
	Tiles.Block.COMPOSTER: true,
	Tiles.Block.PUMPKIN: true,
	Tiles.Block.MELON: true,
	Tiles.Block.TRELLIS: true,
	Tiles.Block.NEST_BOX: true,
	Tiles.Block.BEEHIVE: true,
	Tiles.Block.BEE_NEST: true,
	Tiles.Block.SCARECROW: true,
	Tiles.Block.BEAVER_DAM: true,
	Tiles.Block.KITCHEN: true,
	Tiles.Block.KITCHEN_WEST: true,
	Tiles.Block.KITCHEN_NORTH: true,
	Tiles.Block.KITCHEN_EAST: true,
	Tiles.Block.BUTTER_CHURN: true,
	Tiles.Block.BARREL: true,
	Tiles.Block.CHEESE_CELLAR: true,
	Tiles.Block.FISH_TRAP: true,
	Tiles.Block.SHIPYARD: true,
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
	Tiles.Block.TORCH_BRACKET_LIT: true,
	Tiles.Block.LANTERN: true,
	Tiles.Block.LANTERN_HANGING: true,
	Tiles.Block.LANTERN_WALL: true,
	Tiles.Block.MILL: true,
	Tiles.Block.IRON_WINDOW: true,
	Tiles.Block.IRON_WINDOW_SMALL: true,
	Tiles.Block.IRON_WINDOW_SASH: true,
	Tiles.Block.IRON_WINDOW_ROUND: true,
	Tiles.Block.IRON_DOOR: true,
	Tiles.Block.IRON_TRAPDOOR: true,
	Tiles.Block.IRON_BARS: true,
	Tiles.Block.IRON_RAILING: true,
}
## Objects placed as they are (no way to face), standing on a cube.
const FLOOR_OBJECTS := {
	Tiles.Block.TABLE: true,
	Tiles.Block.RUG: true,
	Tiles.Block.IRON_BARS: true,
	Tiles.Block.WOOD_RAILING: true,
	Tiles.Block.IRON_RAILING: true,
	Tiles.Block.FENCE: true,
	Tiles.Block.CAMPFIRE: true,
	Tiles.Block.TORCH: true,
	Tiles.Block.LANTERN: true,
	Tiles.Block.COMPOSTER: true,
	Tiles.Block.TRELLIS: true,
	Tiles.Block.PUMPKIN: true,
	Tiles.Block.NEST_BOX: true,
	Tiles.Block.BEEHIVE: true,
	Tiles.Block.SCARECROW: true,
	Tiles.Block.MILL: true,
	Tiles.Block.BUTTER_CHURN: true,
	Tiles.Block.BARREL: true,
	Tiles.Block.CHEESE_CELLAR: true,
}

## Objects set over still water (a fish trap), not on the ground.
const ON_WATER := {Tiles.Block.FISH_TRAP: true}


## Whether a voxel can be broken (a door's top: through its door).
static func can_break(voxel: int, row: int) -> bool:
	return (
		row >= LOWEST_ROW
		and voxel != Voxels.AIR
		and voxel != Voxels.UNKNOWN
		and not Voxels.is_liquid(voxel)
		and not Openings.is_top(Voxels.block_of(voxel))
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
		or Voxels.is_shaped(voxel)
		or ObjectShapes.front_of(block) != Vector2i.ZERO
		or FLOOR_OBJECTS.has(block)
		or Growth.SAPLINGS.has(block)
		or Farming.SOWN.has(block)
		or block == Tiles.Block.TURTLE_EGGS
		or ON_WATER.has(block)
	)


## The cells a placed voxel takes ({cell: voxel}; empty: no room). A cube
## takes the cell aimed at; a wide object (workbench, big gate) faces
## `front` and takes the cell aimed at and the one on its right (or else
## the one on its left); other furniture faces `front` in the cell aimed
## at, the objects placed as they are stand there, all free of anything
## solid or liquid and standing on cubes. What hangs on a wall faces
## `front` (away from the side of the cube aimed at, behind it). `face`:
## the side of the cube aimed at (UP: its top); a torch goes on the ground
## or into an empty bracket (aimed at it, `cell` is the bracket's), never
## straight against a wall; a lantern on the ground, hung from the cube
## above (its underside aimed at) or on a wall.
static func placement(
	cell: Vector3i,
	voxel: int,
	front: Vector2i,
	voxel_at: Callable,
	face := Vector3i.UP,
	upper := false
) -> Dictionary:
	var block := Voxels.block_of(voxel)
	if ShapedBlocks.is_shaped(block):
		return ShapedBlocks.placement(cell, block, front, face, upper, voxel_at)
	var kind := ObjectShapes.kind_of(block)
	if ObjectShapes.WALL_MOUNTED.has(kind):
		return _hung(cell, kind, front, voxel_at)
	if block == Tiles.Block.TORCH:
		var bracket := Voxels.block_of(voxel_at.call(cell))
		if ObjectShapes.kind_of(bracket) == Tiles.Block.TORCH_BRACKET:
			var lit := ObjectShapes.facing(
				Tiles.Block.TORCH_BRACKET_LIT, ObjectShapes.front_of(bracket)
			)
			return {cell: Voxels.of_block(lit)}
		if face.y == 0:
			return {}
	if block == Tiles.Block.LANTERN and face.y < 0:
		var there: int = voxel_at.call(cell)
		if not is_replaceable(there) or Voxels.is_liquid(there):
			return {}
		if not Voxels.is_cube(voxel_at.call(cell + Vector3i.UP)):
			return {}
		return {cell: Voxels.of_block(Tiles.Block.LANTERN_HANGING)}
	if block == Tiles.Block.LANTERN and face.y == 0:
		return _hung(cell, Tiles.Block.LANTERN_WALL, front, voxel_at)
	if Openings.is_door(block):
		# Two levels: its cell and the one over it, both free.
		var over: int = voxel_at.call(cell + Vector3i.UP)
		if not _bench_room(cell, voxel_at) or not is_replaceable(over) or Voxels.is_liquid(over):
			return {}
		var door := ObjectShapes.facing(kind, front)
		return {
			cell: Voxels.of_block(door), cell + Vector3i.UP: Voxels.of_block(Openings.top_of(door))
		}
	if ObjectShapes.WIDE_KINDS.has(kind):
		var left := ObjectShapes.facing(kind, front)
		var right := ObjectShapes.wide_right(left)
		var step := Vector3i(right.x, 0, right.y)
		var end := Voxels.of_block(ObjectShapes.wide_end(kind, right))
		for start: Vector3i in [cell, cell - step]:
			if _bench_room(start, voxel_at) and _bench_room(start + step, voxel_at):
				return {start: Voxels.of_block(left), start + step: end}
		return {}
	if kind == Tiles.Block.SHIPYARD:
		# Facing the water (Boats.water_side), not the player.
		var water := Boats.water_side(cell, voxel_at, -front)
		if water == Vector2i.ZERO or not _bench_room(cell, voxel_at):
			return {}
		return {cell: Voxels.of_block(ObjectShapes.facing(kind, water))}
	if kind != -1:
		if not _bench_room(cell, voxel_at):
			return {}
		return {cell: Voxels.of_block(ObjectShapes.facing(kind, front))}
	if ON_WATER.has(block):
		var under: int = voxel_at.call(cell + Vector3i.DOWN)
		var still := Voxels.is_water(under) and Fluids.level_of(under) == 0
		return {cell: voxel} if still and voxel_at.call(cell) == Voxels.AIR else {}
	if block == Tiles.Block.RUG:
		# On a floor, not on another rug.
		var free: bool = voxel_at.call(cell) != voxel and _bench_room(cell, voxel_at)
		return {cell: voxel} if free else {}
	if FLOOR_OBJECTS.has(block):
		return {cell: voxel} if _bench_room(cell, voxel_at) else {}
	if Farming.SOWN.has(block):
		return Farming.sowing(cell, voxel, voxel_at)
	if block == Tiles.Block.TURTLE_EGGS:
		# Turtle eggs go back into the sand.
		var sand: bool = voxel_at.call(cell + Vector3i.DOWN) == Voxels.of_ground(Tiles.Ground.SAND)
		var spot: int = voxel_at.call(cell)
		return {cell: voxel} if sand and is_replaceable(spot) and not Voxels.is_liquid(spot) else {}
	if Growth.SAPLINGS.has(block):
		var there: int = voxel_at.call(cell)
		var free := is_replaceable(there) and not Voxels.is_liquid(there)
		return {cell: voxel} if free and Growth.is_soil(voxel_at.call(cell + Vector3i.DOWN)) else {}
	return {cell: voxel} if takes(voxel_at.call(cell)) else {}


## Whether breaking a voxel wears the tool in hand (not what breaks at
## once: small plants).
static func wears(voxel: int) -> bool:
	return hand_seconds(voxel) > INSTANT_SECONDS


## Something of `kind` (see ObjectShapes.WALL_MOUNTED) hung in `cell`
## facing `front`, on the cube behind it (long curtains: the cell under
## free too, they hang down to the floor).
static func _hung(cell: Vector3i, kind: int, front: Vector2i, voxel_at: Callable) -> Dictionary:
	var there: int = voxel_at.call(cell)
	var behind: int = voxel_at.call(cell - Vector3i(front.x, 0, front.y))
	if not is_replaceable(there) or Voxels.is_liquid(there) or not Voxels.is_cube(behind):
		return {}
	if ObjectShapes.LONG_CURTAINS.has(kind):
		var below: int = voxel_at.call(cell + Vector3i.DOWN)
		if Voxels.is_solid(below) or Voxels.is_cube(below) or Voxels.is_liquid(below):
			return {}
	return {cell: Voxels.of_block(ObjectShapes.facing(kind, front))}


## The cell under the first cube over `cell` (within CEILING_SEARCH rows,
## through air only): where a lantern hangs from that ceiling; MAX: none.
static func under_ceiling(cell: Vector3i, voxel_at: Callable) -> Vector3i:
	for up in CEILING_SEARCH:
		var at := cell + Vector3i(0, up, 0)
		var voxel: int = voxel_at.call(at + Vector3i.UP)
		if Voxels.is_cube(voxel):
			return at if voxel_at.call(at) == Voxels.AIR else Vector3i.MAX
		if voxel != Voxels.AIR:
			break
	return Vector3i.MAX


## Whether placing `voxel` aimed at `there` fills it (a torch into an empty
## bracket, grapes on a trellis, anything but a rug onto a rug) instead of
## going next to it.
static func fills(there: int, voxel: int) -> bool:
	var block := Voxels.block_of(voxel)
	if is_rug(there):
		return not is_rug(voxel)
	if Farming.bed_of(block) == Farming.Bed.TRELLIS and Farming.SOWN.has(block):
		return Voxels.block_of(there) == Tiles.Block.TRELLIS
	return (
		block == Tiles.Block.TORCH
		and ObjectShapes.kind_of(Voxels.block_of(there)) == Tiles.Block.TORCH_BRACKET
	)


## Whether where `voxel` goes depends on the side aimed at (what hangs on
## a wall, a torch, a lantern): the client sends that side.
static func minds_the_side(voxel: int) -> bool:
	var block := Voxels.block_of(voxel)
	return (
		ObjectShapes.WALL_MOUNTED.has(ObjectShapes.kind_of(block))
		or block == Tiles.Block.TORCH
		or block == Tiles.Block.LANTERN
	)


## Whether a voxel swings when used: a gate, a door, a trapdoor, curtains
## or shutters (drawn or opened; see swung_cells).
static func swings(voxel: int) -> bool:
	if voxel == Voxels.UNKNOWN:
		return false
	var block := Voxels.block_of(voxel)
	return ObjectShapes.is_gate(block) or ObjectShapes.is_curtain(block) or Openings.is_top(block)


## A gate in `cell` swung open or shut (curtains drawn or tied back): its
## cells and their new voxels. A door's top follows it, and the other half
## of a double door does the same (Openings.partner).
static func swung_cells(cell: Vector3i, voxel: int, voxel_at: Callable) -> Dictionary:
	var cells := {}
	var parts := object_cells(cell, voxel, voxel_at)
	var door := Voxels.block_of(voxel_at.call(parts[0]))
	if not Openings.is_door(door):
		for part in parts:
			var block := Voxels.block_of(voxel_at.call(part))
			cells[part] = Voxels.of_block(ObjectShapes.swung(block))
		return cells
	var opening := not ObjectShapes.is_open(door)
	var other := Openings.partner(door, parts[0], voxel_at)
	for bottom: Vector3i in [parts[0], other]:
		if bottom == Vector3i.MAX:
			continue
		var block := Voxels.block_of(voxel_at.call(bottom))
		if ObjectShapes.is_open(block) != opening:
			block = ObjectShapes.swung(block)
		cells[bottom] = Voxels.of_block(block)
		if Openings.is_top(Voxels.block_of(voxel_at.call(bottom + Vector3i.UP))):
			cells[bottom + Vector3i.UP] = Voxels.of_block(Openings.top_of(block))
	return cells


## What hangs on the sides of the cube in `cell` or from it (it falls with
## it).
static func hung_on(cell: Vector3i, voxel_at: Callable) -> Array[Vector3i]:
	var hung: Array[Vector3i] = []
	var below := cell + Vector3i.DOWN
	if ObjectShapes.is_hanging(Voxels.block_of(voxel_at.call(below))):
		hung.append(below)
	for side: Vector2i in ObjectShapes.WAYS:
		var at := cell + Vector3i(side.x, 0, side.y)
		var block := Voxels.block_of(voxel_at.call(at))
		if ObjectShapes.is_wall_mounted(block) and ObjectShapes.front_of(block) == side:
			hung.append(at)
	return hung


## Whether a voxel opens something when used (right click): a workbench,
## a chest, a furnace (not a broken one) or a kitchen counter.
static func opens(voxel: int) -> bool:
	var block := Voxels.block_of(voxel)
	return (
		ObjectShapes.is_bench(block)
		or ObjectShapes.is_chest(block)
		or ObjectShapes.furnace_kind(block) != -1
		or ObjectShapes.is_kitchen(block)
		or ObjectShapes.is_shipyard(block)
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
	# A door and its top, either aimed at.
	if Openings.is_top(block):
		var below := cell + Vector3i.DOWN
		if Openings.is_door(Voxels.block_of(voxel_at.call(below))):
			return [below, cell]
		return [cell]
	if Openings.is_door(block):
		if Openings.is_top(Voxels.block_of(voxel_at.call(cell + Vector3i.UP))):
			return [cell, cell + Vector3i.UP]
		return [cell]
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
		takes(there)
		and not Voxels.is_liquid(there)
		and Voxels.is_cube(voxel_at.call(cell + Vector3i.DOWN))
	)


## Whether furniture or a block can be placed into a voxel: what is
## replaceable, and a rug (it then lies under it: ChunkData.rugs).
static func takes(voxel: int) -> bool:
	return is_replaceable(voxel) or is_rug(voxel)


static func is_rug(voxel: int) -> bool:
	return voxel == Voxels.of_block(Tiles.Block.RUG)


## Whether a block can be placed into a voxel: air, liquids, small plants
## (not what players placed: a torch, a curtain...).
static func is_replaceable(voxel: int) -> bool:
	if voxel == Voxels.AIR or Voxels.is_liquid(voxel):
		return true
	if not Voxels.is_object(voxel) or Voxels.is_solid(voxel):
		return false
	if Farming.is_crop(Voxels.block_of(voxel)):
		return false
	return Items.item_placing(ObjectShapes.base_kind(Voxels.block_of(voxel))) == Items.Id.NONE


## Objects stand on the voxel under them: breaking it breaks them too
## (not what hangs on a wall or from a ceiling: see hung_on).
static func needs_support(voxel: int) -> bool:
	var block := Voxels.block_of(voxel)
	return (
		Voxels.is_object(voxel)
		and not Voxels.is_shaped(voxel)
		and not ObjectShapes.is_wall_mounted(block)
		and not ObjectShapes.is_hanging(block)
	)


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
	if ShapedBlocks.is_shaped(block):
		# Stairs and slabs break as their material does.
		return tool_for(Voxels.of_block(ShapedBlocks.material_of(block)))
	if block == Tiles.Block.AIR:
		var ground := Voxels.ground_of(voxel)
		if ground == Tiles.Ground.NONE or Voxels.is_liquid(voxel):
			return Items.Tool.NONE
		return Items.Tool.PICKAXE if PICKAXE_GROUNDS.has(ground) else Items.Tool.SHOVEL
	var kind := ObjectShapes.pair_of(ObjectShapes.base_kind(block))
	if ObjectShapes.is_tree(block) or AXE_BLOCKS.has(block) or AXE_BLOCKS.has(kind):
		return Items.Tool.AXE
	if Tiles.is_cube(block) or PICKAXE_BLOCKS.has(block) or PICKAXE_BLOCKS.has(kind):
		return Items.Tool.PICKAXE
	return Items.Tool.NONE


## Seconds to break a voxel by hand: how hard it is.
static func hand_seconds(voxel: int) -> float:
	var block := Voxels.block_of(voxel)
	if ShapedBlocks.is_shaped(block):
		return hand_seconds(Voxels.of_block(ShapedBlocks.material_of(block)))
	if block == Tiles.Block.AIR:
		return GROUND_SECONDS.get(Voxels.ground_of(voxel), SOIL_SECONDS)
	if Growth.YOUNG.has(block):
		return YOUNG_TREE_SECONDS
	if ObjectShapes.is_tree(block):
		return TREE_SECONDS
	if BLOCK_SECONDS.has(block):
		return BLOCK_SECONDS[block]
	# By kind, open or shut (open gates and doors: their shut kind's).
	var kind := ObjectShapes.pair_of(ObjectShapes.base_kind(block))
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
