extends TestCase
## Dogs and cats: a wolf tamed with meat into a dog, a wild cat shy unless
## a fish is held and won over with fish, orders (follow, stay, guard), a
## follower at heel and brought back from far, a dog barking at monsters
## and biting them, driving wolves off and keeping prey safe, herding
## strays back to its post, a cat hunting moles and crows, its player's
## blows sparing it, saved, young ones of their parents' player.

const SEA := GameConst.SEA_LEVEL
## The flat ground around the player (tiles each way).
const FLAT := 24

var _server: GameServer
var _client: LocalTransport
var _session: GameServer.PlayerSession


## A server, a player on flat grass, noon, no creatures.
func _world() -> void:
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
	for dz in range(-FLAT, FLAT + 1):
		for dx in range(-FLAT, FLAT + 1):
			var column := Vector3i(tile.x + dx, SEA - 1, tile.y + dz)
			_server.world.set_voxel(column, Voxels.of_ground(Tiles.Ground.GRASS))
			for up in range(1, 9):
				_server.world.set_voxel(column + Vector3i(0, up, 0), Voxels.AIR)
	for creature: Creature in _server.creatures.living.values().duplicate():
		_server.creatures.remove(_server, creature, false)
	_server.creatures.rng.seed = 11


func _tile() -> Vector2i:
	return Coords.world_to_tile(_session.position)


## A creature standing on the tile `dx`, `dz` from where the player stood
## first.
func _add(kind: int, dx: int, dz: int, height := 0.0) -> Creature:
	var box: Vector2 = Species.BOX[kind]
	var feet := Coords.tile_to_world_center(_tile() + Vector2i(dx, dz)) + Vector2(0.0, box.y * 0.5)
	return _server.creatures.add(kind, feet, height)


## A dog or a cat of the player's.
func _tamed(kind: int, dx: int, dz: int) -> Companion:
	var companion := _add(kind, dx, dz) as Companion
	companion.tame("Alex")
	return companion


func _hold(item: int, count := 1) -> void:
	_session.inventory.items[0] = item
	_session.inventory.counts[0] = count
	_session.inventory.wear[0] = 0


## Tends an animal with what is in the first slot: the notices' keys.
func _tend(animal: Animal) -> Array:
	_client.poll()
	_client.send(Msg.tend_animal(animal.id, 0))
	_server.process_messages()
	var told := _client.poll().filter(
		func(m: Dictionary) -> bool: return m["t"] == Msg.ANIMAL_NOTICE
	)
	return told.map(func(m: Dictionary) -> String: return m["key"])


func _alive(creature: Creature) -> bool:
	return _server.creatures.living.has(creature.id)


## How far (tiles) a creature stands from the player.
func _gap(creature: Creature) -> float:
	return creature.center().distance_to(_session.position) / GameConst.TILE_SIZE


## Lets creatures live `seconds` as Creatures.update would (all of them, or
## `only` those), without monsters or pests coming.
func _live(seconds: float, only: Array = []) -> void:
	var step := 0.1
	var creatures := _server.creatures
	var voxel_at := creatures.voxel_at
	for i in int(seconds / step):
		if i % 10 == 0:
			Companions.gather(_server, creatures)
		var living := only if not only.is_empty() else creatures.living.values()
		for creature: Creature in living:
			if not creatures.living.has(creature.id):
				continue
			if creature is Monster:
				Monsters.sense(_server, creatures, creature as Monster, step)
			elif creature is Animal:
				Husbandry.sense(_server, creatures, creature as Animal, step)
				if Wildlife.minds(creature.species):
					Wildlife.sense(_server, creatures, creature as Animal, step)
				elif creature is Companion:
					Companions.sense(_server, creatures, creature as Companion, step)
			creature.think(step, voxel_at, creatures.rng)
			creature.move(step, voxel_at)
			if creature is Companion and (creature as Companion).strike:
				Companions.land_blow(_server, creatures, creature as Companion)


func test_companions_are_described() -> void:
	for kind: int in Species.COMPANIONS:
		var name := String(Species.Id.find_key(kind))
		assert_true(Creatures.make(kind, Vector2.ZERO, 0.0) is Companion, "%s" % name)
		for table: Dictionary in [
			Species.CHASE_SPEED, Species.DAMAGE, Companion.STRIKE_PAUSE, Companions.COATS
		]:
			assert_true(table.has(kind), "%s described" % name)
		assert_ne(tr(Species.NAME_KEYS[kind]), Species.NAME_KEYS[kind], "%s named" % name)
		assert_ne(tr(Species.HOME_KEYS[kind]), Species.HOME_KEYS[kind], "%s at home" % name)
		var coats: Array = CompanionModels.DOGS if kind == Species.Id.DOG else CompanionModels.CATS
		assert_eq(coats.size(), Companions.COATS[kind], "every coat drawn")
		for coat in coats.size():
			for collar: bool in [false, true]:
				var parts := CreatureModels.parts(kind, false, coat, collar)
				var names := parts.map(func(part: CreatureModels.Part) -> String: return part.name)
				for part: String in [
					"body", "head", "tail", "leg_fl", "leg_fr", "leg_bl", "leg_br"
				]:
					assert_true(names.has(part), "%s %d has its %s" % [name, coat, part])
		var bare: CreatureModels.Part = CreatureModels.parts(kind, false, 0, false)[4]
		var worn: CreatureModels.Part = CreatureModels.parts(kind, false, 0, true)[4]
		assert_ne(bare.grid.voxels, worn.grid.voxels, "%s: tame, a collar" % name)
	assert_true(Species.living_in(Biomes.Id.SAVANNA).has(Species.Id.CAT), "wild cats")
	assert_true(Species.BIOMES[Species.Id.DOG].is_empty(), "dogs are tamed wolves")
	assert_true(Companions.cat_food.has(Items.Id.RAW_FISH))
	for fish: int in FishTable.SPECIES:
		assert_true(Companions.cat_food.has(fish), "a cat eats any fish")
	for key: String in [
		"HUD_COMPANION_WARY",
		"HUD_COMPANION_TAMED",
		"HUD_WOLF_TAMED",
		"HUD_WOLF_GROWLS",
		"HUD_CAT_WILD",
		"HUD_DOG_STRAY",
		"HUD_COMPANION_NOT_YOURS",
		"HUD_COMPANION_HEALED",
		"HUD_COMPANION_FOLLOW",
		"HUD_COMPANION_STAY",
		"HUD_DOG_GUARD",
		"HUD_CAT_GUARD",
		"HUD_COMPANION_BARKS",
	]:
		assert_ne(tr(key), key, "%s written" % key)
		assert_true(tr(key).begins_with("%s"), "%s names the animal" % key)


func test_a_wolf_given_meat_becomes_a_dog() -> void:
	_world()
	var wolf := _add(Species.Id.WOLF, 1, 0) as Predator
	_hold(Items.Id.RAW_MUTTON, 64)
	wolf.angry_at = _session.id
	assert_eq(_tend(wolf), ["HUD_WOLF_GROWLS"], "angry with you, it takes nothing")
	assert_eq(_session.inventory.counts[0], 64)
	wolf.angry_at = -1
	_hold(Items.Id.STICK)
	assert_eq(_tend(wolf), ["HUD_ANIMAL_WILD"], "without meat, it stays wild")
	_hold(Items.Id.RAW_MUTTON, 64)
	var tries := 0
	while _alive(wolf) and tries < 40:
		var told := _tend(wolf)
		tries += 1
		assert_true(told == ["HUD_COMPANION_WARY"] or told == ["HUD_WOLF_TAMED"], str(told))
	assert_false(_alive(wolf), "tamed after %d" % tries)
	assert_eq(_session.inventory.counts[0], 64 - tries, "each try eats a meat")
	var dog: Companion = null
	for creature: Creature in _server.creatures.living.values():
		if creature.species == Species.Id.DOG:
			dog = creature
	assert_true(dog != null and dog.is_tame(), "a dog in its place")
	assert_eq(dog.owner_name, "Alex")
	assert_eq(dog.order, Companion.Order.FOLLOW, "it follows you")
	assert_eq(dog.coat, 0, "grey like a wolf")
	assert_true(dog.flags() & Animal.Flag.TAME, "a collar")
	assert_true(dog.center().distance_to(wolf.center()) < 2.0, "where the wolf stood")
	assert_true(dog.belongs_to(_session.id))


func test_a_wild_cat_shies_unless_a_fish_is_held() -> void:
	_world()
	var shy := _add(Species.Id.CAT, 3, 0) as Companion
	assert_false(shy.is_tame())
	_live(0.2, [shy])
	assert_eq(shy.state, Creature.State.FLEE, "it runs from you")
	var cat := _add(Species.Id.CAT, -6, 0) as Companion
	_hold(Items.Id.TROUT, 64)
	_live(6.0, [cat])
	assert_ne(cat.state, Creature.State.FLEE, "a fish in hand: it comes")
	assert_true(_gap(cat) < 4.0, "up to you: %.1f" % _gap(cat))
	_hold(Items.Id.STICK)
	assert_eq(_tend(cat), ["HUD_CAT_WILD"], "a stick will not do")
	_hold(Items.Id.TROUT, 64)
	var tries := 0
	while not cat.is_tame() and tries < 40:
		_tend(cat)
		tries += 1
	assert_true(cat.is_tame(), "won over by fish")
	assert_eq(cat.owner_name, "Alex")
	assert_eq(_session.inventory.counts[0], 64 - tries)
	assert_true(cat.coat < Companions.WILD_COATS[Species.Id.CAT], "a wild cat's coat")


func test_orders_follow_stay_guard_and_a_follower_keeps_up() -> void:
	_world()
	var dog := _tamed(Species.Id.DOG, 1, 0)
	_hold(Items.Id.STICK)
	assert_eq(_tend(dog), ["HUD_COMPANION_STAY"])
	assert_eq(dog.order, Companion.Order.STAY)
	assert_eq(dog.state, Creature.State.SIT, "it sits")
	assert_eq(dog.affection, 2, "petted today")
	assert_eq(_tend(dog), ["HUD_DOG_GUARD"])
	assert_eq(dog.order, Companion.Order.GUARD)
	assert_true(dog.post.distance_to(dog.feet()) < 0.1, "where it stands")
	assert_eq(dog.affection, 2, "petted once a day")
	assert_eq(_tend(dog), ["HUD_COMPANION_FOLLOW"])
	# It keeps at your heel, and sits when you stand still.
	_session.position += Vector2(8.0, 3.0) * GameConst.TILE_SIZE
	_live(6.0, [dog])
	assert_true(_gap(dog) <= Companion.HEEL + 0.6, "at heel: %.1f" % _gap(dog))
	_live(Companion.SIT_AFTER + 0.5, [dog])
	assert_eq(dog.state, Creature.State.SIT, "sitting by you")
	# Too far, it is brought to you.
	_session.position += Vector2(-30.0, 0.0) * GameConst.TILE_SIZE
	Companions.gather(_server, _server.creatures)
	assert_true(_gap(dog) <= 3.0, "brought to you: %.1f" % _gap(dog))
	# Staying, it stays.
	_tend(dog)
	var stays := dog.center()
	_session.position += Vector2(10.0, 0.0) * GameConst.TILE_SIZE
	_live(3.0, [dog])
	Companions.gather(_server, _server.creatures)
	assert_true(dog.center().distance_to(stays) < 8.0, "it stays")
	_session.position -= Vector2(10.0, 0.0) * GameConst.TILE_SIZE
	# Not yours: someone else's dog is not told anything.
	var other := _tamed(Species.Id.DOG, -1, 1)
	other.owner_name = "Bea"
	assert_eq(_tend(other), ["HUD_COMPANION_NOT_YOURS"])
	assert_eq(other.order, Companion.Order.FOLLOW)


func test_a_dog_barks_and_bites_monsters_and_drives_wolves_off() -> void:
	_world()
	var dog := _tamed(Species.Id.DOG, 1, 0)
	var lurker := _add(Species.Id.SHADE_LURKER, 6, 0) as Monster
	_client.poll()
	_live(6.0, [dog, lurker])
	assert_true(dog.barking or not _alive(lurker), "it barks at it")
	var told := _client.poll().filter(
		func(m: Dictionary) -> bool: return m.get("key", "") == "HUD_COMPANION_BARKS"
	)
	assert_eq(told.size(), 1, "you are told, once")
	assert_true(
		not _alive(lurker) or lurker.health < Species.HEALTH[Species.Id.SHADE_LURKER], "bitten"
	)
	_live(20.0, [dog, lurker])
	assert_false(_alive(lurker), "the dog killed it")
	_live(1.0, [dog])
	assert_false(dog.barking, "quiet again")
	# Prey near a dog is safe from wolves; a bitten wolf runs off.
	var sheep := _add(Species.Id.SHEEP, -4, 0)
	dog.body.place(sheep.body.feet + Vector2(2.0, 0.0) * GameConst.TILE_SIZE, 0.0)
	var wolf := _add(Species.Id.WOLF, -12, 0) as Predator
	Wildlife.sense(_server, _server.creatures, wolf, 0.1)
	assert_false(wolf.has_target(), "no hunting near a dog")
	var dogs := Companions.dogs_of(_server.creatures)
	assert_true(Companions.protects(dogs, sheep))
	var far := _add(Species.Id.SHEEP, -20, 0)
	assert_false(Companions.protects(dogs, far), "too far from the dog")
	wolf.target_id = sheep.id
	wolf.target = Vector3(1.0, 0.0, 1.0)
	wolf.angry_at = _session.id
	dog.target_id = wolf.id
	dog.strike = true
	dog.body.place(wolf.body.feet + Vector2(10.0, 0.0), 0.0)
	Companions.land_blow(_server, _server.creatures, dog)
	assert_eq(wolf.health, Species.HEALTH[Species.Id.WOLF] - Species.DAMAGE[Species.Id.DOG])
	assert_eq(wolf.state, Creature.State.FLEE, "it runs off")
	assert_false(wolf.has_target(), "its hunt forgotten")
	assert_eq(wolf.angry_at, -1, "angry with nobody for it")
	assert_eq(wolf.provoked, Vector2.INF)


func test_a_guarding_dog_herds_strays_back() -> void:
	_world()
	var dog := _tamed(Species.Id.DOG, 0, 4)
	dog.command(Companion.Order.GUARD)
	var post := Vector2(dog.post.x, dog.post.z)
	var sheep := _add(Species.Id.SHEEP, 11, 4) as Animal
	var closest := INF
	var driven := false
	for i in 30:
		_live(1.0, [dog, sheep])
		driven = driven or dog.drive_id == sheep.id
		closest = minf(closest, (sheep.center() / GameConst.TILE_SIZE).distance_to(post))
	assert_true(driven, "it went for the stray")
	assert_true(closest <= Companions.BACK_IN + 1.0, "brought back: %.1f" % closest)


func test_a_cat_hunts_moles_and_crows() -> void:
	_world()
	var cat := _tamed(Species.Id.CAT, 0, 3)
	cat.command(Companion.Order.GUARD)
	var mole := _add(Species.Id.MOLE, 4, 3) as Mole
	mole.state = Creature.State.WANDER
	_live(4.0, [cat])
	assert_true(_alive(mole), "under ground, it waits")
	assert_eq(cat.target_id, mole.id, "by its tunnel")
	mole.state = Creature.State.IDLE
	_live(4.0, [cat])
	assert_false(_alive(mole), "come up, it is caught")
	var crow := _add(Species.Id.CROW, -3, 5, 3.0) as Crow
	crow.state = Creature.State.WANDER
	_live(3.0, [cat])
	assert_true(_alive(crow), "flying, it is out of reach")
	crow.body.place(crow.body.feet, 0.0)
	crow.state = Creature.State.GRAZE
	_live(4.0, [cat])
	assert_false(_alive(crow), "landed, it is caught")
	var feathers := 0
	for dropped: DroppedItem in _server.items.values():
		if dropped.item == Items.Id.FEATHER:
			feathers += dropped.count
	assert_true(feathers > 0, "feathers left")


func test_its_player_spares_it_and_others_do_not() -> void:
	_world()
	var dog := _tamed(Species.Id.DOG, 1, 0)
	dog.owner_id = _session.id
	_hold(Items.Id.IRON_SWORD)
	_server.creatures.attack(_server, _session, dog.id, 0)
	assert_eq(dog.health, Species.HEALTH[Species.Id.DOG], "its player's blow spares it")
	dog.owner_name = "Bea"
	dog.owner_id = 99
	_server.creatures.attack(_server, _session, dog.id, 0)
	assert_true(dog.health < Species.HEALTH[Species.Id.DOG], "not theirs: hurt")
	# Its food heals it; a while later it mends by itself too.
	dog.owner_name = "Alex"
	var hurt := dog.health
	_hold(Items.Id.COOKED_BEEF, 4)
	assert_eq(_tend(dog), ["HUD_COMPANION_HEALED"])
	assert_eq(dog.health, mini(hurt + Companions.HEAL, Species.HEALTH[Species.Id.DOG]))
	assert_eq(_session.inventory.counts[0], 3)


func test_companions_are_saved_and_have_young_ones() -> void:
	_world()
	var dog := _tamed(Species.Id.DOG, 1, 0)
	dog.command(Companion.Order.GUARD)
	dog.coat = 3
	var again := Creatures.from_dict(dog.to_dict()) as Companion
	assert_true(again != null)
	assert_eq(again.owner_name, "Alex")
	assert_eq(again.order, Companion.Order.GUARD)
	assert_eq(again.post, dog.post)
	assert_eq(again.coat, 3)
	assert_true(again.flags() & Animal.Flag.TAME)
	var cat := Creatures.from_dict(_add(Species.Id.CAT, 2, 2).to_dict()) as Companion
	assert_false(cat.is_tame(), "a wild cat stays wild")
	# Fed in good health, two dogs have a puppy: yours too.
	var mother := _tamed(Species.Id.DOG, 2, 0)
	var father := _tamed(Species.Id.DOG, 2, 1)
	_hold(Items.Id.RAW_BEEF, 4)
	assert_eq(_tend(mother), ["HUD_ANIMAL_IN_LOVE"])
	_tend(father)
	var before := _server.creatures.living.size()
	Husbandry.update(_server, _server.creatures)
	assert_eq(_server.creatures.living.size(), before + 1, "a puppy is born")
	var puppy: Companion = null
	for creature: Creature in _server.creatures.living.values():
		if creature is Companion and (creature as Companion).is_baby():
			puppy = creature
	assert_true(puppy != null and puppy.species == Species.Id.DOG)
	assert_eq(puppy.owner_name, "Alex", "yours")
	assert_true(puppy.coat >= 0 and puppy.coat < Companions.COATS[Species.Id.DOG])
