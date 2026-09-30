class_name Msg
extends RefCounted
## Message types exchanged between the game server and its clients.
## Messages are plain Dictionaries: {"t": TYPE, ...fields} so they can be
## passed by reference locally or serialized with var_to_bytes() later.

# Client -> server
const HELLO := "hello"
const PLAYER_MOVE := "player_move"
const SET_TIME := "set_time"

# Server -> client
const WELCOME := "welcome"
const CHUNK_DATA := "chunk_data"
const CHUNK_UNLOAD := "chunk_unload"
const TIME_STATE := "time_state"
const PLAYER_CORRECTION := "player_correction"


static func hello(player_name: String, view_distance: int) -> Dictionary:
	return {"t": HELLO, "name": player_name, "view_distance": view_distance}


static func player_move(position: Vector2, facing: Vector2i) -> Dictionary:
	return {"t": PLAYER_MOVE, "pos": position, "facing": facing}


## `mode` is a WorldClock.Mode; `value` is day minutes (NORMAL) or the
## frozen time of day in game seconds (FROZEN); unused for SYNCED.
static func set_time(mode: int, value: float) -> Dictionary:
	return {"t": SET_TIME, "mode": mode, "value": value}


static func welcome(player_id: int, spawn: Vector2, world: Dictionary) -> Dictionary:
	return {"t": WELCOME, "player_id": player_id, "spawn": spawn, "world": world}


## Sends a snapshot: the client must never share memory with the server.
static func chunk_data(chunk: ChunkData) -> Dictionary:
	return {"t": CHUNK_DATA, "chunk": chunk.duplicate_chunk().to_dict()}


static func chunk_unload(coord: Vector2i) -> Dictionary:
	return {"t": CHUNK_UNLOAD, "coord": coord}


static func time_state(clock: WorldClock) -> Dictionary:
	return {"t": TIME_STATE, "clock": clock.to_dict()}


static func player_correction(position: Vector2) -> Dictionary:
	return {"t": PLAYER_CORRECTION, "pos": position}
