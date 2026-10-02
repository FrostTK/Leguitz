extends TestCase
## Combat: swords and their recipes, armor (its own slots, what it takes
## off monsters' blows, its wear, lost when passing out), the bow and its
## arrows (used up, hurting what they meet, falling where they land).

const N := Items.Id.NONE
const SEA := GameConst.SEA_LEVEL
const TS := GameConst.TILE_SIZE


## Returns [server, client transport, session] with a joined player, no
## animals around, standing on a flat stone floor with room above.
func _joined(mode := WorldSettings.GameMode.SURVIVAL) -> Array:
	var settings := WorldSettings.create("Test", "42", mode)
	var server := GameServer.new(settings, null, false)
	var transports := LocalTransport.create_pair()
	server.connect_client(transports[1])
	transports[0].send(Msg.hello("Alex", 2))
	server.process_messages()
	transports[0].poll()
	var session := server.first_session()
	server.creatures.living.clear()
	var tile := Coords.world_to_tile(session.position)
	var floor_row := floori(session.height + 0.01) + SEA
	for x in range(-3, 10):
		for z in range(-3, 4):
			var cell := Vector3i(tile.x + x, floor_row, tile.y + z)
			server.world.set_voxel(cell - Vector3i(0, 1, 0), Voxels.of_block(Tiles.Block.STONE))
			for up in 4:
				server.world.set_voxel(cell + Vector3i(0, up, 0), Voxels.AIR)
	session.height = floor_row - SEA
	return [server, transports[0], session]


## A grid `width` cells across with `rows` (one character per cell; a
## space is empty) filled from the top left with `items` by character.
func _grid(rows: Array, items: Dictionary, width: int) -> PackedInt32Array:
	var cells := PackedInt32Array()
	cells.resize(width * width)
	cells.fill(N)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if row[x] != " ":
				cells[y * width + x] = items[row[x]]
	return cells


func _wear_all(bag: Inventory, items: Array) -> void:
	for piece in Armor.PIECES:
		bag.items[Inventory.ARMOR + piece] = items[piece]
		bag.counts[Inventory.ARMOR + piece] = 1


func test_swords_hit_hardest_and_are_made_at_the_workbench() -> void:
	for tier in Items.Tier.size():
		var tools := Items.tools_of_tier(tier)
		var swords := tools.filter(
			func(item: int) -> bool: return Items.tool_of(item) == Items.Tool.SWORD
		)
		assert_eq(swords.size(), 1, "a sword of each material")
		for tool: int in tools:
			assert_true(Combat.damage_of(swords[0]) >= Combat.damage_of(tool), "the hardest")
		assert_eq(Items.max_stack(swords[0]), 1)
	assert_true(Combat.damage_of(Items.Id.DIAMOND_SWORD) > Combat.damage_of(Items.Id.WOODEN_SWORD))
	var made := {"M": Items.Id.IRON_INGOT, "S": Items.Id.STICK}
	var sword := _grid(["M", "M", "S"], made, 5)
	assert_eq(Recipes.result_of(sword, 5), Vector2i(Items.Id.IRON_SWORD, 1))
	assert_eq(Recipes.result_of(_grid(["M", "M", "S"], made, 3), 3), Vector2i.ZERO, "workbench")


func test_bows_arrows_string_and_armor_have_recipes() -> void:
	var string := _grid(["W"], {"W": Items.Id.WOOL}, 3)
	assert_eq(Recipes.result_of(string, 3), Vector2i(Items.Id.STRING, 4), "wool spun")
	var fletched := {"P": Items.Id.STONE, "S": Items.Id.STICK, "F": Items.Id.FEATHER}
	assert_eq(Recipes.result_of(_grid(["P", "S", "F"], fletched, 3), 3).x, Items.Id.ARROW)
	var bow := _grid([" SR", "S R", " SR"], {"S": Items.Id.STICK, "R": Items.Id.STRING}, 5)
	assert_eq(Recipes.result_of(bow, 5), Vector2i(Items.Id.BOW, 1))
	for item: int in Armor.ITEMS:
		var material: int = Armor.MADE_OF[Armor.material_of(item)]
		var shape: Array = Armor.PATTERNS[Armor.piece_of(item)]
		var cells := _grid(shape, {"M": material}, 5)
		assert_eq(Recipes.result_of(cells, 5), Vector2i(item, 1), Items.name_key(item))
		assert_eq(Items.max_stack(item), 1)
		assert_true(Items.durability(item) > 0, "it wears")
	var hide_set := 0
	var diamond_set := 0
	for item: int in Armor.ITEMS:
		if Armor.material_of(item) == Armor.Kind.HIDE:
			hide_set += Armor.points_of(item)
		elif Armor.material_of(item) == Armor.Kind.DIAMOND:
			diamond_set += Armor.points_of(item)
	assert_eq(hide_set, 7)
	assert_eq(diamond_set, VitalsBar.MAX_DEFENSE, "a whole diamond armor fills the gauge")


func test_armor_goes_on_in_its_own_slot() -> void:
	var bag := Inventory.new()
	var helmet_slot := Inventory.ARMOR + Armor.Piece.HELMET
	var chest_slot := Inventory.ARMOR + Armor.Piece.CHESTPLATE
	bag.items[Inventory.CURSOR] = Items.Id.IRON_CHESTPLATE
	bag.counts[Inventory.CURSOR] = 1
	bag.click(helmet_slot, false, false)
	assert_eq(bag.items[helmet_slot], N, "a chestplate is no helmet")
	assert_eq(bag.items[Inventory.CURSOR], Items.Id.IRON_CHESTPLATE)
	bag.click(chest_slot, false, false)
	assert_eq(bag.items[chest_slot], Items.Id.IRON_CHESTPLATE, "on")
	assert_eq(bag.items[Inventory.CURSOR], N)
	assert_eq(Armor.defense(bag), 6)
	# Shift from the slots: on if its slot is free.
	bag.add(Items.Id.HIDE_BOOTS, 1)
	bag.add(Items.Id.GOLDEN_CHESTPLATE, 1)
	var boots := bag.items.find(Items.Id.HIDE_BOOTS)
	bag.click(boots, false, true)
	assert_eq(bag.items[Inventory.ARMOR + Armor.Piece.BOOTS], Items.Id.HIDE_BOOTS)
	var gold := bag.items.find(Items.Id.GOLDEN_CHESTPLATE)
	bag.click(gold, false, true)
	assert_eq(bag.items[chest_slot], Items.Id.IRON_CHESTPLATE, "taken: it stays in the slots")
	assert_true(bag.items.find(Items.Id.GOLDEN_CHESTPLATE) < Inventory.SLOTS)
	# Off: by hand, or shift into the slots.
	bag.click(chest_slot, false, true)
	assert_eq(bag.items[chest_slot], N)
	assert_true(bag.items.find(Items.Id.IRON_CHESTPLATE) < Inventory.SLOTS, "back in the slots")
	bag.click(Inventory.ARMOR + Armor.Piece.BOOTS, false, false)
	assert_eq(bag.items[Inventory.CURSOR], Items.Id.HIDE_BOOTS, "taken off by hand")
	assert_eq(Armor.defense(bag), 0)
	# Saved with the rest.
	_wear_all(bag, [Items.Id.IRON_HELMET, N, N, Items.Id.DIAMOND_BOOTS])
	bag.wear[Inventory.ARMOR] = 5
	var again := Inventory.new()
	again.load_dict(bag.to_dict())
	assert_eq(again.items[Inventory.ARMOR], Items.Id.IRON_HELMET)
	assert_eq(again.wear[Inventory.ARMOR], 5)
	assert_eq(Armor.defense(again), 5)


func test_armor_softens_monsters_blows_and_wears() -> void:
	var setup := _joined()
	var server: GameServer = setup[0]
	var session: GameServer.PlayerSession = setup[2]
	var bag := session.inventory
	var iron := [
		Items.Id.IRON_HELMET,
		Items.Id.IRON_CHESTPLATE,
		Items.Id.IRON_LEGGINGS,
		Items.Id.IRON_BOOTS,
	]
	_wear_all(bag, iron)
	assert_eq(Armor.defense(bag), 15)
	assert_almost(Armor.reduce(10.0, 15), 4.0, 0.001, "60% off")
	assert_almost(Armor.reduce(10.0, 40), 2.0, 0.001, "80% at most")
	# 2 points through 60%: 0.8, carried to the next blow.
	server.hurt(session, 2, Vitals.Cause.LURKER)
	assert_eq(session.health, Vitals.MAX_HEALTH, "nothing yet")
	session.immune = 0.0
	server.hurt(session, 2, Vitals.Cause.LURKER)
	assert_eq(session.health, Vitals.MAX_HEALTH - 1, "the leftovers add up")
	for piece in Armor.PIECES:
		assert_eq(bag.wear[Inventory.ARMOR + piece], 2, "every piece wore twice")
	session.immune = 0.0
	server.hurt(session, 3, Vitals.Cause.FALL)
	assert_eq(session.health, Vitals.MAX_HEALTH - 4, "falls go through armor")
	assert_eq(bag.wear[Inventory.ARMOR], 2)
	# Worn out, a piece breaks.
	bag.wear[Inventory.ARMOR] = Items.durability(Items.Id.IRON_HELMET) - 1
	session.immune = 0.0
	server.hurt(session, 3, Vitals.Cause.MIMIC)
	assert_eq(bag.items[Inventory.ARMOR], N, "the helmet broke")
	assert_eq(bag.items[Inventory.ARMOR + 1], Items.Id.IRON_CHESTPLATE)


func test_passing_out_drops_the_armor_too() -> void:
	var setup := _joined()
	var server: GameServer = setup[0]
	var session: GameServer.PlayerSession = setup[2]
	_wear_all(session.inventory, [Items.Id.HIDE_HELMET, N, N, Items.Id.GOLDEN_BOOTS])
	session.health = 1
	server.hurt(session, 5, Vitals.Cause.FALL)
	assert_false(session.alive())
	assert_eq(Armor.defense(session.inventory), 0, "nothing worn left")
	var lying := server.items.values().map(func(d: DroppedItem) -> int: return d.item)
	assert_true(Items.Id.HIDE_HELMET in lying, "it lies there")
	assert_true(Items.Id.GOLDEN_BOOTS in lying)


func test_a_bow_shoots_arrows_that_hurt_and_fall_where_they_land() -> void:
	var setup := _joined()
	var server: GameServer = setup[0]
	var client: LocalTransport = setup[1]
	var session: GameServer.PlayerSession = setup[2]
	var bag := session.inventory
	bag.items[0] = Items.Id.BOW
	bag.counts[0] = 1
	bag.items[4] = Items.Id.ARROW
	bag.counts[4] = 3
	var sheep := server.creatures.add(
		Species.Id.SHEEP, session.position + Vector2(5.0 * TS, 0.0), session.height
	)
	var feet := session.position / TS
	var origin := Vector3(feet.x, session.height + Archery.CHEST, feet.y)
	client.send(Msg.shoot(0, sheep.bounds().get_center() - origin, 1.0))
	server.process_messages()
	assert_eq(server.archery.arrows.size(), 1, "it flies")
	assert_eq(bag.counts[4], 2, "an arrow used")
	assert_eq(bag.wear[0], 1, "the bow wears")
	var said := client.poll().map(func(m: Dictionary) -> String: return m["t"])
	assert_true(Msg.ARROW_SPAWN in said, "everyone sees it")
	for i in 20:
		server.archery.update(server, GameConst.TICK_DELTA)
	assert_true(server.archery.arrows.is_empty(), "it met the sheep")
	assert_eq(sheep.health, Species.HEALTH[Species.Id.SHEEP] - int(Archery.DAMAGE), "hurt")
	assert_true(Msg.ARROW_REMOVE in client.poll().map(func(m: Dictionary) -> String: return m["t"]))
	# Not twice at once.
	server.tick_count += ceili(Archery.SHOT_PAUSE / GameConst.TICK_DELTA) + 1
	client.send(Msg.shoot(0, Vector3(1.0, -1.0, 0.0), 1.0))
	client.send(Msg.shoot(0, Vector3(1.0, -1.0, 0.0), 1.0))
	server.process_messages()
	assert_eq(bag.counts[4], 1, "one shot")
	for i in 20:
		server.archery.update(server, GameConst.TICK_DELTA)
	assert_true(server.archery.arrows.is_empty(), "it met the floor")
	var lying := server.items.values().map(func(d: DroppedItem) -> int: return d.item)
	assert_true(Items.Id.ARROW in lying, "it fell there, to be picked up")
	# Without a bow in the slot named, or without arrows, nothing.
	server.tick_count += 100
	client.send(Msg.shoot(4, Vector3.FORWARD, 1.0))
	server.process_messages()
	assert_true(server.archery.arrows.is_empty(), "arrows are not a bow")
	bag.take(4, 1)
	client.send(Msg.shoot(0, Vector3.FORWARD, 1.0))
	server.process_messages()
	assert_true(server.archery.arrows.is_empty(), "no arrows left")


func test_creative_players_shoot_without_arrows() -> void:
	var setup := _joined(WorldSettings.GameMode.CREATIVE)
	var server: GameServer = setup[0]
	var client: LocalTransport = setup[1]
	var session: GameServer.PlayerSession = setup[2]
	session.inventory.items[2] = Items.Id.BOW
	session.inventory.counts[2] = 1
	client.send(Msg.shoot(2, Vector3(1.0, -1.0, 0.0), 0.5))
	server.process_messages()
	assert_eq(server.archery.arrows.size(), 1)
	assert_eq(session.inventory.wear[2], 0, "the bow does not wear")
	for i in 20:
		server.archery.update(server, GameConst.TICK_DELTA)
	assert_true(server.archery.arrows.is_empty())
	assert_true(server.items.is_empty(), "nothing left lying around")


func test_arrows_fly_the_same_everywhere() -> void:
	var from := Vector3(1.0, 2.0, 3.0)
	var launch := Vector3(10.0, 5.0, 0.0)
	assert_eq(Archery.fly(from, launch, 0.0), from)
	var later := Archery.fly(from, launch, 1.0)
	assert_almost(later.x, 11.0, 0.001)
	assert_almost(later.y, 2.0 + 5.0 - Archery.GRAVITY * 0.5, 0.001, "it falls")
	# The client aims along the arc that lands where the mouse points.
	var start := Vector3(0.0, 1.0, 0.0)
	var goal := Vector3(12.0, 0.0, 5.0)
	var way := Archer.ballistic(start, goal, Archery.ARROW_SPEED)
	var flat := Vector2(goal.x - start.x, goal.z - start.z).length()
	var time := flat / (Vector2(way.x, way.z).length() * Archery.ARROW_SPEED)
	var landing := Archery.fly(start, way * Archery.ARROW_SPEED, time)
	assert_almost(landing.distance_to(goal), 0.0, 0.01, "it lands there")
