extends TestCase
## Boats: a shipyard facing the water, a boat built on its slipway and
## launched, its slots' rules, boarding, steering (rowing, the hull kept on
## the water), leaving onto the bank, the engine burning coal, animals on a
## lead coming aboard, docking, breaking into its parts, lava, saves.

const SEA := GameConst.SEA_LEVEL

var _server: GameServer
var _client: LocalTransport
var _session: GameServer.PlayerSession
var _yard := Vector3i.ZERO


## A server, a player on grass by a pond three deep (from 3 to 12 tiles
## east, 9 across), a shipyard on the bank between them facing it; noon.
func _pond() -> void:
	var settings := WorldSettings.create("Test", "42", WorldSettings.GameMode.SURVIVAL)
	_server = GameServer.new(settings, null, false)
	var transports := LocalTransport.create_pair()
	_server.connect_client(transports[1])
	transports[0].send(Msg.hello("Alex", 2))
	_server.process_messages()
	_client = transports[0]
	_session = _server.first_session()
	_session.height = 0.0
	_server.clock.set_frozen(WorldClock.FROZEN_NOON)
	var tile := Coords.world_to_tile(_session.position)
	for dz in range(-6, 7):
		for dx in range(-3, 15):
			var column := Vector3i(tile.x + dx, SEA - 1, tile.y + dz)
			var pond := dx >= 3 and dx <= 12 and absi(dz) <= 4
			for down in 4:
				var ground := Tiles.Ground.WATER if pond and down < 3 else Tiles.Ground.GRASS
				_server.world.set_voxel(column - Vector3i(0, down, 0), Voxels.of_ground(ground))
			for up in range(1, 6):
				_server.world.set_voxel(column + Vector3i(0, up, 0), Voxels.AIR)
	_yard = Vector3i(tile.x + 2, SEA, tile.y)
	var east := ObjectShapes.facing(Tiles.Block.SHIPYARD, Vector2i(1, 0))
	_server.world.set_voxel(_yard, Voxels.of_block(east))


func _send(message: Dictionary) -> void:
	_client.send(message)
	_server.process_messages()


## Puts `count` of an item on the cursor and clicks a slot of the boat
## screen open with it.
func _put(item: int, slot: int, count := 1) -> void:
	var bag := _session.inventory
	bag.items[Inventory.CURSOR] = item
	bag.counts[Inventory.CURSOR] = count
	_send(Msg.boat_click(slot, false, false))


## A boat built on the shipyard: a stern, `sections` sections, a bow, a
## bench on its first place and a chest on its second.
func _build(sections := 1) -> Boat:
	_send(Msg.open_yard(_yard))
	_put(Items.Id.BOAT_STERN, Boat.STERN)
	_put(Items.Id.BOAT_SECTION, Boat.SECTIONS, sections)
	_put(Items.Id.BOAT_BOW, Boat.BOW)
	_put(Items.Id.BOAT_BENCH, Boat.PLACE)
	_put(Items.Id.CHEST, Boat.PLACE + 1)
	return _server.boats.on_yard(_yard)


func test_a_shipyard_faces_the_water() -> void:
	_pond()
	var yard := Voxels.of_block(Tiles.Block.SHIPYARD)
	var toward_player := Vector2i(-1, 0)
	var bank := _yard + Vector3i(0, 0, 2)
	var placed := Mining.placement(bank, yard, toward_player, _server.world.voxel_at)
	assert_eq(placed.size(), 1, "on the bank")
	var block := Voxels.block_of(placed.get(bank, Voxels.AIR))
	assert_eq(ObjectShapes.front_of(block), Vector2i(1, 0), "facing the water, not the player")
	var dry := _yard - Vector3i(3, 0, 0)
	assert_true(Mining.placement(dry, yard, toward_player, _server.world.voxel_at).is_empty())


func test_a_boat_is_built_on_the_slipway_and_launched() -> void:
	_pond()
	_send(Msg.open_yard(_yard))
	assert_eq(_session.yard_open, _yard, "its screen open")
	assert_true(_server.boats.on_yard(_yard) == null, "no boat yet")
	var boat := _build(2)
	assert_true(boat != null, "a boat on the slipway")
	assert_eq(boat.sections(), 2)
	assert_eq(boat.places(), 4, "two places and one a section")
	assert_true(boat.complete())
	assert_true(boat.chests.has(1), "a chest on its second place")
	_send(Msg.boat_act(Boats.Act.LAUNCH))
	assert_eq(boat.yard, Boat.NO_YARD, "afloat")
	var row := BoatBody.water_row(boat)
	assert_eq(row, SEA - 1, "on the pond")
	assert_true(BoatBody.fits(boat, boat.at, boat.yaw, row, _server.world.voxel_at))
	assert_almost(boat.forward().x, 1.0, 0.001, "its bow out over the water")
	var bag := _session.inventory
	bag.items[Inventory.CURSOR] = Items.Id.NONE
	_send(Msg.open_boat(boat.id))
	_send(Msg.boat_click(Boat.BOW, false, false))
	assert_eq(boat.slots.items[Boat.BOW], Items.Id.BOAT_BOW, "the hull only at a shipyard")


func test_the_slots_keep_their_rules() -> void:
	var boat := Boat.new()
	var bag := Inventory.new()
	bag.items[Inventory.CURSOR] = Items.Id.BOAT_BENCH
	bag.counts[Inventory.CURSOR] = 1
	assert_eq(boat.click(bag, Boat.ENGINE, false, false, true), "-", "a bench is no engine")
	assert_eq(boat.click(bag, Boat.PLACE + 2, false, false, true), "-", "only as many places")
	assert_eq(boat.click(bag, Boat.PLACE + 1, false, false, true), "")
	bag.items[Inventory.CURSOR] = Items.Id.BOAT_SECTION
	bag.counts[Inventory.CURSOR] = 5
	boat.click(bag, Boat.SECTIONS, false, false, true)
	assert_eq(boat.sections(), Boat.MOST_SECTIONS, "three sections at most")
	assert_eq(bag.counts[Inventory.CURSOR], 2)
	bag.items[Inventory.CURSOR] = Items.Id.CHEST
	bag.counts[Inventory.CURSOR] = 1
	boat.click(bag, Boat.PLACE + 4, false, false, true)
	boat.chests[4].items[0] = Items.Id.STONE
	boat.chests[4].counts[0] = 3
	assert_eq(boat.refusal(Boat.PLACE + 4, true), "HUD_BOAT_CHEST_FULL", "a chest leaves empty")
	assert_eq(boat.refusal(Boat.SECTIONS, true), "HUD_BOAT_LAST_PLACE", "its place is taken")
	boat.seats[1] = 7
	assert_eq(boat.refusal(Boat.PLACE + 1, true), "HUD_BOAT_SEAT_TAKEN")
	assert_eq(boat.refusal(Boat.BOW, false), "-")
	bag.items[Inventory.CURSOR] = Items.Id.COAL
	bag.counts[Inventory.CURSOR] = 64
	boat.click(bag, Boat.FUEL, false, false, false)
	assert_eq(boat.fuel(), 64, "coal goes in afloat")
	assert_false(boat.powered(), "no engine")


func test_a_boat_is_boarded_rowed_and_left() -> void:
	_pond()
	var boat := _build()
	_send(Msg.boat_act(Boats.Act.LAUNCH))
	_send(Msg.board(boat.id))
	assert_eq(boat.pilot, _session.id, "at the helm")
	assert_eq(_session.boat, boat.id)
	var start := boat.at
	for i in 20:
		BoatBody.step(boat, 1.0, 0.0, false, 0.05, _server.world.voxel_at)
	assert_true(boat.at.x > start.x + 0.2, "rowed out")
	assert_true(boat.speed <= BoatBody.ROW_SPEED, "no faster than oars")
	for i in 400:
		BoatBody.step(boat, 1.0, 0.0, false, 0.05, _server.world.voxel_at)
	var row := BoatBody.water_row(boat)
	assert_true(BoatBody.fits(boat, boat.at, boat.yaw, row, _server.world.voxel_at), "afloat")
	var tile := Coords.world_to_tile(_session.position)
	var bow := boat.at.x + boat.length() * 0.5
	assert_true(bow <= tile.x + 13.01, "stopped at the far bank")
	boat.at = start
	_send(Msg.leave_boat())
	assert_eq(boat.pilot, -1, "off the boat")
	assert_eq(_session.boat, -1)
	var feet := Coords.world_to_tile(_session.position)
	assert_true(_server.world.can_stand(feet, SEA), "on the bank")


func test_the_engine_burns_coal() -> void:
	_pond()
	var boat := _build()
	_put(Items.Id.COAL_ENGINE, Boat.ENGINE)
	_put(Items.Id.COAL, Boat.FUEL, 2)
	_send(Msg.boat_act(Boats.Act.LAUNCH))
	_send(Msg.board(boat.id))
	assert_true(boat.powered(), "coal to burn")
	var report := Msg.boat_steer(boat)
	report["throttle"] = 1.0
	_send(report)
	_server.boats.update(_server, 30.0)
	assert_eq(boat.fuel(), 1, "a coal burning")
	_server.boats.update(_server, 30.0)
	assert_eq(boat.fuel(), 0, "the next one")
	_server.boats.update(_server, 61.0)
	assert_false(boat.powered(), "out of coal")
	assert_eq(boat.burn, 0.0)


func test_led_animals_come_aboard() -> void:
	_pond()
	var boat := _build(1)
	_put(Items.Id.BOAT_BENCH, Boat.PLACE + 2)
	_send(Msg.boat_act(Boats.Act.LAUNCH))
	var feet := _session.position + Vector2(GameConst.TILE_SIZE, 0.0)
	var sheep := _server.creatures.add(Species.Id.SHEEP, feet, 0.0) as Animal
	sheep.leader = _session.id
	_send(Msg.board(boat.id))
	assert_eq(sheep.seated, boat.id, "aboard on a free bench")
	assert_true(-sheep.id in boat.seats.values())
	_server.boats.update(_server, 0.05)
	var seat := boat.seat(boat.seats.find_key(-sheep.id))
	assert_almost(sheep.body.height, seat.y, 0.01, "sitting on it")
	_send(Msg.leave_boat())
	assert_eq(sheep.seated, -1, "off with the player")
	assert_true(boat.seats.is_empty())


func test_a_boat_docks_and_breaks_into_its_parts() -> void:
	_pond()
	var boat := _build()
	_send(Msg.boat_act(Boats.Act.LAUNCH))
	_send(Msg.boat_act(Boats.Act.DOCK))
	assert_eq(boat.yard, _yard, "back up the slipway")
	_send(Msg.boat_act(Boats.Act.LAUNCH))
	var items := _server.items.size()
	for i in Boats.BREAK_HITS:
		_send(Msg.boat_hit(boat.id, -1))
	assert_false(_server.boats.living.has(boat.id), "broken")
	var dropped := {}
	for item: DroppedItem in _server.items.values():
		dropped[item.item] = true
	assert_true(_server.items.size() > items, "its parts fall")
	for part: int in [Items.Id.BOAT_BOW, Items.Id.BOAT_STERN, Items.Id.CHEST]:
		assert_true(dropped.has(part), "%s dropped" % Items.name_key(part))


func test_lava_burns_a_boat_and_boats_are_saved() -> void:
	_pond()
	var boat := _build(2)
	boat.chests[1].items[0] = Items.Id.DIAMOND
	boat.chests[1].counts[0] = 2
	var saved := Boats.new()
	saved.load_save(_server.boats.to_save())
	var copy: Boat = saved.living[boat.id]
	assert_eq(copy.sections(), 2, "saved whole")
	assert_eq(copy.chests[1].items[0], Items.Id.DIAMOND, "with what it carries")
	assert_eq(copy.yard, _yard, "on its slipway")
	_send(Msg.boat_act(Boats.Act.LAUNCH))
	_send(Msg.board(boat.id))
	var side := Vector3i(floori(boat.at.x), SEA - 1, floori(boat.at.z) + 1)
	_server.world.set_voxel(side, Voxels.of_ground(Tiles.Ground.LAVA))
	_server.boats.update(_server, 0.05)
	assert_false(_server.boats.living.has(boat.id), "burnt")
	assert_eq(_session.boat, -1, "the pilot thrown off")
