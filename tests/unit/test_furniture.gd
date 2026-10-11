extends TestCase
## Bedroom and living room (phase 8, step 7): storage opening as chests,
## tall furniture and beds in two cells, sleeping the night away and waking
## beside one's bed, shelves showing their things, a tablecloth on a table,
## seats, a sofa two tiles wide, the recipes.

const SEA := GameConst.SEA_LEVEL
const SOUTH := Vector2i(0, 1)
const NIGHT := 22.0 * 3600.0

var _server: GameServer
var _client: LocalTransport
var _session: GameServer.PlayerSession


## A server, a player, the cell two tiles east of their feet on stone, free
## up to three rows (and around it).
func _start() -> Vector3i:
	var settings := WorldSettings.create("Test", "42", WorldSettings.GameMode.SURVIVAL)
	_server = GameServer.new(settings, null, false)
	var transports := LocalTransport.create_pair()
	_server.connect_client(transports[1])
	transports[0].send(Msg.hello("Alex", 2))
	_server.process_messages()
	_client = transports[0]
	_session = _server.first_session()
	_server.creatures.living.clear()
	var feet := Coords.world_to_tile(_session.position)
	var cell := Vector3i(feet.x + 2, floori(_session.height + 0.01) + SEA, feet.y)
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			_server.world.set_voxel(cell + Vector3i(dx, -1, dz), Voxels.of_block(Tiles.Block.STONE))
			for up in 3:
				_server.world.set_voxel(cell + Vector3i(dx, up, dz), Voxels.AIR)
	return cell


func _hold(item: int, count := 4) -> void:
	_session.inventory.items[0] = item
	_session.inventory.counts[0] = count
	_session.inventory.selected = 0


func _send(message: Dictionary) -> void:
	_client.send(message)
	_server.process_messages()


func _block(cell: Vector3i) -> int:
	return Voxels.block_of(_server.world.voxel_at(cell))


func test_storage_opens_as_a_chest() -> void:
	for kind: int in Furniture.STORAGES:
		assert_true(ObjectShapes.is_chest(kind), "%d stores" % kind)
		assert_true(Mining.opens(Voxels.of_block(kind)))
	assert_true(ObjectShapes.is_chest(ObjectShapes.facing(Tiles.Block.COMMODE, Vector2i(1, 0))))
	assert_false(ObjectShapes.is_chest(Tiles.Block.TABLE))


func test_a_wardrobe_stands_two_levels() -> void:
	var cell := _start()
	_hold(Items.Id.WARDROBE)
	_send(Msg.block_place(cell, 0, SOUTH, Vector3i.UP))
	assert_eq(ObjectShapes.kind_of(_block(cell)), Tiles.Block.WARDROBE, "placed")
	assert_eq(_block(cell + Vector3i.UP), Tiles.Block.FURNITURE_TOP, "its top")
	var at := _server.world.voxel_at
	var eye := Vector3(cell.x + 0.5, cell.y - SEA + 1.5, cell.z + 3.0)
	var hit := VoxelRay.cast(eye, Vector3.FORWARD, 5.0, at)
	assert_eq(hit.cell, cell, "aimed at its top, the wardrobe is met")
	_send(Msg.block_break(cell + Vector3i.UP, -1))
	assert_eq(_server.world.voxel_at(cell), Voxels.AIR, "broken by its top")
	assert_eq(_server.world.voxel_at(cell + Vector3i.UP), Voxels.AIR)
	var lying := _server.items.values().map(func(d: DroppedItem) -> int: return d.item)
	assert_eq(lying, [Items.Id.WARDROBE], "one wardrobe")


func test_a_bed_lies_in_two_cells() -> void:
	var cell := _start()
	_hold(Items.Id.BED)
	_send(Msg.block_place(cell, 0, SOUTH, Vector3i.UP))
	var foot := _block(cell)
	assert_eq(ObjectShapes.kind_of(foot), Tiles.Block.BED, "its foot where placed")
	var head := cell - Vector3i(0, 0, 1)
	assert_eq(ObjectShapes.kind_of(_block(head)), Tiles.Block.BED_HEAD, "its head behind")
	assert_eq(ObjectShapes.model_block(_block(head)), -1, "its foot holds its model")
	assert_true(Tints.dyed(_block(head)), "its blanket takes a tint")
	_send(Msg.block_break(head, -1))
	assert_eq(_server.world.voxel_at(cell), Voxels.AIR, "the whole bed goes")
	var lying := _server.items.values().map(func(d: DroppedItem) -> int: return d.item)
	assert_eq(lying, [Items.Id.BED], "one bed")


func test_sleeping_passes_the_night() -> void:
	var cell := _start()
	_hold(Items.Id.BED)
	_send(Msg.block_place(cell, 0, SOUTH, Vector3i.UP))
	_server.clock.total_game_seconds = 12.0 * 3600.0
	_client.poll()
	_send(Msg.sleep(cell - Vector3i(0, 0, 1)))
	assert_eq(_session.bed, cell, "they will wake here (by its foot)")
	assert_false(_session.sleeping, "not by day")
	var told := _client.poll().filter(func(m: Dictionary) -> bool: return m["t"] == Msg.NOTICE)
	assert_eq(told.size(), 2, "where they wake, why they cannot sleep")
	_server.clock.total_game_seconds = NIGHT
	_send(Msg.sleep(cell))
	assert_true(_session.sleeping, "at night they sleep")
	var day := _server.clock.day_index()
	for i in ceili(Beds.SLEEP_SECONDS / GameConst.TICK_DELTA) + 2:
		Beds.update(_server, GameConst.TICK_DELTA)
	assert_false(_session.sleeping, "they woke")
	assert_eq(_server.clock.day_index(), day + 1, "the next day")
	assert_almost(_server.clock.time_of_day(), Beds.WAKE_HOUR * 3600.0, 1.0, "in the morning")
	# Passed out, they get up beside their bed.
	_session.health = 0
	Survival.get_up(_server, _session)
	var tile := Coords.world_to_tile(_session.position)
	assert_true(absi(tile.x - cell.x) + absi(tile.y - cell.z) <= 2, "beside the bed")


func test_shelves_show_their_things() -> void:
	var cell := _start()
	var wall := cell - Vector3i(0, 0, 1)
	_server.world.set_voxel(wall, Voxels.of_block(Tiles.Block.STONE))
	_server.world.set_voxel(cell, Voxels.of_block(Tiles.Block.SHELF))
	_hold(Items.Id.APPLE, 2)
	_send(Msg.shelf(cell, 0))
	_send(Msg.shelf(cell, 0))
	var held := Shelves.items_at(_server.world, cell)
	assert_eq(held[0], Items.Id.APPLE)
	assert_eq(held[1], Items.Id.APPLE, "one at a time")
	assert_eq(_session.inventory.items[0], Items.Id.NONE, "out of the hand")
	var coord := Coords.tile_to_chunk(Vector2i(cell.x, cell.z))
	var chunk := ChunkData.from_dict(_server.world.chunks[coord].to_dict())
	assert_true(chunk.shelves.has(cell), "sent with the chunk")
	_send(Msg.shelf(cell, 0))
	assert_eq(Shelves.items_at(_server.world, cell)[1], Items.Id.NONE, "empty-handed: one back")
	assert_eq(_session.inventory.items[0], Items.Id.APPLE)
	Shelves.spill(_server, cell)
	assert_eq(_server.items.size(), 1, "broken, its things fall")


func test_a_tablecloth_and_seats() -> void:
	var cell := _start()
	_server.world.set_voxel(cell, Voxels.of_block(Tiles.Block.TABLE))
	var cloth := Items.placed_voxel(Items.Id.TABLECLOTH)
	assert_true(Mining.fills(_server.world.voxel_at(cell), cloth), "it goes on the table")
	var placed := Mining.placement(cell, cloth, SOUTH, _server.world.voxel_at)
	assert_eq(Voxels.block_of(placed[cell]), Tiles.Block.TABLE_CLOTHED)
	var drops := Items.drops(placed[cell], Vector2i.ZERO, RandomNumberGenerator.new())
	assert_eq(drops, [Vector2i(Items.Id.TABLE, 1), Vector2i(Items.Id.TABLECLOTH, 1)])
	assert_true(Tints.dyed(Tiles.Block.TABLE_CLOTHED))
	assert_true(Furniture.is_seat(ObjectShapes.facing(Tiles.Block.CHAIR, SOUTH)), "a chair")
	assert_true(Furniture.is_seat(Tiles.Block.SOFA_END_X), "a sofa's other end")
	assert_true(Furniture.is_seat(Tiles.Block.STOOL))
	# A sofa two tiles wide.
	_hold(Items.Id.SOFA)
	_send(Msg.block_place(cell + Vector3i(0, 0, 1), 0, SOUTH, Vector3i.UP))
	var sofa := cell + Vector3i(0, 0, 1)
	var parts := Mining.object_cells(sofa, _server.world.voxel_at(sofa), _server.world.voxel_at)
	assert_eq(parts.size(), 2, "a sofa takes two tiles")


func test_the_recipes() -> void:
	var items := [
		Items.Id.BED,
		Items.Id.WARDROBE,
		Items.Id.DRESSER,
		Items.Id.BOOKCASE,
		Items.Id.COMMODE,
		Items.Id.WALL_CUPBOARD,
		Items.Id.CRATE,
		Items.Id.BASKET,
		Items.Id.SHELF,
		Items.Id.ARMCHAIR,
		Items.Id.SOFA,
		Items.Id.BENCH,
		Items.Id.STOOL,
		Items.Id.ROCKING_CHAIR,
		Items.Id.COFFEE_TABLE,
		Items.Id.DESK,
		Items.Id.NIGHTSTAND,
		Items.Id.PEDESTAL_TABLE,
		Items.Id.TABLECLOTH
	]
	for item: int in items:
		assert_ne(tr(Items.name_key(item)), Items.name_key(item), "%d named" % item)
		var made := false
		for recipe: Dictionary in Recipes.all():
			made = made or recipe["result"][0] == item
		assert_true(made, "%s has a recipe" % Items.name_key(item))
