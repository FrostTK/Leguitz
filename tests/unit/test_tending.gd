extends TestCase
## Tending crops (Watering, Composting): the watering can filled at water
## or a sink and keeping farmland wet a while, the rain watering what is
## under the sky, canals of flowing water, crops under glass and by a
## lantern underground, the composter filling up and rotting into compost,
## compost making a crop or a sapling grow a stage.

const SEA := GameConst.SEA_LEVEL

var _server: GameServer
var _client: LocalTransport
var _session: GameServer.PlayerSession


func _grass_at(cell: Vector3i) -> int:
	if cell.y < SEA - 1:
		return Voxels.of_block(Tiles.Block.STONE)
	return Voxels.of_ground(Tiles.Ground.GRASS) if cell.y == SEA - 1 else Voxels.AIR


## A grass field around the origin at noon, a player standing in it.
func _field(mode := WorldSettings.GameMode.SURVIVAL) -> GameServer:
	var settings := WorldSettings.create("Test", "42", mode)
	_server = GameServer.new(settings, null, false)
	_server.clock.set_frozen(WorldClock.FROZEN_NOON)
	var transports := LocalTransport.create_pair()
	_client = transports[0]
	_server.connect_client(transports[1])
	_client.send(Msg.hello("Alex", 2))
	_server.process_messages()
	_session = _server.first_session()
	for x in range(-12, 13):
		for z in range(-12, 13):
			for y in range(SEA - 3, SEA + 6):
				_server.world.set_voxel(Vector3i(x, y, z), _grass_at(Vector3i(x, y, z)))
	_session.position = Coords.tile_to_world_center(Vector2i.ZERO)
	_session.height = 0.0
	return _server


func _at(x: int, y: int, z: int) -> int:
	return _server.world.voxel_at(Vector3i(x, SEA + y, z))


func _put(x: int, y: int, z: int, voxel: int) -> void:
	_server.world.set_voxel(Vector3i(x, SEA + y, z), voxel)


func _hold(item: int, count := 1, wear := 0) -> void:
	_session.inventory.items[0] = item
	_session.inventory.counts[0] = count
	_session.inventory.wear[0] = wear


func _send(message: Dictionary) -> void:
	_client.send(message)
	_server.process_messages()


func test_a_can_is_filled_at_water_or_a_sink() -> void:
	_field()
	_put(2, -1, 0, Voxels.of_ground(Tiles.Ground.WATER))
	_put(-2, 0, 0, Voxels.of_block(Tiles.Block.SINK))
	_hold(Items.Id.WATERING_CAN)
	assert_eq(Items.max_stack(Items.Id.WATERING_CAN), 1)
	_send(Msg.fill_can(Vector3i(1, SEA - 1, 0), 0))
	assert_eq(_session.inventory.wear[0], 0, "grass fills nothing")
	_send(Msg.fill_can(Vector3i(2, SEA - 1, 0), 0))
	assert_eq(_session.inventory.wear[0], Items.CAN_WATER, "full")
	_session.inventory.wear[0] = 3
	_send(Msg.fill_can(Vector3i(-2, SEA, 0), 0))
	assert_eq(_session.inventory.wear[0], Items.CAN_WATER, "at a sink too")
	_hold(Items.Id.STICK)
	_send(Msg.fill_can(Vector3i(2, SEA - 1, 0), 0))
	assert_eq(_session.inventory.wear[0], 0, "not a stick")
	# Flowing water fills it too; the water stays saved with the can.
	assert_true(Watering.fills_from(Voxels.of_ground(Tiles.Ground.WATER_FLOW_2)))
	assert_false(Watering.fills_from(Voxels.of_ground(Tiles.Ground.LAVA)))
	var bag := Inventory.new()
	bag.add(Items.Id.WATERING_CAN, 1, 12)
	var copy := Inventory.new()
	copy.load_dict(bag.to_dict())
	assert_eq(copy.wear[0], 12, "its water kept")


func test_watered_farmland_stays_wet_a_while_then_dries() -> void:
	_field()
	_put(1, -1, 0, Voxels.of_ground(Tiles.Ground.FARMLAND))
	_put(1, 0, 0, Voxels.of_block(Tiles.Block.WHEAT_0))
	_put(2, -1, 0, Voxels.of_ground(Tiles.Ground.FARMLAND))
	var bed := Vector3i(1, SEA - 1, 0)
	assert_eq(Watering.bed_of(bed + Vector3i.UP, _server.world.voxel_at), bed, "under the crop")
	assert_eq(Watering.bed_of(Vector3i(3, SEA - 1, 0), _server.world.voxel_at), Vector3i.MAX)
	_hold(Items.Id.WATERING_CAN, 1, 2)
	_send(Msg.water(bed, 0))
	assert_eq(_at(1, -1, 0), Voxels.of_ground(Tiles.Ground.FARMLAND_WET), "wet at once")
	assert_eq(_session.inventory.wear[0], 1, "a tile's water used")
	_send(Msg.water(Vector3i(2, SEA - 1, 0), 0))
	_send(Msg.water(Vector3i(3, SEA - 1, 0), 0))
	assert_eq(_session.inventory.wear[0], 0, "grass is not watered")
	_send(Msg.water(Vector3i(2, SEA - 1, 0), 0))
	assert_eq(_at(2, -1, 0), Voxels.of_ground(Tiles.Ground.FARMLAND_WET))
	_put(2, -1, 0, Voxels.of_ground(Tiles.Ground.FARMLAND))
	_send(Msg.water(Vector3i(2, SEA - 1, 0), 0))
	assert_eq(_at(2, -1, 0), Voxels.of_ground(Tiles.Ground.FARMLAND), "the can is empty")
	# Wet far from any water while it lasts, then dry again.
	var chunk: ChunkData = _server.world.chunks[Vector2i.ZERO]
	assert_true(chunk.watered.has(bed))
	Growth.update(_server, 0.0)
	assert_eq(_at(1, -1, 0), Voxels.of_ground(Tiles.Ground.FARMLAND_WET), "still wet")
	assert_eq(Farming.stage_seconds(_server.world, bed + Vector3i.UP), Farming.STAGE_SECONDS)
	chunk.watered[bed] = 1.0
	Growth.update(_server, 0.0)
	assert_eq(_at(1, -1, 0), Voxels.of_ground(Tiles.Ground.FARMLAND), "dried out")
	assert_false(chunk.watered.has(bed))
	# Broken, farmland forgets its water.
	chunk.watered[bed] = 100.0
	_put(1, -1, 0, Voxels.AIR)
	assert_false(chunk.watered.has(bed))


func test_creative_waters_without_using_water() -> void:
	_field(WorldSettings.GameMode.CREATIVE)
	_put(1, -1, 0, Voxels.of_ground(Tiles.Ground.FARMLAND))
	_hold(Items.Id.WATERING_CAN)
	_send(Msg.water(Vector3i(1, SEA - 1, 0), 0))
	assert_eq(_at(1, -1, 0), Voxels.of_ground(Tiles.Ground.FARMLAND_WET))
	assert_eq(_session.inventory.wear[0], 0)
	var bag := Inventory.new()
	GameModes.take_from_catalog(bag, Items.Id.WATERING_CAN, false, false)
	assert_eq(bag.wear[Inventory.CURSOR], Items.CAN_WATER, "the catalog's comes full")


func test_the_rain_waters_farmland_under_the_sky() -> void:
	_field()
	_put(1, -1, 0, Voxels.of_ground(Tiles.Ground.FARMLAND))
	_put(1, 0, 0, Voxels.of_block(Tiles.Block.CARROTS_1))
	_put(4, -1, 0, Voxels.of_ground(Tiles.Ground.FARMLAND))
	_put(4, 2, 0, Voxels.of_block(Tiles.Block.GLASS))
	Growth.update(_server, 0.0)
	assert_eq(_at(1, -1, 0), Voxels.of_ground(Tiles.Ground.FARMLAND), "dry before the rain")
	_server.weather.set_kind(Weather.Kind.RAIN)
	Growth.update(_server, 0.0)
	assert_eq(_at(1, -1, 0), Voxels.of_ground(Tiles.Ground.FARMLAND_WET), "rained on")
	assert_eq(_at(4, -1, 0), Voxels.of_ground(Tiles.Ground.FARMLAND), "glass is a roof")
	_server.weather.set_kind(Weather.Kind.CLEAR)
	Growth.update(_server, 0.0)
	assert_eq(_at(1, -1, 0), Voxels.of_ground(Tiles.Ground.FARMLAND_WET), "wet after the rain")


func test_a_canal_of_flowing_water_wets_farmland() -> void:
	_field()
	# A source far from the field flows down a ditch towards it.
	for x in range(-6, -1):
		_put(x, -1, 0, Voxels.AIR)
	_put(-6, -1, 0, Voxels.of_ground(Tiles.Ground.WATER))
	_put(1, -1, 0, Voxels.of_ground(Tiles.Ground.FARMLAND))
	Growth.update(_server, 0.0)
	assert_eq(_at(1, -1, 0), Voxels.of_ground(Tiles.Ground.FARMLAND), "too far from the source")
	_server.fluids.touch(_server.world.loaded_voxel_at, Vector3i(-5, SEA - 1, 0), Voxels.AIR)
	for i in 100:
		_server.fluids.update(_server)
	assert_true(Voxels.is_water(_at(-2, -1, 0)), "the water ran down the ditch")
	Growth.update(_server, 0.0)
	assert_eq(_at(1, -1, 0), Voxels.of_ground(Tiles.Ground.FARMLAND_WET), "watered by the canal")


func test_crops_grow_under_glass_and_by_a_lantern_underground() -> void:
	_field()
	# A greenhouse: a glass roof over a field.
	_put(1, -1, 1, Voxels.of_ground(Tiles.Ground.FARMLAND_WET))
	_put(1, 0, 1, Voxels.of_block(Tiles.Block.WHEAT_0))
	for x in range(-1, 4):
		for z in range(-1, 4):
			_put(x, 2, z, Voxels.of_block(Tiles.Block.GLASS))
	# A cellar: a field under the rock, a lantern beside it.
	for x in range(6, 12):
		for z in range(6, 12):
			for y in range(0, 4):
				_put(x, y, z, Voxels.of_block(Tiles.Block.STONE))
	_put(8, -1, 8, Voxels.of_ground(Tiles.Ground.FARMLAND_WET))
	_put(8, 0, 8, Voxels.of_block(Tiles.Block.WHEAT_0))
	_put(9, 0, 8, Voxels.AIR)
	_put(9, 1, 8, Voxels.AIR)
	Growth.update(_server, 1.0)
	assert_eq(Voxels.block_of(_at(1, 0, 1)), Tiles.Block.WHEAT_1, "the sun through glass")
	assert_eq(Voxels.block_of(_at(8, 0, 8)), Tiles.Block.WHEAT_0, "nothing in the dark")
	_put(9, 0, 8, Voxels.of_block(Tiles.Block.LANTERN))
	Growth.update(_server, 1.0)
	assert_eq(Voxels.block_of(_at(8, 0, 8)), Tiles.Block.WHEAT_1, "a lantern lights it")


func test_a_composter_fills_rots_and_gives_compost() -> void:
	_field()
	_put(1, 0, 0, Voxels.of_block(Tiles.Block.COMPOSTER))
	var cell := Vector3i(1, SEA, 0)
	assert_true(Composting.is_composter(Tiles.Block.COMPOSTER_4))
	assert_eq(Composting.level_of(Tiles.Block.COMPOSTER_READY), Composting.FILL + 1)
	_hold(Items.Id.STONE, 4)
	_send(Msg.compost(cell, 0))
	assert_eq(Voxels.block_of(_at(1, 0, 0)), Tiles.Block.COMPOSTER, "stone does not rot")
	_hold(Items.Id.SEEDS, 10)
	for i in Composting.FILL:
		_send(Msg.compost(cell, 0))
	assert_eq(Voxels.block_of(_at(1, 0, 0)), Tiles.Block.COMPOSTER_FULL, "full")
	assert_eq(_session.inventory.counts[0], 10 - Composting.FILL, "a piece a level")
	_send(Msg.compost(cell, 0))
	assert_eq(_session.inventory.counts[0], 10 - Composting.FILL, "no room for more")
	_server.clock.set_frozen(WorldClock.FROZEN_MIDNIGHT)
	Growth.update(_server, 1.0)
	assert_eq(Voxels.block_of(_at(1, 0, 0)), Tiles.Block.COMPOSTER_READY, "rots in the dark too")
	_send(Msg.compost(cell, 0))
	assert_eq(Voxels.block_of(_at(1, 0, 0)), Tiles.Block.COMPOSTER, "emptied")
	var compost := 0
	for slot in Inventory.SLOTS:
		if _session.inventory.items[slot] == Items.Id.COMPOST:
			compost += _session.inventory.counts[slot]
	assert_eq(compost, 1, "a compost")
	# Broken, a composter gives itself back, and its compost when ready.
	var rng := RandomNumberGenerator.new()
	var full := Items.drops(Voxels.of_block(Tiles.Block.COMPOSTER_5), Vector2i.ZERO, rng)
	assert_eq(full, [Vector2i(Items.Id.COMPOSTER, 1)])
	var ready := Items.drops(Voxels.of_block(Tiles.Block.COMPOSTER_READY), Vector2i.ZERO, rng)
	assert_eq(ready, [Vector2i(Items.Id.COMPOSTER, 1), Vector2i(Items.Id.COMPOST, 1)])
	assert_true(Mining.can_place(Items.placed_voxel(Items.Id.COMPOSTER)))
	assert_eq(Mining.tool_for(Voxels.of_block(Tiles.Block.COMPOSTER_3)), Items.Tool.AXE)
	assert_true(ObjectShapes.stand_height(Tiles.Block.COMPOSTER_6) > 0.5, "stood on")


func test_compost_makes_a_crop_or_a_sapling_grow_a_stage() -> void:
	_field()
	_put(1, -1, 0, Voxels.of_ground(Tiles.Ground.FARMLAND))
	_put(1, 0, 0, Voxels.of_block(Tiles.Block.POTATOES_2))
	_put(-3, 0, -3, Voxels.of_block(Tiles.Block.OAK_SAPLING))
	_hold(Items.Id.COMPOST, 3)
	_server.clock.set_frozen(WorldClock.FROZEN_MIDNIGHT)
	_send(Msg.spread_compost(Vector3i(1, SEA, 0), 0))
	assert_eq(Voxels.block_of(_at(1, 0, 0)), Tiles.Block.POTATOES_3, "a stage at once")
	assert_eq(_session.inventory.counts[0], 2)
	_send(Msg.spread_compost(Vector3i(1, SEA, 0), 0))
	assert_eq(_session.inventory.counts[0], 2, "ripe: nothing more")
	_send(Msg.spread_compost(Vector3i(-3, SEA, -3), 0))
	assert_eq(Voxels.block_of(_at(-3, 0, -3)), Tiles.Block.YOUNG_OAK, "a sapling grows")
	_put(-3, 2, -3, Voxels.of_block(Tiles.Block.STONE))
	_send(Msg.spread_compost(Vector3i(-3, SEA, -3), 0))
	assert_eq(Voxels.block_of(_at(-3, 0, -3)), Tiles.Block.YOUNG_OAK, "no room to grow")
	assert_eq(_session.inventory.counts[0], 1)
	assert_eq(
		Composting.guess_spread(Voxels.of_block(Tiles.Block.WHEAT_1)),
		Voxels.of_block(Tiles.Block.WHEAT_2)
	)
	assert_eq(Composting.guess_spread(Voxels.of_block(Tiles.Block.OAK_SAPLING)), Voxels.AIR)


func test_the_farm_recipes() -> void:
	var cells := PackedInt32Array()
	cells.resize(Inventory.OWN_GRID * Inventory.OWN_GRID)
	for i: int in [0, 4, 5, 7, 8]:
		cells[i] = Items.Id.COPPER_INGOT
	assert_eq(Recipes.result_of(cells, Inventory.OWN_GRID), Vector2i(Items.Id.WATERING_CAN, 1))
	cells.fill(Items.Id.NONE)
	for i: int in [0, 2, 3, 5, 6, 7, 8]:
		cells[i] = Items.Id.BIRCH_PLANKS
	assert_eq(Recipes.result_of(cells, Inventory.OWN_GRID), Vector2i(Items.Id.COMPOSTER, 1))
