extends TestCase
## Sorting the bag (BagSort, the inventory's Sort button) and the item
## groups behind it and the bag's filters (ItemGroups).

const N := Items.Id.NONE


func test_the_bag_is_joined_and_laid_in_the_catalogs_order() -> void:
	var bag := Inventory.new()
	var dirt := Items.max_stack(Items.Id.DIRT)
	var put := [
		[Items.Id.DIRT, 20, 0],
		[Items.Id.BREAD, 3, 0],
		[Items.Id.DIRT, dirt - 5, 0],
		[Items.Id.IRON_PICKAXE, 1, 40],
		[Items.Id.IRON_PICKAXE, 1, 3],
		[Items.Id.BREAD, 2, 0],
	]
	for at in put.size():
		var slot := Inventory.HOTBAR + at * 3
		bag.items[slot] = put[at][0]
		bag.counts[slot] = put[at][1]
		bag.wear[slot] = put[at][2]
	bag.items[0] = Items.Id.TORCH
	bag.counts[0] = 7
	BagSort.sort(bag)
	assert_eq(bag.items[0], Items.Id.TORCH, "the hotbar stays")
	assert_eq(bag.counts[0], 7)
	var laid: Array = []
	for slot in range(Inventory.HOTBAR, Inventory.SLOTS):
		if bag.items[slot] != N:
			laid.append([bag.items[slot], bag.counts[slot], bag.wear[slot]])
	var expected: Array = [
		[Items.Id.IRON_PICKAXE, 1, 3],
		[Items.Id.IRON_PICKAXE, 1, 40],
		[Items.Id.BREAD, 5, 0],
		[Items.Id.DIRT, dirt, 0],
		[Items.Id.DIRT, 15, 0],
	]
	expected.sort_custom(
		func(a: Array, b: Array) -> bool:
			var first := ItemGroups.place_of(a[0])
			var second := ItemGroups.place_of(b[0])
			if first != second:
				return first < second
			return a[1] > b[1] if a[1] != b[1] else a[2] < b[2]
	)
	assert_eq(laid, expected, "stacks joined, in order, from the bag's first slot")
	var first: int = laid[0][0]
	for stack: Array in laid:
		assert_true(ItemGroups.place_of(first) <= ItemGroups.place_of(stack[0]))


func test_filters_hold_their_items() -> void:
	var filter := ItemGroups.Filter
	assert_eq(ItemGroups.filter_of(Items.Id.IRON_PICKAXE), filter.TOOLS)
	assert_eq(ItemGroups.filter_of(Items.Id.BREAD), filter.FOOD)
	assert_eq(ItemGroups.filter_of(Items.Id.OAK_PLANKS), filter.BLOCKS)
	assert_eq(ItemGroups.filter_of(Items.Id.OAK_DOOR), filter.BLOCKS)
	assert_eq(ItemGroups.filter_of(Items.Id.CHAIR), filter.HOME)
	assert_eq(ItemGroups.filter_of(Items.Id.WHEAT), filter.NATURE)
	assert_eq(ItemGroups.filter_of(Items.Id.IRON_INGOT), filter.MATERIALS)
	assert_true(ItemGroups.matches(Items.Id.CHAIR, filter.ALL))
	assert_false(ItemGroups.matches(Items.Id.CHAIR, filter.FOOD))
	for tab: int in ItemGroups.Tab.values():
		assert_true(ItemGroups.FILTER_OF.has(tab), "every tab has its filter")


func test_the_server_sorts_a_players_bag() -> void:
	var settings := WorldSettings.create("Test", "42", WorldSettings.GameMode.SURVIVAL)
	var server := GameServer.new(settings, null, false)
	var transports := LocalTransport.create_pair()
	server.connect_client(transports[1])
	transports[0].send(Msg.hello("Alex", 2))
	server.process_messages()
	var session := server.first_session()
	for slot in range(Inventory.HOTBAR, Inventory.SLOTS):
		session.inventory.items[slot] = N
		session.inventory.counts[slot] = 0
	session.inventory.items[Inventory.SLOTS - 1] = Items.Id.BREAD
	session.inventory.counts[Inventory.SLOTS - 1] = 4
	transports[0].poll()
	transports[0].send(Msg.sort_bag())
	server.process_messages()
	assert_eq(session.inventory.items[Inventory.HOTBAR], Items.Id.BREAD, "moved to the front")
	assert_eq(session.inventory.items[Inventory.SLOTS - 1], N)
	var told := false
	for message: Dictionary in transports[0].poll():
		told = told or message.get("t") == Msg.INVENTORY
	assert_true(told, "the player is told")
