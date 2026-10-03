class_name WorldGenerator
extends RefCounted
## Deterministic world generation, following Minecraft's pipeline:
## seed -> climate noises -> terrain height (splines) -> rivers -> biome
## -> surface rules -> vegetation, plus noise caves and ores underground.
##
## Thread-safe: generate_chunk() only reads shared state, so the server can
## generate many chunks in parallel on worker threads.

## Meters of per-tile noise added to decide where water ends (ragged shores).
const WATER_EDGE_DETAIL := 1.5
const SALT_SPACING := 40
## Water gets one voxel deeper every this many meters below sea level.
const WATER_DEPTH_STEP := 5.0
const MAX_WATER_DEPTH := 12

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

var _rock_column := _build_rock_column()
var _air_column := PackedInt32Array()
var _spacing_seed := 0


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
	_air_column.resize(GameConst.WORLD_HEIGHT)
	_spacing_seed = HashUtil.derive_seed(world_seed, SALT_SPACING)


func generate_chunk(coord: Vector2i) -> ChunkData:
	var chunk := ChunkData.new(coord)
	_generate_terrain(chunk)
	# Caves stay under the terrain: the column tops do not change.
	caves.carve(chunk)
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
	if not is_free_ground(chunk, local):
		return false
	# Leave some room around the player.
	for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbor: Vector2i = local + offset
		if neighbor.x < 0 or neighbor.y < 0 or neighbor.x > 15 or neighbor.y > 15:
			return false
		if not is_free_ground(chunk, neighbor):
			return false
	return true


## True if a body can stand on the terrain of a column: dry ground with
## nothing solid on it.
static func is_free_ground(chunk: ChunkData, local: Vector2i) -> bool:
	var ground := chunk.surface_voxel(local)
	if not Voxels.is_cube(ground):
		return false
	return not Voxels.is_solid(chunk.object_on_surface(local))


## Terrain of a chunk: rock, then filler, the surface voxel and what
## stands on it, from the climate and terrain shape of each column.
func _generate_terrain(chunk: ChunkData) -> void:
	var size := GameConst.CHUNK_SIZE
	# Pass 1 covers a 2-tile border: cliff edges and the vegetation of the
	# 1-tile border must come out the same as in the neighbor chunks.
	var span := size + 4
	var origin := Coords.chunk_origin_tile(chunk.coord)
	var corner := origin - Vector2i(2, 2)
	var grid := ClimateGrid.new(climate, Rect2i(corner, Vector2i(span, span)))

	# Pass 1: heights and water.
	var levels := PackedInt32Array()
	var water := PackedByteArray()
	levels.resize(span * span)
	water.resize(span * span)
	var columns: Array[Column] = []
	columns.resize(span * span)
	for gy in span:
		for gx in span:
			var column := column_from_grid(grid, corner.x + gx, corner.y + gy)
			var index := gy * span + gx
			levels[index] = column.level
			water[index] = 1 if column.water else 0
			columns[index] = column

	# Pass 2: ground and vegetation of the chunk and its 1-tile border.
	var grounds := PackedInt32Array()
	var blocks := PackedInt32Array()
	grounds.resize(span * span)
	blocks.resize(span * span)
	for gy in range(1, span - 1):
		for gx in range(1, span - 1):
			var index := gy * span + gx
			var column := columns[index]
			var ground := surface.ground_for(
				column.biome, column.height, column.level, column.detail, column.water
			)
			grounds[index] = ground
			var level := levels[index]
			var cliff_edge := (
				levels[index - span] < level
				or levels[index + 1] < level
				or levels[index + span] < level
				or levels[index - 1] < level
			)
			if not cliff_edge:
				var near_water := (
					water[index - span] + water[index + 1] + water[index + span] + water[index - 1]
				)
				blocks[index] = surface.block_for(
					column.biome,
					ground,
					column.height,
					column.erosion,
					corner.x + gx,
					corner.y + gy,
					near_water > 0
				)

	# Pass 3: the voxels of each column, in storage order.
	var voxels := PackedInt32Array()
	for ly in size:
		for lx in size:
			var index := ly * size + lx
			var at := (ly + 2) * span + (lx + 2)
			var column := columns[at]
			var tile := origin + Vector2i(lx, ly)
			var block := _spaced(blocks, at, span, tile, column.biome)
			if ObjectShapes.is_tree(block):
				block = surface.orchard_tree(column.biome, block, tile.x, tile.y)
				if Growth.FRUITING.has(block):
					# In blossom: it will bear fruit (Growth).
					var cell := Vector3i(tile.x, GameConst.SEA_LEVEL + column.level, tile.y)
					chunk.growing[cell] = true
			if column.water:
				voxels.append_array(_water_column(column, grounds[at], block))
				chunk.tops[index] = GameConst.SEA_LEVEL
			else:
				voxels.append_array(_land_column(column, grounds[at], block))
				var top := GameConst.SEA_LEVEL + column.level
				chunk.tops[index] = top + 1 if Tiles.is_cube(block) else top
			chunk.biome[index] = column.biome
	chunk.voxels = voxels


## Trees, rocks and other solid objects never stand on neighboring tiles,
## so bodies can always walk between them: of solid objects touching each
## other (3 x 3), only the one ranked first by its tile's hash stays; the
## others leave their tile to the undergrowth.
func _spaced(blocks: PackedInt32Array, at: int, span: int, tile: Vector2i, biome: int) -> int:
	var block := blocks[at]
	if SurfaceBuilder.WILD_FRUITS.has(block):
		return block if _alone(blocks, at, span) else Tiles.Block.AIR
	if not _is_spaced(block):
		return block
	var rank := HashUtil.hash2(_spacing_seed, tile.x, tile.y)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if (dx == 0 and dy == 0) or not _is_spaced(blocks[at + dy * span + dx]):
				continue
			var other := HashUtil.hash2(_spacing_seed, tile.x + dx, tile.y + dy)
			if other > rank or (other == rank and (dy < 0 or (dy == 0 and dx < 0))):
				return surface.undergrowth_for(biome, tile.x, tile.y)
	return block


## Solid objects that keep their distance (not cube blocks: rock outcrops
## form solid masses; wild fruits keep away from them instead: _alone).
static func _is_spaced(block: int) -> bool:
	return (
		Tiles.is_block_solid(block)
		and not Tiles.is_cube(block)
		and block != Tiles.Block.AIR
		and not SurfaceBuilder.WILD_FRUITS.has(block)
	)


## Whether no solid object (but cubes) stands around a tile: a wild fruit
## is only kept there (so no tree is thinned out for it).
static func _alone(blocks: PackedInt32Array, at: int, span: int) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var other := blocks[at + dy * span + dx]
			if (dx != 0 or dy != 0) and Tiles.is_block_solid(other) and not Tiles.is_cube(other):
				return false
	return true


## Rock up to the filler, the filler (dirt under grass...), the surface
## voxel at the column's level and what stands on it (tree, plant, rock).
func _land_column(column: Column, ground: int, block: int) -> PackedInt32Array:
	var top := GameConst.SEA_LEVEL + column.level - 1
	var filler_start := top - SurfaceBuilder.FILLER_DEPTH
	var voxels := _rock_column.slice(0, filler_start)
	for row in range(filler_start, top):
		voxels.append(surface.filler_for(ground, column.height, row))
	voxels.append(Voxels.of_ground(ground))
	voxels.append(Voxels.of_block(block))
	voxels.append_array(_air_column.slice(0, GameConst.WORLD_HEIGHT - voxels.size()))
	return voxels


## Sea, lakes and rivers: a bed deeper where the terrain goes lower, water
## up to just under level 0 (its surface shows at level 0), maybe ice on
## top and a lily pad.
func _water_column(column: Column, ground: int, block: int) -> PackedInt32Array:
	var surface_row := GameConst.SEA_LEVEL - 1
	var depth := clampi(int(-column.height / WATER_DEPTH_STEP) + 1, 1, MAX_WATER_DEPTH)
	var bed := surface_row - depth
	var bed_voxel := surface.bed_for(column.biome, column.detail)
	var voxels := _rock_column.slice(0, bed - 1)
	voxels.append(bed_voxel)
	voxels.append(bed_voxel)
	var liquid := Voxels.of_ground(Tiles.Ground.WATER if ground == Tiles.Ground.ICE else ground)
	for row in range(bed + 1, surface_row):
		voxels.append(liquid)
	voxels.append(Voxels.of_ground(ground))
	voxels.append(Voxels.of_block(block))
	voxels.append_array(_air_column.slice(0, GameConst.WORLD_HEIGHT - voxels.size()))
	return voxels


static func _build_rock_column() -> PackedInt32Array:
	var voxels := PackedInt32Array()
	for row in GameConst.WORLD_HEIGHT:
		voxels.append(CaveGenerator.rock_at(row))
	return voxels
