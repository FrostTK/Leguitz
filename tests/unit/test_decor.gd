extends TestCase
## What players furnish houses and gardens with: recipes, placing (on the
## ground facing them, hung on a wall, two tiles wide), what each gives
## back, fences joining their neighbors, gates swinging (bodies go through
## open ones only), what hangs on a wall falling with it, the campfire's
## light.

const SEA := GameConst.SEA_LEVEL
const DECOR: Array[int] = [
	Items.Id.TORCH_BRACKET,
	Items.Id.CURTAINS,
	Items.Id.GLASS_PANE,
	Items.Id.WINDOW,
	Items.Id.SINK,
	Items.Id.TOILET,
	Items.Id.TABLE,
	Items.Id.CHAIR,
	Items.Id.FENCE,
	Items.Id.GATE,
	Items.Id.BIG_GATE,
	Items.Id.CAMPFIRE,
]


## Returns [server, client transport, session]: a joined player on a flat
## stone floor (level 0) with room above, nobody else around.
func _joined() -> Array:
	var settings := WorldSettings.create("Test", "42", WorldSettings.GameMode.SURVIVAL)
	var server := GameServer.new(settings, null, false)
	var transports := LocalTransport.create_pair()
	server.connect_client(transports[1])
	transports[0].send(Msg.hello("Alex", 2))
	server.process_messages()
	transports[0].poll()
	var session := server.first_session()
	server.creatures.living.clear()
	var tile := Coords.world_to_tile(session.position)
	for x in range(-6, 7):
		for z in range(-6, 7):
			var cell := Vector3i(tile.x + x, SEA, tile.y + z)
			server.world.set_voxel(cell - Vector3i(0, 1, 0), Voxels.of_block(Tiles.Block.STONE))
			for up in 4:
				server.world.set_voxel(cell + Vector3i(0, up, 0), Voxels.AIR)
	session.height = 0.0
	session.position = Coords.tile_to_world_center(tile)
	return [server, transports[0], session]


func _cell(session: GameServer.PlayerSession, dx: int, dz: int) -> Vector3i:
	var tile := Coords.world_to_tile(session.position)
	return Vector3i(tile.x + dx, SEA, tile.y + dz)


func test_every_decoration_has_a_recipe_a_block_and_comes_back() -> void:
	var made := {}
	for recipe in Recipes.all():
		made[recipe["result"][0]] = true
	var rng := RandomNumberGenerator.new()
	for item in DECOR:
		assert_true(made.has(item), "%s has a recipe" % Items.name_key(item))
		var voxel := Items.placed_voxel(item)
		assert_true(Mining.can_place(voxel), "%s can be placed" % Items.name_key(item))
		var block := Voxels.block_of(voxel)
		var blocks: Array = ObjectShapes.FACING_KINDS.get(block, [block])
		for way: int in blocks:
			var drops := Items.drops(Voxels.of_block(way), Vector2i.ZERO, rng)
			assert_eq(
				drops, [Vector2i(item, 1)], "%s gives itself back" % Tiles.Block.find_key(way)
			)
	# Open gates and a big gate's ends too.
	for block: int in [
		Tiles.Block.GATE_OPEN_EAST, Tiles.Block.BIG_GATE_END_X, Tiles.Block.BIG_GATE_OPEN_END_Z
	]:
		var drops := Items.drops(Voxels.of_block(block), Vector2i.ZERO, rng)
		assert_eq(drops.size(), 1, String(Tiles.Block.find_key(block)))
	assert_eq(Mining.tool_for(Voxels.of_block(Tiles.Block.FENCE)), Items.Tool.AXE)
	assert_eq(Mining.tool_for(Voxels.of_block(Tiles.Block.SINK_EAST)), Items.Tool.PICKAXE)
	assert_eq(Mining.hand_seconds(Voxels.of_block(Tiles.Block.GATE_OPEN_NORTH)), 2.0)


func test_what_hangs_on_a_wall_needs_a_cube_behind_and_falls_with_it() -> void:
	var setup := _joined()
	var server: GameServer = setup[0]
	var client: LocalTransport = setup[1]
	var session: GameServer.PlayerSession = setup[2]
	var wall := _cell(session, 2, 0)
	server.world.set_voxel(wall, Voxels.of_block(Tiles.Block.OAK_PLANKS))
	var bracket := Items.placed_voxel(Items.Id.TORCH_BRACKET)
	var at := wall + Vector3i(-1, 0, 0)
	var placed := Mining.placement(at, bracket, Vector2i(-1, 0), server.world.voxel_at)
	assert_eq(placed.size(), 1)
	assert_eq(Voxels.block_of(placed[at]), Tiles.Block.TORCH_BRACKET_WEST, "facing away")
	var floating := Mining.placement(at, bracket, Vector2i(1, 0), server.world.voxel_at)
	assert_true(floating.is_empty(), "nothing behind it")
	# Placed through the server, then the wall broken: it falls.
	session.inventory.items[0] = Items.Id.TORCH_BRACKET
	session.inventory.counts[0] = 1
	client.send(Msg.block_place(at, 0, Vector2i(-1, 0)))
	server.process_messages()
	assert_eq(Voxels.block_of(server.world.voxel_at(at)), Tiles.Block.TORCH_BRACKET_WEST)
	assert_false(Voxels.is_solid(server.world.voxel_at(at)), "bodies go by it")
	# Breaking the floor under it does not drop it: it hangs on its wall.
	assert_false(Mining.needs_support(server.world.voxel_at(at)))
	client.send(Msg.block_break(wall, -1))
	server.process_messages()
	assert_eq(server.world.voxel_at(at), Voxels.AIR, "fell with its wall")
	var lying := server.items.values().map(func(d: DroppedItem) -> int: return d.item)
	assert_true(Items.Id.TORCH_BRACKET in lying, "given back")


func test_fences_join_their_neighbors_and_keep_bodies_out() -> void:
	var chunk := ChunkData.new(Vector2i.ZERO)
	for lz in GameConst.CHUNK_SIZE:
		for lx in GameConst.CHUNK_SIZE:
			chunk.set_voxel(Vector3i(lx, SEA - 1, lz), Voxels.of_block(Tiles.Block.STONE))
	var fence := Voxels.of_block(Tiles.Block.FENCE)
	# A row of three fences, a gate at its east end, a block north of the
	# middle one.
	for x: int in [4, 5, 6]:
		chunk.set_voxel(Vector3i(x, SEA, 8), fence)
	chunk.set_voxel(Vector3i(7, SEA, 8), Voxels.of_block(Tiles.Block.GATE))
	chunk.set_voxel(Vector3i(5, SEA, 7), Voxels.of_block(Tiles.Block.STONE))
	var job := ChunkJob.of_chunk(chunk, func(_coord: Vector2i) -> ChunkData: return null)
	job.variants.resize(256)
	job.variants[Tiles.Block.FENCE] = ObjectShapes.FENCE_VARIANTS
	var result := ChunkMesher.build(job)
	var versions := {}
	for key: Vector2i in result.props:
		if key.x == Tiles.Block.FENCE:
			versions[key.y] = result.props[key].size()
	# North 1, east 2, south 4, west 8.
	assert_eq(versions.get(2, 0), 1, "the west end joins east")
	assert_eq(versions.get(2 | 8 | 1, 0), 1, "the middle: both ways and the block")
	assert_eq(versions.get(2 | 8, 0), 1, "the east end: the fence and the gate")
	# Nobody walks through or jumps over a fence or a shut gate; an open
	# gate lets them by.
	var world := ClientWorld.new()
	world.store(chunk)
	assert_true(PlayerBody.obstacle(Vector2i(5, 8), 0.0, world.voxel_at).has_area())
	assert_true(PlayerBody.obstacle(Vector2i(5, 8), 1.25, world.voxel_at).has_area(), "too high")
	assert_true(PlayerBody.obstacle(Vector2i(7, 8), 0.0, world.voxel_at).has_area())
	chunk.set_voxel(Vector3i(7, SEA, 8), Voxels.of_block(Tiles.Block.GATE_OPEN))
	assert_false(PlayerBody.obstacle(Vector2i(7, 8), 0.0, world.voxel_at).has_area(), "open")


func test_gates_swing_open_and_shut_but_not_on_anybody() -> void:
	var setup := _joined()
	var server: GameServer = setup[0]
	var client: LocalTransport = setup[1]
	var session: GameServer.PlayerSession = setup[2]
	# A big gate two tiles south of the player, facing them.
	var cell := _cell(session, 0, 2)
	var big := Items.placed_voxel(Items.Id.BIG_GATE)
	var cells := Mining.placement(cell, big, Vector2i(0, -1), server.world.voxel_at)
	assert_eq(cells.size(), 2, "two tiles")
	for at: Vector3i in cells:
		server.change_voxel(at, cells[at])
	var other: Vector3i = cells.keys()[1]
	assert_eq(
		Mining.object_cells(other, server.world.voxel_at(other), server.world.voxel_at).size(), 2
	)
	client.send(Msg.swing_gate(other))
	server.process_messages()
	for at: Vector3i in cells:
		var block := Voxels.block_of(server.world.voxel_at(at))
		assert_true(ObjectShapes.is_open(block), "both ends open")
		assert_false(Voxels.is_solid(server.world.voxel_at(at)))
	# Someone in the gateway: it does not shut on them.
	session.position = Coords.tile_to_world_center(Vector2i(cell.x, cell.z))
	client.send(Msg.swing_gate(cell))
	server.process_messages()
	assert_true(ObjectShapes.is_open(Voxels.block_of(server.world.voxel_at(cell))), "still open")
	session.position += Vector2(0, -2.0 * GameConst.TILE_SIZE)
	client.send(Msg.swing_gate(cell))
	server.process_messages()
	assert_false(ObjectShapes.is_open(Voxels.block_of(server.world.voxel_at(cell))), "shut")
	# Broken: one gate back, both ends gone.
	client.send(Msg.block_break(other, -1))
	server.process_messages()
	for at: Vector3i in cells:
		assert_eq(server.world.voxel_at(at), Voxels.AIR)
	var lying := server.items.values().map(func(d: DroppedItem) -> int: return d.item)
	assert_eq(lying.count(Items.Id.BIG_GATE), 1)


func test_a_campfire_burns_and_keeps_monsters_away() -> void:
	var fire := Voxels.of_block(Tiles.Block.CAMPFIRE)
	assert_true(ObjectShapes.is_lit(Tiles.Block.CAMPFIRE))
	var voxel_at := func(cell: Vector3i) -> int: return fire if cell == Vector3i(2, SEA, 0) else 0
	assert_true(Light.near_fire(voxel_at, Vector3i(0, SEA, 0)))
	assert_false(Light.near_fire(voxel_at, Vector3i(20, SEA, 0)))


func test_what_hangs_high_over_the_ground_is_drawn() -> void:
	var chunk := ChunkData.new(Vector2i.ZERO)
	for lz in GameConst.CHUNK_SIZE:
		for lx in GameConst.CHUNK_SIZE:
			chunk.set_voxel(Vector3i(lx, SEA - 1, lz), Voxels.of_block(Tiles.Block.STONE))
	# A wall four levels high, curtains hung near its top, over the grass.
	for up in 4:
		chunk.set_voxel(Vector3i(5, SEA + up, 5), Voxels.of_block(Tiles.Block.OAK_PLANKS))
	var curtains := Voxels.of_block(Tiles.Block.CURTAINS)
	chunk.set_voxel(Vector3i(5, SEA + 3, 6), curtains)
	var column := 6 * GameConst.CHUNK_SIZE + 5
	assert_eq(chunk.raised.get(column, 0), SEA + 4, "rises over its column's ground")
	var copy := ChunkData.from_dict(chunk.to_dict())
	assert_eq(copy.raised, chunk.raised, "sent with the chunk")
	copy.recompute_tops()
	assert_eq(copy.raised, chunk.raised, "found again when loaded")
	var job := ChunkJob.of_chunk(chunk, func(_coord: Vector2i) -> ChunkData: return null)
	job.variants.resize(256)
	job.variants[Tiles.Block.CURTAINS] = 1
	var result := ChunkMesher.build(job)
	assert_true(result.props.has(Vector2i(Tiles.Block.CURTAINS, 0)), "drawn")
	chunk.set_voxel(Vector3i(5, SEA + 3, 6), Voxels.AIR)
	assert_false(chunk.raised.has(column), "gone with it")
