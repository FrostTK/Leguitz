class_name CropModels
extends RefCounted
## The crops of phase 7's step 4 in their stages (Farming.stage_of: 3 is
## ripe), the wild plants the first seeds come from, pumpkins and melons,
## the trellis, and their items. Field crops grow in rows across their tile
## (beetroot, cabbages, corn, tomatoes on stakes, strawberries, raspberry
## canes, flax, rice standing in the water); a pumpkin or melon stem creeps from the middle
## of its tile; grapes climb a trellis; sugar cane grows back
## (VoxelModels.sugar_cane).

const BEET_LEAF := ["#2c5e2c", "#3d7c36", "#55994a"]
const BEET_RED := ["#5e1630", "#86213f", "#a8304f"]
const CABBAGE_OUTER := ["#3a6e48", "#4f8a58", "#6aa46a"]
const CABBAGE_HEAD := ["#8cc28a", "#a9d6a0", "#c6e6b8"]
const CORN_GREEN := ["#3f7a2a", "#58993a", "#7cb84e"]
const CORN_GOLD := ["#d9a92e", "#efc744", "#f8de72"]
const ROASTED := ["#6a3a12", "#a8681e", "#d09a3a"]
const HUSK := ["#8aa04a", "#a9bc62", "#c8d482"]
const TASSEL := ["#b8b060", "#c8a860"]
const SILK := "#9a6a3a"
const STAKE := ["#7a5a34", "#9a7646"]
const TOMATO_LEAF := ["#2f6a2a", "#3f8a34", "#58a548"]
const TOMATO_GREEN := ["#5e9a32", "#7cb846"]
const TOMATO_RED := ["#a8201e", "#d8322a", "#ff6a4a"]
const STRAWBERRY_LEAF := ["#2e6a2e", "#43883c", "#62a650"]
const STRAWBERRY_RED := ["#a81a2a", "#d42a3a", "#ff5a6a"]
const RASPBERRY_CANE := ["#6a3e2e", "#8a5640"]
const RASPBERRY_LEAF := ["#2e5e2a", "#447a36", "#5e9646"]
const RASPBERRY_RED := ["#9a1440", "#d02c5a", "#f06a8c"]
const PETALS := ["#f6f2e6", "#f2d046"]
const FLAX_GREEN := ["#4f8a3a", "#6aa64a"]
const FLAX_BLUE := ["#4a6ad8", "#7a98f0"]
const FLAX_GOLD := ["#a8883a", "#c9a74a", "#e0c46a"]
const PUMPKIN_LEAF := ["#2e6428", "#447f34", "#5f9c44"]
const MELON_LEAF := ["#3a7a2e", "#52953c", "#74b052"]
const BLOOM := ["#e8b020", "#f8d040"]
const PUMPKIN := ["#b8500e", "#e0741e", "#f59530", "#ffb85a"]
const PUMPKIN_STALK := ["#4a4a22", "#6a6a30"]
const MELON := ["#24501a", "#3a7428", "#64a444", "#8ac460"]
const MELON_FLESH := ["#c8202c", "#ec4a4e", "#d8e8b0"]
const RICE_GREEN := ["#4f9a3a", "#6ab84a", "#8ad060"]
const RICE_GOLD := ["#b8923a", "#d9b85a", "#ecd27e"]
const WOOD := ["#6a4a2a", "#8a6a3e", "#a7834e"]
const GRAPE_LEAF := ["#2f6a26", "#45883a", "#62a44c"]
const GRAPE := ["#5a2e86", "#7e48b0", "#a678d8"]
const VINE_WOOD := ["#4a2e1a", "#6a442a"]
const LEAF_ITEM := ["#3f7a2a", "#5a9a3a"]
## How many plants a wild one shows (the others: one).
const WILD_COUNT := {
	Tiles.Block.WILD_BEETROOT: 3,
	Tiles.Block.WILD_CABBAGE: 2,
	Tiles.Block.WILD_CORN: 2,
	Tiles.Block.WILD_STRAWBERRY: 4,
	Tiles.Block.WILD_FLAX: 7,
	Tiles.Block.WILD_RICE: 3,
	Tiles.Block.WILD_RASPBERRY: 2,
}


static func build(block: int, variant: int) -> VoxelGrid:
	if block == Tiles.Block.SUGAR_CANE or Farming.sown_of(block) == Tiles.Block.SUGAR_CANE_0:
		return _cane(block, variant)
	var rng := RandomNumberGenerator.new()
	rng.seed = HashUtil.hash2(0xC309, block, variant)
	match block:
		Tiles.Block.PUMPKIN:
			return _pumpkin(rng)
		Tiles.Block.MELON:
			return _melon(rng)
		Tiles.Block.TRELLIS:
			var trellis := _grid(26)
			_trellis(trellis)
			return trellis
	if Farming.WILD.has(block):
		return _wild(block, rng)
	if not Farming.is_crop(block):
		return null
	var stage := Farming.stage_of(block)
	var kind := Farming.sown_of(block)
	var grid := _grid(28 if kind == Tiles.Block.CORN_0 else 26)
	match kind:
		Tiles.Block.BEETROOTS_0:
			for foot in _feet(rng, [3, 8, 13], 3):
				_beet(grid, rng, foot, stage)
		Tiles.Block.CABBAGES_0:
			for foot in _feet(rng, [4, 12], 2):
				_cabbage(grid, rng, foot, stage)
		Tiles.Block.CORN_0:
			for foot in _feet(rng, [4, 12], 3):
				_corn(grid, rng, foot, stage)
		Tiles.Block.TOMATOES_0:
			for foot in _feet(rng, [4, 12], 2):
				_tomato(grid, rng, foot, stage, true)
		Tiles.Block.STRAWBERRIES_0:
			for foot in _feet(rng, [3, 8, 13], 3):
				_strawberry(grid, rng, foot, stage)
		Tiles.Block.RASPBERRIES_0:
			for foot in _feet(rng, [4, 12], 3):
				_raspberry(grid, rng, foot, stage)
		Tiles.Block.FLAX_0:
			for foot in _feet(rng, [3, 8, 13], 5):
				_flax(grid, rng, foot, stage)
		Tiles.Block.RICE_0:
			for foot in _feet(rng, [3, 8, 13], 3):
				_rice(grid, rng, foot, stage)
		Tiles.Block.PUMPKIN_STEM_0:
			_stem(grid, rng, stage, PUMPKIN_LEAF, 1.8)
		Tiles.Block.MELON_STEM_0:
			_stem(grid, rng, stage, MELON_LEAF, 1.3)
		Tiles.Block.GRAPES_0:
			_trellis(grid)
			_vine(grid, rng, stage)
			grid.sway = 0.15
			grid.sway_from = 4
			return grid
	grid.sway = 0.7 if kind == Tiles.Block.CORN_0 else 0.6
	grid.sway_from = 1
	return grid


## The model of a crop's item (null for others).
static func item(item_id: int) -> VoxelGrid:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xC4 + item_id
	match item_id:
		Items.Id.BEETROOT:
			return _beetroot()
		Items.Id.BEETROOT_SEEDS:
			return _pips(rng, ["#6a2a2a", "#8a3a34"])
		Items.Id.CABBAGE:
			return _cabbage_head()
		Items.Id.CABBAGE_SEEDS:
			return _pips(rng, ["#3a2a22", "#5a4030"])
		Items.Id.CORN:
			return _cob(false)
		Items.Id.ROASTED_CORN:
			return _cob(true)
		Items.Id.TOMATO:
			return _fruit(TOMATO_RED, 3.4, TOMATO_LEAF[1])
		Items.Id.TOMATO_SEEDS:
			return _pips(rng, ["#c8b87a", "#efe2a8"])
		Items.Id.STRAWBERRY:
			return _strawberry_item()
		Items.Id.FLAX_SEEDS:
			return _pips(rng, ["#5a3a1e", "#8a5a2e"])
		Items.Id.FLAX:
			return _flax_bundle()
		Items.Id.LINEN:
			return _linen()
		Items.Id.PUMPKIN:
			return _pumpkin(rng)
		Items.Id.PUMPKIN_SEEDS:
			return _pips(rng, ["#d8c898", "#f6ecc8"])
		Items.Id.MELON_SEEDS:
			return _pips(rng, ["#1e1a18", "#3a302a"])
		Items.Id.MELON_SLICE:
			return _melon_slice()
		Items.Id.RICE:
			return _heap(rng, ["#e8dcc0", "#f6f0e0", "#c9a44a"])
		Items.Id.COOKED_RICE:
			return _cooked_rice(rng)
		Items.Id.SUGAR:
			return _heap(rng, ["#d4d4d8", "#ececf0", "#ffffff"])
		Items.Id.TRELLIS:
			var trellis := _grid(26)
			_trellis(trellis)
			return trellis
		Items.Id.GRAPE_SEEDS:
			return _pips(rng, ["#4a3020", "#6a4630"])
		Items.Id.GRAPES:
			return _bunch()
		Items.Id.APPLE:
			return _fruit(["#9a1218", "#d22a26", "#c8d84a"], 3.6, LEAF_ITEM[1])
		Items.Id.APPLE_SEEDS:
			return _pips(rng, ["#2e1a10", "#4a2c1a"])
		Items.Id.CHERRIES:
			return _cherries()
		Items.Id.CHERRY_PITS:
			return _pips(rng, ["#c9b08a", "#e0caa4"])
		Items.Id.ORANGE:
			return _fruit(OrchardColors.TREES[Tiles.Block.ORANGE_TREE][3], 3.8, LEAF_ITEM[0])
		Items.Id.ORANGE_SEEDS:
			return _pips(rng, ["#e0d2a8", "#f6eccc"])
		Items.Id.RASPBERRY:
			return _raspberry_item()
		Items.Id.PEACH:
			return _fruit(["#d8483a", "#f4a058", "#ffd28c"], 3.7, LEAF_ITEM[1])
		Items.Id.PEACH_PIT:
			return _pit()
	return null


# ---------------------------------------------------------------- crops


## A tile's grid, `height` voxels tall, standing on its middle.
static func _grid(height: int) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, height, 16))
	grid.pivot = Vector2(8, 8)
	return grid


## Where plants stand in rows across a tile: `rows` (z), `per_row` in each,
## shifted a voxel here and there.
static func _feet(rng: RandomNumberGenerator, rows: Array, per_row: int) -> Array[Vector3]:
	var feet: Array[Vector3] = []
	for z: int in rows:
		for i in per_row:
			var x := roundi((i + 0.5) * 16.0 / per_row) + rng.randi_range(-1, 0)
			feet.append(Vector3(x, 0, z + rng.randi_range(-1, 1)))
	return feet


## A blade `width` voxels wide from `from` to `to` (side by side, across).
static func _blade(grid: VoxelGrid, from: Vector3, to: Vector3, width: int, paint: int) -> void:
	var along := to - from
	var across := Vector3(-along.z, 0.0, along.x).normalized()
	for i in width:
		grid.line(from + across * i, to + across * i, 0.0, paint)


## Beetroot: broad leaves on red stalks; ripe, the dark red root shows at
## the ground.
static func _beet(grid: VoxelGrid, rng: RandomNumberGenerator, foot: Vector3, stage: int) -> void:
	var height: int = [2, 3, 5, 6][stage]
	var leaves := 3 if stage == 0 else 5
	for k in leaves:
		var angle := TAU * (k + rng.randf() * 0.5) / leaves
		var out := Vector3(cos(angle), 0.0, sin(angle)) * height * 0.45
		var tip := foot + out + Vector3(0, height, 0)
		var stalk := foot.lerp(tip, 0.35)
		grid.line(foot, stalk, 0.0, _leaf(BEET_RED[1]))
		_blade(grid, stalk, tip, 2 if stage >= 2 else 1, _leaf(BEET_LEAF[k % 3]))
	if stage == 3:
		var root := Vector3i(foot)
		grid.box(root, root + Vector3i(1, 0, 1), _solid(BEET_RED[1]))
		grid.set_voxel(root + Vector3i(0, 1, 0), _solid(BEET_RED[2]))
		grid.set_voxel(root + Vector3i(1, 0, 0), _solid(BEET_RED[0]))


## A cabbage: a rosette of outer leaves, then a pale head swelling in it.
static func _cabbage(
	grid: VoxelGrid, rng: RandomNumberGenerator, foot: Vector3, stage: int
) -> void:
	var spread: float = [1.2, 2.4, 3.2, 3.6][stage]
	grid.ellipsoid(
		foot + Vector3(0.5, 0.5, 0.5), Vector3(spread, 1.0, spread), _leaf(CABBAGE_OUTER[1])
	)
	for k in 6:
		var angle := TAU * (k + rng.randf() * 0.4) / 6.0
		var rim := foot + Vector3(0.5 + cos(angle) * spread, 1.2, 0.5 + sin(angle) * spread)
		grid.set_voxel(Vector3i(rim.floor()), _leaf(CABBAGE_OUTER[2 if k % 2 else 0]))
	if stage < 2:
		return
	var r := 1.6 if stage == 2 else 2.5
	var center := foot + Vector3(0.5, r * 0.85 + 0.8, 0.5)
	var top := center.y + r
	var head := func(p: Vector3i) -> int:
		var shade := 2 if p.y >= top - 1.2 else (1 if p.y >= center.y - 0.5 else 0)
		return _leaf(CABBAGE_HEAD[shade])
	grid.ellipsoid(center, Vector3(r, r * 0.85, r), head)


## Corn: a tall stalk, long blades arching off its nodes; a tassel on top
## and a cob in its husk, golden when ripe.
static func _corn(grid: VoxelGrid, rng: RandomNumberGenerator, foot: Vector3, stage: int) -> void:
	var height: int = [3, 9, 17, 24][stage] + rng.randi_range(-1, 0)
	grid.line(foot, foot + Vector3(0, height, 0), 0.0, _leaf(CORN_GREEN[1]))
	var angle := rng.randf() * TAU
	var y := 1
	while y < height - 2:
		angle += PI + rng.randf_range(-0.6, 0.6)
		var out := Vector3(cos(angle), 0.0, sin(angle))
		var length := 3.0 + stage * 1.2
		var node := foot + Vector3(0, y, 0)
		var bend := node + out * length * 0.5 + Vector3(0, 1.5, 0)
		var tip := node + out * length + Vector3(0, -0.5, 0)
		var color := _leaf(CORN_GREEN[(y / 4 + 2) % 3])
		grid.line(node, bend, 0.0, color)
		grid.line(bend, tip, 0.0, color)
		y += 4
	if stage < 2:
		return
	var top := foot + Vector3(0, height, 0)
	for k in 3:
		var spike := Vector3(rng.randf_range(-1.5, 1.5), 2.5, rng.randf_range(-1.5, 1.5))
		grid.line(top, top + spike, 0.0, _leaf(TASSEL[stage - 2]))
	var side := Vector3(1, 0, 0) if rng.randf() < 0.5 else Vector3(0, 0, 1)
	var cob := Vector3i((foot + side + Vector3(0, int(height * 0.45), 0)).floor())
	for k in 4:
		var ripe := stage == 3 and k in [1, 2]
		grid.set_voxel(
			cob + Vector3i(0, k, 0), _leaf(CORN_GOLD[k % 2 + 1] if ripe else HUSK[k % 2])
		)
	grid.set_voxel(cob + Vector3i(0, 4, 0), _leaf(SILK if stage == 3 else HUSK[2]))


## A tomato plant winding up its stake (`staked`; wild, it sprawls), leaves
## off the vine; green fruit, red when ripe.
static func _tomato(
	grid: VoxelGrid, rng: RandomNumberGenerator, foot: Vector3, stage: int, staked: bool
) -> void:
	var height: int = [3, 7, 11, 13][stage] - (0 if staked else 4)
	if staked and stage >= 1:
		grid.line(foot + Vector3(1, 0, 0), foot + Vector3(1, 14, 0), 0.0, _solid(STAKE[0]))
		grid.set_voxel(Vector3i(foot) + Vector3i(1, 14, 0), _solid(STAKE[1]))
	var spots: Array[Vector3] = []
	for y in height:
		var p := foot + Vector3(sin(y * 0.8) * 0.8, y, cos(y * 0.8) * 0.8)
		if not staked:
			p += Vector3(sin(y * 0.5) * y * 0.3, 0, 0)
		grid.set_voxel(Vector3i(p.round()), _leaf(TOMATO_LEAF[0]))
		if y % 2 == 1:
			var angle := rng.randf() * TAU
			var leaf := p + Vector3(cos(angle) * 1.6, 0.3, sin(angle) * 1.6)
			grid.ellipsoid(leaf, Vector3(1.3, 0.7, 1.3), _leaf(TOMATO_LEAF[1 + y % 4 / 2]))
			spots.append(p + Vector3(cos(angle + 2.5) * 1.7, -0.5, sin(angle + 2.5) * 1.7))
	if stage < 2:
		return
	for i in range(0, spots.size(), 2):
		var at := Vector3i(spots[i].round())
		var colors: Array = TOMATO_RED if stage == 3 else TOMATO_GREEN
		grid.set_voxel(at, _leaf(colors[1]))
		grid.set_voxel(at + Vector3i.DOWN, _leaf(colors[0]))
		if stage == 3:
			grid.set_voxel(at + Vector3i(1, 0, 0), _leaf(colors[2]))


## A strawberry plant: three-lobed leaves low over the ground; white flowers,
## then red berries lying at its rim.
static func _strawberry(
	grid: VoxelGrid, rng: RandomNumberGenerator, foot: Vector3, stage: int
) -> void:
	var spread: float = [0.8, 1.5, 2.2, 2.4][stage]
	var height: int = [1, 2, 2, 3][stage]
	for k in 3 + stage:
		var angle := TAU * (k + rng.randf() * 0.4) / (3 + stage)
		var out := Vector3(cos(angle), 0.0, sin(angle))
		var tip := foot + out * spread + Vector3(0, height, 0)
		grid.line(foot, tip, 0.0, _leaf(STRAWBERRY_LEAF[0]))
		var across := Vector3(-out.z, 0.0, out.x)
		for lobe: Vector3 in [Vector3.ZERO, across, -across, out]:
			grid.set_voxel(Vector3i((tip + lobe).round()), _leaf(STRAWBERRY_LEAF[1 + k % 2]))
	if stage == 2:
		for k in 2:
			var angle := rng.randf() * TAU
			var at := Vector3i((foot + Vector3(cos(angle), 0, sin(angle)) * spread).round())
			grid.set_voxel(at + Vector3i(0, height + 1, 0), _leaf(PETALS[0]))
			grid.set_voxel(at + Vector3i(0, height + 2, 0), _leaf(PETALS[1]))
	if stage == 3:
		for k in rng.randi_range(2, 3):
			var angle := rng.randf() * TAU
			var at := Vector3i((foot + Vector3(cos(angle), 0, sin(angle)) * (spread + 0.8)).round())
			grid.set_voxel(at + Vector3i(0, 1, 0), _leaf(STRAWBERRY_RED[1]))
			grid.set_voxel(at, _leaf(STRAWBERRY_RED[0]))
			grid.set_voxel(at + Vector3i(1, 1, 0), _leaf(STRAWBERRY_RED[2]))


## A raspberry plant: canes arching out from its foot, leaves along them;
## white flowers, then red berries hanging under the leaves.
static func _raspberry(
	grid: VoxelGrid, rng: RandomNumberGenerator, foot: Vector3, stage: int
) -> void:
	var height: int = [3, 7, 10, 11][stage]
	var canes := 2 if stage == 0 else 4
	for k in canes:
		var angle := TAU * (k + rng.randf() * 0.5) / canes
		var out := Vector3(cos(angle), 0.0, sin(angle))
		var reach := 0.8 + stage * 0.8
		var steps := height + 2
		for s in steps + 1:
			var t := float(s) / steps
			var p := foot + out * sin(t * PI * 0.5) * reach + Vector3(0, t * height, 0)
			var color: String = RASPBERRY_CANE[k % 2] if stage >= 2 else RASPBERRY_LEAF[0]
			grid.set_voxel(Vector3i(p.round()), _leaf(color))
			if s % 2 == 1 and s > 1:
				var across := Vector3(-out.z, 0.0, out.x) * (1 if s % 4 == 1 else -1)
				var leaf := Vector3i((p + across).round())
				grid.set_voxel(leaf, _leaf(RASPBERRY_LEAF[1 + s % 3 / 2]))
				grid.set_voxel(leaf + Vector3i(0, 1, 0), _leaf(RASPBERRY_LEAF[2]))
				var under := Vector3i((p - across * 0.5 + Vector3(0, -1, 0)).round())
				if stage == 2 and s % 4 == 3:
					grid.set_voxel(under, _leaf(PETALS[0]))
				elif stage == 3 and s % 4 == 3:
					grid.set_voxel(under, _leaf(RASPBERRY_RED[1]))
					grid.set_voxel(under + Vector3i.DOWN, _leaf(RASPBERRY_RED[0]))
					grid.set_voxel(under + Vector3i(1, 0, 0), _leaf(RASPBERRY_RED[2]))


## Flax: thin stems swaying, sky-blue flowers, then golden with round seed
## heads.
static func _flax(grid: VoxelGrid, rng: RandomNumberGenerator, foot: Vector3, stage: int) -> void:
	var height: int = [3, 7, 11, 12][stage] + rng.randi_range(-1, 0)
	var lean := Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6)) * stage * 0.4
	var top := foot + Vector3(0, height, 0) + lean
	var stem: String = FLAX_GOLD[1] if stage == 3 else FLAX_GREEN[stage % 2]
	grid.line(foot, top, 0.0, _leaf(stem))
	var head := Vector3i(top.round())
	if stage == 2:
		grid.set_voxel(head, _leaf(FLAX_BLUE[1]))
		grid.set_voxel(head + Vector3i(1, 0, 0), _leaf(FLAX_BLUE[0]))
		grid.set_voxel(head + Vector3i(0, 0, 1), _leaf(FLAX_BLUE[0]))
	elif stage == 3:
		grid.set_voxel(head, _leaf(FLAX_GOLD[0]))
		grid.set_voxel(head + Vector3i(1, 1, 0), _leaf(FLAX_GOLD[2]))


## Rice: clumps of thin blades standing in the water; heads arching over,
## golden when ripe.
static func _rice(grid: VoxelGrid, rng: RandomNumberGenerator, foot: Vector3, stage: int) -> void:
	var height: int = [3, 7, 10, 11][stage]
	for k in 5:
		var angle := TAU * (k + rng.randf() * 0.5) / 5.0
		var out := Vector3(cos(angle), 0.0, sin(angle))
		var tip := foot + out * (0.6 + stage * 0.5) + Vector3(0, height - k % 2, 0)
		grid.line(foot, tip, 0.0, _leaf(RICE_GREEN[k % 3]))
		if stage >= 2:
			var colors: Array = RICE_GOLD if stage == 3 else RICE_GREEN
			var arch := tip + out * 1.5 + Vector3(0, 0.5, 0)
			grid.line(tip, arch, 0.0, _leaf(colors[1]))
			grid.line(arch, arch + out + Vector3(0, -2, 0), 0.0, _leaf(colors[2]))


## A pumpkin or melon stem: a sprout, then a vine creeping out over the
## ground from the middle of its tile, big leaves along it; grown, a
## yellow flower (its fruit then comes on a tile beside it).
static func _stem(
	grid: VoxelGrid, rng: RandomNumberGenerator, stage: int, leaves: Array, leaf_size: float
) -> void:
	var middle := Vector3(8, 0, 8)
	grid.line(middle, middle + Vector3(0, 2, 0), 0.0, _leaf(leaves[0]))
	if stage == 0:
		for side: Vector3 in [Vector3(-1, 2, 0), Vector3(1, 2, 0)]:
			grid.set_voxel(Vector3i(middle + side), _leaf(leaves[2]))
		return
	var arms := mini(stage, 3)
	var turn := rng.randf() * TAU
	for a in arms:
		var angle := turn + TAU * a / arms
		var out := Vector3(cos(angle), 0.0, sin(angle))
		var across := Vector3(-out.z, 0.0, out.x)
		var length: int = [0, 4, 6, 7][stage]
		for s in range(1, length + 1):
			var p := middle + out * s + across * sin(s * 0.9) * 0.7
			grid.set_voxel(Vector3i(p.floor()), _leaf(leaves[0]))
			if s % 2 == 0:
				var pad := p + across * (1.5 if s % 4 == 0 else -1.5) + Vector3(0, 1, 0)
				grid.disc(
					Vector2(pad.x, pad.z), leaf_size, int(pad.y), _leaf(leaves[1 + s % 3 / 2])
				)
		if stage == 3 and a == 0:
			var bloom := Vector3i((middle + out * 3 + Vector3(0, 2, 0)).floor())
			grid.set_voxel(bloom, _leaf(BLOOM[1]))
			grid.set_voxel(bloom + Vector3i(1, 0, 0), _leaf(BLOOM[0]))
			grid.set_voxel(bloom + Vector3i(0, 0, 1), _leaf(BLOOM[0]))


## A trellis: two posts and a top rail, a diamond lattice between them
## (along x).
static func _trellis(grid: VoxelGrid) -> void:
	for x: int in [1, 14]:
		grid.box(Vector3i(x, 0, 7), Vector3i(x, 23, 8), _solid(WOOD[0]))
	grid.box(Vector3i(1, 24, 7), Vector3i(14, 24, 8), _solid(WOOD[2]))
	for k in range(-2, 4):
		for x in range(2, 14):
			for y: int in [2 + k * 6 + (x - 2), 2 + k * 6 + (13 - x)]:
				if y >= 1 and y <= 23:
					grid.set_voxel(Vector3i(x, y, 8), _solid(WOOD[1]))


## A grapevine on its trellis: a shoot at the foot of a post, its trunk
## climbing and canes running along the lattice, leaves covering it, then
## bunches of grapes hanging under the canes.
static func _vine(grid: VoxelGrid, rng: RandomNumberGenerator, stage: int) -> void:
	var foot := Vector3(3, 0, 9)
	var reach: int = [4, 12, 20, 20][stage]
	for y in reach:
		grid.set_voxel(Vector3i(3 + int(sin(y * 0.6)), y, 9), _solid(VINE_WOOD[y % 2]))
	if stage == 0:
		for side: Vector3i in [Vector3i(2, 3, 9), Vector3i(4, 4, 10)]:
			grid.set_voxel(side, _leaf(GRAPE_LEAF[2]))
		return
	var canes: Array = [10] if stage == 1 else [10, 18]
	for cane in canes:
		var span := 8 if stage == 1 else 12
		grid.line(foot + Vector3(0, cane, 0), Vector3(3 + span, cane, 9), 0.0, _solid(VINE_WOOD[1]))
		# Broad leaves on both sides, of all sizes, some hanging lower.
		for x in range(3, 3 + span, 2):
			for z: int in [6, 10]:
				if rng.randf() < 0.2:
					continue
				var leaf := Vector3(
					x + rng.randf_range(-0.8, 0.8),
					cane + rng.randf_range(-1.0, 2.0),
					z + 0.5 + rng.randf_range(-0.6, 0.6)
				)
				var size := Vector3(
					rng.randf_range(1.0, 1.8), rng.randf_range(0.9, 1.6), rng.randf_range(0.6, 1.0)
				)
				grid.ellipsoid(leaf, size, _leaf(GRAPE_LEAF[rng.randi() % 3]))
		if stage == 3:
			for x in range(5, 3 + span, 4):
				for z: int in [6, 10]:
					_cluster(grid, Vector3i(x, cane - 1, z), 5)


## A bunch of grapes hanging from `top`, `rows` voxels long, narrowing.
static func _cluster(grid: VoxelGrid, top: Vector3i, rows: int) -> void:
	for r in rows:
		var half := 1 if r < rows - 2 else 0
		for dx in range(-half, half + 1):
			var shade := 2 if (dx + r) % 3 == 0 else (1 if r < rows / 2 else 0)
			grid.set_voxel(top + Vector3i(dx, -r, 0), _leaf(GRAPE[shade]))


## Sugar cane by stage: short young canes, then taller, then the full ones
## of the wild (VoxelModels.sugar_cane, the same as before).
static func _cane(block: int, variant: int) -> VoxelGrid:
	var rng := RandomNumberGenerator.new()
	rng.seed = HashUtil.hash2(0x7E5E, block, variant)
	match block:
		Tiles.Block.SUGAR_CANE_0:
			return VoxelModels.sugar_cane(rng, Vector2i(6, 10), 2)
		Tiles.Block.SUGAR_CANE_1:
			return VoxelModels.sugar_cane(rng, Vector2i(12, 18), 4)
	return VoxelModels.sugar_cane(rng)


## A pumpkin: a ribbed ball, lighter on top, its stalk curling.
static func _pumpkin(rng: RandomNumberGenerator) -> VoxelGrid:
	var grid := _grid(14)
	var radii := Vector3(6.5 + rng.randf_range(-0.5, 0.3), 5.0 + rng.randf_range(-0.4, 0.4), 6.2)
	var center := Vector3(8, radii.y, 8)
	var paint := func(p: Vector3i) -> int:
		var d := Vector3(p) + Vector3.ONE * 0.5 - center
		if cos(8.0 * atan2(d.z, d.x)) < -0.7:
			return _solid(PUMPKIN[0])
		var height := d.y / radii.y
		return _solid(
			PUMPKIN[3] if height > 0.65 else (PUMPKIN[2] if height > -0.2 else PUMPKIN[1])
		)
	grid.ellipsoid(center, radii, paint)
	var top := int(center.y + radii.y)
	grid.box(Vector3i(7, top - 1, 7), Vector3i(8, top + 1, 8), _solid(PUMPKIN_STALK[0]))
	grid.set_voxel(Vector3i(9, top + 1, 8), _solid(PUMPKIN_STALK[1]))
	return grid


## A melon: an oval, dark green with pale stripes along it.
static func _melon(rng: RandomNumberGenerator) -> VoxelGrid:
	var grid := _grid(12)
	var radii := Vector3(6.6, 4.8 + rng.randf_range(-0.3, 0.3), 5.6)
	var center := Vector3(8, radii.y, 8)
	var salt := rng.randi()
	var paint := func(p: Vector3i) -> int:
		var d := Vector3(p) + Vector3.ONE * 0.5 - center
		var wobble := (HashUtil.unit2(salt, p.x / 2, p.y + p.z * 31) - 0.5) * 0.8
		var stripe := cos(7.0 * atan2(d.y, d.z) + wobble) > 0.35
		var top := d.y > radii.y * 0.6
		if stripe:
			return _solid(MELON[3] if top else MELON[2])
		return _solid(MELON[1] if top else MELON[0])
	grid.ellipsoid(center, radii, paint)
	grid.set_voxel(Vector3i(8, int(center.y + radii.y), 8), _solid(PUMPKIN_STALK[0]))
	return grid


## A wild plant: a few of its crop's ripe plants grown where they fell (wild
## flax in flower, a sprawling tomato, a grapevine over a bush).
static func _wild(block: int, rng: RandomNumberGenerator) -> VoxelGrid:
	var grid := _grid(26)
	var feet: Array[Vector3] = []
	var count: int = WILD_COUNT.get(block, 1)
	for i in count:
		feet.append(Vector3(rng.randi_range(5, 11), 0, rng.randi_range(5, 11)))
	for foot in feet:
		match block:
			Tiles.Block.WILD_BEETROOT:
				_beet(grid, rng, foot, 3)
			Tiles.Block.WILD_CABBAGE:
				_cabbage(grid, rng, foot, 2)
			Tiles.Block.WILD_CORN:
				_corn(grid, rng, foot, 3)
			Tiles.Block.WILD_TOMATO:
				_tomato(grid, rng, Vector3(8, 0, 8), 3, false)
			Tiles.Block.WILD_STRAWBERRY:
				_strawberry(grid, rng, foot, 3)
			Tiles.Block.WILD_FLAX:
				_flax(grid, rng, foot, 2)
			Tiles.Block.WILD_RICE:
				_rice(grid, rng, foot, 3)
			Tiles.Block.WILD_GRAPES:
				_wild_vine(grid, rng)
			Tiles.Block.WILD_RASPBERRY:
				_raspberry(grid, rng, foot, 3)
	grid.sway = 0.6
	grid.sway_from = 1
	return grid


## A wild grapevine sprawling over a bush, bunches hanging at its sides.
static func _wild_vine(grid: VoxelGrid, rng: RandomNumberGenerator) -> void:
	var paint := func(_p: Vector3i) -> int: return _leaf(GRAPE_LEAF[rng.randi() % 3])
	grid.ellipsoid(Vector3(8, 4, 8), Vector3(5.5, 4.5, 5.5), paint)
	VoxelModels.roughen(grid, rng, 0.25, 0.15)
	for k in 4:
		var angle := TAU * (k + rng.randf() * 0.5) / 4.0
		var side := Vector3i((Vector3(8, 4, 8) + Vector3(cos(angle), 0, sin(angle)) * 6.2).round())
		_cluster(grid, side, 3)


# ---------------------------------------------------------------- items


## A handful of seeds (or pips): little grains of two shades.
static func _pips(rng: RandomNumberGenerator, colors: Array) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(10, 2, 10))
	for k in 7:
		var spot := Vector3i(rng.randi_range(1, 7), 0, rng.randi_range(1, 7))
		grid.set_voxel(spot, _solid(colors[0]))
		grid.set_voxel(spot + Vector3i(1, 0, 0), _solid(colors[1]))
		if k % 3 == 0:
			grid.set_voxel(spot + Vector3i(0, 1, 0), _solid(colors[1]))
	return grid


## A small heap of grains (rice, sugar).
static func _heap(rng: RandomNumberGenerator, colors: Array) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(10, 5, 10))
	var paint := func(_p: Vector3i) -> int:
		var roll := rng.randf()
		return _solid(colors[2] if roll < 0.12 else (colors[1] if roll < 0.6 else colors[0]))
	grid.ellipsoid(Vector3(5, 0.5, 5), Vector3(4.6, 3.6, 4.6), paint)
	return grid


## A round fruit (tomato, apple, orange): lit on top, a stalk and a leaf.
static func _fruit(colors: Array, radius: float, leaf: String) -> VoxelGrid:
	var size := ceili(radius * 2.0) + 1
	var grid := VoxelGrid.new(Vector3i(size, size + 2, size))
	var center := Vector3(size * 0.5, radius, size * 0.5)
	var paint := func(p: Vector3i) -> int:
		var d := (Vector3(p) + Vector3.ONE * 0.5 - center) / radius
		if d.y > 0.45 and d.x < 0.2:
			return _solid(colors[2])
		return _solid(colors[1] if d.y > -0.4 else colors[0])
	grid.ellipsoid(center, Vector3.ONE * radius, paint)
	var top := Vector3i(int(center.x), int(center.y + radius), int(center.z))
	grid.set_voxel(top, _solid("#5a3a20"))
	grid.set_voxel(top + Vector3i(0, 1, 0), _solid("#5a3a20"))
	grid.set_voxel(top + Vector3i(1, 0, 0), _solid(leaf))
	grid.set_voxel(top + Vector3i(2, 1, 0), _solid(leaf))
	return grid


## A raspberry: a rounded cone of little red drupelets, its green cap.
static func _raspberry_item() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(7, 8, 7))
	var paint := func(p: Vector3i) -> int:
		if p.y >= 5 and p.x <= 3:
			return _solid(RASPBERRY_RED[2])
		return _solid(RASPBERRY_RED[(p.x + p.y + p.z) % 2])
	grid.ellipsoid(Vector3(3.5, 3.2, 3.5), Vector3(2.8, 3.2, 2.8), paint)
	for d: Vector3i in [
		Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1)
	]:
		grid.set_voxel(Vector3i(3, 6, 3) + d, _solid(RASPBERRY_LEAF[1]))
	grid.set_voxel(Vector3i(3, 7, 3), _solid(RASPBERRY_LEAF[0]))
	return grid


## A peach pit: an oval stone, wrinkled with dark grooves.
static func _pit() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(8, 6, 6))
	var paint := func(p: Vector3i) -> int:
		if (p.x * 3 + p.y * 2 + p.z) % 5 == 0:
			return _solid("#5a3420")
		return _solid("#a06a44" if p.y >= 3 else "#84543a")
	grid.ellipsoid(Vector3(4, 2.6, 3), Vector3(3.6, 2.6, 2.6), paint)
	return grid


## A beetroot: a dark red bulb tapering to its root, leaf stalks on top.
static func _beetroot() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(8, 11, 8))
	grid.ellipsoid(Vector3(4, 4, 4), Vector3(3.3, 3.2, 3.3), _solid(BEET_RED[1]))
	grid.ellipsoid(Vector3(3.2, 5, 3.4), Vector3(1.4, 1.2, 1.4), _solid(BEET_RED[2]))
	grid.line(Vector3(4, 1, 4), Vector3(4, 0, 5), 0.0, _solid(BEET_RED[0]))
	for k in 3:
		grid.line(Vector3(4, 7, 4), Vector3(2 + k * 2, 10, 4), 0.0, _solid(BEET_LEAF[k]))
	return grid


## A cabbage: a round pale head wrapped in darker leaves.
static func _cabbage_head() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(10, 9, 10))
	grid.ellipsoid(Vector3(5, 3.6, 5), Vector3(4.6, 3.6, 4.6), _solid(CABBAGE_OUTER[1]))
	grid.ellipsoid(Vector3(5, 4.4, 5), Vector3(3.8, 3.4, 3.8), _solid(CABBAGE_HEAD[1]))
	grid.ellipsoid(Vector3(4.4, 6.4, 4.6), Vector3(1.8, 1.2, 1.8), _solid(CABBAGE_HEAD[2]))
	for z in range(1, 9, 3):
		grid.set_voxel(Vector3i(5, 6, z), _solid(CABBAGE_OUTER[0]))
	return grid


## An ear of corn lying down: rows of kernels, its husk peeled back
## (`roasted`: browned, no husk).
static func _cob(roasted: bool) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(15, 6, 6))
	var colors: Array = ROASTED if roasted else CORN_GOLD
	for x in 11:
		var radius := lerpf(2.4, 1.4, x / 10.0)
		for y in 6:
			for z in 6:
				if Vector2(y + 0.5 - 3.0, z + 0.5 - 3.0).length() <= radius + 0.25:
					var shade := 2 if y >= 4 else (1 if (x + y + z) % 2 else 0)
					grid.set_voxel(Vector3i(x + 4, y, z), _solid(colors[shade]))
	if not roasted:
		for k in 3:
			grid.line(Vector3(5, 1 + k * 2, 3), Vector3(0, k * 2, 1 + k * 2), 0.0, _solid(HUSK[k]))
	return grid


## A strawberry: a red cone, seeds dotting it, a green star on top.
static func _strawberry_item() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(8, 8, 8))
	var radii: Array[float] = [0.8, 1.8, 2.5, 2.9, 2.7, 1.9]
	for y in radii.size():
		var paint := func(p: Vector3i) -> int:
			if (p.x * 3 + p.y * 5 + p.z * 7) % 6 == 0:
				return _solid("#f2d046")
			return _solid(STRAWBERRY_RED[2] if y >= 4 and p.x < 4 else STRAWBERRY_RED[1])
		grid.disc(Vector2(4, 4), radii[y], y, paint)
	for d: Vector3i in [
		Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1)
	]:
		grid.set_voxel(Vector3i(4, 6, 4) + d, _solid(STRAWBERRY_LEAF[1]))
	grid.set_voxel(Vector3i(4, 7, 4), _solid(STRAWBERRY_LEAF[0]))
	return grid


## A bundle of flax: golden stalks splaying out of a band, blue flowers at
## their tips.
static func _flax_bundle() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(11, 14, 11))
	var middle := Vector3(5, 0, 5)
	for i in 7:
		var angle := TAU * i / 7.0
		var out := Vector3(cos(angle), 0, sin(angle))
		var top := middle + out * 3.4 + Vector3(0, 12, 0)
		grid.line(middle + out * 1.0, top, 0.0, _solid(FLAX_GOLD[1 + i % 2]))
		grid.set_voxel(Vector3i(top.round()) + Vector3i.UP, _solid(FLAX_BLUE[i % 2]))
	grid.cylinder(Vector2(5, 5), 1.6, 4, 5, _solid("#7a4f22"))
	return grid


## Linen: a folded length of pale cloth.
static func _linen() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(12, 4, 9))
	grid.box(Vector3i(0, 0, 0), Vector3i(11, 1, 8), _solid("#d8ccb0"))
	grid.box(Vector3i(1, 2, 0), Vector3i(10, 3, 8), _solid("#ece2c8"))
	grid.box(Vector3i(1, 3, 4), Vector3i(10, 3, 4), _solid("#cfc2a4"))
	for x in range(1, 11, 2):
		grid.set_voxel(Vector3i(x, 2, 0), _solid("#bfb294"))
	return grid


## A slice of melon: a half-moon of red flesh with black seeds, a pale band
## and its green rind.
static func _melon_slice() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(14, 8, 3))
	for x in 14:
		for y in 8:
			var d := Vector2(x + 0.5 - 7.0, y + 0.5).length()
			if d > 7.0:
				continue
			var color: String = MELON[1]
			if d < 5.2:
				color = "#1e1a18" if (x * 5 + y * 3) % 11 == 0 and d < 4.0 else MELON_FLESH[1]
			elif d < 6.0:
				color = MELON_FLESH[2]
			for z in 3:
				grid.set_voxel(Vector3i(x, y, z), _solid(color))
	return grid


## Cooked rice: a white mound on a broad leaf.
static func _cooked_rice(rng: RandomNumberGenerator) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(12, 5, 12))
	grid.disc(Vector2(6, 6), 5.6, 0, _solid(LEAF_ITEM[0]))
	var paint := func(_p: Vector3i) -> int:
		return _solid("#ffffff" if rng.randf() < 0.3 else "#f2eee2")
	grid.ellipsoid(Vector3(6, 1, 6), Vector3(3.8, 3.2, 3.8), paint)
	return grid


## A bunch of grapes on its stalk, a leaf at the top.
static func _bunch() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(9, 12, 7))
	var rows: Array[int] = [4, 4, 3, 3, 2, 1]
	for r in rows.size():
		var y := 8 - r * 1.4
		for k in rows[r]:
			var x := 4.5 + (k - (rows[r] - 1) * 0.5) * 1.8
			var shade := 2 if r == 0 and k < 2 else (1 if (k + r) % 2 else 0)
			grid.ellipsoid(Vector3(x, y, 3.5), Vector3(1.1, 1.1, 1.1), _solid(GRAPE[shade]))
	grid.line(Vector3(4.5, 9, 3.5), Vector3(4.5, 11, 3.5), 0.0, _solid(VINE_WOOD[1]))
	grid.box(Vector3i(5, 10, 2), Vector3i(7, 11, 4), _solid(GRAPE_LEAF[1]))
	return grid


## Two cherries hanging from joined stalks, a leaf at the top.
static func _cherries() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(10, 10, 6))
	var colors: Array = OrchardColors.TREES[Tiles.Block.CHERRY_TREE][3]
	for center: Vector3 in [Vector3(2.5, 2, 3), Vector3(7, 1.6, 3)]:
		grid.ellipsoid(center, Vector3(1.7, 1.7, 1.7), _solid(colors[1]))
		grid.set_voxel(Vector3i(center) + Vector3i(-1, 1, -1), _solid(colors[2]))
		grid.line(center + Vector3(0, 1.5, 0), Vector3(5, 8.5, 3), 0.0, _solid("#5a6a2a"))
	grid.box(Vector3i(5, 8, 2), Vector3i(7, 9, 3), _solid(LEAF_ITEM[1]))
	return grid


static func _solid(hex: String) -> int:
	return VoxelGrid.voxel(Color(hex))


static func _leaf(hex: String) -> int:
	return VoxelGrid.voxel(Color(hex), VoxelGrid.Kind.FOLIAGE)
