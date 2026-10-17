extends TestCase
## The creative catalog's tabs and search (CreativeCatalog): every item in
## one tab, where things go, names found in either language, case and
## accents aside, several words at once.

const TAB := ItemGroups.Tab


func test_every_item_is_in_one_tab() -> void:
	var seen := {}
	for tab: int in TAB.values():
		var items := ItemGroups.items_of(tab)
		assert_false(items.is_empty(), "%s has items" % TAB.find_key(tab))
		for item in items:
			assert_false(seen.has(item), "%d in one tab only" % item)
			seen[item] = true
			assert_eq(ItemGroups.tab_of(item), tab)
	assert_eq(seen.size(), Items.Id.size() - 2, "every item but the book")
	assert_false(seen.has(Items.Id.GUIDE_BOOK))
	for tab: int in CreativeCatalog.TABS:
		var on_it: int = CreativeCatalog.TABS[tab][1]
		assert_eq(ItemGroups.tab_of(on_it), tab, "a tab shows one of its own")
		var key: String = CreativeCatalog.TABS[tab][0]
		assert_ne(tr(key), key, "%s named" % key)


func test_where_things_go() -> void:
	var expected := {
		Items.Id.OAK_PLANKS: TAB.BLOCKS,
		Items.Id.GLASS: TAB.BLOCKS,
		Items.Id.OAK_STAIRS: TAB.SHAPES,
		Items.Id.TILE_ROOF_RIDGE: TAB.SHAPES,
		Items.Id.COBBLESTONE_WALL: TAB.SHAPES,
		Items.Id.DIRT: TAB.NATURE,
		Items.Id.STONE: TAB.NATURE,
		Items.Id.FLOWER_BLUE: TAB.NATURE,
		Items.Id.OAK_DOOR: TAB.OPENINGS,
		Items.Id.WINDOW: TAB.OPENINGS,
		Items.Id.FENCE: TAB.OPENINGS,
		Items.Id.BED: TAB.FURNITURE,
		Items.Id.WORKBENCH: TAB.FURNITURE,
		Items.Id.BATHTUB: TAB.FURNITURE,
		Items.Id.CANDLE: TAB.DECOR,
		Items.Id.CURTAINS: TAB.DECOR,
		Items.Id.PAINTING: TAB.DECOR,
		Items.Id.SEEDS: TAB.FARM,
		Items.Id.OAK_SAPLING: TAB.FARM,
		Items.Id.BEEHIVE: TAB.FARM,
		Items.Id.WATERING_CAN: TAB.FARM,
		Items.Id.BREAD: TAB.FOOD,
		Items.Id.RAW_FISH: TAB.FOOD,
		Items.Id.IRON_PICKAXE: TAB.TOOLS,
		Items.Id.IRON_HELMET: TAB.TOOLS,
		Items.Id.FISHING_ROD: TAB.TOOLS,
		Items.Id.PAINT_RED: TAB.TOOLS,
		Items.Id.IRON_INGOT: TAB.MATERIALS,
		Items.Id.STICK: TAB.MATERIALS,
		Items.Id.OAK_LOG: TAB.MATERIALS,
	}
	for item: int in expected:
		assert_eq(ItemGroups.tab_of(item), expected[item], String(Items.Id.find_key(item)))
	var tools := ItemGroups.items_of(TAB.TOOLS)
	assert_true(tools.find(Items.Id.DIAMOND_HOE) < tools.find(Items.Id.BOW), "tools first")
	assert_true(tools.find(Items.Id.ARROW) < tools.find(Items.Id.HIDE_HELMET), "then the bow")


func test_names_are_found_in_either_language() -> void:
	var french := CreativeCatalog.search("chêne")
	assert_false(french.is_empty())
	assert_eq(french[0], Items.Id.OAK_PLANKS, "what begins so first")
	assert_true(Items.Id.OAK_DOOR in french, "and what holds it")
	assert_eq(CreativeCatalog.search("CHENE"), french, "case and accents aside")
	var english := CreativeCatalog.search("oak planks")
	assert_eq(english[0], Items.Id.OAK_PLANKS, "in English too")
	var both := CreativeCatalog.search("porte chene")
	assert_true(Items.Id.OAK_DOOR in both, "every word")
	assert_false(Items.Id.OAK_PLANKS in both, "not just one")
	assert_true(CreativeCatalog.search("xyzzy").is_empty(), "nothing by that name")
	assert_true(CreativeCatalog.search("   ").is_empty(), "nothing typed")
	assert_false(Items.Id.GUIDE_BOOK in CreativeCatalog.search("livre"), "never the book")
