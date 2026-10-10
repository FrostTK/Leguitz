extends TestCase
## Doors, trapdoors, ladders, shutters, bars and railings (phase 8, step
## 4): a door takes two cells, opens and shuts with its top, keeps bodies
## and the daylight out shut; double doors hang on their outer sides and
## open together; a trapdoor is walked on shut, climbed through open; a
## ladder is climbed and never hurts; shutters close and take a tint; bars
## and railings join; the recipes.

const SEA := GameConst.SEA_LEVEL
const N := Items.Id.NONE

var _server: GameServer
var _client: LocalTransport
var _session: GameServer.PlayerSession


## A server, a player, the cell two tiles east of their feet on stone, free
## up to three rows.
func _start() -> Vector3i:
	var settings := WorldSettings.create("Test", "42", WorldSettings.GameMode.SURVIVAL)
	_server = GameServer.new(settings, null, false)
	var transports := LocalTransport.create_pair()
	_server.connect_client(transports[1])
	transports[0].send(Msg.hello("Alex", 2))
	_server.process_messages()
	_client = transports[0]
	_session = _server.first_session()
	var feet := Coords.world_to_tile(_session.position)
	var cell := Vector3i(feet.x + 2, floori(_session.height + 0.01) + SEA, feet.y)
	for dx in range(-1, 2):
		_server.world.set_voxel(cell + Vector3i(dx, -1, 0), Voxels.of_block(Tiles.Block.STONE))
		for up in 3:
			_server.world.set_voxel(cell + Vector3i(dx, up, 0), Voxels.AIR)
	return cell


func _hold(item: int) -> void:
	_session.inventory.items[0] = item
	_session.inventory.counts[0] = 4
	_session.inventory.wear[0] = 0


func _send(message: Dictionary) -> void:
	_client.send(message)
	_server.process_messages()


## Voxels from a dictionary (cell -> voxel; air elsewhere).
func _world(cells: Dictionary) -> Callable:
	return func(cell: Vector3i) -> int: return cells.get(cell, Voxels.AIR)


func test_a_door_takes_two_cells_and_swings() -> void:
	var cell := _start()
	_hold(Items.Id.SPRUCE_DOOR)
	_send(Msg.block_place(cell, 0, Vector2i(0, 1), Vector3i.UP))
	var door := Voxels.block_of(_server.world.voxel_at(cell))
	assert_eq(ObjectShapes.kind_of(door), Tiles.Block.SPRUCE_DOOR, "the door")
	assert_eq(_server.world.voxel_at(cell + Vector3i.UP), Voxels.of_block(Tiles.Block.DOOR_TOP))
	var tile := Vector2i(cell.x, cell.z)
	var level := float(cell.y - SEA)
	var at := _server.world.voxel_at
	assert_true(PlayerBody.obstacle(tile, level, at).has_area(), "shut, nobody goes through")
	assert_eq(LightField.passing(Voxels.of_block(door)), LightField.OPAQUE, "nor the daylight")
	assert_eq(LightField.passing(Voxels.of_block(Tiles.Block.DOOR_TOP)), LightField.OPAQUE)
	# Used on its top, it opens, its top with it.
	_send(Msg.swing_gate(cell + Vector3i.UP))
	var open := Voxels.block_of(_server.world.voxel_at(cell))
	assert_true(ObjectShapes.is_open(open), "open")
	assert_eq(ObjectShapes.front_of(open), Vector2i(0, 1), "the same way")
	var top := _server.world.voxel_at(cell + Vector3i.UP)
	assert_eq(top, Voxels.of_block(Tiles.Block.DOOR_TOP_OPEN))
	assert_false(PlayerBody.obstacle(tile, level, at).has_area(), "open, one walks through")
	assert_eq(LightField.passing(Voxels.of_block(open)), LightField.CLEAR)
	# Broken by its top, it goes and gives itself back.
	_send(Msg.block_break(cell + Vector3i.UP, -1))
	assert_eq(_server.world.voxel_at(cell), Voxels.AIR)
	assert_eq(_server.world.voxel_at(cell + Vector3i.UP), Voxels.AIR)
	var lying := _server.items.values().map(func(d: DroppedItem) -> int: return d.item)
	assert_eq(lying, [Items.Id.SPRUCE_DOOR], "one door")


func test_double_doors_open_together() -> void:
	var south := Vector2i(0, 1)
	var a := ObjectShapes.facing(Tiles.Block.OAK_DOOR, south)
	var cells := {
		Vector3i(0, SEA, 0): Voxels.of_block(a),
		Vector3i(0, SEA + 1, 0): Voxels.of_block(Tiles.Block.DOOR_TOP),
		Vector3i(1, SEA, 0): Voxels.of_block(a),
		Vector3i(1, SEA + 1, 0): Voxels.of_block(Tiles.Block.DOOR_TOP),
	}
	var at := _world(cells)
	assert_eq(Openings.left_of(a), Vector2i(-1, 0), "facing south, its left is west")
	assert_false(Openings.hinge_right(a, Vector3i(0, SEA, 0), at), "the west one on its left")
	assert_true(Openings.hinge_right(a, Vector3i(1, SEA, 0), at), "the east one on its right")
	assert_eq(Openings.partner(a, Vector3i(0, SEA, 0), at), Vector3i(1, SEA, 0))
	var swung := Mining.swung_cells(Vector3i(0, SEA, 0), Voxels.of_block(a), at)
	assert_eq(swung.size(), 4, "both doors and their tops")
	assert_true(ObjectShapes.is_open(Voxels.block_of(swung[Vector3i(1, SEA, 0)])))
	assert_eq(ObjectShapes.variant_count(a), 2, "two versions: hung left or right")
	var glazed := ObjectShapes.facing(Tiles.Block.GLAZED_DOOR, south)
	assert_eq(Openings.top_of(glazed), Tiles.Block.DOOR_TOP_GLAZED)
	var light := LightField.passing(Voxels.of_block(Tiles.Block.DOOR_TOP_GLAZED))
	assert_eq(light, LightField.CLEAR, "a glazed door lets the day in")


func test_a_trapdoor_is_walked_on_shut() -> void:
	var stone := Voxels.of_block(Tiles.Block.STONE)
	var cells := {Vector3i(1, SEA - 1, 0): stone, Vector3i(0, SEA - 3, 0): stone}
	var at := _world(cells)
	var trapdoor := Voxels.of_block(Tiles.Block.OAK_TRAPDOOR)
	var hole := Vector3i(0, SEA - 1, 0)
	var placed := Mining.placement(hole, trapdoor, Vector2i(-1, 0), at, Vector3i.LEFT)
	assert_eq(placed.size(), 1, "hung on the side of the hole")
	cells[hole] = placed[hole]
	var feet := Vector2(8.0, 8.0)
	assert_almost(PlayerBody.support(feet, 0.5, at), 0.0, 0.001, "shut: the floor's level")
	cells[hole] = Voxels.of_block(ObjectShapes.swung(Voxels.block_of(placed[hole])))
	assert_almost(PlayerBody.support(feet, 0.5, at), -2.0, 0.001, "open: down the hole")
	assert_true(ObjectShapes.is_wall_mounted(Tiles.Block.IRON_TRAPDOOR_OPEN_EAST))


func test_a_ladder_is_climbed() -> void:
	var stone := Voxels.of_block(Tiles.Block.STONE)
	var ladder := Voxels.of_block(ObjectShapes.facing(Tiles.Block.LADDER, Vector2i(1, 0)))
	var cells := {}
	for x in range(-1, 2):
		cells[Vector3i(x, SEA - 1, 0)] = stone
	for row in range(SEA, SEA + 4):
		cells[Vector3i(-1, row, 0)] = stone
		cells[Vector3i(0, row, 0)] = ladder
	var at := _world(cells)
	var body := PlayerBody.new()
	body.place(Vector2(8.0, 8.0), 0.0)
	for i in 10:
		body.step(Vector2.ZERO, true, 0.1, at)
	assert_true(body.height > 2.0, "it climbs while jump is held")
	var high := body.height
	body.step(Vector2.ZERO, false, 0.1, at, true)
	assert_almost(body.height, high, 0.001, "it holds on")
	for i in 30:
		body.step(Vector2.ZERO, false, 0.1, at)
	assert_almost(body.height, 0.0, 0.001, "it slides down")
	assert_eq(body.take_fall(), 0.0, "and never falls")


func test_shutters_close_and_take_a_tint() -> void:
	var cell := _start()
	var window := cell + Vector3i(1, 1, 0)
	_server.world.set_voxel(window, Voxels.of_block(Tiles.Block.WINDOW))
	_hold(Items.Id.SHUTTERS)
	var at := cell + Vector3i(0, 1, 0)
	_send(Msg.block_place(at, 0, Vector2i(-1, 0), Vector3i.LEFT))
	var open := Voxels.block_of(_server.world.voxel_at(at))
	assert_eq(ObjectShapes.kind_of(open), Tiles.Block.SHUTTERS, "hung outside the window")
	assert_true(Tints.dyed(open), "paintable")
	_send(Msg.swing_gate(at))
	var shut := Voxels.block_of(_server.world.voxel_at(at))
	assert_eq(ObjectShapes.kind_of(shut), Tiles.Block.SHUTTERS_CLOSED)
	assert_eq(LightField.passing(Voxels.of_block(shut)), LightField.OPAQUE, "the day kept out")
	var drops := Items.drops(Voxels.of_block(shut), Vector2i.ZERO, RandomNumberGenerator.new())
	assert_eq(drops[0].x, Items.Id.SHUTTERS)


func test_bars_and_railings_join() -> void:
	var bars := Tiles.Block.IRON_BARS
	assert_true(Openings.joins(bars, Voxels.of_block(bars)))
	assert_true(Openings.joins(bars, Voxels.of_block(Tiles.Block.GLASS_PANE_WEST)), "panes")
	assert_true(Openings.joins(bars, Voxels.of_block(Tiles.Block.STONE)), "walls")
	assert_false(Openings.joins(bars, Voxels.of_block(Tiles.Block.WOOD_RAILING)))
	var railing := Tiles.Block.IRON_RAILING
	assert_true(Openings.joins(railing, Voxels.of_block(Tiles.Block.WOOD_RAILING)))
	assert_eq(ObjectShapes.variant_count(railing), ObjectShapes.FENCE_VARIANTS)
	assert_eq(ObjectShapes.blocking_levels(railing, 0), 2, "nobody jumps over")
	assert_eq(LightField.passing(Voxels.of_block(bars)), LightField.CLEAR, "seen through")


func test_the_recipes() -> void:
	var o := Items.Id.OAK_PLANKS
	var b := Items.Id.BIRCH_PLANKS
	var i := Items.Id.IRON_INGOT
	var g := Items.Id.GLASS
	var s := Items.Id.STICK
	var three := func(cells: Array) -> Vector2i:
		return Recipes.result_of(PackedInt32Array(cells), 3)
	assert_eq(three.call([b, b, N, b, b, N, b, b, N]), Vector2i(Items.Id.BIRCH_DOOR, 3))
	assert_eq(three.call([i, i, N, i, i, N, i, i, N]), Vector2i(Items.Id.IRON_DOOR, 3))
	assert_eq(three.call([g, g, N, g, g, N, o, o, N]), Vector2i(Items.Id.GLAZED_DOOR, 3))
	assert_eq(three.call([o, o, o, b, b, b, N, N, N]), Vector2i(Items.Id.OAK_TRAPDOOR, 2))
	assert_eq(three.call([s, N, s, s, o, s, s, N, s]), Vector2i(Items.Id.LADDER, 3))
	assert_eq(three.call([o, o, N, s, s, N, o, o, N]), Vector2i(Items.Id.SHUTTERS, 2))
	assert_eq(three.call([i, i, i, i, i, i, N, N, N]), Vector2i(Items.Id.IRON_BARS, 16))
	assert_eq(three.call([o, o, o, s, s, s, N, N, N]), Vector2i(Items.Id.WOOD_RAILING, 4))
	assert_eq(three.call([i, N, i, i, i, i, i, N, i]), Vector2i(Items.Id.IRON_RAILING, 6))
	var open := ObjectShapes.facing(Tiles.Block.ACACIA_DOOR_OPEN, Vector2i(-1, 0))
	assert_eq(
		Items.item_placing(ObjectShapes.pair_of(ObjectShapes.base_kind(open))), Items.Id.ACACIA_DOOR
	)
	assert_eq(Mining.tool_for(Voxels.of_block(open)), Items.Tool.AXE, "by its shut kind")


func test_one_climbs_out_of_a_cellar() -> void:
	var stone := Voxels.of_block(Tiles.Block.STONE)
	var ladder := Voxels.of_block(ObjectShapes.facing(Tiles.Block.LADDER, Vector2i(1, 0)))
	var cells := {}
	for x in range(-1, 3):
		for z in range(-1, 2):
			cells[Vector3i(x, SEA - 1, z)] = stone
			cells[Vector3i(x, SEA - 5, z)] = stone
	# The hole over the shaft (an open trapdoor), the ladder under it.
	cells[Vector3i(0, SEA - 1, 0)] = Voxels.of_block(
		ObjectShapes.facing(Tiles.Block.OAK_TRAPDOOR_OPEN, Vector2i(1, 0))
	)
	for row in range(SEA - 4, SEA - 1):
		cells[Vector3i(-1, row, 0)] = stone
		cells[Vector3i(0, row, 0)] = ladder
		cells[Vector3i(1, row, 0)] = stone
	var at := _world(cells)
	var body := PlayerBody.new()
	body.place(Vector2(8.0, 8.0), -4.0)
	for i in 30:
		body.step(Vector2.ZERO, true, 0.1, at)
	assert_true(body.height > -0.6, "up to the floor's edge: %f" % body.height)
	for i in 10:
		body.step(Vector2(16.0, 0.0) * 0.1, true, 0.1, at)
	assert_almost(body.height, 0.0, 0.01, "and out onto the floor")
	assert_true(body.feet.x > 16.0)
