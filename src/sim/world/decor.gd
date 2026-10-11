class_name Decor
extends RefCounted
## A house's ambiance (phase 8, step 8; static tables and rules, shared;
## models: AmbianceModels, WallDecorModels). Lights switched on and off by
## hand (SWITCHED: a candle, a candelabra, a chandelier hung from a
## ceiling, a bedside lamp, a wall sconce; a shower runs or not:
## Mining.swings, ObjectShapes.swung). Small things standing on a floor or
## on furniture (ON_FURNITURE: drawn down onto its top, `sink`). Pictures
## to choose (PICTURES: a right click, Msg.TURN_PICTURE, shows the next;
## the look is kept in the cell's tint, Tints' frame bits; a tile's own
## until then). A flower pot holds a plant (POTTED: a shelf of one,
## Shelves; its model's version shows it). What the client brings to life
## (LIVE: clocks' hands, a map of the surroundings, a running shower:
## LiveProps). Hearths burn (Hearths).

const MESSAGES: Array[String] = [Msg.TURN_PICTURE]
## Lights and a shower: their kind as placed and their other state.
const SWITCHED := {
	Tiles.Block.CANDLE: Tiles.Block.CANDLE_OUT,
	Tiles.Block.CANDELABRA: Tiles.Block.CANDELABRA_OUT,
	Tiles.Block.CHANDELIER: Tiles.Block.CHANDELIER_OUT,
	Tiles.Block.BEDSIDE_LAMP: Tiles.Block.BEDSIDE_LAMP_OFF,
	Tiles.Block.WALL_SCONCE: Tiles.Block.WALL_SCONCE_OUT,
	Tiles.Block.SHOWER: Tiles.Block.SHOWER_ON,
}
## Small things standing on a floor or on the top of furniture, by kind.
const ON_FURNITURE := {
	Tiles.Block.CANDLE: true,
	Tiles.Block.CANDLE_OUT: true,
	Tiles.Block.CANDELABRA: true,
	Tiles.Block.CANDELABRA_OUT: true,
	Tiles.Block.BEDSIDE_LAMP: true,
	Tiles.Block.BEDSIDE_LAMP_OFF: true,
	Tiles.Block.FLOWER_POT: true,
}
## Pictures to choose from, by kind: how many.
const PICTURES := {Tiles.Block.PAINTING: 8, Tiles.Block.PORTRAIT: 8}
## Other kinds with versions of their own (by tile): a window box's
## flowers, a house plant.
const VERSIONS := {Tiles.Block.WINDOW_BOX: 3, Tiles.Block.HOUSEPLANT: 3}
## What goes in a flower pot: the item and the plant it shows (a block
## whose model is shown smaller in the pot).
const POTTED := {
	Items.Id.FLOWER_RED: Tiles.Block.FLOWER_RED,
	Items.Id.FLOWER_YELLOW: Tiles.Block.FLOWER_YELLOW,
	Items.Id.FLOWER_BLUE: Tiles.Block.FLOWER_BLUE,
	Items.Id.FLOWER_WHITE: Tiles.Block.FLOWER_WHITE,
	Items.Id.FLOWER_PINK: Tiles.Block.FLOWER_PINK,
	Items.Id.MUSHROOM_RED: Tiles.Block.MUSHROOM_RED,
	Items.Id.MUSHROOM_BROWN: Tiles.Block.MUSHROOM_BROWN,
	Items.Id.FERN: Tiles.Block.FERN,
	Items.Id.OAK_SAPLING: Tiles.Block.OAK_SAPLING,
	Items.Id.BIRCH_SAPLING: Tiles.Block.BIRCH_SAPLING,
	Items.Id.SPRUCE_SAPLING: Tiles.Block.SPRUCE_SAPLING,
	Items.Id.DARK_OAK_SAPLING: Tiles.Block.DARK_OAK_SAPLING,
	Items.Id.JUNGLE_SAPLING: Tiles.Block.JUNGLE_SAPLING,
	Items.Id.ACACIA_SAPLING: Tiles.Block.ACACIA_SAPLING,
	Items.Id.SWAMP_OAK_SAPLING: Tiles.Block.SWAMP_OAK_SAPLING,
	Items.Id.APPLE_SEEDS: Tiles.Block.APPLE_SAPLING,
	Items.Id.CHERRY_PITS: Tiles.Block.CHERRY_SAPLING,
	Items.Id.ORANGE_SEEDS: Tiles.Block.ORANGE_SAPLING,
	Items.Id.PEACH_PIT: Tiles.Block.PEACH_SAPLING,
}
## What the client brings to life (LiveProps), by kind.
const LIVE := {
	Tiles.Block.WALL_CLOCK: true,
	Tiles.Block.GRANDFATHER_CLOCK: true,
	Tiles.Block.FRAMED_MAP: true,
	Tiles.Block.SHOWER_ON: true,
}
## The facing kinds (ObjectShapes builds them by name).
const FACING := [
	Tiles.Block.WALL_SCONCE,
	Tiles.Block.WALL_SCONCE_OUT,
	Tiles.Block.FIREPLACE,
	Tiles.Block.FIREPLACE_LIT,
	Tiles.Block.STOVE,
	Tiles.Block.STOVE_LIT,
	Tiles.Block.PAINTING,
	Tiles.Block.PORTRAIT,
	Tiles.Block.WALL_CLOCK,
	Tiles.Block.MIRROR,
	Tiles.Block.FRAMED_MAP,
	Tiles.Block.DEER_TROPHY,
	Tiles.Block.BEAR_TROPHY,
	Tiles.Block.TAPESTRY,
	Tiles.Block.SPICE_RACK,
	Tiles.Block.COAT_RACK,
	Tiles.Block.WINDOW_BOX,
	Tiles.Block.BATHTUB,
	Tiles.Block.SHOWER,
	Tiles.Block.SHOWER_ON,
	Tiles.Block.WASHBASIN,
	Tiles.Block.GRANDFATHER_CLOCK,
	Tiles.Block.TOY_CHEST,
	Tiles.Block.PIANO,
	Tiles.Block.CRADLE,
	Tiles.Block.FOLDING_SCREEN,
]


## A light or a shower, either way (see SWITCHED).
static func is_switch(block: int) -> bool:
	var kind := ObjectShapes.base_kind(block)
	return SWITCHED.has(kind) or SWITCHED.values().has(kind)


static func is_picture(block: int) -> bool:
	return PICTURES.has(ObjectShapes.kind_of(block))


static func is_pot(block: int) -> bool:
	return block == Tiles.Block.FLOWER_POT


static func is_live(block: int) -> bool:
	return LIVE.has(ObjectShapes.base_kind(block))


## How many versions a block's model has here (0: not one of these): its
## pictures, a pot empty then with each plant, a window box's flowers.
static func versions(block: int) -> int:
	var kind := ObjectShapes.base_kind(block)
	if is_pot(block):
		return 1 + POTTED.size()
	return PICTURES.get(kind, VERSIONS.get(kind, 0))


## The version of a picture shown (`packed`: its cell's tint, the look
## chosen; else `own`, its tile's).
static func picture(packed: int, own: int) -> int:
	var look := Tints.frame_of(packed)
	return look if look >= 0 else own


## The version of a pot holding `items` (a shelf's: none, empty).
static func pot_version(items: PackedInt32Array) -> int:
	if items.is_empty() or items[0] == Items.Id.NONE:
		return 0
	return POTTED.keys().find(items[0]) + 1


## How high the top of what stands under something is (levels from its
## cell's floor): a cube's whole level, furniture's top (a tall one's top
## cell: its whole level); 0: nothing to stand on.
static func rest_height(below: int) -> float:
	if Voxels.is_cube(below):
		return 1.0
	var block := Voxels.block_of(below)
	if Furniture.is_top(block):
		return 1.0
	var top := ObjectShapes.stand_height(block)
	return top if top <= 1.0 else 0.0


## How far down (levels) a small thing standing on furniture is drawn
## (`below`: the voxel under it): onto its top.
static func sink(block: int, below: int) -> float:
	if not ON_FURNITURE.has(ObjectShapes.base_kind(block)):
		return 0.0
	var rest := rest_height(below)
	return 1.0 - rest if rest > 0.0 else 0.0


## Whether Decor places a block (placement): a chandelier, what stands on
## furniture.
static func places(block: int) -> bool:
	return ON_FURNITURE.has(block) or block == Tiles.Block.CHANDELIER


## Where a block placed in `cell` goes ({cell: voxel}; empty: nowhere). A
## chandelier hangs from a ceiling: aimed at its underside (`face` DOWN),
## else from the first one over the cell (Mining.under_ceiling); small
## things stand on a floor or on furniture.
static func placement(cell: Vector3i, voxel: int, face: Vector3i, voxel_at: Callable) -> Dictionary:
	if Voxels.block_of(voxel) == Tiles.Block.CHANDELIER:
		var spot := cell if face.y < 0 else Mining.under_ceiling(cell, voxel_at)
		if spot == Vector3i.MAX or not Voxels.is_cube(voxel_at.call(spot + Vector3i.UP)):
			return {}
		var free: int = voxel_at.call(spot)
		return {spot: voxel} if Mining.is_replaceable(free) and not Voxels.is_liquid(free) else {}
	var there: int = voxel_at.call(cell)
	if not Mining.takes(there) or Voxels.is_liquid(there):
		return {}
	return {cell: voxel} if rest_height(voxel_at.call(cell + Vector3i.DOWN)) > 0.0 else {}


## Msg.TURN_PICTURE: a picture within reach shows the next one (its look
## kept in its cell's tint). False: not this message.
static func handle(
	server: GameServer, session: GameServer.PlayerSession, message: Dictionary
) -> bool:
	if not message.get("t") in MESSAGES:
		return false
	var cell: Vector3i = message.get("cell", Vector3i.ZERO)
	var block := Voxels.block_of(server.world.voxel_at(cell))
	var near := Mining.reach_to(session.position, session.height, cell)
	if not session.joined or not session.alive() or not is_picture(block):
		return true
	if near > Mining.REACH + GameServer.REACH_LEEWAY:
		return true
	var own := ObjectShapes.variant_at(block, Vector2i(cell.x, cell.z))
	var shown := picture(Tints.at(server.world, cell), own)
	var count: int = PICTURES[ObjectShapes.kind_of(block)]
	Tints.set_tint(server, cell, Tints.pack(-1, (shown + 1) % count))
	return true
