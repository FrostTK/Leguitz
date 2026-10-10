extends TestCase
## Husbandry: feeding, mates and young ones growing up, shears and buckets,
## eggs in a nest box, affection by the day, the lead, sleeping under a
## roof, and the animals' farm life saved.

const SEA := GameConst.SEA_LEVEL
const TS := GameConst.TILE_SIZE

var _server: GameServer
var _client: LocalTransport
var _session: GameServer.PlayerSession


## A server, a player on flat grass (14 tiles around), noon.
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
	for creature: Creature in _server.creatures.living.values().duplicate():
		_server.creatures.remove(_server, creature, false)


func _tile() -> Vector2i:
	return Coords.world_to_tile(_session.position)


## An animal of `kind` standing `dx`, `dz` tiles from the player.
func _animal(kind: int, dx: int, dz: int) -> Animal:
	var box: Vector2 = Species.BOX[kind]
	var feet := Coords.tile_to_world_center(_tile() + Vector2i(dx, dz)) + Vector2(0.0, box.y * 0.5)
	return _server.creatures.add(kind, feet, 0.0) as Animal


func _hold(item: int, count := 1) -> void:
	_session.inventory.items[0] = item
	_session.inventory.counts[0] = count
	_session.inventory.wear[0] = 0


func _tend(animal: Animal) -> Array:
	_client.poll()
	_client.send(Msg.tend_animal(animal.id, 0))
	_server.process_messages()
	return _client.poll().filter(func(m: Dictionary) -> bool: return m["t"] == Msg.ANIMAL_NOTICE)


func _lying(item: int) -> int:
	var count := 0
	for dropped: DroppedItem in _server.items.values():
		if dropped.item == item:
			count += dropped.count
	return count


## How many of an item the player holds.
func _held(item: int) -> int:
	var count := 0
	for slot in Inventory.SLOTS:
		if _session.inventory.items[slot] == item:
			count += _session.inventory.counts[slot]
	return count


## Lets an animal live `seconds` (its farm life, thinking, moving).
func _live(animal: Animal, seconds: float) -> void:
	var step := 0.1
	var voxel_at := _server.creatures.voxel_at
	for i in int(seconds / step):
		Husbandry.sense(_server, _server.creatures, animal, step)
		animal.think(step, voxel_at, _server.creatures.rng)
		animal.move(step, voxel_at)


func test_fed_animals_have_a_young_one_that_grows_up() -> void:
	_farm()
	var ewe := _animal(Species.Id.SHEEP, 2, 0)
	var ram := _animal(Species.Id.SHEEP, 3, 0)
	_hold(Items.Id.WHEAT, 5)
	var told := _tend(ewe)
	assert_true(ewe.love > 0.0, "fed: in love")
	assert_eq(_session.inventory.counts[0], 4, "the wheat is eaten")
	assert_eq(ewe.affection, 1, "fed today: it loves more")
	assert_eq(told[0]["key"], "HUD_ANIMAL_IN_LOVE")
	_hold(Items.Id.CARROT, 5)
	_tend(ram)
	assert_eq(ram.love, 0.0, "a sheep does not eat carrots")
	_hold(Items.Id.WHEAT, 5)
	_tend(ram)
	var before := _server.creatures.living.size()
	Husbandry.update(_server, _server.creatures)
	assert_eq(_server.creatures.living.size(), before + 1, "a young one is born")
	var young: Animal = null
	for creature: Creature in _server.creatures.living.values():
		if creature is Animal and (creature as Animal).is_baby():
			young = creature
	assert_true(young != null and young.species == Species.Id.SHEEP)
	assert_true(young.flags() & Animal.Flag.BABY, "players see it young")
	assert_true(young.body.tall < Species.TALL[Species.Id.SHEEP], "small")
	assert_eq(ewe.love, 0.0)
	assert_true(ewe.breed_rest > 0.0, "its parents rest")
	told = _tend(ewe)
	assert_eq(told[0]["key"], "HUD_ANIMAL_NOT_HUNGRY", "fed today, resting: not hungry")
	assert_eq(_session.inventory.counts[0], 4, "nothing eaten")
	# Fed, the young one grows faster; in time it is grown.
	var age := young.age
	_tend(young)
	assert_true(young.age < age, "feeding helps it grow")
	Husbandry.sense(_server, _server.creatures, young, young.age + 1.0)
	assert_false(young.is_baby(), "grown")
	assert_eq(young.body.tall, Species.TALL[Species.Id.SHEEP])


func test_shears_and_a_bucket_take_wool_and_milk() -> void:
	_farm()
	var sheep := _animal(Species.Id.SHEEP, 2, 0)
	_hold(Items.Id.SHEARS)
	_tend(sheep)
	assert_true(sheep.shorn, "shorn")
	assert_true(_lying(Items.Id.WOOL) >= 1, "its wool falls")
	assert_eq(_session.inventory.wear[0], 1, "the shears wear")
	var told := _tend(sheep)
	assert_eq(told[0]["key"], "HUD_ANIMAL_SHORN", "not twice")
	_live(sheep, 0.2)
	Husbandry.sense(_server, _server.creatures, sheep, sheep.wool_in + 1.0)
	assert_false(sheep.shorn, "its wool grew back")
	_hold(Items.Id.BUCKET)
	_tend(sheep)
	assert_eq(_session.inventory.items[0], Items.Id.MILK_BUCKET, "milked")
	_hold(Items.Id.BUCKET)
	told = _tend(sheep)
	assert_eq(told[0]["key"], "HUD_ANIMAL_NO_MILK", "not at once again")
	assert_eq(_session.inventory.items[0], Items.Id.BUCKET)
	# Milk is drunk; the bucket stays.
	_hold(Items.Id.MILK_BUCKET)
	_session.food = 5
	Survival.eat(_server, _session, 0)
	assert_eq(_session.food, 5 + Food.SATIETY[Items.Id.MILK_BUCKET])
	assert_eq(_session.inventory.items[0], Items.Id.BUCKET, "the bucket back in hand")
	# Too young for either.
	var lamb := _animal(Species.Id.SHEEP, -2, 0)
	lamb.set_age(100.0)
	_hold(Items.Id.SHEARS)
	told = _tend(lamb)
	assert_eq(told[0]["key"], "HUD_ANIMAL_YOUNG")
	assert_false(lamb.shorn)


func test_chickens_lay_in_a_nest_box_else_on_the_ground() -> void:
	_farm()
	var hen := _animal(Species.Id.CHICKEN, 2, 0)
	Husbandry.sense(_server, _server.creatures, hen, 0.1)
	assert_true(hen.egg_in > 0.0, "it starts counting")
	hen.egg_in = 0.5
	Husbandry.sense(_server, _server.creatures, hen, 1.0)
	assert_eq(_lying(Items.Id.EGG), 1, "no nest box: an egg on the ground")
	var nest := Vector3i(_tile().x + 4, SEA, _tile().y + 2)
	_server.world.set_voxel(nest, Voxels.of_block(Tiles.Block.NEST_BOX))
	hen.egg_in = 0.5
	Husbandry.sense(_server, _server.creatures, hen, 1.0)
	assert_eq(Voxels.block_of(_server.world.voxel_at(nest)), Tiles.Block.NEST_BOX_1, "in the nest")
	assert_eq(_lying(Items.Id.EGG), 1)
	_client.send(Msg.pick(nest))
	_server.process_messages()
	assert_eq(Voxels.block_of(_server.world.voxel_at(nest)), Tiles.Block.NEST_BOX, "gathered")
	assert_eq(_held(Items.Id.EGG), 1, "an egg in the bag")
	assert_eq(Smelting.result_of(Tiles.Block.FOOD_FURNACE, Items.Id.EGG), Items.Id.FRIED_EGG)
	var rng := RandomNumberGenerator.new()
	var broken := Items.drops(Voxels.of_block(Tiles.Block.NEST_BOX_2), Vector2i.ZERO, rng)
	assert_eq(broken, [Vector2i(Items.Id.NEST_BOX, 1), Vector2i(Items.Id.EGG, 2)])


func test_affection_grows_a_day_at_a_time_and_fades_without_care() -> void:
	_farm()
	_server.clock.set_normal(20.0)
	var deer := _animal(Species.Id.DEER, 2, 0)
	_hold(Items.Id.NONE, 0)
	var told := _tend(deer)
	assert_eq(deer.affection, 1, "petted")
	assert_eq(told[0]["key"], "HUD_ANIMAL_LOVES")
	assert_eq(told[0]["value"], 1)
	told = _tend(deer)
	assert_eq(deer.affection, 1, "once a day")
	assert_eq(told[0]["key"], "HUD_ANIMAL_PETTED")
	_hold(Items.Id.APPLE, 3)
	_tend(deer)
	assert_eq(deer.affection, 2, "fed too")
	Husbandry.update(_server, _server.creatures)
	_server.clock.total_game_seconds += WorldClock.GAME_SECONDS_PER_DAY
	Husbandry.update(_server, _server.creatures)
	assert_eq(deer.affection, 2, "cared for yesterday")
	_server.clock.total_game_seconds += WorldClock.GAME_SECONDS_PER_DAY
	Husbandry.update(_server, _server.creatures)
	assert_eq(deer.affection, 1, "a day without care")
	# Loved, a sheep gives more wool.
	var sheep := _animal(Species.Id.SHEEP, -2, 0)
	sheep.affection = Husbandry.ADORED
	_hold(Items.Id.SHEARS)
	_tend(sheep)
	assert_true(_lying(Items.Id.WOOL) >= Husbandry.SHEARED[Species.Id.SHEEP].x + 2, "more wool")


func test_a_lead_takes_an_animal_along() -> void:
	_farm()
	var boar := _animal(Species.Id.BOAR, 2, 0)
	_hold(Items.Id.LEAD, 2)
	_tend(boar)
	assert_eq(boar.led_by(), _session.id, "on the lead")
	assert_eq(_session.inventory.counts[0], 1, "the lead is used")
	_session.position += Vector2(8.0, 0.0) * TS
	_live(boar, 8.0)
	var apart := boar.center().distance_to(_session.position) / TS
	assert_true(apart < Husbandry.LEAD_SLACK + 1.0, "it followed: %.1f tiles" % apart)
	_tend(boar)
	assert_eq(boar.led_by(), -1, "let go")
	assert_eq(_session.inventory.counts[0], 2, "the lead back")
	_tend(boar)
	_session.position += Vector2(Husbandry.LEAD_SNAP + 4.0, 0.0) * TS
	Husbandry.sense(_server, _server.creatures, boar, 0.1)
	assert_eq(boar.led_by(), -1, "too far: it snapped")
	assert_eq(_lying(Items.Id.LEAD), 1)


func test_loved_animals_sleep_under_a_roof_at_night() -> void:
	_farm()
	var hen := _animal(Species.Id.CHICKEN, 2, 0)
	hen.affection = 1
	# A little roof two levels up, four tiles away.
	var roof := _tile() + Vector2i(6, 3)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var at := Vector3i(roof.x + dx, SEA + 2, roof.y + dz)
			_server.world.set_voxel(at, Voxels.of_block(Tiles.Block.OAK_PLANKS))
	var wild := _animal(Species.Id.CHICKEN, -3, 0)
	_server.clock.set_frozen(WorldClock.FROZEN_MIDNIGHT)
	Husbandry.sense(_server, _server.creatures, hen, 0.1)
	assert_true(hen.shelter != Animal.NO_SHELTER, "it found a roof")
	_live(hen, 12.0)
	_live(wild, 2.0)
	assert_eq(hen.state, Creature.State.SLEEP, "asleep")
	assert_true(hen.tile().distance_to(roof) <= 1.5, "under the roof")
	assert_eq(hen.cared_day, _server.clock.day_index(), "a night under a roof is care")
	assert_eq(wild.state, Creature.State.SLEEP, "a wild one sleeps where it is")
	assert_eq(wild.shelter, Animal.NO_SHELTER)
	_server.clock.set_frozen(WorldClock.FROZEN_NOON)
	_live(hen, 1.0)
	assert_ne(hen.state, Creature.State.SLEEP, "awake by day")


func test_farm_life_is_saved() -> void:
	var sheep := Animal.create(Species.Id.SHEEP, Vector2(8.0, 14.0), 0.0)
	sheep.set_age(50.0)
	sheep.affection = 4
	sheep.shorn = true
	sheep.wool_in = 30.0
	sheep.cared_day = 3
	var again := Creatures.from_dict(sheep.to_dict()) as Animal
	assert_true(again.is_baby())
	assert_true(again.body.tall < Species.TALL[Species.Id.SHEEP], "small again")
	assert_eq(again.affection, 4)
	assert_true(again.shorn)
	assert_eq(again.cared_day, 3)
	assert_eq(again.leader, -1, "a lead is not kept")
	for item: int in [Items.Id.SHEARS, Items.Id.BUCKET, Items.Id.LEAD, Items.Id.NEST_BOX]:
		var cells := PackedInt32Array()
		cells.resize(Inventory.OWN_GRID * Inventory.OWN_GRID)
		var made := false
		for recipe: Dictionary in Recipes.all():
			if recipe["result"][0] == item:
				made = true
		assert_true(made, "%s is made" % Items.name_key(item))
	assert_eq(Items.max_stack(Items.Id.SHEARS), 1)
	assert_eq(Items.durability(Items.Id.SHEARS), Items.SHEARS_DURABILITY)
