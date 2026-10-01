class_name Msg
extends RefCounted
## Message types exchanged between the game server and its clients.
## Messages are plain Dictionaries: {"t": TYPE, ...fields} so they can be
## passed by reference locally or serialized with var_to_bytes() later.

# Client -> server
const HELLO := "hello"
const PLAYER_MOVE := "player_move"
const SET_TIME := "set_time"
const DEBUG_MOVE_DEPTH := "debug_move_depth"
const MAP_REQUEST := "map_request"
const DEBUG_SET_WEATHER := "debug_set_weather"
const SET_VIEW_DISTANCE := "set_view_distance"

## map_request() row for a map of the surface.
const MAP_SURFACE := -1

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


## Debug/creative: go to the next place to stand below (-1) or above (+1).
static func debug_move_depth(direction: int) -> Dictionary:
	return {"t": DEBUG_MOVE_DEPTH, "direction": direction}


## Asks for a map image centered on a tile (debug map): the surface, or a
## horizontal cut through the voxels at `row` (MAP_SURFACE: the surface).
static func map_request(center: Vector2i, row: int, size_px: int, scale: int) -> Dictionary:
	return {"t": MAP_REQUEST, "center": center, "row": row, "size": size_px, "scale": scale}


## Debug/creative: force a weather (Weather.Kind).
## Radius in chunks the client needs around the player.
static func set_view_distance(distance: int) -> Dictionary:
	return {"t": SET_VIEW_DISTANCE, "distance": distance}


static func debug_set_weather(kind: int) -> Dictionary:
	return {"t": DEBUG_SET_WEATHER, "kind": kind}


static func weather_state(weather: Weather) -> Dictionary:
	return {"t": WEATHER_STATE, "weather": weather.to_dict()}


## `height` is the feet height in levels.
static func welcome(player_id: int, spawn: Vector2, height: float, world: Dictionary) -> Dictionary:
	return {"t": WELCOME, "player_id": player_id, "spawn": spawn, "h": height, "world": world}


## Sends a snapshot: the client must never share memory with the server.
static func chunk_data(chunk: ChunkData) -> Dictionary:
	return {"t": CHUNK_DATA, "chunk": chunk.duplicate_chunk().to_dict()}


static func chunk_unload(coord: Vector2i) -> Dictionary:
	return {"t": CHUNK_UNLOAD, "coord": coord}


static func time_state(clock: WorldClock) -> Dictionary:
	return {"t": TIME_STATE, "clock": clock.to_dict()}


static func player_correction(position: Vector2, height: float) -> Dictionary:
	return {"t": PLAYER_CORRECTION, "pos": position, "h": height}


static func player_teleport(position: Vector2, height: float) -> Dictionary:
	return {"t": PLAYER_TELEPORT, "pos": position, "h": height}


## `png` is a PNG-encoded image.
static func map_data(png: PackedByteArray, center: Vector2i, row: int, scale: int) -> Dictionary:
	return {"t": MAP_DATA, "png": png, "center": center, "row": row, "scale": scale}
