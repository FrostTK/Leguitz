class_name Seasons
extends RefCounted
## The calendar and what the seasons change for what grows (static, given
## the clock: WorldClock keeps the setting, `season_days` days a season, 0
## none, and the day the first spring began, `season_start`). Spring,
## summer, autumn and winter follow one another (`season`, `day`,
## `progress`, `year`); a SYNCED world follows the device's date instead
## (northern seasons: spring from March, summer from June, autumn from
## September, winter from December). Growth asks `allows`: where winters
## are mild (MILD_WINTERS: deserts, savannas, jungles, badlands, warm seas)
## nothing waits; elsewhere a crop grows only in its seasons (CROPS, by its
## sown stage), unless it grows under a roof or glass (not
## Watering.under_sky: a greenhouse); fruit trees bear fruit in summer and
## autumn only (they blossom all the same); in winter saplings and young
## trees wait for spring and grass no longer spreads. Snow falls instead of rain in winter
## where winters are not mild (`snows_in`, the client's WeatherEffects and
## SeasonLook).

enum Bit { SPRING = 1, SUMMER = 2, AUTUMN = 4, WINTER = 8 }

const ALL := 15
const MILD_WINTERS := {
	Biomes.Id.WARM_OCEAN: true,
	Biomes.Id.DESERT: true,
	Biomes.Id.SAVANNA: true,
	Biomes.Id.SAVANNA_PLATEAU: true,
	Biomes.Id.JUNGLE: true,
	Biomes.Id.SPARSE_JUNGLE: true,
	Biomes.Id.BADLANDS: true,
}
## The seasons each crop grows in (by its sown stage).
const CROPS := {
	Tiles.Block.WHEAT_0: Bit.SPRING | Bit.SUMMER | Bit.AUTUMN,
	Tiles.Block.CARROTS_0: Bit.SPRING | Bit.SUMMER | Bit.AUTUMN,
	Tiles.Block.POTATOES_0: Bit.SPRING | Bit.SUMMER,
	Tiles.Block.BEETROOTS_0: Bit.SPRING | Bit.AUTUMN | Bit.WINTER,
	Tiles.Block.CABBAGES_0: Bit.SPRING | Bit.AUTUMN | Bit.WINTER,
	Tiles.Block.CORN_0: Bit.SUMMER | Bit.AUTUMN,
	Tiles.Block.TOMATOES_0: Bit.SUMMER,
	Tiles.Block.STRAWBERRIES_0: Bit.SPRING | Bit.SUMMER,
	Tiles.Block.FLAX_0: Bit.SPRING | Bit.SUMMER,
	Tiles.Block.PUMPKIN_STEM_0: Bit.SUMMER | Bit.AUTUMN,
	Tiles.Block.MELON_STEM_0: Bit.SUMMER,
	Tiles.Block.RICE_0: Bit.SPRING | Bit.SUMMER,
	Tiles.Block.SUGAR_CANE_0: Bit.SPRING | Bit.SUMMER | Bit.AUTUMN,
	Tiles.Block.GRAPES_0: Bit.SUMMER | Bit.AUTUMN,
	Tiles.Block.RASPBERRIES_0: Bit.SUMMER | Bit.AUTUMN,
}
## When fruit trees bear fruit.
const FRUIT := Bit.SUMMER | Bit.AUTUMN


## Whether the world has seasons.
static func on(clock: WorldClock) -> bool:
	return clock.season_days > 0


## The season now (spring when the world has none; `local_unix`: the
## device's local time, for a synced world).
static func season(
	clock: WorldClock, local_unix: float = WorldClock.local_unix_now()
) -> WorldClock.Season:
	if not on(clock):
		return WorldClock.Season.SPRING
	if clock.mode == WorldClock.Mode.SYNCED:
		return _dated(local_unix).x as WorldClock.Season
	return posmod(floori(_days_in(clock) / clock.season_days), 4) as WorldClock.Season


## The day of the season (0 its first).
static func day(clock: WorldClock, local_unix: float = WorldClock.local_unix_now()) -> int:
	if not on(clock):
		return 0
	if clock.mode == WorldClock.Mode.SYNCED:
		return _dated(local_unix).y
	return posmod(floori(_days_in(clock)), clock.season_days)


## How far into its season the world is (0 to 1, with the time of day).
static func progress(clock: WorldClock, local_unix: float = WorldClock.local_unix_now()) -> float:
	if not on(clock):
		return 0.0
	if clock.mode == WorldClock.Mode.SYNCED:
		var dated := _dated(local_unix)
		var fraction := (
			fposmod(local_unix, WorldClock.GAME_SECONDS_PER_DAY) / WorldClock.GAME_SECONDS_PER_DAY
		)
		return clampf((dated.y + fraction) / dated.z, 0.0, 1.0)
	return fposmod(_days_in(clock), clock.season_days) / clock.season_days


## The year (0 the first; synced: the device's).
static func year(clock: WorldClock, local_unix: float = WorldClock.local_unix_now()) -> int:
	if clock.mode == WorldClock.Mode.SYNCED:
		var date := Time.get_date_dict_from_unix_time(int(local_unix))
		return int(date["year"]) - (1 if int(date["month"]) < 3 else 0)
	if not on(clock):
		return 0
	return floori(_days_in(clock) / (clock.season_days * 4.0))


## Seasons of `days` days each (0: none), today's season kept.
static func set_length(clock: WorldClock, days: int) -> void:
	days = clampi(days, 0, WorldClock.MOST_SEASON_DAYS)
	if days == clock.season_days:
		return
	if days == 0 or not on(clock):
		clock.season_days = days
		clock.season_start = clock.day_index()
		return
	var now := season(clock)
	var today := mini(day(clock), days - 1)
	clock.season_days = days
	set_season(clock, now, today)


## Moves the calendar so that today is the day `on_day` (0 the first) of
## `which` (not in a synced world: the device's date rules).
static func set_season(clock: WorldClock, which: int, on_day := 0) -> void:
	if not on(clock) or clock.mode == WorldClock.Mode.SYNCED:
		return
	var days := clock.season_days
	clock.season_start = clock.day_index() - posmod(which, 4) * days - clampi(on_day, 0, days - 1)


## A season's bit (WorldClock.Season).
static func bit(which: int) -> int:
	return 1 << which


## The seasons a crop grows in (ALL: what is no crop).
static func of_crop(block: int) -> int:
	return CROPS.get(Farming.sown_of(block), ALL)


## Whether winters are mild in a biome (no snow, nothing waits).
static func mild(biome: int) -> bool:
	return MILD_WINTERS.has(biome)


## Whether snow falls instead of rain in a biome now.
static func snows_in(clock: WorldClock, biome: int) -> bool:
	return on(clock) and season(clock) == WorldClock.Season.WINTER and not mild(biome)


## Whether what grows in a cell (a crop, a fruit tree, a sapling or a young
## tree, dirt by grass) may grow a stage now (see the class).
static func allows(server: GameServer, chunk: ChunkData, cell: Vector3i, block: int) -> bool:
	var clock := server.clock
	if not on(clock):
		return true
	if mild(chunk.get_biome(Coords.tile_to_local(Vector2i(cell.x, cell.z)))):
		return true
	var which := season(clock)
	var now := bit(which)
	if Farming.is_crop(block):
		return of_crop(block) & now != 0 or not Watering.under_sky(server.world, cell)
	if Growth.FRUITING.has(block):
		return FRUIT & now != 0
	return which != WorldClock.Season.WINTER


## Days since the first spring began (with the time of day).
static func _days_in(clock: WorldClock) -> float:
	return clock.total_game_seconds / WorldClock.GAME_SECONDS_PER_DAY - clock.season_start


## Synced: the season of a local time, the day of the season (0 its first)
## and how many days it lasts.
static func _dated(local_unix: float) -> Vector3i:
	var date := Time.get_date_dict_from_unix_time(int(local_unix))
	var month := int(date["month"])
	var which := WorldClock.Season.WINTER
	for candidate: int in [
		WorldClock.Season.SPRING, WorldClock.Season.SUMMER, WorldClock.Season.AUTUMN
	]:
		var starts: int = WorldClock.SEASON_MONTHS[candidate]
		if month >= starts and month < starts + 3:
			which = candidate as WorldClock.Season
	var in_year := int(date["year"])
	var first_month: int = WorldClock.SEASON_MONTHS[which]
	if which == WorldClock.Season.WINTER and month < 3:
		in_year -= 1
	var first := _unix_of(in_year, first_month)
	var next := _unix_of(in_year + (1 if first_month == 12 else 0), (first_month % 12) + 3)
	var into := floori((local_unix - first) / WorldClock.GAME_SECONDS_PER_DAY)
	var length := roundi((next - first) / WorldClock.GAME_SECONDS_PER_DAY)
	return Vector3i(which, clampi(into, 0, length - 1), length)


static func _unix_of(in_year: int, month: int) -> float:
	return float(Time.get_unix_time_from_datetime_dict({"year": in_year, "month": month, "day": 1}))
