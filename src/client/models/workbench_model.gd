class_name WorkbenchModel
extends RefCounted
## The workbench: a carpenter's beech bench two tiles long (32 x 16
## voxels, its front towards +z): a thick laminated top with a vise at its
## left end, under it an open shelf, four small drawers, two large ones and
## a cupboard, legs on sled feet; on the top, a small iron anvil, a hammer
## and a saw.

const SIZE := Vector3i(32, 20, 16)
## Beech: the top's strips, the frame and the fronts (dark to light).
const TOP := ["#c18a53", "#d29a62", "#ddaa72", "#e7b981"]
const FRAME := ["#9f6c3c", "#b98049", "#c99157"]
const FRONT := ["#cf9a62", "#e0ad75", "#eabb85"]
const END_GRAIN := ["#a66d3c", "#b8804b"]
const RECESS := "#7c5130"
const PULL := "#3f2614"
const IRON := ["#34363d", "#565a63", "#7d818c", "#aeb2bc"]
const HANDLE := ["#5f3b1f", "#7f532c"]
## Rows (y) of the top, and where the cupboard stands under it.
const TOP_Y := 12
const BODY := Rect2i(4, 2, 24, 7)


static func build() -> VoxelGrid:
	var grid := VoxelGrid.new(SIZE)
	_frame(grid)
	_cabinet(grid)
	_top(grid)
	_vise(grid)
	_anvil(grid, Vector3i(24, TOP_Y + 3, 7))
	_hammer(grid)
	_saw(grid)
	return grid


static func _v(hex: String) -> int:
	return VoxelGrid.voxel(Color(hex))


## Legs on sled feet at both ends, and the rails holding the top.
static func _frame(grid: VoxelGrid) -> void:
	for x0: int in [2, 27]:
		grid.box(Vector3i(x0, 0, 1), Vector3i(x0 + 2, 1, 14), _v(FRAME[1]))
		grid.box(Vector3i(x0, 1, 1), Vector3i(x0 + 2, 1, 14), _v(FRAME[2]))
		for z0: int in [2, 12]:
			grid.box(Vector3i(x0, 2, z0), Vector3i(x0 + 1, TOP_Y - 1, z0 + 1), _v(FRAME[1]))
			grid.box(Vector3i(x0 + 1, 2, z0), Vector3i(x0 + 1, TOP_Y - 1, z0 + 1), _v(FRAME[0]))
		grid.box(Vector3i(x0, TOP_Y - 2, 2), Vector3i(x0 + 1, TOP_Y - 1, 13), _v(FRAME[1]))
	# A low rail from foot to foot, behind the cupboard's plinth.
	grid.box(Vector3i(4, 1, 7), Vector3i(27, 1, 8), _v(FRAME[0]))


## The cupboard: the open shelf under the top, then four small drawers,
## two large ones and a door with its hinges, between stiles.
static func _cabinet(grid: VoxelGrid) -> void:
	var low := BODY.position.y
	var high := BODY.end.y - 1
	var left := BODY.position.x
	var right := BODY.end.x - 1
	grid.box(Vector3i(left, low, 3), Vector3i(right, high, 13), _v(FRAME[1]))
	grid.box(Vector3i(left, low - 1, 4), Vector3i(right, low - 1, 12), _v(RECESS))
	# The open shelf: a board over the drawers, a dark back behind the gap.
	grid.box(Vector3i(left, high + 1, 3), Vector3i(right, high + 1, 13), _v(FRAME[0]))
	grid.box(Vector3i(left, high + 1, 13), Vector3i(right, high + 1, 13), _v(FRAME[0]))
	grid.box(Vector3i(left, high + 2, 3), Vector3i(right, TOP_Y - 1, 4), _v(RECESS))
	# Four small drawers: fronts of one voxel between recessed rails.
	for y in range(low, high + 1, 2):
		grid.box(Vector3i(5, y, 14), Vector3i(10, y, 14), _v(FRONT[1]))
		grid.box(Vector3i(5, y, 14), Vector3i(10, y, 14), _shade_front())
		grid.box(Vector3i(7, y, 14), Vector3i(8, y, 14), _v(PULL))
	# Two large drawers, their finger holes cut in their top edge.
	for y0: int in [low, low + 4]:
		grid.box(Vector3i(12, y0, 14), Vector3i(19, y0 + 2, 14), _shade_front())
		grid.box(Vector3i(15, y0 + 2, 14), Vector3i(16, y0 + 2, 14), _v(PULL))
	# The door, its hinges on the right, its finger hole at the top left.
	grid.box(Vector3i(21, low, 14), Vector3i(26, high, 14), _shade_front())
	grid.box(Vector3i(22, high, 14), Vector3i(23, high, 14), _v(PULL))
	for y: int in [low + 1, high - 1]:
		grid.set_voxel(Vector3i(26, y, 15), _v(IRON[3]))
	# Stiles between the sections.
	for x: int in [left, 11, 20, right]:
		grid.box(Vector3i(x, low, 13), Vector3i(x, high, 13), _v(FRAME[0]))


## A front panel's shade: lighter at its top, darker at its foot.
static func _shade_front() -> Callable:
	return func(p: Vector3i) -> int:
		var t := HashUtil.unit2(0xB3, p.x / 3, p.y)
		return _v(FRONT[clampi(int(t * 2.4 + (p.y % 2) * 0.4), 0, 2)])


## The top: strips of beech along its length, end grain at both ends.
static func _top(grid: VoxelGrid) -> void:
	var strips := func(p: Vector3i) -> int:
		if p.x == 0 or p.x == SIZE.x - 1:
			return _v(END_GRAIN[(p.z + p.y) % 2])
		var shade := int(HashUtil.unit2(0x7A, p.z, 0) * 3.0)
		if p.y == TOP_Y + 2 and HashUtil.unit2(0x7B, p.x / 2, p.z) < 0.12:
			shade = maxi(shade - 1, 0)
		return _v(TOP[shade + (1 if p.y == TOP_Y + 2 else 0)])
	grid.box(Vector3i(0, TOP_Y, 1), Vector3i(SIZE.x - 1, TOP_Y + 2, 14), strips)


## The front vise at the left end: a wooden jaw under the top's edge, the
## end of its iron screw and its handle hanging down.
static func _vise(grid: VoxelGrid) -> void:
	grid.box(Vector3i(0, TOP_Y - 3, 14), Vector3i(5, TOP_Y - 1, 15), _v(FRAME[2]))
	grid.box(Vector3i(0, TOP_Y - 3, 15), Vector3i(5, TOP_Y - 3, 15), _v(FRAME[1]))
	grid.box(Vector3i(2, TOP_Y - 2, 15), Vector3i(3, TOP_Y - 2, 15), _v(IRON[2]))
	grid.box(Vector3i(2, 4, 15), Vector3i(2, TOP_Y - 3, 15), _v(IRON[1]))
	grid.set_voxel(Vector3i(2, 3, 15), _v(IRON[3]))


## A small iron anvil standing on the top (`at`: the middle of its foot).
static func _anvil(grid: VoxelGrid, at: Vector3i) -> void:
	grid.box(at + Vector3i(-2, 0, -2), at + Vector3i(2, 0, 2), _v(IRON[0]))
	grid.box(at + Vector3i(-1, 1, -1), at + Vector3i(1, 1, 1), _v(IRON[1]))
	grid.box(at + Vector3i(-2, 2, -1), at + Vector3i(3, 2, 1), _v(IRON[1]))
	grid.box(at + Vector3i(-2, 3, -1), at + Vector3i(3, 3, 1), _v(IRON[3]))
	# The horn, tapering to a point on the left.
	grid.box(at + Vector3i(-3, 2, 0), at + Vector3i(-3, 3, 0), _v(IRON[2]))
	grid.set_voxel(at + Vector3i(-4, 3, 0), _v(IRON[3]))


## An iron hammer lying on the top, near the front.
static func _hammer(grid: VoxelGrid) -> void:
	var y := TOP_Y + 3
	grid.box(Vector3i(6, y, 11), Vector3i(11, y, 11), _v(HANDLE[1]))
	grid.set_voxel(Vector3i(6, y, 11), _v(HANDLE[0]))
	grid.box(Vector3i(12, y, 10), Vector3i(13, y + 1, 12), _v(IRON[2]))
	grid.box(Vector3i(12, y + 1, 10), Vector3i(13, y + 1, 12), _v(IRON[3]))


## An iron saw lying on the top, near the back.
static func _saw(grid: VoxelGrid) -> void:
	var y := TOP_Y + 3
	grid.box(Vector3i(9, y, 3), Vector3i(16, y, 4), _v(IRON[3]))
	for x in range(9, 17, 2):
		grid.set_voxel(Vector3i(x, y, 3), _v(IRON[1]))
	grid.box(Vector3i(17, y, 3), Vector3i(19, y, 5), _v(HANDLE[1]))
	grid.set_voxel(Vector3i(18, y, 4), _v(HANDLE[0]))
