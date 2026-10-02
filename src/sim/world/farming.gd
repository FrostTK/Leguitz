class_name Farming
extends RefCounted
## Fields and crops, on the server (static, given the server; Growth runs
## them). A hoe tills grass or dirt into farmland (`till`: the small plant
## over it goes); farmland is wet with water within MOIST_REACH tiles (on
## its row or the one above), else dry, and left dry with nothing sown it
## goes back to dirt after a while (FALLOW_SECONDS). Wheat seeds, carrots
## and potatoes are sown on farmland and grow a stage at a time (STAGES;
## on average after STAGE_SECONDS on wet farmland, DRY_SLOWER times longer
## on dry), in the light (Growth.LIGHT). A ripe crop gives its harvest and
## more seed (`harvest`); an unripe one only its seed back.

## How far (tiles) water wets farmland.
const MOIST_REACH := 4
const STAGE_SECONDS := 240.0
const DRY_SLOWER := 3.0
const FALLOW_SECONDS := 120.0
## The next stage of each crop, its ripe stage, and the first (sown).
const STAGES := {
	Tiles.Block.WHEAT_0: Tiles.Block.WHEAT_1,
	Tiles.Block.WHEAT_1: Tiles.Block.WHEAT_2,
	Tiles.Block.WHEAT_2: Tiles.Block.WHEAT_3,
	Tiles.Block.CARROTS_0: Tiles.Block.CARROTS_1,
	Tiles.Block.CARROTS_1: Tiles.Block.CARROTS_2,
	Tiles.Block.CARROTS_2: Tiles.Block.CARROTS_3,
	Tiles.Block.POTATOES_0: Tiles.Block.POTATOES_1,
	Tiles.Block.POTATOES_1: Tiles.Block.POTATOES_2,
	Tiles.Block.POTATOES_2: Tiles.Block.POTATOES_3,
}
const RIPE := {
	Tiles.Block.WHEAT_3: true,
	Tiles.Block.CARROTS_3: true,
	Tiles.Block.POTATOES_3: true,
}
const SOWN := {
	Tiles.Block.WHEAT_0: true,
	Tiles.Block.CARROTS_0: true,
	Tiles.Block.POTATOES_0: true,
}
## What tilling takes: grasses and dirt.
const TILLED := {Tiles.Ground.DIRT: true, Tiles.Ground.PODZOL: true}
## A crop's seed (what an unripe one gives back), its harvest when ripe
## [item, fewest, most], and the seeds a ripe one gives on top [fewest,
## most].
const SEED_OF := {
	Tiles.Block.WHEAT_0: Items.Id.SEEDS,
	Tiles.Block.CARROTS_0: Items.Id.CARROT,
	Tiles.Block.POTATOES_0: Items.Id.POTATO,
}
const HARVEST := {
	Tiles.Block.WHEAT_3: [Items.Id.WHEAT, 1, 1, 1, 3],
	Tiles.Block.CARROTS_3: [Items.Id.CARROT, 2, 4, 0, 0],
	Tiles.Block.POTATOES_3: [Items.Id.POTATO, 2, 4, 0, 0],
}
## Server: a hoe is used this far at most (local units, like placing).
const REACH_LEEWAY := 1.5


static func is_farmland(voxel: int) -> bool:
	return (
		voxel == Voxels.of_ground(Tiles.Ground.FARMLAND)
		or voxel == Voxels.of_ground(Tiles.Ground.FARMLAND_WET)
	)


static func is_crop(block: int) -> bool:
	return STAGES.has(block) or RIPE.has(block)


## The first stage of a crop (its kind).
static func sown_of(block: int) -> int:
	var sown := block
	for first: int in SOWN:
		var stage := first
		while stage != block and STAGES.has(stage):
			stage = STAGES[stage]
		if stage == block:
			sown = first
	return sown


## What tilling `cell` changes ({cell: voxel}; empty: it cannot be): grass
## or dirt with air or a small plant over it becomes dry farmland, the
## plant goes.
static func tilled(cell: Vector3i, voxel_at: Callable) -> Dictionary:
	var ground: int = voxel_at.call(cell)
	if not (TILLED.has(ground) or Growth.GRASSES.has(ground)):
		return {}
	var above: int = voxel_at.call(cell + Vector3i.UP)
	if Voxels.is_liquid(above) or not Mining.is_replaceable(above):
		return {}
	var cells := {cell: Voxels.of_ground(Tiles.Ground.FARMLAND)}
	if above != Voxels.AIR:
		cells[cell + Vector3i.UP] = Voxels.AIR
	return cells


## A player tilled a cell with the hoe in hotbar slot `slot` (Msg.TILL):
## within reach, the hoe in hand wears (not in creative). Refused, they are
## told what is there.
static func till(
	server: GameServer, session: GameServer.PlayerSession, message: Dictionary
) -> void:
	if not session.joined or not session.alive():
		return
	var cell: Vector3i = message.get("cell", Vector3i.ZERO)
	var slot := clampi(int(message.get("slot", 0)), 0, Inventory.HOTBAR - 1)
	var bag := session.inventory
	var cells := tilled(cell, server.world.voxel_at)
	var near := Mining.reach_to(session.position, session.height, cell)
	if (
		cells.is_empty()
		or near > Mining.REACH + REACH_LEEWAY
		or Items.tool_of(bag.items[slot]) != Items.Tool.HOE
	):
		for at: Vector3i in [cell, cell + Vector3i.UP]:
			session.transport.send(Msg.block_changed(at, server.world.voxel_at(at)))
		return
	for at: Vector3i in cells:
		server.change_voxel(at, cells[at])
	if not GameModes.creative(server) and Items.durability(bag.items[slot]) > 0:
		bag.wear_out(slot)
		session.transport.send(Msg.inventory(bag))


## What breaking a crop gives: ripe, its harvest and seeds; else its seed.
static func harvest(block: int, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not RIPE.has(block):
		result.append(Vector2i(SEED_OF[sown_of(block)], 1))
		return result
	var crop: Array = HARVEST[block]
	result.append(Vector2i(crop[0], rng.randi_range(crop[1], crop[2])))
	var seeds := rng.randi_range(crop[3], crop[4])
	if seeds > 0:
		result.append(Vector2i(SEED_OF[sown_of(block)], seeds))
	return result


## Whether water lies within MOIST_REACH tiles of farmland (on its row or
## the one above).
static func wet_near(world: WorldState, cell: Vector3i) -> bool:
	for dz in range(-MOIST_REACH, MOIST_REACH + 1):
		for dx in range(-MOIST_REACH, MOIST_REACH + 1):
			for dy in 2:
				if Voxels.is_water(world.loaded_voxel_at(cell + Vector3i(dx, dy, dz))):
					return true
	return false


## Farmland settles (Growth, every check): wet or dry by the water near;
## dry with nothing sown, it may go back to dirt (`odds` this time).
static func settle_farmland(server: GameServer, cell: Vector3i, voxel: int, odds: float) -> void:
	var world := server.world
	var wet := wet_near(world, cell)
	var above := Voxels.block_of(world.loaded_voxel_at(cell + Vector3i.UP))
	if not wet and not is_crop(above) and server.rng.randf() < odds:
		server.change_voxel(cell, Voxels.of_ground(Tiles.Ground.DIRT))
		return
	var now := Voxels.of_ground(Tiles.Ground.FARMLAND_WET if wet else Tiles.Ground.FARMLAND)
	if now != voxel:
		server.change_voxel(cell, now)


## How long a crop takes on average to grow a stage (seconds, unpaced):
## longer on dry farmland.
static func stage_seconds(world: WorldState, cell: Vector3i) -> float:
	var under := world.loaded_voxel_at(cell + Vector3i.DOWN)
	if under == Voxels.of_ground(Tiles.Ground.FARMLAND_WET):
		return STAGE_SECONDS
	return STAGE_SECONDS * DRY_SLOWER
