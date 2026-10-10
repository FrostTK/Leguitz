class_name ChunkProps
extends RefCounted
## The objects of a chunk build (ChunkMesher.Result.props, model instances,
## split from ChunkMesher): trees, plants, rocks, what players place. Each
## gets a variant, a quarter turn and a slight shade from its tile, so the
## same seed always grows the same forest (the same as physics:
## ObjectShapes); what players place keeps its turn (none, or the way it
## faces); a wide object (a workbench, a big gate) is drawn from its left
## end, turned the way it faces, over both its tiles. INSTANCE_CUSTOM.a
## holds its sky light and season bits (the caller's `sky`) and its wind
## phase; cloth with a tint (curtains, rugs: Tints.dyed) adds DYED and
## carries the color in INSTANCE_CUSTOM.rgb (sRGB; voxel.gdshaderinc
## dyes its PAINT voxels). Fences and rugs show the sides they join
## (ObjectShapes.FENCE_SIDES bits; rugs of one tint); a rug lying under
## something (ChunkData.rugs) is drawn under it. Thread-safe.

const SIZE := GameConst.CHUNK_SIZE
const SPAN := SIZE + 2
const HEIGHT := GameConst.WORLD_HEIGHT
const SEA := GameConst.SEA_LEVEL
const STRIDE_X := HEIGHT
const STRIDE_Z := SPAN * HEIGHT
## INSTANCE_CUSTOM.a's bit telling dyed cloth (over the sky light, 0 to
## 15, and the seasons' 16, 32 and 64: SeasonLook.prop_bits).
const DYED := 128


## Adds what stands in voxel (lx, y, lz) of a chunk being built (`base`:
## its column in the padded `voxels`), and the rug under it if any.
static func add(
	result: ChunkMesher.Result,
	job: ChunkJob,
	voxel: int,
	voxels: PackedInt32Array,
	base: int,
	lx: int,
	y: int,
	lz: int,
	origin: Vector2i,
	sky: int
) -> void:
	var cell := Vector3i(origin.x + lx, y, origin.y + lz)
	var tint: int = job.tints.get(cell, 0) if not job.tints.is_empty() else 0
	_add(result, job, voxel, voxels, base, Vector3i(lx, y, lz), origin, sky, tint)
	if not job.rugs.is_empty() and job.rugs.has(cell):
		var rug: int = job.rugs[cell]
		_add(result, job, ChunkData.RUG, voxels, base, Vector3i(lx, y, lz), origin, sky, rug)


static func _add(
	result: ChunkMesher.Result,
	job: ChunkJob,
	voxel: int,
	voxels: PackedInt32Array,
	base: int,
	at: Vector3i,
	origin: Vector2i,
	sky: int,
	tint: int
) -> void:
	var block := Voxels.block_of(voxel)
	var count := job.variants[block]
	if count == 0:
		return
	var y := at.y
	var tile := origin + Vector2i(at.x, at.z)
	var h := HashUtil.hash2(ObjectShapes.SALT, tile.x, tile.y)
	var height := float(y - SEA)
	if y > 0 and Voxels.is_liquid(voxels[base + y - 1]):
		height -= 1.0 - Fluids.surface(voxels[base + y - 1])
	height -= ObjectShapes.SUNK.get(ObjectShapes.base_kind(block), 0.0)
	# Where it stands and which version: the same as physics (ObjectShapes).
	var offset := Vector2(ObjectShapes.offset_at(block, tile)) / 16.0
	var foot := Vector3(at.x + 0.5 + offset.x, height, at.z + 0.5 + offset.y)
	var turn := ChunkMesher.prop_turn(tile)
	if ObjectShapes.front_of(block) != Vector2i.ZERO:
		turn = Basis(Vector3.UP, ObjectShapes.turn_of(block))
	elif (
		Mining.FLOOR_OBJECTS.has(ObjectShapes.base_kind(block))
		or Farming.bed_of(block) == Farming.Bed.TRELLIS
	):
		turn = Basis()
	if ObjectShapes.is_wide_left(block):
		var right := ObjectShapes.wide_right(block)
		foot += Vector3(right.x, 0.0, right.y) * 0.5
	var shade := 0.93 + ((h >> 16) & 15) / 15.0 * 0.14
	var warmth := 0.97 + ((h >> 20) & 7) / 7.0 * 0.06
	# Its wind phase, after the sky light it stands in (see voxel.gdshader).
	var phase := ((h >> 24) & 255) / 256.0
	var custom := Color(shade * warmth, shade, shade / warmth, sky + phase)
	var dye := Tints.glass_of(tint)
	if dye >= 0 and Tints.dyed(block):
		var color := Tints.color(dye)
		custom = Color(color.r, color.g, color.b, sky + DYED + phase)
	var variant := ObjectShapes.variant_at(block, tile)
	var index := base + y
	if block == Tiles.Block.FENCE:
		variant = _fence_sides(voxels, index)
	elif block == Tiles.Block.RUG:
		variant = _rug_sides(job, voxels, index, Vector3i(tile.x, y, tile.y), tint)
	elif ObjectShapes.JOINING.has(block):
		variant = _joined_sides(block, voxels, index)
	elif Openings.is_door(block):
		# Hung on its right when a door stands on its left (a double door).
		var left := Openings.left_of(block)
		var there := voxels[index + left.x * STRIDE_X + left.y * STRIDE_Z]
		var pair := Voxels.block_of(there)
		var paired := (
			Openings.is_door(pair) and ObjectShapes.front_of(pair) == ObjectShapes.front_of(block)
		)
		variant = 1 if paired else 0
	var key := Vector2i(ObjectShapes.model_block(block), variant % count)
	if not result.props.has(key):
		result.props[key] = []
	result.props[key].append([Transform3D(turn, foot), custom])


## The sides a fence at `index` (padded voxels) joins (ObjectShapes.FENCE_SIDES
## bits: north, east, south, west).
static func _fence_sides(voxels: PackedInt32Array, index: int) -> int:
	var sides := 0
	for bit in ObjectShapes.FENCE_SIDES.size():
		var side: Vector2i = ObjectShapes.FENCE_SIDES[bit]
		if ObjectShapes.fence_joins(voxels[index + side.x * STRIDE_X + side.y * STRIDE_Z]):
			sides |= 1 << bit
	return sides


## The sides bars or a railing at `index` (padded voxels) join
## (Openings.joins; FENCE_SIDES bits).
static func _joined_sides(block: int, voxels: PackedInt32Array, index: int) -> int:
	var sides := 0
	for bit in ObjectShapes.FENCE_SIDES.size():
		var side: Vector2i = ObjectShapes.FENCE_SIDES[bit]
		if Openings.joins(block, voxels[index + side.x * STRIDE_X + side.y * STRIDE_Z]):
			sides |= 1 << bit
	return sides


## The sides a rug in `cell` (`index` in the padded voxels) joins: rugs of
## its tint beside it, lying free or under something (FENCE_SIDES bits).
static func _rug_sides(
	job: ChunkJob, voxels: PackedInt32Array, index: int, cell: Vector3i, tint: int
) -> int:
	var sides := 0
	for bit in ObjectShapes.FENCE_SIDES.size():
		var side: Vector2i = ObjectShapes.FENCE_SIDES[bit]
		var next := cell + Vector3i(side.x, 0, side.y)
		var there := voxels[index + side.x * STRIDE_X + side.y * STRIDE_Z]
		var joins: bool = there == ChunkData.RUG and job.tints.get(next, 0) == tint
		if joins or job.rugs.get(next, -1) == tint:
			sides |= 1 << bit
	return sides
