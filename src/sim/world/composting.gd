class_name Composting
extends RefCounted
## Composters and compost, on the server (static, given the server). A
## composter (Tiles.Block.COMPOSTER and its stages, ObjectShapes.STAGE_OF)
## takes plant waste a piece at a time (`put`: COMPOSTABLE items, a level
## each), FILL pieces fill it; full, it rots into compost (on average after
## ROT_SECONDS, paced by WorldClock.scale_duration; Growth runs it, light
## or not), and ready, it gives a compost and empties (`put` again, with
## anything in hand). Compost spread on a crop or a sapling (`spread`)
## makes it grow a stage at once (Growth.next_stage: a tree still needs
## room).

## Pieces of waste a composter takes before it rots.
const FILL := 7
## How long (seconds, the default day's) a full composter takes to rot.
const ROT_SECONDS := 60.0
## Server: a composter or a crop is reached this far at most (local units).
const REACH_LEEWAY := 1.5
## The composter by level (0: empty, FILL: full and rotting), then ready.
const LEVELS: Array[int] = [
	Tiles.Block.COMPOSTER,
	Tiles.Block.COMPOSTER_1,
	Tiles.Block.COMPOSTER_2,
	Tiles.Block.COMPOSTER_3,
	Tiles.Block.COMPOSTER_4,
	Tiles.Block.COMPOSTER_5,
	Tiles.Block.COMPOSTER_6,
	Tiles.Block.COMPOSTER_FULL,
]
## What goes into a composter: plants, seeds, what grows on the farm,
## bread and the food that went wrong.
const COMPOSTABLE := {
	Items.Id.SEEDS: true,
	Items.Id.BERRIES: true,
	Items.Id.DRIED_BERRIES: true,
	Items.Id.FLOWER_RED: true,
	Items.Id.FLOWER_YELLOW: true,
	Items.Id.FLOWER_BLUE: true,
	Items.Id.FLOWER_WHITE: true,
	Items.Id.FLOWER_PINK: true,
	Items.Id.MUSHROOM_RED: true,
	Items.Id.MUSHROOM_BROWN: true,
	Items.Id.MUSHROOM_STEW: true,
	Items.Id.CACTUS: true,
	Items.Id.SUGAR_CANE: true,
	Items.Id.LILY_PAD: true,
	Items.Id.SEAWEED: true,
	Items.Id.FERN: true,
	Items.Id.OAK_SAPLING: true,
	Items.Id.BIRCH_SAPLING: true,
	Items.Id.SPRUCE_SAPLING: true,
	Items.Id.DARK_OAK_SAPLING: true,
	Items.Id.JUNGLE_SAPLING: true,
	Items.Id.ACACIA_SAPLING: true,
	Items.Id.SWAMP_OAK_SAPLING: true,
	Items.Id.WHEAT: true,
	Items.Id.CARROT: true,
	Items.Id.POTATO: true,
	Items.Id.BAKED_POTATO: true,
	Items.Id.DOUGH: true,
	Items.Id.BREAD: true,
	Items.Id.CHARRED_FOOD: true,
	Items.Id.BEETROOT_SEEDS: true,
	Items.Id.BEETROOT: true,
	Items.Id.CABBAGE_SEEDS: true,
	Items.Id.CABBAGE: true,
	Items.Id.CORN: true,
	Items.Id.ROASTED_CORN: true,
	Items.Id.TOMATO_SEEDS: true,
	Items.Id.TOMATO: true,
	Items.Id.STRAWBERRY: true,
	Items.Id.FLAX_SEEDS: true,
	Items.Id.FLAX: true,
	Items.Id.PUMPKIN_SEEDS: true,
	Items.Id.PUMPKIN: true,
	Items.Id.MELON_SEEDS: true,
	Items.Id.MELON_SLICE: true,
	Items.Id.RICE: true,
	Items.Id.COOKED_RICE: true,
	Items.Id.GRAPE_SEEDS: true,
	Items.Id.GRAPES: true,
	Items.Id.APPLE: true,
	Items.Id.APPLE_SEEDS: true,
	Items.Id.CHERRIES: true,
	Items.Id.CHERRY_PITS: true,
	Items.Id.ORANGE: true,
	Items.Id.ORANGE_SEEDS: true,
	Items.Id.RASPBERRY: true,
	Items.Id.PEACH: true,
	Items.Id.PEACH_PIT: true,
}


static func is_composter(block: int) -> bool:
	return ObjectShapes.base_kind(block) == Tiles.Block.COMPOSTER


## How full a composter is (0 to FILL; FILL + 1: ready; -1: not one).
static func level_of(block: int) -> int:
	if block == Tiles.Block.COMPOSTER_READY:
		return FILL + 1
	return LEVELS.find(block)


## What using a composter with `item` in hand makes of it ({} if nothing
## happens): ready, it empties (a compost comes out: "compost"); with
## waste in hand and room left, it fills a level ("used": the item goes).
static func use(block: int, item: int) -> Dictionary:
	var level := level_of(block)
	if level == FILL + 1:
		return {"block": Tiles.Block.COMPOSTER, "compost": true}
	if level < 0 or level >= FILL or not COMPOSTABLE.has(item):
		return {}
	return {"block": LEVELS[level + 1], "used": true}


## What compost spread on a voxel makes it (Voxels.AIR: nothing): an
## unripe crop its next stage, a sapling or a young tree what it grows into
## if it has room, a fruit tree in blossom its fruit.
static func spread_on(world: WorldState, cell: Vector3i, voxel: int) -> int:
	if not takes_compost(Voxels.block_of(voxel)):
		return Voxels.AIR
	var tile := Vector2i(cell.x, cell.z)
	var chunk: ChunkData = world.chunks.get(Coords.tile_to_chunk(tile))
	if chunk == null:
		return Voxels.AIR
	var next := Growth.next_stage(world, chunk, cell, voxel)
	return Voxels.AIR if next == voxel else next


## Whether compost makes a block grow (see spread_on).
static func takes_compost(block: int) -> bool:
	return (
		Farming.STAGES.has(block)
		or Growth.SAPLINGS.has(block)
		or Growth.YOUNG.has(block)
		or Growth.FRUITING.has(block)
	)


## What a client may guess compost spread makes (a crop's next stage; a
## tree's room is the server's to say: Voxels.AIR).
static func guess_spread(voxel: int) -> int:
	var block := Voxels.block_of(voxel)
	return Voxels.of_block(Farming.STAGES[block]) if Farming.STAGES.has(block) else Voxels.AIR


## A player used a composter at `cell` with hotbar slot `slot` in hand
## (Msg.COMPOST): a piece of waste goes in (not used up in creative), or the
## compost ready comes out (into the slots, else at their feet). Refused,
## they are told what is there.
static func put(server: GameServer, session: GameServer.PlayerSession, message: Dictionary) -> void:
	if not session.joined or not session.alive():
		return
	var cell: Vector3i = message.get("cell", Vector3i.ZERO)
	var slot := clampi(int(message.get("slot", 0)), 0, Inventory.HOTBAR - 1)
	var bag := session.inventory
	var voxel := server.world.voxel_at(cell)
	var near := Mining.reach_to(session.position, session.height, cell)
	var done := use(Voxels.block_of(voxel), bag.items[slot])
	if done.is_empty() or near > Mining.REACH + REACH_LEEWAY:
		session.transport.send(Msg.block_changed(cell, voxel))
		session.transport.send(Msg.inventory(bag))
		return
	server.change_voxel(cell, Voxels.of_block(done["block"]))
	if done.get("used", false) and not GameModes.creative(server):
		bag.take(slot, 1)
	if done.get("compost", false) and bag.add(Items.Id.COMPOST, 1) > 0:
		server.throw_item(session, Items.Id.COMPOST, 1)
	session.transport.send(Msg.inventory(bag))


## A player spread the compost of hotbar slot `slot` on `cell`
## (Msg.SPREAD_COMPOST): an unripe crop or a sapling within reach grows a
## stage (the compost goes, but in creative). Refused, they are told what
## is there.
static func spread(
	server: GameServer, session: GameServer.PlayerSession, message: Dictionary
) -> void:
	if not session.joined or not session.alive():
		return
	var cell: Vector3i = message.get("cell", Vector3i.ZERO)
	var slot := clampi(int(message.get("slot", 0)), 0, Inventory.HOTBAR - 1)
	var bag := session.inventory
	var voxel := server.world.voxel_at(cell)
	var near := Mining.reach_to(session.position, session.height, cell)
	var next := Voxels.AIR
	if bag.items[slot] == Items.Id.COMPOST and near <= Mining.REACH + REACH_LEEWAY:
		next = spread_on(server.world, cell, voxel)
	if next == Voxels.AIR:
		session.transport.send(Msg.block_changed(cell, voxel))
		session.transport.send(Msg.inventory(bag))
		return
	server.change_voxel(cell, next)
	if not GameModes.creative(server):
		bag.take(slot, 1)
	session.transport.send(Msg.inventory(bag))
