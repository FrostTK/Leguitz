class_name Machines
extends RefCounted
## The kitchen's machines on the server (static, given the server): the
## mill grinds grain into flour, the butter churn milk into butter, the
## barrel fruit into juice (apple juice left longer turns into cider), the
## cheese cellar milk into cheese; a fish trap set in the water catches,
## for each bait it was given, what lives there (FishTable.trap_pick for
## the water: Fishing.water_at). Each is a block by stage (STAGES:
## empty, working, ready; ObjectShapes.STAGE_OF). Used with what it takes
## in hand (Msg.USE_MACHINE: right click or E), an empty one takes up to
## CAPACITY of it (a milk's bucket comes back) and works SECONDS (each item
## for the mill; paced by WorldClock.scale_duration); ready, using it gives
## what it made (juice and cider into glass bottles held in hand, as many
## as there are; a trap's catches) and it empties. What a machine holds
## (ChunkData.machines: cell -> {"input", "inputs", "made", "count",
## "left", "ferments"}, a ready trap's "catches": item -> count) is
## saved with its chunk; GameServer.tick runs `update` every TICKS; broken,
## it spills what it held (`spill`).

enum Kind { MILL, CHURN, BARREL, CELLAR, TRAP }
enum Stage { EMPTY, WORKING, READY }

const TICKS := 20
## The blocks of each machine by stage.
const STAGES := {
	Kind.MILL: [Tiles.Block.MILL, Tiles.Block.MILL_WORKING, Tiles.Block.MILL_READY],
	Kind.CHURN:
	[Tiles.Block.BUTTER_CHURN, Tiles.Block.BUTTER_CHURN_WORKING, Tiles.Block.BUTTER_CHURN_READY],
	Kind.BARREL: [Tiles.Block.BARREL, Tiles.Block.BARREL_WORKING, Tiles.Block.BARREL_READY],
	Kind.CELLAR:
	[
		Tiles.Block.CHEESE_CELLAR,
		Tiles.Block.CHEESE_CELLAR_WORKING,
		Tiles.Block.CHEESE_CELLAR_READY,
	],
	Kind.TRAP: [Tiles.Block.FISH_TRAP, Tiles.Block.FISH_TRAP_BAITED, Tiles.Block.FISH_TRAP_FULL],
}
## What each machine makes of what it takes: input -> [made, count each].
const MAKES := {
	Kind.MILL: {Items.Id.WHEAT: [Items.Id.FLOUR, 1], Items.Id.CORN: [Items.Id.FLOUR, 1]},
	Kind.CHURN: {Items.Id.MILK_BUCKET: [Items.Id.BUTTER, 2]},
	Kind.BARREL:
	{
		Items.Id.APPLE: [Items.Id.APPLE_JUICE, 1],
		Items.Id.GRAPES: [Items.Id.FRUIT_JUICE, 1],
		Items.Id.ORANGE: [Items.Id.FRUIT_JUICE, 1],
		Items.Id.PEACH: [Items.Id.FRUIT_JUICE, 1],
		Items.Id.CHERRIES: [Items.Id.FRUIT_JUICE, 1],
		Items.Id.BERRIES: [Items.Id.FRUIT_JUICE, 1],
		Items.Id.RASPBERRY: [Items.Id.FRUIT_JUICE, 1],
		Items.Id.STRAWBERRY: [Items.Id.FRUIT_JUICE, 1],
		Items.Id.MELON_SLICE: [Items.Id.FRUIT_JUICE, 1],
	},
	Kind.CELLAR: {Items.Id.MILK_BUCKET: [Items.Id.CHEESE, 3]},
	Kind.TRAP:
	{
		Items.Id.WORM: [Items.Id.NONE, 1],
		Items.Id.BAIT_BALL: [Items.Id.NONE, 1],
		Items.Id.FISH_BAIT: [Items.Id.NONE, 1],
	},
}
## How much a machine takes at once, and how long it works (seconds, the
## default day's; the mill's for each grain, a trap's for each bait).
const CAPACITY := {Kind.MILL: 16, Kind.CHURN: 1, Kind.BARREL: 8, Kind.CELLAR: 1, Kind.TRAP: 4}
const SECONDS := {
	Kind.MILL: 8.0, Kind.CHURN: 45.0, Kind.BARREL: 240.0, Kind.CELLAR: 600.0, Kind.TRAP: 150.0
}
const EACH := {Kind.MILL: true, Kind.TRAP: true}
## Apple juice left in a barrel this much longer turns into cider.
const CIDER_SECONDS := 480.0
## What comes out into glass bottles held in hand.
const BOTTLED := {Items.Id.APPLE_JUICE: true, Items.Id.FRUIT_JUICE: true, Items.Id.CIDER: true}
## Server: a machine is reached this far at most (local units).
const REACH_LEEWAY := 1.5


## The machine a block is (-1: none).
static func kind_of(block: int) -> int:
	for kind: int in STAGES:
		if block in STAGES[kind]:
			return kind
	return -1


## The stage of a machine's block (Stage; -1: not a machine).
static func stage_of(block: int) -> int:
	var kind := kind_of(block)
	return -1 if kind < 0 else (STAGES[kind] as Array).find(block)


## Whether an empty machine takes an item.
static func takes(block: int, item: int) -> bool:
	return stage_of(block) == Stage.EMPTY and MAKES[kind_of(block)].has(item)


## Whether using a machine with `item` in hand does something (a client's
## guess: it takes the item, or it is ready and gives, with bottles in
## hand for what is bottled... which the server knows best).
static func usable(block: int, item: int) -> bool:
	return takes(block, item) or stage_of(block) == Stage.READY


## A player used a machine at `cell` with hotbar slot `slot` in hand
## (Msg.USE_MACHINE): an empty one takes what it makes something of, a
## ready one gives what it made. Refused, they are told what is there.
static func use(server: GameServer, session: GameServer.PlayerSession, message: Dictionary) -> void:
	if not session.joined or not session.alive():
		return
	var cell: Vector3i = message.get("cell", Vector3i.ZERO)
	var slot := clampi(int(message.get("slot", 0)), 0, Inventory.HOTBAR - 1)
	var voxel := server.world.voxel_at(cell)
	var block := Voxels.block_of(voxel)
	var near := Mining.reach_to(session.position, session.height, cell)
	var done := false
	if near <= Mining.REACH + REACH_LEEWAY:
		if takes(block, session.inventory.items[slot]):
			done = _load(server, session, cell, block, slot)
		elif stage_of(block) == Stage.READY:
			done = _empty(server, session, cell, block, slot)
	if not done:
		session.transport.send(Msg.block_changed(cell, voxel))
	session.transport.send(Msg.inventory(session.inventory))


## The machines of the loaded chunks work (`seconds` real seconds): done,
## they show what they made; apple juice ferments into cider.
static func update(server: GameServer, seconds: float) -> void:
	for chunk: ChunkData in server.world.chunks.values():
		if chunk.machines.is_empty():
			continue
		for cell: Vector3i in chunk.machines.keys():
			var held: Dictionary = chunk.machines[cell]
			if held["left"] <= 0.0:
				continue
			held["left"] = held["left"] - seconds
			if held["left"] > 0.0:
				continue
			var block := Voxels.block_of(server.world.voxel_at(cell))
			var kind := kind_of(block)
			if kind < 0:
				chunk.machines.erase(cell)
				continue
			if kind == Kind.TRAP:
				held["catches"] = _catches(server, cell, held["inputs"])
			elif held.get("ferments", false):
				held["made"] = Items.Id.CIDER
				held["ferments"] = false
			elif held["made"] == Items.Id.APPLE_JUICE:
				held["ferments"] = true
				held["left"] = server.clock.scale_duration(CIDER_SECONDS)
			server.world.contents_changed(cell)
			var ready: int = STAGES[kind][Stage.READY]
			if block != ready:
				server.change_voxel(cell, Voxels.of_block(ready))


## A machine broken at `cell`: what it held falls out (what it was given
## while working; what it made when ready, but liquids, lost without a
## bottle).
static func spill(server: GameServer, cell: Vector3i) -> void:
	var chunk: ChunkData = server.world.chunks.get(Coords.tile_to_chunk(Vector2i(cell.x, cell.z)))
	if chunk == null or not chunk.machines.has(cell):
		return
	var held: Dictionary = chunk.machines[cell]
	chunk.machines.erase(cell)
	var middle := Vector3(cell.x + 0.5, cell.y - GameConst.SEA_LEVEL + 0.5, cell.z + 0.5)
	var working: bool = held["left"] > 0.0 and not held.get("ferments", false)
	var catches: Dictionary = held.get("catches", {})
	if not working and not catches.is_empty():
		for caught: int in catches:
			var throw := Vector3(server.rng.randf_range(-1.0, 1.0), 3.0, 0.0)
			server.spawn_item(caught, catches[caught], middle, throw)
		return
	var item: int = held["input"] if working else held["made"]
	var count: int = held["inputs"] if working else held["count"]
	if item == Items.Id.MILK_BUCKET or (not working and BOTTLED.has(item)):
		return
	var speed := Vector3(server.rng.randf_range(-1.0, 1.0), 3.0, server.rng.randf_range(-1.0, 1.0))
	server.spawn_item(item, count, middle, speed)


## What an empty machine takes from the slot: up to CAPACITY (all of it in
## creative, left in hand), a milk's bucket back.
static func _load(
	server: GameServer, session: GameServer.PlayerSession, cell: Vector3i, block: int, slot: int
) -> bool:
	var chunk: ChunkData = server.world.chunks.get(Coords.tile_to_chunk(Vector2i(cell.x, cell.z)))
	if chunk == null:
		return false
	var kind := kind_of(block)
	var bag := session.inventory
	var item := bag.items[slot]
	var count := mini(bag.counts[slot], CAPACITY[kind])
	var made: Array = MAKES[kind][item]
	var seconds: float = SECONDS[kind] * (count if EACH.has(kind) else 1)
	chunk.machines[cell] = {
		"input": item,
		"inputs": count,
		"made": made[0],
		"count": count * made[1],
		"left": server.clock.scale_duration(seconds),
		"ferments": false,
	}
	if not GameModes.creative(server):
		bag.take(slot, count)
		if Items.LEFT_AFTER.has(item):
			_give(server, session, slot, Items.LEFT_AFTER[item], count)
	server.world.contents_changed(cell)
	server.change_voxel(cell, Voxels.of_block(STAGES[kind][Stage.WORKING]))
	return true


## A ready machine gives what it made into the slots (bottled ones into
## glass bottles in hand, as many as there are; the rest stays) and
## empties.
static func _empty(
	server: GameServer, session: GameServer.PlayerSession, cell: Vector3i, block: int, slot: int
) -> bool:
	var chunk: ChunkData = server.world.chunks.get(Coords.tile_to_chunk(Vector2i(cell.x, cell.z)))
	if chunk == null or not chunk.machines.has(cell):
		server.change_voxel(cell, Voxels.of_block(STAGES[kind_of(block)][Stage.EMPTY]))
		return true
	var held: Dictionary = chunk.machines[cell]
	var bag := session.inventory
	if held.has("catches"):
		var catches: Dictionary = held["catches"]
		for caught: int in catches:
			_give(server, session, slot, caught, catches[caught])
		chunk.machines.erase(cell)
		server.world.contents_changed(cell)
		server.change_voxel(cell, Voxels.of_block(STAGES[kind_of(block)][Stage.EMPTY]))
		return true
	var made: int = held["made"]
	var given: int = held["count"]
	if BOTTLED.has(made):
		if bag.items[slot] != Items.Id.GLASS_BOTTLE:
			return false
		given = mini(given, bag.counts[slot])
		if not GameModes.creative(server):
			bag.take(slot, given)
	_give(server, session, slot, made, given)
	held["count"] = held["count"] - given
	server.world.contents_changed(cell)
	if held["count"] > 0:
		return true
	chunk.machines.erase(cell)
	server.change_voxel(cell, Voxels.of_block(STAGES[kind_of(block)][Stage.EMPTY]))
	return true


## What a trap at `cell` caught for `baits` baits (item -> count).
static func _catches(server: GameServer, cell: Vector3i, baits: int) -> Dictionary:
	var water := Fishing.water_at(server.world, cell + Vector3i.DOWN).x
	var catches := {}
	for i in baits:
		var caught := FishTable.trap_pick(server.rng, water)
		catches[caught] = catches.get(caught, 0) + 1
	return catches


## Gives a player `count` of an item: into the slot in hand if it is empty,
## else the slots, else at their feet.
static func _give(
	server: GameServer, session: GameServer.PlayerSession, slot: int, item: int, count: int
) -> void:
	var bag := session.inventory
	var left := count
	if bag.items[slot] == Items.Id.NONE:
		var put := mini(left, Items.max_stack(item))
		bag.items[slot] = item
		bag.counts[slot] = put
		bag.wear[slot] = 0
		left -= put
	left = bag.add(item, left)
	if left > 0:
		server.throw_item(session, item, left)
