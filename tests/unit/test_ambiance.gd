extends TestCase
## A house's ambiance (phase 8, step 8): lights switched on and off, small
## things standing on furniture, a chandelier hanging from a ceiling, a
## hearth burning its fuel and smoking up a chimney, the cold of winter and
## a fire's warmth, flower pots and pictures, the bathroom, the recipes.

const SEA := GameConst.SEA_LEVEL
const SOUTH := Vector2i(0, 1)
const ITEMS: Array[int] = [
	Items.Id.CANDLE,
	Items.Id.CANDELABRA,
	Items.Id.CHANDELIER,
	Items.Id.BEDSIDE_LAMP,
	Items.Id.WALL_SCONCE,
	Items.Id.FIREPLACE,
	Items.Id.STOVE,
	Items.Id.PAINTING,
	Items.Id.PORTRAIT,
	Items.Id.WALL_CLOCK,
	Items.Id.MIRROR,
	Items.Id.FRAMED_MAP,
	Items.Id.DEER_TROPHY,
	Items.Id.BEAR_TROPHY,
	Items.Id.TAPESTRY,
	Items.Id.SPICE_RACK,
	Items.Id.COAT_RACK,
	Items.Id.CUSHION,
	Items.Id.FLOWER_POT,
	Items.Id.WINDOW_BOX,
	Items.Id.HOUSEPLANT,
	Items.Id.BATHTUB,
	Items.Id.SHOWER,
	Items.Id.WASHBASIN,
	Items.Id.GRANDFATHER_CLOCK,
	Items.Id.TOY_CHEST,
	Items.Id.PIANO,
	Items.Id.CRADLE,
	Items.Id.FOLDING_SCREEN,
]

var _server: GameServer
var _client: LocalTransport
var _session: GameServer.PlayerSession


## A server, a player, the cell two tiles east of their feet on stone, free
## up to four rows (and around it).
func _start() -> Vector3i:
	var settings := WorldSettings.create("Test", "42", WorldSettings.GameMode.SURVIVAL)
	_server = GameServer.new(settings, null, false)
	var transports := LocalTransport.create_pair()
	_server.connect_client(transports[1])
	transports[0].send(Msg.hello("Alex", 2))
	_server.process_messages()
	_client = transports[0]
	_session = _server.first_session()
	_server.creatures.living.clear()
	var feet := Coords.world_to_tile(_session.position)
	var cell := Vector3i(feet.x + 2, floori(_session.height + 0.01) + SEA, feet.y)
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			_server.world.set_voxel(cell + Vector3i(dx, -1, dz), Voxels.of_block(Tiles.Block.STONE))
			for up in 4:
				_server.world.set_voxel(cell + Vector3i(dx, up, dz), Voxels.AIR)
	return cell


func _hold(item: int, count := 4) -> void:
	_session.inventory.items[0] = item
	_session.inventory.counts[0] = count
	_session.inventory.selected = 0


func _send(message: Dictionary) -> void:
	_client.send(message)
	_server.process_messages()


func _block(cell: Vector3i) -> int:
	return Voxels.block_of(_server.world.voxel_at(cell))


func _lying() -> Array:
	return _server.items.values().map(func(d: DroppedItem) -> int: return d.item)


func test_lights_go_out_and_light_again() -> void:
	var cell := _start()
	_hold(Items.Id.CANDLE)
	_send(Msg.block_place(cell, 0, SOUTH, Vector3i.UP))
	assert_eq(_block(cell), Tiles.Block.CANDLE, "placed lit")
	assert_true(ObjectShapes.is_lit(Tiles.Block.CANDLE))
	assert_true(LightField.shine(_server.world.voxel_at(cell)) > 0, "it shines")
	assert_true(Mining.swings(_server.world.voxel_at(cell)), "a right click puts it out")
	_send(Msg.swing_gate(cell))
	assert_eq(_block(cell), Tiles.Block.CANDLE_OUT)
	assert_eq(LightField.shine(_server.world.voxel_at(cell)), 0, "out, it does not")
	assert_false(ObjectShapes.is_lit(Tiles.Block.CANDLE_OUT))
	var drops := Items.drops(_server.world.voxel_at(cell), Vector2i.ZERO, _server.rng)
	assert_eq(drops, [Vector2i(Items.Id.CANDLE, 1)], "a candle put out gives the candle")
	_send(Msg.swing_gate(cell))
	assert_eq(_block(cell), Tiles.Block.CANDLE, "lit again")
	# A wall sconce, either way it faces, and the shower.
	var sconce := ObjectShapes.facing(Tiles.Block.WALL_SCONCE, Vector2i(1, 0))
	assert_eq(ObjectShapes.kind_of(ObjectShapes.swung(sconce)), Tiles.Block.WALL_SCONCE_OUT)
	assert_eq(ObjectShapes.front_of(ObjectShapes.swung(sconce)), Vector2i(1, 0))
	assert_eq(ObjectShapes.swung(Tiles.Block.TABLE), Tiles.Block.TABLE, "no other state")


func test_small_things_stand_on_furniture() -> void:
	var cell := _start()
	_server.world.set_voxel(cell, Voxels.of_block(Tiles.Block.NIGHTSTAND))
	_hold(Items.Id.BEDSIDE_LAMP)
	var over := cell + Vector3i.UP
	_send(Msg.block_place(over, 0, SOUTH, Vector3i.UP))
	assert_eq(_block(over), Tiles.Block.BEDSIDE_LAMP, "on the nightstand")
	var top := ObjectShapes.stand_height(Tiles.Block.NIGHTSTAND)
	var below := _server.world.voxel_at(cell)
	assert_almost(Decor.sink(Tiles.Block.BEDSIDE_LAMP, below), 1.0 - top, 0.001, "on its top")
	var floor := Voxels.of_block(Tiles.Block.STONE)
	assert_eq(Decor.sink(Tiles.Block.BEDSIDE_LAMP, floor), 0.0, "on a floor: as it is")
	assert_eq(Decor.sink(Tiles.Block.TABLE, below), 0.0, "only small things")
	# Not on what one does not stand on.
	var air := Mining.placement(
		over + Vector3i(1, 0, 0), Voxels.of_block(Tiles.Block.CANDLE), SOUTH, _server.world.voxel_at
	)
	assert_true(air.is_empty(), "not in the air")
	_send(Msg.block_break(cell, -1))
	assert_eq(_server.world.voxel_at(over), Voxels.AIR, "it falls with the nightstand")
	assert_true(_lying().has(Items.Id.BEDSIDE_LAMP), "and gives itself back")


func test_a_chandelier_hangs_from_the_ceiling() -> void:
	var cell := _start()
	var ceiling := cell + Vector3i(0, 3, 0)
	_server.world.set_voxel(ceiling, Voxels.of_block(Tiles.Block.STONE))
	_hold(Items.Id.CHANDELIER)
	_send(Msg.block_place(cell, 0, SOUTH, Vector3i.UP))
	var hung := ceiling + Vector3i.DOWN
	assert_eq(_block(hung), Tiles.Block.CHANDELIER, "under the ceiling over the floor aimed at")
	assert_eq(_block(cell), Tiles.Block.AIR)
	assert_true(ObjectShapes.is_hanging(_block(hung)))
	_send(Msg.block_break(ceiling, -1))
	assert_eq(_server.world.voxel_at(hung), Voxels.AIR, "it falls with the ceiling")
	assert_true(_lying().has(Items.Id.CHANDELIER))


func test_a_hearth_burns_its_fuel() -> void:
	var cell := _start()
	_hold(Items.Id.FIREPLACE)
	_send(Msg.block_place(cell, 0, SOUTH, Vector3i.UP))
	var end := cell + Vector3i(1, 0, 0)
	assert_eq(ObjectShapes.kind_of(_block(cell)), Tiles.Block.FIREPLACE, "two tiles wide")
	assert_eq(ObjectShapes.wide_kind(_block(end)), Tiles.Block.FIREPLACE)
	var chimney := cell + Vector3i(0, 3, 0)
	_server.world.set_voxel(chimney, Voxels.of_block(Tiles.Block.CHIMNEY))
	assert_false(RoofBlocks.smokes(chimney, _server.world.voxel_at), "cold")
	_hold(Items.Id.OAK_LOG, 2)
	_send(Msg.stoke(end, 0))
	assert_eq(ObjectShapes.kind_of(_block(cell)), Tiles.Block.FIREPLACE_LIT, "lit")
	assert_eq(ObjectShapes.wide_kind(_block(end)), Tiles.Block.FIREPLACE_LIT, "both ends")
	assert_eq(_session.inventory.counts[0], 1, "a log went in")
	assert_true(RoofBlocks.smokes(chimney, _server.world.voxel_at), "its chimney smokes")
	assert_true(LightField.shine(_server.world.voxel_at(cell)) > 0, "the fire shines")
	var chunk := _server.world.chunks[Coords.tile_to_chunk(Vector2i(cell.x, cell.z))]
	var burns := _server.clock.scale_duration(Smelting.burn_seconds(Items.Id.OAK_LOG))
	assert_almost(chunk.fires[cell], burns * Hearths.BURN_SLOWER, 0.01, "longer than a furnace")
	Hearths.update(_server, chunk.fires[cell] + 1.0)
	assert_eq(ObjectShapes.kind_of(_block(cell)), Tiles.Block.FIREPLACE, "burnt out")
	assert_eq(ObjectShapes.wide_kind(_block(end)), Tiles.Block.FIREPLACE)
	_send(Msg.stoke(cell, 0))
	_hold(Items.Id.WATERING_CAN, 1)
	_send(Msg.stoke(cell, 0))
	assert_eq(ObjectShapes.kind_of(_block(cell)), Tiles.Block.FIREPLACE, "the can puts it out")
	assert_false(chunk.fires.has(cell))
	_hold(Items.Id.DIRT)
	_client.poll()
	_send(Msg.stoke(cell, 0))
	var told := _client.poll().filter(func(m: Dictionary) -> bool: return m["t"] == Msg.NOTICE)
	assert_eq(told.size(), 1, "dirt does not burn")


func test_winter_is_cold_and_a_fire_warms() -> void:
	var cell := _start()
	var clock := _server.clock
	Seasons.set_length(clock, 7)
	Seasons.set_season(clock, WorldClock.Season.WINTER)
	var tile := Coords.world_to_tile(_session.position)
	var chunk := _server.world.chunks[Coords.tile_to_chunk(tile)]
	var local := Coords.tile_to_local(tile)
	chunk.biome[local.y * GameConst.CHUNK_SIZE + local.x] = Biomes.Id.PLAINS
	Warmth.update(_server, _session)
	assert_true(_session.effects.has(Effects.Kind.COLD), "cold in winter")
	_session.effort = 0.0
	Survival.spend(_server, _session, 0.4)
	assert_almost(_session.effort, 0.4 * Survival.COLD_HUNGER, 0.001, "hunger comes faster")
	_server.world.set_voxel(cell, Voxels.of_block(Tiles.Block.CAMPFIRE))
	Warmth.update(_server, _session)
	assert_false(_session.effects.has(Effects.Kind.COLD), "warm by the fire")
	assert_true(Effects.has(_session.effects, Effects.Kind.WARM))
	_server.world.set_voxel(cell, Voxels.AIR)
	Warmth.update(_server, _session)
	assert_false(_session.effects.has(Effects.Kind.COLD), "the warmth lasts a while")
	_session.effects.erase(Effects.Kind.WARM)
	Seasons.set_season(clock, WorldClock.Season.SUMMER)
	Warmth.update(_server, _session)
	assert_false(_session.effects.has(Effects.Kind.COLD), "not in summer")


func test_pots_hold_a_plant_and_pictures_turn() -> void:
	var cell := _start()
	_hold(Items.Id.FLOWER_POT)
	_send(Msg.block_place(cell, 0, SOUTH, Vector3i.UP))
	assert_eq(_block(cell), Tiles.Block.FLOWER_POT)
	_hold(Items.Id.STICK)
	_send(Msg.shelf(cell, 0))
	assert_eq(Shelves.items_at(_server.world, cell, 1)[0], Items.Id.NONE, "only plants")
	_hold(Items.Id.FLOWER_BLUE, 2)
	_send(Msg.shelf(cell, 0))
	var held := Shelves.items_at(_server.world, cell, 1)
	assert_eq(held[0], Items.Id.FLOWER_BLUE, "planted")
	assert_eq(_session.inventory.counts[0], 1)
	assert_eq(Decor.pot_version(held), Decor.POTTED.keys().find(Items.Id.FLOWER_BLUE) + 1)
	assert_eq(ObjectShapes.variant_count(Tiles.Block.FLOWER_POT), Decor.POTTED.size() + 1)
	_send(Msg.block_break(cell, -1))
	assert_true(_lying().has(Items.Id.FLOWER_BLUE), "broken, its plant falls")
	assert_true(_lying().has(Items.Id.FLOWER_POT))
	# A painting on a wall, the next picture each right click.
	var wall := cell - Vector3i(0, 0, 1)
	_server.world.set_voxel(wall, Voxels.of_block(Tiles.Block.STONE))
	_hold(Items.Id.PAINTING)
	_send(Msg.block_place(cell, 0, SOUTH, Vector3i(0, 0, 1)))
	assert_eq(ObjectShapes.kind_of(_block(cell)), Tiles.Block.PAINTING, "hung")
	var own := ObjectShapes.variant_at(_block(cell), Vector2i(cell.x, cell.z))
	assert_eq(Decor.picture(Tints.at(_server.world, cell), own), own, "its tile's at first")
	_send(Msg.turn_picture(cell))
	var count: int = Decor.PICTURES[Tiles.Block.PAINTING]
	var shown := Decor.picture(Tints.at(_server.world, cell), own)
	assert_eq(shown, (own + 1) % count, "the next one")
	for i in count - 1:
		_send(Msg.turn_picture(cell))
	assert_eq(Decor.picture(Tints.at(_server.world, cell), own), own, "round again")


func test_the_bathroom_and_more() -> void:
	var cell := _start()
	_hold(Items.Id.BATHTUB)
	_send(Msg.block_place(cell, 0, SOUTH, Vector3i.UP))
	assert_eq(ObjectShapes.kind_of(_block(cell)), Tiles.Block.BATHTUB, "two tiles long")
	assert_true(Watering.fills_from(_server.world.voxel_at(cell + Vector3i(1, 0, 0))), "a tap")
	assert_true(Furniture.is_seat(_block(cell)), "one sits in it")
	var shower := cell + Vector3i(0, 0, -2)
	_hold(Items.Id.SHOWER)
	_send(Msg.block_place(shower, 0, SOUTH, Vector3i.UP))
	assert_eq(ObjectShapes.kind_of(_block(shower)), Tiles.Block.SHOWER, "a shower")
	assert_eq(_block(shower + Vector3i.UP), Tiles.Block.FURNITURE_TOP, "two levels high")
	assert_false(Voxels.is_solid(_server.world.voxel_at(shower)), "one steps into it")
	_send(Msg.swing_gate(shower))
	assert_eq(ObjectShapes.kind_of(_block(shower)), Tiles.Block.SHOWER_ON, "running")
	assert_eq(_block(shower + Vector3i.UP), Tiles.Block.FURNITURE_TOP, "its top stays")
	assert_true(Decor.is_live(_block(shower)))
	assert_true(Furniture.is_storage(ObjectShapes.facing(Tiles.Block.TOY_CHEST, SOUTH)))
	assert_true(Tints.dyed(Tiles.Block.BEDSIDE_LAMP_OFF), "a lamp's shade")


func test_every_thing_is_named_made_and_given_back() -> void:
	var rng := RandomNumberGenerator.new()
	for item in ITEMS:
		assert_ne(tr(Items.name_key(item)), Items.name_key(item), "%d named" % item)
		var voxel := Items.placed_voxel(item)
		assert_true(Mining.can_place(voxel), "%s can be placed" % Items.name_key(item))
		for way: int in ObjectShapes.blocks_of(Voxels.block_of(voxel)):
			var other := ObjectShapes.swung(way)
			for block: int in [way, other]:
				var drops := Items.drops(Voxels.of_block(block), Vector2i.ZERO, rng)
				assert_eq(
					drops, [Vector2i(item, 1)], "%s gives it back" % Tiles.Block.find_key(block)
				)
	# Each recipe makes its own thing, in the inventory's grid and at the
	# workbench (none hidden by another's pattern).
	for recipe: Dictionary in HomeRecipes.ROOMS + HomeRecipes.AMBIANCE:
		for width: int in [Inventory.OWN_GRID, Recipes.WORKBENCH_GRID]:
			var made := Recipes.find(_laid_out(recipe, width), width)
			var name := Items.name_key(recipe["result"][0])
			assert_false(made.is_empty(), "%s is made (%d)" % [name, width])
			if not made.is_empty():
				assert_eq(made["result"][0], recipe["result"][0], "%s, not another" % name)


## A recipe's ingredients laid in a grid `width` wide (groups: their first).
func _laid_out(recipe: Dictionary, width: int) -> PackedInt32Array:
	var cells := PackedInt32Array()
	cells.resize(width * width)
	cells.fill(Items.Id.NONE)
	if recipe.has("ingredients"):
		var ingredients: Array = recipe["ingredients"]
		for i in ingredients.size():
			cells[i] = ingredients[i]
		return cells
	var pattern: Array = recipe["pattern"]
	for row in pattern.size():
		var line: String = pattern[row]
		for column in line.length():
			if line[column] != " ":
				var ingredient: Variant = recipe["keys"][line[column]]
				cells[row * width + column] = ingredient[0] if ingredient is Array else ingredient
	return cells
