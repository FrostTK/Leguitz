class_name Boats
extends RefCounted
## The boats on the server (held by GameServer; saved in boats.cfg). A
## shipyard (a block on a bank, facing the water: `water_side`) builds one
## on its slipway: its screen (Msg.OPEN_YARD) shows the boat there, its
## parts put in like a chest's (Msg.BOAT_CLICK, Boat.click; the hull only
## there), and launches it (Msg.BOAT_ACT LAUNCH: on the water in front, if
## there is room); a boat moored near a free shipyard with nobody aboard
## goes back up its slipway (DOCK) whole. A boat's own screen (Msg.OPEN_BOAT,
## E aboard) changes its engine, fuel, benches and chests anywhere and opens
## its chests (OPEN_CHEST: a chest screen; their cells are chest_cell's). A
## player boards (Msg.BOARD: the pilot's place, else a free bench), with
## the animals they lead on free benches, and leaves (Msg.LEAVE_BOAT: onto
## the nearest bank, else into the water). The pilot's client steps the boat
## (BoatBody) and reports it (Msg.BOAT_STEER); the server keeps riders on
## their seats, burns coal while the engine runs (COAL_SECONDS each, more at
## full throttle), tires a rowing pilot, and burns a boat touching lava.
## Struck BREAK_HITS times (an axe twice as hard; Msg.BOAT_HIT) with nobody
## aboard, a boat breaks into its parts and what it carries; so does the one
## on a shipyard broken. Its net fishes (Nets: Msg.NET casts it or hauls
## it in). A pot of paint in hand paints its hull, or its stripe (Shift; an
## axe scrapes it: Msg.BOAT_PAINT; a pot gives Items.PAINT_COATS coats, then
## its glass bottle is left). Every player is told of every boat (Msg.BOAT,
## BOAT_MOVE, BOAT_REMOVE, BOAT_HURT).

enum Act { LAUNCH, DOCK, OPEN_CHEST }

## Seconds a coal (or charcoal) runs the engine, how much faster it burns
## at full throttle.
const COAL_SECONDS := 60.0
const FULL_BURN := 1.8
## Effort a second of rowing (Survival.spend), like walking.
const ROW_EFFORT := 0.04
const BREAK_HITS := 6
const HIT_FORGET := 4.0
## A boat moors this near a shipyard's slipway to go back up it (tiles).
const DOCK_RANGE := 4.0
## Water a shipyard needs in front of it (tiles).
const LAUNCH_ROOM := 5
## How far (tiles) a player reaches a boat, leaves it for a bank, and an
## animal they lead comes aboard from.
const REACH := 5.5
const LANDING := 3
const LEAD_RANGE := 8.0
## Moving boats are told every MOVE_TICKS.
const MOVE_TICKS := 2
## A boat's chest is opened as the chest of a cell of this row and under
## (x: the boat, y: CHEST_ROW - its place).
const CHEST_ROW := -10
## The messages handled here.
const MESSAGES: Array[String] = [
	Msg.OPEN_YARD,
	Msg.OPEN_BOAT,
	Msg.BOAT_CLICK,
	Msg.BOAT_ACT,
	Msg.BOARD,
	Msg.LEAVE_BOAT,
	Msg.BOAT_STEER,
	Msg.BOAT_HIT,
	Msg.NET,
	Msg.BOAT_PAINT,
]

var living: Dictionary[int, Boat] = {}
var _next_id := 1
var _hits: Dictionary[int, Vector2] = {}
var _ticks := 0


## The side of a shipyard at `cell` facing water (LAUNCH_ROOM tiles of it
## in a row, a row or two under the bank); `prefer` first (ZERO: none).
static func water_side(cell: Vector3i, voxel_at: Callable, prefer := Vector2i.ZERO) -> Vector2i:
	var sides: Array[Vector2i] = [prefer]
	sides.append_array(ObjectShapes.WAYS)
	for side in sides:
		if side == Vector2i.ZERO:
			continue
		var row := launch_row(cell, side, voxel_at)
		if row == -1:
			continue
		var open := true
		for k in range(1, LAUNCH_ROOM + 1):
			var water := Vector3i(cell.x + side.x * k, row, cell.z + side.y * k)
			if not Voxels.is_water(voxel_at.call(water)):
				open = false
		if open:
			return side
	return Vector2i.ZERO


## The water row in front of a shipyard (a row or two under it; -1: none).
static func launch_row(cell: Vector3i, side: Vector2i, voxel_at: Callable) -> int:
	for down in range(1, 4):
		var at := Vector3i(cell.x + side.x, cell.y - down, cell.z + side.y)
		if (
			Voxels.is_water(voxel_at.call(at))
			and not Voxels.is_water(voxel_at.call(at + Vector3i.UP))
		):
			return at.y
	return -1


## Where a boat lies on a shipyard's slipway: its stern at the yard, its
## bow out over the water.
static func cradle(boat: Boat, cell: Vector3i, front: Vector2i) -> void:
	var middle := (
		Vector2(cell.x + 0.5, cell.z + 0.5) + Vector2(front) * (boat.length() * 0.5 + 0.05)
	)
	boat.at = Vector3(middle.x, cell.y - GameConst.SEA_LEVEL + 0.25, middle.y)
	boat.yaw = atan2(front.x, front.y)
	boat.speed = 0.0


## The cell of a boat's chest, opened like a chest's.
static func chest_cell(id: int, place: int) -> Vector3i:
	return Vector3i(id, CHEST_ROW - place, 0)


## The chest of a boat's chest cell (null: none).
func chest_at(cell: Vector3i) -> Inventory:
	var boat: Boat = living.get(cell.x)
	return null if boat == null else boat.chests.get(CHEST_ROW - cell.y)


## The boat on a shipyard (null: none).
func on_yard(cell: Vector3i) -> Boat:
	for boat: Boat in living.values():
		if boat.yard == cell:
			return boat
	return null


## Handles a boat message; false if it is not one.
func handle(server: GameServer, session: GameServer.PlayerSession, message: Dictionary) -> bool:
	if not message.get("t") in MESSAGES:
		return false
	if not session.joined:
		return true
	match message.get("t"):
		Msg.OPEN_YARD:
			_open_yard(server, session, message.get("cell", GameServer.NO_CELL))
		Msg.OPEN_BOAT:
			_open_boat(server, session, int(message.get("id", -1)))
		Msg.BOAT_CLICK:
			_click(server, session, message)
		Msg.BOAT_ACT:
			_act(server, session, int(message.get("act", -1)), int(message.get("place", -1)))
		Msg.BOARD:
			board(server, session, int(message.get("id", -1)))
		Msg.LEAVE_BOAT:
			leave(server, session, true)
		Msg.BOAT_STEER:
			_steer(session, message)
		Msg.BOAT_HIT:
			_hit(server, session, int(message.get("id", -1)), int(message.get("slot", -1)))
		Msg.NET:
			Nets.toggle(server, session)
		Msg.BOAT_PAINT:
			_paint(server, session, message)
	return true


## A new player is shown every boat.
func welcome(session: GameServer.PlayerSession) -> void:
	for boat: Boat in living.values():
		session.transport.send(Msg.boat(boat))


## Every tick: riders kept on their seats, coal burning, rowing tiring,
## lava; moving boats told.
func update(server: GameServer, delta: float) -> void:
	_ticks += 1
	for boat: Boat in living.values():
		_check_riders(server, boat)
		if boat.yard != Boat.NO_YARD:
			continue
		Nets.update(server, boat, delta)
		_seat_riders(server, boat)
		if boat.pilot < 0:
			boat.throttle = 0.0
			continue
		_burn(server, boat, delta)
		var row := BoatBody.water_row(boat)
		if BoatBody.touches_lava(boat, row, server.world.loaded_voxel_at):
			_destroy(server, boat, true)
			continue
		if _ticks % MOVE_TICKS == 0:
			server.broadcast(Msg.boat_move(boat))


## A player boards a boat (see the class): the pilot's place if free, else
## a free bench; the animals they lead take the other free benches.
func board(server: GameServer, session: GameServer.PlayerSession, id: int) -> void:
	var boat: Boat = living.get(id)
	if boat == null or session.boat >= 0 or not session.alive() or boat.yard != Boat.NO_YARD:
		return
	if _distance(session, boat) > REACH + boat.length() * 0.5:
		return
	var place := -1 if boat.pilot < 0 else boat.free_bench()
	if place == -1 and boat.pilot >= 0:
		session.transport.send(Msg.notice("HUD_BOAT_FULL"))
		return
	if place < 0:
		boat.pilot = session.id
		boat.speed = 0.0
	else:
		boat.seats[place] = session.id
	session.boat = id
	session.seat = place
	for creature: Creature in server.creatures.living.values():
		var animal := creature as Animal
		if animal == null or animal.leader != session.id or animal.seated >= 0:
			continue
		var bench := boat.free_bench(true)
		var away := animal.center().distance_to(session.position) / GameConst.TILE_SIZE
		if bench < 0 or away > LEAD_RANGE:
			continue
		boat.seats[bench] = -animal.id
		animal.seated = id
	_seat_riders(server, boat)
	server.broadcast(Msg.boat(boat))


## A player leaves their boat: onto the nearest bank within LANDING
## tiles, else into the water beside it (`landing` false: where they are);
## the animals they lead with them.
func leave(server: GameServer, session: GameServer.PlayerSession, landing: bool) -> void:
	var boat: Boat = living.get(session.boat)
	session.boat = -1
	session.seat = -1
	if boat == null:
		return
	var seat := boat.seat(-1)
	if boat.pilot == session.id:
		boat.pilot = -1
		boat.throttle = 0.0
		boat.speed = 0.0
	for place: int in boat.seats.keys():
		if boat.seats[place] == session.id:
			seat = boat.seat(place)
			boat.seats.erase(place)
	var spot := Vector3(seat.x, seat.y, seat.z)
	if landing:
		spot = _landing(server, boat, Vector2(seat.x, seat.z))
		var feet := Vector2(spot.x, spot.z) * GameConst.TILE_SIZE
		session.position = feet
		session.height = spot.y
		session.transport.send(Msg.player_teleport(feet, spot.y))
	for place: int in boat.seats.keys():
		var animal := server.creatures.living.get(-boat.seats[place]) as Animal
		if animal != null and animal.leader == session.id:
			boat.seats.erase(place)
			_unseat(animal, spot)
	server.broadcast(Msg.boat(boat))


## A shipyard was broken: the boat on its slipway breaks into its parts.
func yard_broken(server: GameServer, cell: Vector3i) -> void:
	var boat := on_yard(cell)
	if boat != null:
		_destroy(server, boat, false)


## The screens' state is gone (the inventory closed).
func closed(session: GameServer.PlayerSession) -> void:
	session.boat_open = -1
	session.yard_open = GameServer.NO_CELL


func to_save() -> Dictionary:
	var saved: Array[Dictionary] = []
	for boat: Boat in living.values():
		var data := boat.to_dict()
		data["pilot"] = -1
		data["seats"] = {}
		data["speed"] = 0.0
		saved.append(data)
	return {"boats": saved, "next": _next_id}


func load_save(data: Dictionary) -> void:
	living.clear()
	_next_id = int(data.get("next", 1))
	for saved: Dictionary in data.get("boats", []):
		var boat := Boat.from_dict(saved)
		boat.pilot = -1
		boat.seats.clear()
		living[boat.id] = boat
		_next_id = maxi(_next_id, boat.id + 1)


# ---------------------------------------------------------------- screens


func _open_yard(server: GameServer, session: GameServer.PlayerSession, cell: Vector3i) -> void:
	var block := Voxels.block_of(server.world.voxel_at(cell))
	var near := Mining.reach_to(session.position, session.height, cell)
	if not ObjectShapes.is_shipyard(block) or near > Mining.REACH + GameServer.REACH_LEEWAY:
		return
	session.yard_open = cell
	var boat := on_yard(cell)
	session.boat_open = boat.id if boat != null else -1
	session.transport.send(Msg.boat_screen(cell, session.boat_open))


func _open_boat(server: GameServer, session: GameServer.PlayerSession, id: int) -> void:
	var boat: Boat = living.get(id)
	if boat == null:
		return
	if boat.yard != Boat.NO_YARD:
		_open_yard(server, session, boat.yard)
		return
	if session.boat != id and _distance(session, boat) > REACH + boat.length() * 0.5:
		return
	session.yard_open = GameServer.NO_CELL
	session.boat_open = id
	session.transport.send(Msg.boat_screen(GameServer.NO_CELL, id))


## A click on the open screen's boat (a shipyard's makes one when a part
## goes on its empty slipway, and lets go of an empty one).
func _click(server: GameServer, session: GameServer.PlayerSession, message: Dictionary) -> void:
	var at_yard := session.yard_open != GameServer.NO_CELL
	var boat: Boat = living.get(session.boat_open)
	if at_yard and boat == null:
		if not ObjectShapes.is_shipyard(Voxels.block_of(server.world.voxel_at(session.yard_open))):
			return
		boat = Boat.new()
		boat.id = _next_id
		_next_id += 1
		boat.yard = session.yard_open
		living[boat.id] = boat
		session.boat_open = boat.id
	if boat == null:
		return
	var slot := int(message.get("slot", -1))
	var right: bool = message.get("right", false)
	var shift: bool = message.get("shift", false)
	var refused := boat.click(session.inventory, slot, right, shift, at_yard)
	if refused.begins_with("HUD_"):
		session.transport.send(Msg.notice(refused))
	if not Nets.has_net(boat):
		# Its net taken out: hauled in.
		boat.net_down = false
		Nets.haul(server, session, boat)
	session.transport.send(Msg.inventory(session.inventory))
	if at_yard:
		var front := ObjectShapes.front_of(Voxels.block_of(server.world.voxel_at(boat.yard)))
		cradle(boat, boat.yard, front)
		if boat.contents().is_empty():
			living.erase(boat.id)
			server.broadcast(Msg.boat_remove(boat.id, false))
			session.boat_open = -1
			session.transport.send(Msg.boat_screen(session.yard_open, -1))
			return
	server.broadcast(Msg.boat(boat))
	if session.boat_open == boat.id and at_yard:
		session.transport.send(Msg.boat_screen(session.yard_open, boat.id))


func _act(server: GameServer, session: GameServer.PlayerSession, act: int, place: int) -> void:
	var boat: Boat = living.get(session.boat_open)
	if boat == null:
		return
	match act:
		Act.LAUNCH:
			_launch(server, session, boat)
		Act.DOCK:
			_dock(server, session, boat)
		Act.OPEN_CHEST:
			var chest: Inventory = boat.chests.get(place)
			if chest != null:
				var cell := chest_cell(boat.id, place)
				session.chest = cell
				session.transport.send(Msg.chest(cell, chest))


## Down the slipway onto the water in front (room for its hull there).
func _launch(server: GameServer, session: GameServer.PlayerSession, boat: Boat) -> void:
	if boat.yard == Boat.NO_YARD or not boat.complete():
		return
	var voxel_at := server.world.loaded_voxel_at
	var front := ObjectShapes.front_of(Voxels.block_of(voxel_at.call(boat.yard)))
	var row := launch_row(boat.yard, front, voxel_at)
	var middle := Vector2(boat.yard.x + 0.5, boat.yard.z + 0.5)
	middle += Vector2(front) * (1.1 + boat.length() * 0.5)
	var water := Vector3(middle.x, row - GameConst.SEA_LEVEL + 1.0, middle.y)
	var yaw := atan2(front.x, front.y)
	if row == -1 or not BoatBody.fits(boat, water, yaw, row, voxel_at):
		session.transport.send(Msg.notice("HUD_BOAT_NO_ROOM"))
		return
	boat.yard = Boat.NO_YARD
	boat.at = Vector3(water.x, BoatBody.surface_at(water, row, voxel_at), water.z)
	boat.yaw = yaw
	boat.speed = 0.0
	server.broadcast(Msg.boat(boat))
	session.transport.send(Msg.boat_screen(GameServer.NO_CELL, boat.id))
	session.yard_open = GameServer.NO_CELL


## Up the slipway of the nearest free shipyard within DOCK_RANGE.
func _dock(server: GameServer, session: GameServer.PlayerSession, boat: Boat) -> void:
	if boat.yard != Boat.NO_YARD or not boat.is_empty():
		session.transport.send(Msg.notice("HUD_BOAT_ABOARD"))
		return
	var best := GameServer.NO_CELL
	var nearest := INF
	var reach := ceili(DOCK_RANGE + boat.length() * 0.5)
	var row := BoatBody.water_row(boat)
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			for dy in range(1, 4):
				var cell := Vector3i(floori(boat.at.x) + dx, row + dy, floori(boat.at.z) + dz)
				var block := Voxels.block_of(server.world.loaded_voxel_at(cell))
				if not ObjectShapes.is_shipyard(block) or on_yard(cell) != null:
					continue
				var away := Vector2(cell.x + 0.5 - boat.at.x, cell.z + 0.5 - boat.at.z).length()
				if away < nearest:
					nearest = away
					best = cell
	if best == GameServer.NO_CELL or nearest > DOCK_RANGE + boat.length() * 0.5:
		session.transport.send(Msg.notice("HUD_BOAT_NO_YARD"))
		return
	boat.yard = best
	cradle(boat, best, ObjectShapes.front_of(Voxels.block_of(server.world.voxel_at(best))))
	server.broadcast(Msg.boat(boat))
	session.yard_open = best
	session.transport.send(Msg.boat_screen(best, boat.id))


# ---------------------------------------------------------------- afloat


## The pilot's report of where the boat went (see BoatBody): taken if it
## is not too far from the last, else they are told where it is.
func _steer(session: GameServer.PlayerSession, message: Dictionary) -> void:
	var boat: Boat = living.get(session.boat)
	if boat == null or boat.pilot != session.id or boat.yard != Boat.NO_YARD:
		return
	var at: Variant = message.get("at", boat.at)
	if not at is Vector3 or (at as Vector3).distance_to(boat.at) > 2.0:
		session.transport.send(Msg.boat_move(boat, true))
		return
	boat.at = at
	boat.yaw = float(message.get("yaw", boat.yaw))
	boat.speed = clampf(float(message.get("speed", 0.0)), -BoatBody.FULL_SPEED, BoatBody.FULL_SPEED)
	boat.throttle = clampf(float(message.get("throttle", 0.0)), -1.0, 1.0)
	boat.full = message.get("full", false)


## The engine burns coal while it pushes (the next one when one is out);
## rowing tires the pilot.
func _burn(server: GameServer, boat: Boat, delta: float) -> void:
	if boat.throttle == 0.0:
		return
	if not boat.powered():
		var rower := server.session_of(boat.pilot)
		if rower != null:
			Survival.spend(server, rower, ROW_EFFORT * delta)
		return
	boat.burn -= delta * (FULL_BURN if boat.full else 1.0)
	if boat.burn > 0.0:
		return
	if boat.fuel() > 0:
		boat.slots.take(Boat.FUEL, 1)
		boat.burn += COAL_SECONDS
	else:
		boat.burn = 0.0
	server.broadcast(Msg.boat(boat))


## Riders gone (left the game, passed out, an animal gone) leave their
## seats.
func _check_riders(server: GameServer, boat: Boat) -> void:
	var changed := false
	if boat.pilot >= 0:
		var pilot := server.session_of(boat.pilot)
		if pilot == null or not pilot.alive() or pilot.boat != boat.id:
			boat.pilot = -1
			boat.throttle = 0.0
			boat.speed = 0.0
			changed = true
	for place: int in boat.seats.keys():
		var rider := boat.seats[place]
		var gone := false
		if rider > 0:
			var player := server.session_of(rider)
			gone = player == null or not player.alive() or player.boat != boat.id
		else:
			gone = not server.creatures.living.has(-rider)
		if gone:
			boat.seats.erase(place)
			changed = true
	if changed:
		server.broadcast(Msg.boat(boat))


## Players and animals aboard sit where their seats are.
func _seat_riders(server: GameServer, boat: Boat) -> void:
	var riders := {}
	if boat.pilot >= 0:
		riders[boat.pilot] = -1
	for place: int in boat.seats:
		riders[boat.seats[place]] = place
	for rider: int in riders:
		var seat := boat.seat(riders[rider])
		if rider > 0:
			var player := server.session_of(rider)
			if player != null:
				player.position = Vector2(seat.x, seat.z) * GameConst.TILE_SIZE
				player.height = seat.y
		elif rider < 0:
			var creature: Creature = server.creatures.living.get(-rider)
			if creature != null:
				creature.body.place(Vector2(seat.x, seat.z) * GameConst.TILE_SIZE, seat.y)
				creature.body.needs_landing = false
				creature.heading = boat.forward()
				creature.dirty = true


## A bank to step onto from a seat (the nearest tile one stands on within
## LANDING tiles, its feet), else the water beside the boat.
func _landing(server: GameServer, boat: Boat, from: Vector2) -> Vector3:
	var row := BoatBody.water_row(boat)
	var best := Vector3.INF
	var nearest := INF
	for dz in range(-LANDING, LANDING + 1):
		for dx in range(-LANDING, LANDING + 1):
			var tile := Vector2i(floori(from.x) + dx, floori(from.y) + dz)
			for up in range(1, 4):
				if not server.world.can_stand(tile, row + up):
					continue
				var middle := Vector2(tile.x + 0.5, tile.y + 0.5)
				var away := middle.distance_to(from)
				if away < nearest:
					nearest = away
					best = Vector3(middle.x, row + up - GameConst.SEA_LEVEL, middle.y)
	if best != Vector3.INF:
		return best
	var side := Vector2(boat.forward().y, -boat.forward().x)
	var water := from + side * (Boat.WIDTH * Boat.VOXEL * 0.5 + 0.6)
	return Vector3(water.x, boat.at.y - 0.5, water.y)


static func _unseat(animal: Animal, spot: Vector3) -> void:
	animal.seated = -1
	animal.body.place(Vector2(spot.x, spot.z) * GameConst.TILE_SIZE, spot.y)
	animal.dirty = true


## A player paints a boat's hull or stripe with the pot in hand, or
## scrapes it with an axe (see the class).
func _paint(server: GameServer, session: GameServer.PlayerSession, message: Dictionary) -> void:
	var boat: Boat = living.get(int(message.get("id", -1)))
	if boat == null or not session.alive():
		return
	if session.boat != boat.id and _distance(session, boat) > REACH + boat.length() * 0.5:
		return
	var bag := session.inventory
	var slot := clampi(int(message.get("slot", 0)), 0, Inventory.HOTBAR - 1)
	var zone := 1 if message.get("stripe", false) else 0
	var item := bag.items[slot]
	var creative := GameModes.creative(server)
	if item in Items.PAINTS:
		boat.paint[zone] = Items.PAINTS.find(item)
		if not creative and bag.wear_out(slot):
			# Its last coat: the glass bottle is left.
			bag.items[slot] = Items.Id.GLASS_BOTTLE
			bag.counts[slot] = 1
	elif Items.tool_of(item) == Items.Tool.AXE and boat.paint[zone] >= 0:
		boat.paint[zone] = -1
		if not creative:
			bag.wear_out(slot)
	else:
		return
	session.transport.send(Msg.inventory(bag))
	server.broadcast(Msg.boat(boat))


## A player strikes a boat with the hotbar slot `slot` in hand (see the
## class).
func _hit(server: GameServer, session: GameServer.PlayerSession, id: int, slot: int) -> void:
	var boat: Boat = living.get(id)
	if boat == null or not boat.is_empty() or not session.alive():
		return
	if _distance(session, boat) > REACH + boat.length() * 0.5:
		return
	var now := server.tick_count * GameConst.TICK_DELTA
	var hits: Vector2 = _hits.get(id, Vector2(0.0, now))
	if now - hits.y > HIT_FORGET:
		hits.x = 0.0
	var bag := session.inventory
	var axe := (
		slot >= 0 and slot < Inventory.HOTBAR and Items.tool_of(bag.items[slot]) == Items.Tool.AXE
	)
	hits = Vector2(hits.x + (2.0 if axe else 1.0), now)
	_hits[id] = hits
	if axe and not GameModes.creative(server):
		bag.wear_out(slot)
		session.transport.send(Msg.inventory(bag))
	server.broadcast(Msg.boat_hurt(id))
	if hits.x >= BREAK_HITS or GameModes.creative(server):
		_destroy(server, boat, false)


## A boat goes: broken, it drops its parts and what it carries; burnt
## (lava), only its chests' contents spill. Its riders are put off.
func _destroy(server: GameServer, boat: Boat, burnt: bool) -> void:
	for session in server.sessions:
		if session.boat == boat.id:
			session.boat = -1
			session.seat = -1
	for place: int in boat.seats:
		var animal := server.creatures.living.get(-boat.seats[place]) as Animal
		if animal != null:
			_unseat(animal, boat.seat(place))
	var drops := boat.contents()
	if burnt:
		drops.clear()
		for place: int in boat.chests:
			var chest := boat.chests[place]
			for slot in Inventory.CHEST:
				if chest.items[slot] != Items.Id.NONE:
					drops.append(Vector2i(chest.items[slot], chest.counts[slot]))
	for drop in drops:
		var throw := Vector3(
			server.rng.randf_range(-1.5, 1.5), 3.0, server.rng.randf_range(-1.5, 1.5)
		)
		server.spawn_item(drop.x, drop.y, boat.at + Vector3(0.0, 0.5, 0.0), throw)
	living.erase(boat.id)
	_hits.erase(boat.id)
	server.broadcast(Msg.boat_remove(boat.id, burnt))


static func _distance(session: GameServer.PlayerSession, boat: Boat) -> float:
	var feet := session.position / GameConst.TILE_SIZE
	return feet.distance_to(Vector2(boat.at.x, boat.at.z))
