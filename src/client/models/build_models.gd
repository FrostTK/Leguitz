class_name BuildModels
extends RefCounted
## The voxel models of walls, pillars and beams (phase 8, step 6; see
## BuildShapes), DecorModels' ways. A wall: its arms to the sides it joins
## (FENCE_SIDES bits, as a fence's), a post where it does not run straight
## through, stones in mortar and a capping. A pillar: a fluted stone column,
## a brick pillar, a chamfered wooden post, with its base and its capital
## where its stack starts and ends (BuildShapes.CAPITAL, BASE bits). A beam:
## square timber along its axis, its grain running along it.

## Each wall's stones (mortar, dark, mid, light), and its capping.
const WALL_COLORS := {
	Tiles.Block.COBBLESTONE_WALL: ["#3f3d45", "#66646e", "#7d7b85", "#9a98a2", "#8d8b95"],
	Tiles.Block.STONE_BRICK_WALL: ["#45434e", "#605e6a", "#7a7884", "#93919c", "#a3a1ab"],
	Tiles.Block.BRICK_WALL: ["#c9bba8", "#823b2a", "#a24e38", "#bd6a4f", "#a3a1ab"],
	Tiles.Block.MOSSY_STONE_WALL: ["#3f3d45", "#5d7a3a", "#7d7b85", "#9a98a2", "#738f47"],
	Tiles.Block.SANDSTONE_WALL: ["#efe2bf", "#b99a5e", "#d6b97e", "#e8d29e", "#f1dda8"],
}
const STONE := ["#7d7b88", "#9e9ca8", "#bab8c3", "#d4d3db"]
const BRICK := ["#c9bba8", "#823b2a", "#a24e38", "#bd6a4f"]


## The model of a block (null: not one of these).
static func build(block: int, variant: int) -> VoxelGrid:
	if BuildShapes.is_wall(block):
		return wall(block, variant)
	if BuildShapes.is_pillar(block):
		return pillar(block, variant)
	if BuildShapes.is_beam(block):
		var wood: String = BuildShapes.BEAMS[BuildShapes.beam_kind(block)][2]
		return beam(wood, BuildShapes.beam_axis(block))
	return null


## The color of a block's chips (BlockColors; Color(0, 0, 0, 0): not one).
static func color_of(kind: int) -> Color:
	if BuildShapes.is_wall(kind):
		return Color(WALL_COLORS[kind][2])
	if BuildShapes.is_pillar(kind):
		return Color(OpeningModels.WOODS["OAK"][2] if kind == Tiles.Block.WOOD_POST else STONE[2])
	if BuildShapes.is_beam(kind):
		var wood: String = BuildShapes.BEAMS[BuildShapes.beam_kind(kind)][2]
		return Color(OpeningModels.WOODS[wood][2])
	return Color(0, 0, 0, 0)


## A wall joining the sides of `sides` (ObjectShapes.FENCE_SIDES bits:
## north, east, south, west): 6 voxels thick, 13 high, a post 8 square and
## 16 high in the middle unless it runs straight through.
static func wall(block: int, sides: int) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 16, 16))
	var colors: Array = WALL_COLORS[block]
	var straight := sides == 5 or sides == 10
	if not straight:
		_stones(grid, Vector3i(4, 0, 4), Vector3i(11, 15, 11), colors)
	for bit in ObjectShapes.FENCE_SIDES.size():
		var way: Vector2i = ObjectShapes.FENCE_SIDES[bit]
		if sides & (1 << bit) == 0:
			continue
		var low := Vector3i(5, 0, 5)
		var high := Vector3i(10, 12, 10)
		if way.x > 0:
			high.x = 15
		elif way.x < 0:
			low.x = 0
		elif way.y > 0:
			high.z = 15
		else:
			low.z = 0
		_stones(grid, low, high, colors)
	return grid


## Stones in mortar filling a box, a capping on top: courses of 3 voxels,
## stones 4 or 5 long, each its own shade (along the box's length).
static func _stones(grid: VoxelGrid, low: Vector3i, high: Vector3i, colors: Array) -> void:
	for z in range(low.z, high.z + 1):
		for y in range(low.y, high.y + 1):
			for x in range(low.x, high.x + 1):
				var course := y / 4
				var along := x + z + course * 3
				var stone := along / 5
				var hex: String
				if y == high.y:
					hex = colors[4]
				elif y % 4 == 3 or along % 5 == 4:
					hex = colors[0]
				else:
					var shade := HashUtil.hash2(0x57, stone, course) % 3
					hex = colors[1 + shade]
				grid.set_voxel(Vector3i(x, y, z), _v(hex))


## A pillar: a stone column, a brick pillar or a wooden post, its base and
## its capital as `bits` says (BuildShapes.BASE, CAPITAL).
static func pillar(block: int, bits: int) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 16, 16))
	var base := bits & BuildShapes.BASE != 0
	var capital := bits & BuildShapes.CAPITAL != 0
	var from := 3 if base else 0
	var to := 12 if capital else 15
	match block:
		Tiles.Block.STONE_COLUMN:
			# A fluted round shaft.
			for y in range(from, to + 1):
				for z in 16:
					for x in 16:
						var d := Vector2(x - 7.5, z - 7.5)
						if d.length() > 4.6:
							continue
						var flute := int(round((d.angle() + PI) / TAU * 12.0)) % 2 == 0
						var hex: String = STONE[1] if flute and d.length() > 3.6 else STONE[2]
						grid.set_voxel(Vector3i(x, y, z), _v(hex))
			if base:
				grid.box(Vector3i(1, 0, 1), Vector3i(14, 1, 14), _v(STONE[1]))
				grid.disc(Vector2(8, 8), 6.0, 2, _v(STONE[2]))
			if capital:
				grid.disc(Vector2(8, 8), 6.0, 13, _v(STONE[2]))
				grid.box(Vector3i(1, 14, 1), Vector3i(14, 15, 14), _v(STONE[3]))
				grid.box(Vector3i(1, 14, 1), Vector3i(14, 14, 14), _v(STONE[2]))
		Tiles.Block.BRICK_PILLAR:
			for y in range(from, to + 1):
				for z in range(2, 14):
					for x in range(2, 14):
						var along := x + z
						var mortar := y % 3 == 2 or (along + (y / 3) * 3) % 6 == 5
						grid.set_voxel(Vector3i(x, y, z), _v(BRICK[0] if mortar else BRICK[2]))
			if base:
				grid.box(Vector3i(1, 0, 1), Vector3i(14, 2, 14), _v(STONE[1]))
			if capital:
				grid.box(Vector3i(1, 13, 1), Vector3i(14, 15, 14), _v(STONE[2]))
		_:
			var wood: Array = OpeningModels.WOODS["OAK"]
			for y in range(from, to + 1):
				for z in range(4, 12):
					for x in range(4, 12):
						# Chamfered corners, grain up the post.
						if (x == 4 or x == 11) and (z == 4 or z == 11):
							continue
						var hex: String = wood[1] if (x + y * 3) % 7 == 0 else wood[2]
						if x == 4 or z == 4:
							hex = wood[3]
						grid.set_voxel(Vector3i(x, y, z), _v(hex))
			if base:
				grid.box(Vector3i(2, 0, 2), Vector3i(13, 2, 13), _v(STONE[1]))
			if capital:
				grid.box(Vector3i(2, 13, 2), Vector3i(13, 15, 13), _v(wood[2]))
				grid.box(Vector3i(2, 15, 2), Vector3i(13, 15, 13), _v(wood[3]))
	return grid


## A beam of `wood` (OpeningModels.WOODS' names) along `axis`: 10 voxels
## square, its whole cell long, its grain along it, its edges darker.
static func beam(wood: String, axis: Vector3i) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 16, 16))
	var colors: Array = OpeningModels.WOODS[wood]
	for along in 16:
		for a in range(3, 13):
			for b in range(3, 13):
				var edge := a == 3 or a == 12 or b == 3 or b == 12
				var hex: String = colors[1] if edge else colors[2]
				if not edge and (a * 5 + b * 3 + along / 5) % 9 == 0:
					hex = colors[1]
				elif not edge and (a + b) % 4 == 0:
					hex = colors[3]
				var at := Vector3i(along, a, b)
				if axis.y != 0:
					at = Vector3i(a, along, b)
				elif axis.z != 0:
					at = Vector3i(a, b, along)
				grid.set_voxel(at, _v(hex))
	return grid


static func _v(hex: String) -> int:
	return VoxelGrid.voxel(Color(hex))
