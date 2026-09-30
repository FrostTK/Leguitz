class_name Biomes
extends RefCounted
## Biome registry and selection, modeled on Minecraft's multi-noise biome
## table: the biome is picked from temperature and humidity bands, then
## adjusted by terrain (ocean depth, coast, rivers, plateaus, slopes,
## peaks) and erosion. Ids are stored in chunks: only append.

enum Id {
	NONE,
	OCEAN,
	DEEP_OCEAN,
	WARM_OCEAN,
	COLD_OCEAN,
	FROZEN_OCEAN,
	RIVER,
	FROZEN_RIVER,
	BEACH,
	SNOWY_BEACH,
	STONY_SHORE,
	PLAINS,
	SNOWY_PLAINS,
	DESERT,
	SWAMP,
	FOREST,
	FLOWER_FOREST,
	BIRCH_FOREST,
	DARK_FOREST,
	TAIGA,
	SNOWY_TAIGA,
	OLD_GROWTH_TAIGA,
	SAVANNA,
	SAVANNA_PLATEAU,
	JUNGLE,
	SPARSE_JUNGLE,
	BADLANDS,
	MEADOW,
	GROVE,
	SNOWY_SLOPES,
	JAGGED_PEAKS,
	FROZEN_PEAKS,
	STONY_PEAKS,
	MUSHROOM_FIELDS,
	CAVES,
	DEEP_CAVES,
}

## Temperature and humidity band limits (Minecraft values).
const TEMPERATURE_BANDS: Array[float] = [-0.45, -0.15, 0.2, 0.55]
const HUMIDITY_BANDS: Array[float] = [-0.35, -0.1, 0.1, 0.3]

## Minecraft's "middle biomes" table, indexed [temperature][humidity].
const MIDDLE: Array = [
	[Id.SNOWY_PLAINS, Id.SNOWY_PLAINS, Id.SNOWY_PLAINS, Id.SNOWY_TAIGA, Id.TAIGA],
	[Id.PLAINS, Id.PLAINS, Id.FOREST, Id.TAIGA, Id.OLD_GROWTH_TAIGA],
	[Id.FLOWER_FOREST, Id.PLAINS, Id.FOREST, Id.BIRCH_FOREST, Id.DARK_FOREST],
	[Id.SAVANNA, Id.SAVANNA, Id.FOREST, Id.SPARSE_JUNGLE, Id.JUNGLE],
	[Id.DESERT, Id.DESERT, Id.DESERT, Id.DESERT, Id.DESERT],
]
const PLATEAU: Array = [
	[Id.SNOWY_PLAINS, Id.SNOWY_PLAINS, Id.SNOWY_PLAINS, Id.SNOWY_TAIGA, Id.SNOWY_TAIGA],
	[Id.MEADOW, Id.MEADOW, Id.FOREST, Id.TAIGA, Id.OLD_GROWTH_TAIGA],
	[Id.MEADOW, Id.MEADOW, Id.MEADOW, Id.MEADOW, Id.DARK_FOREST],
	[Id.SAVANNA_PLATEAU, Id.SAVANNA_PLATEAU, Id.FOREST, Id.FOREST, Id.JUNGLE],
	[Id.BADLANDS, Id.BADLANDS, Id.BADLANDS, Id.BADLANDS, Id.BADLANDS],
]

## Terrain heights (m) separating lowlands, slopes and peaks.
const SLOPE_HEIGHT := 55.0
const PEAK_HEIGHT := 82.0
const PLATEAU_HEIGHT := 28.0
const BEACH_MAX_HEIGHT := 2.5
const DEEP_OCEAN_HEIGHT := -20.0
## Oceans only freeze in the coldest part of the frozen band.
const FROZEN_OCEAN_TEMPERATURE := -0.6

## Display data: translation key and map color.
const INFO := {
	Id.NONE: ["BIOME_NONE", Color("000000")],
	Id.OCEAN: ["BIOME_OCEAN", Color("3f7fd0")],
	Id.DEEP_OCEAN: ["BIOME_DEEP_OCEAN", Color("2c5aa6")],
	Id.WARM_OCEAN: ["BIOME_WARM_OCEAN", Color("33aac4")],
	Id.COLD_OCEAN: ["BIOME_COLD_OCEAN", Color("41699f")],
	Id.FROZEN_OCEAN: ["BIOME_FROZEN_OCEAN", Color("93b9dc")],
	Id.RIVER: ["BIOME_RIVER", Color("4b93dc")],
	Id.FROZEN_RIVER: ["BIOME_FROZEN_RIVER", Color("a8cdee")],
	Id.BEACH: ["BIOME_BEACH", Color("ead38e")],
	Id.SNOWY_BEACH: ["BIOME_SNOWY_BEACH", Color("e3ebf2")],
	Id.STONY_SHORE: ["BIOME_STONY_SHORE", Color("8b8a93")],
	Id.PLAINS: ["BIOME_PLAINS", Color("7cbc4c")],
	Id.SNOWY_PLAINS: ["BIOME_SNOWY_PLAINS", Color("eef3f8")],
	Id.DESERT: ["BIOME_DESERT", Color("e8d18a")],
	Id.SWAMP: ["BIOME_SWAMP", Color("5e7a3c")],
	Id.FOREST: ["BIOME_FOREST", Color("3f8a36")],
	Id.FLOWER_FOREST: ["BIOME_FLOWER_FOREST", Color("6aae4c")],
	Id.BIRCH_FOREST: ["BIOME_BIRCH_FOREST", Color("78b05a")],
	Id.DARK_FOREST: ["BIOME_DARK_FOREST", Color("2d5b28")],
	Id.TAIGA: ["BIOME_TAIGA", Color("3d6f52")],
	Id.SNOWY_TAIGA: ["BIOME_SNOWY_TAIGA", Color("c8d8de")],
	Id.OLD_GROWTH_TAIGA: ["BIOME_OLD_GROWTH_TAIGA", Color("4b5e3a")],
	Id.SAVANNA: ["BIOME_SAVANNA", Color("bdb35c")],
	Id.SAVANNA_PLATEAU: ["BIOME_SAVANNA_PLATEAU", Color("a99f4f")],
	Id.JUNGLE: ["BIOME_JUNGLE", Color("2b8a33")],
	Id.SPARSE_JUNGLE: ["BIOME_SPARSE_JUNGLE", Color("58a443")],
	Id.BADLANDS: ["BIOME_BADLANDS", Color("c8733b")],
	Id.MEADOW: ["BIOME_MEADOW", Color("98d266")],
	Id.GROVE: ["BIOME_GROVE", Color("b4cfc4")],
	Id.SNOWY_SLOPES: ["BIOME_SNOWY_SLOPES", Color("dde7f0")],
	Id.JAGGED_PEAKS: ["BIOME_JAGGED_PEAKS", Color("f5f8fc")],
	Id.FROZEN_PEAKS: ["BIOME_FROZEN_PEAKS", Color("c9dff3")],
	Id.STONY_PEAKS: ["BIOME_STONY_PEAKS", Color("a09fa8")],
	Id.MUSHROOM_FIELDS: ["BIOME_MUSHROOM_FIELDS", Color("9c80a8")],
	Id.CAVES: ["BIOME_CAVES", Color("5a5a62")],
	Id.DEEP_CAVES: ["BIOME_DEEP_CAVES", Color("3c3c46")],
}


static func name_key(id: int) -> String:
	return INFO.get(id, INFO[Id.NONE])[0]


static func map_color(id: int) -> Color:
	return INFO.get(id, INFO[Id.NONE])[1]


static func band(value: float, bands: Array[float]) -> int:
	var index := 0
	while index < bands.size() and value >= bands[index]:
		index += 1
	return index


static func is_ocean(id: int) -> bool:
	return id >= Id.OCEAN and id <= Id.FROZEN_OCEAN


static func is_cold(id: int) -> bool:
	return (
		id
		in [
			Id.FROZEN_OCEAN,
			Id.FROZEN_RIVER,
			Id.SNOWY_BEACH,
			Id.SNOWY_PLAINS,
			Id.SNOWY_TAIGA,
			Id.GROVE,
			Id.SNOWY_SLOPES,
			Id.JAGGED_PEAKS,
			Id.FROZEN_PEAKS,
		]
	)


## Picks the surface biome of a column.
## `h` is the terrain height (m), `river` tells if the column is a river.
static func select(
	continentalness: float,
	erosion: float,
	weirdness: float,
	temperature: float,
	humidity: float,
	h: float,
	river: bool
) -> int:
	var t := band(temperature, TEMPERATURE_BANDS)
	var hu := band(humidity, HUMIDITY_BANDS)
	if TerrainShaper.is_mushroom_island(continentalness, weirdness):
		return Id.MUSHROOM_FIELDS
	if river:
		return Id.FROZEN_RIVER if t == 0 else Id.RIVER
	if h < 0.0:
		return _ocean(temperature, h)
	if h < BEACH_MAX_HEIGHT and continentalness < -0.02:
		if erosion < -0.4:
			return Id.STONY_SHORE
		if t == 0:
			return Id.SNOWY_BEACH
		return Id.DESERT if t == 4 else Id.BEACH
	if h >= PEAK_HEIGHT:
		if t <= 2:
			return Id.JAGGED_PEAKS if weirdness > 0.0 else Id.FROZEN_PEAKS
		return Id.STONY_PEAKS
	if h >= SLOPE_HEIGHT:
		if t <= 1:
			return Id.GROVE if hu >= 3 else Id.SNOWY_SLOPES
		if t == 2:
			return Id.GROVE if hu >= 4 else Id.MEADOW
		return PLATEAU[t][hu]
	if h >= PLATEAU_HEIGHT and TerrainShaper.peaks_valleys(weirdness) > 0.3:
		return PLATEAU[t][hu]
	if erosion > 0.55 and h < 12.0 and t >= 1 and t <= 3 and hu >= 2:
		return Id.SWAMP
	if t == 4 and erosion < -0.35:
		return Id.BADLANDS
	return MIDDLE[t][hu]


static func _ocean(temperature: float, h: float) -> int:
	if temperature < FROZEN_OCEAN_TEMPERATURE:
		return Id.FROZEN_OCEAN
	if h < DEEP_OCEAN_HEIGHT:
		return Id.DEEP_OCEAN
	var t := band(temperature, TEMPERATURE_BANDS)
	if t <= 1:
		return Id.COLD_OCEAN
	return Id.WARM_OCEAN if t == 4 else Id.OCEAN
