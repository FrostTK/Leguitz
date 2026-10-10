class_name ChunkJob
extends RefCounted
## What a chunk build reads (ChunkMesher.build): the voxels and column
## tops of the chunk and of its 8 neighbors (3 x 3, row by row; empty
## arrays where not loaded), and more.

var coord := Vector2i.ZERO
var voxels: Array[PackedInt32Array] = []
var tops: Array[PackedByteArray] = []
## The chunk's columns where something rises over the terrain (see
## ChunkData.raised).
var raised: Dictionary[int, int] = {}
## Model variants per block (0 = not a prop), see PropLibrary.
var variants := PackedByteArray()
## Row the view cuts the world at (HEIGHT: no cut), for the surface map,
## and the columns it cuts (chunk and border, SPAN x SPAN, 1 where it
## does; empty: all, see CutRegion.columns_of).
var cut_row := GameConst.WORLD_HEIGHT
var cut_columns := PackedByteArray()
## Surface map only (the cut moved): no geometry.
var map_only := false
## Bumped by every new build of the chunk: older results are dropped.
var serial := 0
## The chunk's columns' biomes (the seasons: SeasonLook.prop_bits).
var biome := PackedByteArray()
## The tints of the chunk and of its neighbors (Tints.pack, by cell).
var tints: Dictionary[Vector3i, int] = {}


static func of_chunk(chunk: ChunkData, neighbor: Callable) -> ChunkJob:
	var job := ChunkJob.new()
	job.coord = chunk.coord
	job.raised = chunk.raised.duplicate()
	job.biome = chunk.biome.duplicate()
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var other: ChunkData = (
				chunk if dx == 0 and dz == 0 else neighbor.call(chunk.coord + Vector2i(dx, dz))
			)
			job.voxels.append(other.voxels if other != null else PackedInt32Array())
			job.tops.append(other.tops if other != null else PackedByteArray())
			if other != null:
				job.tints.merge(other.tints)
	return job
