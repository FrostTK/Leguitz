class_name Wildlife
extends RefCounted
## The wild animals' lives on the server (static, given the server;
## Creatures.update calls `sense` before each one thinks, and `land_blow`
## when a predator strikes).
## Predators (Predator): angered by a blow, a wolf's pack turns on the
## player who struck it (the nearest to where the blow came from), a bear
## too, for ANGER_SECONDS; a bear warns a player who comes within
## WARN_RANGE (State.ALERT) and charges if they stay WARN_SECONDS; at night
## wolves go for a player within NIGHT_RANGE who is not in the light
## (Light.is_lit: torches, lanterns, fires keep them off); hungry, a
## predator goes for the nearest prey animal (Species.PREY) within
## HUNT_RANGE, its pack with it, for a while (Predator.CHASE_SECONDS: fences
## keep a herd safe), and once it has killed it is fed HUNGER_SECONDS
## (paced). No creative player nor spectator is ever a target.
## Turtles lay their eggs on sand every EGG_SECONDS (paced), not near other
## eggs; the eggs hatch (Growth calls `hatch`: TURTLE_EGGS, _1, _2, then
## young turtles). Beavers build a dam of sticks in the still water by the
## bank every DAM_SECONDS (paced), up to MOST_DAM blocks around.

## Players are told (HUD_ANIMAL_WILD) these do not take care.
const WILD := {Species.Id.WOLF: true, Species.Id.BEAR: true, Species.Id.FISH: true}
const HUNT_RANGE := 14.0
const HUNGER_SECONDS := 300.0
## Pack members within this far (tiles) hunt and fight together.
const PACK_RANGE := 12.0
const NIGHT_RANGE := 8.0
const ANGER_SECONDS := 30.0
## A target farther than this (tiles) is given up.
const GIVE_UP := 24.0
const WARN_RANGE := 5.0
const WARN_SECONDS := 2.5
## A blow pushes the player back this fast (tiles per second) and up.
const PUSH := Vector2(6.0, 4.0)
## A blow lands up to this much farther than Predator.REACH (the player
## moves while messages travel).
const REACH_LEEWAY := 0.6
const EGG_SECONDS := 900.0
const EGG_SPACING := 4
const EGGS: Array[int] = [
	Tiles.Block.TURTLE_EGGS, Tiles.Block.TURTLE_EGGS_1, Tiles.Block.TURTLE_EGGS_2
]
const HATCH_SECONDS := 300.0
const HATCHLINGS := Vector2i(1, 2)
const DAM_SECONDS := 300.0
const DAM_RANGE := 6
const MOST_DAM := 6


static func is_wild(kind: int) -> bool:
	return WILD.has(kind)


## Whether Wildlife minds an animal's life (predators, turtles, beavers).
static func minds(kind: int) -> bool:
	return Species.PREDATORS.has(kind) or kind == Species.Id.TURTLE or kind == Species.Id.BEAVER


## A wild animal's step, before it thinks (see the class).
static func sense(server: GameServer, creatures: Creatures, animal: Animal, delta: float) -> void:
	if animal is Predator:
		_sense_predator(server, creatures, animal as Predator, delta)
	elif animal.species == Species.Id.TURTLE:
		_turtle(server, animal, delta)
	elif animal.species == Species.Id.BEAVER:
		_beaver(server, animal, delta)


## A predator's blow landed: a player is hurt and pushed back, a prey
## animal hurt; killed, it is eaten and the predator fed.
static func land_blow(server: GameServer, creatures: Creatures, predator: Predator) -> void:
	predator.strike = false
	if predator.target_player >= 0:
		var session := _session(server, predator.target_player)
		if session == null or not Monsters.hunts(server, session):
			return
		var feet := session.position / GameConst.TILE_SIZE
		var chest := Vector3(feet.x, session.height + 0.9, feet.y)
		if predator.middle().distance_to(chest) > Predator.REACH + REACH_LEEWAY + 0.5:
			return
		var kind := predator.species
		Survival.hurt(server, session, Species.DAMAGE[kind], Species.CAUSE[kind])
		var away := session.position - predator.center()
		if away.length() < 0.01:
			away = predator.heading
		session.transport.send(Msg.push(away.normalized() * PUSH.x * GameConst.TILE_SIZE, PUSH.y))
		return
	var prey: Creature = creatures.living.get(predator.target_id)
	if prey == null or prey.bounds().get_center().distance_to(predator.middle()) > 2.0:
		return
	if not prey.hurt_by(predator.center(), Species.DAMAGE[predator.species]):
		return
	creatures.tell_seers(server, prey.id, Msg.entity_hurt(prey.id))
	if prey.health <= 0:
		# Eaten: nothing left.
		creatures.remove(server, prey, true)
		var eaters := _pack(creatures, predator)
		eaters.append(predator)
		for member: Predator in eaters:
			if member.target_id == prey.id:
				member.forget()
				member.hunger = server.clock.scale_duration(HUNGER_SECONDS)


## Turtle eggs hatch a stage at a time (`odds` of a stage now); the last
## stage gives young turtles.
static func hatch(server: GameServer, cell: Vector3i, block: int, odds: float) -> void:
	if server.rng.randf() >= odds:
		return
	var stage := EGGS.find(block)
	if stage < EGGS.size() - 1:
		server.change_voxel(cell, Voxels.of_block(EGGS[stage + 1]))
		return
	server.change_voxel(cell, Voxels.AIR)
	var box: Vector2 = Species.BOX[Species.Id.TURTLE]
	var feet := Coords.tile_to_world_center(Vector2i(cell.x, cell.z)) + Vector2(0.0, box.y * 0.5)
	for i in server.rng.randi_range(HATCHLINGS.x, HATCHLINGS.y):
		var young := (
			server.creatures.add(Species.Id.TURTLE, feet, cell.y - GameConst.SEA_LEVEL) as Animal
		)
		young.set_age(server.clock.scale_duration(Husbandry.GROW_SECONDS))


static func _sense_predator(
	server: GameServer, creatures: Creatures, predator: Predator, delta: float
) -> void:
	if predator.provoked != Vector2.INF:
		var striker := _nearest_player(server, predator.provoked, GIVE_UP)
		predator.provoked = Vector2.INF
		if striker != null:
			var pack := _pack(creatures, predator) if predator.species == Species.Id.WOLF else []
			pack.append(predator)
			for member: Predator in pack:
				member.angry_at = striker.id
				member.anger = ANGER_SECONDS
	predator.anger = maxf(predator.anger - delta, 0.0)
	if predator.anger <= 0.0:
		predator.angry_at = -1
	var angry := _session(server, predator.angry_at)
	if angry != null and _hunted(server, predator, angry):
		_go_for_player(predator, angry)
		return
	if predator.species == Species.Id.BEAR:
		if _warn(server, predator, delta):
			return
	elif server.clock.is_night():
		var prowled := _nearest_player(server, predator.center(), NIGHT_RANGE)
		if prowled != null and _hunted(server, predator, prowled):
			var tile := Coords.world_to_tile(prowled.position)
			var row := floori(prowled.height + 0.01) + GameConst.SEA_LEVEL
			if not Light.is_lit(creatures.world, Vector3i(tile.x, row, tile.y), server.clock):
				_go_for_player(predator, prowled)
				return
	if predator.target_player >= 0:
		predator.forget()
	_hunt_prey(server, creatures, predator, delta)


## A bear and a player too close: it warns them, and charges if they stay.
## False when nobody is near.
static func _warn(server: GameServer, bear: Predator, delta: float) -> bool:
	var near := _nearest_player(server, bear.center(), WARN_RANGE)
	if near == null or not _hunted(server, bear, near):
		bear.warned = maxf(bear.warned - delta, 0.0)
		bear.calm()
		if bear.target_player >= 0:
			bear.forget()
		return false
	bear.warned += delta
	if bear.warned >= WARN_SECONDS:
		bear.angry_at = near.id
		bear.anger = ANGER_SECONDS
		bear.warned = 0.0
		_go_for_player(bear, near)
	else:
		bear.warn(near.position - bear.center())
	return true


## A hungry predator goes for the nearest prey (its pack's, if one of them
## has one), for a while.
static func _hunt_prey(
	server: GameServer, creatures: Creatures, predator: Predator, delta: float
) -> void:
	var prey: Creature = creatures.living.get(predator.target_id)
	if prey != null:
		predator.chased += delta
		var gone := prey.center().distance_to(predator.center()) / GameConst.TILE_SIZE > GIVE_UP
		if predator.chased > Predator.CHASE_SECONDS or gone:
			predator.forget()
			predator.hunger = server.clock.scale_duration(HUNGER_SECONDS) * 0.25
			return
		var feet := prey.center() / GameConst.TILE_SIZE
		predator.target = Vector3(feet.x, prey.body.height, feet.y)
		return
	predator.forget()
	if predator.hunger > 0.0:
		return
	for member in _pack(creatures, predator):
		if member.target_id >= 0 and creatures.living.has(member.target_id):
			predator.target_id = member.target_id
			return
	var nearest := HUNT_RANGE * GameConst.TILE_SIZE
	for creature: Creature in creatures.living.values():
		if not Species.PREY.has(creature.species):
			continue
		var distance := creature.center().distance_to(predator.center())
		if distance < nearest:
			nearest = distance
			predator.target_id = creature.id


static func _go_for_player(predator: Predator, session: GameServer.PlayerSession) -> void:
	var feet := session.position / GameConst.TILE_SIZE
	predator.target = Vector3(feet.x, session.height, feet.y)
	predator.target_player = session.id
	predator.target_id = -1


## Whether a predator may go for a player: hunted (awake, not creative nor
## a spectator) and not too far nor too high.
static func _hunted(
	server: GameServer, predator: Predator, session: GameServer.PlayerSession
) -> bool:
	if not Monsters.hunts(server, session):
		return false
	var distance := session.position.distance_to(predator.center()) / GameConst.TILE_SIZE
	return distance <= GIVE_UP and absf(session.height - predator.body.height) <= 6.0


## A grown turtle on sand lays its eggs now and then.
static func _turtle(server: GameServer, turtle: Animal, delta: float) -> void:
	if turtle.is_baby() or not turtle.body.on_ground:
		return
	if turtle.chore_in <= 0.0:
		turtle.chore_in = (
			server.clock.scale_duration(EGG_SECONDS) * server.rng.randf_range(0.7, 1.3)
		)
		return
	turtle.chore_in -= delta
	if turtle.chore_in > 0.0:
		return
	var world := server.world
	var tile := turtle.tile()
	var cell := Vector3i(tile.x, floori(turtle.body.height + 0.01) + GameConst.SEA_LEVEL, tile.y)
	if world.loaded_voxel_at(cell + Vector3i.DOWN) != Voxels.of_ground(Tiles.Ground.SAND):
		return
	if world.loaded_voxel_at(cell) != Voxels.AIR:
		return
	for dz in range(-EGG_SPACING, EGG_SPACING + 1):
		for dx in range(-EGG_SPACING, EGG_SPACING + 1):
			for dy in range(-1, 2):
				var other := Voxels.block_of(world.loaded_voxel_at(cell + Vector3i(dx, dy, dz)))
				if other in EGGS:
					return
	server.change_voxel(cell, Voxels.of_block(Tiles.Block.TURTLE_EGGS))


## A grown beaver builds a block of its dam in the still water by the bank
## now and then.
static func _beaver(server: GameServer, beaver: Animal, delta: float) -> void:
	if beaver.is_baby():
		return
	if beaver.chore_in <= 0.0:
		beaver.chore_in = (
			server.clock.scale_duration(DAM_SECONDS) * server.rng.randf_range(0.7, 1.3)
		)
		return
	beaver.chore_in -= delta
	if beaver.chore_in > 0.0:
		return
	var cell := dam_spot(server.world, beaver.tile(), beaver.body.height)
	if cell != Vector3i.MAX:
		server.change_voxel(cell, Voxels.of_block(Tiles.Block.BEAVER_DAM))


## Where a beaver near `tile` (at `height`, levels) builds next: a still
## water cell open to the air beside the bank or the dam, MOST_DAM blocks
## of dam within DAM_RANGE at most (MAX: nowhere).
static func dam_spot(world: WorldState, tile: Vector2i, height: float) -> Vector3i:
	var row := floori(height + 0.01) + GameConst.SEA_LEVEL
	var dams := 0
	for dz in range(-DAM_RANGE, DAM_RANGE + 1):
		for dx in range(-DAM_RANGE, DAM_RANGE + 1):
			for dy in range(-2, 2):
				var at := Vector3i(tile.x + dx, row + dy, tile.y + dz)
				if world.loaded_voxel_at(at) == Voxels.of_block(Tiles.Block.BEAVER_DAM):
					dams += 1
	if dams >= MOST_DAM:
		return Vector3i.MAX
	var still := Voxels.of_ground(Tiles.Ground.WATER)
	for radius in range(1, 3):
		for dz in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				for dy in [0, -1]:
					var cell := Vector3i(tile.x + dx, row + dy, tile.y + dz)
					if world.loaded_voxel_at(cell) != still:
						continue
					if world.loaded_voxel_at(cell + Vector3i.UP) != Voxels.AIR:
						continue
					for side: Vector3i in [
						Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK
					]:
						var by := world.loaded_voxel_at(cell + side)
						if Voxels.is_cube(by) or by == Voxels.of_block(Tiles.Block.BEAVER_DAM):
							return cell
	return Vector3i.MAX


## The other wolves of a predator's pack (same kind, within PACK_RANGE).
static func _pack(creatures: Creatures, predator: Predator) -> Array:
	var pack := []
	var reach := PACK_RANGE * GameConst.TILE_SIZE
	for creature: Creature in creatures.living.values():
		if creature == predator or not creature is Predator:
			continue
		if creature.species == predator.species:
			if creature.center().distance_to(predator.center()) <= reach:
				pack.append(creature)
	return pack


static func _session(server: GameServer, id: int) -> GameServer.PlayerSession:
	if id < 0:
		return null
	for session in server.sessions:
		if session.id == id and session.joined:
			return session
	return null


## The joined player nearest a spot (world pixels) within `range` tiles.
static func _nearest_player(
	server: GameServer, from: Vector2, within: float
) -> GameServer.PlayerSession:
	var best: GameServer.PlayerSession = null
	var nearest := within * GameConst.TILE_SIZE
	for session in server.sessions:
		if not session.joined or not session.alive():
			continue
		var distance := session.position.distance_to(from)
		if distance <= nearest:
			nearest = distance
			best = session
	return best
