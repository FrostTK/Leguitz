class_name BlockColors
extends RefCounted
## The main color of each voxel, for the bits flying off it: the average of
## its top in the terrain atlases; objects from their models' palettes.

const TREE_COLORS := {
	Tiles.Block.OAK: [TreeModels.OAK_BARK, TreeModels.OAK_LEAVES],
	Tiles.Block.BIRCH: [TreeModels.BIRCH_BARK, TreeModels.BIRCH_LEAVES],
	Tiles.Block.DARK_OAK: [TreeModels.DARK_BARK, TreeModels.DARK_LEAVES],
	Tiles.Block.JUNGLE_TREE: [TreeModels.JUNGLE_BARK, TreeModels.JUNGLE_LEAVES],
	Tiles.Block.SWAMP_OAK: [TreeModels.SWAMP_BARK, TreeModels.SWAMP_LEAVES],
	Tiles.Block.ACACIA: [TreeModels.ACACIA_BARK, TreeModels.ACACIA_LEAVES],
	Tiles.Block.SPRUCE: [TreeModels.SPRUCE_BARK, TreeModels.SPRUCE_LEAVES],
	Tiles.Block.SNOWY_SPRUCE: [TreeModels.SPRUCE_BARK, TreeModels.SPRUCE_LEAVES],
}
const OBJECT_COLORS := {
	Tiles.Block.ROCK: Color(0.5, 0.5, 0.53),
	Tiles.Block.MOSSY_ROCK: Color(0.42, 0.5, 0.38),
	Tiles.Block.CACTUS: Color(0.33, 0.6, 0.27),
	Tiles.Block.BIG_MUSHROOM: Color(0.62, 0.32, 0.26),
	Tiles.Block.DEAD_BUSH: Color(0.5, 0.38, 0.24),
	Tiles.Block.FLOWER_RED: Color(0.8, 0.22, 0.2),
	Tiles.Block.FLOWER_YELLOW: Color(0.92, 0.8, 0.25),
	Tiles.Block.FLOWER_BLUE: Color(0.32, 0.45, 0.85),
	Tiles.Block.FLOWER_WHITE: Color(0.92, 0.92, 0.9),
	Tiles.Block.FLOWER_PINK: Color(0.9, 0.5, 0.7),
	Tiles.Block.MUSHROOM_RED: Color(0.75, 0.2, 0.18),
	Tiles.Block.MUSHROOM_BROWN: Color(0.55, 0.38, 0.25),
}
const PLANT_COLOR := Color(0.32, 0.58, 0.24)

static var _cache: Dictionary[int, Color] = {}


static func of(voxel: int) -> Color:
	if not _cache.has(voxel):
		_cache[voxel] = _compute(voxel)
	return _cache[voxel]


## The leaves of a tree (for the burst when it falls).
static func leaves_of(block: int) -> Color:
	var palettes: Array = TREE_COLORS.get(block, [])
	return Color(palettes[1][2]) if not palettes.is_empty() else PLANT_COLOR


static func _compute(voxel: int) -> Color:
	var block := Voxels.block_of(voxel)
	if block == Tiles.Block.AIR:
		return _average(TerrainRenderer.GROUND_ATLAS.get_image(), Voxels.ground_of(voxel))
	if TileAtlas.is_wall(block):
		return _average(TerrainRenderer.WALL_ATLAS.get_image(), TileAtlas.WALL_KINDS[block])
	if TREE_COLORS.has(block):
		return Color(TREE_COLORS[block][0][2])
	return OBJECT_COLORS.get(block, PLANT_COLOR)


## Average color of the first 16 x 16 cell of an atlas row.
static func _average(atlas: Image, row: int) -> Color:
	var sum := Color(0, 0, 0, 0)
	var count := 0
	for y in range(row * 16, mini(row * 16 + 16, atlas.get_height())):
		for x in 16:
			var pixel := atlas.get_pixel(x, y)
			if pixel.a > 0.5:
				sum += pixel
				count += 1
	return Color(sum.r / count, sum.g / count, sum.b / count) if count > 0 else Color.GRAY
