class_name ChestModel
extends RefCounted
## The chest: an oak box of planks (14 x 13 x 12 voxels, its front towards
## +z) bound with dark iron at its corners and around its lid, a gold latch
## in front.

const SIZE := Vector3i(14, 13, 12)
const WOOD := ["#7a5130", "#9a6a3c", "#b37f4b", "#c99560"]
const IRON := ["#2e2f35", "#4b4d55", "#6f727c"]
const LATCH := ["#8f6a1c", "#d9b443", "#f3d878"]
## The lid's first row.
const LID := 8


static func build() -> VoxelGrid:
	var grid := VoxelGrid.new(SIZE)
	var right := SIZE.x - 1
	var top := SIZE.y - 1
	var front := SIZE.z - 1
	grid.box(Vector3i.ZERO, Vector3i(right, top, front), _planks())
	# The lid sits a voxel proud of the box at the front and the sides.
	grid.box(Vector3i(0, LID - 1, 0), Vector3i(right, LID - 1, front), _v(WOOD[0]))
	for x: int in [0, right]:
		for z: int in [0, front]:
			grid.box(Vector3i(x, 0, z), Vector3i(x, top, z), _v(IRON[1]))
	# Iron around the lid's edge and on its top's border.
	for y: int in [LID, top]:
		grid.box(Vector3i(0, y, front), Vector3i(right, y, front), _v(IRON[1]))
		grid.box(Vector3i(0, y, 0), Vector3i(0, y, front), _v(IRON[1]))
		grid.box(Vector3i(right, y, 0), Vector3i(right, y, front), _v(IRON[1]))
	grid.box(Vector3i(1, top, 0), Vector3i(right - 1, top, 0), _v(IRON[0]))
	grid.box(Vector3i(0, 0, front), Vector3i(right, 0, front), _v(IRON[0]))
	# The latch, over the seam.
	var middle := SIZE.x / 2
	grid.box(Vector3i(middle - 1, LID - 3, front), Vector3i(middle, LID + 1, front), _v(LATCH[1]))
	grid.box(Vector3i(middle - 1, LID + 1, front), Vector3i(middle, LID + 1, front), _v(LATCH[2]))
	grid.box(Vector3i(middle - 1, LID - 3, front), Vector3i(middle, LID - 3, front), _v(LATCH[0]))
	grid.set_voxel(Vector3i(middle - 1, LID - 1, front), _v(IRON[0]))
	return grid


static func _v(hex: String) -> int:
	return VoxelGrid.voxel(Color(hex))


## Planks lying across, a darker line between two boards, the grain here
## and there.
static func _planks() -> Callable:
	return func(p: Vector3i) -> int:
		if p.y % 3 == 2:
			return _v(WOOD[1])
		var grain := HashUtil.unit2(0xC4E5, p.x / 3 + p.z * 5, p.y)
		return _v(WOOD[3] if grain > 0.82 else WOOD[2])
