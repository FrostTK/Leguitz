class_name ItemGroups
extends RefCounted
## Every item sorted into groups (static, shared: the creative catalog's
## tabs, the bag's filters, sorting a bag): Tab, the catalog's tabs
## (building blocks, stairs and roofs, nature, doors and windows,
## furniture, decoration, the farm, food, tools and gear, materials;
## `tab_of`), and Filter, the inventory's coarser filters (`filter_of`):
## tools, blocks (with stairs, roofs, doors and windows), food, nature
## (with the farm), the home (furniture and decoration), materials.

enum Tab { BLOCKS, SHAPES, NATURE, OPENINGS, FURNITURE, DECOR, FARM, FOOD, TOOLS, MATERIALS }
enum Filter { ALL, TOOLS, BLOCKS, FOOD, NATURE, HOME, MATERIALS }

## Each tab's filter.
const FILTER_OF := {
	Tab.BLOCKS: Filter.BLOCKS,
	Tab.SHAPES: Filter.BLOCKS,
	Tab.OPENINGS: Filter.BLOCKS,
	Tab.NATURE: Filter.NATURE,
	Tab.FARM: Filter.NATURE,
	Tab.FURNITURE: Filter.HOME,
	Tab.DECOR: Filter.HOME,
	Tab.FOOD: Filter.FOOD,
	Tab.TOOLS: Filter.TOOLS,
	Tab.MATERIALS: Filter.MATERIALS,
}
## The tools' tab besides the tools, the armor and the pots of paint: the
## bow, fishing, boats.
const GEAR := {
	Items.Id.BOW: true,
	Items.Id.ARROW: true,
	Items.Id.FISHING_ROD: true,
	Items.Id.FISHING_NET: true,
	Items.Id.WORM: true,
	Items.Id.BAIT_BALL: true,
	Items.Id.FISH_BAIT: true,
	Items.Id.FISH_TRAP: true,
	Items.Id.SHIPYARD: true,
	Items.Id.BOAT_BOW: true,
	Items.Id.BOAT_SECTION: true,
	Items.Id.BOAT_STERN: true,
	Items.Id.BOILER: true,
	Items.Id.PROPELLER: true,
	Items.Id.COAL_ENGINE: true,
	Items.Id.BOAT_BENCH: true,
}
## The farm's gear and what it gives that is not food.
const FARM_ITEMS := {
	Items.Id.WHEAT: true,
	Items.Id.FLAX: true,
	Items.Id.WATERING_CAN: true,
	Items.Id.SHEARS: true,
	Items.Id.BUCKET: true,
	Items.Id.LEAD: true,
	Items.Id.COMPOST: true,
	Items.Id.EGG: true,
}
## Wild plants (placing nothing), with nature.
const WILD := {
	Items.Id.FLOWER_RED: true,
	Items.Id.FLOWER_YELLOW: true,
	Items.Id.FLOWER_BLUE: true,
	Items.Id.FLOWER_WHITE: true,
	Items.Id.FLOWER_PINK: true,
	Items.Id.FERN: true,
	Items.Id.CACTUS: true,
	Items.Id.LILY_PAD: true,
}
## The cubes the world is made of (the others are building blocks).
const NATURAL_CUBES := {
	Tiles.Block.STONE: true,
	Tiles.Block.DEEPSLATE: true,
	Tiles.Block.SANDSTONE: true,
	Tiles.Block.PACKED_ICE: true,
}
## Doors and windows' tab besides doors, trapdoors, panes and windows, by
## kind.
const OPENING_KINDS := {
	Tiles.Block.LADDER: true,
	Tiles.Block.SHUTTERS: true,
	Tiles.Block.IRON_BARS: true,
	Tiles.Block.WOOD_RAILING: true,
	Tiles.Block.IRON_RAILING: true,
	Tiles.Block.FENCE: true,
	Tiles.Block.GATE: true,
	Tiles.Block.BIG_GATE: true,
}
## The farm's tab besides what is sown and saplings, by kind.
const FARM_KINDS := {
	Tiles.Block.PUMPKIN: true,
	Tiles.Block.COMPOSTER: true,
	Tiles.Block.TRELLIS: true,
	Tiles.Block.SCARECROW: true,
	Tiles.Block.BEEHIVE: true,
	Tiles.Block.NEST_BOX: true,
	Tiles.Block.TURTLE_EGGS: true,
}
## Decoration (the other things placed are furniture), by kind.
const DECOR_KINDS := {
	Tiles.Block.TORCH: true,
	Tiles.Block.TORCH_BRACKET: true,
	Tiles.Block.LANTERN: true,
	Tiles.Block.CAMPFIRE: true,
	Tiles.Block.CURTAINS: true,
	Tiles.Block.CURTAINS_LONG: true,
	Tiles.Block.CURTAINS_IRON: true,
	Tiles.Block.CURTAINS_LONG_IRON: true,
	Tiles.Block.RUG: true,
	Tiles.Block.CANDLE: true,
	Tiles.Block.CANDELABRA: true,
	Tiles.Block.CHANDELIER: true,
	Tiles.Block.BEDSIDE_LAMP: true,
	Tiles.Block.WALL_SCONCE: true,
	Tiles.Block.PAINTING: true,
	Tiles.Block.PORTRAIT: true,
	Tiles.Block.WALL_CLOCK: true,
	Tiles.Block.MIRROR: true,
	Tiles.Block.FRAMED_MAP: true,
	Tiles.Block.DEER_TROPHY: true,
	Tiles.Block.BEAR_TROPHY: true,
	Tiles.Block.TAPESTRY: true,
	Tiles.Block.SPICE_RACK: true,
	Tiles.Block.COAT_RACK: true,
	Tiles.Block.CUSHION: true,
	Tiles.Block.FLOWER_POT: true,
	Tiles.Block.WINDOW_BOX: true,
	Tiles.Block.HOUSEPLANT: true,
	Tiles.Block.FOLDING_SCREEN: true,
}

## Every tab's items (Items order within each; the tools' tab: tools, the
## bow and arrows, armor, the rest), and each item's place in that order.
static var _tabs := _sort()
static var _places := _number()


## Every item but the player's book, tab after tab.
static func order() -> Array[int]:
	var result: Array[int] = []
	for each: int in Tab.values():
		result.append_array(_tabs[each])
	return result


## The items of a tab.
static func items_of(which: Tab) -> Array[int]:
	return _tabs[which]


## The tab an item is in (see the class).
static func tab_of(item: int) -> Tab:
	if Items.TOOLS.has(item) or Armor.is_armor(item) or GEAR.has(item) or item in Items.PAINTS:
		return Tab.TOOLS
	if Items.is_food(item):
		return Tab.FOOD
	if FARM_ITEMS.has(item):
		return Tab.FARM
	var voxel := Items.placed_voxel(item)
	if voxel == Voxels.AIR:
		return Tab.NATURE if WILD.has(item) else Tab.MATERIALS
	var block := Voxels.block_of(voxel)
	if block == Tiles.Block.AIR:
		# A ground: dirt, sand, snow...
		return Tab.NATURE
	var kind := ObjectShapes.pair_of(ObjectShapes.base_kind(block))
	if (
		Tiles.is_shaped(block)
		or RoofBlocks.is_dormer(block)
		or BuildShapes.material_of(block) != Tiles.Block.AIR
		or block == Tiles.Block.CHIMNEY
	):
		return Tab.SHAPES
	if (
		Glass.is_window(block)
		or Glass.is_pane(block)
		or Openings.is_door(block)
		or Openings.is_trapdoor(block)
		or OPENING_KINDS.has(kind)
	):
		return Tab.OPENINGS
	if Tiles.is_cube(block):
		return Tab.NATURE if NATURAL_CUBES.has(block) else Tab.BLOCKS
	if Farming.SOWN.has(block) or Growth.SAPLINGS.has(block) or FARM_KINDS.has(kind):
		return Tab.FARM
	return Tab.DECOR if DECOR_KINDS.has(kind) else Tab.FURNITURE


## The filter an item is in.
static func filter_of(item: int) -> Filter:
	return FILTER_OF[tab_of(item)]


## Whether an item shows under a filter.
static func matches(item: int, filter: Filter) -> bool:
	return filter == Filter.ALL or filter_of(item) == filter


## An item's place in the catalog's order (tab after tab).
static func place_of(item: int) -> int:
	return _places.get(item, Items.Id.size())


static func _sort() -> Dictionary:
	var tabs := {}
	for each: int in Tab.values():
		var items: Array[int] = []
		tabs[each] = items
	for item in range(Items.Id.NONE + 1, Items.Id.size()):
		if item != Items.Id.GUIDE_BOOK:
			(tabs[tab_of(item)] as Array[int]).append(item)
	var gear: Array[int] = tabs[Tab.TOOLS]
	gear.sort_custom(func(a: int, b: int) -> bool: return _gear_rank(a) < _gear_rank(b))
	return tabs


## Where an item of the tools' tab goes in it.
static func _gear_rank(item: int) -> int:
	var group := 3
	if Items.TOOLS.has(item):
		group = 0
	elif item in [Items.Id.BOW, Items.Id.ARROW]:
		group = 1
	elif Armor.is_armor(item):
		group = 2
	return group * Items.Id.size() + item


static func _number() -> Dictionary:
	var places := {}
	var every := order()
	for at in every.size():
		places[every[at]] = at
	return places
