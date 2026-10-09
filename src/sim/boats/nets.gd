class_name Nets
extends RefCounted
## A boat's fishing net on the server (static, given the server; Boats runs
## it). In its slot (Boat.NET), a player aboard casts it or hauls it in
## (Msg.NET; taken out of its slot it is hauled in too). Cast, it wears: a
## point every WEAR_SECONDS in the water, FAST_WEAR times as fast dragged
## at speed (over SLOW tiles a second: then it catches nothing),
## CATCH_WEAR for each catch; worn out (Items.NET_DURABILITY) it tears and
## what it held is lost. Over water DEPTH deep or more, still or slow,
## something comes into it every CATCH_SECONDS or so (FishTable.pick for
## the water under the boat: Fishing.water_at, the time, the rain, the
## depth): into a chest aboard with room, else the net keeps it (HOLD at
## most, shown; full, it catches no more). Hauled in, what it holds goes to
## the player. It goes on fishing with nobody aboard. Real seconds (as a
## line's).

const WEAR_SECONDS := 15.0
const FAST_WEAR := 3.0
const CATCH_WEAR := 2
const SLOW := 2.5
const DEPTH := 2
const CATCH_SECONDS := Vector2(20.0, 45.0)
const HOLD := 8


static func has_net(boat: Boat) -> bool:
	return boat.slots.items[Boat.NET] == Items.Id.FISHING_NET


## How many things the net holds.
static func held(boat: Boat) -> int:
	var count := 0
	for item: int in boat.net_catch:
		count += boat.net_catch[item]
	return count


## A player aboard casts their boat's net, or hauls it in.
static func toggle(server: GameServer, session: GameServer.PlayerSession) -> void:
	var boat: Boat = server.boats.living.get(session.boat)
	if boat == null or not has_net(boat) or boat.yard != Boat.NO_YARD:
		return
	boat.net_down = not boat.net_down
	boat.net_waiting = server.rng.randf_range(CATCH_SECONDS.x, CATCH_SECONDS.y)
	if not boat.net_down:
		haul(server, session, boat)
	server.broadcast(Msg.boat(boat))


## What the net holds goes to a player: into the bag, else at their feet.
static func haul(server: GameServer, session: GameServer.PlayerSession, boat: Boat) -> void:
	if boat.net_catch.is_empty():
		return
	for item: int in boat.net_catch:
		var left := session.inventory.add(item, boat.net_catch[item])
		if left > 0:
			server.throw_item(session, item, left)
	boat.net_catch.clear()
	session.transport.send(Msg.inventory(session.inventory))


## A cast net fishes and wears for `delta` seconds (see the class).
static func update(server: GameServer, boat: Boat, delta: float) -> void:
	if not boat.net_down or boat.yard != Boat.NO_YARD:
		return
	if not has_net(boat):
		boat.net_down = false
		server.broadcast(Msg.boat(boat))
		return
	var fast := absf(boat.speed) > SLOW
	boat.net_wearing += delta * (FAST_WEAR if fast else 1.0)
	var worn := 0
	while boat.net_wearing >= WEAR_SECONDS:
		boat.net_wearing -= WEAR_SECONDS
		worn += 1
	var cell := Vector3i(floori(boat.at.x), BoatBody.water_row(boat), floori(boat.at.z))
	var depth := Fishing.depth_at(server.world, cell)
	if not fast and depth >= DEPTH:
		boat.net_waiting -= delta
		if boat.net_waiting <= 0.0:
			boat.net_waiting = server.rng.randf_range(CATCH_SECONDS.x, CATCH_SECONDS.y)
			if _catch(server, boat, cell, depth):
				worn += CATCH_WEAR
	if worn > 0:
		_wear(server, boat, worn)


## Something comes into the net: into a chest aboard, else the net (not
## when full). Returns whether it did.
static func _catch(server: GameServer, boat: Boat, cell: Vector3i, depth: int) -> bool:
	var water := Fishing.water_at(server.world, cell)
	var time := FishTable.time_of(server.clock)
	if water.x == FishTable.Water.CAVE:
		time = FishTable.Period.NIGHT
	var raining := server.weather.is_raining()
	var caught := FishTable.pick(server.rng, water.x, water.y, time, raining, depth, Items.Id.NONE)
	var places := boat.chests.keys()
	places.sort()
	for place: int in places:
		if _put(boat.chests[place], caught):
			var chest_cell := Boats.chest_cell(boat.id, place)
			for session in server.sessions:
				if session.joined and session.chest == chest_cell:
					session.transport.send(Msg.chest(chest_cell, boat.chests[place]))
			return true
	if held(boat) >= HOLD:
		return false
	boat.net_catch[caught] = boat.net_catch.get(caught, 0) + 1
	server.broadcast(Msg.boat(boat))
	return true


## Puts one item in a chest's slots (the same item first). Returns
## whether there was room.
static func _put(chest: Inventory, item: int) -> bool:
	var empty := -1
	for slot in Inventory.CHEST:
		if chest.items[slot] == item and chest.counts[slot] < Items.max_stack(item):
			chest.counts[slot] += 1
			return true
		if chest.items[slot] == Items.Id.NONE and empty < 0:
			empty = slot
	if empty < 0:
		return false
	chest.items[empty] = item
	chest.counts[empty] = 1
	chest.wear[empty] = 0
	return true


## The net wears `points`; worn out, it tears (its catch lost, the
## riders told).
static func _wear(server: GameServer, boat: Boat, points: int) -> void:
	for i in points:
		if boat.slots.wear_out(Boat.NET):
			boat.net_down = false
			boat.net_catch.clear()
			for session in server.sessions:
				if session.joined and session.boat == boat.id:
					session.transport.send(Msg.notice("HUD_NET_TORN"))
			break
	server.broadcast(Msg.boat(boat))
