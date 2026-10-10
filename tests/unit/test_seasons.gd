extends TestCase
## Seasons: the calendar (seasons following the days, set by the menu and
## by command, saved, worlds saved before them starting with spring, a
## synced world following the device's date), crops growing in their
## seasons or under glass, trees waiting for spring, fruit in summer and
## autumn, mild winters where nothing waits, snow instead of rain, how the
## seasons look.

const SEA := GameConst.SEA_LEVEL
const DAY := WorldClock.GAME_SECONDS_PER_DAY

var _server: GameServer


## A grass field around the origin at noon, in the plains, on the first
## day of spring.
func _field() -> void:
	var settings := WorldSettings.create("Test", "42", WorldSettings.GameMode.SURVIVAL)
	_server = GameServer.new(settings, null, false)
	_server.clock.set_frozen(WorldClock.FROZEN_NOON)
	Seasons.set_season(_server.clock, WorldClock.Season.SPRING)
	for x in range(-12, 13):
		for z in range(-12, 13):
			for y in range(SEA - 3, SEA + 8):
				var voxel := Voxels.AIR
				if y < SEA - 1:
					voxel = Voxels.of_block(Tiles.Block.STONE)
				elif y == SEA - 1:
					voxel = Voxels.of_ground(Tiles.Ground.GRASS)
				_server.world.set_voxel(Vector3i(x, y, z), voxel)
			_biome(Vector3i(x, SEA, z), Biomes.Id.PLAINS)


func _biome(cell: Vector3i, biome: int) -> void:
	var tile := Vector2i(cell.x, cell.z)
	var chunk: ChunkData = _server.world.chunks[Coords.tile_to_chunk(tile)]
	var local := Coords.tile_to_local(tile)
	chunk.biome[local.y * GameConst.CHUNK_SIZE + local.x] = biome


## A crop sown on wet farmland at `x`, `z`; under glass two rows up when
## `glass`.
func _crop(x: int, z: int, sown: int, glass := false) -> Vector3i:
	var cell := Vector3i(x, SEA, z)
	_server.world.set_voxel(cell + Vector3i.DOWN, Voxels.of_ground(Tiles.Ground.FARMLAND_WET))
	_server.world.set_voxel(cell, Voxels.of_block(sown))
	if glass:
		_server.world.set_voxel(cell + Vector3i(0, 2, 0), Voxels.of_block(Tiles.Block.GLASS))
	return cell


func _block(cell: Vector3i) -> int:
	return Voxels.block_of(_server.world.voxel_at(cell))


func _grow() -> void:
	Growth.update(_server, 1.0)


func test_the_calendar_follows_the_days() -> void:
	var clock := WorldClock.new()
	assert_true(Seasons.on(clock), "a new world has seasons")
	assert_eq(clock.season_days, WorldClock.DEFAULT_SEASON_DAYS)
	assert_eq(Seasons.season(clock), WorldClock.Season.SPRING, "it starts with spring")
	assert_eq(Seasons.day(clock), 0)
	clock.total_game_seconds += 7.0 * DAY
	assert_eq(Seasons.season(clock), WorldClock.Season.SUMMER)
	clock.total_game_seconds += 3.0 * DAY
	assert_eq(Seasons.day(clock), 3)
	var expected := (3.0 + WorldClock.NEW_WORLD_TIME / DAY) / 7.0
	assert_true(absf(Seasons.progress(clock) - expected) < 0.001, "how far into summer")
	clock.total_game_seconds += 18.0 * DAY
	assert_eq(Seasons.season(clock), WorldClock.Season.SPRING, "a year went by")
	assert_eq(Seasons.year(clock), 1)
	Seasons.set_season(clock, WorldClock.Season.AUTUMN, 2)
	assert_eq(Seasons.season(clock), WorldClock.Season.AUTUMN, "set by command")
	assert_eq(Seasons.day(clock), 2)
	Seasons.set_length(clock, 14)
	assert_eq(Seasons.season(clock), WorldClock.Season.AUTUMN, "longer seasons keep today's")
	assert_eq(Seasons.day(clock), 2)
	Seasons.set_length(clock, 0)
	assert_false(Seasons.on(clock))
	Seasons.set_length(clock, 5)
	assert_eq(Seasons.season(clock), WorldClock.Season.SPRING, "turned on: spring starts")
	assert_eq(Seasons.day(clock), 0)
	# Saved, and loaded again.
	Seasons.set_season(clock, WorldClock.Season.WINTER, 4)
	var again := WorldClock.new()
	again.load_dict(clock.to_dict())
	assert_eq(Seasons.season(again), WorldClock.Season.WINTER)
	assert_eq(Seasons.day(again), 4)
	assert_eq(again.season_days, 5)
	# A world saved before seasons: spring starts the day it is loaded.
	var old := clock.to_dict()
	old.erase("season_days")
	old.erase("season_start")
	var older := WorldClock.new()
	older.load_dict(old)
	assert_eq(older.season_days, WorldClock.DEFAULT_SEASON_DAYS)
	assert_eq(Seasons.season(older), WorldClock.Season.SPRING)
	assert_eq(Seasons.day(older), 0)


func test_a_synced_world_follows_the_date() -> void:
	var clock := WorldClock.new()
	var january := _unix(2026, 1, 15)
	clock.set_synced(january)
	assert_eq(Seasons.season(clock, january), WorldClock.Season.WINTER)
	assert_eq(Seasons.day(clock, january), 45, "from the first of December")
	assert_eq(Seasons.year(clock, january), 2025, "the winter began last year")
	var april := _unix(2026, 4, 10)
	assert_eq(Seasons.season(clock, april), WorldClock.Season.SPRING)
	assert_eq(Seasons.day(clock, april), 40)
	assert_eq(Seasons.season(clock, _unix(2026, 7, 1)), WorldClock.Season.SUMMER)
	assert_eq(Seasons.season(clock, _unix(2026, 10, 31)), WorldClock.Season.AUTUMN)
	assert_eq(Seasons.day(clock, _unix(2026, 10, 31)), 60)
	var progress := Seasons.progress(clock, _unix(2026, 12, 1))
	assert_true(progress < 0.02, "winter just began: %.3f" % progress)
	Seasons.set_season(clock, WorldClock.Season.SUMMER)
	assert_eq(Seasons.season(clock, january), WorldClock.Season.WINTER, "the date rules")


func _unix(year: int, month: int, day: int) -> float:
	return float(Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": day}))


func test_crops_grow_in_their_seasons_or_under_glass() -> void:
	_field()
	var outside := _crop(2, 2, Tiles.Block.TOMATOES_0)
	var inside := _crop(6, 2, Tiles.Block.TOMATOES_0, true)
	_grow()
	assert_eq(_block(outside), Tiles.Block.TOMATOES_0, "no tomatoes in spring outside")
	assert_eq(_block(inside), Tiles.Block.TOMATOES_1, "in a greenhouse they grow")
	Seasons.set_season(_server.clock, WorldClock.Season.SUMMER)
	_grow()
	assert_eq(_block(outside), Tiles.Block.TOMATOES_1, "summer: they grow")
	Seasons.set_season(_server.clock, WorldClock.Season.WINTER)
	var wheat := _crop(2, 6, Tiles.Block.WHEAT_0)
	var cabbage := _crop(4, 6, Tiles.Block.CABBAGES_0)
	_grow()
	assert_eq(_block(wheat), Tiles.Block.WHEAT_0, "no wheat in winter")
	assert_eq(_block(cabbage), Tiles.Block.CABBAGES_1, "cabbages stand the cold")
	# Where winters are mild nothing waits.
	var south := _crop(8, 8, Tiles.Block.WHEAT_0)
	_biome(south, Biomes.Id.DESERT)
	_grow()
	assert_eq(_block(south), Tiles.Block.WHEAT_1)
	# Without seasons everything grows.
	Seasons.set_length(_server.clock, 0)
	_grow()
	assert_eq(_block(wheat), Tiles.Block.WHEAT_1)
	for sown: int in Seasons.CROPS:
		assert_true(Farming.SOWN.has(sown), "%s is a crop" % Tiles.Block.find_key(sown))
		assert_true(Seasons.CROPS[sown] != 0, "it grows some time")
	for sown: int in Farming.SOWN:
		assert_true(Seasons.CROPS.has(sown), "%s has its seasons" % Tiles.Block.find_key(sown))


func test_trees_wait_for_spring_and_fruit_comes_in_summer() -> void:
	_field()
	Seasons.set_season(_server.clock, WorldClock.Season.WINTER)
	var sapling := Vector3i(-6, SEA, 6)
	_server.world.set_voxel(sapling, Voxels.of_block(Tiles.Block.OAK_SAPLING))
	var orchard := Vector3i(-6, SEA, -6)
	_server.world.set_voxel(orchard, Voxels.of_block(Tiles.Block.APPLE_TREE))
	var dirt := Vector3i(0, SEA - 1, -8)
	_server.world.set_voxel(dirt, Voxels.of_ground(Tiles.Ground.DIRT))
	_grow()
	assert_eq(_block(sapling), Tiles.Block.OAK_SAPLING, "it waits for spring")
	assert_eq(_block(orchard), Tiles.Block.APPLE_TREE, "no fruit in winter")
	assert_eq(_server.world.voxel_at(dirt), Voxels.of_ground(Tiles.Ground.DIRT), "no grass")
	Seasons.set_season(_server.clock, WorldClock.Season.SPRING)
	_grow()
	assert_eq(_block(sapling), Tiles.Block.YOUNG_OAK, "spring: it grows")
	assert_eq(_block(orchard), Tiles.Block.APPLE_TREE, "in blossom")
	assert_eq(_server.world.voxel_at(dirt), Voxels.of_ground(Tiles.Ground.GRASS))
	Seasons.set_season(_server.clock, WorldClock.Season.SUMMER)
	_grow()
	assert_eq(_block(orchard), Tiles.Block.APPLE_TREE_FRUIT, "fruit in summer")


func test_snow_falls_in_winter_where_winters_bite() -> void:
	var clock := WorldClock.new()
	assert_false(Seasons.snows_in(clock, Biomes.Id.PLAINS), "not in spring")
	Seasons.set_season(clock, WorldClock.Season.WINTER)
	assert_true(Seasons.snows_in(clock, Biomes.Id.PLAINS))
	assert_true(Seasons.snows_in(clock, Biomes.Id.FOREST))
	assert_false(Seasons.snows_in(clock, Biomes.Id.DESERT), "mild winters")
	assert_false(Seasons.snows_in(clock, Biomes.Id.JUNGLE))
	Seasons.set_length(clock, 0)
	assert_false(Seasons.snows_in(clock, Biomes.Id.PLAINS), "no seasons")


func test_the_look_follows_the_seasons() -> void:
	var summer := SeasonLook.goals(WorldClock.Season.SUMMER, 0.6)
	assert_eq(summer.slice(0, 3), [0.0, 0.0, 0.0], "summer: green, leafy, no snow")
	assert_eq(summer[3], SeasonLook.GRASS[WorldClock.Season.SUMMER])
	var autumn := SeasonLook.goals(WorldClock.Season.AUTUMN, 0.5)
	assert_eq(autumn[0], 1.0, "mid-autumn: turned")
	assert_true(autumn[1] < 0.1, "still on the trees")
	var late := SeasonLook.goals(WorldClock.Season.AUTUMN, 1.0)
	assert_true(late[1] > 0.8, "falling")
	var winter := SeasonLook.goals(WorldClock.Season.WINTER, 0.5)
	assert_eq(winter[1], 1.0, "bare")
	assert_eq(winter[2], 1.0, "snowed in")
	var thaw := SeasonLook.goals(WorldClock.Season.WINTER, 1.0)
	assert_eq(thaw[2], 0.0, "the snow melts at winter's end")
	assert_eq(thaw[0], 0.0, "green buds")
	var first := SeasonLook.goals(WorldClock.Season.SPRING, 0.0)
	assert_eq(first[2], 0.0, "spring starts without snow")
	assert_true(first[1] <= SeasonLook.LAST_BARE, "and almost in leaf")
	var spring := SeasonLook.goals(WorldClock.Season.SPRING, 0.5)
	assert_eq(spring[1], 0.0, "leaves again")
	assert_eq(spring[2], 0.0, "melted")
	# Each season's end is the next one's start.
	for season in 4:
		var end := SeasonLook.goals(season, 1.0)
		var start := SeasonLook.goals((season + 1) % 4, 0.0)
		for i in 3:
			assert_true(absf(end[i] - start[i]) < 0.16, "smooth %d/%d" % [season, i])
	var plains := Biomes.Id.PLAINS
	assert_eq(SeasonLook.prop_bits(Tiles.Block.OAK, plains), 48, "deciduous, winters bite")
	assert_eq(SeasonLook.prop_bits(Tiles.Block.SPRUCE, plains), 32, "evergreen")
	assert_eq(SeasonLook.prop_bits(Tiles.Block.OAK, Biomes.Id.DESERT), 16, "a mild winter")


func test_seasons_are_set_from_the_menu_and_by_command() -> void:
	var settings := WorldSettings.create("Test", "42", WorldSettings.GameMode.SURVIVAL)
	var server := GameServer.new(settings, null, false)
	var transports := LocalTransport.create_pair()
	server.connect_client(transports[1])
	var client: LocalTransport = transports[0]
	client.send(Msg.hello("Alex", 2))
	server.process_messages()
	client.poll()
	client.send(Msg.set_seasons(10))
	server.process_messages()
	assert_eq(server.clock.season_days, 10, "the pause menu's choice")
	var told := client.poll().filter(func(m: Dictionary) -> bool: return m["t"] == Msg.TIME_STATE)
	assert_eq(told.size(), 1, "everyone is told")
	assert_eq(told[0]["clock"]["season_days"], 10)
	client.send(Msg.chat("/saison hiver 3"))
	server.process_messages()
	assert_eq(Seasons.season(server.clock), WorldClock.Season.WINTER)
	assert_eq(Seasons.day(server.clock), 2, "the third day")
	client.send(Msg.chat("/season off"))
	server.process_messages()
	assert_false(Seasons.on(server.clock))
	client.send(Msg.chat("/saison 5"))
	server.process_messages()
	assert_eq(server.clock.season_days, 5)
	for key: String in [
		"SEASON_SPRING",
		"SEASON_SUMMER",
		"SEASON_AUTUMN",
		"SEASON_WINTER",
		"SETTING_SEASONS",
		"SEASONS_OFF",
		"SEASONS_DAYS",
		"HUD_SEASON_TIME",
		"CMD_SEASON_USAGE",
		"CMD_SEASON_HELP",
		"CMD_SEASON_DONE",
		"BOOK_FARM_SEASONS_INTRO",
	]:
		assert_ne(tr(key), key, "%s written" % key)
