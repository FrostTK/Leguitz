class_name FishTable
extends RefCounted
## What lives in the water, shared by the server (what bites a line, what a
## trap catches) and the client (the book). Each fish (SPECIES) has the
## waters it lives in (Water, from the biome of the place: Fishing.water_at;
## underground, out of the sky, is a cave's), the climates it likes
## (Climate), when it bites (Period: by day, at dawn and dusk, at night;
## always night in a cave), the depth of water it wants under the bobber,
## how common it is, the bait it prefers (BAIT_FAVOR times likelier on
## it), whether rain brings it out (it bites any time then, RAIN_FAVOR
## times likelier) and how big one may be (cm, told when caught: small
## ones come more often). A line brings up junk now and then (JUNK); traps
## catch crayfish and crabs too (TRAPS).

enum Water { LAKE = 1, RIVER = 2, SWAMP = 4, SEA = 8, CAVE = 16 }
enum Climate { COLD = 1, MILD = 2, WARM = 4 }
enum Period { DAY = 1, TWILIGHT = 2, NIGHT = 4 }

## Any climate, any time.
const ALL := 7
const FRESH := Water.LAKE | Water.RIVER
## Per fish: [waters, climates, times, depth, how common, bait, rain,
## size (cm)].
const SPECIES := {
	Items.Id.PERCH: [FRESH, ALL, ALL, 1, 30, Items.Id.WORM, false, Vector2i(12, 35)],
	Items.Id.TROUT:
	[
		FRESH,
		Climate.COLD | Climate.MILD,
		Period.DAY | Period.TWILIGHT,
		1,
		18,
		Items.Id.WORM,
		true,
		Vector2i(20, 60),
	],
	Items.Id.CARP:
	[
		FRESH | Water.SWAMP,
		Climate.MILD | Climate.WARM,
		ALL,
		1,
		20,
		Items.Id.BAIT_BALL,
		false,
		Vector2i(30, 80),
	],
	Items.Id.PIKE:
	[FRESH, ALL, Period.DAY | Period.TWILIGHT, 3, 9, Items.Id.FISH_BAIT, false, Vector2i(40, 110)],
	Items.Id.CATFISH:
	[
		FRESH | Water.SWAMP,
		Climate.MILD | Climate.WARM,
		Period.TWILIGHT | Period.NIGHT,
		3,
		8,
		Items.Id.FISH_BAIT,
		false,
		Vector2i(60, 180),
	],
	Items.Id.EEL:
	[
		FRESH | Water.SWAMP,
		ALL,
		Period.TWILIGHT | Period.NIGHT,
		1,
		12,
		Items.Id.WORM,
		true,
		Vector2i(40, 100),
	],
	Items.Id.SALMON:
	[
		Water.RIVER | Water.SEA,
		Climate.COLD,
		ALL,
		2,
		18,
		Items.Id.FISH_BAIT,
		true,
		Vector2i(50, 100),
	],
	Items.Id.SARDINE:
	[
		Water.SEA,
		Climate.MILD | Climate.WARM,
		Period.DAY | Period.TWILIGHT,
		1,
		30,
		Items.Id.BAIT_BALL,
		false,
		Vector2i(12, 22),
	],
	Items.Id.MACKEREL:
	[
		Water.SEA,
		ALL,
		Period.DAY | Period.TWILIGHT,
		2,
		22,
		Items.Id.FISH_BAIT,
		false,
		Vector2i(25, 45),
	],
	Items.Id.COD:
	[
		Water.SEA,
		Climate.COLD | Climate.MILD,
		ALL,
		4,
		16,
		Items.Id.WORM,
		false,
		Vector2i(40, 120),
	],
	Items.Id.SEA_BASS:
	[
		Water.SEA,
		Climate.MILD | Climate.WARM,
		Period.TWILIGHT | Period.NIGHT,
		2,
		12,
		Items.Id.FISH_BAIT,
		true,
		Vector2i(35, 80),
	],
	Items.Id.TUNA:
	[
		Water.SEA,
		Climate.MILD | Climate.WARM,
		Period.DAY,
		8,
		5,
		Items.Id.FISH_BAIT,
		false,
		Vector2i(80, 250),
	],
	Items.Id.LANTERNFISH:
	[
		Water.SEA | Water.CAVE,
		ALL,
		Period.NIGHT,
		4,
		4,
		Items.Id.NONE,
		false,
		Vector2i(5, 12),
	],
	Items.Id.CAVE_FISH: [Water.CAVE, ALL, ALL, 1, 30, Items.Id.WORM, false, Vector2i(8, 20)],
}
## Caught in traps only: their size (cm).
const SHELLFISH := {Items.Id.CRAYFISH: Vector2i(8, 16), Items.Id.CRAB: Vector2i(10, 24)}
## A line brings up junk this often (less with a bait): per item [waters,
## how common].
const JUNK_CHANCE := 0.12
const JUNK_BAITED := 0.06
const JUNK := {
	Items.Id.SEAWEED: [FRESH | Water.SWAMP | Water.SEA, 6],
	Items.Id.DRIFTWOOD: [FRESH | Water.SEA, 4],
}
const BAIT_FAVOR := 3.0
const RAIN_FAVOR := 2.0
## What a trap catches in each water (how common each).
const TRAPS := {
	Water.LAKE:
	{
		Items.Id.CRAYFISH: 40,
		Items.Id.PERCH: 25,
		Items.Id.EEL: 15,
		Items.Id.CARP: 10,
		Items.Id.SEAWEED: 10,
	},
	Water.RIVER:
	{
		Items.Id.CRAYFISH: 45,
		Items.Id.EEL: 20,
		Items.Id.PERCH: 20,
		Items.Id.TROUT: 10,
		Items.Id.SEAWEED: 5,
	},
	Water.SWAMP: {Items.Id.CRAYFISH: 45, Items.Id.EEL: 30, Items.Id.CARP: 15, Items.Id.SEAWEED: 10},
	Water.SEA:
	{Items.Id.CRAB: 45, Items.Id.SARDINE: 25, Items.Id.MACKEREL: 10, Items.Id.SEAWEED: 20},
	Water.CAVE: {Items.Id.CAVE_FISH: 60, Items.Id.CRAYFISH: 40},
}
## Dawn and dusk: this many hours around sunrise and sunset.
const TWILIGHT_HOURS := 1.5
const SUNRISE_HOUR := 6.5
const SUNSET_HOUR := 18.5

const COLD_BIOMES := {
	Biomes.Id.COLD_OCEAN: true,
	Biomes.Id.FROZEN_OCEAN: true,
	Biomes.Id.FROZEN_RIVER: true,
	Biomes.Id.SNOWY_BEACH: true,
	Biomes.Id.SNOWY_PLAINS: true,
	Biomes.Id.SNOWY_TAIGA: true,
	Biomes.Id.TAIGA: true,
	Biomes.Id.OLD_GROWTH_TAIGA: true,
	Biomes.Id.GROVE: true,
	Biomes.Id.SNOWY_SLOPES: true,
	Biomes.Id.JAGGED_PEAKS: true,
	Biomes.Id.FROZEN_PEAKS: true,
	Biomes.Id.STONY_PEAKS: true,
}
const WARM_BIOMES := {
	Biomes.Id.WARM_OCEAN: true,
	Biomes.Id.DESERT: true,
	Biomes.Id.SAVANNA: true,
	Biomes.Id.SAVANNA_PLATEAU: true,
	Biomes.Id.JUNGLE: true,
	Biomes.Id.SPARSE_JUNGLE: true,
	Biomes.Id.BADLANDS: true,
}
const SEA_BIOMES := {
	Biomes.Id.OCEAN: true,
	Biomes.Id.DEEP_OCEAN: true,
	Biomes.Id.WARM_OCEAN: true,
	Biomes.Id.COLD_OCEAN: true,
	Biomes.Id.FROZEN_OCEAN: true,
	Biomes.Id.BEACH: true,
	Biomes.Id.SNOWY_BEACH: true,
	Biomes.Id.STONY_SHORE: true,
}


## The water a biome's lakes, rivers or seas are (open to the sky).
static func water_of(biome: int) -> int:
	if SEA_BIOMES.has(biome):
		return Water.SEA
	if biome in [Biomes.Id.RIVER, Biomes.Id.FROZEN_RIVER]:
		return Water.RIVER
	if biome == Biomes.Id.SWAMP:
		return Water.SWAMP
	if biome in [Biomes.Id.CAVES, Biomes.Id.DEEP_CAVES]:
		return Water.CAVE
	return Water.LAKE


static func climate_of(biome: int) -> int:
	if COLD_BIOMES.has(biome):
		return Climate.COLD
	return Climate.WARM if WARM_BIOMES.has(biome) else Climate.MILD


## The time it is for the fish: dawn and dusk, the day, the night.
static func time_of(clock: WorldClock) -> int:
	var hour := clock.time_of_day() / 3600.0
	if absf(hour - SUNRISE_HOUR) < TWILIGHT_HOURS or absf(hour - SUNSET_HOUR) < TWILIGHT_HOURS:
		return Period.TWILIGHT
	return Period.NIGHT if clock.is_night() else Period.DAY


## How likely a fish is to bite there and then (0: it does not).
static func weight_of(
	fish: int, water: int, climate: int, time: int, raining: bool, depth: int, bait: int
) -> float:
	var row: Array = SPECIES[fish]
	if not (row[0] & water) or not (row[1] & climate) or depth < row[3]:
		return 0.0
	var rain: bool = raining and row[6]
	if not (row[2] & time) and not rain:
		return 0.0
	var weight := float(row[4])
	if bait != Items.Id.NONE and bait == row[5]:
		weight *= BAIT_FAVOR
	if rain:
		weight *= RAIN_FAVOR
	return weight


## What bites a line (see weight_of; now and then junk, none in caves).
static func pick(
	rng: RandomNumberGenerator,
	water: int,
	climate: int,
	time: int,
	raining: bool,
	depth: int,
	bait: int
) -> int:
	var junk := JUNK_BAITED if bait != Items.Id.NONE else JUNK_CHANCE
	if rng.randf() < junk:
		var weights := {}
		for item: int in JUNK:
			if JUNK[item][0] & water:
				weights[item] = float(JUNK[item][1])
		var found := _draw(rng, weights)
		if found != Items.Id.NONE:
			return found
	var fishes := {}
	for fish: int in SPECIES:
		var weight := weight_of(fish, water, climate, time, raining, depth, bait)
		if weight > 0.0:
			fishes[fish] = weight
	var caught := _draw(rng, fishes)
	if caught != Items.Id.NONE:
		return caught
	return Items.Id.CAVE_FISH if water == Water.CAVE else Items.Id.SEAWEED


## What a trap catches in a water.
static func trap_pick(rng: RandomNumberGenerator, water: int) -> int:
	return _draw(rng, TRAPS.get(water, TRAPS[Water.LAKE]))


## How big a caught fish is (cm; 0: not a fish).
static func size_of(rng: RandomNumberGenerator, item: int) -> int:
	var span := Vector2i.ZERO
	if SPECIES.has(item):
		span = SPECIES[item][7]
	elif SHELLFISH.has(item):
		span = SHELLFISH[item]
	else:
		return 0
	return roundi(lerpf(span.x, span.y, rng.randf() * rng.randf()))


## One of the keys of `weights` (item -> how common), as likely as each
## is common (Items.Id.NONE: none).
static func _draw(rng: RandomNumberGenerator, weights: Dictionary) -> int:
	var total := 0.0
	for item: int in weights:
		total += float(weights[item])
	if total <= 0.0:
		return Items.Id.NONE
	var at := rng.randf() * total
	for item: int in weights:
		at -= float(weights[item])
		if at < 0.0:
			return item
	return weights.keys().back()
