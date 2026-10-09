extends TestCase
## Fishing: where each fish lives and when it bites (FishTable), where a
## bobber lands, a cast waiting for a bite and reeled in (a fish leaps out,
## the bait used, the rod worn), a bite missed (the bait taken), the line
## going with the rod, fish traps set on the water and their catches, the
## recipes, cooking and worms.

const SEA := GameConst.SEA_LEVEL

var _server: GameServer
var _client: LocalTransport
var _session: GameServer.PlayerSession


## A server, a player on flat grass by a pond three deep (4 to 6 tiles
## east), noon, clear.
func _pond() -> void:
	var settings := WorldSettings.create("Test", "42", WorldSettings.GameMode.SURVIVAL)
	_server = GameServer.new(settings, null, false)
	var transports := LocalTransport.create_pair()
	_server.connect_client(transports[1])
	transports[0].send(Msg.hello("Alex", 2))
	_server.process_messages()
	_client = transports[0]
	_session = _server.first_session()
	_session.height = 0.0
	_server.clock.set_frozen(WorldClock.FROZEN_NOON)
	_server.weather.set_kind(Weather.Kind.CLEAR)
	var tile := Coords.world_to_tile(_session.position)
	for dz in range(-4, 5):
		for dx in range(-4, 8):
			var column := Vector3i(tile.x + dx, SEA - 1, tile.y + dz)
			var pond := dx >= 4 and dx <= 6 and absi(dz) <= 1
			for down in 4:
				var ground := Tiles.Ground.WATER if pond and down < 3 else Tiles.Ground.GRASS
				_server.world.set_voxel(column - Vector3i(0, down, 0), Voxels.of_ground(ground))
			for up in range(1, 6):
				_server.world.set_voxel(column + Vector3i(0, up, 0), Voxels.AIR)
	var bag := _session.inventory
	bag.selected = 0
	bag.items[0] = Items.Id.FISHING_ROD
	bag.counts[0] = 1
	bag.wear[0] = 0
	bag.items[1] = Items.Id.WORM
	bag.counts[1] = 5


func _cell(dx: int, dz: int) -> Vector3i:
	var tile := Coords.world_to_tile(_session.position)
	return Vector3i(tile.x + dx, SEA, tile.y + dz)


## Casts at the pond's middle.
func _cast() -> void:
	var cell := _cell(5, 0)
	_client.send(Msg.cast(0, Vector3(cell.x + 0.5, 0.0, cell.z + 0.5)))
	_server.process_messages()


func _line() -> Fishing.Line:
	return _session.line


## The line goes on until its bobber does `state` (forcing the waits).
func _until(state: int) -> void:
	for i in 4:
		if _line() == null or _line().state == state:
			return
		_line().left = 0.0
		Fishing.update(_server, 0.01)


func test_fish_live_and_bite_where_and_when_they_should() -> void:
	assert_eq(FishTable.water_of(Biomes.Id.OCEAN), FishTable.Water.SEA)
	assert_eq(FishTable.water_of(Biomes.Id.FROZEN_RIVER), FishTable.Water.RIVER)
	assert_eq(FishTable.water_of(Biomes.Id.SWAMP), FishTable.Water.SWAMP)
	assert_eq(FishTable.water_of(Biomes.Id.PLAINS), FishTable.Water.LAKE)
	assert_eq(FishTable.climate_of(Biomes.Id.TAIGA), FishTable.Climate.COLD)
	assert_eq(FishTable.climate_of(Biomes.Id.JUNGLE), FishTable.Climate.WARM)
	var lake := FishTable.Water.LAKE
	var mild := FishTable.Climate.MILD
	var day := FishTable.Period.DAY
	var night := FishTable.Period.NIGHT
	var none := Items.Id.NONE
	var catfish := Items.Id.CATFISH
	assert_eq(FishTable.weight_of(catfish, lake, mild, day, false, 3, none), 0.0, "night fish")
	assert_true(FishTable.weight_of(catfish, lake, mild, night, false, 3, none) > 0.0)
	assert_eq(FishTable.weight_of(Items.Id.PIKE, lake, mild, day, false, 1, none), 0.0, "deep")
	assert_true(FishTable.weight_of(Items.Id.PIKE, lake, mild, day, false, 3, none) > 0.0)
	var sea := FishTable.Water.SEA
	var tuna := Items.Id.TUNA
	var cold := FishTable.Climate.COLD
	assert_eq(FishTable.weight_of(tuna, sea, cold, day, false, 9, none), 0.0, "warm seas")
	assert_true(FishTable.weight_of(tuna, sea, FishTable.Climate.WARM, day, false, 9, none) > 0.0)
	var eel := Items.Id.EEL
	assert_eq(FishTable.weight_of(eel, lake, mild, day, false, 2, none), 0.0)
	assert_true(FishTable.weight_of(eel, lake, mild, day, true, 2, none) > 0.0, "out in the rain")
	var plain := FishTable.weight_of(Items.Id.PERCH, lake, mild, day, false, 1, none)
	var baited := FishTable.weight_of(Items.Id.PERCH, lake, mild, day, false, 1, Items.Id.WORM)
	assert_almost(baited, plain * FishTable.BAIT_FAVOR, 0.001, "its bait")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var cave := FishTable.Water.CAVE
	for i in 200:
		var caught := FishTable.pick(rng, cave, mild, night, false, 4, none)
		assert_true(caught in [Items.Id.CAVE_FISH, Items.Id.LANTERNFISH], "cave fish only")
		var at_sea := FishTable.pick(rng, sea, mild, day, false, 3, none)
		var row: Array = FishTable.SPECIES.get(at_sea, [sea])
		assert_true((row[0] & sea) != 0 or FishTable.JUNK.has(at_sea), "a sea fish")
		var size := FishTable.size_of(rng, caught)
		var span: Vector2i = FishTable.SPECIES[caught][7]
		assert_true(size >= span.x and size <= span.y, "its size")
		assert_true(FishTable.trap_pick(rng, sea) in FishTable.TRAPS[sea], "a trap's catch")


func test_a_bobber_lands_on_water_or_on_the_ground() -> void:
	var voxel_at := func(cell: Vector3i) -> int:
		if cell.y >= SEA:
			return Voxels.AIR
		if cell.x < 0:
			return Voxels.of_ground(Tiles.Ground.WATER)
		return Voxels.of_ground(Tiles.Ground.GRASS)
	var wet := Fishing.landing(Vector3(-2.5, 3.0, 0.5), voxel_at)
	assert_true(wet["water"], "on the water")
	var surface := Fluids.surface(Voxels.of_ground(Tiles.Ground.WATER)) - 1.0
	assert_almost(wet["at"].y, surface, 0.001, "at its surface")
	var dry := Fishing.landing(Vector3(2.5, 3.0, 0.5), voxel_at)
	assert_false(dry["water"], "on the ground")
	var feet := Vector3(0.0, 0.0, 0.0)
	var far := Fishing.within_reach(feet, Vector3(40.0, 0.0, 0.0))
	assert_almost(far.x, Fishing.CAST_RANGE, 0.001, "not farther than a cast")


func test_a_fish_bites_and_is_reeled_in() -> void:
	_pond()
	_cast()
	assert_true(_line() != null, "the line is out")
	assert_eq(_line().bait, Items.Id.WORM, "a worm on the hook")
	Fishing.update(_server, 5.0)
	assert_eq(_line().state, Fishing.State.FLOATING, "floating on the pond")
	_until(Fishing.State.BITE)
	assert_eq(_line().state, Fishing.State.BITE, "a fish bites")
	var fish := _line().fish
	assert_true(FishTable.SPECIES.has(fish) or FishTable.JUNK.has(fish), "something bit")
	var before := _server.items.size()
	_client.send(Msg.reel())
	_server.process_messages()
	assert_true(_line() == null, "reeled in")
	assert_eq(_server.items.size(), before + 1, "it leaps out of the water")
	var dropped: DroppedItem = _server.items.values().back()
	assert_eq(dropped.item, fish)
	assert_eq(_session.inventory.counts[1], 4, "the worm used up")
	assert_eq(_session.inventory.wear[0], 1, "the rod wears")


func test_a_missed_bite_takes_the_bait_and_too_soon_brings_nothing() -> void:
	_pond()
	_cast()
	Fishing.update(_server, 5.0)
	_until(Fishing.State.BITE)
	Fishing.update(_server, Fishing.BITE_SECONDS + Fishing.BITE_LEEWAY + 0.05)
	assert_eq(_line().state, Fishing.State.FLOATING, "the fish got away")
	assert_eq(_session.inventory.counts[1], 4, "with the worm")
	var before := _server.items.size()
	_client.send(Msg.reel())
	_server.process_messages()
	assert_eq(_server.items.size(), before, "reeled in too soon: nothing")
	assert_eq(_session.inventory.counts[1], 4, "the worm kept")
	assert_eq(_session.inventory.wear[0], 0, "the rod unworn")


func test_the_line_goes_with_the_rod() -> void:
	_pond()
	_cast()
	_session.inventory.selected = 2
	Fishing.update(_server, 0.05)
	assert_true(_line() == null, "another slot in hand: the line goes")
	_session.inventory.selected = 0
	_session.inventory.items[0] = Items.Id.STICK
	_cast()
	assert_true(_line() == null, "no rod, no cast")
	_session.inventory.items[0] = Items.Id.FISHING_ROD
	var cell := _cell(-2, 0)
	_client.send(Msg.cast(0, Vector3(cell.x + 0.5, 0.0, cell.z + 0.5)))
	_server.process_messages()
	Fishing.update(_server, 5.0)
	assert_eq(_line().state, Fishing.State.GROUND, "on the grass nothing bites")
	_cast()
	assert_eq(_line().state, Fishing.State.FLYING, "a new cast takes the line back first")
	assert_true(_line().water, "into the pond")


func test_a_trap_set_on_the_water_catches_for_its_baits() -> void:
	_pond()
	var trap := Voxels.of_block(Tiles.Block.FISH_TRAP)
	var water := _cell(4, 0)
	var placed := Mining.placement(water, trap, Vector2i(0, 1), _server.world.voxel_at)
	assert_eq(placed.size(), 1, "set on still water")
	var grass := Mining.placement(_cell(1, 0), trap, Vector2i(0, 1), _server.world.voxel_at)
	assert_true(grass.is_empty(), "not on the ground")
	_server.world.set_voxel(water, trap)
	_session.inventory.items[0] = Items.Id.WORM
	_session.inventory.counts[0] = 3
	_client.send(Msg.use_machine(water, 0))
	_server.process_messages()
	var block := Voxels.block_of(_server.world.voxel_at(water))
	assert_eq(block, Tiles.Block.FISH_TRAP_BAITED, "baited")
	assert_eq(_session.inventory.items[0], Items.Id.NONE, "the worms in it")
	Machines.update(_server, 100000.0)
	block = Voxels.block_of(_server.world.voxel_at(water))
	assert_eq(block, Tiles.Block.FISH_TRAP_FULL, "a catch")
	_client.send(Msg.use_machine(water, 0))
	_server.process_messages()
	var catches := {}
	for kind: int in FishTable.TRAPS:
		catches.merge(FishTable.TRAPS[kind])
	var caught := 0
	for slot in Inventory.SLOTS:
		if catches.has(_session.inventory.items[slot]):
			caught += _session.inventory.counts[slot]
	assert_eq(caught, 3, "a catch for each worm, in the bag")
	block = Voxels.block_of(_server.world.voxel_at(water))
	assert_eq(block, Tiles.Block.FISH_TRAP, "empty again")


func test_fishing_recipes_cooking_and_worms() -> void:
	var bag := Inventory.new()
	var rod := [
		Items.Id.NONE,
		Items.Id.NONE,
		Items.Id.STICK,
		Items.Id.NONE,
		Items.Id.STICK,
		Items.Id.STRING,
		Items.Id.STICK,
		Items.Id.NONE,
		Items.Id.STRING,
	]
	for i in rod.size():
		var cell := Inventory.CRAFT + (i / Inventory.OWN_GRID) * Inventory.GRID
		cell += i % Inventory.OWN_GRID
		bag.items[cell] = rod[i]
		bag.counts[cell] = 1 if rod[i] != Items.Id.NONE else 0
	assert_eq(bag.craft_result(Inventory.OWN_GRID), Vector2i(Items.Id.FISHING_ROD, 1))
	var sushi := Inventory.new()
	for i in 3:
		var item: int = [Items.Id.COOKED_RICE, Items.Id.SALMON, Items.Id.SEAWEED][i]
		sushi.items[Inventory.CRAFT + i] = item
		sushi.counts[Inventory.CRAFT + i] = 1
	assert_eq(sushi.craft_result(Inventory.OWN_GRID, true), Vector2i(Items.Id.SUSHI, 3))
	for fish: int in FishTable.SPECIES.keys() + FishTable.SHELLFISH.keys():
		var cooked := Smelting.result_of(Tiles.Block.FOOD_FURNACE, fish)
		assert_true(Items.is_food(fish) and Items.is_food(cooked), "%d grills" % fish)
		assert_true(Items.FOOD[cooked] > Items.FOOD[fish], "cooked feeds better")
		var charred := Smelting.result_of(Tiles.Block.FACTORY_FURNACE, cooked)
		assert_eq(charred, Items.Id.CHARRED_FOOD, "the factory furnace chars it")
		assert_true(fish in Recipes.SEAFOOD, "a seafood")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var worms := 0
	for i in 300:
		var grass := Voxels.of_ground(Tiles.Ground.GRASS)
		for drop: Vector2i in Items.drops(grass, Vector2i.ZERO, rng):
			if drop.x == Items.Id.WORM:
				worms += 1
	assert_true(worms > 0 and worms < 60, "worms now and then in the soil")
	assert_eq(Items.max_stack(Items.Id.FISHING_ROD), 1, "rods do not stack")
	assert_eq(Items.durability(Items.Id.FISHING_ROD), Items.ROD_DURABILITY)
