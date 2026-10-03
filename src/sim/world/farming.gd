class_name Farming
extends RefCounted
## Fields and crops, on the server (static, given the server; Growth runs
## them). A hoe tills grass or dirt into farmland (`till`: the small plant
## over it goes); farmland is wet with water within MOIST_REACH tiles (on
## its row or the one above), else dry, and left dry with nothing sown it
## goes back to dirt after a while (FALLOW_SECONDS); watered (a can, the
## rain: Watering), it stays wet for a while too. Crops are sown on
## farmland (wheat seeds, carrots, potatoes, beetroot, cabbage, corn,
## tomato, strawberries, raspberries, flax, pumpkin and melon seeds) and
## grow a stage at
## a time (STAGES; on average after STAGE_SECONDS on wet farmland,
## DRY_SLOWER times longer on dry), in the light (Growth.LIGHT); some have
## other beds (BEDS: rice over shallow water, sugar cane on a bank, grapes
## on a trellis). A ripe crop gives its harvest and more seed (`harvest`);
## an unripe one only its seed back. A grown pumpkin or melon stem puts its
## fruit on a free tile beside it (`bear_fruit`), again once it is taken;
## ripe tomatoes, strawberries, raspberries, grapes and sugar cane are
## picked without breaking them (Picking). Wild plants (WILD) give the first seeds.

## Where a crop grows (BEDS): on farmland, over still water one deep, on
## soil or sand with water beside, on a trellis standing on soil.
enum Bed { FIELD, WATER, BANK, TRELLIS }

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
	Tiles.Block.BEETROOTS_0: Tiles.Block.BEETROOTS_1,
	Tiles.Block.BEETROOTS_1: Tiles.Block.BEETROOTS_2,
	Tiles.Block.BEETROOTS_2: Tiles.Block.BEETROOTS_3,
	Tiles.Block.CABBAGES_0: Tiles.Block.CABBAGES_1,
	Tiles.Block.CABBAGES_1: Tiles.Block.CABBAGES_2,
	Tiles.Block.CABBAGES_2: Tiles.Block.CABBAGES_3,
	Tiles.Block.CORN_0: Tiles.Block.CORN_1,
	Tiles.Block.CORN_1: Tiles.Block.CORN_2,
	Tiles.Block.CORN_2: Tiles.Block.CORN_3,
	Tiles.Block.TOMATOES_0: Tiles.Block.TOMATOES_1,
	Tiles.Block.TOMATOES_1: Tiles.Block.TOMATOES_2,
	Tiles.Block.TOMATOES_2: Tiles.Block.TOMATOES_3,
	Tiles.Block.STRAWBERRIES_0: Tiles.Block.STRAWBERRIES_1,
	Tiles.Block.STRAWBERRIES_1: Tiles.Block.STRAWBERRIES_2,
	Tiles.Block.STRAWBERRIES_2: Tiles.Block.STRAWBERRIES_3,
	Tiles.Block.FLAX_0: Tiles.Block.FLAX_1,
	Tiles.Block.FLAX_1: Tiles.Block.FLAX_2,
	Tiles.Block.FLAX_2: Tiles.Block.FLAX_3,
	Tiles.Block.PUMPKIN_STEM_0: Tiles.Block.PUMPKIN_STEM_1,
	Tiles.Block.PUMPKIN_STEM_1: Tiles.Block.PUMPKIN_STEM_2,
	Tiles.Block.PUMPKIN_STEM_2: Tiles.Block.PUMPKIN_STEM_3,
	Tiles.Block.MELON_STEM_0: Tiles.Block.MELON_STEM_1,
	Tiles.Block.MELON_STEM_1: Tiles.Block.MELON_STEM_2,
	Tiles.Block.MELON_STEM_2: Tiles.Block.MELON_STEM_3,
	Tiles.Block.RICE_0: Tiles.Block.RICE_1,
	Tiles.Block.RICE_1: Tiles.Block.RICE_2,
	Tiles.Block.RICE_2: Tiles.Block.RICE_3,
	Tiles.Block.SUGAR_CANE_0: Tiles.Block.SUGAR_CANE_1,
	Tiles.Block.SUGAR_CANE_1: Tiles.Block.SUGAR_CANE,
	Tiles.Block.GRAPES_0: Tiles.Block.GRAPES_1,
	Tiles.Block.GRAPES_1: Tiles.Block.GRAPES_2,
	Tiles.Block.GRAPES_2: Tiles.Block.GRAPES_3,
	Tiles.Block.RASPBERRIES_0: Tiles.Block.RASPBERRIES_1,
	Tiles.Block.RASPBERRIES_1: Tiles.Block.RASPBERRIES_2,
	Tiles.Block.RASPBERRIES_2: Tiles.Block.RASPBERRIES_3,
}
const RIPE := {
	Tiles.Block.WHEAT_3: true,
	Tiles.Block.CARROTS_3: true,
	Tiles.Block.POTATOES_3: true,
	Tiles.Block.BEETROOTS_3: true,
	Tiles.Block.CABBAGES_3: true,
	Tiles.Block.CORN_3: true,
	Tiles.Block.TOMATOES_3: true,
	Tiles.Block.STRAWBERRIES_3: true,
	Tiles.Block.FLAX_3: true,
	Tiles.Block.PUMPKIN_STEM_3: true,
	Tiles.Block.MELON_STEM_3: true,
	Tiles.Block.RICE_3: true,
	Tiles.Block.SUGAR_CANE: true,
	Tiles.Block.GRAPES_3: true,
	Tiles.Block.RASPBERRIES_3: true,
}
const SOWN := {
	Tiles.Block.WHEAT_0: true,
	Tiles.Block.CARROTS_0: true,
	Tiles.Block.POTATOES_0: true,
	Tiles.Block.BEETROOTS_0: true,
	Tiles.Block.CABBAGES_0: true,
	Tiles.Block.CORN_0: true,
	Tiles.Block.TOMATOES_0: true,
	Tiles.Block.STRAWBERRIES_0: true,
	Tiles.Block.FLAX_0: true,
	Tiles.Block.PUMPKIN_STEM_0: true,
	Tiles.Block.MELON_STEM_0: true,
	Tiles.Block.RICE_0: true,
	Tiles.Block.SUGAR_CANE_0: true,
	Tiles.Block.GRAPES_0: true,
	Tiles.Block.RASPBERRIES_0: true,
}
## The crops that do not grow on farmland (by their sown stage).
const BEDS := {
	Tiles.Block.RICE_0: Bed.WATER,
	Tiles.Block.SUGAR_CANE_0: Bed.BANK,
	Tiles.Block.GRAPES_0: Bed.TRELLIS,
}
## Grown stems and the fruit they put beside them.
const FRUIT_OF := {
	Tiles.Block.PUMPKIN_STEM_3: Tiles.Block.PUMPKIN,
	Tiles.Block.MELON_STEM_3: Tiles.Block.MELON,
}
## What tilling takes: grasses and dirt.
const TILLED := {Tiles.Ground.DIRT: true, Tiles.Ground.PODZOL: true}
## Loose grounds besides soil (Growth.is_soil) and farmland: sugar cane
## grows in them, rice over them.
const LOOSE := {
	Tiles.Ground.SAND: true,
	Tiles.Ground.RED_SAND: true,
	Tiles.Ground.GRAVEL: true,
}
## A crop's seed (what an unripe one gives back), its harvest when ripe
## [item, fewest, most], and the seeds a ripe one gives on top [fewest,
## most].
const SEED_OF := {
	Tiles.Block.WHEAT_0: Items.Id.SEEDS,
	Tiles.Block.CARROTS_0: Items.Id.CARROT,
	Tiles.Block.POTATOES_0: Items.Id.POTATO,
	Tiles.Block.BEETROOTS_0: Items.Id.BEETROOT_SEEDS,
	Tiles.Block.CABBAGES_0: Items.Id.CABBAGE_SEEDS,
	Tiles.Block.CORN_0: Items.Id.CORN,
	Tiles.Block.TOMATOES_0: Items.Id.TOMATO_SEEDS,
	Tiles.Block.STRAWBERRIES_0: Items.Id.STRAWBERRY,
	Tiles.Block.FLAX_0: Items.Id.FLAX_SEEDS,
	Tiles.Block.PUMPKIN_STEM_0: Items.Id.PUMPKIN_SEEDS,
	Tiles.Block.MELON_STEM_0: Items.Id.MELON_SEEDS,
	Tiles.Block.RICE_0: Items.Id.RICE,
	Tiles.Block.SUGAR_CANE_0: Items.Id.SUGAR_CANE,
	Tiles.Block.GRAPES_0: Items.Id.GRAPE_SEEDS,
	Tiles.Block.RASPBERRIES_0: Items.Id.RASPBERRY,
}
const HARVEST := {
	Tiles.Block.WHEAT_3: [Items.Id.WHEAT, 1, 1, 1, 3],
	Tiles.Block.CARROTS_3: [Items.Id.CARROT, 2, 4, 0, 0],
	Tiles.Block.POTATOES_3: [Items.Id.POTATO, 2, 4, 0, 0],
	Tiles.Block.BEETROOTS_3: [Items.Id.BEETROOT, 1, 2, 1, 2],
	Tiles.Block.CABBAGES_3: [Items.Id.CABBAGE, 1, 1, 1, 2],
	Tiles.Block.CORN_3: [Items.Id.CORN, 2, 3, 0, 0],
	Tiles.Block.TOMATOES_3: [Items.Id.TOMATO, 2, 3, 1, 1],
	Tiles.Block.STRAWBERRIES_3: [Items.Id.STRAWBERRY, 2, 3, 0, 0],
	Tiles.Block.FLAX_3: [Items.Id.FLAX, 2, 3, 1, 2],
	Tiles.Block.PUMPKIN_STEM_3: [Items.Id.PUMPKIN_SEEDS, 1, 2, 0, 0],
	Tiles.Block.MELON_STEM_3: [Items.Id.MELON_SEEDS, 1, 2, 0, 0],
	Tiles.Block.RICE_3: [Items.Id.RICE, 2, 4, 0, 0],
	Tiles.Block.SUGAR_CANE: [Items.Id.SUGAR_CANE, 1, 3, 0, 0],
	Tiles.Block.GRAPES_3: [Items.Id.GRAPES, 2, 3, 1, 1],
	Tiles.Block.RASPBERRIES_3: [Items.Id.RASPBERRY, 2, 3, 0, 0],
}
## Wild plants (generation) and what they give: [[item, fewest, most]...].
const WILD := {
	Tiles.Block.WILD_BEETROOT: [[Items.Id.BEETROOT, 1, 1], [Items.Id.BEETROOT_SEEDS, 1, 2]],
	Tiles.Block.WILD_CABBAGE: [[Items.Id.CABBAGE, 1, 1], [Items.Id.CABBAGE_SEEDS, 1, 2]],
	Tiles.Block.WILD_CORN: [[Items.Id.CORN, 1, 2]],
	Tiles.Block.WILD_TOMATO: [[Items.Id.TOMATO, 1, 2], [Items.Id.TOMATO_SEEDS, 1, 2]],
	Tiles.Block.WILD_STRAWBERRY: [[Items.Id.STRAWBERRY, 1, 3]],
	Tiles.Block.WILD_FLAX: [[Items.Id.FLAX, 1, 1], [Items.Id.FLAX_SEEDS, 1, 2]],
	Tiles.Block.WILD_RICE: [[Items.Id.RICE, 1, 3]],
	Tiles.Block.WILD_GRAPES: [[Items.Id.GRAPES, 1, 2], [Items.Id.GRAPE_SEEDS, 1, 2]],
	Tiles.Block.WILD_RASPBERRY: [[Items.Id.RASPBERRY, 1, 3]],
}
## Server: a hoe is used this far at most (local units, like placing).
const REACH_LEEWAY := 1.5

## Every stage of a crop -> its sown stage.
static var _sown := _build_sown()


static func is_farmland(voxel: int) -> bool:
	return (
		voxel == Voxels.of_ground(Tiles.Ground.FARMLAND)
		or voxel == Voxels.of_ground(Tiles.Ground.FARMLAND_WET)
	)


static func is_crop(block: int) -> bool:
	return STAGES.has(block) or RIPE.has(block)


## The first stage of a crop (its kind).
static func sown_of(block: int) -> int:
	return _sown.get(block, block)


## How far a crop has grown: 0 sown, then a stage more each time (-1: no
## crop).
static func stage_of(block: int) -> int:
	if not _sown.has(block):
		return -1
	var stage := 0
	var at: int = _sown[block]
	while at != block:
		at = STAGES[at]
		stage += 1
	return stage


## Where a crop grows (Bed.FIELD: farmland).
static func bed_of(block: int) -> int:
	return BEDS.get(sown_of(block), Bed.FIELD)


## What sowing the first stage of a crop (`voxel`) into `cell` changes
## ({cell: voxel}; empty: it cannot go there): on farmland, into air or a
## small plant; rice into air over still water one deep (over soil or
## sand); sugar cane on soil or sand with water beside it; grapes into a
## trellis standing on soil or farmland.
static func sowing(cell: Vector3i, voxel: int, voxel_at: Callable) -> Dictionary:
	var block := Voxels.block_of(voxel)
	var there: int = voxel_at.call(cell)
	var bed := bed_of(block)
	var room := Mining.is_replaceable(there) and not Voxels.is_liquid(there)
	if bed == Bed.WATER:
		room = there == Voxels.AIR
	elif bed == Bed.TRELLIS:
		room = Voxels.block_of(there) == Tiles.Block.TRELLIS
	return {cell: voxel} if room and holds(cell, block, voxel_at) else {}


## Whether what is under a crop (any stage) still lets it grow (its bed:
## farmland; still shallow water; a bank by water; soil under a trellis).
static func holds(cell: Vector3i, block: int, voxel_at: Callable) -> bool:
	var under: int = voxel_at.call(cell + Vector3i.DOWN)
	match bed_of(block):
		Bed.WATER:
			var bottom: int = voxel_at.call(cell + Vector3i.DOWN * 2)
			return (
				Voxels.is_water(under)
				and Fluids.level_of(under) == 0
				and (_soft(bottom) or is_farmland(bottom))
			)
		Bed.BANK:
			return (_soft(under) or is_farmland(under)) and by_water(cell + Vector3i.DOWN, voxel_at)
		Bed.TRELLIS:
			return Growth.is_soil(under) or is_farmland(under)
	return is_farmland(under)


## Whether water lies beside a cell (its four sides, on its row or the
## one under it).
static func by_water(cell: Vector3i, voxel_at: Callable) -> bool:
	for side: Vector2i in ObjectShapes.WAYS:
		for dy in 2:
			if Voxels.is_water(voxel_at.call(cell + Vector3i(side.x, -dy, side.y))):
				return true
	return false


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


## What breaking a crop gives: ripe, its harvest and seeds; else its seed
## (grapes: their trellis too).
static func harvest(block: int, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if bed_of(block) == Bed.TRELLIS:
		result.append(Vector2i(Items.Id.TRELLIS, 1))
	if not RIPE.has(block):
		result.append(Vector2i(SEED_OF[sown_of(block)], 1))
		return result
	var crop: Array = HARVEST[block]
	result.append(Vector2i(crop[0], rng.randi_range(crop[1], crop[2])))
	var seeds := rng.randi_range(crop[3], crop[4])
	if seeds > 0:
		result.append(Vector2i(SEED_OF[sown_of(block)], seeds))
	return result


## What a wild plant gives.
static func wild_harvest(block: int, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for gift: Array in WILD[block]:
		result.append(Vector2i(gift[0], rng.randi_range(gift[1], gift[2])))
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


## Farmland settles (Growth, every check): wet or dry by the water near
## (or `watered`: by a can, the rain); dry with nothing sown, it may go back
## to dirt (`odds` this time).
static func settle_farmland(
	server: GameServer, cell: Vector3i, voxel: int, odds: float, watered := false
) -> void:
	var world := server.world
	var wet := watered or wet_near(world, cell)
	var above := Voxels.block_of(world.loaded_voxel_at(cell + Vector3i.UP))
	if not wet and not is_crop(above) and server.rng.randf() < odds:
		server.change_voxel(cell, Voxels.of_ground(Tiles.Ground.DIRT))
		return
	var now := Voxels.of_ground(Tiles.Ground.FARMLAND_WET if wet else Tiles.Ground.FARMLAND)
	if now != voxel:
		server.change_voxel(cell, now)


## How long a crop takes on average to grow a stage (seconds, unpaced):
## longer on dry farmland (rice, sugar cane and vines are by water or
## rooted deep).
static func stage_seconds(world: WorldState, cell: Vector3i) -> float:
	var under := world.loaded_voxel_at(cell + Vector3i.DOWN)
	if under == Voxels.of_ground(Tiles.Ground.FARMLAND):
		return STAGE_SECONDS * DRY_SLOWER
	return STAGE_SECONDS


## A grown stem (FRUIT_OF) puts its fruit on one of the free tiles beside
## it (air or a small plant over soil, sand or farmland, nobody standing
## there); none while one of its fruits lies beside it.
static func bear_fruit(server: GameServer, cell: Vector3i, block: int) -> void:
	var world := server.world
	var fruit: int = FRUIT_OF[block]
	var free: Array[Vector3i] = []
	for side: Vector2i in ObjectShapes.WAYS:
		var at := cell + Vector3i(side.x, 0, side.y)
		var voxel := world.loaded_voxel_at(at)
		if Voxels.block_of(voxel) == fruit:
			return
		var under := world.loaded_voxel_at(at + Vector3i.DOWN)
		if (
			Mining.is_replaceable(voxel)
			and not Voxels.is_liquid(voxel)
			and (_soft(under) or is_farmland(under))
			and not Fixtures.someone_in(server, at)
		):
			free.append(at)
	if not free.is_empty():
		server.change_voxel(free[server.rng.randi() % free.size()], Voxels.of_block(fruit))


## Soil (Growth.is_soil) or a loose ground (LOOSE).
static func _soft(voxel: int) -> bool:
	return Growth.is_soil(voxel) or (voxel < Voxels.BLOCK_BASE and LOOSE.has(voxel))


static func _build_sown() -> Dictionary:
	var lookup := {}
	for first: int in SOWN:
		var stage := first
		lookup[stage] = first
		while STAGES.has(stage):
			stage = STAGES[stage]
			lookup[stage] = first
	return lookup
