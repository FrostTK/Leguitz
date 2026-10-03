class_name SaplingModels
extends RefCounted
## Saplings (Growth): a little stem of their species' bark and a few tufts
## of its leaves; a spruce's is a tiny cone, an acacia's a flat tuft, a
## jungle tree's has broad leaves, a swamp oak's a strand of moss. Their
## items look the same (a fruit tree's item is its pips: CropModels).

const SPECIES := {
	Tiles.Block.OAK_SAPLING: [TreeModels.OAK_BARK, TreeModels.OAK_LEAVES],
	Tiles.Block.BIRCH_SAPLING: [TreeModels.BIRCH_BARK, TreeModels.BIRCH_LEAVES],
	Tiles.Block.SPRUCE_SAPLING: [TreeModels.SPRUCE_BARK, TreeModels.SPRUCE_LEAVES],
	Tiles.Block.DARK_OAK_SAPLING: [TreeModels.DARK_BARK, TreeModels.DARK_LEAVES],
	Tiles.Block.JUNGLE_SAPLING: [TreeModels.JUNGLE_BARK, TreeModels.JUNGLE_LEAVES],
	Tiles.Block.ACACIA_SAPLING: [TreeModels.ACACIA_BARK, TreeModels.ACACIA_LEAVES],
	Tiles.Block.SWAMP_OAK_SAPLING: [TreeModels.SWAMP_BARK, TreeModels.SWAMP_LEAVES],
	Tiles.Block.APPLE_SAPLING: [OrchardColors.APPLE_BARK, OrchardColors.APPLE_LEAVES],
	Tiles.Block.CHERRY_SAPLING: [OrchardColors.CHERRY_BARK, OrchardColors.CHERRY_LEAVES],
	Tiles.Block.ORANGE_SAPLING: [OrchardColors.ORANGE_BARK, OrchardColors.ORANGE_LEAVES],
	Tiles.Block.PEACH_SAPLING: [OrchardColors.PEACH_BARK, OrchardColors.PEACH_LEAVES],
}
const SIZE := Vector3i(15, 16, 15)
const MIDDLE := Vector3(7, 0, 7)


static func build(block: int, variant: int) -> VoxelGrid:
	var rng := RandomNumberGenerator.new()
	rng.seed = HashUtil.hash2(0x5A91, block, variant)
	var colors: Array = SPECIES[block]
	var bark: Array = colors[0]
	var leaves: Array = colors[1]
	var grid := VoxelGrid.new(SIZE)
	match block:
		Tiles.Block.SPRUCE_SAPLING:
			_cone(grid, rng, bark, leaves)
		Tiles.Block.ACACIA_SAPLING:
			_flat(grid, rng, bark, leaves)
		Tiles.Block.JUNGLE_SAPLING:
			_broad(grid, rng, bark, leaves)
		_:
			_tufts(grid, rng, bark, leaves, block == Tiles.Block.DARK_OAK_SAPLING)
	if block == Tiles.Block.SWAMP_OAK_SAPLING:
		var tip := MIDDLE + Vector3(2, 7, 0)
		var moss := _leaf(TreeModels.HANGING_MOSS[1])
		grid.line(tip, tip - Vector3(0, 3, 0), 0.0, moss)
	grid.sway = 0.5
	grid.sway_from = 2
	return grid


## The model of a sapling item (its block's first version).
static func item(item_id: int) -> VoxelGrid:
	var block: int = Items.PLACES_BLOCK.get(item_id, Tiles.Block.AIR)
	return build(block, 0) if SPECIES.has(block) else null


## A stem with a twig or two, leaves in small round tufts.
static func _tufts(
	grid: VoxelGrid, rng: RandomNumberGenerator, bark: Array, leaves: Array, thick: bool
) -> void:
	var height := rng.randi_range(8, 10)
	var stem := _wood(bark[2])
	grid.line(MIDDLE, MIDDLE + Vector3(rng.randf_range(-0.8, 0.8), height, 0), 0.0, stem)
	if thick:
		grid.line(MIDDLE + Vector3(1, 0, 0), MIDDLE + Vector3(1, height - 3, 0), 0.0, stem)
	var top := MIDDLE + Vector3(0, height, 0)
	_tuft(grid, top + Vector3(0, 1, 0), 2.6, leaves, rng)
	for i in rng.randi_range(2, 3):
		var angle := TAU * (i + rng.randf_range(-0.2, 0.2)) / 3.0
		var start := MIDDLE + Vector3(0, rng.randi_range(4, height - 2), 0)
		var tip := start + Vector3(cos(angle) * 3.5, rng.randf_range(1.5, 3.0), sin(angle) * 3.5)
		grid.line(start, tip, 0.0, _wood(bark[1]))
		_tuft(grid, tip, rng.randf_range(1.4, 2.0), leaves, rng)


## A little spruce: tiers of needles narrowing up the stem.
static func _cone(grid: VoxelGrid, rng: RandomNumberGenerator, bark: Array, leaves: Array) -> void:
	var height := rng.randi_range(11, 13)
	grid.line(MIDDLE, MIDDLE + Vector3(0, height, 0), 0.0, _wood(bark[2]))
	var y := 3
	while y < height:
		var radius := lerpf(4.2, 1.2, float(y - 3) / (height - 3))
		var shade := 1 + (y % 3)
		grid.disc(Vector2(MIDDLE.x, MIDDLE.z), radius, y, _leaf(leaves[mini(shade, 4)]))
		grid.disc(
			Vector2(MIDDLE.x, MIDDLE.z), radius - 1.2, y + 1, _leaf(leaves[mini(shade + 1, 4)])
		)
		y += 3
	grid.set_voxel(Vector3i(MIDDLE) + Vector3i(0, height + 1, 0), _leaf(leaves[4]))


## A leaning stem under a flat tuft (an acacia's crown).
static func _flat(grid: VoxelGrid, rng: RandomNumberGenerator, bark: Array, leaves: Array) -> void:
	var height := rng.randi_range(8, 10)
	var top := MIDDLE + Vector3(rng.randf_range(-2.0, 2.0), height, rng.randf_range(-1.5, 1.5))
	grid.line(MIDDLE, top, 0.0, _wood(bark[2]))
	grid.disc(Vector2(top.x, top.z), 3.6, int(top.y), _leaf(leaves[2]))
	grid.disc(Vector2(top.x, top.z), 2.6, int(top.y) + 1, _leaf(leaves[3]))
	grid.set_voxel(Vector3i(top) + Vector3i(1, 2, 0), _leaf(leaves[4]))


## A stem with a few broad leaves hanging out (a jungle tree's).
static func _broad(grid: VoxelGrid, rng: RandomNumberGenerator, bark: Array, leaves: Array) -> void:
	var height := rng.randi_range(9, 11)
	grid.line(MIDDLE, MIDDLE + Vector3(0, height, 0), 0.0, _wood(bark[2]))
	for i in 4:
		var angle := TAU * (i + rng.randf_range(-0.15, 0.15)) / 4.0
		var out := Vector3(cos(angle), 0, sin(angle))
		var start := MIDDLE + Vector3(0, height - (i % 2) * 3, 0)
		for t in range(1, 6):
			var spot := start + out * t + Vector3(0, -0.12 * t * t + 0.6 * t, 0)
			var side := Vector3(-out.z, 0, out.x)
			var width := 1.0 if t in [2, 3, 4] else 0.0
			grid.line(spot - side * width, spot + side * width, 0.0, _leaf(leaves[2 + t % 2]))
	grid.set_voxel(Vector3i(MIDDLE) + Vector3i(0, height + 1, 0), _leaf(leaves[4]))


static func _tuft(
	grid: VoxelGrid, center: Vector3, radius: float, leaves: Array, rng: RandomNumberGenerator
) -> void:
	grid.ellipsoid(center, Vector3(radius, radius * 0.8, radius), _leaf(leaves[2]))
	# Lighter on top, a little darker below.
	grid.ellipsoid(
		center + Vector3(0, 0.8, 0), Vector3(radius * 0.6, 0.6, radius * 0.6), _leaf(leaves[4])
	)
	var spot := center + Vector3(rng.randf_range(-1, 1), -radius * 0.6, rng.randf_range(-1, 1))
	grid.set_voxel(Vector3i(spot.round()), _leaf(leaves[1]))


static func _wood(hex: String) -> int:
	return VoxelGrid.voxel(Color(hex))


static func _leaf(hex: String) -> int:
	return VoxelGrid.voxel(Color(hex), VoxelGrid.Kind.FOLIAGE)
