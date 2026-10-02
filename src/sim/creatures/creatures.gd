class_name Creatures
extends RefCounted
## The animals of a world, run by the server. A chunk gets its herd (or
## none) the first time it loads, the same for a seed: a chance in
## HERD_CHANCE, a species of its biome (Species.BIOMES), on free ground;
## never in a chunk players built in. Animals live (think, move) within
## ACTIVE_RADIUS chunks of a player, every other tick (half of them each
## tick), and sleep elsewhere; they are saved
## with the world (WorldStorage creatures file). Each player is shown the
## animals of the chunks it has: Msg.ENTITY_SPAWN, then ENTITY_MOVE every
## SYNC_TICKS while they move, ENTITY_REMOVE when they leave its view or
## die. Players hit them (Msg.ATTACK, Combat): hurt, they run away with
## their herd; dead, they leave what they give. Never holds the server
## (the calls needing it are given it).

const SALT := 0x5A11E7
const HERD_CHANCE := 0.3
## Tries per animal to find a free spot in its chunk.
const SPOT_TRIES := 6
const ACTIVE_RADIUS := 3
const SYNC_TICKS := 2
## New chunks get their herd this often (ticks).
const POPULATE_TICKS := 10
## One of a herd hurt, the others within this many tiles run away too.
const HERD_PANIC := 6.0

var world: WorldState
var animals: Dictionary[int, Animal] = {}
## The chunks whose herd was placed (with or without animals).
var populated: Dictionary[Vector2i, bool] = {}
var rng := RandomNumberGenerator.new()

var _seed := 0
var _next_id := 1
var _ticks := 0


func _init(world_state: WorldState, world_seed: int) -> void:
	world = world_state
	_seed = HashUtil.derive_seed(world_seed, SALT)
	rng.randomize()


## A voxel where its chunk is loaded, else Voxels.UNKNOWN (never makes a
## chunk: animals stop at the edge of the loaded world).
func voxel_at(cell: Vector3i) -> int:
	return world.loaded_voxel_at(cell)


## A new animal standing with its feet at `feet` (world pixels, see
## Animal) and `height` (levels).
func add(kind: int, feet: Vector2, height: float) -> Animal:
	var animal := Animal.create(kind, feet, height)
	animal.id = _next_id
	_next_id += 1
	animals[animal.id] = animal
	return animal


## Puts `count` animals of a kind where they can stand around a spot
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


## One tick: new chunks get their herd, the animals near players live.
func update(delta: float, sessions: Array) -> void:
	_ticks += 1
	if _ticks % POPULATE_TICKS == 1:
		_populate_new()
	var active := _active_chunks(sessions)
	if active.is_empty():
		return
	var at := voxel_at
	var half := _ticks % 2
	for animal: Animal in animals.values():
		if animal.id % 2 == half and active.has(Coords.tile_to_chunk(animal.tile())):
			animal.think(delta * 2.0, at, rng)
			animal.move(delta * 2.0, at)


## Shows each player the animals of the chunks it has (see the class).
func sync(sessions: Array) -> void:
	if _ticks % SYNC_TICKS != 0:
		return
	for session: GameServer.PlayerSession in sessions:
		if not session.joined:
			continue
		var seen := session.seen_animals
		for id: int in seen.keys():
			var gone: Animal = animals.get(id)
			if gone == null or not session.sent_chunks.has(_chunk_of(gone)):
				seen.erase(id)
				session.transport.send(Msg.entity_remove(id, false))
		for animal: Animal in animals.values():
			if not session.sent_chunks.has(_chunk_of(animal)):
				continue
			if not seen.has(animal.id):
				seen[animal.id] = true
				session.transport.send(Msg.entity_spawn(animal))
			elif animal.dirty:
				session.transport.send(Msg.entity_move(animal))
	for animal: Animal in animals.values():
		animal.dirty = false


## A player hits the animal `id` with the hotbar slot `slot` in hand
## (Msg.ATTACK): within Combat.REACH of their eye, not sooner than
## Combat.BLOW_SECONDS after their last blow. It is hurt and runs away
## with its herd; a tool in hand wears (not in creative); dead, it leaves
## what it gives where it fell.
func attack(server: GameServer, session: GameServer.PlayerSession, id: int, slot: int) -> void:
	var animal: Animal = animals.get(id)
	if animal == null or not session.joined or not session.alive():
		return
	var now := server.tick_count * GameConst.TICK_DELTA
	if now - session.last_blow < Combat.BLOW_SECONDS - Combat.BLOW_LEEWAY:
		return
	var feet := session.position / GameConst.TILE_SIZE
	var eye := Vector3(feet.x, session.height + Mining.EYE_HEIGHT, feet.y)
	var bounds := animal.bounds()
	if eye.distance_to(eye.clamp(bounds.position, bounds.end)) > Combat.REACH + Combat.REACH_LEEWAY:
		return
	session.last_blow = now
	var bag := session.inventory
	var held := bag.items[slot] if slot >= 0 and slot < Inventory.HOTBAR else Items.Id.NONE
	if not animal.hurt_by(session.position, Combat.damage_of(held)):
		return
	for other in server.sessions:
		if other.seen_animals.has(id):
			other.transport.send(Msg.entity_hurt(id))
	if Items.durability(held) > 0 and not GameModes.creative(server):
		bag.wear_out(slot)
		session.transport.send(Msg.inventory(bag))
	Survival.spend(server, session, Vitals.BREAK_EFFORT)
	var reach := HERD_PANIC * GameConst.TILE_SIZE
	for other: Animal in animals.values():
		if other != animal and other.species == animal.species:
			if other.center().distance_to(animal.center()) <= reach:
				other.scare(session.position)
	if animal.health <= 0:
		_die(server, animal)


## Everything to save: the animals and the chunks already given theirs.
func to_save() -> Dictionary:
	var list: Array[Dictionary] = []
	for animal: Animal in animals.values():
		list.append(animal.to_dict())
	var done := PackedInt32Array()
	for coord: Vector2i in populated:
		done.append(coord.x)
		done.append(coord.y)
	return {"animals": list, "populated": done}


func load_save(data: Dictionary) -> void:
	for entry: Dictionary in data.get("animals", []):
		var animal := Animal.from_dict(entry)
		if animal != null:
			animal.id = _next_id
			_next_id += 1
			animals[animal.id] = animal
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
	for i in count * SPOT_TRIES:
		if placed >= count:
			break
		var spot := HashUtil.hash2(_seed + 7919 * (i + 1), coord.x, coord.y)
		var local := Vector2i(spot & 15, (spot >> 4) & 15)
		var row := chunk.top_row(local)
		if not _free_spot(chunk, local, row, Species.TALL[kind]):
			continue
		var tile := coord * GameConst.CHUNK_SIZE + local
		var box: Vector2 = Species.BOX[kind]
		var feet := Coords.tile_to_world_center(tile) + Vector2(0.0, box.y * 0.5)
		add(kind, feet, float(row - GameConst.SEA_LEVEL))
		placed += 1


## Whether an animal `tall` levels high can stand on a column's ground:
## a natural ground (not water, not what players build) with room above.
static func _free_spot(chunk: ChunkData, local: Vector2i, row: int, tall: float) -> bool:
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


static func _chunk_of(animal: Animal) -> Vector2i:
	return Coords.tile_to_chunk(animal.tile())


## An animal died: what it gives falls where it was; its players see it
## go.
func _die(server: GameServer, animal: Animal) -> void:
	animals.erase(animal.id)
	var bounds := animal.bounds()
	var middle := bounds.get_center()
	for drop: Array in Species.DROPS[animal.species]:
		var count := rng.randi_range(drop[1], drop[2])
		if count > 0:
			var speed := Vector3(rng.randf_range(-1.0, 1.0), 3.0, rng.randf_range(-1.0, 1.0))
			server.spawn_item(drop[0], count, middle, speed)
	for session in server.sessions:
		if session.seen_animals.erase(animal.id):
			session.transport.send(Msg.entity_remove(animal.id, true))
