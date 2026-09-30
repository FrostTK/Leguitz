class_name CaveGenerator
extends RefCounted
## Underground layers (-1 to -6). Solid rock by default, carved by the
## three kinds of Minecraft noise caves:
## - "cheese" caves: large open chambers, with rock pillars left inside,
## - "spaghetti" caves: long winding tunnels (thin bands around the zero
##   line of a noise),
## - "noodle" caves: narrow crawlways.
## Chambers may hold underground lakes (upper layers) or lava (deep
## layers), and ores are distributed by depth like Minecraft's.

const MIN_LAYER := -6
## From this depth on, stone turns into deepslate (Minecraft's y < 0).
const DEEPSLATE_DEPTH := 4

const SALT_BASE := 100

const ROCK := 0
const TUNNEL := 1
const CHAMBER := 2

## [ore block, min depth, max depth, frequency, threshold]
## Lower threshold = more ore. Checked in order (rarest first).
const ORES := [
	[Tiles.Block.DIAMOND_ORE, 5, 6, 1.0 / 3.5, 0.885],
	[Tiles.Block.RUBY_ORE, 4, 6, 1.0 / 5.0, 0.81],
	[Tiles.Block.LAPIS_ORE, 3, 5, 1.0 / 5.0, 0.83],
	[Tiles.Block.GOLD_ORE, 3, 6, 1.0 / 5.0, 0.82],
	[Tiles.Block.IRON_ORE, 1, 5, 1.0 / 6.0, 0.79],
	[Tiles.Block.COPPER_ORE, 1, 3, 1.0 / 7.0, 0.8],
	[Tiles.Block.COAL_ORE, 1, 3, 1.0 / 7.0, 0.75],
]

var _cheese: FastNoiseLite
var _pillars: FastNoiseLite
var _spaghetti_a: FastNoiseLite
var _spaghetti_b: FastNoiseLite
var _noodle: FastNoiseLite
var _fluid: FastNoiseLite
var _ore_noises: Array[FastNoiseLite] = []
var _decoration_seed := 0


func _init(world_seed: int) -> void:
	_cheese = _noise(world_seed, SALT_BASE + 1, 1.0 / 70.0, 3)
	_pillars = _noise(world_seed, SALT_BASE + 2, 1.0 / 9.0, 1)
	_spaghetti_a = _noise(world_seed, SALT_BASE + 3, 1.0 / 90.0, 2)
	_spaghetti_b = _noise(world_seed, SALT_BASE + 4, 1.0 / 110.0, 2)
	_noodle = _noise(world_seed, SALT_BASE + 5, 1.0 / 45.0, 1)
	_fluid = _noise(world_seed, SALT_BASE + 6, 1.0 / 50.0, 2)
	for i in ORES.size():
		_ore_noises.append(_noise(world_seed, SALT_BASE + 20 + i, ORES[i][3], 1))
	_decoration_seed = HashUtil.derive_seed(world_seed, SALT_BASE + 50)


func generate_chunk(chunk: ChunkData) -> void:
	var depth := -chunk.layer
	var deep := depth >= DEEPSLATE_DEPTH
	var wall := Tiles.Block.DEEPSLATE if deep else Tiles.Block.STONE
	var floor_ground := Tiles.Ground.DEEPSLATE_FLOOR if deep else Tiles.Ground.STONE_FLOOR
	var biome := Biomes.Id.DEEP_CAVES if deep else Biomes.Id.CAVES
	var origin := Coords.chunk_origin_tile(chunk.coord)
	var index := 0
	for ly in GameConst.CHUNK_SIZE:
		var ty := origin.y + ly
		for lx in GameConst.CHUNK_SIZE:
			var tx := origin.x + lx
			var sx := _slice_x(depth, tx)
			var sy := _slice_y(depth, ty)
			chunk.biome[index] = biome
			chunk.ground[index] = floor_ground
			var openness := _openness(depth, sx, sy)
			if openness == ROCK:
				chunk.blocks[index] = _rock(depth, sx, sy, wall)
			else:
				if openness == CHAMBER:
					chunk.ground[index] = _chamber_ground(depth, sx, sy, floor_ground)
				if chunk.ground[index] == floor_ground:
					chunk.blocks[index] = _cave_decoration(depth, tx, ty)
			index += 1


func is_open(layer: int, tx: int, ty: int) -> bool:
	var depth := -layer
	return _openness(depth, _slice_x(depth, tx), _slice_y(depth, ty)) != ROCK


## Ground of an open tile: floor, or water/lava in chambers.
func chamber_ground_at(layer: int, tx: int, ty: int) -> int:
	var depth := -layer
	var sx := _slice_x(depth, tx)
	var sy := _slice_y(depth, ty)
	var floor_ground := (
		Tiles.Ground.DEEPSLATE_FLOOR if depth >= DEEPSLATE_DEPTH else Tiles.Ground.STONE_FLOOR
	)
	if _openness(depth, sx, sy) != CHAMBER:
		return floor_ground
	return _chamber_ground(depth, sx, sy, floor_ground)


## Block of a closed tile (wall or ore) at a layer.
func rock_at(layer: int, tx: int, ty: int) -> int:
	var depth := -layer
	var wall := Tiles.Block.DEEPSLATE if depth >= DEEPSLATE_DEPTH else Tiles.Block.STONE
	return _rock(depth, _slice_x(depth, tx), _slice_y(depth, ty), wall)


## Each layer is a different slice through the same noises.
static func _slice_x(depth: int, tx: int) -> float:
	return tx + depth * 1013.0


static func _slice_y(depth: int, ty: int) -> float:
	return ty - depth * 1013.0


func _openness(depth: int, sx: float, sy: float) -> int:
	var cheese_threshold := 0.42 - depth * 0.02
	if _cheese.get_noise_2d(sx, sy) > cheese_threshold and _pillars.get_noise_2d(sx, sy) < 0.55:
		return CHAMBER
	if (
		absf(_spaghetti_a.get_noise_2d(sx, sy)) < 0.035
		or absf(_spaghetti_b.get_noise_2d(sy, sx)) < 0.03
		or absf(_noodle.get_noise_2d(sx, sy)) < 0.012
	):
		return TUNNEL
	return ROCK


func _chamber_ground(depth: int, sx: float, sy: float, floor_ground: int) -> int:
	var fluid := _fluid.get_noise_2d(sx, sy)
	if depth <= 3 and fluid > 0.38:
		return Tiles.Ground.WATER
	if depth >= 5 and fluid < -0.36:
		return Tiles.Ground.LAVA
	return floor_ground


func _rock(depth: int, sx: float, sy: float, wall: int) -> int:
	for i in ORES.size():
		var ore: Array = ORES[i]
		if depth < ore[1] or depth > ore[2]:
			continue
		if _ore_noises[i].get_noise_2d(sx, sy) > ore[4]:
			return ore[0]
	return wall


func _cave_decoration(depth: int, tx: int, ty: int) -> int:
	var roll := HashUtil.unit2(_decoration_seed + depth, tx, ty)
	if depth <= 3 and roll < 0.006:
		return Tiles.Block.MUSHROOM_BROWN
	if depth <= 2 and roll > 0.996:
		return Tiles.Block.MUSHROOM_RED
	if roll > 0.985 and roll <= 0.996:
		return Tiles.Block.ROCK
	return Tiles.Block.AIR


static func _noise(world_seed: int, salt: int, frequency: float, octaves: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = HashUtil.derive_seed(world_seed, salt) & 0x7FFFFFFF
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	if octaves > 1:
		noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		noise.fractal_octaves = octaves
	else:
		noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	return noise
