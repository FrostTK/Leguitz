class_name GameServer
extends RefCounted
## Authoritative simulation of one world.
##
## In solo play it runs in the same process as the client ("integrated
## server", like Minecraft) and talks to it through a LocalTransport. Later,
## the very same class will run on a host or dedicated server and talk to
## remote clients through a network transport.

const CHUNKS_SENT_PER_TICK := 16
const TIME_BROADCAST_TICKS := GameConst.TICKS_PER_SECOND * 5
const UNLOAD_CHECK_TICKS := GameConst.TICKS_PER_SECOND * 2
## A saved world saves itself this often (real seconds of play), and when
## a player asks (pausing), at most this often.
const AUTOSAVE_TICKS := GameConst.TICKS_PER_SECOND * 120
const SAVE_REQUEST_MSEC := 5000
## Leeway (local units) on the reach of a player breaking or placing (they
## move while their messages travel).
const REACH_LEEWAY := 1.5
## Items lying around: players pick them up within PICKUP_RANGE (local
## units from the body, from a level under the feet, where a hole just dug
## is, to over the head; they fly in at ATTRACT_SPEED), take them within
## COLLECT_RANGE of its middle; their moves are sent every ITEM_SYNC_TICKS.
const PICKUP_RANGE := 2.0
const PICKUP_BELOW := 1.1
const COLLECT_RANGE := 0.5
const ATTRACT_SPEED := 7.0
const ITEM_SYNC_TICKS := 2
## A thrown item leaves the hand this fast (levels per second), forwards
## and up.
const THROW_SPEED := Vector2(6.0, 4.0)
## Max distance (world px) a player may move between two updates before
## the server corrects them. Generous: real validation comes with Phase 3.
const MAX_MOVE_PER_UPDATE := 96.0
## No chest or furnace open.
const NO_CELL := Vector3i(0, -1, 0)
## Furnaces run every FURNACE_TICKS; their players see them as often.
const FURNACE_TICKS := 2
const MAP_MIN_SIZE := 64
const MAP_MAX_SIZE := 512
const MAP_MAX_SCALE := 16


class PlayerSession:
	extends RefCounted
	var id := 0
	var transport: Transport
	var player_name := ""
	var joined := false
	var position := Vector2.ZERO
	var facing := Vector2i.DOWN
	## Feet height in levels (as reported by the client).
	var height := 0.0
	var view_distance := GameConst.DEFAULT_VIEW_DISTANCE
	var sent_chunks: Dictionary[Vector2i, bool] = {}
	var inventory := Inventory.new()
	## Cells across of the crafting grid the player uses (a workbench's is
	## wider than the inventory's).
	var craft_width := Inventory.OWN_GRID
	## The chest the player has open (NO_CELL: none).
	var chest := NO_CELL
	## The furnace the player has open (NO_CELL: none).
	var furnace := NO_CELL
	## Vitality (Vitals); 0: passed out, until they get up (Msg.RESPAWN).
	var health := Vitals.MAX_HEALTH
	## Satiety (Vitals), and the effort spent towards the next point lost.
	var food := Vitals.MAX_FOOD
	var effort := 0.0
	## Seconds left of the immunity after a hurt, since the last hurt, and
	## in lava (towards the next burn) and getting better (the next point).
	var immune := 0.0
	var since_hurt := INF
	var burning := 0.0
	var healing := 0.0
	var starving := 0.0

	func alive() -> bool:
		return health > 0


class MapJob:
	extends RefCounted
	var session: PlayerSession
	var task := -1
	var center := Vector2i.ZERO
	var row := Msg.MAP_SURFACE
	var size := 256
	var scale := 1
	var png := PackedByteArray()


var settings: WorldSettings
var clock: WorldClock
var weather: Weather
var world: WorldState
var generation: ChunkGenerationQueue
var spawn_tile := Vector2i.ZERO
## Dev: players start at spawn_tile even where they were saved elsewhere.
var spawn_forced := false
## Where the world is saved (null: a throwaway world, see use_storage).
var storage: WorldStorage
var tick_count := 0
## Items lying in the world, by id.
var items: Dictionary[int, DroppedItem] = {}
## Debug commands (moving between caves, world map). Restricted to
## creative mode and server operators once those exist.
var allow_debug_commands := true
## Draws what breaks drop and where things fly.
var rng := RandomNumberGenerator.new()

var _sessions: Array[PlayerSession] = []
var _last_save_msec := -SAVE_REQUEST_MSEC
var _next_item_id := 1
var _next_player_id := 1
var _map_jobs: Array[MapJob] = []


func _init(world_settings: WorldSettings, world_clock: WorldClock = null, threaded := true) -> void:
	settings = world_settings
	clock = world_clock if world_clock != null else WorldClock.new()
	weather = Weather.new(settings.world_seed)
	var generator := WorldGenerator.new(settings.world_seed)
	world = WorldState.new(generator)
	generation = ChunkGenerationQueue.new(generator, threaded)
	spawn_tile = generator.find_spawn_tile()
	clock.sync_to_device()


## Saves the world in `world_storage` from now on. `saved`: what it held
## (WorldStorage.read_world; the settings and clock were read from it to
## create this server); a new world is saved right away.
func use_storage(world_storage: WorldStorage, saved: Dictionary) -> void:
	storage = world_storage
	world.storage = world_storage
	if saved.is_empty():
		save()
		return
	weather.load_dict(saved.get("weather", {}))
	for data: Dictionary in saved.get("items", []):
		var dropped := DroppedItem.from_dict(data)
		if Items.is_valid(dropped.item) and dropped.count > 0:
			dropped.id = _next_item_id
			_next_item_id += 1
			items[dropped.id] = dropped


## Writes the world to its storage: settings, clock, weather, players and
## the chunks they changed. False if something could not be written (or
## the world is not saved).
func save() -> bool:
	if storage == null:
		return false
	_last_save_msec = Time.get_ticks_msec()
	world.store_changed()
	var lying: Array[Dictionary] = []
	for dropped: DroppedItem in items.values():
		lying.append(dropped.to_dict())
	var ok := storage.save_world(settings, clock, weather, lying)
	for session in _sessions:
		if session.joined:
			ok = storage.save_player(session.player_name, player_state(session)) and ok
	ok = storage.flush() and ok
	if ok:
		_broadcast(Msg.world_saved())
	else:
		push_warning("The world could not be saved in %s" % storage.folder)
	return ok


## What is saved of a player.
static func player_state(session: PlayerSession) -> Dictionary:
	return {
		"position": session.position,
		"height": session.height,
		"facing": session.facing,
		"inventory": session.inventory.to_dict(),
		"health": session.health,
		"food": session.food,
	}


## Puts an item in the world (it falls, then waits to be picked up).
func spawn_item(
	item: int, count: int, at: Vector3, speed: Vector3, delay := DroppedItem.PICKUP_DELAY
) -> DroppedItem:
	var dropped := DroppedItem.create(item, count, at, speed)
	dropped.id = _next_item_id
	_next_item_id += 1
	dropped.pickup_delay = delay
	items[dropped.id] = dropped
	_broadcast(Msg.item_spawn(dropped))
	return dropped


## Waits for background work; call before quitting.
func shutdown() -> void:
	generation.wait_all()
	generation.collect()
	for job in _map_jobs:
		if job.task >= 0:
			WorkerThreadPool.wait_for_task_completion(job.task)
	_map_jobs.clear()


func connect_client(transport: Transport) -> void:
	var session := PlayerSession.new()
	session.transport = transport
	_sessions.append(session)


func player_count() -> int:
	return _sessions.size()


func first_session() -> PlayerSession:
	return _sessions[0] if not _sessions.is_empty() else null


## Handles every pending client message. Runs even while the simulation is
## paused so that menus (e.g. time settings) keep working.
func process_messages() -> void:
	for session in _sessions:
		for message in session.transport.poll():
			_handle_message(session, message)
	_send_finished_maps()


## Advances the simulation by one fixed step (1/20 s).
func tick() -> void:
	tick_count += 1
	clock.advance(GameConst.TICK_DELTA)
	clock.sync_to_device()
	if weather.tick(GameConst.TICK_DELTA, clock):
		_broadcast(Msg.weather_state(weather))
	_collect_generated()
	for session in _sessions:
		if session.joined:
			_stream_chunks(session, CHUNKS_SENT_PER_TICK)
	if tick_count % TIME_BROADCAST_TICKS == 0:
		_broadcast(Msg.time_state(clock))
		_broadcast(Msg.weather_state(weather))
	_update_items(GameConst.TICK_DELTA)
	Survival.update(self, _sessions, GameConst.TICK_DELTA)
	if tick_count % FURNACE_TICKS == 0:
		_update_furnaces(GameConst.TICK_DELTA * FURNACE_TICKS)
	if tick_count % UNLOAD_CHECK_TICKS == 0:
		_unload_unused_chunks()
	if storage != null and tick_count % AUTOSAVE_TICKS == 0:
		save()


func _handle_message(session: PlayerSession, message: Dictionary) -> void:
	match message.get("t"):
		Msg.HELLO:
			_on_hello(session, message)
		Msg.PLAYER_MOVE:
			_on_player_move(session, message)
		Msg.SET_TIME:
			_on_set_time(message)
		Msg.DEBUG_MOVE_DEPTH:
			_on_debug_move_depth(session, message)
		Msg.MAP_REQUEST:
			_on_map_request(session, message)
		Msg.DEBUG_SET_WEATHER:
			_on_debug_set_weather(session, message)
		Msg.DEBUG_GIVE_TOOLS:
			_on_debug_give_tools(session, message)
		Msg.SET_VIEW_DISTANCE:
			_on_set_view_distance(session, message)
		Msg.BLOCK_BREAK:
			_on_block_break(session, message)
		Msg.BLOCK_PLACE:
			_on_block_place(session, message)
		Msg.SELECT_SLOT:
			session.inventory.selected = clampi(
				int(message.get("slot", 0)), 0, Inventory.HOTBAR - 1
			)
		Msg.SLOT_CLICK:
			if session.joined:
				var slot := int(message.get("slot", -1))
				var open := _open_chest(session)
				var oven := _open_furnace(session)
				session.inventory.click(
					slot, message.get("right", false), message.get("shift", false), open, oven
				)
				session.transport.send(Msg.inventory(session.inventory))
				if open != null:
					_chest_changed(session.chest)
				if oven != null:
					_furnace_changed(session.furnace)
		Msg.SLOT_SPREAD:
			_on_slot_spread(session, message)
		Msg.RESPAWN:
			Survival.get_up(self, session)
		Msg.EAT:
			Survival.eat(self, session, int(message.get("slot", -1)))
		Msg.OPEN_CHEST:
			_on_open_chest(session, message)
		Msg.CHEST_CLICK:
			var chest := _open_chest(session)
			if chest != null:
				var slot := int(message.get("slot", -1))
				var right: bool = message.get("right", false)
				session.inventory.click_chest(chest, slot, right, message.get("shift", false))
				session.transport.send(Msg.inventory(session.inventory))
				_chest_changed(session.chest)
		Msg.OPEN_FURNACE:
			_on_open_furnace(session, message)
		Msg.FURNACE_CLICK:
			var oven := _open_furnace(session)
			if oven != null:
				var slot := int(message.get("slot", -1))
				var right: bool = message.get("right", false)
				session.inventory.click_furnace(oven, slot, right, message.get("shift", false))
				session.transport.send(Msg.inventory(session.inventory))
				_furnace_changed(session.furnace)
		Msg.ITEM_DROP:
			_on_item_drop(session, message)
		Msg.INVENTORY_CLOSE:
			if session.joined:
				for left in session.inventory.put_back_all():
					throw_item(session, left.x, left.y, left.z)
				session.craft_width = Inventory.OWN_GRID
				session.chest = NO_CELL
				session.furnace = NO_CELL
				session.transport.send(Msg.inventory(session.inventory))
		Msg.OPEN_WORKBENCH:
			_on_open_workbench(session, message)
		Msg.CRAFT:
			if session.joined:
				session.inventory.craft(session.craft_width, message.get("shift", false))
				session.transport.send(Msg.inventory(session.inventory))
		Msg.SAVE_REQUEST:
			if session.joined and Time.get_ticks_msec() - _last_save_msec >= SAVE_REQUEST_MSEC:
				save()
		var unknown:
			push_warning("Server: unknown message type %s" % unknown)


func _on_hello(session: PlayerSession, message: Dictionary) -> void:
	if session.joined:
		return
	session.id = _next_player_id
	_next_player_id += 1
	session.player_name = str(message.get("name", "Player"))
	session.view_distance = _clamp_view_distance(
		message.get("view_distance", GameConst.DEFAULT_VIEW_DISTANCE)
	)
	_place_player(session)
	session.joined = true
	session.transport.send(
		Msg.welcome(session.id, session.position, session.height, settings.to_dict())
	)
	session.transport.send(Msg.time_state(clock))
	session.transport.send(Msg.weather_state(weather))
	session.transport.send(Msg.inventory(session.inventory))
	session.transport.send(Msg.vitals(session.health, session.food))
	for dropped: DroppedItem in items.values():
		session.transport.send(Msg.item_spawn(dropped))
	# Start generating the whole initial view right away.
	_stream_chunks(session, CHUNKS_SENT_PER_TICK)
	_collect_generated()
	_stream_chunks(session, CHUNKS_SENT_PER_TICK)


## Where a joining player starts: where they were saved, or at the spawn.
func _place_player(session: PlayerSession) -> void:
	var saved := storage.load_player(session.player_name) if storage != null else {}
	session.inventory.load_dict(saved.get("inventory", {}))
	session.health = clampi(int(saved.get("health", Vitals.MAX_HEALTH)), 0, Vitals.MAX_HEALTH)
	session.food = clampi(int(saved.get("food", Vitals.MAX_FOOD)), 0, Vitals.MAX_FOOD)
	if session.health == 0:
		# They left while passed out: they get up at the spawn.
		session.health = Vitals.MAX_HEALTH
		session.food = Vitals.MAX_FOOD
		saved.erase("position")
	if saved.has("position") and not spawn_forced:
		session.position = saved["position"]
		session.height = saved.get("height", 0.0)
		session.facing = saved.get("facing", Vector2i.DOWN)
		# Never inside the ground (the world may have changed since); on
		# top of furniture is fine.
		var tile := Coords.world_to_tile(session.position)
		var row := floori(session.height + 0.01) + GameConst.SEA_LEVEL
		var there := world.voxel_at(Vector3i(tile.x, row, tile.y))
		var top := ObjectShapes.stand_height(Voxels.block_of(there))
		var on_top := top > 0.0 and session.height >= row - GameConst.SEA_LEVEL + top - 0.01
		if Voxels.is_solid(there) and not on_top:
			session.height = world.surface_height(tile)
		return
	session.position = Coords.tile_to_world_center(spawn_tile) + Vector2(0, 4)
	session.height = world.surface_height(spawn_tile)


## A player broke a voxel: gone if it can be broken and is within reach,
## and what stood on it with it. Refused, the player is told what is there.
func _on_block_break(session: PlayerSession, message: Dictionary) -> void:
	if not session.joined or not session.alive():
		return
	var cell: Vector3i = message.get("cell", Vector3i.ZERO)
	var voxel := world.voxel_at(cell)
	var near := Mining.reach_to(session.position, session.height, cell)
	if not Mining.can_break(voxel, cell.y) or near > Mining.REACH + REACH_LEEWAY:
		session.transport.send(Msg.block_changed(cell, voxel))
		return
	# The tool in hand wears (and may break).
	var slot := int(message.get("slot", -1))
	if slot >= 0 and slot < Inventory.HOTBAR and Mining.wears(voxel):
		var bag := session.inventory
		if Items.durability(bag.items[slot]) > 0:
			bag.wear_out(slot)
			session.transport.send(Msg.inventory(bag))
	# The whole object goes (both ends of a workbench), and what stood on it.
	var cells := Mining.object_cells(cell, voxel, world.voxel_at)
	for part in cells:
		change_voxel(part, Mining.left_after_break(part, world.voxel_at))
	_drop_from(cell, voxel)
	_spill_contents(cell)
	Survival.spend(self, session, Vitals.BREAK_EFFORT)
	for part in cells:
		var above := part + Vector3i.UP
		var standing := world.voxel_at(above)
		if Mining.needs_support(standing):
			for piece in Mining.object_cells(above, standing, world.voxel_at):
				change_voxel(piece, Voxels.AIR)
			_drop_from(above, standing)


## A chest or a furnace broken: what it held falls out where it was.
func _spill_contents(cell: Vector3i) -> void:
	var chest := world.take_chest(cell)
	if chest != null:
		_spill(cell, chest, Inventory.CHEST)
	var furnace := world.take_furnace(cell)
	if furnace != null:
		_spill(cell, furnace.slots, Furnace.SLOTS)
	world.contents_changed(cell)
	for other in _sessions:
		if other.chest == cell:
			other.chest = NO_CELL
		if other.furnace == cell:
			other.furnace = NO_CELL


func _spill(cell: Vector3i, holder: Inventory, slots: int) -> void:
	var middle := Vector3(cell.x + 0.5, cell.y - GameConst.SEA_LEVEL + 0.5, cell.z + 0.5)
	for slot in slots:
		if holder.items[slot] != Items.Id.NONE:
			var speed := Vector3(rng.randf_range(-1.5, 1.5), 3.0, rng.randf_range(-1.5, 1.5))
			var dropped := spawn_item(holder.items[slot], holder.counts[slot], middle, speed)
			dropped.wear = holder.wear[slot]


## What a broken voxel gives falls where it was.
func _drop_from(cell: Vector3i, voxel: int) -> void:
	var tile := Vector2i(cell.x, cell.z)
	var middle := Vector3(cell.x + 0.5, cell.y - GameConst.SEA_LEVEL + 0.5, cell.z + 0.5)
	for drop in Items.drops(voxel, tile, rng):
		var speed := Vector3(rng.randf_range(-1.0, 1.0), 3.0, rng.randf_range(-1.0, 1.0))
		spawn_item(drop.x, drop.y, middle, speed)


## A player placed the block of a hotbar slot: kept if it is a block,
## within reach, against the terrain, into air, water or a small plant, and
## in nobody's way; it leaves the slot. Refused, the player is told what is
## there (and what they hold).
func _on_block_place(session: PlayerSession, message: Dictionary) -> void:
	if not session.joined or not session.alive():
		return
	var cell: Vector3i = message.get("cell", Vector3i.ZERO)
	var slot := clampi(int(message.get("slot", 0)), 0, Inventory.HOTBAR - 1)
	var voxel := Items.placed_voxel(session.inventory.items[slot])
	var front: Vector2i = message.get("front", Vector2i(0, 1))
	if absi(front.x) + absi(front.y) != 1:
		front = Vector2i(0, 1)
	var cells := Mining.placement(cell, voxel, front, world.voxel_at)
	var near := Mining.reach_to(session.position, session.height, cell)
	var ok := (
		cell.y >= Mining.LOWEST_ROW
		and cell.y < GameConst.WORLD_HEIGHT
		and Mining.can_place(voxel)
		and not cells.is_empty()
		and near <= Mining.REACH + REACH_LEEWAY
		and (cells.size() > 1 or _against_terrain(cell))
	)
	for other in _sessions:
		for at: Vector3i in cells:
			if ok and other.joined and Mining.overlaps_body(at, other.position, other.height):
				ok = false
	if not ok:
		# What is really there, where the player guessed it changed.
		for at: Vector3i in cells.keys() if not cells.is_empty() else [cell]:
			session.transport.send(Msg.block_changed(at, world.voxel_at(at)))
		session.transport.send(Msg.inventory(session.inventory))
		return
	for at: Vector3i in cells:
		change_voxel(at, cells[at])
	session.inventory.take(slot, 1)
	session.transport.send(Msg.inventory(session.inventory))


## A player shared the stack in hand between slots (a left drag): theirs,
## the open chest's, the open furnace's.
func _on_slot_spread(session: PlayerSession, message: Dictionary) -> void:
	var targets: Variant = message.get("targets", [])
	if not session.joined or not targets is Array:
		return
	var open := _open_chest(session)
	var oven := _open_furnace(session)
	session.inventory.spread(
		(targets as Array).slice(0, Inventory.SIZE + Inventory.CHEST), open, oven
	)
	session.transport.send(Msg.inventory(session.inventory))
	if open != null:
		_chest_changed(session.chest)
	if oven != null:
		_furnace_changed(session.furnace)


## A player opened a workbench: crafting uses its whole grid, if there is
## one within reach.
func _on_open_workbench(session: PlayerSession, message: Dictionary) -> void:
	if not session.joined:
		return
	var cell: Vector3i = message.get("cell", Vector3i.ZERO)
	var near := Mining.reach_to(session.position, session.height, cell)
	var there := Voxels.block_of(world.voxel_at(cell))
	if ObjectShapes.is_bench(there) and near <= Mining.REACH + REACH_LEEWAY:
		session.craft_width = Inventory.GRID


## A player opened a chest within reach: they see what it holds, and
## their clicks go to it until they close it.
func _on_open_chest(session: PlayerSession, message: Dictionary) -> void:
	if not session.joined:
		return
	var cell: Vector3i = message.get("cell", Vector3i.ZERO)
	var near := Mining.reach_to(session.position, session.height, cell)
	var there := Voxels.block_of(world.voxel_at(cell))
	if not ObjectShapes.is_chest(there) or near > Mining.REACH + REACH_LEEWAY:
		return
	session.chest = cell
	session.transport.send(Msg.chest(cell, world.chest_at(cell)))


## The chest a player has open (null: none, or it is gone).
func _open_chest(session: PlayerSession) -> Inventory:
	if not session.joined or session.chest == NO_CELL:
		return null
	if not ObjectShapes.is_chest(Voxels.block_of(world.voxel_at(session.chest))):
		return null
	return world.chest_at(session.chest)


## A chest's items changed: saved with its chunk, shown to every player
## who has it open.
func _chest_changed(cell: Vector3i) -> void:
	world.contents_changed(cell)
	for other in _sessions:
		if other.joined and other.chest == cell:
			other.transport.send(Msg.chest(cell, world.chest_at(cell)))


## A player opened a furnace within reach (not a broken one): they see
## it, and their clicks go to it until they close it.
func _on_open_furnace(session: PlayerSession, message: Dictionary) -> void:
	if not session.joined:
		return
	var cell: Vector3i = message.get("cell", Vector3i.ZERO)
	var near := Mining.reach_to(session.position, session.height, cell)
	var there := Voxels.block_of(world.voxel_at(cell))
	if ObjectShapes.furnace_kind(there) == -1 or near > Mining.REACH + REACH_LEEWAY:
		return
	session.furnace = cell
	session.transport.send(Msg.furnace(cell, world.furnace_at(cell)))


## The furnace a player has open (null: none, or it is gone).
func _open_furnace(session: PlayerSession) -> Furnace:
	if not session.joined or session.furnace == NO_CELL:
		return null
	if ObjectShapes.furnace_kind(Voxels.block_of(world.voxel_at(session.furnace))) == -1:
		return null
	return world.furnace_at(session.furnace)


## A furnace's slots changed: saved with its chunk, lit or put out, shown
## to every player who has it open.
func _furnace_changed(cell: Vector3i) -> void:
	world.contents_changed(cell)
	_show_fire(cell)
	_send_furnace(cell)


func _send_furnace(cell: Vector3i) -> void:
	for other in _sessions:
		if other.joined and other.furnace == cell:
			other.transport.send(Msg.furnace(cell, world.furnace_at(cell)))


## A furnace's voxel shows whether it burns (its lit kind, the same way).
func _show_fire(cell: Vector3i) -> void:
	var block := Voxels.block_of(world.voxel_at(cell))
	var kind := ObjectShapes.furnace_kind(block)
	if kind == -1:
		return
	var lit := world.furnace_at(cell).burning()
	var shown := ObjectShapes.facing(
		ObjectShapes.LIT[kind] if lit else kind, ObjectShapes.front_of(block)
	)
	if shown != block:
		change_voxel(cell, Voxels.of_block(shown))


## The furnaces of the loaded chunks burn and cook (`delta`: real
## seconds); the players who opened one see it.
func _update_furnaces(delta: float) -> void:
	for chunk: ChunkData in world.chunks.values():
		if chunk.furnaces.is_empty():
			continue
		for cell: Vector3i in chunk.furnaces.keys():
			var furnace: Furnace = chunk.furnaces[cell]
			var was := [furnace.fire, furnace.progress]
			match furnace.step(delta, clock):
				Furnace.Step.BROKE:
					_break_furnace(cell)
				Furnace.Step.CHANGED:
					_furnace_changed(cell)
				_:
					if was != [furnace.fire, furnace.progress]:
						_send_furnace(cell)


## Ore melted in a food furnace: it breaks (the ore is lost), what it held
## spills, and it is useless.
func _break_furnace(cell: Vector3i) -> void:
	var block := Voxels.block_of(world.voxel_at(cell))
	_spill_contents(cell)
	var broken := ObjectShapes.facing(Tiles.Block.BROKEN_FURNACE, ObjectShapes.front_of(block))
	change_voxel(cell, Voxels.of_block(broken))


## A player throws one item of a slot, or its whole stack.
func _on_item_drop(session: PlayerSession, message: Dictionary) -> void:
	if not session.joined:
		return
	var slot := int(message.get("slot", -1))
	if slot < 0 or slot > Inventory.CURSOR:
		return
	var item := session.inventory.items[slot]
	var worn := session.inventory.wear[slot]
	var whole: bool = message.get("whole", false)
	var count := session.inventory.take(slot, session.inventory.counts[slot] if whole else 1)
	if count > 0:
		throw_item(session, item, count, worn)
	session.transport.send(Msg.inventory(session.inventory))


## Throws items out in front of a player (`wear`: a tool's).
func throw_item(session: PlayerSession, item: int, count: int, wear := 0) -> void:
	var facing := Vector2(session.facing).normalized()
	var at := body_middle(session) + Vector3(facing.x, 0.4, facing.y) * 0.4
	var speed := Vector3(facing.x * THROW_SPEED.x, THROW_SPEED.y, facing.y * THROW_SPEED.x)
	spawn_item(item, count, at, speed, DroppedItem.THROWN_DELAY).wear = wear


## The middle of a player's body (local units).
static func body_middle(session: PlayerSession) -> Vector3:
	var feet := session.position / GameConst.TILE_SIZE
	return Vector3(feet.x, session.height + PlayerBody.BODY_HEIGHT * 0.5, feet.y)


## Items fall and rest; players nearby pull them in and pick them up; old
## ones vanish. Their moves go out every ITEM_SYNC_TICKS.
func _update_items(delta: float) -> void:
	var sync := tick_count % ITEM_SYNC_TICKS == 0
	for id: int in items.keys():
		var dropped: DroppedItem = items[id]
		if not world.has_chunk(
			Coords.tile_to_chunk(Vector2i(floori(dropped.position.x), floori(dropped.position.z)))
		):
			continue
		var moved := false
		var picker := _picker_for(dropped)
		if picker != null:
			var target := body_middle(picker)
			dropped.position = dropped.position.move_toward(target, ATTRACT_SPEED * delta)
			dropped.resting = false
			moved = true
			if dropped.position.distance_to(target) <= COLLECT_RANGE:
				_collect(picker, dropped)
				continue
		else:
			moved = dropped.step(delta, world.voxel_at)
		if dropped.is_expired():
			items.erase(id)
			_broadcast(Msg.item_remove(id, 0))
		elif moved and sync:
			_broadcast(Msg.item_move(dropped))


## The player pulling an item in: the nearest one within reach with room
## for it (null if none).
func _picker_for(dropped: DroppedItem) -> PlayerSession:
	if dropped.pickup_delay > 0.0:
		return null
	var best: PlayerSession = null
	var best_distance := PICKUP_RANGE
	for session in _sessions:
		if (
			not session.joined
			or not session.alive()
			or session.inventory.room_for(dropped.item) <= 0
		):
			continue
		var feet := session.position / GameConst.TILE_SIZE
		var height := clampf(
			dropped.position.y,
			session.height - PICKUP_BELOW,
			session.height + PlayerBody.BODY_HEIGHT
		)
		var distance := dropped.position.distance_to(Vector3(feet.x, height, feet.y))
		if distance <= best_distance:
			best = session
			best_distance = distance
	return best


func _collect(session: PlayerSession, dropped: DroppedItem) -> void:
	var left := session.inventory.add(dropped.item, dropped.count, dropped.wear)
	if left > 0:
		dropped.count = left
		dropped.pickup_delay = DroppedItem.THROWN_DELAY
		_broadcast(Msg.item_spawn(dropped))
	else:
		items.erase(dropped.id)
		_broadcast(Msg.item_remove(dropped.id, session.id))
	session.transport.send(Msg.inventory(session.inventory))


## Sets a voxel and tells every player who has its chunk.
func change_voxel(cell: Vector3i, voxel: int) -> void:
	world.set_voxel(cell, voxel)
	var coord := Coords.tile_to_chunk(Vector2i(cell.x, cell.z))
	for session in _sessions:
		if session.joined and session.sent_chunks.has(coord):
			session.transport.send(Msg.block_changed(cell, voxel))


## Whether a cell touches the terrain (a block is placed against another).
func _against_terrain(cell: Vector3i) -> bool:
	for side: Vector3i in [
		Vector3i.UP, Vector3i.DOWN, Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK
	]:
		if Voxels.is_cube(world.voxel_at(cell + side)):
			return true
	return false


## The client's view grew or shrank (zoom, window, camera): stream more
## chunks, or drop the far ones.
func _on_set_view_distance(session: PlayerSession, message: Dictionary) -> void:
	if not session.joined:
		return
	session.view_distance = _clamp_view_distance(message.get("distance", session.view_distance))
	_stream_chunks(session, CHUNKS_SENT_PER_TICK)


static func _clamp_view_distance(value: Variant) -> int:
	return clampi(int(value), GameConst.MIN_VIEW_DISTANCE, GameConst.MAX_VIEW_DISTANCE)


func _on_player_move(session: PlayerSession, message: Dictionary) -> void:
	if not session.joined or not session.alive():
		return
	var new_pos: Vector2 = message.get("pos", session.position)
	if new_pos.distance_to(session.position) > MAX_MOVE_PER_UPDATE:
		session.transport.send(Msg.player_correction(session.position, session.height))
		return
	var walked := new_pos.distance_to(session.position) / GameConst.TILE_SIZE
	Survival.spend(self, session, walked * Vitals.WALK_EFFORT)
	session.position = new_pos
	session.facing = message.get("facing", session.facing)
	session.height = message.get("h", session.height)
	var fell := float(message.get("fell", 0.0))
	if fell > 0.0:
		Survival.landed(self, session, fell)


## A player loses vitality (see Survival.hurt).
func hurt(session: PlayerSession, points: int, cause: int) -> void:
	Survival.hurt(self, session, points, cause)


func _on_set_time(message: Dictionary) -> void:
	var value: float = message.get("value", WorldClock.DEFAULT_DAY_MINUTES)
	match int(message.get("mode", WorldClock.Mode.NORMAL)):
		WorldClock.Mode.NORMAL:
			clock.set_normal(value)
		WorldClock.Mode.SYNCED:
			clock.set_synced()
		WorldClock.Mode.FROZEN:
			clock.set_frozen(value)
	_broadcast(Msg.time_state(clock))


## Debug: jump down to the next cave (or back up towards the surface),
## in the player's column or the closest one that has such a place.
func _on_debug_move_depth(session: PlayerSession, message: Dictionary) -> void:
	if not allow_debug_commands or not session.joined:
		return
	var direction := signi(int(message.get("direction", 0)))
	if direction == 0:
		return
	var tile := Coords.world_to_tile(session.position)
	var found := world.find_floor(tile, session.height, direction)
	if found.is_empty():
		return
	session.position = Coords.tile_to_world_center(found[0]) + Vector2(0, 4)
	session.height = found[1]
	session.transport.send(Msg.player_teleport(session.position, session.height))
	_stream_chunks(session, CHUNKS_SENT_PER_TICK)


## Debug: a player gets the tools of a tier (what does not fit is thrown
## at their feet).
func _on_debug_give_tools(session: PlayerSession, message: Dictionary) -> void:
	if not allow_debug_commands or not session.joined:
		return
	var tier := clampi(int(message.get("tier", 0)), 0, Items.Tier.size() - 1)
	for item in Items.tools_of_tier(tier):
		if session.inventory.add(item, 1) > 0:
			throw_item(session, item, 1)
	session.transport.send(Msg.inventory(session.inventory))


func _on_debug_set_weather(session: PlayerSession, message: Dictionary) -> void:
	if not allow_debug_commands or not session.joined:
		return
	var kind := clampi(int(message.get("kind", 0)), 0, Weather.Kind.size() - 1)
	weather.set_kind(kind as Weather.Kind, clock)
	_broadcast(Msg.weather_state(weather))


func _on_map_request(session: PlayerSession, message: Dictionary) -> void:
	if not allow_debug_commands or not session.joined:
		return
	var job := MapJob.new()
	job.session = session
	job.center = message.get("center", Vector2i.ZERO)
	var row := int(message.get("row", Msg.MAP_SURFACE))
	job.row = clampi(row, Msg.MAP_SURFACE, GameConst.WORLD_HEIGHT - 1)
	job.size = clampi(int(message.get("size", 256)), MAP_MIN_SIZE, MAP_MAX_SIZE)
	job.scale = clampi(int(message.get("scale", 1)), 1, MAP_MAX_SCALE)
	if generation.threaded:
		job.task = WorkerThreadPool.add_task(_render_map.bind(job), false, "World map")
		_map_jobs.append(job)
	else:
		_render_map(job)
		_map_jobs.append(job)
		_send_finished_maps()


func _render_map(job: MapJob) -> void:
	var image := WorldMapRenderer.render(world.generator, job.row, job.center, job.size, job.scale)
	job.png = image.save_png_to_buffer()


func _send_finished_maps() -> void:
	for job in _map_jobs.duplicate():
		if job.task >= 0:
			if not WorkerThreadPool.is_task_completed(job.task):
				continue
			WorkerThreadPool.wait_for_task_completion(job.task)
		_map_jobs.erase(job)
		job.session.transport.send(Msg.map_data(job.png, job.center, job.row, job.scale))


func _collect_generated() -> void:
	for chunk in generation.collect():
		world.store(chunk)


func _stream_chunks(session: PlayerSession, budget: int) -> void:
	var center := Coords.world_to_chunk(session.position)
	var radius := session.view_distance
	for coord: Vector2i in session.sent_chunks.keys():
		if Coords.chunk_distance(coord, center) > radius + 1:
			session.sent_chunks.erase(coord)
			session.transport.send(Msg.chunk_unload(coord))
	var missing: Array[Vector2i] = []
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var coord := center + Vector2i(dx, dy)
			if not session.sent_chunks.has(coord):
				missing.append(coord)
	if missing.is_empty():
		return
	missing.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			return (a - center).length_squared() < (b - center).length_squared()
	)
	var sent := 0
	for coord in missing:
		if world.has_chunk(coord) or world.load_saved(coord):
			if sent >= budget:
				continue
			session.sent_chunks[coord] = true
			session.transport.send(Msg.chunk_data(world.chunks[coord]))
			sent += 1
		elif not generation.request(coord):
			break


func _unload_unused_chunks() -> void:
	# Keep every chunk in (or just around) a player's view, sent or not yet.
	var needed := {}
	for session in _sessions:
		var center := Coords.world_to_chunk(session.position)
		var radius := session.view_distance + 1
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				needed[center + Vector2i(dx, dy)] = true
	world.unload_unused(needed)


func _broadcast(message: Dictionary) -> void:
	for session in _sessions:
		if session.joined:
			session.transport.send(message)
