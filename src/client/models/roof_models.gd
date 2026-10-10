class_name RoofModels
extends RefCounted
## The voxel models of the roofs' objects (phase 8, step 5; see
## RoofBlocks), DecorModels' ways (front +z): a dormer, a window in a small
## gabled box clad in its covering, standing in a roof in a slope's place
## (open at its back and under it: from the attic one looks out of its
## window); a brick chimney, its shaft, or its top (version 1: a stone
## coping and two clay pots, where its smoke comes out: SMOKE).

## Each covering's colors, dark to light (RoofBlocks.COVERINGS' order).
const COVERINGS := [
	["#5e2613", "#83391b", "#b4552e", "#d47448", "#e8936a"],
	["#2b2f37", "#434955", "#5c6371", "#767e8d", "#8f97a5"],
	["#3f3123", "#655039", "#8a7254", "#a88d69", "#bfa582"],
	["#6e5527", "#937537", "#c4a259", "#e0c47e", "#ecd79c"],
]
## A dormer's painted frame, its glass.
const FRAME := ["#8f8775", "#c9c0aa", "#e9e2cf"]
const GLASS := ["#7d9ea8", "#a9c9d2", "#dceef2"]
const BRICK := ["#6a2c1e", "#8e3e2b", "#ad5338"]
const MORTAR := ["#8f8678", "#b8ad9c"]
const COPING := ["#85838e", "#a3a1ab", "#c4c3ca"]
const POT := ["#7a3a1e", "#a8552e", "#c87048"]
## Where the smoke comes out of a chimney's top (from the middle of its
## cell's floor, local units).
const SMOKE := Vector3(0.0, 1.3, 0.0)
## A dormer's roof peaks this high (voxels).
const DORMER_PEAK := 24


## The model of a block (null: not one of these).
static func build(block: int, variant: int) -> VoxelGrid:
	if RoofBlocks.is_dormer(block):
		return dormer(RoofBlocks.covering_of(block))
	if block == Tiles.Block.CHIMNEY:
		return chimney(variant == 1)
	return null


## The color of a block's chips (BlockColors; Color(0, 0, 0, 0): not one).
static func color_of(kind: int) -> Color:
	if RoofBlocks.is_dormer(kind):
		return Color(COVERINGS[RoofBlocks.covering_of(kind)][2])
	if kind == Tiles.Block.CHIMNEY:
		return Color(BRICK[1])
	return Color(0, 0, 0, 0)


## A dormer clad in a covering: its cheeks, its window in a painted frame
## over a sill, its little gabled roof running back into the roof.
static func dormer(covering: int) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, DORMER_PEAK, 16))
	var clad: Array = COVERINGS[covering]
	# The cheeks, in courses of the covering.
	for x: int in [0, 1, 14, 15]:
		for y in 16:
			for z in 16:
				var hex: String = clad[1] if y % 4 == 0 else clad[2 if x in [0, 15] else 1]
				grid.set_voxel(Vector3i(x, y, z), _v(hex))
	# The front: an apron under the sill, the framed window, a gable over it.
	for x in range(2, 14):
		for y in 16:
			var hex: String = FRAME[1]
			if y < 3:
				hex = clad[2] if y % 2 == 0 else clad[1]
			elif y == 3:
				hex = FRAME[0]
			elif x >= 4 and x <= 11 and y >= 5 and y <= 13 and x != 7 and x != 8 and y != 9:
				hex = GLASS[2] if x + y == 13 or x + y == 14 else GLASS[1 if y > 9 else 0]
			elif y == 4 or y == 14:
				hex = FRAME[2]
			grid.set_voxel(Vector3i(x, y, 15), _v(hex))
		grid.set_voxel(Vector3i(x, 3, 14), _v(FRAME[0]))
	# The roof: 45 degrees each side of a ridge along z, its courses along z.
	for x in 16:
		var top := 16 + mini(x, 15 - x) + 1
		for z in 16:
			for y in range(16, top):
				var hex: String = clad[1]
				if y == top - 1:
					hex = clad[3] if (z % 4) < 3 else clad[2]
				elif z == 15:
					hex = FRAME[1] if y < top - 2 else clad[0]
				grid.set_voxel(Vector3i(x, y, z), _v(hex))
	return grid


## A brick chimney's shaft, 14 voxels square; its `top` crowned with a
## stone coping and two clay pots.
static func chimney(top: bool) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 21 if top else 16, 16))
	var shaft := 13 if top else 16
	for z in range(1, 15):
		for y in shaft:
			for x in range(1, 15):
				grid.set_voxel(Vector3i(x, y, z), _v(_brick(x + z, y)))
	if not top:
		return grid
	for z in 16:
		for x in 16:
			var edge := x == 0 or z == 0 or x == 15 or z == 15
			grid.set_voxel(Vector3i(x, 13, z), _v(COPING[0] if edge else COPING[1]))
			grid.set_voxel(Vector3i(x, 14, z), _v(COPING[1] if edge else COPING[2]))
	for pot_x: int in [3, 9]:
		for y in range(15, 21):
			for z in range(6, 10):
				for x in range(pot_x, pot_x + 4):
					var rim := y == 20 or y == 15
					var inside := x > pot_x and x < pot_x + 3 and z > 6 and z < 9
					if inside and y >= 19:
						grid.set_voxel(Vector3i(x, y, z), _v(MORTAR[0] if y == 19 else "#1c1714"))
						continue
					var hex: String = POT[2] if rim else POT[1 if (x + z) % 3 else 0]
					grid.set_voxel(Vector3i(x, y, z), _v(hex))
	return grid


## A brick wall's color at (along, up): bricks 5 long and 2 high, mortar
## between, every other row offset.
static func _brick(along: int, up: int) -> String:
	var row := up / 3
	if up % 3 == 2:
		return MORTAR[1]
	var place := (along + (3 if row % 2 else 0)) % 6
	if place == 5:
		return MORTAR[0]
	return BRICK[(row + (along + 3 * (row % 2)) / 6) % 3]


static func _v(hex: String) -> int:
	return VoxelGrid.voxel(Color(hex))
