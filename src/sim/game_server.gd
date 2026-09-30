class_name GameServer
extends RefCounted
## Authoritative simulation of one world.
##
## In solo play it runs in the same process as the client ("integrated
## server", like Minecraft) and talks to it through a LocalTransport. Later,
## the very same class will run on a host or dedicated server and talk to
## remote clients through a network transport.

const CHUNKS_SENT_PER_TICK := 12
const TIME_BROADCAST_TICKS := GameConst.TICKS_PER_SECOND * 5
const UNLOAD_CHECK_TICKS := GameConst.TICKS_PER_SECOND * 2
## Max distance (world px) a player may move between two updates before
## the server corrects them. Generous: real validation comes with Phase 3.
const MAX_MOVE_PER_UPDATE := 96.0
const MIN_VIEW_DISTANCE := 2
const MAX_VIEW_DISTANCE := 16


class PlayerSession:
	extends RefCounted
	var id := 0
	var transport: Transport
	var player_name := ""
	var joined := false
	var position := Vector2.ZERO
	var facing := Vector2i.DOWN
	var view_distance := GameConst.DEFAULT_VIEW_DISTANCE
	var sent_chunks: Dictionary[Vector2i, bool] = {}


var settings: WorldSettings
var clock: WorldClock
var world: WorldState
var spawn_tile := Vector2i.ZERO
var tick_count := 0

var _sessions: Array[PlayerSession] = []
var _next_player_id := 1


func _init(world_settings: WorldSettings, world_clock: WorldClock = null) -> void:
	settings = world_settings
	clock = world_clock if world_clock != null else WorldClock.new()
	world = WorldState.new(TerrainGenerator.new(settings.world_seed))
	spawn_tile = world.generator.find_spawn_tile()
	clock.sync_to_device()


func connect_client(transport: Transport) -> void:
	var session := PlayerSession.new()
	session.transport = transport
	_sessions.append(session)


func player_count() -> int:
	return _sessions.size()


## Handles every pending client message. Runs even while the simulation is
## paused so that menus (e.g. time settings) keep working.
func process_messages() -> void:
	for session in _sessions:
		for message in session.transport.poll():
			_handle_message(session, message)


## Advances the simulation by one fixed step (1/20 s).
func tick() -> void:
	tick_count += 1
	clock.advance(GameConst.TICK_DELTA)
	clock.sync_to_device()
	for session in _sessions:
		if session.joined:
			_stream_chunks(session, CHUNKS_SENT_PER_TICK)
	if tick_count % TIME_BROADCAST_TICKS == 0:
		_broadcast(Msg.time_state(clock))
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
		var unknown:
			push_warning("Server: unknown message type %s" % unknown)


func _on_hello(session: PlayerSession, message: Dictionary) -> void:
	if session.joined:
		return
	session.id = _next_player_id
	_next_player_id += 1
	session.player_name = str(message.get("name", "Player"))
	session.view_distance = clampi(
		int(message.get("view_distance", GameConst.DEFAULT_VIEW_DISTANCE)),
		MIN_VIEW_DISTANCE,
		MAX_VIEW_DISTANCE
	)
	session.position = Coords.tile_to_world_center(spawn_tile) + Vector2(0, 4)
	session.joined = true
	session.transport.send(Msg.welcome(session.id, session.position, settings.to_dict()))
	session.transport.send(Msg.time_state(clock))
	# Send the whole initial view at once, like Minecraft's "loading terrain".
	_stream_chunks(session, 1 << 30)


func _on_player_move(session: PlayerSession, message: Dictionary) -> void:
	if not session.joined:
		return
	var new_pos: Vector2 = message.get("pos", session.position)
	if new_pos.distance_to(session.position) > MAX_MOVE_PER_UPDATE:
		session.transport.send(Msg.player_correction(session.position))
		return
	session.position = new_pos
	session.facing = message.get("facing", session.facing)


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
	for i in mini(budget, missing.size()):
		var coord := missing[i]
		session.sent_chunks[coord] = true
		session.transport.send(Msg.chunk_data(world.get_or_create_chunk(coord)))


func _unload_unused_chunks() -> void:
	var needed := {}
	for session in _sessions:
		needed.merge(session.sent_chunks)
	world.unload_unused(needed)


func _broadcast(message: Dictionary) -> void:
	for session in _sessions:
		if session.joined:
			session.transport.send(message)
