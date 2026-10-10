class_name Companions
extends RefCounted
## Dogs and cats on the server (static, given the server; Creatures runs
## `sense` before each one thinks, `land_blow` when one bites and `gather`
## every BRING_TICKS). A wolf given meat (DOG_FOOD, raw or cooked) by a
## player it is not after eats it (its hunger goes) and now and then
## (TAME_CHANCE) is tamed: it becomes their dog. A wild cat takes to a
## player the same way with fish (`cat_food`); it shies away from players
## within SHY_RANGE unless they hold a fish, then it comes up to them. Its
## player's right click (Msg.TEND_ANIMAL, `tend`) with its food heals it
## (HEAL), else feeds it as farm animals are fed (Husbandry.feed: love,
## young ones of a coat of their own, COATS); with anything else it tells
## it the next order (Companion.Order: follow, stay, guard) and pets it.
## Someone else's companion is not theirs to tend, nor to hurt.
## Following, it is brought to its player when they get farther than
## BRING_RANGE (not while they are aboard a boat: it takes a bench with
## them, Boats); it heals a point every MEND_SECONDS. A dog barks at the
## monsters and hunting predators within BARK_RANGE (its player is told
## now and then) and, following or guarding, goes for those within
## DEFEND_RANGE of its player or its post (giving up past LEASH): bitten,
## a monster is hurt, a predator driven off (it flees, forgets its hunt);
## no predator hunts prey near a dog (`protects`). Guarding, a dog herds
## back to its post the farm animals (FLOCK) within HERD_RANGE that
## strayed farther than KEEP. A cat following or guarding hunts the moles
## and crows within HUNT_RANGE: a mole once it comes up, a crow once it
## lands.

const TAME_CHANCE := 0.34
const SHY_RANGE := 6.0
const CURIOUS_RANGE := 9.0
const HEAL := 4
const MEND_SECONDS := 20.0
const BRING_TICKS := 20
const BRING_RANGE := 20.0
const BRING_HEIGHT := 6.0
## How often (seconds) it looks around for what to hunt or herd.
const LOOK_SECONDS := 0.5
const BARK_RANGE := 12.0
## Its player is told it barks at most this often (seconds).
const BARK_NOTICE := 30.0
const DEFEND_RANGE := 8.0
const LEASH := 16.0
## Bites land up to this much farther than Companion.REACH (they move).
const REACH_LEEWAY := 1.0
const HUNT_RANGE := 10.0
## Herding: the flock around its post, kept within KEEP tiles; one that
## strayed is driven back until within BACK_IN, the dog behind it
## (BEHIND tiles), pushing it on within PUSH_RANGE; it gives up after
## DRIVE_SECONDS.
const HERD_RANGE := 16.0
const KEEP := 7.0
const BACK_IN := 4.0
const BEHIND := 1.6
const PUSH_RANGE := 2.5
const DRIVE_SECONDS := 15.0
const FLOCK := {
	Species.Id.SHEEP: true,
	Species.Id.CHICKEN: true,
	Species.Id.COW: true,
	Species.Id.GOAT: true,
	Species.Id.DUCK: true,
	Species.Id.PIG: true,
}
## How many coats each kind has (CompanionModels), the wild ones' first.
const COATS := {Species.Id.DOG: 5, Species.Id.CAT: 6}
const WILD_COATS := {Species.Id.DOG: 1, Species.Id.CAT: 2}
## A young one has a parent's coat this often, else any.
const LIKE_A_PARENT := 0.6
const DOG_FOOD: Array[int] = [
	Items.Id.RAW_MUTTON,
	Items.Id.RAW_PORK,
	Items.Id.RAW_CHICKEN,
	Items.Id.RAW_VENISON,
	Items.Id.RAW_BEEF,
	Items.Id.RAW_RABBIT,
	Items.Id.RAW_DUCK,
	Items.Id.COOKED_MUTTON,
	Items.Id.COOKED_PORK,
	Items.Id.COOKED_CHICKEN,
	Items.Id.COOKED_VENISON,
	Items.Id.COOKED_BEEF,
	Items.Id.COOKED_RABBIT,
	Items.Id.COOKED_DUCK,
]
## Every fish, raw or grilled.
static var cat_food := _fish()


## What a companion eats (and is tamed with).
static func food_of(kind: int) -> Array[int]:
	return DOG_FOOD if kind == Species.Id.DOG else cat_food


## A companion's step before it thinks (see the class).
static func sense(
	server: GameServer, creatures: Creatures, companion: Companion, delta: float
) -> void:
	var owner := _owner(server, companion)
	companion.owner_id = owner.id if owner != null else -1
	companion.owner_at = owner.position if owner != null else Animal.NOWHERE
	companion.owner_height = owner.height if owner != null else 0.0
	if not companion.is_tame():
		_wild(server, companion)
		return
	if owner != null and companion.order == Companion.Order.FOLLOW:
		# Time spent together counts as care.
		companion.cared_day = server.clock.day_index()
	_mend(companion, delta)
	companion.told_in = maxf(companion.told_in - delta, 0.0)
	companion.look_in -= delta
	if companion.look_in <= 0.0:
		companion.look_in = LOOK_SECONDS
		if companion.species == Species.Id.DOG:
			_watch(creatures, companion, owner)
		else:
			_prowl(creatures, companion)
	_keep_on(creatures, companion)
	if companion.species == Species.Id.DOG:
		_herd(creatures, companion, delta)


## A companion's bite landed: what it bit is hurt (dead, it leaves what
## it gives); a predator is driven off.
static func land_blow(server: GameServer, creatures: Creatures, companion: Companion) -> void:
	companion.strike = false
	var prey: Creature = creatures.living.get(companion.target_id)
	if prey == null:
		companion.forget()
		return
	var reach := Companion.REACH + REACH_LEEWAY
	if prey.bounds().get_center().distance_to(companion.middle()) > reach:
		return
	if not prey.hurt_by(companion.center(), Species.DAMAGE[companion.species]):
		return
	creatures.tell_seers(server, prey.id, Msg.entity_hurt(prey.id))
	if prey.health <= 0:
		creatures.die(server, prey)
		companion.forget()
		return
	var predator := prey as Predator
	if predator != null:
		# Not angry with a player for it: it runs off, its hunt forgotten.
		predator.provoked = Vector2.INF
		predator.forget()
		predator.angry_at = -1
		predator.anger = 0.0
		predator.hunger = server.clock.scale_duration(Wildlife.HUNGER_SECONDS) * 0.5
		predator.scare(companion.center())
		companion.forget()


## Following companions far from their player are brought to them.
static func gather(server: GameServer, creatures: Creatures) -> void:
	for creature: Creature in creatures.living.values():
		var companion := creature as Companion
		if companion == null or not companion.is_tame() or companion.seated >= 0:
			continue
		if companion.order != Companion.Order.FOLLOW:
			continue
		var owner := _owner(server, companion)
		if owner == null or owner.boat >= 0:
			continue
		var gap := companion.center().distance_to(owner.position) / GameConst.TILE_SIZE
		if gap <= BRING_RANGE and absf(owner.height - companion.body.height) <= BRING_HEIGHT:
			continue
		_bring(creatures, companion, owner)


## A player's right click on a companion or a wolf, within reach
## (Husbandry.tend): taming, healing, feeding, orders. False when it is
## none of this (a wolf without meat in hand: Husbandry says it is wild).
static func tend(
	server: GameServer, session: GameServer.PlayerSession, animal: Animal, slot: int
) -> bool:
	var bag := session.inventory
	var held := bag.items[slot] if slot >= 0 and slot < Inventory.HOTBAR else Items.Id.NONE
	if animal is Predator:
		if animal.species != Species.Id.WOLF or not DOG_FOOD.has(held):
			return false
		_tame_wolf(server, session, animal as Predator, slot)
		return true
	var companion := animal as Companion
	if companion == null:
		return false
	var food := food_of(companion.species)
	if not companion.is_tame():
		if food.has(held):
			_tame(server, session, companion, slot)
		else:
			var key := "HUD_CAT_WILD" if companion.species == Species.Id.CAT else "HUD_DOG_STRAY"
			_notice(session, companion, key)
		return true
	if companion.owner_name != session.player_name:
		_notice(session, companion, "HUD_COMPANION_NOT_YOURS")
		return true
	if food.has(held):
		var most: int = Species.HEALTH[companion.species]
		if companion.health < most:
			companion.health = mini(companion.health + HEAL, most)
			_eat(server, session, slot)
			_notice(session, companion, "HUD_COMPANION_HEALED")
		else:
			Husbandry.feed(server, session, companion, slot, server.clock.day_index())
		return true
	_order(server, session, companion)
	return true


## Whether a dog keeps predators off an animal: guarding near it (its post
## within HERD_RANGE) or anywhere within DEFEND_RANGE of it. `dogs`: the
## tame dogs (`dogs_of`).
static func protects(dogs: Array[Companion], animal: Creature) -> bool:
	var at := animal.center() / GameConst.TILE_SIZE
	for dog in dogs:
		if dog.order == Companion.Order.GUARD and dog.post != Vector3.INF:
			if Vector2(dog.post.x, dog.post.z).distance_to(at) <= HERD_RANGE:
				return true
		if dog.center().distance_to(animal.center()) / GameConst.TILE_SIZE <= DEFEND_RANGE:
			return true
	return false


## The tame dogs on the ground.
static func dogs_of(creatures: Creatures) -> Array[Companion]:
	var dogs: Array[Companion] = []
	for creature: Creature in creatures.living.values():
		var dog := creature as Companion
		if dog != null and dog.species == Species.Id.DOG and dog.is_tame() and dog.seated < 0:
			dogs.append(dog)
	return dogs


## A young one's coat: often a parent's, else any of its kind's; tame, it
## is its parents' player's and does as they were told.
static func born(
	young: Companion, mother: Companion, father: Companion, rng: RandomNumberGenerator
) -> void:
	var parent := mother if rng.randf() < 0.5 else father
	young.coat = parent.coat
	if rng.randf() >= LIKE_A_PARENT:
		young.coat = rng.randi() % int(COATS[young.species])
	if mother.is_tame():
		young.tame(mother.owner_name)
		young.command(mother.order)


## A wild cat: it comes up to a player holding a fish, shies away from
## one who does not.
static func _wild(server: GameServer, companion: Companion) -> void:
	if companion.species != Species.Id.CAT or companion.state == Creature.State.FLEE:
		return
	var nearest: GameServer.PlayerSession = null
	var best := CURIOUS_RANGE * GameConst.TILE_SIZE
	for session in server.sessions:
		if not session.joined or not session.alive() or session.spectator:
			continue
		var distance := session.position.distance_to(companion.center())
		if distance <= best:
			best = distance
			nearest = session
	if nearest == null:
		return
	if cat_food.has(nearest.inventory.held()):
		companion.leader_at = nearest.position
	elif best <= SHY_RANGE * GameConst.TILE_SIZE:
		companion.scare(nearest.position)


## A point of vitality back now and then.
static func _mend(companion: Companion, delta: float) -> void:
	if companion.health >= Species.HEALTH[companion.species]:
		companion.mend_in = MEND_SECONDS
		return
	companion.mend_in -= delta
	if companion.mend_in <= 0.0:
		companion.mend_in = MEND_SECONDS
		companion.health += 1


## A dog looks around: it barks at what comes near and, following or
## guarding, goes for the nearest within DEFEND_RANGE of its player or
## post (keeping on the one it goes for while within LEASH).
static func _watch(creatures: Creatures, dog: Companion, owner: GameServer.PlayerSession) -> void:
	var watched := _watched(dog)
	var barking := false
	var best: Creature = null
	var nearest := INF
	for creature: Creature in creatures.living.values():
		if not _threat(creature) or absf(creature.body.height - dog.body.height) > 6.0:
			continue
		var from_dog := creature.center().distance_to(dog.center()) / GameConst.TILE_SIZE
		if from_dog <= BARK_RANGE:
			barking = true
		if watched == Animal.NOWHERE:
			continue
		var from_watched := creature.center().distance_to(watched) / GameConst.TILE_SIZE
		if from_watched <= DEFEND_RANGE and from_dog < nearest:
			nearest = from_dog
			best = creature
	var current: Creature = creatures.living.get(dog.target_id)
	if current != null and watched != Animal.NOWHERE and _threat(current):
		if current.center().distance_to(watched) / GameConst.TILE_SIZE <= LEASH:
			best = current
	_aim(dog, best)
	if barking != dog.barking:
		dog.barking = barking
		dog.dirty = true
	if barking and owner != null and dog.told_in <= 0.0:
		dog.told_in = BARK_NOTICE
		_notice(owner, dog, "HUD_COMPANION_BARKS")
	if dog.drive_id < 0 and not dog.has_target():
		_pick_stray(creatures, dog)


## A cat looks around for a mole or a crow near its player or post.
static func _prowl(creatures: Creatures, cat: Companion) -> void:
	var watched := _watched(cat)
	if watched == Animal.NOWHERE:
		_aim(cat, null)
		return
	var best: Creature = null
	var nearest := INF
	for creature: Creature in creatures.living.values():
		if not _pest(creature):
			continue
		var from_watched := creature.center().distance_to(watched) / GameConst.TILE_SIZE
		var from_cat := creature.center().distance_to(cat.center()) / GameConst.TILE_SIZE
		if from_watched <= HUNT_RANGE and from_cat < nearest:
			nearest = from_cat
			best = creature
	var current: Creature = creatures.living.get(cat.target_id)
	if current != null and _pest(current):
		if current.center().distance_to(watched) / GameConst.TILE_SIZE <= LEASH:
			best = current
	_aim(cat, best)


## Where a companion keeps watch (world pixels): its player, following;
## its post, guarding; nowhere when it stays (or its player is away).
static func _watched(companion: Companion) -> Vector2:
	match companion.order:
		Companion.Order.FOLLOW:
			return companion.owner_at
		Companion.Order.GUARD:
			var post := companion.post if companion.post != Vector3.INF else companion.feet()
			return Vector2(post.x, post.z) * GameConst.TILE_SIZE
	return Animal.NOWHERE


## What a dog barks at and goes for: an awake monster, a predator on the
## hunt or angry.
static func _threat(creature: Creature) -> bool:
	if creature is Monster:
		return creature.state != Creature.State.DORMANT
	var predator := creature as Predator
	if predator == null or predator.state == Creature.State.FLEE:
		return false
	return predator.has_target() or predator.angry_at >= 0 or predator.state == Creature.State.ALERT


## What a cat hunts: a mole at work, a crow not flying off.
static func _pest(creature: Creature) -> bool:
	if creature is Mole:
		return not (creature as Mole).done
	if creature is Crow:
		return creature.state != Creature.State.FLEE and not (creature as Crow).gone
	return false


static func _aim(companion: Companion, creature: Creature) -> void:
	if creature == null:
		if companion.has_target():
			companion.forget()
			companion.dirty = true
		return
	companion.target_id = creature.id
	_keep_on(null, companion, creature)


## Where its target is now, and whether it can be bitten (a mole up, a
## crow landed); gone, it is forgotten.
static func _keep_on(creatures: Creatures, companion: Companion, known: Creature = null) -> void:
	if companion.target_id < 0:
		return
	var prey := known
	if prey == null and creatures != null:
		prey = creatures.living.get(companion.target_id)
	var fled := prey != null and prey.state == Creature.State.FLEE and not prey is Monster
	if prey == null or fled:
		companion.forget()
		companion.dirty = true
		return
	var at := prey.center() / GameConst.TILE_SIZE
	companion.target = Vector3(at.x, prey.body.height, at.y)
	companion.target_ready = true
	if prey is Mole:
		companion.target_ready = (prey as Mole).is_up()
	elif prey is Crow:
		companion.target_ready = prey.state == Creature.State.GRAZE


## A guarding dog picks the farm animal around its post that strayed the
## farthest (not one it gave up on just before).
static func _pick_stray(creatures: Creatures, dog: Companion) -> void:
	if dog.order != Companion.Order.GUARD or dog.post == Vector3.INF:
		return
	var post := Vector2(dog.post.x, dog.post.z)
	var farthest := KEEP
	var stray: Animal = null
	for creature: Creature in creatures.living.values():
		var animal := creature as Animal
		if animal == null or not FLOCK.has(animal.species) or animal.id == dog.gave_up:
			continue
		if animal.seated >= 0 or animal.leader >= 0 or animal.state == Creature.State.SLEEP:
			continue
		var away := (animal.center() / GameConst.TILE_SIZE).distance_to(post)
		if away > farthest and away <= HERD_RANGE:
			farthest = away
			stray = animal
	if stray != null:
		dog.drive_id = stray.id
		dog.driving = 0.0


## A guarding dog drives its stray back: it runs round behind it and
## pushes it on towards the post.
static func _herd(creatures: Creatures, dog: Companion, delta: float) -> void:
	if dog.drive_id < 0:
		return
	var stray := creatures.living.get(dog.drive_id) as Animal
	var post := Vector2(dog.post.x, dog.post.z)
	dog.driving += delta
	var done := (
		stray == null
		or dog.order != Companion.Order.GUARD
		or dog.post == Vector3.INF
		or stray.seated >= 0
		or stray.leader >= 0
	)
	if not done:
		var at := stray.center() / GameConst.TILE_SIZE
		done = at.distance_to(post) <= BACK_IN
		if dog.driving > DRIVE_SECONDS:
			dog.gave_up = stray.id
			done = true
	if done:
		dog.drive_id = -1
		dog.drive_at = Vector3.INF
		return
	var from := stray.center() / GameConst.TILE_SIZE
	var away := (from - post).normalized()
	var behind := from + away * BEHIND
	dog.drive_at = Vector3(behind.x, stray.body.height, behind.y)
	if dog.center().distance_to(stray.center()) / GameConst.TILE_SIZE <= PUSH_RANGE:
		var spot := Vector2i(post.floor()) + Vector2i(stray.id % 3 - 1, (stray.id / 3) % 3 - 1)
		stray.drive(spot, creatures.voxel_at)


## Puts a companion beside its player, on ground level with them (if any).
static func _bring(
	creatures: Creatures, companion: Companion, owner: GameServer.PlayerSession
) -> void:
	var tile := Coords.world_to_tile(owner.position)
	var tall: float = Species.TALL[companion.species]
	for ring in [1, 2]:
		for dz in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dz)) != ring:
					continue
				var spot := tile + Vector2i(dx, dz)
				var ground := Pathfinder.ground_at(spot, owner.height, creatures.voxel_at, tall)
				if is_nan(ground) or absf(ground - owner.height) > 1.5:
					continue
				var box: Vector2 = companion.body.box
				var feet := Coords.tile_to_world_center(spot) + Vector2(0.0, box.y * 0.5)
				companion.brought(feet, ground)
				return


static func _tame_wolf(
	server: GameServer, session: GameServer.PlayerSession, wolf: Predator, slot: int
) -> void:
	if wolf.angry_at == session.id or wolf.target_player == session.id:
		_notice(session, wolf, "HUD_WOLF_GROWLS")
		return
	_eat(server, session, slot)
	wolf.forget()
	wolf.hunger = server.clock.scale_duration(Wildlife.HUNGER_SECONDS)
	if server.creatures.rng.randf() >= TAME_CHANCE:
		_notice(session, wolf, "HUD_COMPANION_WARY")
		return
	var creatures := server.creatures
	var dog := creatures.add(Species.Id.DOG, wolf.body.feet, wolf.body.height) as Companion
	dog.heading = wolf.heading
	dog.coat = 0
	dog.tame(session.player_name)
	dog.owner_id = session.id
	_notice(session, wolf, "HUD_WOLF_TAMED")
	creatures.remove(server, wolf, false)


static func _tame(
	server: GameServer, session: GameServer.PlayerSession, companion: Companion, slot: int
) -> void:
	_eat(server, session, slot)
	if server.creatures.rng.randf() >= TAME_CHANCE:
		_notice(session, companion, "HUD_COMPANION_WARY")
		return
	companion.tame(session.player_name)
	companion.owner_id = session.id
	_notice(session, companion, "HUD_COMPANION_TAMED")


## Its player tells it the next order (and pets it, once a day).
static func _order(
	server: GameServer, session: GameServer.PlayerSession, companion: Companion
) -> void:
	var next := (companion.order + 1) % Companion.Order.size()
	companion.command(next as Companion.Order)
	var day := server.clock.day_index()
	if companion.petted_day != day:
		companion.petted_day = day
		companion.cared_day = day
		companion.affection = mini(companion.affection + 1, Husbandry.MAX_AFFECTION)
	var key := "HUD_COMPANION_FOLLOW"
	match companion.order:
		Companion.Order.STAY:
			key = "HUD_COMPANION_STAY"
		Companion.Order.GUARD:
			key = "HUD_DOG_GUARD" if companion.species == Species.Id.DOG else "HUD_CAT_GUARD"
	_notice(session, companion, key)


## What was in hand is eaten (not in creative).
static func _eat(server: GameServer, session: GameServer.PlayerSession, slot: int) -> void:
	if not GameModes.creative(server):
		session.inventory.take(slot, 1)


static func _notice(session: GameServer.PlayerSession, animal: Animal, key: String) -> void:
	session.transport.send(Msg.animal_notice(key, animal.species, animal.affection))


## Its player, joined and awake (null: not here).
static func _owner(server: GameServer, companion: Companion) -> GameServer.PlayerSession:
	if not companion.is_tame():
		return null
	for session in server.sessions:
		if session.joined and session.player_name == companion.owner_name and session.alive():
			return session
	return null


static func _fish() -> Array[int]:
	var fish: Array[int] = [Items.Id.RAW_FISH, Items.Id.COOKED_FISH]
	for raw: int in FishTable.SPECIES:
		fish.append(raw)
		if Smelting.FOOD.has(raw):
			fish.append(Smelting.FOOD[raw])
	return fish
