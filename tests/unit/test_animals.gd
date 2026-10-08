extends TestCase
## Animals: their species, the ways they find over the voxels, how they
## live (wander, stay on the ground, run away when hurt, die), the herds
## placed in chunks, hitting them through the server, what they give,
## their saves, and their meat cooked.

const SEA := GameConst.SEA_LEVEL
const TS := GameConst.TILE_SIZE
const FOLDER := "user://test_worlds/animals"

## A test world: flat grass at level 0, with `walls` (tile -> its top
## level, cubes from the ground up) and `water` tiles.
var walls: Dictionary[Vector2i, int] = {}
var water: Dictionary[Vector2i, bool] = {}


func _voxel_at(cell: Vector3i) -> int:
	var tile := Vector2i(cell.x, cell.z)
	var level := cell.y - SEA
	if water.has(tile) and level == -1:
		return Voxels.of_ground(Tiles.Ground.WATER)
	if level < 0:
		return Voxels.of_ground(Tiles.Ground.GRASS)
	if walls.has(tile) and level < walls[tile]:
		return Voxels.of_block(Tiles.Block.STONE)
	return Voxels.AIR


func _flat() -> void:
	walls.clear()
	water.clear()


func test_every_species_is_described() -> void:
	for kind: int in Species.Id.values():
		for table: Dictionary in [
			Species.NAME_KEYS,
			Species.HOME_KEYS,
			Species.BOX,
			Species.TALL,
			Species.HEALTH,
			Species.WALK_SPEED,
			Species.FLEE_SPEED,
			Species.DROPS,
		]:
			assert_true(table.has(kind), "%s described" % Species.Id.find_key(kind))
		var own := (
			[Species.CHASE_SPEED, Species.DAMAGE, Species.CAUSE, Monsters.MAX_OF]
			if Species.is_monster(kind)
			else [Species.BIOMES, Species.HERD]
		)
		for table: Dictionary in own:
			assert_true(table.has(kind), "%s described" % Species.Id.find_key(kind))
		for drop: Array in Species.DROPS[kind]:
			assert_true(Items.is_valid(drop[0]))
			assert_true(drop[1] <= drop[2])
		assert_true(Species.FLEE_SPEED[kind] > Species.WALK_SPEED[kind], "they run away fast")
		assert_true(Species.BOX[kind].x <= GameConst.TILE_SIZE, "fits between trees")
	assert_true(Species.living_in(Biomes.Id.PLAINS).has(Species.Id.SHEEP))
	var at_sea := Species.living_in(Biomes.Id.OCEAN)
	assert_true(at_sea.size() == 1 and at_sea.has(Species.Id.FISH), "only fish at sea")


func test_ways_climb_one_level_go_round_walls_and_avoid_water() -> void:
	_flat()
	var on_flat := Pathfinder.find(Vector2i(0, 0), 0.0, Vector2i(5, 3), _voxel_at, 1.1)
	assert_eq(on_flat[-1], Vector3(5.5, 0.0, 3.5), "to the goal")
	assert_true(on_flat.size() <= 6, "diagonals shorten it: %d" % on_flat.size())
	# A step of one level is climbed, one of two is not.
	walls[Vector2i(2, 0)] = 1
	var step := Pathfinder.find(Vector2i(0, 0), 0.0, Vector2i(2, 0), _voxel_at, 1.1)
	assert_eq(step[-1].y, 1.0, "up one level")
	walls[Vector2i(2, 0)] = 2
	for z in range(-6, 7):
		walls[Vector2i(4, z)] = 2
	assert_almost(Pathfinder.ground_at(Vector2i(2, 0), 0.0, _voxel_at, 1.1), NAN, 0.0)
	var round := Pathfinder.find(Vector2i(0, 0), 0.0, Vector2i(6, 0), _voxel_at, 1.1)
	assert_eq(round[-1], Vector3(6.5, 0.0, 0.5), "round the wall")
	for point in round:
		assert_eq(point.y, 0.0, "never on top of it")
	# Water is never walked into.
	_flat()
	for z in range(-10, 11):
		water[Vector2i(3, z)] = true
	var wet := Pathfinder.find(Vector2i(0, 0), 0.0, Vector2i(6, 0), _voxel_at, 1.1)
	for point in wet:
		assert_false(water.has(Vector2i(floori(point.x), floori(point.z))), "round the river")
	assert_true(is_nan(Pathfinder.ground_at(Vector2i(3, 0), 0.0, _voxel_at, 1.1)))
	# Down a cliff of three levels, not of four.
	_flat()
	walls[Vector2i(0, 0)] = 3
	assert_eq(Pathfinder.ground_at(Vector2i(1, 0), 3.0, _voxel_at, 1.1), 0.0)
	walls[Vector2i(0, 0)] = 4
	assert_true(is_nan(Pathfinder.ground_at(Vector2i(1, 0), 4.0, _voxel_at, 1.1)))


func test_an_animal_wanders_on_the_ground_and_runs_away_when_hurt() -> void:
	_flat()
	walls[Vector2i(3, 2)] = 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var sheep := Animal.create(Species.Id.SHEEP, Vector2(8.0, 14.0), 0.0)
	var start := sheep.center()
	var farthest := 0.0
	for i in 20 * 40:
		sheep.think(GameConst.TICK_DELTA, _voxel_at, rng)
		sheep.move(GameConst.TICK_DELTA, _voxel_at)
		farthest = maxf(farthest, sheep.center().distance_to(start))
		assert_true(sheep.body.height > -0.01, "never under the ground")
	assert_true(farthest > 2.0 * TS, "it wandered: %.1f tiles" % (farthest / TS))
	# A blow: hurt, thrown back, then off at a run.
	var health := sheep.health
	var from := sheep.center() + Vector2(-20.0, 0.0)
	assert_true(sheep.hurt_by(from, 3))
	assert_eq(sheep.health, health - 3)
	assert_eq(sheep.state, Creature.State.FLEE)
	assert_false(sheep.hurt_by(from, 3), "not twice at once")
	var before := sheep.center()
	for i in 20 * 2:
		sheep.think(GameConst.TICK_DELTA, _voxel_at, rng)
		sheep.move(GameConst.TICK_DELTA, _voxel_at)
	assert_true(sheep.center().x - before.x > 2.0 * TS, "away from the blow")
	assert_true(sheep.speed > Species.WALK_SPEED[Species.Id.SHEEP], "at a run")
	var again := Creatures.from_dict(sheep.to_dict())
	assert_eq(again.health, sheep.health, "saved")
	assert_eq(again.body.box, Species.BOX[Species.Id.SHEEP])


## Returns [server, client transport, session] with a joined player.
func _joined() -> Array:
	var settings := WorldSettings.create("Test", "42", WorldSettings.GameMode.SURVIVAL)
	var server := GameServer.new(settings, null, false)
	var transports := LocalTransport.create_pair()
	server.connect_client(transports[1])
	transports[0].send(Msg.hello("Alex", 2))
	server.process_messages()
	return [server, transports[0], server.first_session()]


func _said(client: LocalTransport, kind: String) -> Array:
	return client.poll().filter(func(m: Dictionary) -> bool: return m["t"] == kind)


func test_chunks_get_their_herds_once_and_the_same_for_a_seed() -> void:
	var setup := _joined()
	var server: GameServer = setup[0]
	for i in 2:
		server.tick()
	var creatures := server.creatures
	assert_eq(creatures.populated.size(), server.world.chunks.size(), "every loaded chunk")
	for animal: Animal in creatures.living.values():
		var chunk := server.world.chunks[Coords.tile_to_chunk(animal.tile())]
		var biome := chunk.get_biome(Vector2i(8, 8))
		assert_true(animal.species in Species.living_in(biome), "where it lives")
	# The same herds for the same seed.
	var twins: Array[Creatures] = []
	for i in 2:
		twins.append(Creatures.new(server.world, server.settings.world_seed))
		for coord: Vector2i in server.world.chunks:
			twins[i].populate(server.world.chunks[coord])
	var herds: Array[Array] = [[], []]
	for i in 2:
		for animal: Animal in twins[i].living.values():
			herds[i].append([animal.species, animal.body.feet])
	assert_eq(herds[0], herds[1])
	assert_eq(herds[0].size(), creatures.living.size())
	var twin := twins[0]
	# Never where players built.
	var built := ChunkData.new(Vector2i(500, 500))
	built.modified = true
	var count := twin.living.size()
	twin.populate(built)
	assert_eq(twin.living.size(), count)


func test_players_see_hit_and_hunt_animals() -> void:
	var setup := _joined()
	var server: GameServer = setup[0]
	var client: LocalTransport = setup[1]
	var session: GameServer.PlayerSession = setup[2]
	server.creatures.living.clear()
	server.creatures.populated.clear()
	for coord: Vector2i in server.world.chunks:
		server.creatures.populated[coord] = true
	server.creatures.spawn_near(Species.Id.CHICKEN, session.position, session.height, 3)
	assert_eq(server.creatures.living.size(), 3)
	server.tick()
	server.tick()
	var shown := _said(client, Msg.ENTITY_SPAWN)
	assert_eq(shown.size(), 3, "the player sees them")
	assert_eq(shown[0]["kind"], Species.Id.CHICKEN)
	var prey: Animal = server.creatures.living.values()[0]
	# Out of reach: nothing.
	session.position = prey.center() + Vector2(10.0 * TS, 0.0)
	client.send(Msg.attack(prey.id))
	server.process_messages()
	assert_eq(prey.health, Species.HEALTH[Species.Id.CHICKEN], "out of reach")
	# Close by, with a pickaxe: hurt, its herd runs too, the tool wears.
	session.position = prey.center() + Vector2(-TS, 0.0)
	session.height = prey.body.height
	session.inventory.items[0] = Items.Id.WOODEN_PICKAXE
	session.inventory.counts[0] = 1
	client.send(Msg.attack(prey.id, 0))
	server.process_messages()
	var damage := Combat.damage_of(Items.Id.WOODEN_PICKAXE)
	assert_eq(prey.health, Species.HEALTH[Species.Id.CHICKEN] - damage)
	assert_eq(session.inventory.wear[0], 1, "the pickaxe wore")
	assert_eq(_said(client, Msg.ENTITY_HURT).size(), 1)
	var panic := Creatures.HERD_PANIC * TS
	for animal: Animal in server.creatures.living.values():
		if animal.center().distance_to(prey.center()) <= panic:
			assert_eq(animal.state, Creature.State.FLEE, "the herd runs away")
	# Too soon after: nothing.
	client.send(Msg.attack(prey.id, 0))
	server.process_messages()
	assert_eq(prey.health, Species.HEALTH[Species.Id.CHICKEN] - damage, "not so fast")
	for i in 10:
		server.tick()
	session.position = prey.center() + Vector2(-TS, 0.0)
	session.height = prey.body.height
	client.poll()
	client.send(Msg.attack(prey.id, 0))
	server.process_messages()
	assert_false(server.creatures.living.has(prey.id), "it fell")
	var gone := _said(client, Msg.ENTITY_REMOVE)
	assert_eq(gone.size(), 1)
	assert_true(gone[0]["died"])
	var meat := server.items.values().filter(
		func(d: DroppedItem) -> bool: return d.item == Items.Id.RAW_CHICKEN
	)
	assert_eq(meat.size(), 1, "it left its meat")


func test_blocks_are_not_placed_on_animals_and_they_are_saved() -> void:
	var storage := WorldStorage.new(FOLDER)
	storage.erase()
	var setup := _joined()
	var server: GameServer = setup[0]
	var client: LocalTransport = setup[1]
	var session: GameServer.PlayerSession = setup[2]
	server.use_storage(storage, {})
	server.creatures.spawn_near(Species.Id.DEER, session.position, session.height, 1)
	var deer: Animal = server.creatures.living.values()[-1]
	var tile := deer.tile()
	var cell := Vector3i(tile.x, floori(deer.body.height + 0.01) + SEA, tile.y)
	session.inventory.add(Items.Id.WOOL, 4)
	session.position = deer.center() + Vector2(-2.0 * TS, 0.0)
	session.height = deer.body.height
	client.send(Msg.block_place(cell, 0))
	server.process_messages()
	assert_ne(server.world.voxel_at(cell), Voxels.of_block(Tiles.Block.WOOL), "not on the deer")
	assert_true(server.save())
	var again := GameServer.new(server.settings, null, false)
	again.use_storage(WorldStorage.new(FOLDER), storage.read_world())
	assert_eq(again.creatures.living.size(), server.creatures.living.size(), "saved")
	assert_eq(again.creatures.populated.size(), server.creatures.populated.size())
	storage.erase()


func test_meat_roasts_and_wool_builds() -> void:
	var raw := [Items.Id.RAW_MUTTON, Items.Id.RAW_PORK, Items.Id.RAW_CHICKEN, Items.Id.RAW_VENISON]
	for item: int in raw:
		var cooked := Smelting.result_of(Tiles.Block.FOOD_FURNACE, item)
		assert_true(Items.FOOD[cooked] > Items.FOOD[item], "%s feeds more roasted" % item)
		assert_eq(Smelting.result_of(Tiles.Block.FACTORY_FURNACE, item), Items.Id.CHARRED_FOOD)
	assert_true(Vitals.POISONS.has(Items.Id.RAW_CHICKEN), "raw chicken makes sick")
	assert_eq(Items.placed_voxel(Items.Id.WOOL), Voxels.of_block(Tiles.Block.WOOL))
	assert_true(Voxels.is_cube(Voxels.of_block(Tiles.Block.WOOL)))
	assert_true(Mining.BLOCK_SECONDS.has(Tiles.Block.WOOL))
	assert_eq(Combat.damage_of(Items.Id.NONE), Combat.HAND_DAMAGE)
	assert_true(Combat.damage_of(Items.Id.DIAMOND_AXE) > Combat.damage_of(Items.Id.WOODEN_AXE))


func test_a_way_point_right_over_it_never_loses_it() -> void:
	_flat()
	var boar := Creatures.make(Species.Id.BOAR, Vector2(8.0, 14.0) * TS, 0.0)
	var middle := boar.center() / TS
	# The next point straight above its middle (a ledge it must climb).
	boar._way = [Vector3(middle.x, 1.0, middle.y), Vector3(middle.x + 3.0, 0.0, middle.y)]
	for i in 20:
		boar.move(0.05, _voxel_at)
	assert_true(boar.body.feet.is_finite(), "still somewhere: %s" % boar.body.feet)
	assert_true(boar.heading.is_finite())
	# Saved lost by an older version: left out when the world loads.
	var lost := {"species": Species.Id.BOAR, "feet": Vector2(NAN, NAN), "height": 0.5}
	assert_eq(Creatures.from_dict(lost), null)
	var fine := boar.to_dict()
	assert_true(Creatures.from_dict(fine) != null)
