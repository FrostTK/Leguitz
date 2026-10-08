class_name Creatures
extends RefCounted
## The creatures of a world, run by the server: animals and monsters.
## A chunk gets its herd of animals (or none) the first time it loads, the
## same for a seed: a chance in HERD_CHANCE, a species of its biome
## (Species.BIOMES), on free ground; never in a chunk players built in.
## Monsters come out in the dark around players and go when far or in
## daylight (Monsters). Creatures live (think, move) within ACTIVE_RADIUS
## chunks of a player, every other tick (half of them each tick), and sleep
## elsewhere; animals are saved with the world (WorldStorage creatures
## file), monsters are not. Each player is shown the creatures of the
## chunks it has: Msg.ENTITY_SPAWN, then ENTITY_MOVE every SYNC_TICKS
## while they move, ENTITY_REMOVE when they leave its view or die. Players
## hit them (Msg.ATTACK, Combat): hurt, animals run away with their herd;
## dead, creatures leave what they give. Farm life (feeding, young ones,
## leads, wool, milk, eggs, love, sleep): Husbandry. Wild ones (predators'
## hunts, turtles' eggs, beavers' dams): Wildlife; fish are born in the
## water of their chunk. What comes to fields (moles, crows, lantern
## bumblebees): Pests. Never holds the server (the calls needing it are
## given it).

const SALT := 0x5A11E7
const HERD_CHANCE := 0.3
## Tries per animal to find a free spot in its chunk.
const SPOT_TRIES := 6
const ACTIVE_RADIUS := 3
const SYNC_TICKS := 2
## New chunks get their herd this often (ticks); monsters come and go this
## often.
const POPULATE_TICKS := 10
const MONSTER_TICKS := 20
## One of a herd hurt, the others within this many tiles run away too.
const HERD_PANIC := 6.0

var world: WorldState
## Every creature, by id.
var living: Dictionary[int, Creature] = {}
## The chunks whose herd was placed (with or without animals).
var populated: Dictionary[Vector2i, bool] = {}
var rng := RandomNumberGenerator.new()
## The day (WorldClock.day_index) farm life last saw (Husbandry.update).
var day := -1

var _seed := 0
var _next_id := 1
var _ticks := 0


func _init(world_state: WorldState, world_seed: int) -> void:
	world = world_state
	_seed = HashUtil.derive_seed(world_seed, SALT)
	rng.randomize()


## A new creature of `kind` (an Animal or a Monster).
static func make(kind: int, feet: Vector2, height: float) -> Creature:
	if Species.is_monster(kind):
		return Monster.create(kind, feet, height)
	if kind == Species.Id.BEE or kind == Species.Id.LANTERN_BUMBLEBEE:
		return Bee.create(kind, feet, height)
	if Species.PREDATORS.has(kind):
		return Predator.create(kind, feet, height)
	if Species.AQUATIC.has(kind):
		return Fish.create(kind, feet, height)
	if kind == Species.Id.MOLE:
		return Mole.create(kind, feet, height)
	if kind == Species.Id.CROW:
		return Crow.create(kind, feet, height)
	return Animal.create(kind, feet, height)


## A creature saved by Creature.to_dict (null if its kind is unknown, or
## it was saved lost: nowhere, a step once divided by zero).
static func from_dict(data: Dictionary) -> Creature:
	var kind := int(data.get("species", -1))
	var feet: Vector2 = data.get("feet", Vector2.ZERO)
	if not Species.is_valid(kind) or not feet.is_finite():
		return null
	if not is_finite(float(data.get("height", 0.0))):
		return null
	var creature := make(kind, data.get("feet", Vector2.ZERO), float(data.get("height", 0.0)))
	creature.load_dict(data)
	return creature


## A voxel where its chunk is loaded, else Voxels.UNKNOWN (never makes a
## chunk: creatures stop at the edge of the loaded world).
func voxel_at(cell: Vector3i) -> int:
	return world.loaded_voxel_at(cell)


## A new creature standing with its feet at `feet` (world pixels, see
## Creature) and `height` (levels).
func add(kind: int, feet: Vector2, height: float) -> Creature:
	return adopt(make(kind, feet, height))


## Lets a creature live in the world (gives it its id).
func adopt(creature: Creature) -> Creature:
	creature.id = _next_id
	_next_id += 1
	living[creature.id] = creature
	return creature


## Puts `count` creatures of a kind where they can stand around a spot
## (feet in world pixels, height in levels; developer option, tests).
func spawn_near(kind: int, feet: Vector2, height: float, count: int) -> void:
	var around := Coords.world_to_tile(feet)
	var box: Vector2 = Species.BOX[kind]
	var placed := 0
	for i in count * 16:
		if placed >= count:
			break
		var tile := around + Vector2i(rng.randi_range(-4, 4), rng.randi_range(-4, 4))
		if tile.distance_to(around) < 2.0:
			continue
		var ground := Pathfinder.ground_at(tile, height, voxel_at, Species.TALL[kind])
		if not is_nan(ground):
			add(kind, Coords.tile_to_world_center(tile) + Vector2(0.0, box.y * 0.5), ground)
			placed += 1


## One tick: new chunks get their herd, monsters come and go, the
## creatures near players live (monsters hunt and strike).
func update(server: GameServer, delta: float) -> void:
	_ticks += 1
	var sessions := server.sessions
	if _ticks % POPULATE_TICKS == 1:
		_populate_new()
	if _ticks % MONSTER_TICKS == 0:
		Monsters.come_and_go(server, self)
	if _ticks % Pests.PEST_TICKS == 7:
		Pests.come_and_go(server, self)
	Husbandry.update(server, self)
	var active := _active_chunks(sessions)
	if active.is_empty():
		return
	var at := voxel_at
	var half := _ticks % 2
	for creature: Creature in living.values():
		if creature.id % 2 != half or not active.has(Coords.tile_to_chunk(creature.tile())):
			continue
		var monster := creature as Monster
		if monster != null:
			Monsters.sense(server, self, monster, delta * 2.0)
		elif creature is Animal:
			Husbandry.sense(server, self, creature as Animal, delta * 2.0)
			if Wildlife.minds(creature.species):
				Wildlife.sense(server, self, creature as Animal, delta * 2.0)
		elif creature.species == Species.Id.BEE:
			Apiary.sense(server, self, creature as Bee)
		else:
			Pests.sense(server, self, creature)
		if not living.has(creature.id):
			continue
		creature.think(delta * 2.0, at, rng)
		creature.move(delta * 2.0, at)
		if monster != null and monster.strike:
			Monsters.land_blow(server, monster)
		elif creature is Predator and (creature as Predator).strike:
			Wildlife.land_blow(server, self, creature as Predator)


## Shows each player the creatures of the chunks it has (see the class).
func sync(sessions: Array) -> void:
	if _ticks % SYNC_TICKS != 0:
		return
	for session: GameServer.PlayerSession in sessions:
		if not session.joined:
			continue
		var seen := session.seen_creatures
		for id: int in seen.keys():
			var gone: Creature = living.get(id)
			if gone == null or not session.sent_chunks.has(_chunk_of(gone)):
				seen.erase(id)
				session.transport.send(Msg.entity_remove(id, false))
		for creature: Creature in living.values():
			if not session.sent_chunks.has(_chunk_of(creature)):
				continue
			if not seen.has(creature.id):
				seen[creature.id] = true
				session.transport.send(Msg.entity_spawn(creature))
			elif creature.dirty:
				session.transport.send(Msg.entity_move(creature))
	for creature: Creature in living.values():
		creature.dirty = false


## A player hits the creature `id` with the hotbar slot `slot` in hand
## (Msg.ATTACK): within Combat.REACH of their eye, not sooner than
## Combat.BLOW_SECONDS after their last blow. It is hurt (an animal runs
## away with its herd); a tool in hand wears (not in creative); dead, it
## leaves what it gives where it fell.
func attack(server: GameServer, session: GameServer.PlayerSession, id: int, slot: int) -> void:
	var target: Creature = living.get(id)
	if target == null or not session.joined or not session.alive():
		return
	var now := server.tick_count * GameConst.TICK_DELTA
	if now - session.last_blow < Combat.BLOW_SECONDS - Combat.BLOW_LEEWAY:
		return
	var feet := session.position / GameConst.TILE_SIZE
	var eye := Vector3(feet.x, session.height + Mining.EYE_HEIGHT, feet.y)
	var bounds := target.bounds()
	if eye.distance_to(eye.clamp(bounds.position, bounds.end)) > Combat.REACH + Combat.REACH_LEEWAY:
		return
	session.last_blow = now
	var bag := session.inventory
	var held := bag.items[slot] if slot >= 0 and slot < Inventory.HOTBAR else Items.Id.NONE
	if not target.hurt_by(session.position, Combat.damage_of(held)):
		return
	tell_seers(server, id, Msg.entity_hurt(id))
	if Items.durability(held) > 0 and not GameModes.creative(server):
		bag.wear_out(slot)
		session.transport.send(Msg.inventory(bag))
	Survival.spend(server, session, Vitals.BREAK_EFFORT)
	if target is Animal and not (target is Predator):
		var reach := HERD_PANIC * GameConst.TILE_SIZE
		for other: Creature in living.values():
			if other is Animal and other != target and other.species == target.species:
				if other.center().distance_to(target.center()) <= reach:
					(other as Animal).scare(session.position)
	if target.health <= 0:
		die(server, target)


## Sends a message to every player shown creature `id`.
func tell_seers(server: GameServer, id: int, message: Dictionary) -> void:
	for session in server.sessions:
		if session.seen_creatures.has(id):
			session.transport.send(message)


## Takes a creature out of the world: its players see it go (`died`: it
## tips over and fades).
func remove(server: GameServer, creature: Creature, died: bool) -> void:
	living.erase(creature.id)
	for session in server.sessions:
		if session.seen_creatures.erase(creature.id):
			session.transport.send(Msg.entity_remove(creature.id, died))


## Everything to save: the animals and the chunks already given theirs.
func to_save() -> Dictionary:
	var list: Array[Dictionary] = []
	for creature: Creature in living.values():
		if creature is Animal:
			list.append(creature.to_dict())
	var done := PackedInt32Array()
	for coord: Vector2i in populated:
		done.append(coord.x)
		done.append(coord.y)
	return {"animals": list, "populated": done}


func load_save(data: Dictionary) -> void:
	for entry: Dictionary in data.get("animals", []):
		var creature := from_dict(entry)
		if creature is Animal:
			adopt(creature)
	var done: PackedInt32Array = data.get("populated", PackedInt32Array())
	for i in range(0, done.size() - 1, 2):
		populated[Vector2i(done[i], done[i + 1])] = true


## Places a chunk's herd, if it has one (see the class).
func populate(chunk: ChunkData) -> void:
	if chunk.modified:
		return
	var coord := chunk.coord
	var h := HashUtil.hash2(_seed, coord.x, coord.y)
	if float(h & 0xFFFF) / 65536.0 >= HERD_CHANCE:
		return
	var middle := Vector2i(GameConst.CHUNK_SIZE / 2, GameConst.CHUNK_SIZE / 2)
	var kinds := Species.living_in(chunk.get_biome(middle))
	if kinds.is_empty():
		return
	var kind: int = kinds[(h >> 16) % kinds.size()]
	var herd: Vector2i = Species.HERD[kind]
	var count := herd.x + (h >> 20) % (herd.y - herd.x + 1)
	var placed := 0
	var aquatic := Species.AQUATIC.has(kind)
	for i in count * SPOT_TRIES:
		if placed >= count:
			break
		var spot := HashUtil.hash2(_seed + 7919 * (i + 1), coord.x, coord.y)
		var local := Vector2i(spot & 15, (spot >> 4) & 15)
		var row := chunk.top_row(local)
		if aquatic:
			# Fish: in the water, a row under its top.
			row = water_spot(chunk, local)
			if row < 0:
				continue
		elif not free_spot(chunk, local, row, Species.TALL[kind]):
			continue
		var tile := coord * GameConst.CHUNK_SIZE + local
		var box: Vector2 = Species.BOX[kind]
		var feet := Coords.tile_to_world_center(tile) + Vector2(0.0, box.y * 0.5)
		add(kind, feet, float(row - GameConst.SEA_LEVEL))
		placed += 1


## Whether a creature `tall` levels high can stand on a column's ground:
## a natural ground (not water, not what players build) with room above.
static func free_spot(chunk: ChunkData, local: Vector2i, row: int, tall: float) -> bool:
	if row < 1 or row + ceili(tall) >= GameConst.WORLD_HEIGHT:
		return false
	var ground := chunk.get_voxel(Vector3i(local.x, row - 1, local.y))
	if not Voxels.is_cube(ground) or Voxels.ground_of(ground) == Tiles.Ground.NONE:
		return false
	for y in range(row, row + ceili(tall)):
		var voxel := chunk.get_voxel(Vector3i(local.x, y, local.y))
		if Voxels.is_solid(voxel) or Voxels.is_liquid(voxel):
			return false
	return true


## The row a fish is born in, in a column of water at least two deep (-1:
## not one).
static func water_spot(chunk: ChunkData, local: Vector2i) -> int:
	var top := chunk.top_row(local)
	for row in range(top, maxi(top - 4, 1), -1):
		var voxel := chunk.get_voxel(Vector3i(local.x, row, local.y))
		var under := chunk.get_voxel(Vector3i(local.x, row - 1, local.y))
		if Voxels.is_water(voxel) and Voxels.is_water(under):
			return row - 1
	return -1


func _populate_new() -> void:
	for coord: Vector2i in world.chunks:
		if not populated.has(coord):
			populated[coord] = true
			populate(world.chunks[coord])


## The chunks within ACTIVE_RADIUS of a player (loaded ones).
func _active_chunks(sessions: Array) -> Dictionary:
	var active := {}
	for session: GameServer.PlayerSession in sessions:
		if not session.joined:
			continue
		var center := Coords.world_to_chunk(session.position)
		for dy in range(-ACTIVE_RADIUS, ACTIVE_RADIUS + 1):
			for dx in range(-ACTIVE_RADIUS, ACTIVE_RADIUS + 1):
				var coord := center + Vector2i(dx, dy)
				if world.has_chunk(coord):
					active[coord] = true
	return active


static func _chunk_of(creature: Creature) -> Vector2i:
	return Coords.tile_to_chunk(creature.tile())


## A creature died (a blow, an arrow): what it gives falls where it was;
## its players see it go.
func die(server: GameServer, creature: Creature) -> void:
	var middle := creature.bounds().get_center()
	var drops: Array = Species.DROPS[creature.species].duplicate()
	if creature.led_by() >= 0:
		drops.append([Items.Id.LEAD, 1, 1])
	for drop: Array in drops:
		var count := rng.randi_range(drop[1], drop[2])
		if count > 0:
			var speed := Vector3(rng.randf_range(-1.0, 1.0), 3.0, rng.randf_range(-1.0, 1.0))
			server.spawn_item(drop[0], count, middle, speed)
	remove(server, creature, true)
