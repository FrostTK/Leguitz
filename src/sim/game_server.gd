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
## Max distance (world px) a player may move between two updates before
## the server corrects them. Generous: real validation comes with Phase 3.
const MAX_MOVE_PER_UPDATE := 96.0
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
var tick_count := 0
## Debug commands (moving between caves, world map). Restricted to
## creative mode and server operators once those exist.
var allow_debug_commands := true

var _sessions: Array[PlayerSession] = []
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
	if tick_count % UNLOAD_CHECK_TICKS == 0:
		_unload_unused_chunks()


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
		Msg.SET_VIEW_DISTANCE:
			_on_set_view_distance(session, message)
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
	session.position = Coords.tile_to_world_center(spawn_tile) + Vector2(0, 4)
	session.height = world.surface_height(spawn_tile)
	session.joined = true
	session.transport.send(
		Msg.welcome(session.id, session.position, session.height, settings.to_dict())
	)
	session.transport.send(Msg.time_state(clock))
	session.transport.send(Msg.weather_state(weather))
	# Start generating the whole initial view right away.
	_stream_chunks(session, CHUNKS_SENT_PER_TICK)
	_collect_generated()
	_stream_chunks(session, CHUNKS_SENT_PER_TICK)


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
	if not session.joined:
		return
	var new_pos: Vector2 = message.get("pos", session.position)
	if new_pos.distance_to(session.position) > MAX_MOVE_PER_UPDATE:
		session.transport.send(Msg.player_correction(session.position, session.height))
		return
	session.position = new_pos
	session.facing = message.get("facing", session.facing)
	session.height = message.get("h", session.height)


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
		if world.has_chunk(coord):
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
