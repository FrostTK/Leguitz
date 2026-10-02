extends TestCase
## Monsters: they come out in the dark around players they may hunt and go
## in daylight or far away; the lurker freezes in the light, the mimic lies
## dormant until approached, fliers dive; their blows hurt, push and (the
## moth's) put the lantern out; they are never saved.

const SEA := GameConst.SEA_LEVEL
const TS := GameConst.TILE_SIZE


## A flat grass world at level 0.
func _voxel_at(cell: Vector3i) -> int:
	return Voxels.of_ground(Tiles.Ground.GRASS) if cell.y < SEA else Voxels.AIR


## Returns [server, client transport, session] with a joined player.
func _joined(mode := WorldSettings.GameMode.SURVIVAL) -> Array:
	var settings := WorldSettings.create("Test", "42", mode)
	var server := GameServer.new(settings, null, false)
	var transports := LocalTransport.create_pair()
	server.connect_client(transports[1])
	transports[0].send(Msg.hello("Alex", 2))
	server.process_messages()
	transports[0].poll()
	return [server, transports[0], server.first_session()]


func _monsters(server: GameServer) -> Array:
	return server.creatures.living.values().filter(func(c: Creature) -> bool: return c is Monster)


func test_monsters_come_out_at_night_and_melt_in_daylight() -> void:
	var setup := _joined()
	var server: GameServer = setup[0]
	var session: GameServer.PlayerSession = setup[2]
	server.clock.set_frozen(WorldClock.FROZEN_MIDNIGHT)
	for i in 400:
		Monsters.come_and_go(server, server.creatures)
	var night := _monsters(server)
	assert_true(night.size() >= 3, "they came: %d" % night.size())
	assert_true(night.size() <= Monsters.MAX_NEAR, "not too many")
	for monster: Monster in night:
		var away := monster.center().distance_to(session.position) / TS
		assert_true(away >= Monsters.SPAWN_DISTANCE.x - 1.0, "not under the nose: %.1f" % away)
	# Daylight: those under the open sky melt; cave ones stay.
	server.clock.set_frozen(WorldClock.FROZEN_NOON)
	Monsters.come_and_go(server, server.creatures)
	for monster: Monster in _monsters(server):
		var tile := monster.tile()
		var cell := Vector3i(tile.x, floori(monster.body.height + 0.01) + SEA, tile.y)
		assert_false(Light.sky_open(server.world, cell), "only cave ones left")
	assert_true(
		server.creatures.to_save()["animals"].all(
			func(data: Dictionary) -> bool: return not Species.is_monster(data["species"])
		),
		"monsters are never saved"
	)


func test_creative_players_and_spectators_are_left_alone() -> void:
	var setup := _joined(WorldSettings.GameMode.CREATIVE)
	var server: GameServer = setup[0]
	var session: GameServer.PlayerSession = setup[2]
	assert_false(Monsters.hunts(server, session))
	server.clock.set_frozen(WorldClock.FROZEN_MIDNIGHT)
	for i in 200:
		Monsters.come_and_go(server, server.creatures)
	assert_eq(_monsters(server).size(), 0, "none come out for them")
	var lurker := (
		server.creatures.add(
			Species.Id.SHADE_LURKER, session.position + Vector2(TS, 0), session.height
		)
		as Monster
	)
	Monsters.sense(server, server.creatures, lurker, 0.1)
	assert_false(lurker.has_prey(), "nor hunt them")
	server.settings.game_mode = WorldSettings.GameMode.SURVIVAL
	Monsters.sense(server, server.creatures, lurker, 0.1)
	assert_true(lurker.has_prey(), "survival players are")
	session.spectator = true
	session.health = 0
	Monsters.sense(server, server.creatures, lurker, 0.1)
	assert_false(lurker.has_prey(), "not spectators")


func test_the_lurker_freezes_in_the_light_and_strikes_in_the_dark() -> void:
	var rng := RandomNumberGenerator.new()
	var lurker := Monster.create(Species.Id.SHADE_LURKER, Vector2(8, 14), 0.0)
	lurker.hunt(Vector2(8.0 + 6.0 * TS, 14.0), 0.0)
	lurker.lit = true
	for i in 20:
		lurker.think(0.1, _voxel_at, rng)
		lurker.move(0.1, _voxel_at)
	assert_eq(lurker.state, Creature.State.FROZEN)
	assert_almost(lurker.body.feet.x, 8.0, 0.5, "it does not move")
	lurker.lit = false
	var struck := false
	for i in 60:
		lurker.think(0.1, _voxel_at, rng)
		lurker.move(0.1, _voxel_at)
		if lurker.strike:
			struck = true
			lurker.strike = false
	assert_true(struck, "it came and struck")
	assert_true(lurker.body.feet.x > 4.0 * TS, "it walked up: %.0f" % lurker.body.feet.x)
	# The light: lava or a burning furnace near, daylight under the sky.
	var fire := func(cell: Vector3i) -> int:
		if cell == Vector3i(3, SEA, 0):
			return Voxels.of_block(Tiles.Block.FOOD_FURNACE_LIT)
		return _voxel_at(cell)
	assert_true(Light.near_fire(fire, Vector3i(0, SEA, 0)))
	assert_false(Light.near_fire(fire, Vector3i(10, SEA, 0)))


func test_the_mimic_waits_as_a_rock_then_bites() -> void:
	var rng := RandomNumberGenerator.new()
	var mimic := Monster.create(Species.Id.ROCK_MIMIC, Vector2(8, 14), 0.0)
	assert_eq(mimic.state, Creature.State.DORMANT)
	mimic.hunt(Vector2(8.0 + 5.0 * TS, 14.0), 0.0)
	for i in 10:
		mimic.think(0.1, _voxel_at, rng)
		mimic.move(0.1, _voxel_at)
	assert_eq(mimic.state, Creature.State.DORMANT, "a rock while nobody is close")
	mimic.hunt(Vector2(8.0 + 2.0 * TS, 14.0), 0.0)
	mimic.think(0.1, _voxel_at, rng)
	assert_eq(mimic.state, Creature.State.CHASE, "awake")
	# Left alone, it settles again; a blow wakes it.
	mimic.forget()
	for i in 80:
		mimic.think(0.1, _voxel_at, rng)
		mimic.move(0.1, _voxel_at)
	assert_eq(mimic.state, Creature.State.DORMANT, "settled")
	assert_true(mimic.hurt_by(mimic.center() - Vector2(TS, 0), 1))
	assert_eq(mimic.state, Creature.State.CHASE, "woken by a blow")


func test_a_moth_dives_and_its_blow_puts_the_lantern_out() -> void:
	var setup := _joined()
	var server: GameServer = setup[0]
	var client: LocalTransport = setup[1]
	var session: GameServer.PlayerSession = setup[2]
	var moth := (
		server.creatures.add(
			Species.Id.LANTERN_MOTH, session.position + Vector2(3.0 * TS, 0), session.height + 2.0
		)
		as Monster
	)
	moth.prey_id = session.id
	var rng := RandomNumberGenerator.new()
	var at := server.creatures.voxel_at
	var struck := false
	for i in 200:
		moth.hunt(session.position, session.height)
		moth.think(0.05, at, rng)
		moth.move(0.05, at)
		if moth.strike:
			struck = true
			Monsters.land_blow(server, moth)
			break
	assert_true(struck, "it dived")
	assert_eq(session.health, Vitals.MAX_HEALTH - Species.DAMAGE[Species.Id.LANTERN_MOTH])
	var said := client.poll()
	var kinds := said.map(func(m: Dictionary) -> String: return m["t"])
	assert_true(Msg.PUSH in kinds, "pushed back")
	assert_true(Msg.LANTERN_OUT in kinds, "the lantern goes out")
	var vitals := said.filter(func(m: Dictionary) -> bool: return m["t"] == Msg.VITALS)
	assert_eq(vitals[0]["cause"], Vitals.Cause.MOTH)


func test_monster_gifts() -> void:
	assert_true(Smelting.is_fuel(Items.Id.WISP_EMBER), "a wisp's ember burns")
	assert_true(Smelting.burn_seconds(Items.Id.WISP_EMBER) > Smelting.burn_seconds(Items.Id.COAL))
	for kind: int in Species.MONSTERS:
		assert_true(Vitals.CAUSE_KEYS.has(Species.CAUSE[kind]), "its own words")
