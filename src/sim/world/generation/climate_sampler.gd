class_name ClimateSampler
extends RefCounted
## The five climate parameters of Minecraft's (1.18+) multi-noise world
## generation, sampled from independent seeded noises:
##
## - continentalness: ocean <-> coast <-> far inland
## - erosion: low = rugged/mountainous, high = flat
## - weirdness: its zero-lines become rivers; |weirdness| drives
##   "peaks and valleys" (PV)
## - temperature, humidity: choose the biome
##
## Like Minecraft, the climate is sampled on a coarse grid (every
## GRID_STEP tiles) and interpolated in between: it is ~16x cheaper and
## gives smooth biome borders.

enum Param { CONTINENTALNESS, EROSION, WEIRDNESS, TEMPERATURE, HUMIDITY }

const PARAM_COUNT := 5
const GRID_STEP := 4

const SALT_CONTINENTALNESS := 10
const SALT_EROSION := 11
const SALT_WEIRDNESS := 12
const SALT_TEMPERATURE := 13
const SALT_HUMIDITY := 14
const SALT_DETAIL := 15

## Raw FBM noise has a standard deviation of ~0.25. Scaling it spreads the
## parameters over [-1, 1] (std ~0.5) so Minecraft-like thresholds apply.
const PARAM_SCALE := 2.0
## Shifts the land/ocean balance towards land (about 1/3 ocean).
const CONTINENTALNESS_BIAS := 0.08

## Fine per-tile noise for terrain texture (patches, ragged shores).
var detail := FastNoiseLite.new()

var _noises: Array[FastNoiseLite] = []


func _init(world_seed: int) -> void:
	_noises.resize(PARAM_COUNT)
	_noises[Param.CONTINENTALNESS] = make_fbm(
		world_seed, SALT_CONTINENTALNESS, 1.0 / 1200.0, 5, 70.0
	)
	_noises[Param.EROSION] = make_fbm(world_seed, SALT_EROSION, 1.0 / 600.0, 4, 0.0)
	_noises[Param.WEIRDNESS] = make_fbm(world_seed, SALT_WEIRDNESS, 1.0 / 500.0, 4, 30.0)
	_noises[Param.TEMPERATURE] = make_fbm(world_seed, SALT_TEMPERATURE, 1.0 / 1500.0, 4, 60.0)
	_noises[Param.HUMIDITY] = make_fbm(world_seed, SALT_HUMIDITY, 1.0 / 1100.0, 4, 60.0)
	detail = make_fbm(world_seed, SALT_DETAIL, 1.0 / 24.0, 3, 0.0)


## Exact (non-interpolated) parameter value at a world position.
func raw(param: int, x: float, y: float) -> float:
	var value := _noises[param].get_noise_2d(x, y) * PARAM_SCALE
	if param == Param.CONTINENTALNESS:
		value += CONTINENTALNESS_BIAS
	return clampf(value, -1.0, 1.0)


static func make_fbm(
	world_seed: int, salt: int, frequency: float, octaves: int, warp: float
) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = HashUtil.derive_seed(world_seed, salt) & 0x7FFFFFFF
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves
	if warp > 0.0:
		noise.domain_warp_enabled = true
		noise.domain_warp_type = FastNoiseLite.DOMAIN_WARP_SIMPLEX
		noise.domain_warp_amplitude = warp
		noise.domain_warp_frequency = frequency * 2.0
		noise.domain_warp_fractal_type = FastNoiseLite.DOMAIN_WARP_FRACTAL_NONE
	return noise
