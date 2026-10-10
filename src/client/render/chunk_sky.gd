class_name ChunkSky
extends RefCounted
## The sky light of a chunk build (ChunkMesher, on a worker thread): worked
## out over the chunk and its 8 neighbors (light goes LightField.MAX cells
## at most; a missing neighbor is rock), read per padded cell (see
## ChunkMesher.pad), and the chunk's own part kept for the client
## (ChunkMesher.Result.sky_open / sky_levels, WorldView3D.sky_at).

const SIZE := ChunkMesher.SIZE
const SPAN := ChunkMesher.SPAN
const HEIGHT := ChunkMesher.HEIGHT
## The region's span, and where a padded column lies in it.
const REGION_SPAN := SIZE * 3
const REGION_OFFSET := (SIZE - 1) * REGION_SPAN + SIZE - 1

## A row of columns standing for a missing neighbor: rock (no light from
## there), and their tops.
static var _solid_row := _build_solid_row()
static var _solid_tops := _build_solid_tops()


## The sky light (0..LightField.MAX) of the padded cell at `index`, from
## the region's [levels, open] (see field).
static func level(levels: PackedByteArray, open: PackedInt32Array, index: int) -> int:
	var pz := index / (SPAN * HEIGHT)
	var at := index + (REGION_OFFSET + pz * (REGION_SPAN - SPAN)) * HEIGHT
	if at % HEIGHT >= open[at / HEIGHT]:
		return LightField.MAX
	return levels[at]


## The sky light over the chunk and its neighbors (LightField.sky).
static func field(job: ChunkJob) -> Array:
	var voxels := PackedInt32Array()
	var tops := PackedByteArray()
	for rz in REGION_SPAN:
		var lz := rz % SIZE
		for chunk_x in 3:
			# A row of a chunk's columns lies in one piece.
			var source := (rz / SIZE) * 3 + chunk_x
			var chunk := job.voxels[source]
			if chunk.is_empty():
				voxels.append_array(_solid_row)
				tops.append_array(_solid_tops)
				continue
			voxels.append_array(chunk.slice(lz * SIZE * HEIGHT, (lz + 1) * SIZE * HEIGHT))
			tops.append_array(job.tops[source].slice(lz * SIZE, (lz + 1) * SIZE))
	return LightField.sky(voxels, tops, REGION_SPAN)


## Keeps the chunk's own part of the region's sky light.
static func keep(result: ChunkMesher.Result, sky: Array) -> void:
	var levels: PackedByteArray = sky[0]
	var open: PackedInt32Array = sky[1]
	for lz in SIZE:
		for lx in SIZE:
			var column := (lz + SIZE) * REGION_SPAN + lx + SIZE
			result.sky_open.append(open[column])
			result.sky_levels.append_array(levels.slice(column * HEIGHT, (column + 1) * HEIGHT))


static func _build_solid_row() -> PackedInt32Array:
	var row := PackedInt32Array()
	row.resize(SIZE * HEIGHT)
	row.fill(Voxels.of_block(Tiles.Block.STONE))
	return row


static func _build_solid_tops() -> PackedByteArray:
	var tops := PackedByteArray()
	tops.resize(SIZE)
	tops.fill(HEIGHT)
	return tops
