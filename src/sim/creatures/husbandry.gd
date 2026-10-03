class_name Husbandry
extends RefCounted
## Farm life, on the server (static, given the server; Creatures runs it,
## each animal keeps its own timers: Animal). Fed what it likes (FEED), a
## grown animal looks for a mate for LOVE_SECONDS; two of a kind in love
## near each other meet and a young one is born (it grows up after
## GROW_SECONDS, sooner when fed), then its parents rest a while
## (BREED_REST_SECONDS). A lead takes an animal along: it follows its
## player, and too far the lead snaps. Shears take a sheep's wool (it grows
## back), a bucket its milk (now and then); chickens lay eggs, in a nest box
## near if there is one, else on the ground. An animal loves the players who
## pet it and feed it (once a day each, up to MAX_AFFECTION), less after a
## day without care; loved, it gives more (LOVED, ADORED). At night animals
## sleep; one that is loved first goes under a roof nearby (SHELTER_RANGE),
## and a night there counts as care. Durations are the default day's,
## paced by WorldClock.scale_duration (LOVE_SECONDS: real seconds).

const MAX_AFFECTION := 5
## Loved this much, it gives more: a fleece more, milk and eggs sooner;
## adored, a fleece more again and two eggs now and then.
const LOVED := 3
const ADORED := 5
const LOVED_SOONER := 0.75
const TWIN_EGGS := 0.3
const LOVE_SECONDS := 30.0
const BREED_REST_SECONDS := 300.0
const GROW_SECONDS := 1200.0
## Feeding a young one takes this share off its growing up.
const FEED_GROWTH := 0.1
## Mates find each other this far (tiles) and meet this close.
const MATE_RANGE := 8.0
const MATE_MEET := 1.3
const WOOL_SECONDS := 300.0
const MILK_SECONDS := 300.0
const EGG_SECONDS := 300.0
## A chicken lays in a nest box this near (tiles across, rows up and down).
const NEST_RANGE := 8
const NEST_ROWS := 2
## On a lead an animal follows farther than LEAD_SLACK tiles; farther than
## LEAD_SNAP the lead snaps.
const LEAD_SLACK := 2.5
const LEAD_SNAP := 12.0
## At night a loved animal looks for a roof this far (tiles; ground tiles
## tried at most), something over its head within ROOF_ROWS.
const SHELTER_RANGE := 12
const SHELTER_TRIES := 400
const ROOF_ROWS := 5
## How often (ticks) mates look for each other.
const PAIR_TICKS := 5
## What each species eats (a right click with it).
const FEED := {
	Species.Id.SHEEP: [Items.Id.WHEAT, Items.Id.CABBAGE],
	Species.Id.BOAR: [Items.Id.CARROT, Items.Id.POTATO, Items.Id.BEETROOT, Items.Id.APPLE],
	Species.Id.CHICKEN:
	[
		Items.Id.SEEDS,
		Items.Id.BEETROOT_SEEDS,
		Items.Id.CABBAGE_SEEDS,
		Items.Id.TOMATO_SEEDS,
		Items.Id.FLAX_SEEDS,
		Items.Id.PUMPKIN_SEEDS,
		Items.Id.MELON_SEEDS,
		Items.Id.RICE,
		Items.Id.CORN,
	],
	Species.Id.DEER: [Items.Id.APPLE, Items.Id.CABBAGE, Items.Id.CARROT],
}
## Who gives wool to shears (and how many fleeces at least, at most), milk
## to a bucket, eggs.
const SHEARED := {Species.Id.SHEEP: Vector2i(1, 2)}
const MILKED := {Species.Id.SHEEP: true}
const LAYS := {Species.Id.CHICKEN: true}
## A nest box by the eggs in it.
const NESTS: Array[int] = [
	Tiles.Block.NEST_BOX, Tiles.Block.NEST_BOX_1, Tiles.Block.NEST_BOX_2, Tiles.Block.NEST_BOX_3
]

## Tiles around a spot, nearest first (looking for a shelter).
static var _around := _build_around()


## Farm life for all the animals (Creatures.update, every tick): mates meet,
## a new day takes love from those left without care.
static func update(server: GameServer, creatures: Creatures) -> void:
	var day := server.clock.day_index()
	if creatures.day != day:
		if creatures.day >= 0:
			_neglect(creatures, day)
		creatures.day = day
	if server.tick_count % PAIR_TICKS == 0:
		_pair(server, creatures)


## One animal's step before it thinks (`delta` seconds): its timers, its
## lead, the night and its shelter.
static func sense(server: GameServer, creatures: Creatures, animal: Animal, delta: float) -> void:
	_tick(server, creatures, animal, delta)
	animal.leader_at = Animal.NOWHERE
	if animal.leader >= 0:
		var player := _session(server, animal.leader)
		var snap := LEAD_SNAP * GameConst.TILE_SIZE
		if (
			player == null
			or not player.alive()
			or animal.center().distance_to(player.position) > snap
		):
			_snap(server, animal, player)
		else:
			animal.leader_at = player.position
	animal.night = server.clock.is_night()
	if not animal.night:
		animal.shelter = Animal.NO_SHELTER
		animal.shelter_searched = false
	elif animal.affection > 0 and not animal.shelter_searched:
		animal.shelter_searched = true
		animal.shelter = find_shelter(creatures.voxel_at, animal)
	if animal.state == Creature.State.SLEEP:
		var height := animal.body.height
		if covered(creatures.voxel_at, animal.tile(), height, animal.body.tall):
			animal.cared_day = server.clock.day_index()


## A player used an animal with what is in a hotbar slot (Msg.TEND_ANIMAL):
## within reach, its own lead lets it go, a lead takes it along, shears
## shear it, a bucket milks it, what it eats feeds it, anything else pets
## it. The player is told how it went (Msg.ANIMAL_NOTICE).
static func tend(
	server: GameServer, session: GameServer.PlayerSession, message: Dictionary
) -> void:
	var animal := server.creatures.living.get(int(message.get("id", -1))) as Animal
	if animal == null or not session.joined or not session.alive():
		return
	if not _within_reach(session, animal):
		return
	var slot := int(message.get("slot", -1))
	var bag := session.inventory
	var held := bag.items[slot] if slot >= 0 and slot < Inventory.HOTBAR else Items.Id.NONE
	var day := server.clock.day_index()
	if animal.leader == session.id:
		_unleash(server, session, animal)
	elif held == Items.Id.LEAD:
		if animal.leader < 0:
			animal.leader = session.id
			animal.dirty = true
			if not GameModes.creative(server):
				bag.take(slot, 1)
	elif held == Items.Id.SHEARS:
		_shear(server, session, animal, slot)
	elif held == Items.Id.BUCKET:
		_milk(server, session, animal, slot)
	elif FEED.get(animal.species, []).has(held):
		_feed(server, session, animal, slot, day)
	else:
		_pet(session, animal, day)
	session.transport.send(Msg.inventory(bag))


## The nearest tile (to `animal`) with a roof over its ground, within
## SHELTER_RANGE (Animal.NO_SHELTER: none).
static func find_shelter(voxel_at: Callable, animal: Animal) -> Vector2i:
	var start := animal.tile()
	var tries := 0
	for offset: Vector2i in _around:
		var tile := start + offset
		var ground := Pathfinder.ground_at(tile, animal.body.height, voxel_at, animal.body.tall)
		if is_nan(ground):
			continue
		if covered(voxel_at, tile, ground, animal.body.tall):
			return tile
		tries += 1
		if tries >= SHELTER_TRIES:
			break
	return Animal.NO_SHELTER


## Whether a cube lies over a body `tall` levels high standing on a tile at
## `ground` (levels), within ROOF_ROWS.
static func covered(voxel_at: Callable, tile: Vector2i, ground: float, tall: float) -> bool:
	var row := floori(ground + 0.01) + GameConst.SEA_LEVEL + ceili(tall)
	for up in ROOF_ROWS:
		var voxel: int = voxel_at.call(Vector3i(tile.x, row + up, tile.y))
		if voxel != Voxels.UNKNOWN and Voxels.is_cube(voxel):
			return true
	return false


## How long (seconds) until a product comes back: paced, sooner when loved.
static func soon(server: GameServer, animal: Animal, seconds: float) -> float:
	var share := LOVED_SOONER if animal.affection >= LOVED else 1.0
	return server.clock.scale_duration(seconds) * share


static func _tick(server: GameServer, creatures: Creatures, animal: Animal, delta: float) -> void:
	if animal.age > 0.0:
		animal.age -= delta
		if animal.age <= 0.0:
			animal.set_age(0.0)
	if animal.love > 0.0:
		animal.love = maxf(animal.love - delta, 0.0)
		if animal.love == 0.0:
			animal.mate_at = Animal.NOWHERE
			animal.dirty = true
	animal.breed_rest = maxf(animal.breed_rest - delta, 0.0)
	animal.milk_in = maxf(animal.milk_in - delta, 0.0)
	if animal.shorn:
		animal.wool_in -= delta
		if animal.wool_in <= 0.0:
			animal.wool_in = 0.0
			animal.shorn = false
			animal.dirty = true
	if LAYS.has(animal.species) and not animal.is_baby():
		var before := animal.egg_in
		animal.egg_in -= delta
		if animal.egg_in <= 0.0:
			animal.egg_in = soon(server, animal, EGG_SECONDS) * creatures.rng.randf_range(0.8, 1.2)
			# The first time it only starts counting.
			if before > 0.0:
				_lay(server, creatures, animal)


## Two of a kind in love near each other walk to each other; met, a young
## one is born between them.
static func _pair(server: GameServer, creatures: Creatures) -> void:
	var lovers: Array[Animal] = []
	for creature: Creature in creatures.living.values():
		var animal := creature as Animal
		if animal != null and animal.love > 0.0 and not animal.is_baby():
			if animal.breed_rest <= 0.0:
				lovers.append(animal)
	var reach := MATE_RANGE * GameConst.TILE_SIZE
	for animal in lovers:
		if animal.love <= 0.0:
			continue
		var mate: Animal = null
		var nearest := reach
		for other in lovers:
			if other == animal or other.species != animal.species or other.love <= 0.0:
				continue
			var distance := other.center().distance_to(animal.center())
			if distance < nearest:
				nearest = distance
				mate = other
		animal.mate_at = mate.center() if mate != null else Animal.NOWHERE
		if mate != null and nearest < MATE_MEET * GameConst.TILE_SIZE:
			_birth(server, creatures, animal, mate)


static func _birth(
	server: GameServer, creatures: Creatures, mother: Animal, father: Animal
) -> void:
	var feet := (mother.body.feet + father.body.feet) * 0.5
	var height := maxf(mother.body.height, father.body.height)
	var young := creatures.add(mother.species, feet, height) as Animal
	young.set_age(server.clock.scale_duration(GROW_SECONDS))
	young.heading = mother.heading
	# Born to loved parents, it knows its players a little.
	young.affection = (mother.affection + father.affection) / 4
	young.cared_day = server.clock.day_index()
	for parent: Animal in [mother, father]:
		parent.love = 0.0
		parent.breed_rest = server.clock.scale_duration(BREED_REST_SECONDS)
		parent.mate_at = Animal.NOWHERE
		parent.dirty = true


## A day went by: the loved animals nobody cared for that day love less.
static func _neglect(creatures: Creatures, day: int) -> void:
	for creature: Creature in creatures.living.values():
		var animal := creature as Animal
		if animal != null and animal.affection > 0 and animal.cared_day < day - 1:
			animal.affection -= 1


## A chicken lays (two eggs now and then when adored): in the nearest nest
## box with room, else at its feet.
static func _lay(server: GameServer, creatures: Creatures, animal: Animal) -> void:
	var count := 1
	if animal.affection >= ADORED and creatures.rng.randf() < TWIN_EGGS:
		count = 2
	var nest := _nest_near(creatures.voxel_at, animal)
	if nest != Vector3i.MAX:
		var level := NESTS.find(Voxels.block_of(creatures.voxel_at(nest)))
		server.change_voxel(nest, Voxels.of_block(NESTS[mini(level + count, NESTS.size() - 1)]))
		return
	var speed := Vector3(0.0, 1.5, 0.0)
	server.spawn_item(Items.Id.EGG, count, animal.bounds().get_center(), speed)


## The nearest nest box with room around an animal (Vector3i.MAX: none).
static func _nest_near(voxel_at: Callable, animal: Animal) -> Vector3i:
	var at := animal.tile()
	var row := floori(animal.body.height + 0.01) + GameConst.SEA_LEVEL
	var best := Vector3i.MAX
	var nearest := INF
	var full: int = NESTS[NESTS.size() - 1]
	for dz in range(-NEST_RANGE, NEST_RANGE + 1):
		for dx in range(-NEST_RANGE, NEST_RANGE + 1):
			for dy in range(-NEST_ROWS, NEST_ROWS + 1):
				var cell := Vector3i(at.x + dx, row + dy, at.y + dz)
				var block := Voxels.block_of(voxel_at.call(cell))
				if block in NESTS and block != full and dx * dx + dz * dz < nearest:
					nearest = dx * dx + dz * dz
					best = cell
	return best


static func _feed(
	server: GameServer, session: GameServer.PlayerSession, animal: Animal, slot: int, day: int
) -> void:
	var used := false
	if animal.is_baby():
		animal.set_age(animal.age - server.clock.scale_duration(GROW_SECONDS) * FEED_GROWTH)
		used = true
	elif animal.love <= 0.0 and animal.breed_rest <= 0.0:
		animal.love = LOVE_SECONDS
		animal.dirty = true
		used = true
	var loved := animal.fed_day != day
	if loved:
		animal.fed_day = day
		animal.cared_day = day
		animal.affection = mini(animal.affection + 1, MAX_AFFECTION)
	if not used and not loved:
		_notice(session, animal, "HUD_ANIMAL_NOT_HUNGRY")
		return
	if not GameModes.creative(server):
		session.inventory.take(slot, 1)
	if animal.love > 0.0 and not animal.is_baby():
		_notice(session, animal, "HUD_ANIMAL_IN_LOVE")
	else:
		_notice(session, animal, "HUD_ANIMAL_LOVES")


static func _pet(session: GameServer.PlayerSession, animal: Animal, day: int) -> void:
	if animal.petted_day == day:
		_notice(session, animal, "HUD_ANIMAL_PETTED")
		return
	animal.petted_day = day
	animal.cared_day = day
	animal.affection = mini(animal.affection + 1, MAX_AFFECTION)
	_notice(session, animal, "HUD_ANIMAL_LOVES")


static func _shear(
	server: GameServer, session: GameServer.PlayerSession, animal: Animal, slot: int
) -> void:
	if not SHEARED.has(animal.species):
		_notice(session, animal, "HUD_ANIMAL_NOTHING")
		return
	if animal.is_baby():
		_notice(session, animal, "HUD_ANIMAL_YOUNG")
		return
	if animal.shorn:
		_notice(session, animal, "HUD_ANIMAL_SHORN")
		return
	var fleeces: Vector2i = SHEARED[animal.species]
	var count := server.creatures.rng.randi_range(fleeces.x, fleeces.y)
	count += (1 if animal.affection >= LOVED else 0) + (1 if animal.affection >= ADORED else 0)
	var speed := Vector3(0.0, 2.5, 0.0)
	server.spawn_item(Items.Id.WOOL, count, animal.bounds().get_center(), speed)
	animal.shorn = true
	animal.wool_in = soon(server, animal, WOOL_SECONDS)
	animal.dirty = true
	if not GameModes.creative(server):
		session.inventory.wear_out(slot)


static func _milk(
	server: GameServer, session: GameServer.PlayerSession, animal: Animal, slot: int
) -> void:
	if not MILKED.has(animal.species):
		_notice(session, animal, "HUD_ANIMAL_NOTHING")
		return
	if animal.is_baby():
		_notice(session, animal, "HUD_ANIMAL_YOUNG")
		return
	if animal.milk_in > 0.0:
		_notice(session, animal, "HUD_ANIMAL_NO_MILK")
		return
	var bag := session.inventory
	if not GameModes.creative(server):
		bag.take(slot, 1)
	if bag.items[slot] == Items.Id.NONE:
		bag.items[slot] = Items.Id.MILK_BUCKET
		bag.counts[slot] = 1
	elif bag.add(Items.Id.MILK_BUCKET, 1) > 0:
		server.throw_item(session, Items.Id.MILK_BUCKET, 1)
	animal.milk_in = soon(server, animal, MILK_SECONDS)


static func _unleash(server: GameServer, session: GameServer.PlayerSession, animal: Animal) -> void:
	animal.leader = -1
	animal.leader_at = Animal.NOWHERE
	animal.dirty = true
	if not GameModes.creative(server) and session.inventory.add(Items.Id.LEAD, 1) > 0:
		server.throw_item(session, Items.Id.LEAD, 1)


## The lead snaps (its player too far, or gone): it falls by the animal.
static func _snap(server: GameServer, animal: Animal, player: GameServer.PlayerSession) -> void:
	animal.leader = -1
	animal.dirty = true
	server.spawn_item(Items.Id.LEAD, 1, animal.bounds().get_center(), Vector3(0.0, 2.0, 0.0))
	if player != null:
		_notice(player, animal, "HUD_ANIMAL_LEAD_SNAPPED")


static func _notice(session: GameServer.PlayerSession, animal: Animal, key: String) -> void:
	session.transport.send(Msg.animal_notice(key, animal.species, animal.affection))


static func _within_reach(session: GameServer.PlayerSession, animal: Animal) -> bool:
	var feet := session.position / GameConst.TILE_SIZE
	var eye := Vector3(feet.x, session.height + Mining.EYE_HEIGHT, feet.y)
	var bounds := animal.bounds()
	var distance := eye.distance_to(eye.clamp(bounds.position, bounds.end))
	return distance <= Combat.REACH + Combat.REACH_LEEWAY


static func _session(server: GameServer, id: int) -> GameServer.PlayerSession:
	for session in server.sessions:
		if session.id == id and session.joined:
			return session
	return null


static func _build_around() -> Array[Vector2i]:
	var offsets: Array[Vector2i] = []
	for dz in range(-SHELTER_RANGE, SHELTER_RANGE + 1):
		for dx in range(-SHELTER_RANGE, SHELTER_RANGE + 1):
			offsets.append(Vector2i(dx, dz))
	offsets.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool: return a.length_squared() < b.length_squared()
	)
	return offsets
