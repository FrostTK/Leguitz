class_name Msg
extends RefCounted
## Message types exchanged between the game server and its clients.
## Messages are plain Dictionaries: {"t": TYPE, ...fields} so they can be
## passed by reference locally or serialized with var_to_bytes() later.

# Client -> server
const HELLO := "hello"
const PLAYER_MOVE := "player_move"
const SET_TIME := "set_time"
const DEBUG_CHANGE_LAYER := "debug_change_layer"
const MAP_REQUEST := "map_request"
const DEBUG_SET_WEATHER := "debug_set_weather"
const SET_VIEW_DISTANCE := "set_view_distance"

# Server -> client
const WELCOME := "welcome"
const CHUNK_DATA := "chunk_data"
const CHUNK_UNLOAD := "chunk_unload"
const TIME_STATE := "time_state"
const PLAYER_CORRECTION := "player_correction"
const PLAYER_TELEPORT := "player_teleport"
const MAP_DATA := "map_data"
const WEATHER_STATE := "weather_state"


static func hello(player_name: String, view_distance: int) -> Dictionary:
	return {"t": HELLO, "name": player_name, "view_distance": view_distance}


## `height` is the feet height in levels (jumps, falls).
static func player_move(position: Vector2, facing: Vector2i, height := 0.0) -> Dictionary:
	return {"t": PLAYER_MOVE, "pos": position, "facing": facing, "h": height}


## `mode` is a WorldClock.Mode; `value` is day minutes (NORMAL) or the
## frozen time of day in game seconds (FROZEN); unused for SYNCED.
static func set_time(mode: int, value: float) -> Dictionary:
	return {"t": SET_TIME, "mode": mode, "value": value}


## Debug/creative: move up (+1) or down (-1) one layer.
static func debug_change_layer(delta: int) -> Dictionary:
	return {"t": DEBUG_CHANGE_LAYER, "delta": delta}


## Asks for a map image centered on a tile (debug map).
static func map_request(center: Vector2i, layer: int, size_px: int, scale: int) -> Dictionary:
	return {"t": MAP_REQUEST, "center": center, "layer": layer, "size": size_px, "scale": scale}


## Debug/creative: force a weather (Weather.Kind).
## Radius in chunks the client needs around the player.
static func set_view_distance(distance: int) -> Dictionary:
	return {"t": SET_VIEW_DISTANCE, "distance": distance}


static func debug_set_weather(kind: int) -> Dictionary:
	return {"t": DEBUG_SET_WEATHER, "kind": kind}


static func weather_state(weather: Weather) -> Dictionary:
	return {"t": WEATHER_STATE, "weather": weather.to_dict()}


static func welcome(player_id: int, spawn: Vector2, layer: int, world: Dictionary) -> Dictionary:
	return {"t": WELCOME, "player_id": player_id, "spawn": spawn, "layer": layer, "world": world}


## Sends a snapshot: the client must never share memory with the server.
static func chunk_data(chunk: ChunkData) -> Dictionary:
	return {"t": CHUNK_DATA, "chunk": chunk.duplicate_chunk().to_dict()}


static func chunk_unload(key: Vector3i) -> Dictionary:
	return {"t": CHUNK_UNLOAD, "key": key}


static func time_state(clock: WorldClock) -> Dictionary:
	return {"t": TIME_STATE, "clock": clock.to_dict()}


static func player_correction(position: Vector2) -> Dictionary:
	return {"t": PLAYER_CORRECTION, "pos": position}


static func player_teleport(position: Vector2, layer: int) -> Dictionary:
	return {"t": PLAYER_TELEPORT, "pos": position, "layer": layer}


## `png` is a PNG-encoded image.
static func map_data(png: PackedByteArray, center: Vector2i, layer: int, scale: int) -> Dictionary:
	return {"t": MAP_DATA, "png": png, "center": center, "layer": layer, "scale": scale}
