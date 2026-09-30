class_name WorldGenerator
extends RefCounted
## Deterministic world generation, following Minecraft's pipeline:
## seed -> climate noises -> terrain height (splines) -> rivers -> biome
## -> surface rules -> vegetation, plus noise caves and ores underground.
##
## Thread-safe: generate_chunk() only reads shared state, so the server can
## generate many chunks in parallel on worker threads.

const SURFACE_LAYER := 0
const MIN_LAYER := CaveGenerator.MIN_LAYER
const SALT_RAMPS := 40
const RAMP_THRESHOLD := 0.42
## Meters of per-tile noise added to decide where water ends (ragged shores).
const WATER_EDGE_DETAIL := 1.5

## Biomes where a new player may spawn.
const SPAWN_BIOMES := {
	Biomes.Id.PLAINS: true,
	Biomes.Id.FOREST: true,
	Biomes.Id.FLOWER_FOREST: true,
	Biomes.Id.BIRCH_FOREST: true,
	Biomes.Id.MEADOW: true,
	Biomes.Id.SAVANNA: true,
	Biomes.Id.TAIGA: true,
	Biomes.Id.SNOWY_PLAINS: true,
}

var world_seed := 0
var climate: ClimateSampler
var shaper := TerrainShaper.new()
var surface: SurfaceBuilder
var caves: CaveGenerator
var _ramps: FastNoiseLite


class Column:
	extends RefCounted
	var continentalness := 0.0
	var erosion := 0.0
	var weirdness := 0.0
	var temperature := 0.0
	var humidity := 0.0
	var detail := 0.0
	var height := 0.0
	var level := 0
	var river := false
	var water := false
	var biome := Biomes.Id.NONE


func _init(seed_value: int) -> void:
	world_seed = seed_value
	climate = ClimateSampler.new(world_seed)
	surface = SurfaceBuilder.new(world_seed)
	caves = CaveGenerator.new(world_seed)
	_ramps = ClimateSampler.make_fbm(world_seed, SALT_RAMPS, 1.0 / 9.0, 1, 0.0)


func generate_chunk(coord: Vector2i, layer: int = SURFACE_LAYER) -> ChunkData:
	var chunk := ChunkData.new(coord, layer)
	if layer < SURFACE_LAYER:
		caves.generate_chunk(chunk)
	else:
		_generate_surface(chunk)
	return chunk


## Full description of one surface column (used by spawn search, maps and
## the debug screen). Matches generate_chunk() exactly.
func sample_column(tx: int, ty: int) -> Column:
	var grid := ClimateGrid.new(climate, Rect2i(tx, ty, 1, 1))
	return column_from_grid(grid, tx, ty)


func column_from_grid(grid: ClimateGrid, tx: int, ty: int) -> Column:
	grid.sample(tx, ty)
	var column := Column.new()
	column.continentalness = grid.continentalness
	column.erosion = grid.erosion
	column.weirdness = grid.weirdness
	column.temperature = grid.temperature
	column.humidity = grid.humidity
	column.detail = climate.detail.get_noise_2d(tx, ty)
	var smooth := shaper.height(grid.continentalness, grid.erosion, grid.weirdness)
	column.height = smooth + column.detail * WATER_EDGE_DETAIL
	column.river = TerrainShaper.is_river(grid.continentalness, grid.weirdness)
	if column.river:
		column.height = minf(column.height, -1.0)
	column.water = column.height < 0.0
	column.level = 0 if column.water else TerrainShaper.level_for_height(smooth)
	column.biome = Biomes.select(
		grid.continentalness,
		grid.erosion,
		grid.weirdness,
		grid.temperature,
		grid.humidity,
		column.height,
		column.river
	)
	return column


## Closest good spawn tile to the world origin: dry, flat, free, in a
## friendly biome.
func find_spawn_tile(max_radius := 4096) -> Vector2i:
	for radius in range(0, max_radius, 16):
		var steps := maxi(1, int(TAU * radius / 16.0))
		for step in steps:
			var angle := TAU * step / steps
			var tile := Vector2i(roundi(cos(angle) * radius), roundi(sin(angle) * radius))
			if _is_good_spawn(tile):
				return tile
	return Vector2i.ZERO


func _is_good_spawn(tile: Vector2i) -> bool:
	var column := sample_column(tile.x, tile.y)
	if column.water or not SPAWN_BIOMES.has(column.biome):
		return false
	var chunk := generate_chunk(Coords.tile_to_chunk(tile))
	var local := Coords.tile_to_local(tile)
	if chunk.is_solid(local) or Tiles.is_water(chunk.get_ground(local)):
		return false
	# Leave some room around the player.
	for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbor: Vector2i = local + offset
		if neighbor.x < 0 or neighbor.y < 0 or neighbor.x > 15 or neighbor.y > 15:
			return false
		if chunk.is_solid(neighbor):
			return false
	return true


func _generate_surface(chunk: ChunkData) -> void:
	var size := GameConst.CHUNK_SIZE
	var span := size + 2
	var origin := Coords.chunk_origin_tile(chunk.coord)
	var grid := ClimateGrid.new(climate, Rect2i(origin - Vector2i.ONE, Vector2i(span, span)))

	# Pass 1: heights and water on the chunk plus a 1-tile border, so cliff
	# edges match across chunk borders.
	var levels := PackedInt32Array()
	var water := PackedByteArray()
	levels.resize(span * span)
	water.resize(span * span)
	var columns: Array[Column] = []
	columns.resize(size * size)
	for gy in span:
		for gx in span:
			var tx := origin.x + gx - 1
			var ty := origin.y + gy - 1
			var column := column_from_grid(grid, tx, ty)
			levels[gy * span + gx] = column.level
			water[gy * span + gx] = 1 if column.water else 0
			if gx >= 1 and gx <= size and gy >= 1 and gy <= size:
				columns[(gy - 1) * size + (gx - 1)] = column

	# Pass 2: ground, cliffs and vegetation of the chunk itself.
	for ly in size:
		for lx in size:
			var index := ly * size + lx
			var center := (ly + 1) * span + (lx + 1)
			var column := columns[index]
			var tx := origin.x + lx
			var ty := origin.y + ly
			var ground := surface.ground_for(
				column.biome, column.height, column.level, column.detail, column.water
			)
			var level := levels[center]
			var shape := 0
			if levels[center - span] < level:
				shape |= ChunkData.SHAPE_LOWER_N
			if levels[center + 1] < level:
				shape |= ChunkData.SHAPE_LOWER_E
			if levels[center + span] < level:
				shape |= ChunkData.SHAPE_LOWER_S
			if levels[center - 1] < level:
				shape |= ChunkData.SHAPE_LOWER_W
			if shape != 0 and _ramps.get_noise_2d(tx, ty) > RAMP_THRESHOLD:
				shape |= ChunkData.SHAPE_RAMP
			if levels[center - span] > level:
				shape |= ChunkData.SHAPE_SHADOW
			var block := Tiles.Block.AIR
			if shape & ChunkData.SHAPE_EDGE_MASK == 0:
				var near_water := (
					(
						water[center - span]
						+ water[center + 1]
						+ water[center + span]
						+ water[center - 1]
					)
					> 0
				)
				block = surface.block_for(
					column.biome, ground, column.height, column.erosion, tx, ty, near_water
				)
			chunk.ground[index] = ground
			chunk.blocks[index] = block
			chunk.levels[index] = level
			chunk.shapes[index] = shape
			chunk.biome[index] = column.biome
