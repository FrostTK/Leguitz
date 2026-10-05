extends TestCase
## Extreme graphics and the savings they turn off: the settings applied
## (the player's own kept), small props' shadows in their coarser copies,
## and the growth checks spread over the ticks.


func test_extreme_sets_the_graphics_at_their_most_and_keeps_the_players_own() -> void:
	var settings = Engine.get_main_loop().root.get_node_or_null("Settings")
	if settings == null:
		return
	var was: bool = settings.extreme
	settings.extreme = false
	assert_eq(settings.effective_quality(), settings.graphics_quality)
	assert_eq(settings.effective_hd(), settings.hd_rendering)
	assert_eq(settings.effective_far_view(), settings.far_view)
	# Never through choose: that would write the player's settings file.
	settings.extreme = true
	assert_eq(settings.effective_quality(), settings.EXTREME_QUALITY)
	assert_true(settings.effective_hd())
	assert_eq(settings.effective_far_view(), settings.EXTREME_FAR_VIEW)
	assert_true(&"extreme" in settings.DISPLAY_KEYS, "saved with the display settings")
	settings.extreme = was


func test_small_props_cast_no_shadow_in_their_coarser_copies() -> void:
	var library := PropLibrary.new()
	var grass := Tiles.Block.TALL_GRASS
	var oak := Tiles.Block.OAK
	assert_true(library.is_small(grass))
	assert_false(library.is_small(oak), "a tree is no small prop")
	assert_true(library.casts_shadow(grass, 0), "near, in full detail: its shadow")
	assert_false(library.casts_shadow(grass, 2), "far or zoomed out: none")
	assert_true(library.casts_shadow(oak, 2), "trees always")
	assert_false(library.casts_shadow(Tiles.Block.LILY_PAD, 0), "on the water: never")
	library.thrifty = false
	assert_true(library.casts_shadow(grass, 2), "extreme: every plant")


func test_growth_checks_each_chunk_once_over_the_ticks() -> void:
	var settings := WorldSettings.create("Test", "42", WorldSettings.GameMode.SURVIVAL)
	var server := GameServer.new(settings, null, false)
	var cells: Array[Vector3i] = []
	for coord: Vector2i in [Vector2i(0, 0), Vector2i(3, 1)]:
		var tile := coord * GameConst.CHUNK_SIZE + Vector2i(5, 5)
		var row := int(server.world.surface_height(tile)) + GameConst.SEA_LEVEL
		var cell := Vector3i(tile.x, row, tile.y)
		server.world.set_voxel(cell, Voxels.of_block(Tiles.Block.COMPOSTER_FULL))
		cells.append(cell)
	var first := Growth.slice_of(Vector2i(0, 0))
	assert_ne(first, Growth.slice_of(Vector2i(3, 1)), "these two on different ticks")
	Growth.update(server, 1.0, first)
	var ready := Voxels.of_block(Tiles.Block.COMPOSTER_READY)
	assert_eq(server.world.voxel_at(cells[0]), ready, "its tick: it rots")
	assert_ne(server.world.voxel_at(cells[1]), ready, "not its tick yet")
	for slice in Growth.CHECK_TICKS:
		if slice != first:
			Growth.update(server, 1.0, slice)
	assert_eq(server.world.voxel_at(cells[1]), ready, "over the ticks, every chunk")
	for coord in 200:
		var slice := Growth.slice_of(Vector2i(coord % 20 - 10, coord / 20 - 5))
		assert_true(slice >= 0 and slice < Growth.CHECK_TICKS)
