extends TestCase
## Wild animals and pests: wolves hunting in packs (prey, a player in the
## dark, whoever struck one of them), a bear warning then charging, fish
## kept in the water, turtles laying eggs that hatch, beavers building a
## dam, a mole ravaging a field from below, crows pecking seedlings unless
## a scarecrow stands near, lantern bumblebees letting crops grow at night.

const SEA := GameConst.SEA_LEVEL

const WILD_SPECIES: Array[int] = [
	Species.Id.WOLF,
	Species.Id.BEAR,
	Species.Id.FROG,
	Species.Id.TURTLE,
	Species.Id.BEAVER,
	Species.Id.FISH,
	Species.Id.MOLE,
	Species.Id.CROW,
	Species.Id.LANTERN_BUMBLEBEE,
]

var _server: GameServer
var _client: LocalTransport
var _session: GameServer.PlayerSession
var _rng := RandomNumberGenerator.new()


## A server, a player on flat grass (14 tiles around), noon, no creatures.
func _wild() -> void:
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
	for creature: Creature in _server.creatures.living.values().duplicate():
		_server.creatures.remove(_server, creature, false)
	_rng.seed = 7


func _tile() -> Vector2i:
	return Coords.world_to_tile(_session.position)


## The cell `dx`, `dz` tiles from the player, on the ground.
func _cell(dx: int, dz: int) -> Vector3i:
	return Vector3i(_tile().x + dx, SEA, _tile().y + dz)


## A creature standing on the tile `dx`, `dz` from the player.
func _add(kind: int, dx: int, dz: int, height := 0.0) -> Creature:
	var box: Vector2 = Species.BOX[kind]
	var feet := Coords.tile_to_world_center(_tile() + Vector2i(dx, dz)) + Vector2(0.0, box.y * 0.5)
	return _server.creatures.add(kind, feet, height)


func _block(cell: Vector3i) -> int:
	return Voxels.block_of(_server.world.voxel_at(cell))


func _place(cell: Vector3i, block: int) -> void:
	_server.world.set_voxel(cell, Voxels.of_block(block))


func _ground(cell: Vector3i, ground: int) -> void:
	_server.world.set_voxel(cell, Voxels.of_ground(ground))


## A field of `block` crops on farmland, 3 x 3 from the tile `dx`, `dz`.
func _field(dx: int, dz: int, block: int) -> Array[Vector3i]:
	var crops: Array[Vector3i] = []
	for z in 3:
		for x in 3:
			var cell := _cell(dx + x, dz + z)
			_ground(cell + Vector3i.DOWN, Tiles.Ground.FARMLAND_WET)
			_place(cell, block)
			crops.append(cell)
	return crops


func _sense(creature: Creature, delta: float) -> void:
	Wildlife.sense(_server, _server.creatures, creature as Animal, delta)


func _alive(creature: Creature) -> bool:
	return _server.creatures.living.has(creature.id)


func _lying() -> int:
	var count := 0
	for dropped: DroppedItem in _server.items.values():
		count += dropped.count
	return count


func test_the_wild_species_are_described() -> void:
	for kind in WILD_SPECIES:
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
		assert_ne(tr(Species.NAME_KEYS[kind]), Species.NAME_KEYS[kind], "%s named" % name)
		assert_ne(tr(Species.HOME_KEYS[kind]), Species.HOME_KEYS[kind], "%s at home" % name)
		var parts := CreatureModels.parts(kind)
		var names := parts.map(func(part: CreatureModels.Part) -> String: return part.name)
		assert_true(names.has("body"), "%s has a body" % name)
		assert_false(Species.is_monster(kind), "%s is no monster" % name)
	for kind: int in Species.PREDATORS:
		assert_true(Creatures.make(kind, Vector2.ZERO, 0.0) is Predator)
		for table: Dictionary in [Species.CHASE_SPEED, Species.DAMAGE, Species.CAUSE]:
			assert_true(table.has(kind), "a predator's blows")
		assert_ne(tr(Vitals.CAUSE_KEYS[Species.CAUSE[kind]]), "", "how it hurts")
		assert_true(Vitals.ARMORED.has(Species.CAUSE[kind]), "armor helps")
	assert_true(Creatures.make(Species.Id.FISH, Vector2.ZERO, 0.0) is Fish)
	assert_true(Creatures.make(Species.Id.MOLE, Vector2.ZERO, 0.0) is Mole)
	assert_true(Creatures.make(Species.Id.CROW, Vector2.ZERO, 0.0) is Crow)
	assert_true(Creatures.make(Species.Id.LANTERN_BUMBLEBEE, Vector2.ZERO, 0.0) is Bee)
	var frog := Creatures.make(Species.Id.FROG, Vector2.ZERO, 0.0)
	assert_true(frog is Animal and not frog is Predator, "a frog is a plain animal")
	for kind: int in Species.PESTS:
		assert_true(Species.BIOMES[kind].is_empty(), "pests come for fields, not biomes")
	assert_true(Species.living_in(Biomes.Id.TAIGA).has(Species.Id.BEAR))
	assert_true(Species.living_in(Biomes.Id.BEACH).has(Species.Id.TURTLE))
	assert_true(Species.living_in(Biomes.Id.RIVER).has(Species.Id.FISH))
	for block: int in [
		Tiles.Block.SCARECROW,
		Tiles.Block.MOLEHILL,
		Tiles.Block.BEAVER_DAM,
		Tiles.Block.TURTLE_EGGS,
		Tiles.Block.TURTLE_EGGS_2,
	]:
		var grid := WildModels.build(block)
		assert_true(
			grid != null and not grid.is_empty(), "%s modeled" % Tiles.Block.find_key(block)
		)
	for item: int in [
		Items.Id.RAW_FISH, Items.Id.COOKED_FISH, Items.Id.SCARECROW, Items.Id.TURTLE_EGG
	]:
		assert_true(ItemModels.build(item) != null, "%s modeled" % Items.Id.find_key(item))
		assert_ne(tr(Items.name_key(item)), Items.name_key(item), "named")


func test_a_wolf_pack_hunts_its_prey_and_is_then_fed() -> void:
	_wild()
	var wolf := _add(Species.Id.WOLF, 3, 0) as Predator
	var other := _add(Species.Id.WOLF, 3, 3) as Predator
	var sheep := _add(Species.Id.SHEEP, 8, 0) as Animal
	_sense(wolf, 0.1)
	assert_eq(wolf.target_id, sheep.id, "it goes for the nearest prey")
	_sense(other, 0.1)
	assert_eq(other.target_id, sheep.id, "its pack with it")
	var voxel_at := _server.world.loaded_voxel_at
	for i in 20:
		if not _alive(sheep):
			break
		var beside := sheep.body.feet + Vector2(-10.0, 0.0)
		wolf.body.place(beside, sheep.body.height)
		sheep.think(1.5, voxel_at, _rng)
		_sense(wolf, 1.5)
		wolf.think(1.5, voxel_at, _rng)
		if wolf.strike:
			Wildlife.land_blow(_server, _server.creatures, wolf)
	assert_false(_alive(sheep), "killed")
	assert_eq(_lying(), 0, "eaten: nothing left")
	assert_true(wolf.hunger > 0.0 and other.hunger > 0.0, "the pack is fed")
	assert_false(wolf.has_target() or other.has_target())
	var rabbit := _add(Species.Id.RABBIT, 6, 0)
	_sense(wolf, 0.1)
	assert_ne(wolf.target_id, rabbit.id, "fed, it lets prey be")


func test_wolves_go_for_a_player_in_the_dark_not_in_the_light() -> void:
	_wild()
	var wolf := _add(Species.Id.WOLF, 4, 0) as Predator
	_sense(wolf, 0.1)
	assert_false(wolf.has_target(), "by day it leaves players alone")
	_server.clock.set_frozen(WorldClock.FROZEN_MIDNIGHT)
	_sense(wolf, 0.1)
	assert_eq(wolf.target_player, _session.id, "at night, a player in the dark")
	# Its blow lands on the player.
	var feet := _session.position + Vector2(-12.0, 0.0)
	wolf.body.place(feet, 0.0)
	_sense(wolf, 0.1)
	wolf.think(0.1, _server.world.loaded_voxel_at, _rng)
	assert_true(wolf.strike, "close: it strikes")
	Wildlife.land_blow(_server, _server.creatures, wolf)
	assert_eq(_session.health, Vitals.MAX_HEALTH - Species.DAMAGE[Species.Id.WOLF], "bitten")
	# A torch beside the player keeps them off.
	_place(_cell(1, 0), Tiles.Block.TORCH)
	_sense(wolf, 0.1)
	assert_eq(wolf.target_player, -1, "not in the light")
	# Never a creative player.
	_place(_cell(1, 0), Tiles.Block.AIR)
	_server.settings.game_mode = WorldSettings.GameMode.CREATIVE
	_sense(wolf, 0.1)
	assert_eq(wolf.target_player, -1, "creative players are left alone")


func test_a_struck_wolf_turns_its_pack_on_the_player() -> void:
	_wild()
	var wolf := _add(Species.Id.WOLF, 3, 0) as Predator
	var other := _add(Species.Id.WOLF, 4, 2) as Predator
	var far := _add(Species.Id.WOLF, -13, -13) as Predator
	far.hunger = 100.0
	assert_true(wolf.hurt_by(_session.position, 1))
	assert_ne(wolf.state, Creature.State.FLEE, "it does not run away")
	_sense(wolf, 0.1)
	_sense(other, 0.1)
	_sense(far, 0.1)
	assert_eq(wolf.target_player, _session.id, "it turns on who struck it")
	assert_eq(other.target_player, _session.id, "its pack too")
	assert_eq(far.target_player, -1, "not wolves of another pack")
	# Wild: it will not be tamed.
	_session.inventory.items[0] = Items.Id.RAW_BEEF
	_session.inventory.counts[0] = 1
	_client.poll()
	_client.send(Msg.tend_animal(wolf.id, 0))
	_server.process_messages()
	var notices := _client.poll().filter(
		func(m: Dictionary) -> bool: return m["t"] == Msg.ANIMAL_NOTICE
	)
	assert_eq(notices.size(), 1)
	assert_eq(notices[0]["key"], "HUD_ANIMAL_WILD", "told it is wild")
	assert_ne(tr("HUD_ANIMAL_WILD"), "HUD_ANIMAL_WILD")


func test_a_bear_warns_then_charges() -> void:
	_wild()
	var bear := _add(Species.Id.BEAR, 3, 0) as Predator
	_sense(bear, 0.5)
	assert_eq(bear.state, Creature.State.ALERT, "it rears up")
	assert_false(bear.has_target(), "a warning first")
	_sense(bear, Wildlife.WARN_SECONDS)
	assert_eq(bear.target_player, _session.id, "the player stayed: it charges")
	var calm := _add(Species.Id.BEAR, 12, 0) as Predator
	_sense(calm, 0.5)
	assert_ne(calm.state, Creature.State.ALERT, "far enough: it does not mind")
	# At night it sleeps.
	_server.clock.set_frozen(WorldClock.FROZEN_MIDNIGHT)
	calm.night = true
	calm.think(0.5, _server.world.loaded_voxel_at, _rng)
	assert_ne(calm.state, Creature.State.CHASE)


func test_fish_stay_in_the_water() -> void:
	_wild()
	# A pond 7 x 7, 3 deep.
	for dz in range(-3, 4):
		for dx in range(4, 11):
			for down in range(1, 4):
				_ground(_cell(dx, dz) - Vector3i(0, down, 0), Tiles.Ground.WATER)
	var fish := _add(Species.Id.FISH, 7, 0, -2.0) as Fish
	var voxel_at := _server.world.loaded_voxel_at
	var moved := false
	var start := fish.middle()
	for i in 300:
		if i == 150:
			fish.hurt_by(fish.center() + Vector2(4.0, 0.0), 1)
		fish.think(0.1, voxel_at, _rng)
		fish.move(0.1, voxel_at)
		var at := fish.middle()
		var cell := Vector3i(floori(at.x), floori(at.y) + SEA, floori(at.z))
		assert_true(Voxels.is_water(voxel_at.call(cell)), "always in the water")
		moved = moved or at.distance_to(start) > 1.0
	assert_true(moved, "it swims about")


func test_turtles_lay_eggs_on_sand_and_they_hatch() -> void:
	_wild()
	for dz in range(-1, 2):
		for dx in range(1, 8):
			_ground(_cell(dx, dz) + Vector3i.DOWN, Tiles.Ground.SAND)
	var turtle := _add(Species.Id.TURTLE, 2, 0) as Animal
	_sense(turtle, 0.1)
	assert_true(turtle.chore_in > 0.0, "it will lay in a while")
	turtle.chore_in = 0.01
	_sense(turtle, 0.1)
	var nest := _cell(2, 0)
	assert_eq(_block(nest), Tiles.Block.TURTLE_EGGS, "eggs in the sand")
	var other := _add(Species.Id.TURTLE, 4, 0) as Animal
	other.chore_in = 0.01
	_sense(other, 0.1)
	assert_eq(_block(_cell(4, 0)), Tiles.Block.AIR, "not next to other eggs")
	var on_grass := _add(Species.Id.TURTLE, -4, 0) as Animal
	on_grass.chore_in = 0.01
	_sense(on_grass, 0.1)
	assert_eq(_block(_cell(-4, 0)), Tiles.Block.AIR, "only on sand")
	var turtles := func() -> int:
		return (
			_server
			. creatures
			. living
			. values()
			. filter(func(c: Creature) -> bool: return c.species == Species.Id.TURTLE)
			. size()
		)
	var before: int = turtles.call()
	Growth.update(_server, 1.0)
	assert_eq(_block(nest), Tiles.Block.TURTLE_EGGS_1, "they crack")
	Growth.update(_server, 1.0)
	assert_eq(_block(nest), Tiles.Block.TURTLE_EGGS_2)
	Growth.update(_server, 1.0)
	assert_eq(_block(nest), Tiles.Block.AIR, "hatched")
	assert_true(turtles.call() > before, "young turtles")
	# Taken, an egg is laid again on sand.
	var egg := Items.placed_voxel(Items.Id.TURTLE_EGG)
	var voxel_at := _server.world.voxel_at
	assert_false(Mining.placement(_cell(6, 0), egg, Vector2i(0, 1), voxel_at).is_empty(), "sand")
	assert_true(Mining.placement(_cell(-6, 0), egg, Vector2i(0, 1), voxel_at).is_empty(), "grass")
	var drops := Items.drops(Voxels.of_block(Tiles.Block.TURTLE_EGGS_1), Vector2i.ZERO, _rng)
	assert_eq(drops[0].x, Items.Id.TURTLE_EGG)


func test_a_beaver_builds_a_dam_by_the_bank() -> void:
	_wild()
	# A still pond one deep, its banks grass.
	for dz in range(-2, 3):
		for dx in range(3, 8):
			_ground(_cell(dx, dz) + Vector3i.DOWN, Tiles.Ground.WATER)
	var beaver := _add(Species.Id.BEAVER, 2, 0) as Animal
	var spot := Wildlife.dam_spot(_server.world, Vector2i(_cell(2, 0).x, _cell(2, 0).z), 0.0)
	assert_ne(spot, Vector3i.MAX, "somewhere to build")
	assert_true(Voxels.is_water(_server.world.voxel_at(spot)), "in the water")
	_sense(beaver, 0.1)
	beaver.chore_in = 0.01
	_sense(beaver, 0.1)
	assert_eq(_block(spot), Tiles.Block.BEAVER_DAM, "a piece of dam")
	var built := 1
	for i in 10:
		var next := Wildlife.dam_spot(_server.world, Vector2i(_cell(2, 0).x, _cell(2, 0).z), 0.0)
		if next == Vector3i.MAX:
			break
		_place(next, Tiles.Block.BEAVER_DAM)
		built += 1
	assert_eq(built, Wildlife.MOST_DAM, "a dam has its size")
	var drops := Items.drops(Voxels.of_block(Tiles.Block.BEAVER_DAM), Vector2i.ZERO, _rng)
	assert_eq(drops[0].x, Items.Id.STICK, "sticks")


func test_a_mole_ravages_a_field_from_below() -> void:
	_wild()
	var crops := _field(4, 0, Tiles.Block.WHEAT_2)
	assert_eq(Pests.crops_near(_server, _session).size(), 9, "a field")
	var box: Vector2 = Species.BOX[Species.Id.MOLE]
	var feet := Coords.tile_to_world_center(Vector2i(crops[4].x, crops[4].z))
	var mole := (
		_server.creatures.add(Species.Id.MOLE, feet + Vector2(0.0, box.y * 0.5), 0.0) as Mole
	)
	mole.field = crops
	mole.target = crops[0]
	assert_false(mole.hurt_by(_session.position, 1), "under ground it cannot be hit")
	var voxel_at := _server.world.loaded_voxel_at
	for i in 100:
		Pests.sense(_server, _server.creatures, mole)
		if _block(crops[0]) == Tiles.Block.MOLEHILL:
			break
		mole.think(0.25, voxel_at, _rng)
		mole.move(0.25, voxel_at)
	assert_eq(_block(crops[0]), Tiles.Block.MOLEHILL, "gnawed from below")
	assert_true(mole.is_up(), "it comes up")
	assert_true(mole.hurt_by(_session.position, 1), "up, it is hit")
	Pests.sense(_server, _server.creatures, mole)
	assert_false(_alive(mole), "hurt, it leaves")
	var drops := Items.drops(Voxels.of_block(Tiles.Block.MOLEHILL), Vector2i.ZERO, _rng)
	assert_eq(drops[0].x, Items.Id.DIRT, "a molehill is dirt")


func test_crows_peck_seedlings_unless_a_scarecrow_stands_near() -> void:
	_wild()
	var crops := _field(8, -1, Tiles.Block.WHEAT_0)
	var crow := _add(Species.Id.CROW, 8, -1, 0.3) as Crow
	crow.peck(crops[0])
	var voxel_at := _server.world.loaded_voxel_at
	for i in 200:
		Pests.sense(_server, _server.creatures, crow)
		if _block(crops[0]) == Tiles.Block.AIR:
			break
		crow.think(0.1, voxel_at, _rng)
		crow.move(0.1, voxel_at)
	assert_eq(_block(crops[0]), Tiles.Block.AIR, "a seedling pecked up")
	assert_ne(crow.target, crops[0], "on to the next one")
	assert_ne(crow.state, Creature.State.FLEE)
	# A scarecrow near: it flies off, and is gone.
	_place(_cell(12, 4), Tiles.Block.SCARECROW)
	Pests.sense(_server, _server.creatures, crow)
	assert_eq(crow.state, Creature.State.FLEE, "scared off")
	crow.think(Crow.OFF_SECONDS + 0.1, voxel_at, _rng)
	Pests.sense(_server, _server.creatures, crow)
	assert_false(_alive(crow), "gone")
	# None come for a watched field.
	assert_true(Pests.scared(_server.world, crops[4]))
	# A scarecrow: a pumpkin over wheat and sticks.
	var stick := Items.Id.STICK
	var none := Items.Id.NONE
	var grid := PackedInt32Array(
		[none, Items.Id.PUMPKIN, none, stick, Items.Id.WHEAT, stick, none, stick, none]
	)
	assert_eq(Recipes.result_of(grid, 3), Vector2i(Items.Id.SCARECROW, 1), "a scarecrow")


func test_crows_fly_off_from_a_player_and_at_night() -> void:
	_wild()
	var crops := _field(1, 1, Tiles.Block.WHEAT_1)
	var crow := _add(Species.Id.CROW, 2, 2, 0.3) as Crow
	crow.peck(crops[4])
	Pests.sense(_server, _server.creatures, crow)
	assert_eq(crow.state, Creature.State.FLEE, "a player too close")
	_session.position += Vector2(30.0, 0.0) * GameConst.TILE_SIZE
	var other := _add(Species.Id.CROW, 2, 2, 0.3) as Crow
	other.peck(crops[4])
	_server.clock.set_frozen(WorldClock.FROZEN_MIDNIGHT)
	Pests.sense(_server, _server.creatures, other)
	assert_eq(other.state, Creature.State.FLEE, "not at night")


func test_lantern_bumblebees_let_crops_grow_at_night() -> void:
	var glows: Array[Vector3] = [Vector3(0.5, 0.5, 0.5)]
	assert_true(Pests.lit_by(glows, Vector3i(4, SEA, 0)))
	assert_false(Pests.lit_by(glows, Vector3i(int(Pests.GLOW_RANGE) + 2, SEA, 0)))
	_wild()
	_server.clock.set_frozen(WorldClock.FROZEN_MIDNIGHT)
	var crops := _field(3, 3, Tiles.Block.WHEAT_1)
	Growth.update(_server, 1.0)
	assert_eq(_block(crops[4]), Tiles.Block.WHEAT_1, "not in the dark")
	var bee := _add(Species.Id.LANTERN_BUMBLEBEE, 4, 4, 1.0) as Bee
	Growth.update(_server, 1.0)
	assert_eq(_block(crops[4]), Tiles.Block.WHEAT_2, "under a bumblebee's glow")
	# They come out at night among flowers, and go home at dawn.
	_server.creatures.remove(_server, bee, false)
	_place(_cell(-3, 2), Tiles.Block.FLOWER_BLUE)
	for i in 60:
		Pests.come_and_go(_server, _server.creatures)
	var out := _server.creatures.living.values().filter(
		func(c: Creature) -> bool: return c.species == Species.Id.LANTERN_BUMBLEBEE
	)
	assert_false(out.is_empty(), "some come out")
	assert_true(out.size() <= Pests.MAX_BUMBLEBEES)
	var first: Bee = out[0]
	assert_false(first.flowers.is_empty(), "told of the flowers and crops")
	_server.clock.set_frozen(WorldClock.FROZEN_NOON)
	first.body.place(
		Coords.tile_to_world_center(Vector2i(first.home.x, first.home.z)), first.doorstep().y - 0.2
	)
	Pests.sense(_server, _server.creatures, first)
	assert_false(_alive(first), "home by day, it goes")
	for i in 20:
		Pests.come_and_go(_server, _server.creatures)
	var by_day := _server.creatures.living.values().filter(
		func(c: Creature) -> bool: return c.species == Species.Id.LANTERN_BUMBLEBEE
	)
	assert_true(by_day.size() < out.size(), "none come out by day")
