extends TestCase
## Aiming at voxels, breaking and placing them.

const SEA := GameConst.SEA_LEVEL

## Cells that are not plain (stone under level 0, air above).
var _cells: Dictionary[Vector3i, int] = {}


func _voxel_at(cell: Vector3i) -> int:
	if _cells.has(cell):
		return _cells[cell]
	return Voxels.of_block(Tiles.Block.STONE) if cell.y < SEA else Voxels.AIR


func test_a_ray_meets_the_first_cube_and_its_side() -> void:
	_cells.clear()
	var down := VoxelRay.cast(Vector3(0.5, 3.5, 0.5), Vector3.DOWN, 10.0, _voxel_at)
	assert_eq(down.cell, Vector3i(0, SEA - 1, 0), "the ground under")
	assert_eq(down.normal, Vector3i.UP, "met on its top")
	assert_almost(down.distance, 3.5)
	_cells[Vector3i(3, SEA, 0)] = Voxels.of_block(Tiles.Block.STONE)
	var across := VoxelRay.cast(Vector3(0.5, 0.5, 0.5), Vector3.RIGHT, 10.0, _voxel_at)
	assert_eq(across.cell, Vector3i(3, SEA, 0))
	assert_eq(across.normal, Vector3i.LEFT, "a block placed against it goes back towards the eye")
	assert_almost(across.distance, 2.5)
	assert_eq(VoxelRay.cast(Vector3(0.5, 0.5, 0.5), Vector3.RIGHT, 2.0, _voxel_at), null, "too far")


func test_a_ray_goes_through_water_to_the_bed() -> void:
	_cells.clear()
	var water := Voxels.of_ground(Tiles.Ground.WATER)
	for y in range(SEA - 3, SEA):
		_cells[Vector3i(0, y, 0)] = water
	var hit := VoxelRay.cast(Vector3(0.5, 2.0, 0.5), Vector3.DOWN, 10.0, _voxel_at)
	assert_eq(hit.cell, Vector3i(0, SEA - 4, 0))


func test_trees_are_met_on_their_trunk_and_plants_low_in_their_cell() -> void:
	_cells.clear()
	var oak := Voxels.of_block(Tiles.Block.OAK)
	_cells[Vector3i(5, SEA, 5)] = oak
	var box := VoxelRay.object_box(Tiles.Block.OAK, Vector3i(5, SEA, 5))
	assert_true(box.size.y >= 3.0, "trunks are several levels tall")
	assert_true(box.size.x < 1.0, "and thinner than their tile")
	# High up the trunk, far above the tree's own voxel.
	var trunk := VoxelRay.cast(Vector3(2.0, 2.5, 5.5), Vector3.RIGHT, 10.0, _voxel_at)
	assert_eq(trunk.cell, Vector3i(5, SEA, 5), "the tree, by its voxel")
	assert_almost(trunk.distance, box.position.x - 2.0, 0.001)
	assert_eq(trunk.normal, Vector3i.LEFT)
	# Beside the trunk, in the same tile: nothing.
	var beside := VoxelRay.cast(Vector3(2.0, 2.5, 5.02), Vector3.RIGHT, 10.0, _voxel_at)
	assert_eq(beside, null)
	var grass := Voxels.of_block(Tiles.Block.TALL_GRASS)
	_cells[Vector3i(7, SEA, 2)] = grass
	var plant := VoxelRay.cast(Vector3(7.5, 3.0, 2.5), Vector3.DOWN, 10.0, _voxel_at)
	assert_eq(plant.cell, Vector3i(7, SEA, 2))
	assert_almost(plant.distance, 3.0 - VoxelRay.PLANT_HEIGHT, 0.001)


func test_breaking_takes_longer_for_harder_blocks() -> void:
	var dirt := Mining.hand_seconds(Voxels.of_ground(Tiles.Ground.DIRT))
	var stone := Mining.hand_seconds(Voxels.of_block(Tiles.Block.STONE))
	var flower := Mining.hand_seconds(Voxels.of_block(Tiles.Block.FLOWER_RED))
	assert_true(flower < dirt and dirt < stone)
	assert_true(Mining.hand_seconds(Voxels.of_block(Tiles.Block.OAK)) > dirt, "chopping a tree")
	for voxel in 256:
		if Voxels.is_cube(voxel) or Voxels.is_object(voxel):
			assert_true(Mining.hand_seconds(voxel) > 0.0)
	assert_false(Mining.can_break(Voxels.of_ground(Tiles.Ground.WATER), SEA), "not water")
	assert_false(Mining.can_break(Voxels.AIR, SEA))
	assert_false(Mining.can_break(Voxels.of_block(Tiles.Block.STONE), 0), "the world's bottom")
	assert_true(Mining.can_place(Voxels.of_ground(Tiles.Ground.DIRT)))
	assert_false(Mining.can_place(Voxels.of_block(Tiles.Block.TALL_GRASS)), "plants come later")
	assert_false(Mining.can_place(Voxels.of_ground(Tiles.Ground.WATER)))


func test_tools_break_what_they_are_made_for_faster() -> void:
	var stone := Voxels.of_block(Tiles.Block.STONE)
	var grass := Voxels.of_ground(Tiles.Ground.GRASS)
	var oak := Voxels.of_block(Tiles.Block.OAK)
	var hand := Mining.hand_seconds(stone)
	assert_eq(Mining.break_seconds(stone, Items.Id.NONE), hand, "by hand")
	assert_eq(Mining.break_seconds(stone, Items.Id.DIRT), hand, "a block in hand is a hand")
	assert_almost(Mining.break_seconds(stone, Items.Id.WOODEN_PICKAXE), hand / 2.0)
	assert_eq(Mining.break_seconds(stone, Items.Id.DIAMOND_SHOVEL), hand, "not made for stone")
	assert_true(Mining.break_seconds(grass, Items.Id.STONE_SHOVEL) < Mining.hand_seconds(grass))
	assert_true(Mining.break_seconds(oak, Items.Id.IRON_AXE) < Mining.hand_seconds(oak), "chop")
	assert_eq(Mining.tool_for(Voxels.of_ground(Tiles.Ground.ICE)), Items.Tool.PICKAXE)
	assert_eq(Mining.tool_for(Voxels.of_ground(Tiles.Ground.SAND)), Items.Tool.SHOVEL)
	assert_eq(Mining.tool_for(Voxels.of_block(Tiles.Block.DIAMOND_ORE)), Items.Tool.PICKAXE)
	assert_eq(Mining.tool_for(Voxels.of_block(Tiles.Block.FLOWER_RED)), Items.Tool.NONE, "plants")
	assert_eq(Mining.tool_for(Voxels.of_ground(Tiles.Ground.WATER)), Items.Tool.NONE)
	# Better materials break faster (gold the fastest, as in Minecraft).
	var last := hand
	for tier: int in [
		Items.Tier.WOOD,
		Items.Tier.STONE,
		Items.Tier.COPPER,
		Items.Tier.IRON,
		Items.Tier.DIAMOND,
		Items.Tier.GOLD,
	]:
		var pickaxe: int = Items.tools_of_tier(tier)[0]
		var seconds := Mining.break_seconds(stone, pickaxe)
		assert_true(seconds < last, "%s breaks faster" % Items.name_key(pickaxe))
		last = seconds
	for item: int in Items.TOOLS:
		for voxel in 256:
			if Voxels.is_cube(voxel) or Voxels.is_object(voxel):
				assert_true(Mining.break_seconds(voxel, item) > 0.0)


## Returns [server, client transport, session] with a joined player.
func _joined() -> Array:
	var settings := WorldSettings.create("Test", "42", WorldSettings.GameMode.SURVIVAL)
	var server := GameServer.new(settings, null, false)
	var transports := LocalTransport.create_pair()
	server.connect_client(transports[1])
	transports[0].send(Msg.hello("Alex", 2))
	server.process_messages()
	transports[0].poll()
	return [server, transports[0], server.first_session()]


## The voxel cell `offset` tiles from the player's, on the ground surface.
func _ground_cell(
	server: GameServer, session: GameServer.PlayerSession, offset: Vector2i
) -> Vector3i:
	var tile := Coords.world_to_tile(session.position) + offset
	var top := server.world.get_or_create_chunk(Coords.tile_to_chunk(tile)).top_row(
		Coords.tile_to_local(tile)
	)
	return Vector3i(tile.x, top - 1, tile.y)


func test_breaking_within_reach_and_what_stood_on_it() -> void:
	var setup := _joined()
	var server: GameServer = setup[0]
	var client: LocalTransport = setup[1]
	var session: GameServer.PlayerSession = setup[2]
	var cell := _ground_cell(server, session, Vector2i(1, 0))
	var flower := Voxels.of_block(Tiles.Block.FLOWER_BLUE)
	server.world.set_voxel(cell + Vector3i.UP, flower)
	client.send(Msg.block_break(cell))
	server.process_messages()
	assert_eq(server.world.voxel_at(cell), Voxels.AIR, "broken")
	assert_eq(server.world.voxel_at(cell + Vector3i.UP), Voxels.AIR, "the flower falls with it")
	var said := client.poll()
	var changed := said.filter(func(m: Dictionary) -> bool: return m["t"] == Msg.BLOCK_CHANGED)
	assert_eq(changed.size(), 2)
	assert_eq(changed[0]["cell"], cell)
	assert_eq(changed[0]["voxel"], Voxels.AIR)
	var dropped := said.filter(func(m: Dictionary) -> bool: return m["t"] == Msg.ITEM_SPAWN)
	assert_eq(dropped.size(), 2, "the soil and the flower fall where they were")
	var chunk := server.world.chunks[Coords.tile_to_chunk(Vector2i(cell.x, cell.z))]
	assert_true(chunk.modified, "saved with the world from now on")
	# Out of reach: refused, the player is told what is there.
	var far := _ground_cell(server, session, Vector2i(9, 0))
	var there := server.world.voxel_at(far)
	client.send(Msg.block_break(far))
	server.process_messages()
	assert_eq(server.world.voxel_at(far), there, "still there")
	said = client.poll()
	assert_eq(said[0]["voxel"], there, "the guess is undone")


func test_placing_against_the_terrain_and_out_of_the_way() -> void:
	var setup := _joined()
	var server: GameServer = setup[0]
	var client: LocalTransport = setup[1]
	var session: GameServer.PlayerSession = setup[2]
	var dirt := Voxels.of_ground(Tiles.Ground.DIRT)
	session.inventory.add(Items.Id.DIRT, 5)
	session.inventory.items[1] = Items.Id.SEEDS
	session.inventory.counts[1] = 3
	var cell := _ground_cell(server, session, Vector2i(2, 0)) + Vector3i.UP
	server.world.set_voxel(cell, Voxels.AIR)
	client.send(Msg.block_place(cell, 0))
	server.process_messages()
	assert_eq(server.world.voxel_at(cell), dirt, "placed on the ground")
	assert_eq(session.inventory.counts[0], 4, "it left the hand")
	client.poll()
	# In the player's own body: refused.
	var feet := Coords.world_to_tile(session.position)
	var row := floori(session.height + 0.01) + SEA
	var inside := Vector3i(feet.x, row, feet.y)
	var before := server.world.voxel_at(inside)
	client.send(Msg.block_place(inside, 0))
	server.process_messages()
	assert_eq(server.world.voxel_at(inside), before)
	assert_eq(client.poll()[0]["voxel"], before, "the guess is undone")
	# Floating in the air, or not a block (seeds): refused.
	var floating := cell + Vector3i(0, 3, 0)
	client.send(Msg.block_place(floating, 0))
	client.send(Msg.block_place(cell + Vector3i.UP, 1))
	server.process_messages()
	assert_eq(server.world.voxel_at(floating), Voxels.AIR)
	assert_eq(server.world.voxel_at(cell + Vector3i.UP), Voxels.AIR)
	assert_eq(session.inventory.counts[0], 4, "nothing used")
	assert_eq(session.inventory.counts[1], 3)


func test_water_fills_what_is_broken_next_to_it() -> void:
	_cells.clear()
	var water := Voxels.of_ground(Tiles.Ground.WATER)
	_cells[Vector3i(0, SEA - 1, 0)] = water
	assert_eq(Mining.left_after_break(Vector3i(0, SEA - 2, 0), _voxel_at), water, "under it")
	assert_eq(Mining.left_after_break(Vector3i(1, SEA - 1, 0), _voxel_at), water, "beside it")
	assert_eq(Mining.left_after_break(Vector3i(0, SEA, 0), _voxel_at), Voxels.AIR, "not over it")
	assert_eq(Mining.left_after_break(Vector3i(5, SEA - 1, 5), _voxel_at), Voxels.AIR)


func test_a_body_overlaps_the_cells_it_stands_in() -> void:
	var feet := Vector2(8.0, 12.0)
	assert_true(Mining.overlaps_body(Vector3i(0, SEA, 0), feet, 0.0), "at the feet")
	assert_true(Mining.overlaps_body(Vector3i(0, SEA + 1, 0), feet, 0.0), "at the head")
	assert_false(Mining.overlaps_body(Vector3i(0, SEA + 2, 0), feet, 0.0), "above the head")
	assert_false(Mining.overlaps_body(Vector3i(0, SEA - 1, 0), feet, 0.0), "the ground under")
	assert_false(Mining.overlaps_body(Vector3i(1, SEA, 0), feet, 0.0), "the next tile")
	assert_almost(Mining.reach_to(feet, 0.0, Vector3i(0, SEA - 1, 0)), Mining.EYE_HEIGHT, 0.001)
