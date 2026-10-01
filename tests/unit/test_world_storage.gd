extends TestCase
## Saving a world: settings, clock, weather, players, changed chunks.

const FOLDER := "user://test_worlds/storage"


func _fresh_storage() -> WorldStorage:
	var storage := WorldStorage.new(FOLDER)
	storage.erase()
	return storage


func _settings() -> WorldSettings:
	return WorldSettings.create("Test", "42", WorldSettings.GameMode.SURVIVAL)


func test_world_settings_clock_and_weather_come_back() -> void:
	var storage := _fresh_storage()
	assert_false(storage.exists(), "nothing saved yet")
	assert_true(storage.read_world().is_empty())
	var settings := _settings()
	settings.world_seed = 0x3FFF_FFFF_FFFF_FFF1
	var clock := WorldClock.new()
	clock.set_normal(45.0)
	clock.total_game_seconds = 3.5 * WorldClock.GAME_SECONDS_PER_DAY
	var weather := Weather.new(1)
	weather.set_kind(Weather.Kind.THUNDER)
	assert_true(storage.save_world(settings, clock, weather))
	assert_true(storage.exists())

	var saved := WorldStorage.new(FOLDER).read_world()
	var loaded_settings := WorldSettings.new()
	loaded_settings.load_dict(saved["settings"])
	assert_eq(loaded_settings.world_seed, settings.world_seed, "big seeds stay exact")
	assert_eq(loaded_settings.world_name, "Test")
	var loaded_clock := WorldClock.new()
	loaded_clock.load_dict(saved["clock"])
	assert_almost(loaded_clock.day_minutes, 45.0)
	assert_almost(loaded_clock.total_game_seconds, clock.total_game_seconds)
	var loaded_weather := Weather.new(2)
	loaded_weather.load_dict(saved["weather"])
	assert_eq(loaded_weather.kind, Weather.Kind.THUNDER)
	assert_true(saved["saved_unix"] > 0.0, "when it was saved")
	storage.erase()
	assert_false(storage.exists(), "erased")


func test_players_come_back_by_name() -> void:
	var storage := _fresh_storage()
	var state := {"position": Vector2(123.5, -40.0), "height": 2.0, "facing": Vector2i.LEFT}
	assert_true(storage.save_player("Alex", state))
	var loaded := WorldStorage.new(FOLDER).load_player("Alex")
	assert_eq(loaded["position"], Vector2(123.5, -40.0))
	assert_almost(loaded["height"], 2.0)
	assert_eq(loaded["facing"], Vector2i.LEFT)
	assert_true(storage.load_player("Sam").is_empty(), "someone new")
	storage.erase()


func test_changed_chunks_come_back_from_their_regions() -> void:
	var storage := _fresh_storage()
	var generator := WorldGenerator.new(42)
	var coords: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(31, 31), Vector2i(32, 0), Vector2i(-1, -1)
	]
	var chunks: Array[ChunkData] = []
	for coord in coords:
		var chunk := generator.generate_chunk(coord)
		chunk.set_voxel(Vector3i(3, 70, 5), Voxels.of_block(Tiles.Block.STONE))
		chunk.modified = true
		storage.store_chunk(chunk)
		chunks.append(chunk)
	assert_true(storage.flush())
	var files := DirAccess.get_files_at(FOLDER + "/regions")
	assert_eq(files.size(), 3, "32 x 32 chunks per region file: %s" % [files])

	var reopened := WorldStorage.new(FOLDER)
	for i in coords.size():
		assert_true(reopened.has_chunk(coords[i]))
		var loaded := reopened.load_chunk(coords[i])
		assert_eq(loaded.coord, coords[i])
		assert_eq(loaded.voxels, chunks[i].voxels, "voxels of %s" % coords[i])
		assert_eq(loaded.biome, chunks[i].biome)
		assert_eq(loaded.tops, chunks[i].tops, "tops recomputed")
		assert_true(loaded.modified, "still saved next time")
	assert_false(reopened.has_chunk(Vector2i(5, 5)), "never changed: generated again")
	assert_eq(reopened.load_chunk(Vector2i(5, 5)), null)
	storage.erase()


func test_a_save_cut_short_keeps_the_last_good_file() -> void:
	var storage := _fresh_storage()
	assert_true(storage.save_player("Alex", {"height": 1.0}))
	assert_true(storage.save_player("Alex", {"height": 2.0}))
	# Cut short while swapping: only the copy of the previous save is left.
	var path := FOLDER + "/players/Alex.cfg"
	assert_eq(DirAccess.rename_absolute(path, path + ".bak"), OK)
	assert_almost(WorldStorage.new(FOLDER).load_player("Alex")["height"], 2.0, 0.0001)
	# The next save replaces it cleanly.
	assert_true(storage.save_player("Alex", {"height": 3.0}))
	assert_false(FileAccess.file_exists(path + ".bak"))
	assert_false(FileAccess.file_exists(path + ".tmp"))
	assert_almost(WorldStorage.new(FOLDER).load_player("Alex")["height"], 3.0, 0.0001)
	storage.erase()


func test_the_server_loads_what_players_changed_and_where_they_were() -> void:
	var storage := _fresh_storage()
	var server := GameServer.new(_settings(), null, false)
	server.use_storage(storage, {})
	assert_true(storage.exists(), "a new world is saved right away")
	var transports := LocalTransport.create_pair()
	server.connect_client(transports[1])
	transports[0].send(Msg.hello("Alex", 2))
	server.process_messages()
	var spawn := server.first_session().position
	var cell := Vector3i(40, 20, -7)
	var gold := Voxels.of_block(Tiles.Block.GOLD_ORE)
	server.world.set_voxel(cell, gold)
	server.first_session().position = spawn + Vector2(48, 16)
	transports[0].poll()
	assert_true(server.save())
	var said := transports[0].poll()
	assert_eq(said.back()["t"], Msg.WORLD_SAVED, "the client hears it")

	var saved := storage.read_world()
	var settings := WorldSettings.new()
	settings.load_dict(saved["settings"])
	var again := GameServer.new(settings, null, false)
	again.use_storage(WorldStorage.new(FOLDER), saved)
	assert_eq(again.world.voxel_at(cell), gold, "the changed chunk, not a generated one")
	var others := LocalTransport.create_pair()
	again.connect_client(others[1])
	others[0].send(Msg.hello("Alex", 2))
	again.process_messages()
	var welcome := others[0].poll()[0]
	assert_eq(welcome["t"], Msg.WELCOME)
	assert_eq(welcome["spawn"], spawn + Vector2(48, 16), "back where they were")
	storage.erase()


func test_changed_chunks_leave_memory_but_not_the_world() -> void:
	var storage := _fresh_storage()
	var world := WorldState.new(WorldGenerator.new(42))
	world.storage = storage
	var cell := Vector3i(5, 60, 5)
	world.set_voxel(cell, Voxels.AIR)
	world.unload_unused({})
	assert_true(world.chunks.is_empty(), "unloaded")
	assert_eq(world.voxel_at(cell), Voxels.AIR, "loaded back as it was changed")
	# A throwaway world keeps changed chunks in memory instead.
	var throwaway := WorldState.new(WorldGenerator.new(42))
	throwaway.set_voxel(cell, Voxels.AIR)
	throwaway.unload_unused({})
	assert_eq(throwaway.chunks.size(), 1)
	storage.erase()


func test_only_dev_seeds_play_throwaway_worlds() -> void:
	assert_true(DevOptions.parse(PackedStringArray()).saves_world())
	assert_false(DevOptions.parse(PackedStringArray(["--seed=42"])).saves_world())
	var restart := DevOptions.parse(PackedStringArray(["--seed=42", "--new-world"]))
	assert_true(restart.saves_world(), "a new saved world with that seed")
	assert_true(restart.new_world)
