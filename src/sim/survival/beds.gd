class_name Beds
extends RefCounted
## Sleeping (phase 8, step 7; static, given the server). A player's right
## click on a bed (Msg.SLEEP) makes it where they wake up after passing out
## (PlayerSession.bed, saved; Survival.get_up: beside it, `wake_spot`) and,
## at night, lays them down in it (PlayerSession.sleeping, told by
## Msg.SLEEPING). When every player is asleep for SLEEP_SECONDS, the night
## passes (the clock goes on to WAKE_HOUR) and they wake. Not with monsters
## about (within SAFE_RANGE), nor when the clock does not run by itself
## (synced with the device, frozen), nor in a bed another sleeps in
## (HUD_BED_TAKEN). Msg.WAKE, a hurt or the bed broken gets them up.

const MESSAGES: Array[String] = [Msg.SLEEP, Msg.WAKE]
const SLEEP_SECONDS := 2.5
const WAKE_HOUR := 6.25
## Tiles around a sleeper no monster may be.
const SAFE_RANGE := 10.0
## Seconds since a hurt that wake a sleeper.
const HURT_WAKES := 0.5


static func handle(
	server: GameServer, session: GameServer.PlayerSession, message: Dictionary
) -> bool:
	if not message.get("t") in MESSAGES:
		return false
	if not session.joined or not session.alive():
		return true
	if message.get("t") == Msg.WAKE:
		_wake(session)
		return true
	var cell: Vector3i = message.get("cell", Vector3i.ZERO)
	var block := Voxels.block_of(server.world.voxel_at(cell))
	var near := Mining.reach_to(session.position, session.height, cell)
	if not Furniture.is_bed(block) or near > Mining.REACH + GameServer.REACH_LEEWAY:
		return true
	var foot := Furniture.foot_cell(cell, block)
	if session.bed != foot:
		session.bed = foot
		session.transport.send(Msg.notice("HUD_BED_SPAWN"))
	var refusal := _refusal(server, session)
	for other in server.sessions:
		if other != session and other.sleeping and other.bed == foot:
			refusal = "HUD_BED_TAKEN"
	if refusal != "":
		session.transport.send(Msg.notice(refusal))
		return true
	session.sleeping = true
	session.slept = 0.0
	session.sits_on = GameServer.NO_CELL
	session.transport.send(Msg.sleeping(foot, true))
	return true


## Every tick: sleepers hurt or without their bed wake; when all players
## are asleep long enough, morning.
static func update(server: GameServer, delta: float) -> void:
	var players := 0
	var asleep := 0
	for session in server.sessions:
		if not session.joined or session.spectator:
			continue
		if not session.alive():
			_wake(session)
			continue
		players += 1
		if not session.sleeping:
			continue
		var bed := Voxels.block_of(server.world.voxel_at(session.bed))
		if session.since_hurt < HURT_WAKES or not Furniture.is_bed(bed):
			_wake(session)
			continue
		session.slept += delta
		if session.slept >= SLEEP_SECONDS:
			asleep += 1
	if players == 0 or asleep < players:
		return
	morning(server.clock)
	server.broadcast(Msg.time_state(server.clock))
	for session in server.sessions:
		if session.sleeping:
			_wake(session)
			session.transport.send(Msg.notice("HUD_GOOD_MORNING"))


## The clock goes on to the next WAKE_HOUR.
static func morning(clock: WorldClock) -> void:
	var day := WorldClock.GAME_SECONDS_PER_DAY
	var candidate := clock.day_index() * day + WAKE_HOUR * 3600.0
	if candidate < clock.total_game_seconds:
		candidate += day
	clock.total_game_seconds = candidate


## Where a player wakes up after passing out: beside their bed, if it is
## still there and a tile beside it is free to stand on ((x, height, z):
## a tile and the level of its floor; Vector3.INF: none).
static func wake_spot(server: GameServer, session: GameServer.PlayerSession) -> Vector3:
	if session.bed == GameServer.NO_CELL:
		return Vector3.INF
	var world := server.world
	var voxel := world.voxel_at(session.bed)
	if not Furniture.is_bed(Voxels.block_of(voxel)):
		return Vector3.INF
	for part in Furniture.cells(session.bed, Voxels.block_of(voxel), world.voxel_at):
		for side: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
			var at := part + side
			var free := (
				world.voxel_at(at) == Voxels.AIR and world.voxel_at(at + Vector3i.UP) == Voxels.AIR
			)
			if free and Voxels.is_cube(world.voxel_at(at + Vector3i.DOWN)):
				return Vector3(at.x, at.y - GameConst.SEA_LEVEL, at.z)
	return Vector3.INF


## Why a player cannot sleep now ("": they can).
static func _refusal(server: GameServer, session: GameServer.PlayerSession) -> String:
	if server.clock.mode != WorldClock.Mode.NORMAL:
		return "HUD_SLEEP_CLOCK"
	if not server.clock.is_night():
		return "HUD_SLEEP_DAY"
	var feet := session.position / GameConst.TILE_SIZE
	for creature: Creature in server.creatures.living.values():
		if creature is Monster:
			var at := creature.body.feet / GameConst.TILE_SIZE
			if at.distance_to(feet) < SAFE_RANGE:
				return "HUD_SLEEP_MONSTERS"
	return ""


static func _wake(session: GameServer.PlayerSession) -> void:
	if not session.sleeping:
		return
	session.sleeping = false
	session.transport.send(Msg.sleeping(session.bed, false))
