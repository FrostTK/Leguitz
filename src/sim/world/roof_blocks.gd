class_name RoofBlocks
extends RefCounted
## Roofs (phase 8, step 5; static tables and rules, shared): the pieces of
## each covering (COVERINGS: terracotta tiles, slates, wood shingles,
## thatch), drawn with the terrain like stairs (ShapedBlocks hands them
## here; RoofFaces draws them). A piece is solid under its surface, a
## height over its cell (`surface`: the most of some branches, each the
## least of some planes, so its creases fall on the halves and diagonals of
## the cell), shared by physics (`boxes`: columns of the cell, a sixteenth
## of a level apart at most: one walks up a roof), aiming and the meshes.
## A slope rises 45 degrees away from the player placing it (Shift: the
## other way) and turns its corners as stairs do (`_slope_surface`: an
## outer corner, a hip, is the least of two slopes, an inner one, a valley,
## the most). A ridge peaks half a level high along its axis (chosen when
## placed: along a ridge beside it, else across the player's view); its
## ends are hipped where a roof goes on lower beyond them (a hipped roof, a
## pyramid's top) and run on into the ridges beside them, crossing them
## (T and cross roofs). A gentle slope rises a level over two cells: low
## then high (GENTLE_HIGH, placed behind a low one). Roof pieces keep the
## sky out (LightField), count as a column's top (ChunkData) and cover a
## building (CutRegion). Dormers and the chimney are objects (ObjectShapes,
## RoofModels).

enum Shape { SLOPE, RIDGE, GENTLE, GENTLE_HIGH }

## [block name prefix, the covering's cube, its item, its dormer] each.
const COVERINGS := [
	["TILE_ROOF", Tiles.Block.ROOF_TILES, Items.Id.ROOF_TILES, Tiles.Block.TILE_DORMER],
	["SLATE_ROOF", Tiles.Block.SLATES, Items.Id.SLATES, Tiles.Block.SLATE_DORMER],
	["SHINGLE_ROOF", Tiles.Block.SHINGLES, Items.Id.SHINGLES, Tiles.Block.SHINGLE_DORMER],
	["THATCH_ROOF", Tiles.Block.THATCH, Items.Id.THATCH, Tiles.Block.THATCH_DORMER],
]
## The ways a block faces (ObjectShapes.WAYS: south, west, north, east).
const WAYS := ShapedBlocks.WAYS
const FACINGS := ["", "_WEST", "_NORTH", "_EAST"]
## The items' shapes (by name suffix).
const ITEMS := {"": Shape.SLOPE, "_RIDGE": Shape.RIDGE, "_GENTLE": Shape.GENTLE}
## A plane cutting a ridge's branch to half the cell rises this steeply.
const STEEP := 1000.0
## The cell's columns for physics, along each side.
const BOX_STEPS := 8
## A chimney smokes with a fire burning this many rows under its foot at
## most, straight down (a campfire, a lit furnace).
const CHIMNEY_REACH := 8
const FIRES := {
	Tiles.Block.CAMPFIRE: true,
	Tiles.Block.FOOD_FURNACE_LIT: true,
	Tiles.Block.FACTORY_FURNACE_LIT: true,
	Tiles.Block.FIREPLACE_LIT: true,
	Tiles.Block.STOVE_LIT: true,
}
const EPSILON := 0.0001

## block -> its shape, covering (index of COVERINGS), item, front; a
## ridge -> its axis; item -> [block, the covering's item, shape]; facing
## kind -> its blocks; the dormers.
static var _shapes: Dictionary[int, int] = {}
static var _coverings: Dictionary[int, int] = {}
static var _items: Dictionary[int, int] = {}
static var _fronts: Dictionary[int, Vector2i] = {}
static var _axes: Dictionary[int, Vector2i] = {}
static var _placing: Dictionary[int, Array] = {}
static var _facings: Dictionary[int, Array] = {}
static var _dormers: Dictionary[int, int] = {}
static var _built := _build()


static func is_roof(block: int) -> bool:
	return Tiles.is_roof(block)


## A roof piece's Shape (-1: none).
static func shape_of(block: int) -> int:
	return _shapes.get(block, -1)


## The index in COVERINGS of a roof piece's or a dormer's covering (-1).
static func covering_of(block: int) -> int:
	return _coverings.get(block, _dormers.get(ObjectShapes.kind_of(block), -1))


## The cube of a roof piece's covering (AIR: not a piece).
static func material_of(block: int) -> int:
	var covering := covering_of(block)
	return COVERINGS[covering][1] if covering >= 0 and is_roof(block) else Tiles.Block.AIR


## The item a roof piece gives back.
static func item_of(block: int) -> int:
	return _items.get(block, Items.Id.NONE)


## The block an item of roof pieces places (AIR: none).
static func placed_by(item: int) -> int:
	return _placing[item][0] if _placing.has(item) else Tiles.Block.AIR


## An item's Shape (-1: not roof pieces).
static func item_shape(item: int) -> int:
	return _placing[item][2] if _placing.has(item) else -1


## The items of roof pieces: [item, its covering's item, its Shape].
static func items() -> Array:
	return _placing.keys().map(func(item: int) -> Array: return [item] + _placing[item].slice(1))


## The facing kinds (slopes, gentle slopes), for ObjectShapes.
static func facing_kinds() -> Dictionary[int, Array]:
	return _facings


## Which way a slope faces, down it (ZERO: a ridge).
static func front_of(block: int) -> Vector2i:
	return _fronts.get(block, Vector2i.ZERO)


## A ridge's axis, as placed ((1, 0): east-west; ZERO: not a ridge).
static func axis_of(block: int) -> Vector2i:
	return _axes.get(block, Vector2i.ZERO)


## The dormers' kinds (their first block).
static func is_dormer(block: int) -> bool:
	return _dormers.has(ObjectShapes.kind_of(block))


## How high (levels, over its cell's floor) a roof piece rises at most.
static func top_of(block: int) -> float:
	return 0.5 if shape_of(block) in [Shape.RIDGE, Shape.GENTLE] else 1.0


## The plane of a 45 degree slope facing `front` (down it): 0 on the edge
## that way, 1 on the opposite one.
static func slope(front: Vector2i) -> Vector3:
	if front.x != 0:
		return Vector3(1.0 if front.x > 0 else 0.0, -front.x, 0.0)
	return Vector3(1.0 if front.y > 0 else 0.0, 0.0, -front.y)


## A roof piece's surface in `cell`: its branches (the height is the most
## of them), each the planes (c, gx, gz: c + gx x + gz z, x and z across
## the cell from 0 to 1) whose least it is. It joins the pieces around
## (`voxel_at`: Callable(cell) -> int; an invalid one: alone).
static func surface(block: int, cell: Vector3i, voxel_at: Callable) -> Array[PackedVector3Array]:
	var front := front_of(block)
	match shape_of(block):
		Shape.SLOPE:
			return _slope_surface(front, cell, voxel_at)
		Shape.RIDGE:
			return _ridge_surface(axis_of(block), cell, voxel_at)
		Shape.GENTLE:
			return [PackedVector3Array([slope(front) * 0.5])]
		Shape.GENTLE_HIGH:
			return [PackedVector3Array([slope(front) * 0.5 + Vector3(0.5, 0.0, 0.0)])]
	return []


## The surface's height (levels over the floor, 0 to 1) at (x, z) of the
## cell.
static func height_at(branches: Array[PackedVector3Array], x: float, z: float) -> float:
	var best := 0.0
	for planes in branches:
		var least := INF
		for plane in planes:
			least = minf(least, plane.x + plane.y * x + plane.z * z)
		best = maxf(best, least)
	return clampf(best, 0.0, 1.0)


## The boxes (local units) filling a surface in `cell`: BOX_STEPS x
## BOX_STEPS columns, each as high as the surface at its middle, the same
## heights side by side joined.
static func boxes(branches: Array[PackedVector3Array], cell: Vector3i) -> Array[AABB]:
	var result: Array[AABB] = []
	var corner := Vector3(cell.x, cell.y - GameConst.SEA_LEVEL, cell.z)
	var step := 1.0 / BOX_STEPS
	# Runs along x of one height (x0, x1, height) -> their box, row by row.
	var open: Dictionary[Vector3, int] = {}
	for iz in BOX_STEPS:
		var row := PackedFloat32Array()
		row.resize(BOX_STEPS)
		for ix in BOX_STEPS:
			row[ix] = height_at(branches, (ix + 0.5) * step, (iz + 0.5) * step)
		var next: Dictionary[Vector3, int] = {}
		var ix := 0
		while ix < BOX_STEPS:
			var end := ix + 1
			while end < BOX_STEPS and absf(row[end] - row[ix]) < EPSILON:
				end += 1
			if row[ix] > EPSILON:
				var key := Vector3(ix, end, row[ix])
				if open.has(key):
					var box := result[open[key]]
					box.size.z += step
					result[open[key]] = box
					next[key] = open[key]
				else:
					var at := corner + Vector3(ix * step, 0.0, iz * step)
					result.append(AABB(at, Vector3((end - ix) * step, row[ix], step)))
					next[key] = result.size() - 1
			ix = end
		open = next
	return result


## The octants (ShapedBlocks.mask's bits) a roof piece fills whole: what
## hides the faces of stairs beside it.
static func octants(block: int, cell: Vector3i, voxel_at: Callable) -> int:
	var branches := surface(block, cell, voxel_at)
	var mask := 0
	for z in 2:
		for x in 2:
			var least := INF
			for corner: Vector2 in [
				Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1), Vector2(0.5, 0.5)
			]:
				var at := (Vector2(x, z) + corner) * 0.5
				least = minf(least, height_at(branches, at.x, at.y))
			if least >= 0.5 - EPSILON:
				mask |= 1 << (x + z * 2)
			if least >= 1.0 - EPSILON:
				mask |= 1 << (x + z * 2 + 4)
	return mask


## The lines a ridge's cap runs along, half a level high (cell
## coordinates, 0 to 1): [from, to, closed at from, closed at to] each (an
## end runs on into a ridge beside it, or stops: closed). Hipped ends draw
## it back to the middle; the ridges running off across it, from there.
static func peaks(block: int, cell: Vector3i, voxel_at: Callable) -> Array:
	var result := []
	if shape_of(block) != Shape.RIDGE:
		return result
	var axis := axis_of(block)
	var branches := surface(block, cell, voxel_at)
	var middle := Vector2(0.5, 0.5)
	var ends := []
	for side: int in [-1, 1]:
		var tip := middle + Vector2(axis) * 0.5 * side
		var high := height_at(branches, tip.x, tip.y) >= 0.5 - EPSILON
		ends.append([tip if high else middle, not _ridge_at(cell + _step(axis * side), voxel_at)])
	if ends[0][0] != ends[1][0]:
		result.append([ends[0][0], ends[1][0], ends[0][1], ends[1][1]])
	var across := Vector2i(axis.y, axis.x)
	for side: int in [-1, 1]:
		var next := cell + _step(across * side)
		if _ridge_at(next, voxel_at) and axis_of(Voxels.block_of(voxel_at.call(next))) == across:
			result.append([middle, middle + Vector2(across * side) * 0.5, false, false])
	return result


## Whether a fire burns under the chimney in `cell` (its stack, then
## CHIMNEY_REACH rows under its foot, straight down): it smokes.
static func smokes(cell: Vector3i, voxel_at: Callable) -> bool:
	var chimney: int = voxel_at.call(cell)
	var at := cell
	while at.y > 0 and voxel_at.call(at + Vector3i.DOWN) == chimney:
		at += Vector3i.DOWN
	for depth in CHIMNEY_REACH:
		at += Vector3i.DOWN
		if at.y < 0:
			break
		if FIRES.has(ObjectShapes.base_kind(Voxels.block_of(voxel_at.call(at)))):
			return true
	return false


## The box around a roof piece (local units).
static func bounds(block: int, cell: Vector3i) -> AABB:
	var low := Vector3(cell.x, cell.y - GameConst.SEA_LEVEL, cell.z)
	return AABB(low, Vector3(1.0, top_of(block), 1.0))


## Where an item of roof pieces placed in `cell` goes ({}: nowhere):
## `front` towards the player, `upper` (Shift, or aimed at the upper half
## of a side) turns a slope the other way. A ridge lies along a ridge
## beside it, else across the player's view; a gentle slope placed behind
## a low one (facing the same way) is the high one.
static func placement(
	cell: Vector3i, block: int, front: Vector2i, upper: bool, voxel_at: Callable
) -> Dictionary:
	if not Mining.is_replaceable(voxel_at.call(cell)):
		return {}
	var placed := block
	var way := maxi(WAYS.find(-front if upper else front), 0)
	var prefix: String = COVERINGS[covering_of(block)][0]
	match shape_of(block):
		Shape.SLOPE:
			placed = _facings[block][way]
		Shape.RIDGE:
			var axis := Vector2i(absi(front.y), absi(front.x))
			for along: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				for side: int in [-1, 1]:
					var next := Voxels.block_of(voxel_at.call(cell + _step(along * side)))
					if shape_of(next) == Shape.RIDGE:
						axis = along
			placed = Tiles.Block[prefix + ("_RIDGE" if axis.x != 0 else "_RIDGE_NS")]
		Shape.GENTLE:
			var facing := WAYS[way]
			var ahead := Voxels.block_of(voxel_at.call(cell + _step(facing)))
			var high := shape_of(ahead) == Shape.GENTLE and front_of(ahead) == facing
			placed = Tiles.Block[prefix + ("_GENTLE_HIGH" if high else "_GENTLE") + FACINGS[way]]
	return {cell: Voxels.of_block(placed)}


## A slope, its corners turned after the slopes around it (as stairs do):
## the slope behind it facing across makes it an outer corner (the least
## of both), else the slope in front of it facing across an inner one (the
## most of both).
static func _slope_surface(
	front: Vector2i, cell: Vector3i, voxel_at: Callable
) -> Array[PackedVector3Array]:
	var own := slope(front)
	if voxel_at.is_valid():
		var behind := _slope_front(voxel_at.call(cell - _step(front)))
		if _across(behind, front) and _slope_front(voxel_at.call(cell + _step(behind))) != front:
			return [PackedVector3Array([own, slope(behind)])]
		var ahead := _slope_front(voxel_at.call(cell + _step(front)))
		if _across(ahead, front) and _slope_front(voxel_at.call(cell - _step(ahead))) != front:
			return [PackedVector3Array([own]), PackedVector3Array([slope(ahead)])]
	return [PackedVector3Array([own])]


## A ridge along `axis`: the least of the slopes down both sides, hipped
## at an end where no ridge goes on and a roof does lower down; with the
## halves of the ridges beside it running off across it.
static func _ridge_surface(
	axis: Vector2i, cell: Vector3i, voxel_at: Callable
) -> Array[PackedVector3Array]:
	var across := Vector2i(axis.y, axis.x)
	var main := PackedVector3Array([slope(across), slope(-across)])
	var branches: Array[PackedVector3Array] = [main]
	if not voxel_at.is_valid():
		return branches
	for end: Vector2i in [axis, -axis]:
		var next: int = voxel_at.call(cell + _step(end))
		if shape_of(Voxels.block_of(next)) == Shape.RIDGE:
			continue
		if Voxels.is_roof(voxel_at.call(cell + _step(end) + Vector3i.DOWN)):
			main.append(slope(end))
	branches[0] = main
	for side: Vector2i in [across, -across]:
		var next := Voxels.block_of(voxel_at.call(cell + _step(side)))
		if shape_of(next) == Shape.RIDGE and axis_of(next) == across:
			var half := Vector3(-STEEP * 0.5 * (side.x + side.y), STEEP * side.x, STEEP * side.y)
			branches.append(PackedVector3Array([slope(axis), slope(-axis), half]))
	return branches


## Whether a ridge stands in `cell` (an invalid `voxel_at`: no).
static func _ridge_at(cell: Vector3i, voxel_at: Callable) -> bool:
	return voxel_at.is_valid() and shape_of(Voxels.block_of(voxel_at.call(cell))) == Shape.RIDGE


## Which way the slope in a voxel faces (ZERO: not a slope).
static func _slope_front(voxel: int) -> Vector2i:
	var block := Voxels.block_of(voxel)
	return front_of(block) if shape_of(block) == Shape.SLOPE else Vector2i.ZERO


static func _across(way: Vector2i, front: Vector2i) -> bool:
	return way != Vector2i.ZERO and way.x * front.x + way.y * front.y == 0


static func _step(way: Vector2i) -> Vector3i:
	return Vector3i(way.x, 0, way.y)


static func _build() -> bool:
	for covering in COVERINGS.size():
		var prefix: String = COVERINGS[covering][0]
		var groups := [
			["", Shape.SLOPE, ""],
			["_GENTLE", Shape.GENTLE, "_GENTLE"],
			["_GENTLE_HIGH", Shape.GENTLE_HIGH, "_GENTLE"],
		]
		for group: Array in groups:
			var blocks := []
			for way in WAYS.size():
				var block: int = Tiles.Block[prefix + group[0] + FACINGS[way]]
				blocks.append(block)
				_shapes[block] = group[1]
				_coverings[block] = covering
				_items[block] = Items.Id[prefix + group[2]]
				_fronts[block] = WAYS[way]
			_facings[blocks[0]] = blocks
		for ridge: Array in [["_RIDGE", Vector2i(1, 0)], ["_RIDGE_NS", Vector2i(0, 1)]]:
			var block: int = Tiles.Block[prefix + ridge[0]]
			_shapes[block] = Shape.RIDGE
			_coverings[block] = covering
			_items[block] = Items.Id[prefix + "_RIDGE"]
			_axes[block] = ridge[1]
		for suffix: String in ITEMS:
			var item: int = Items.Id[prefix + suffix]
			_placing[item] = [Tiles.Block[prefix + suffix], COVERINGS[covering][2], ITEMS[suffix]]
		_dormers[COVERINGS[covering][3]] = covering
	return true
