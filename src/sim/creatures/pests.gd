class_name Pests
extends RefCounted
## What comes to players' fields, on the server (static, given the server;
## Creatures runs `come_and_go` every PEST_TICKS and `sense` before each
## one thinks). Around a player monsters may hunt (Monsters.hunts: never in
## creative), with MIN_CROPS crops or more within FIELD_CHUNKS chunks:
## a mole (Mole) now and then comes up under the field, gnaws crops from
## below and leaves molehills; by day crows (Crow) fly in to the young crops
## (sown or a stage on) and peck them up, unless a scarecrow stands within
## SCARE_RANGE (they also fly off from a player within CROW_FLEE, at
## night, or hit). At night lantern bumblebees (Bee, a lantern bumblebee)
## come out among the flowers and crops around the player and, while
## there, crops within GLOW_RANGE keep growing in the dark (Growth asks
## `lit_by`); they fly home and go at dawn. Never saved.

const PEST_TICKS := 100
const FIELD_CHUNKS := 2
const MIN_CROPS := 6
## Chances every PEST_TICKS, around a player with a field.
const MOLE_CHANCE := 0.02
const CROW_CHANCE := 0.06
const BUMBLEBEE_CHANCE := 0.35
const MAX_CROWS := 3
const MAX_BUMBLEBEES := 4
## Crows: where they come from (tiles away, levels up), what scares them.
const CROW_FROM := Vector2(18.0, 6.0)
const SCARE_RANGE := 8
const CROW_FLEE := 5.0
## Bumblebees: how far around a player they come out (tiles), how far
## their glow keeps crops growing.
const BUMBLEBEE_RANGE := 14
const GLOW_RANGE := 6.0
## Pests farther than this from every player go.
const GONE := 64.0


## Pests that are done go; new ones may come (see the class).
static func come_and_go(server: GameServer, creatures: Creatures) -> void:
	for creature: Creature in creatures.living.values():
		if not Species.PESTS.has(creature.species):
			continue
		var nearest := INF
		for session in server.sessions:
			if session.joined:
				nearest = minf(nearest, session.position.distance_to(creature.center()))
		if nearest / GameConst.TILE_SIZE > GONE:
			creatures.remove(server, creature, false)
	for session in server.sessions:
		if Monsters.hunts(server, session):
			_come(server, creatures, session)


## A pest's step before it thinks: a crow is scared off or takes its
## seedling, a mole takes its crop, a bumblebee rests by day; done, it goes.
static func sense(server: GameServer, creatures: Creatures, pest: Creature) -> void:
	if pest is Crow:
		_crow(server, creatures, pest as Crow)
	elif pest is Mole:
		var mole := pest as Mole
		if mole.bite:
			mole.bite = false
			var cell := mole.target
			if Farming.is_crop(Voxels.block_of(server.world.loaded_voxel_at(cell))):
				server.change_voxel(cell, Voxels.of_block(Tiles.Block.MOLEHILL))
		if mole.done:
			creatures.remove(server, mole, false)
	elif pest is Bee:
		var bee := pest as Bee
		bee.night = not server.clock.is_night()
		if bee.night and bee.is_home():
			creatures.remove(server, bee, false)


## Whether a lantern bumblebee glows near a cell (`glows`: theirs, the
## middles, Growth gathers them with `glowing`).
static func lit_by(glows: Array[Vector3], cell: Vector3i) -> bool:
	var at := Vector3(cell.x + 0.5, cell.y - GameConst.SEA_LEVEL + 0.5, cell.z + 0.5)
	for glow in glows:
		if glow.distance_to(at) <= GLOW_RANGE:
			return true
	return false


## The lantern bumblebees out now (their middles, local units).
static func glowing(creatures: Creatures) -> Array[Vector3]:
	var glows: Array[Vector3] = []
	for creature: Creature in creatures.living.values():
		if creature.species == Species.Id.LANTERN_BUMBLEBEE:
			glows.append(creature.bounds().get_center())
	return glows


## Whether a scarecrow stands within SCARE_RANGE of a cell.
static func scared(world: WorldState, cell: Vector3i) -> bool:
	var reach := Vector3i(SCARE_RANGE, 2, SCARE_RANGE)
	return not scarecrows(world, cell - reach, cell + reach).is_empty()


## The scarecrows in a box of cells (read straight from the loaded chunks).
static func scarecrows(world: WorldState, low: Vector3i, high: Vector3i) -> Array[Vector3i]:
	var found: Array[Vector3i] = []
	var scarecrow := Voxels.of_block(Tiles.Block.SCARECROW)
	var size := GameConst.CHUNK_SIZE
	var height := GameConst.WORLD_HEIGHT
	var bottom := maxi(low.y, 0)
	var top := mini(high.y, height - 1)
	for z in range(low.z, high.z + 1):
		for x in range(low.x, high.x + 1):
			var tile := Vector2i(x, z)
			var chunk: ChunkData = world.chunks.get(Coords.tile_to_chunk(tile))
			if chunk == null:
				continue
			var local := Coords.tile_to_local(tile)
			var column := (local.y * size + local.x) * height
			var voxels := chunk.voxels
			for row in range(bottom, top + 1):
				if voxels[column + row] == scarecrow:
					found.append(Vector3i(x, row, z))
	return found


## The crops within FIELD_CHUNKS chunks of a player (cells).
static func crops_near(server: GameServer, session: GameServer.PlayerSession) -> Array[Vector3i]:
	var crops: Array[Vector3i] = []
	var center := Coords.world_to_chunk(session.position)
	var world := server.world
	for dz in range(-FIELD_CHUNKS, FIELD_CHUNKS + 1):
		for dx in range(-FIELD_CHUNKS, FIELD_CHUNKS + 1):
			var chunk: ChunkData = world.chunks.get(center + Vector2i(dx, dz))
			if chunk == null:
				continue
			for cell: Vector3i in chunk.growing:
				if Farming.is_crop(Voxels.block_of(world.loaded_voxel_at(cell))):
					crops.append(cell)
	return crops


## Whether a crop is young (sown, or a stage on): crows peck it up.
static func is_young(block: int) -> bool:
	var stage := Farming.stage_of(block)
	return stage >= 0 and stage <= 1


static func _come(
	server: GameServer, creatures: Creatures, session: GameServer.PlayerSession
) -> void:
	var rng := creatures.rng
	var counts := _counts(creatures, session)
	var crops := crops_near(server, session)
	var night := server.clock.is_night()
	if crops.size() >= MIN_CROPS:
		if counts.get(Species.Id.MOLE, 0) == 0 and rng.randf() < MOLE_CHANCE:
			var cell: Vector3i = crops[rng.randi() % crops.size()]
			var mole := _add(creatures, Species.Id.MOLE, cell, 0.0) as Mole
			mole.field = crops
			mole.target = cell
		var young := _young(server, crops)
		var crows: int = counts.get(Species.Id.CROW, 0)
		if not night and young.size() >= 2 and crows < MAX_CROWS and rng.randf() < CROW_CHANCE:
			var crop: Vector3i = young[rng.randi() % young.size()]
			var from := Vector2.RIGHT.rotated(rng.randf() * TAU) * CROW_FROM.x
			var start := crop + Vector3i(roundi(from.x), 0, roundi(from.y))
			var crow := _add(creatures, Species.Id.CROW, start, CROW_FROM.y) as Crow
			crow.peck(crop)
	var bumblebees: int = counts.get(Species.Id.LANTERN_BUMBLEBEE, 0)
	if night and bumblebees < MAX_BUMBLEBEES and rng.randf() < BUMBLEBEE_CHANCE:
		_bumblebee(server, creatures, session)


## A lantern bumblebee comes out among flowers or crops near a player.
static func _bumblebee(
	server: GameServer, creatures: Creatures, session: GameServer.PlayerSession
) -> void:
	var rng := creatures.rng
	var tile := Coords.world_to_tile(session.position)
	tile += Vector2i(
		rng.randi_range(-BUMBLEBEE_RANGE, BUMBLEBEE_RANGE),
		rng.randi_range(-BUMBLEBEE_RANGE, BUMBLEBEE_RANGE)
	)
	var chunk: ChunkData = server.world.chunks.get(Coords.tile_to_chunk(tile))
	if chunk == null:
		return
	var row := chunk.top_row(Coords.tile_to_local(tile))
	var cell := Vector3i(tile.x, row, tile.y)
	var flowers := Apiary.flowers_near(server.world, cell)
	if flowers.is_empty():
		return
	var bee := _add(creatures, Species.Id.LANTERN_BUMBLEBEE, cell, 1.0) as Bee
	bee.home = cell
	for flower in flowers.slice(0, Apiary.BEE_FLOWERS):
		bee.flowers.append(
			Vector3(flower.x + 0.5, flower.y - GameConst.SEA_LEVEL + 0.3, flower.z + 0.5)
		)


## A crow: scared off (a scarecrow, a player near, the night), else when it
## pecked through its seedling, on to the next young crop near, if any;
## gone once off.
static func _crow(server: GameServer, creatures: Creatures, crow: Crow) -> void:
	if crow.gone:
		creatures.remove(server, crow, false)
		return
	if crow.state == Creature.State.FLEE:
		return
	var world := server.world
	if server.clock.is_night():
		crow.scare(crow.center())
		return
	for session in server.sessions:
		var near := session.position.distance_to(crow.center()) / GameConst.TILE_SIZE
		if session.joined and session.alive() and near <= CROW_FLEE:
			crow.scare(session.position)
			return
	if crow.target != Vector3i.MAX and scared(world, crow.target):
		crow.scare(crow.center())
		return
	if not crow.bite:
		return
	crow.bite = false
	var cell := crow.target
	if is_young(Voxels.block_of(world.loaded_voxel_at(cell))):
		server.change_voxel(cell, Voxels.AIR)
	var next := Vector3i.MAX
	var nearest := INF
	for dz in range(-4, 5):
		for dx in range(-4, 5):
			var other := cell + Vector3i(dx, 0, dz)
			if is_young(Voxels.block_of(world.loaded_voxel_at(other))):
				var distance := Vector2(dx, dz).length()
				if distance < nearest:
					nearest = distance
					next = other
	if next == Vector3i.MAX:
		crow.scare(crow.center())
	else:
		crow.peck(next)


## The young crops of a field not watched by a scarecrow.
static func _young(server: GameServer, crops: Array[Vector3i]) -> Array[Vector3i]:
	var young: Array[Vector3i] = []
	if crops.is_empty():
		return young
	var low := crops[0]
	var high := crops[0]
	for cell in crops:
		low = low.min(cell)
		high = high.max(cell)
	var reach := Vector3i(SCARE_RANGE, 2, SCARE_RANGE)
	var watching := scarecrows(server.world, low - reach, high + reach)
	for cell in crops:
		if not is_young(Voxels.block_of(server.world.loaded_voxel_at(cell))):
			continue
		var watched := false
		for scarecrow in watching:
			var off := (scarecrow - cell).abs()
			if off.x <= SCARE_RANGE and off.z <= SCARE_RANGE and off.y <= 2:
				watched = true
		if not watched:
			young.append(cell)
	return young


## How many pests of each kind are around a player.
static func _counts(creatures: Creatures, session: GameServer.PlayerSession) -> Dictionary:
	var counts := {}
	for creature: Creature in creatures.living.values():
		if Species.PESTS.has(creature.species):
			if creature.center().distance_to(session.position) <= GONE * GameConst.TILE_SIZE:
				counts[creature.species] = counts.get(creature.species, 0) + 1
	return counts


## A pest of `kind` at a cell, `rise` levels over it.
static func _add(creatures: Creatures, kind: int, cell: Vector3i, rise: float) -> Creature:
	var box: Vector2 = Species.BOX[kind]
	var feet := Coords.tile_to_world_center(Vector2i(cell.x, cell.z)) + Vector2(0.0, box.y * 0.5)
	return creatures.add(kind, feet, cell.y - GameConst.SEA_LEVEL + rise)
