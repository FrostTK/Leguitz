class_name LiquidFaces
extends RefCounted
## What chunk builds (ChunkMesher) need to know of liquids: which liquid a
## voxel is, how high it fills its cell (Fluids.surface), and which sides
## of a liquid show: open to the air or an object (a waterfall, the edge of
## a flow), or to the same liquid lower (a step).

enum Liquid { NONE, WATER, LAVA }

const SIDE_STEPS := ChunkMesher.SIDE_STEPS

## Per voxel id: its Liquid and how high it fills its cell (copy them into
## locals on worker threads).
static var kinds := _build_kinds()
static var heights := _build_heights()


## How high the liquid at `index` (padded voxels) reaches in its cell: 1,
## up to the top, when the same liquid lies above it.
static func top(
	voxels: PackedInt32Array, liquids: PackedByteArray, surfaces: PackedFloat32Array, index: int
) -> float:
	var voxel := voxels[index]
	if index % ChunkMesher.HEIGHT + 1 < ChunkMesher.HEIGHT:
		if liquids[voxels[index + 1]] == liquids[voxel]:
			return 1.0
	return surfaces[voxel]


## Which sides of the liquid at `index` show (a bit per ChunkMesher.Side).
static func sides(
	voxels: PackedInt32Array,
	flags: PackedByteArray,
	liquids: PackedByteArray,
	surfaces: PackedFloat32Array,
	index: int
) -> int:
	# Inlined (it runs for every liquid voxel: oceans are deep).
	var voxel := voxels[index]
	var kind := liquids[voxel]
	var has_above := index % ChunkMesher.HEIGHT + 1 < ChunkMesher.HEIGHT
	var here := 1.0 if has_above and liquids[voxels[index + 1]] == kind else surfaces[voxel]
	var shown := 0
	for side in 4:
		var at: int = index + SIDE_STEPS[side]
		var other := voxels[at]
		if flags[other] & ChunkMesher.CUBE != 0:
			continue
		if liquids[other] == kind:
			if surfaces[other] >= here - 0.001:
				continue
			if has_above and liquids[voxels[at + 1]] == kind:
				continue
		shown |= 1 << side
	return shown


static func _build_kinds() -> PackedByteArray:
	var table := PackedByteArray()
	table.resize(Voxels.used_ids())
	for voxel in table.size():
		if Voxels.is_water(voxel):
			table[voxel] = Liquid.WATER
		elif Voxels.is_lava(voxel):
			table[voxel] = Liquid.LAVA
	return table


static func _build_heights() -> PackedFloat32Array:
	var table := PackedFloat32Array()
	table.resize(Voxels.used_ids())
	for voxel in table.size():
		if Voxels.is_liquid(voxel):
			table[voxel] = Fluids.surface(voxel)
	return table
