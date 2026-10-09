class_name Fishing
extends RefCounted
## Fishing with a rod on the server (static, given the server). A player
## with a rod in hand casts (Msg.CAST: where they aim, at most CAST_RANGE
## tiles away) and the bobber flies there (`landing`: on the water, or on
## the ground, where nothing bites) for FLIGHT seconds and more the farther.
## On the water it waits (`_wait`: WAIT seconds, less with a bait, in the
## rain, at dawn and dusk, more over shallow water; real seconds, a
## player's action), nibbles a moment, then a fish bites for BITE_SECONDS:
## reeled in then (Msg.REEL), the fish (FishTable.pick for the water and
## the climate of the place, `water_at`, the time, the rain, the depth
## under the bobber and the bait) leaps out of the water to the player (a
## dropped item), the rod wears and the bait is used up; missed, the fish
## takes the bait and the bobber waits again. Reeled in sooner, nothing
## comes. The bait is the first one in the player's slots (BAITS, hotbar
## first; none is needed); creative players use none up and their rod
## does not wear. The line goes when the rod leaves the hand, the player
## passes out or walks LINE_SNAP away from the bobber. Every player is told
## where the bobbers are (Msg.BOBBER), the angler what they caught
## (Msg.CAUGHT). Tilling turns up worms (`worm_chance`). Positions in local
## units.

enum State { FLYING, FLOATING, NIBBLE, BITE, GROUND, GONE }

const CAST_RANGE := 14.0
const LINE_SNAP := 22.0
## Seconds a cast flies, and more per tile.
const FLIGHT := 0.3
const FLIGHT_PER_TILE := 0.035
## Rows looked down from where the player aims for what the bobber lands on.
const LANDING_ROWS := 24
## Seconds before a nibble (between the two), and what shortens or
## lengthens the wait.
const WAIT := Vector2(8.0, 22.0)
const BAIT_WAIT := 0.65
const RAIN_WAIT := 0.8
const TWILIGHT_WAIT := 0.75
const SHALLOW_WAIT := 1.4
## Seconds of nibbling (between the two), then of the bite; a reel coming
## this late after the bite still counts (a message's way).
const NIBBLE := Vector2(0.6, 1.6)
const BITE_SECONDS := 0.9
const BITE_LEEWAY := 0.3
## Water deeper than this counts as this deep.
const MOST_DEPTH := 16
const BAITS: Array[int] = [Items.Id.WORM, Items.Id.BAIT_BALL, Items.Id.FISH_BAIT]
## Tilling turns up a worm this often (twice in the rain).
const WORM_CHANCE := 0.15
## A catch leaps to the player in this many seconds, to their chest.
const LEAP_SECONDS := 0.7
const CHEST := 1.0


## A player's line out.
class Line:
	extends RefCounted
	## The hotbar slot of the rod, what the bobber does, where it is.
	var slot := 0
	var state := State.FLYING
	var at := Vector3.ZERO
	## The water cell it floats on (or the cell it lies on), and whether it
	## is water.
	var cell := Vector3i.ZERO
	var water := false
	## Seconds left of what it does.
	var left := 0.0
	## The bait on the hook (Items.Id.NONE: none) and the fish biting.
	var bait := Items.Id.NONE
	var fish := Items.Id.NONE


## Where a cast from `feet` towards `target` goes: at most CAST_RANGE
## tiles away, not far over or under the feet.
static func within_reach(feet: Vector3, target: Vector3) -> Vector3:
	var flat := Vector2(target.x - feet.x, target.z - feet.z)
	if flat.length() > CAST_RANGE:
		flat = flat.normalized() * CAST_RANGE
	var y := clampf(target.y, feet.y - LANDING_ROWS, feet.y + 4.0)
	return Vector3(feet.x + flat.x, y, feet.z + flat.y)


## Seconds a cast from `feet` to `target` flies.
static func flight_of(feet: Vector3, target: Vector3) -> float:
	return FLIGHT + FLIGHT_PER_TILE * Vector2(target.x - feet.x, target.z - feet.z).length()


## Where a bobber thrown at `target` ends ({"at", "cell", "water"}): on
## the first thing under it (through air and what does not block), its
## surface for a liquid; nothing under it: where it was aimed.
static func landing(target: Vector3, voxel_at: Callable) -> Dictionary:
	var tile := Vector2i(floori(target.x), floori(target.z))
	var top := floori(target.y) + GameConst.SEA_LEVEL + 2
	for row in range(top, top - LANDING_ROWS, -1):
		var cell := Vector3i(tile.x, row, tile.y)
		var voxel: int = voxel_at.call(cell)
		if voxel == Voxels.AIR or (Voxels.is_object(voxel) and not Voxels.is_solid(voxel)):
			continue
		var up := Fluids.surface(voxel) if Voxels.is_liquid(voxel) else 1.0
		var at := Vector3(target.x, row - GameConst.SEA_LEVEL + up, target.z)
		return {"at": at, "cell": cell, "water": Voxels.is_water(voxel)}
	return {"at": target, "cell": Vector3i.MAX, "water": false}


## The water at a cell and its climate: Vector2i(FishTable.Water,
## FishTable.Climate), from its column's biome; out of the sky, a cave's.
static func water_at(world: WorldState, cell: Vector3i) -> Vector2i:
	var tile := Vector2i(cell.x, cell.z)
	var chunk: ChunkData = world.chunks.get(Coords.tile_to_chunk(tile))
	if chunk == null:
		return Vector2i(FishTable.Water.LAKE, FishTable.Climate.MILD)
	var biome := chunk.get_biome(Coords.tile_to_local(tile))
	var water := FishTable.water_of(biome)
	if not Watering.under_sky(world, cell):
		water = FishTable.Water.CAVE
	return Vector2i(water, FishTable.climate_of(biome))


## How deep the water is from a cell down (at most MOST_DEPTH).
static func depth_at(world: WorldState, cell: Vector3i) -> int:
	for depth in MOST_DEPTH:
		if not Voxels.is_water(world.loaded_voxel_at(cell + Vector3i.DOWN * depth)):
			return depth
	return MOST_DEPTH


## The slot of the first bait a player carries (hotbar first; -1: none),
## of one kind (Items.Id.NONE: any).
static func bait_slot(bag: Inventory, kind := Items.Id.NONE) -> int:
	for slot in Inventory.SLOTS:
		var item := bag.items[slot]
		if item in BAITS and (kind == Items.Id.NONE or item == kind):
			return slot
	return -1


static func worm_chance(server: GameServer) -> float:
	return WORM_CHANCE * (2.0 if server.weather.is_raining() else 1.0)


## A player casts (see the class); a line still out (they saw it go) goes.
static func cast(
	server: GameServer, session: GameServer.PlayerSession, message: Dictionary
) -> void:
	if not session.joined or not session.alive():
		return
	if session.line != null:
		server.broadcast(Msg.bobber(session.id, State.GONE, session.line.at, 0.0))
		session.line = null
	var slot := int(message.get("slot", -1))
	var bag := session.inventory
	if slot < 0 or slot >= Inventory.HOTBAR or bag.items[slot] != Items.Id.FISHING_ROD:
		session.transport.send(Msg.inventory(bag))
		return
	var flat := session.position / GameConst.TILE_SIZE
	var feet := Vector3(flat.x, session.height, flat.y)
	var aimed: Variant = message.get("target", feet)
	var target := within_reach(feet, aimed if aimed is Vector3 else feet)
	var landed := landing(target, server.world.loaded_voxel_at)
	var line := Line.new()
	line.slot = slot
	line.at = landed["at"]
	line.cell = landed["cell"]
	line.water = landed["water"]
	line.left = flight_of(feet, target)
	var bait := bait_slot(bag)
	line.bait = bag.items[bait] if bait >= 0 else Items.Id.NONE
	session.line = line
	_tell(server, session, line)


## A player reels in: a fish biting comes out of the water.
static func reel(server: GameServer, session: GameServer.PlayerSession) -> void:
	var line: Line = session.line
	if line == null:
		return
	session.line = null
	if line.state == State.BITE and session.alive():
		_land(server, session, line)
	server.broadcast(Msg.bobber(session.id, State.GONE, line.at, 0.0))


## The lines out go on for `delta` seconds (see the class).
static func update(server: GameServer, delta: float) -> void:
	for session in server.sessions:
		var line: Line = session.line
		if line == null:
			continue
		if _snapped(session, line):
			session.line = null
			server.broadcast(Msg.bobber(session.id, State.GONE, line.at, 0.0))
			continue
		line.left -= delta
		if line.state == State.FLYING and line.left <= 0.0:
			line.state = State.FLOATING if line.water else State.GROUND
			line.left = _wait(server, line)
			_tell(server, session, line)
		elif line.state == State.FLOATING and line.left <= 0.0:
			line.state = State.NIBBLE
			line.left = server.rng.randf_range(NIBBLE.x, NIBBLE.y)
			_tell(server, session, line)
		elif line.state == State.NIBBLE and line.left <= 0.0:
			line.state = State.BITE
			line.left = BITE_SECONDS
			line.fish = _bites(server, line)
			_tell(server, session, line)
		elif line.state == State.BITE and line.left <= -BITE_LEEWAY:
			# Missed: the fish took the bait.
			var missed := line.bait != Items.Id.NONE
			_use_bait(server, session, line)
			line.state = State.FLOATING
			line.left = _wait(server, line)
			_tell(server, session, line, missed)


## Whether the line goes: the rod out of hand, the player down or far.
static func _snapped(session: GameServer.PlayerSession, line: Line) -> bool:
	var feet := session.position / GameConst.TILE_SIZE
	var away := Vector3(feet.x, session.height, feet.y).distance_to(line.at)
	return (
		not session.alive()
		or session.inventory.selected != line.slot
		or session.inventory.items[line.slot] != Items.Id.FISHING_ROD
		or away > LINE_SNAP
	)


## Seconds before the next nibble (see the class).
static func _wait(server: GameServer, line: Line) -> float:
	var wait := server.rng.randf_range(WAIT.x, WAIT.y)
	if line.bait != Items.Id.NONE:
		wait *= BAIT_WAIT
	if server.weather.is_raining():
		wait *= RAIN_WAIT
	if FishTable.time_of(server.clock) == FishTable.Period.TWILIGHT:
		wait *= TWILIGHT_WAIT
	if line.water and depth_at(server.world, line.cell) <= 1:
		wait *= SHALLOW_WAIT
	return wait


## What bites the line there and then (FishTable.pick).
static func _bites(server: GameServer, line: Line) -> int:
	var water := water_at(server.world, line.cell)
	var time := FishTable.time_of(server.clock)
	if water.x == FishTable.Water.CAVE:
		time = FishTable.Period.NIGHT
	var depth := depth_at(server.world, line.cell)
	var raining := server.weather.is_raining()
	return FishTable.pick(server.rng, water.x, water.y, time, raining, depth, line.bait)


## The fish on the line leaps to the player; the bait is used up, the rod
## wears (not in creative).
static func _land(server: GameServer, session: GameServer.PlayerSession, line: Line) -> void:
	_use_bait(server, session, line)
	var broke := false
	if not GameModes.creative(server):
		broke = session.inventory.wear_out(line.slot)
		session.transport.send(Msg.inventory(session.inventory))
	var feet := session.position / GameConst.TILE_SIZE
	var chest := Vector3(feet.x, session.height + CHEST, feet.y)
	var from := line.at + Vector3(0.0, 0.3, 0.0)
	var way := chest - from
	var time := LEAP_SECONDS
	var gravity := DroppedItem.GRAVITY
	var speed := Vector3(way.x / time, way.y / time + 0.5 * gravity * time, way.z / time)
	server.spawn_item(line.fish, 1, from, speed, 0.0)
	var size := FishTable.size_of(server.rng, line.fish)
	session.transport.send(Msg.caught(line.fish, size, broke))


## The bait on the hook is used up (not in creative).
static func _use_bait(server: GameServer, session: GameServer.PlayerSession, line: Line) -> void:
	if line.bait == Items.Id.NONE or GameModes.creative(server):
		return
	var slot := bait_slot(session.inventory, line.bait)
	if slot >= 0:
		session.inventory.take(slot, 1)
		session.transport.send(Msg.inventory(session.inventory))
	var next := bait_slot(session.inventory)
	line.bait = session.inventory.items[next] if next >= 0 else Items.Id.NONE


static func _tell(
	server: GameServer, session: GameServer.PlayerSession, line: Line, missed := false
) -> void:
	server.broadcast(Msg.bobber(session.id, line.state, line.at, line.left, missed))
