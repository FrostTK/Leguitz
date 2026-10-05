class_name Apiary
extends RefCounted
## Bees and honey, on the server (static, given the server). A beehive
## (players make it) or a wild bee nest is a block by how much honey it
## holds (HIVES: 0 to FULL). Growth gives each its turn: by day it sends
## its bees out (BEES of a hive, each a Bee creature visiting the flowers
## around it) and fills up a level on average every HONEY_SECONDS (paced),
## faster with more flowers near (FLOWER_RANGE: flowers and crops, up to
## MOST_FLOWERS), not without any. Full, it gives a bottle of honey to a
## glass bottle or honeycomb to shears (`harvest`) and is empty again.
## Crops within POLLINATION_RANGE of a hive grow faster (`pollinated`). At
## night the bees fly home and go in (`sense`).

## A hive's levels: empty to full, a beehive's and a nest's.
const HIVES: Array[Array] = [
	[Tiles.Block.BEEHIVE, Tiles.Block.BEEHIVE_1, Tiles.Block.BEEHIVE_2, Tiles.Block.BEEHIVE_3],
	[Tiles.Block.BEE_NEST, Tiles.Block.BEE_NEST_1, Tiles.Block.BEE_NEST_2, Tiles.Block.BEE_NEST_3],
]
const FULL := 3
## Bees a beehive keeps out by day (a nest one less).
const BEES := 3
const HONEY_SECONDS := 240.0
const FLOWER_RANGE := 6
const FLOWER_ROWS := 2
const MOST_FLOWERS := 4
## The flowers a bee is told of (the nearest).
const BEE_FLOWERS := 8
## Crops this near a hive (tiles) grow this much sooner.
const POLLINATION_RANGE := 8
const POLLINATED := 0.75
## Honeycomb shears take from a full hive.
const COMBS := 3
## Server: a hive is reached this far at most (local units).
const REACH_LEEWAY := 1.5

## Each hive block -> [its kind's levels, its level].
static var _levels := _build_levels()


static func is_hive(block: int) -> bool:
	return _levels.has(block)


## How much honey a hive holds (0 to FULL; -1: not a hive).
static func level_of(block: int) -> int:
	return _levels[block][1] if _levels.has(block) else -1


## The same hive holding `level` honey.
static func with_level(block: int, level: int) -> int:
	var levels: Array = HIVES[_levels[block][0]]
	return levels[clampi(level, 0, FULL)]


## A hive's turn (Growth, every check; `odds`: of a level of honey this
## time, before the flowers): by day its bees come out, and it fills up.
static func work(server: GameServer, cell: Vector3i, voxel: int, odds: float) -> void:
	var world := server.world
	if server.clock.is_night():
		return
	var flowers := flowers_near(world.loaded_voxel_at, cell)
	_send_bees(server, cell, voxel, flowers)
	var level := level_of(Voxels.block_of(voxel))
	if level >= FULL or flowers.is_empty():
		return
	if server.rng.randf() < odds * mini(flowers.size(), MOST_FLOWERS):
		server.change_voxel(cell, Voxels.of_block(with_level(Voxels.block_of(voxel), level + 1)))


## The flowers and crops within FLOWER_RANGE of a hive, nearest first
## (cells).
static func flowers_near(voxel_at: Callable, cell: Vector3i) -> Array[Vector3i]:
	var found: Array[Vector3i] = []
	for dz in range(-FLOWER_RANGE, FLOWER_RANGE + 1):
		for dx in range(-FLOWER_RANGE, FLOWER_RANGE + 1):
			for dy in range(-FLOWER_ROWS, FLOWER_ROWS + 1):
				var at := cell + Vector3i(dx, dy, dz)
				var block := Voxels.block_of(voxel_at.call(at))
				if block in Tiles.FLOWERS or Farming.is_crop(block):
					found.append(at)
	found.sort_custom(
		func(a: Vector3i, b: Vector3i) -> bool:
			return (a - cell).length_squared() < (b - cell).length_squared()
	)
	return found


## Whether a hive stands within POLLINATION_RANGE of a cell (`hives`: the
## hives' cells, Growth gathers them).
static func pollinated(hives: Array[Vector3i], cell: Vector3i) -> bool:
	for hive in hives:
		var off := hive - cell
		if absi(off.x) <= POLLINATION_RANGE and absi(off.z) <= POLLINATION_RANGE:
			if absi(off.y) <= POLLINATION_RANGE:
				return true
	return false


## A bee's step (Creatures.update, before it thinks): at night it flies
## home and, there, goes in (it is taken away); its hive gone, it goes.
static func sense(server: GameServer, creatures: Creatures, bee: Bee) -> void:
	var hive := Voxels.block_of(creatures.voxel_at(bee.home))
	if not is_hive(hive):
		creatures.remove(server, bee, false)
		return
	bee.night = server.clock.is_night()
	if bee.night and bee.is_home():
		creatures.remove(server, bee, false)


## A player harvested the full hive at `cell` with what is in hotbar slot
## `slot` (Msg.HARVEST_HIVE): a glass bottle gives a bottle of honey, shears
## honeycomb (they wear); the hive is empty again. Refused, they are told
## what is there.
static func harvest(
	server: GameServer, session: GameServer.PlayerSession, message: Dictionary
) -> void:
	if not session.joined or not session.alive():
		return
	var cell: Vector3i = message.get("cell", Vector3i.ZERO)
	var slot := clampi(int(message.get("slot", 0)), 0, Inventory.HOTBAR - 1)
	var bag := session.inventory
	var voxel := server.world.voxel_at(cell)
	var block := Voxels.block_of(voxel)
	var held := bag.items[slot]
	var near := Mining.reach_to(session.position, session.height, cell)
	if (
		level_of(block) != FULL
		or near > Mining.REACH + REACH_LEEWAY
		or not (held in [Items.Id.GLASS_BOTTLE, Items.Id.SHEARS])
	):
		session.transport.send(Msg.block_changed(cell, voxel))
		session.transport.send(Msg.inventory(bag))
		return
	server.change_voxel(cell, Voxels.of_block(with_level(block, 0)))
	var creative := GameModes.creative(server)
	if held == Items.Id.SHEARS:
		if not creative:
			bag.wear_out(slot)
		if bag.add(Items.Id.HONEYCOMB, COMBS) > 0:
			server.throw_item(session, Items.Id.HONEYCOMB, COMBS)
	else:
		if not creative:
			bag.take(slot, 1)
		if bag.add(Items.Id.HONEY_BOTTLE, 1) > 0:
			server.throw_item(session, Items.Id.HONEY_BOTTLE, 1)
	session.transport.send(Msg.inventory(bag))


## A hive sends out a bee (by day) while it has fewer than its BEES out;
## they are told of the flowers near (again each time: new ones planted).
static func _send_bees(
	server: GameServer, cell: Vector3i, voxel: int, flowers: Array[Vector3i]
) -> void:
	var creatures := server.creatures
	var wanted := BEES if _levels[Voxels.block_of(voxel)][0] == 0 else BEES - 1
	var spots: Array[Vector3] = []
	for flower in flowers.slice(0, BEE_FLOWERS):
		spots.append(Vector3(flower.x + 0.5, flower.y - GameConst.SEA_LEVEL + 0.3, flower.z + 0.5))
	var out := 0
	for creature: Creature in creatures.living.values():
		if creature is Bee and (creature as Bee).home == cell:
			(creature as Bee).flowers = spots.duplicate()
			out += 1
	if out >= wanted:
		return
	var box: Vector2 = Species.BOX[Species.Id.BEE]
	var feet := Coords.tile_to_world_center(Vector2i(cell.x, cell.z)) + Vector2(0.0, box.y * 0.5)
	var bee := creatures.add(Species.Id.BEE, feet, cell.y - GameConst.SEA_LEVEL + 1.0) as Bee
	bee.home = cell
	bee.flowers = spots.duplicate()


static func _build_levels() -> Dictionary:
	var lookup := {}
	for kind in HIVES.size():
		for level in HIVES[kind].size():
			lookup[HIVES[kind][level]] = [kind, level]
	return lookup
