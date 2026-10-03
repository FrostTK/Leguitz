class_name ObjectShapes
extends RefCounted
## Shapes of the objects standing in voxels (trees, rocks, cacti...), shared
## by physics and by the voxel models: the trunk drawn is the trunk that
## blocks. Each object block has a few versions (trees: TREE_VARIANTS); the
## version of a tile, and where small things stand in it, come from its
## position, so the server and every client agree. Also what players build
## and place: furniture facing them, objects two tiles long (a workbench, a
## big gate), objects hung on a wall, fences joining their neighbors and
## gates that open.

const VARIANTS := 3
const TREE_VARIANTS := 8
const SALT := 0x9A0B
const SIZE_SALT := 0x51E5

## Per tree: trunk width (voxels = world pixels, even) and trunk height
## (voxels, 16 per level), smallest and largest.
const TREES := {
	Tiles.Block.OAK: [Vector2i(6, 10), Vector2i(44, 66)],
	Tiles.Block.BIRCH: [Vector2i(4, 6), Vector2i(58, 84)],
	Tiles.Block.DARK_OAK: [Vector2i(10, 14), Vector2i(40, 56)],
	Tiles.Block.JUNGLE_TREE: [Vector2i(8, 12), Vector2i(88, 128)],
	Tiles.Block.SWAMP_OAK: [Vector2i(6, 8), Vector2i(46, 62)],
	Tiles.Block.ACACIA: [Vector2i(4, 6), Vector2i(36, 48)],
	Tiles.Block.SPRUCE: [Vector2i(4, 6), Vector2i(84, 120)],
	Tiles.Block.SNOWY_SPRUCE: [Vector2i(4, 6), Vector2i(84, 120)],
	# Young trees (Growth): a thin trunk a level or two high under a small
	# crown.
	Tiles.Block.YOUNG_OAK: [Vector2i(2, 4), Vector2i(26, 36)],
	Tiles.Block.YOUNG_BIRCH: [Vector2i(2, 4), Vector2i(30, 42)],
	Tiles.Block.YOUNG_SPRUCE: [Vector2i(2, 4), Vector2i(34, 48)],
	Tiles.Block.YOUNG_DARK_OAK: [Vector2i(4, 6), Vector2i(24, 34)],
	Tiles.Block.YOUNG_JUNGLE_TREE: [Vector2i(2, 4), Vector2i(34, 46)],
	Tiles.Block.YOUNG_ACACIA: [Vector2i(2, 4), Vector2i(22, 32)],
	Tiles.Block.YOUNG_SWAMP_OAK: [Vector2i(2, 4), Vector2i(26, 36)],
	# Fruit trees: small orchard trees, in blossom or bearing fruit (the
	# same trunk: BEARING), and young.
	Tiles.Block.APPLE_TREE: [Vector2i(4, 6), Vector2i(36, 46)],
	Tiles.Block.CHERRY_TREE: [Vector2i(4, 6), Vector2i(38, 50)],
	Tiles.Block.ORANGE_TREE: [Vector2i(4, 6), Vector2i(34, 44)],
	Tiles.Block.APPLE_TREE_FRUIT: [Vector2i(4, 6), Vector2i(36, 46)],
	Tiles.Block.CHERRY_TREE_FRUIT: [Vector2i(4, 6), Vector2i(38, 50)],
	Tiles.Block.ORANGE_TREE_FRUIT: [Vector2i(4, 6), Vector2i(34, 44)],
	Tiles.Block.YOUNG_APPLE_TREE: [Vector2i(2, 4), Vector2i(22, 30)],
	Tiles.Block.YOUNG_CHERRY_TREE: [Vector2i(2, 4), Vector2i(22, 30)],
	Tiles.Block.YOUNG_ORANGE_TREE: [Vector2i(2, 4), Vector2i(22, 30)],
}
## A fruit tree bearing fruit and the same tree in blossom: one shape (its
## trunk and its model's crown) for both.
const BEARING := {
	Tiles.Block.APPLE_TREE_FRUIT: Tiles.Block.APPLE_TREE,
	Tiles.Block.CHERRY_TREE_FRUIT: Tiles.Block.CHERRY_TREE,
	Tiles.Block.ORANGE_TREE_FRUIT: Tiles.Block.ORANGE_TREE,
}
## Other solid objects: the size of the square they block (voxels) and how
## many levels up.
const SOLIDS := {
	Tiles.Block.ROCK: [10, 1],
	Tiles.Block.MOSSY_ROCK: [10, 1],
	Tiles.Block.CACTUS: [8, 2],
	Tiles.Block.BIG_MUSHROOM: [8, 3],
}
## The ways an object placed facing the player can face, in the order of
## the blocks of each kind in FACING_KINDS.
const WAYS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0)]
## Objects placed facing the player: each kind (its first block, whose
## model the others share) and its block for each of the WAYS. The
## workbench's and the big gate's are their left end seen from their
## front; furnaces come unlit and lit, and a food furnace that melted ore
## is broken; gates come closed and open; what hangs on a wall faces away
## from it.
const FACING_KINDS := {
	Tiles.Block.WORKBENCH:
	[
		Tiles.Block.WORKBENCH,
		Tiles.Block.WORKBENCH_WEST,
		Tiles.Block.WORKBENCH_NORTH,
		Tiles.Block.WORKBENCH_EAST,
	],
	Tiles.Block.CHEST:
	[
		Tiles.Block.CHEST,
		Tiles.Block.CHEST_WEST,
		Tiles.Block.CHEST_NORTH,
		Tiles.Block.CHEST_EAST,
	],
	Tiles.Block.FOOD_FURNACE:
	[
		Tiles.Block.FOOD_FURNACE,
		Tiles.Block.FOOD_FURNACE_WEST,
		Tiles.Block.FOOD_FURNACE_NORTH,
		Tiles.Block.FOOD_FURNACE_EAST,
	],
	Tiles.Block.FOOD_FURNACE_LIT:
	[
		Tiles.Block.FOOD_FURNACE_LIT,
		Tiles.Block.FOOD_FURNACE_LIT_WEST,
		Tiles.Block.FOOD_FURNACE_LIT_NORTH,
		Tiles.Block.FOOD_FURNACE_LIT_EAST,
	],
	Tiles.Block.FACTORY_FURNACE:
	[
		Tiles.Block.FACTORY_FURNACE,
		Tiles.Block.FACTORY_FURNACE_WEST,
		Tiles.Block.FACTORY_FURNACE_NORTH,
		Tiles.Block.FACTORY_FURNACE_EAST,
	],
	Tiles.Block.FACTORY_FURNACE_LIT:
	[
		Tiles.Block.FACTORY_FURNACE_LIT,
		Tiles.Block.FACTORY_FURNACE_LIT_WEST,
		Tiles.Block.FACTORY_FURNACE_LIT_NORTH,
		Tiles.Block.FACTORY_FURNACE_LIT_EAST,
	],
	Tiles.Block.BROKEN_FURNACE:
	[
		Tiles.Block.BROKEN_FURNACE,
		Tiles.Block.BROKEN_FURNACE_WEST,
		Tiles.Block.BROKEN_FURNACE_NORTH,
		Tiles.Block.BROKEN_FURNACE_EAST,
	],
	Tiles.Block.TORCH_BRACKET:
	[
		Tiles.Block.TORCH_BRACKET,
		Tiles.Block.TORCH_BRACKET_WEST,
		Tiles.Block.TORCH_BRACKET_NORTH,
		Tiles.Block.TORCH_BRACKET_EAST,
	],
	Tiles.Block.CURTAINS:
	[
		Tiles.Block.CURTAINS,
		Tiles.Block.CURTAINS_WEST,
		Tiles.Block.CURTAINS_NORTH,
		Tiles.Block.CURTAINS_EAST,
	],
	Tiles.Block.GLASS_PANE:
	[
		Tiles.Block.GLASS_PANE,
		Tiles.Block.GLASS_PANE_WEST,
		Tiles.Block.GLASS_PANE_NORTH,
		Tiles.Block.GLASS_PANE_EAST,
	],
	Tiles.Block.SINK:
	[
		Tiles.Block.SINK,
		Tiles.Block.SINK_WEST,
		Tiles.Block.SINK_NORTH,
		Tiles.Block.SINK_EAST,
	],
	Tiles.Block.TOILET:
	[
		Tiles.Block.TOILET,
		Tiles.Block.TOILET_WEST,
		Tiles.Block.TOILET_NORTH,
		Tiles.Block.TOILET_EAST,
	],
	Tiles.Block.CHAIR:
	[
		Tiles.Block.CHAIR,
		Tiles.Block.CHAIR_WEST,
		Tiles.Block.CHAIR_NORTH,
		Tiles.Block.CHAIR_EAST,
	],
	Tiles.Block.GATE:
	[
		Tiles.Block.GATE,
		Tiles.Block.GATE_WEST,
		Tiles.Block.GATE_NORTH,
		Tiles.Block.GATE_EAST,
	],
	Tiles.Block.GATE_OPEN:
	[
		Tiles.Block.GATE_OPEN,
		Tiles.Block.GATE_OPEN_WEST,
		Tiles.Block.GATE_OPEN_NORTH,
		Tiles.Block.GATE_OPEN_EAST,
	],
	Tiles.Block.BIG_GATE:
	[
		Tiles.Block.BIG_GATE,
		Tiles.Block.BIG_GATE_WEST,
		Tiles.Block.BIG_GATE_NORTH,
		Tiles.Block.BIG_GATE_EAST,
	],
	Tiles.Block.BIG_GATE_OPEN:
	[
		Tiles.Block.BIG_GATE_OPEN,
		Tiles.Block.BIG_GATE_OPEN_WEST,
		Tiles.Block.BIG_GATE_OPEN_NORTH,
		Tiles.Block.BIG_GATE_OPEN_EAST,
	],
	Tiles.Block.TORCH_BRACKET_LIT:
	[
		Tiles.Block.TORCH_BRACKET_LIT,
		Tiles.Block.TORCH_BRACKET_LIT_WEST,
		Tiles.Block.TORCH_BRACKET_LIT_NORTH,
		Tiles.Block.TORCH_BRACKET_LIT_EAST,
	],
	Tiles.Block.LANTERN_WALL:
	[
		Tiles.Block.LANTERN_WALL,
		Tiles.Block.LANTERN_WALL_WEST,
		Tiles.Block.LANTERN_WALL_NORTH,
		Tiles.Block.LANTERN_WALL_EAST,
	],
}
## Objects two tiles long: their kind (in FACING_KINDS: their left end,
## which holds the model) and the block of their right end, lying beside
## it, per axis it lies along (x, z). How deep (voxels) their body is across.
const WIDE_KINDS := {
	Tiles.Block.WORKBENCH: [Tiles.Block.WORKBENCH_END_X, Tiles.Block.WORKBENCH_END_Z],
	Tiles.Block.BIG_GATE: [Tiles.Block.BIG_GATE_END_X, Tiles.Block.BIG_GATE_END_Z],
	Tiles.Block.BIG_GATE_OPEN: [Tiles.Block.BIG_GATE_OPEN_END_X, Tiles.Block.BIG_GATE_OPEN_END_Z],
}
const WIDE_DEPTH := {Tiles.Block.WORKBENCH: 14, Tiles.Block.BIG_GATE: 6}
const BENCH_DEPTH := 14
## Chests and furnaces: so many voxels square, a level high.
const BOX_SIZE := 14
## Furniture bodies stand on (jumping onto it), by kind: how high its top
## is (voxels: their models' tops, WorkbenchModel, ChestModel,
## FurnaceModels, DecorModels). It blocks bodies up to there.
const TOPS := {
	Tiles.Block.WORKBENCH: 15,
	Tiles.Block.CHEST: 13,
	Tiles.Block.FOOD_FURNACE: 14,
	Tiles.Block.FOOD_FURNACE_LIT: 14,
	Tiles.Block.FACTORY_FURNACE: 14,
	Tiles.Block.FACTORY_FURNACE_LIT: 14,
	Tiles.Block.BROKEN_FURNACE: 14,
	Tiles.Block.SINK: 12,
	Tiles.Block.TOILET: 8,
	Tiles.Block.TABLE: 14,
	Tiles.Block.CHAIR: 10,
	Tiles.Block.COMPOSTER: 14,
	Tiles.Block.PUMPKIN: 12,
	Tiles.Block.MELON: 11,
}
## Other solid things players place, by kind: the square they block
## (voxels; the others facing them: BOX_SIZE).
const FOOTPRINTS := {
	Tiles.Block.GLASS_PANE: 16,
	Tiles.Block.TOILET: 10,
	Tiles.Block.TABLE: 14,
	Tiles.Block.CHAIR: 12,
	Tiles.Block.FENCE: 16,
	Tiles.Block.GATE: 16,
	Tiles.Block.CAMPFIRE: 12,
	Tiles.Block.COMPOSTER: 14,
	Tiles.Block.PUMPKIN: 14,
	Tiles.Block.MELON: 14,
}
## What keeps bodies out (fences, closed gates): two levels high, nobody
## jumps over.
const BARRIERS := {Tiles.Block.FENCE: true, Tiles.Block.GATE: true, Tiles.Block.BIG_GATE: true}
## The furnaces (their unlit kind) and their lit kind.
const LIT := {
	Tiles.Block.FOOD_FURNACE: Tiles.Block.FOOD_FURNACE_LIT,
	Tiles.Block.FACTORY_FURNACE: Tiles.Block.FACTORY_FURNACE_LIT,
}
## Gates (their closed kind) and their open kind: they swing open and shut
## when used (open, bodies go through).
const OPENS := {
	Tiles.Block.GATE: Tiles.Block.GATE_OPEN,
	Tiles.Block.BIG_GATE: Tiles.Block.BIG_GATE_OPEN,
}
## What hangs on the side of a cube (by kind), facing away from it: it
## falls with it.
const WALL_MOUNTED := {
	Tiles.Block.TORCH_BRACKET: true,
	Tiles.Block.TORCH_BRACKET_LIT: true,
	Tiles.Block.CURTAINS: true,
	Tiles.Block.LANTERN_WALL: true,
}
## What hangs from the cube above it (it falls with it, not with the
## floor).
const HANGING := {Tiles.Block.LANTERN_HANGING: true}
## What burns and lights its surroundings (ChunkMesher's lights), and keeps
## monsters away (Light.near_fire); a lit furnace too (LIT).
const LIGHTS := {
	Tiles.Block.TORCH: true,
	Tiles.Block.TORCH_BRACKET_LIT: true,
	Tiles.Block.LANTERN: true,
	Tiles.Block.LANTERN_HANGING: true,
	Tiles.Block.LANTERN_WALL: true,
	Tiles.Block.CAMPFIRE: true,
}
## Other shapes of one thing (a lantern hung from a ceiling or a wall): the
## kind it is placed as, the item's.
const SHAPE_OF := {
	Tiles.Block.LANTERN_HANGING: Tiles.Block.LANTERN,
	Tiles.Block.LANTERN_WALL: Tiles.Block.LANTERN,
}
## The stages of one thing (a composter filling up): its kind (base_kind),
## each with a model of its own.
const STAGE_OF := {
	Tiles.Block.COMPOSTER_1: Tiles.Block.COMPOSTER,
	Tiles.Block.COMPOSTER_2: Tiles.Block.COMPOSTER,
	Tiles.Block.COMPOSTER_3: Tiles.Block.COMPOSTER,
	Tiles.Block.COMPOSTER_4: Tiles.Block.COMPOSTER,
	Tiles.Block.COMPOSTER_5: Tiles.Block.COMPOSTER,
	Tiles.Block.COMPOSTER_6: Tiles.Block.COMPOSTER,
	Tiles.Block.COMPOSTER_FULL: Tiles.Block.COMPOSTER,
	Tiles.Block.COMPOSTER_READY: Tiles.Block.COMPOSTER,
}
## Fences join their neighbors (fences, gates and cubes): their version is
## the sides they join (FENCE_SIDES bits, 16 versions), not their tile's.
const FENCE_SIDES: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)
]
const FENCE_VARIANTS := 16
## Objects with a single version (no random ones).
const SINGLE := {
	Tiles.Block.TABLE: true,
	Tiles.Block.CAMPFIRE: true,
	Tiles.Block.TORCH: true,
	Tiles.Block.LANTERN: true,
	Tiles.Block.LANTERN_HANGING: true,
	Tiles.Block.COMPOSTER: true,
	Tiles.Block.TRELLIS: true,
}
## Small things stand anywhere in their tile (whole voxels), not centered.
const WANDERING := {
	Tiles.Block.TALL_GRASS: true,
	Tiles.Block.FERN: true,
	Tiles.Block.DEAD_BUSH: true,
	Tiles.Block.FLOWER_RED: true,
	Tiles.Block.FLOWER_YELLOW: true,
	Tiles.Block.FLOWER_BLUE: true,
	Tiles.Block.FLOWER_WHITE: true,
	Tiles.Block.FLOWER_PINK: true,
	Tiles.Block.MUSHROOM_RED: true,
	Tiles.Block.MUSHROOM_BROWN: true,
	Tiles.Block.LILY_PAD: true,
	Tiles.Block.ROCK: true,
	Tiles.Block.MOSSY_ROCK: true,
	Tiles.Block.WILD_BEETROOT: true,
	Tiles.Block.WILD_CABBAGE: true,
	Tiles.Block.WILD_CORN: true,
	Tiles.Block.WILD_TOMATO: true,
	Tiles.Block.WILD_STRAWBERRY: true,
	Tiles.Block.WILD_FLAX: true,
	Tiles.Block.WILD_RICE: true,
}

## block -> (kind, way index), for the facing objects; a wide object's
## right end -> [axis it lies along, kind].
static var _facing := _build_facing()
static var _wide_ends := _build_wide_ends()


static func is_tree(block: int) -> bool:
	return TREES.has(block)


static func variant_count(block: int) -> int:
	if _facing.has(block) or _wide_ends.has(block) or SINGLE.has(base_kind(block)):
		return 1
	if block == Tiles.Block.FENCE:
		return FENCE_VARIANTS
	return TREE_VARIANTS if TREES.has(block) else VARIANTS


## The kind of a facing object (see FACING_KINDS; -1: not one).
static func kind_of(block: int) -> int:
	return _facing[block].x if _facing.has(block) else -1


## The kind of anything placed: a facing object's, a wide object's (either
## end), a composter's however full, else the block itself.
static func base_kind(block: int) -> int:
	if _facing.has(block):
		return _facing[block].x
	if _wide_ends.has(block):
		return _wide_ends[block][1]
	return STAGE_OF.get(block, block)


## The kind of a wide object, either end (-1: not one).
static func wide_kind(block: int) -> int:
	var kind := base_kind(block)
	return kind if WIDE_KINDS.has(kind) else -1


## A wide object's left end (the block holding its model).
static func is_wide_left(block: int) -> bool:
	return WIDE_KINDS.has(kind_of(block))


static func is_wide_end(block: int) -> bool:
	return _wide_ends.has(block)


## The axis a wide object's right end lies along from its left end.
static func end_axis(block: int) -> Vector2i:
	return _wide_ends[block][0] if _wide_ends.has(block) else Vector2i.ZERO


## A part of a workbench (either end).
static func is_bench(block: int) -> bool:
	return wide_kind(block) == Tiles.Block.WORKBENCH


## A workbench's left end (the block holding its model).
static func is_bench_left(block: int) -> bool:
	return kind_of(block) == Tiles.Block.WORKBENCH


## A chest, whichever way it faces.
static func is_chest(block: int) -> bool:
	return kind_of(block) == Tiles.Block.CHEST


## A furnace that works, lit or not (its unlit kind; -1: not one).
static func furnace_kind(block: int) -> int:
	var kind := kind_of(block)
	for unlit: int in LIT:
		if kind == unlit or kind == LIT[unlit]:
			return unlit
	return -1


## Something burning: a lit furnace, a campfire, a torch, a lantern (see
## LIGHTS).
static func is_lit(block: int) -> bool:
	if LIGHTS.has(base_kind(block)):
		return true
	return _facing.has(block) and kind_of(block) in LIT.values()


## Hung from the cube above (see HANGING).
static func is_hanging(block: int) -> bool:
	return HANGING.has(block)


## A gate, open or shut, any part of it.
static func is_gate(block: int) -> bool:
	var kind := base_kind(block)
	return OPENS.has(kind) or OPENS.values().has(kind)


static func is_open(block: int) -> bool:
	return OPENS.values().has(base_kind(block))


## The gate's block once it swung (open <-> shut), the same way facing
## (or the same end).
static func swung(block: int) -> int:
	var kind := base_kind(block)
	var other: int = OPENS.get(kind, OPENS.find_key(kind))
	if _wide_ends.has(block):
		return wide_end(other, end_axis(block))
	return facing(other, front_of(block))


## Hung on the side of a cube (see WALL_MOUNTED).
static func is_wall_mounted(block: int) -> bool:
	return WALL_MOUNTED.has(kind_of(block))


## Whether a fence joins a neighbor voxel: a fence, a gate or a cube.
static func fence_joins(voxel: int) -> bool:
	if Voxels.is_cube(voxel):
		return true
	var block := Voxels.block_of(voxel)
	return block == Tiles.Block.FENCE or is_gate(block)


## The block whose model a block shows: the ways a facing object faces
## share one; -1 for the blocks showing none (a wide object's right end).
static func model_block(block: int) -> int:
	if _wide_ends.has(block):
		return -1
	return kind_of(block) if _facing.has(block) else block


## Which way a facing object faces (ZERO: not one).
static func front_of(block: int) -> Vector2i:
	return WAYS[_facing[block].y] if _facing.has(block) else Vector2i.ZERO


## The block of a facing object (`kind`: see FACING_KINDS) facing `front`
## (a unit step on the ground).
static func facing(kind: int, front: Vector2i) -> int:
	return FACING_KINDS[kind][maxi(WAYS.find(front), 0)]


## How a facing object turns its model (made facing +z), radians about the
## vertical.
static func turn_of(block: int) -> float:
	var front := front_of(block)
	return atan2(front.x, front.y)


## How high (levels) the top of a piece of furniture is, to stand on it
## (0: not something to stand on).
static func stand_height(block: int) -> float:
	return TOPS.get(base_kind(block), 0) / float(GameConst.TILE_SIZE)


## How high (levels) an object blocks bodies from its voxel up: furniture
## up to its top, the others whole levels (blocking_levels).
static func blocking_height(block: int, variant: int) -> float:
	var top := stand_height(block)
	return top if top > 0.0 else float(blocking_levels(block, variant))


## Where a wide object's right end lies from its left end (on its right,
## seen from its front).
static func wide_right(block: int) -> Vector2i:
	var front := front_of(block)
	return Vector2i(front.y, -front.x)


## The block of a wide object's right end (`kind`: its left end's) lying
## `right` of its left end.
static func wide_end(kind: int, right: Vector2i) -> int:
	return WIDE_KINDS[kind][0 if right.x != 0 else 1]


## Version of an object standing on a tile.
static func variant_at(block: int, tile: Vector2i) -> int:
	return HashUtil.hash2(SALT, tile.x, tile.y) % variant_count(block)


## Where an object stands in its tile (voxels from the center).
static func offset_at(block: int, tile: Vector2i) -> Vector2i:
	if not WANDERING.has(block):
		return Vector2i.ZERO
	var h := HashUtil.hash2(SALT, tile.x, tile.y)
	return Vector2i((h >> 8) % 7 - 3, (h >> 12) % 7 - 3)


## Trunk of a tree version: width and height (voxels). The versions spread
## over the whole range, in a shuffled order: every tree differs from its
## neighbors.
static func trunk(block: int, variant: int) -> Vector2i:
	block = BEARING.get(block, block)
	var ranges: Array = TREES[block]
	var widths: Vector2i = ranges[0]
	var heights: Vector2i = ranges[1]
	var a := HashUtil.unit2(SIZE_SALT, block, variant)
	var b := (variant + HashUtil.unit2(SIZE_SALT + 1, block, variant)) / TREE_VARIANTS
	var width := roundi(lerpf(widths.x, widths.y, a) / 2.0) * 2
	return Vector2i(width, roundi(lerpf(heights.x, heights.y, b)))


## Size of the square an object blocks at its foot (voxels; 0: bodies walk
## through it).
static func footprint(block: int, variant: int) -> int:
	if not Tiles.is_block_solid(block):
		return 0
	var kind := base_kind(block)
	if FOOTPRINTS.has(kind):
		return FOOTPRINTS[kind]
	if _facing.has(block) and not is_wide_left(block):
		return BOX_SIZE
	if TREES.has(block):
		return trunk(block, variant).x
	if SOLIDS.has(block):
		return SOLIDS[block][0]
	return 0


## Levels an object blocks, from its voxel up.
static func blocking_levels(block: int, variant: int) -> int:
	var kind := base_kind(block)
	if BARRIERS.has(kind):
		return 2
	if _facing.has(block) or _wide_ends.has(block) or FOOTPRINTS.has(kind):
		return 1
	if TREES.has(block):
		return ceili(trunk(block, variant).y / float(GameConst.TILE_SIZE))
	if SOLIDS.has(block):
		return SOLIDS[block][1]
	return 0


## The box (world pixels) an object standing on a tile blocks (empty if it
## blocks nothing).
static func footprint_rect(block: int, tile: Vector2i) -> Rect2:
	if not Tiles.is_block_solid(block):
		return Rect2()
	var kind := wide_kind(block)
	if kind != -1:
		# Its whole tile along it, its depth across.
		var along := end_axis(block) if is_wide_end(block) else wide_right(block).abs()
		var depth: int = WIDE_DEPTH.get(kind, BENCH_DEPTH)
		var box := Vector2(along) * GameConst.TILE_SIZE + Vector2(Vector2i.ONE - along) * depth
		return Rect2(Coords.tile_to_world_center(tile) - box * 0.5, box)
	var size := footprint(block, variant_at(block, tile))
	if size == 0:
		return Rect2()
	var center := Coords.tile_to_world_center(tile) + Vector2(offset_at(block, tile))
	return Rect2(center - Vector2.ONE * size * 0.5, Vector2.ONE * size)


static func _build_facing() -> Dictionary:
	var lookup := {}
	for kind: int in FACING_KINDS:
		var blocks: Array = FACING_KINDS[kind]
		for way in blocks.size():
			lookup[blocks[way]] = Vector2i(kind, way)
	return lookup


static func _build_wide_ends() -> Dictionary:
	var lookup := {}
	for kind: int in WIDE_KINDS:
		var ends: Array = WIDE_KINDS[kind]
		lookup[ends[0]] = [Vector2i(1, 0), kind]
		lookup[ends[1]] = [Vector2i(0, 1), kind]
	return lookup
