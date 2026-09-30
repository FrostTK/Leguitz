class_name TerrainGenerator
extends RefCounted
## Phase 0 placeholder terrain: one elevation and one moisture noise.
## Phase 1 replaces the internals with the Minecraft-style multi-noise
## pipeline (continentalness, erosion, peaks & valleys, temperature,
## humidity -> biomes, rivers, caves, ores). The public API stays the same.

const SALT_ELEVATION := 1
const SALT_MOISTURE := 2
const SALT_DECORATION := 3

var world_seed := 0
var _elevation := FastNoiseLite.new()
var _moisture := FastNoiseLite.new()
var _decoration_seed := 0


func _init(seed_value: int) -> void:
	world_seed = seed_value
	_elevation.seed = HashUtil.derive_seed(world_seed, SALT_ELEVATION) & 0x7FFFFFFF
	_elevation.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_elevation.frequency = 0.0045
	_elevation.fractal_type = FastNoiseLite.FRACTAL_FBM
	_elevation.fractal_octaves = 5

	_moisture.seed = HashUtil.derive_seed(world_seed, SALT_MOISTURE) & 0x7FFFFFFF
	_moisture.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_moisture.frequency = 0.008
	_moisture.fractal_type = FastNoiseLite.FRACTAL_FBM
	_moisture.fractal_octaves = 3

	_decoration_seed = HashUtil.derive_seed(world_seed, SALT_DECORATION)


func generate_chunk(coord: Vector2i) -> ChunkData:
	var chunk := ChunkData.new(coord)
	var origin := Coords.chunk_origin_tile(coord)
	var index := 0
	for ly in GameConst.CHUNK_SIZE:
		var ty := origin.y + ly
		for lx in GameConst.CHUNK_SIZE:
			var tx := origin.x + lx
			var e := _elevation.get_noise_2d(tx, ty)
			var m := _moisture.get_noise_2d(tx, ty)
			var ground := ground_for(e, m)
			chunk.ground[index] = ground
			chunk.blocks[index] = _block_for(ground, m, tx, ty)
			index += 1
	return chunk


func ground_for(elevation: float, moisture: float) -> int:
	if elevation < -0.32:
		return Tiles.Ground.DEEP_WATER
	if elevation < -0.2:
		return Tiles.Ground.WATER
	if elevation < -0.15:
		return Tiles.Ground.SAND
	if elevation < 0.3:
		return Tiles.Ground.FOREST_GRASS if moisture > 0.12 else Tiles.Ground.GRASS
	if elevation < 0.45:
		return Tiles.Ground.STONE_FLOOR
	return Tiles.Ground.SNOW


## Returns the tile where a new player should appear: the closest dry,
## free tile to the world origin.
func find_spawn_tile(max_radius := 2048) -> Vector2i:
	for radius in range(0, max_radius, 8):
		for step in maxi(1, radius):
			var angle := TAU * step / maxf(1.0, radius)
			var tile := Vector2i(roundi(cos(angle) * radius), roundi(sin(angle) * radius))
			if _is_good_spawn(tile):
				return tile
	return Vector2i.ZERO


func _is_good_spawn(tile: Vector2i) -> bool:
	var e := _elevation.get_noise_2d(tile.x, tile.y)
	var m := _moisture.get_noise_2d(tile.x, tile.y)
	var ground := ground_for(e, m)
	if ground != Tiles.Ground.GRASS:
		return false
	return _block_for(ground, m, tile.x, tile.y) == Tiles.Block.AIR


func _block_for(ground: int, moisture: float, tx: int, ty: int) -> int:
	var roll := HashUtil.unit2(_decoration_seed, tx, ty)
	match ground:
		Tiles.Ground.FOREST_GRASS:
			if roll < 0.22 + moisture * 0.2:
				return Tiles.Block.TREE
			if roll > 0.96:
				return Tiles.Block.BUSH
		Tiles.Ground.GRASS:
			if roll < 0.025:
				return Tiles.Block.TREE
			if roll > 0.975:
				return Tiles.Block.BUSH
		Tiles.Ground.STONE_FLOOR:
			if roll < 0.3:
				return Tiles.Block.ROCK
			if roll > 0.94:
				return Tiles.Block.PINE
		Tiles.Ground.SNOW:
			if roll < 0.12:
				return Tiles.Block.PINE
	return Tiles.Block.AIR
