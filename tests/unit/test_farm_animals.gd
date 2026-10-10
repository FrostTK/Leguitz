extends TestCase
## Farm animals: cows and goats milked, ducks laying and swimming across
## water, a boar's young born a pig, and bees: hives filling with honey by
## the flowers, harvested with a glass bottle or shears, bees going out by
## day and home at night, crops growing faster near a hive; wild bee nests.

const SEA := GameConst.SEA_LEVEL

const NEW_SPECIES: Array[int] = [
	Species.Id.COW,
	Species.Id.GOAT,
	Species.Id.DUCK,
	Species.Id.RABBIT,
	Species.Id.PIG,
	Species.Id.BEE,
]

var _server: GameServer
var _client: LocalTransport
var _session: GameServer.PlayerSession


## A server, a player on flat grass (14 tiles around), noon, no creatures.
func _farm() -> void:
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
	var tile := _tile()
	for dz in range(-14, 15):
		for dx in range(-14, 15):
			var column := Vector3i(tile.x + dx, SEA - 1, tile.y + dz)
			_server.world.set_voxel(column, Voxels.of_ground(Tiles.Ground.GRASS))
			for up in range(1, 9):
				_server.world.set_voxel(column + Vector3i(0, up, 0), Voxels.AIR)
	_clear_creatures()


func _clear_creatures() -> void:
	for creature: Creature in _server.creatures.living.values().duplicate():
		_server.creatures.remove(_server, creature, false)


func _tile() -> Vector2i:
	return Coords.world_to_tile(_session.position)


## The cell `dx`, `dz` tiles from the player, on the ground.
func _cell(dx: int, dz: int) -> Vector3i:
	return Vector3i(_tile().x + dx, SEA, _tile().y + dz)


func _animal(kind: int, dx: int, dz: int) -> Animal:
	var box: Vector2 = Species.BOX[kind]
	var feet := Coords.tile_to_world_center(_tile() + Vector2i(dx, dz)) + Vector2(0.0, box.y * 0.5)
	return _server.creatures.add(kind, feet, 0.0) as Animal


func _hold(item: int, count := 1) -> void:
	_session.inventory.items[0] = item
	_session.inventory.counts[0] = count
	_session.inventory.wear[0] = 0


func _tend(animal: Animal) -> void:
	_client.send(Msg.tend_animal(animal.id, 0))
	_server.process_messages()


func _lying(item: int) -> int:
	var count := 0
	for dropped: DroppedItem in _server.items.values():
		if dropped.item == item:
			count += dropped.count
	return count


func _held(item: int) -> int:
	var count := 0
	for slot in Inventory.SLOTS:
		if _session.inventory.items[slot] == item:
			count += _session.inventory.counts[slot]
	return count


## The bees of the hive at `home`.
func _bees(home: Vector3i) -> Array[Bee]:
	var bees: Array[Bee] = []
	for creature: Creature in _server.creatures.living.values():
		if creature is Bee and (creature as Bee).home == home:
			bees.append(creature)
	return bees


func _block(cell: Vector3i) -> int:
	return Voxels.block_of(_server.world.voxel_at(cell))


func _place(cell: Vector3i, block: int) -> void:
	_server.world.set_voxel(cell, Voxels.of_block(block))


func test_the_new_species_are_described() -> void:
	for kind in NEW_SPECIES:
		var name := String(Species.Id.find_key(kind))
		for table: Dictionary in [
			Species.NAME_KEYS,
			Species.HOME_KEYS,
			Species.BOX,
			Species.TALL,
			Species.HEALTH,
			Species.WALK_SPEED,
			Species.FLEE_SPEED,
			Species.DROPS,
			Species.BIOMES,
			Species.HERD,
		]:
			assert_true(table.has(kind), "%s described" % name)
		var parts := CreatureModels.parts(kind)
		var names := parts.map(func(part: CreatureModels.Part) -> String: return part.name)
		assert_true(names.has("body"), "%s has a body" % name)
		var made := Creatures.make(kind, Vector2.ZERO, 0.0)
		assert_eq(made is Bee, kind == Species.Id.BEE, "%s made" % name)
		if kind != Species.Id.BEE:
			assert_true(Husbandry.FEED.has(kind), "%s eats something" % name)
	assert_true(Species.BIOMES[Species.Id.PIG].is_empty(), "pigs are only born on farms")
	assert_true(Species.BIOMES[Species.Id.BEE].is_empty(), "bees only come out of hives")
	assert_true(Species.FLIERS.has(Species.Id.BEE))


func test_cows_and_goats_give_milk_and_ducks_lay() -> void:
	_farm()
	for kind: int in [Species.Id.COW, Species.Id.GOAT]:
		var animal := _animal(kind, 2, 0)
		_hold(Items.Id.BUCKET)
		_tend(animal)
		assert_eq(_session.inventory.items[0], Items.Id.MILK_BUCKET, "milked")
		_server.creatures.remove(_server, animal, false)
	var duck := _animal(Species.Id.DUCK, 2, 0)
	Husbandry.sense(_server, _server.creatures, duck, 0.1)
	duck.egg_in = 0.5
	Husbandry.sense(_server, _server.creatures, duck, 1.0)
	assert_eq(_lying(Items.Id.EGG), 1, "a duck lays")
	_hold(Items.Id.CORN, 3)
	_tend(duck)
	assert_true(duck.love > 0.0, "ducks eat corn")


func test_a_boar_born_on_the_farm_is_a_pig() -> void:
	_farm()
	var sow := _animal(Species.Id.BOAR, 2, 0)
	var boar := _animal(Species.Id.BOAR, 3, 0)
	_hold(Items.Id.CARROT, 5)
	_tend(sow)
	_tend(boar)
	Husbandry.update(_server, _server.creatures)
	var piglets := _server.creatures.living.values().filter(
		func(creature: Creature) -> bool:
			return creature is Animal and (creature as Animal).is_baby()
	)
	assert_eq(piglets.size(), 1, "a young one")
	assert_eq(piglets[0].species, Species.Id.PIG, "born a pig")
	# Pigs breed pigs.
	assert_eq(Husbandry.BORN_AS.get(Species.Id.PIG, Species.Id.PIG), Species.Id.PIG)


func test_ducks_swim_across_water_where_sheep_go_around() -> void:
	_farm()
	# A pond 3 tiles wide across the way, 2 deep.
	for dz in range(-3, 4):
		for dx in range(2, 5):
			for down in [1, 2]:
				var water := Voxels.of_ground(Tiles.Ground.WATER)
				_server.world.set_voxel(_cell(dx, dz) - Vector3i(0, down, 0), water)
	var voxel_at := _server.world.loaded_voxel_at
	var start := _tile()
	var goal := _tile() + Vector2i(6, 0)
	var swim := Pathfinder.find(start, 0.0, goal, voxel_at, Species.TALL[Species.Id.DUCK], true)
	var walk := Pathfinder.find(start, 0.0, goal, voxel_at, Species.TALL[Species.Id.SHEEP])
	assert_false(swim.is_empty() or walk.is_empty(), "both find a way")
	var wet := func(way: Array[Vector3]) -> bool:
		for point in way:
			var cell := Vector3i(floori(point.x), SEA - 1, floori(point.z))
			if Voxels.is_water(_server.world.voxel_at(cell)):
				return true
		return false
	assert_true(wet.call(swim), "the duck swims across")
	assert_false(wet.call(walk), "the sheep goes around")
	assert_true(swim.size() < walk.size(), "straight across is shorter")
	for point in swim:
		var under := Vector3i(floori(point.x), SEA - 1, floori(point.z))
		if Voxels.is_water(_server.world.voxel_at(under)):
			assert_almost(point.y, -Pathfinder.FLOAT, 0.001, "it floats on the water")


func test_a_hive_fills_with_honey_by_its_flowers() -> void:
	_farm()
	var hive := _cell(3, 0)
	_place(hive, Tiles.Block.BEEHIVE)
	Growth.update(_server, 1.0)
	assert_eq(_block(hive), Tiles.Block.BEEHIVE, "no flowers: no honey")
	assert_eq(_bees(hive).size(), 1, "its bees come out by day, one at a time")
	_place(_cell(5, 1), Tiles.Block.FLOWER_RED)
	_place(_cell(1, -2), Tiles.Block.FLOWER_YELLOW)
	assert_eq(Apiary.flowers_near(_server.world, hive).size(), 2)
	for level in range(1, Apiary.FULL + 1):
		Growth.update(_server, 1.0)
		assert_eq(Apiary.level_of(_block(hive)), level, "a level of honey")
	Growth.update(_server, 1.0)
	assert_eq(_block(hive), Tiles.Block.BEEHIVE_3, "full, it stays full")
	assert_eq(_bees(hive).size(), Apiary.BEES, "no more bees than its own")
	var bee := _bees(hive)[0]
	assert_eq(bee.home, hive)
	assert_eq(bee.flowers.size(), 2, "told of the flowers")
	# Out of the light of day: none come out, and they go in.
	_server.clock.set_frozen(WorldClock.FROZEN_MIDNIGHT)
	bee.body.place(Coords.tile_to_world_center(Vector2i(hive.x, hive.z)), bee.doorstep().y - 0.2)
	_server.creatures.update(_server, 0.05)
	_server.creatures.update(_server, 0.05)
	assert_false(_server.creatures.living.has(bee.id), "home at night, it goes in")
	# Its hive gone, a bee goes.
	_server.clock.set_frozen(WorldClock.FROZEN_NOON)
	_place(hive, Tiles.Block.AIR)
	_server.creatures.update(_server, 0.05)
	_server.creatures.update(_server, 0.05)
	assert_true(_bees(hive).is_empty(), "no hive, no bees")


func test_a_full_hive_gives_honey_to_a_bottle_and_combs_to_shears() -> void:
	_farm()
	var hive := _cell(2, 0)
	_place(hive, Tiles.Block.BEEHIVE_2)
	_hold(Items.Id.GLASS_BOTTLE, 3)
	_client.send(Msg.harvest_hive(hive, 0))
	_server.process_messages()
	assert_eq(_block(hive), Tiles.Block.BEEHIVE_2, "not full: nothing")
	assert_eq(_held(Items.Id.HONEY_BOTTLE), 0)
	_place(hive, Tiles.Block.BEEHIVE_3)
	_client.send(Msg.harvest_hive(hive, 0))
	_server.process_messages()
	assert_eq(_block(hive), Tiles.Block.BEEHIVE, "emptied")
	assert_eq(_held(Items.Id.HONEY_BOTTLE), 1, "a jar of honey")
	assert_eq(_held(Items.Id.GLASS_BOTTLE), 2, "a bottle used")
	_place(hive, Tiles.Block.BEEHIVE_3)
	_hold(Items.Id.SHEARS)
	_client.send(Msg.harvest_hive(hive, 0))
	_server.process_messages()
	assert_eq(_held(Items.Id.HONEYCOMB), Apiary.COMBS, "honeycomb")
	assert_eq(_session.inventory.wear[0], 1, "the shears wear")
	# Honey is eaten, the bottle stays.
	_hold(Items.Id.HONEY_BOTTLE)
	_session.food = 5
	Survival.eat(_server, _session, 0)
	assert_eq(_session.food, 5 + Food.SATIETY[Items.Id.HONEY_BOTTLE])
	assert_eq(_session.inventory.items[0], Items.Id.GLASS_BOTTLE)
	# A hive broken gives itself back; a wild nest its combs.
	var rng := RandomNumberGenerator.new()
	var hive_drops := Items.drops(Voxels.of_block(Tiles.Block.BEEHIVE_2), Vector2i.ZERO, rng)
	assert_eq(hive_drops[0], Vector2i(Items.Id.BEEHIVE, 1))
	var nest_drops := Items.drops(Voxels.of_block(Tiles.Block.BEE_NEST_1), Vector2i.ZERO, rng)
	assert_eq(nest_drops[0].x, Items.Id.HONEYCOMB)
	var plank := Items.Id.OAK_PLANKS
	var comb := Items.Id.HONEYCOMB
	var grid := PackedInt32Array([plank, plank, plank, comb, comb, comb, plank, plank, plank])
	assert_eq(Recipes.result_of(grid, 3), Vector2i(Items.Id.BEEHIVE, 1), "planks and combs")
	var glass := Items.Id.GLASS
	var none := Items.Id.NONE
	grid = PackedInt32Array([glass, none, glass, none, glass, none, none, none, none])
	assert_eq(Recipes.result_of(grid, 3), Vector2i(Items.Id.GLASS_BOTTLE, 3), "bottles")


func test_crops_near_a_hive_grow_faster() -> void:
	var hives: Array[Vector3i] = [Vector3i(0, SEA, 0)]
	assert_true(Apiary.pollinated(hives, Vector3i(Apiary.POLLINATION_RANGE, SEA, -3)))
	assert_false(Apiary.pollinated(hives, Vector3i(Apiary.POLLINATION_RANGE + 1, SEA, 0)))
	assert_true(Apiary.POLLINATED < 1.0)


func test_wild_bee_nests_grow_in_flowery_places() -> void:
	var generator := WorldGenerator.new(42)
	var nests := 0
	var noted := 0
	# Plains and meadows, a flower forest (seed 42).
	for center: Vector2i in [Vector2i(-12, 21), Vector2i(-119, -12), Vector2i(-334, -498)]:
		var base := Coords.tile_to_chunk(center)
		for dz in range(-3, 4):
			for dx in range(-3, 4):
				var chunk := generator.generate_chunk(base + Vector2i(dx, dz))
				var origin := (base + Vector2i(dx, dz)) * GameConst.CHUNK_SIZE
				for cell: Vector3i in chunk.growing:
					var local := Vector2i(cell.x, cell.z) - origin
					if Apiary.is_hive(Voxels.block_of(chunk.object_on_surface(local))):
						noted += 1
				for lz in GameConst.CHUNK_SIZE:
					for lx in GameConst.CHUNK_SIZE:
						var block := Voxels.block_of(chunk.object_on_surface(Vector2i(lx, lz)))
						if Apiary.is_hive(block):
							nests += 1
							assert_true(block in Apiary.HIVES[1], "a wild nest, not a beehive")
	assert_true(nests > 0, "some bee nests")
	assert_eq(noted, nests, "each noted to fill and send its bees")
