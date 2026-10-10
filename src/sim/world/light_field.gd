class_name LightField
extends RefCounted
## Light levels (0 to MAX, Minecraft's), shared by the server and the
## clients. Sky light: the day comes straight down to the first cube (glass
## lets it through, water dims it a level a cell), then spreads sideways
## and down into covered places, a level less per step: a cave far from
## any opening stays at 0. Block light: lava, fires, torches and lanterns
## shine EMISSION levels, a level less per step. Cubes stop both (not glass
## or windows). ChunkMesher bakes the sky light of a chunk into its faces
## (see sky), the server measures a cell's light for the monsters (Light).

const MAX := 15
## How a voxel lets light through (by voxel id): CLEAR, OPAQUE, or WATER
## (a level less per cell).
const CLEAR := 0
const OPAQUE := 1
const WATER := 2
## What shines, by kind (lava: its ground voxel), and how much.
const SHINE := {
	Tiles.Block.CAMPFIRE: 15,
	Tiles.Block.LANTERN: 15,
	Tiles.Block.LANTERN_HANGING: 15,
	Tiles.Block.LANTERN_WALL: 15,
	Tiles.Block.TORCH: 14,
	Tiles.Block.TORCH_BRACKET_LIT: 14,
	Tiles.Block.FOOD_FURNACE_LIT: 13,
	Tiles.Block.FACTORY_FURNACE_LIT: 13,
}
const LAVA_SHINE := 15
## Cubes the light goes through.
const CLEAR_BLOCKS := {
	Tiles.Block.GLASS: true,
	Tiles.Block.WINDOW: true,
	Tiles.Block.OLD_GLASS: true,
	Tiles.Block.LEADED_GLASS: true,
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
	Tiles.Block.IRON_WINDOW: true,
	Tiles.Block.IRON_WINDOW_SMALL: true,
	Tiles.Block.IRON_WINDOW_SASH: true,
	Tiles.Block.IRON_WINDOW_ROUND: true,
}

## Per voxel id: how it lets light through, how much it shines.
static var _passing := _build_passing()
## Built on first use: ObjectShapes (base_kind) may still be loading when
## this class is (ObjectShapes -> ShapedBlocks -> Mining -> Growth -> Light).
static var _shining := PackedByteArray()


## How a voxel lets light through (CLEAR, OPAQUE, WATER).
static func passing(voxel: int) -> int:
	return _passing[voxel] if voxel < _passing.size() else OPAQUE


## How much light a voxel shines (0: none).
static func shine(voxel: int) -> int:
	if _shining.is_empty():
		_shining = _build_shining()
	return _shining[voxel] if voxel < _shining.size() else 0


## The sky light of a region `span` x `span` columns wide (voxels column by
## column, WORLD_HEIGHT rows each, and each column's top, see
## ChunkData.top_row). Returns [levels, open]: `open[column]` is the first
## row from which the sky is fully seen (MAX up there, not stored);
## `levels` holds the others' (0..MAX), one byte a cell.
static func sky(voxels: PackedInt32Array, tops: PackedByteArray, span: int) -> Array:
	var height := GameConst.WORLD_HEIGHT
	var columns := span * span
	var passing_of := _passing.duplicate()
	var levels := PackedByteArray()
	levels.resize(columns * height)
	var open := PackedInt32Array()
	open.resize(columns)
	var queue := PackedInt32Array()
	# Straight down: through clear voxels, then dimmed by water.
	for column in columns:
		var base := column * height
		var y := tops[column] - 1
		while y >= 0 and passing_of[voxels[base + y]] == CLEAR:
			y -= 1
		open[column] = y + 1
	for z in span:
		for x in span:
			_under_water(levels, queue, voxels, passing_of, open, x, z, span)
	# Sideways into covered places, from the cells under the open sky.
	for z in span:
		for x in span:
			var column := z * span + x
			var from := open[column]
			if x > 0 and open[column - 1] > from:
				_seed(levels, queue, voxels, passing_of, column - 1, from, open[column - 1])
			if x < span - 1 and open[column + 1] > from:
				_seed(levels, queue, voxels, passing_of, column + 1, from, open[column + 1])
			if z > 0 and open[column - span] > from:
				_seed(levels, queue, voxels, passing_of, column - span, from, open[column - span])
			if z < span - 1 and open[column + span] > from:
				_seed(levels, queue, voxels, passing_of, column + span, from, open[column + span])
	# Then on, a level less per step.
	var head := 0
	while head < queue.size():
		var index := queue[head]
		head += 1
		var level := levels[index]
		if level <= 1:
			continue
		var y := index % height
		var column := index / height
		var x := column % span
		var z := column / span
		if y + 1 < height and y + 1 < open[column]:
			_spread(levels, queue, voxels, passing_of, index + 1, level)
		if y > 0:
			_spread(levels, queue, voxels, passing_of, index - 1, level)
		if x > 0 and y < open[column - 1]:
			_spread(levels, queue, voxels, passing_of, index - height, level)
		if x < span - 1 and y < open[column + 1]:
			_spread(levels, queue, voxels, passing_of, index + height, level)
		if z > 0 and y < open[column - span]:
			_spread(levels, queue, voxels, passing_of, index - span * height, level)
		if z < span - 1 and y < open[column + span]:
			_spread(levels, queue, voxels, passing_of, index + span * height, level)
	return [levels, open]


## The water at the top of the column at (x, z) dims the sky's light a
## level a cell. Only by columns open from another row (shores, banks) may
## it light its neighbors more than their own water does: those cells
## spread their light (queued), and the last one if something not opaque
## lies under the water.
static func _under_water(
	levels: PackedByteArray,
	queue: PackedInt32Array,
	voxels: PackedInt32Array,
	passing_of: PackedByteArray,
	open: PackedInt32Array,
	x: int,
	z: int,
	span: int
) -> void:
	var height := GameConst.WORLD_HEIGHT
	var column := z * span + x
	var base := column * height
	var y := open[column] - 1
	if y < 0 or passing_of[voxels[base + y]] != WATER:
		return
	var row := open[column]
	var edge := (
		(x > 0 and open[column - 1] != row)
		or (x < span - 1 and open[column + 1] != row)
		or (z > 0 and open[column - span] != row)
		or (z < span - 1 and open[column + span] != row)
	)
	var level := MAX
	while y >= 0 and passing_of[voxels[base + y]] == WATER and level > 1:
		level -= 1
		levels[base + y] = level
		if edge:
			queue.append(base + y)
		y -= 1
	if not edge and y >= 0 and level > 1 and passing_of[voxels[base + y]] != OPAQUE:
		queue.append(base + y + 1)


## The covered cells of `column` from row `from` up to `to` (excluded): the
## sky shines on them from the side.
static func _seed(
	levels: PackedByteArray,
	queue: PackedInt32Array,
	voxels: PackedInt32Array,
	passing_of: PackedByteArray,
	column: int,
	from: int,
	to: int
) -> void:
	var base := column * GameConst.WORLD_HEIGHT
	for y in range(from, to):
		_spread(levels, queue, voxels, passing_of, base + y, MAX)


## Light `level` reaches the cell at `index` from a neighbor.
static func _spread(
	levels: PackedByteArray,
	queue: PackedInt32Array,
	voxels: PackedInt32Array,
	passing_of: PackedByteArray,
	index: int,
	level: int
) -> void:
	var how := passing_of[voxels[index]]
	if how == OPAQUE:
		return
	var next := level - (2 if how == WATER else 1)
	if next > levels[index]:
		levels[index] = next
		queue.append(index)


static func _build_passing() -> PackedByteArray:
	var table := PackedByteArray()
	table.resize(Voxels.used_ids())
	for voxel in table.size():
		if Voxels.is_lava(voxel):
			table[voxel] = OPAQUE
		elif Voxels.is_cube(voxel) and not CLEAR_BLOCKS.has(Voxels.block_of(voxel)):
			table[voxel] = OPAQUE
		elif Voxels.is_liquid(voxel):
			table[voxel] = WATER
	return table


static func _build_shining() -> PackedByteArray:
	var table := PackedByteArray()
	table.resize(Voxels.used_ids())
	for voxel in table.size():
		var block := Voxels.block_of(voxel)
		table[voxel] = SHINE.get(ObjectShapes.base_kind(block), 0)
		if Voxels.is_lava(voxel):
			table[voxel] = LAVA_SHINE
	return table
