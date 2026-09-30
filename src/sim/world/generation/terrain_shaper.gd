class_name TerrainShaper
extends RefCounted
## Turns climate parameters into terrain height, like Minecraft's terrain
## splines: continentalness sets the base height (ocean floor, coast,
## inland), erosion decides how rugged the land is, and "peaks and
## valleys" (derived from weirdness) raises mountains and digs valleys.
## Rivers follow the zero-lines of weirdness, at the bottom of valleys.
##
## Heights are in meters (1 tile = 1 m), sea level = 0.

## Height difference between two terrace levels (one cliff step).
const LEVEL_STEP := 10.0
const HIGH_LEVEL_STEP := 16.0
const HIGH_LEVELS_FROM := 40.0
const MAX_LEVEL := 31

## Continentalness bands (Minecraft 1.18 values).
const MUSHROOM_CONTINENTALNESS := -0.9
const DEEP_OCEAN_CONTINENTALNESS := -0.455
const OCEAN_CONTINENTALNESS := -0.19
const COAST_CONTINENTALNESS := -0.11

## Rivers: |weirdness| below the core width is water; the valley around
## it is carved progressively.
const RIVER_CORE := 0.02
const RIVER_VALLEY := 0.14
const RIVER_MIN_CONTINENTALNESS := -0.16

var _continental := (
	Spline
	. new(
		[
			[-1.0, -40.0],
			[-0.6, -45.0],
			[-0.455, -30.0],
			[-0.3, -18.0],
			[-0.19, -9.0],
			[-0.16, -2.5],
			[-0.11, 1.5],
			[-0.05, 3.0],
			[0.03, 5.0],
			[0.3, 10.0],
			[1.0, 16.0],
		]
	)
)
var _erosion_amplitude := (
	Spline
	. new(
		[
			[-1.0, 1.0],
			[-0.78, 0.95],
			[-0.375, 0.62],
			[-0.2225, 0.42],
			[0.05, 0.2],
			[0.45, 0.08],
			[0.55, 0.05],
			[1.0, 0.03],
		]
	)
)
var _relief := (
	Spline
	. new(
		[
			[-1.0, -14.0],
			[-0.85, -7.0],
			[-0.6, -2.0],
			[-0.2, 0.0],
			[0.2, 9.0],
			[0.45, 32.0],
			[0.7, 72.0],
			[1.0, 112.0],
		]
	)
)


## Minecraft's "peaks and valleys": 1 on ridges, -1 in valleys.
static func peaks_valleys(weirdness: float) -> float:
	return 1.0 - absf(3.0 * absf(weirdness) - 2.0)


static func is_mushroom_island(continentalness: float, weirdness: float) -> bool:
	return continentalness <= MUSHROOM_CONTINENTALNESS and weirdness > 0.45


## 0 far from rivers, 1 at the river center. Rivers do not exist in oceans.
static func river_proximity(continentalness: float, weirdness: float) -> float:
	if continentalness < RIVER_MIN_CONTINENTALNESS:
		return 0.0
	var coast_fade := smoothstep(RIVER_MIN_CONTINENTALNESS, -0.08, continentalness)
	return (1.0 - smoothstep(RIVER_CORE, RIVER_VALLEY, absf(weirdness))) * coast_fade


static func is_river(continentalness: float, weirdness: float) -> bool:
	return (
		continentalness >= RIVER_MIN_CONTINENTALNESS + 0.02
		and absf(weirdness) < RIVER_CORE
		and not is_mushroom_island(continentalness, weirdness)
	)


## Smooth terrain height in meters before rivers are cut into water.
## Terrace levels come from this smooth height (clean cliff lines); a small
## per-tile `detail` is only added to decide where the water ends.
func height(continentalness: float, erosion: float, weirdness: float) -> float:
	if is_mushroom_island(continentalness, weirdness):
		return 3.0
	var base := _continental.sample(continentalness)
	var inland := smoothstep(-0.2, 0.05, continentalness)
	var relief := _relief.sample(peaks_valleys(weirdness))
	var h := base + inland * _erosion_amplitude.sample(erosion) * relief
	# Carve the valley around rivers down towards the water.
	var valley := river_proximity(continentalness, weirdness)
	if valley > 0.0 and h > 0.0:
		h = lerpf(h, minf(h, 1.0), valley * valley)
	return h


## Terrace level of a height: one step every LEVEL_STEP m in the lowlands,
## wider steps (HIGH_LEVEL_STEP) in the mountains so slopes stay readable.
static func level_for_height(h: float) -> int:
	if h <= 0.0:
		return 0
	if h < HIGH_LEVELS_FROM:
		return floori(h / LEVEL_STEP)
	var low_levels := floori(HIGH_LEVELS_FROM / LEVEL_STEP)
	return mini(low_levels + floori((h - HIGH_LEVELS_FROM) / HIGH_LEVEL_STEP), MAX_LEVEL)
