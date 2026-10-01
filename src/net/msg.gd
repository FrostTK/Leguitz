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
const SAVE_REQUEST := "save_request"
const BLOCK_BREAK := "block_break"
const BLOCK_PLACE := "block_place"
const SELECT_SLOT := "select_slot"
const SLOT_CLICK := "slot_click"
const SLOT_SPREAD := "slot_spread"
const RESPAWN := "respawn"
const ITEM_DROP := "item_drop"
const INVENTORY_CLOSE := "inventory_close"
const DEBUG_GIVE_TOOLS := "debug_give_tools"
const CRAFT := "craft"
const OPEN_WORKBENCH := "open_workbench"
const OPEN_CHEST := "open_chest"
const CHEST_CLICK := "chest_click"
const OPEN_FURNACE := "open_furnace"
const FURNACE_CLICK := "furnace_click"

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
const WORLD_SAVED := "world_saved"
const BLOCK_CHANGED := "block_changed"
const INVENTORY := "inventory"
const ITEM_SPAWN := "item_spawn"
const ITEM_MOVE := "item_move"
const ITEM_REMOVE := "item_remove"
const CHEST := "chest"
const HEALTH := "health"
const DIED := "died"
const FURNACE := "furnace"


## The player broke the voxel at `cell` (tile x, row, tile y) with the
## hotbar slot `slot` in hand (-1: nothing of it, the player's book).
static func block_break(cell: Vector3i, slot := -1) -> Dictionary:
	return {"t": BLOCK_BREAK, "cell": cell, "slot": slot}


## The player placed the block of hotbar slot `slot` at `cell` (a
## workbench facing `front`, see Mining.placement).
static func block_place(cell: Vector3i, slot: int, front := Vector2i(0, 1)) -> Dictionary:
	return {"t": BLOCK_PLACE, "cell": cell, "slot": slot, "front": front}


## The player took hotbar slot `slot` in hand.
static func select_slot(slot: int) -> Dictionary:
	return {"t": SELECT_SLOT, "slot": slot}


## A click on an inventory slot (see Inventory.click).
static func slot_click(slot: int, right: bool, shift: bool) -> Dictionary:
	return {"t": SLOT_CLICK, "slot": slot, "right": right, "shift": shift}


## The player shared the cursor's stack between slots with a left drag
## (Inventory.spread; `targets`: Vector2i(Inventory.Holder, index)).
static func slot_spread(targets: Array) -> Dictionary:
	return {"t": SLOT_SPREAD, "targets": targets}


## The player throws one item of a slot (Inventory.CURSOR: what the cursor
## holds), or the whole stack.
static func item_drop(slot: int, whole: bool) -> Dictionary:
	return {"t": ITEM_DROP, "slot": slot, "whole": whole}


## The inventory screen closed: the cursor's stack and the crafting grid
## go back.
static func inventory_close() -> Dictionary:
	return {"t": INVENTORY_CLOSE}


## The player opened the workbench standing in `cell`: their crafting
## grid is its 5 x 5 one until the screen closes.
static func open_workbench(cell: Vector3i) -> Dictionary:
	return {"t": OPEN_WORKBENCH, "cell": cell}


## The player opened the chest standing in `cell` (until the screen
## closes, Msg.inventory_close).
static func open_chest(cell: Vector3i) -> Dictionary:
	return {"t": OPEN_CHEST, "cell": cell}


## A click on a slot of the chest the player opened (Inventory.click_chest).
static func chest_click(slot: int, right: bool, shift: bool) -> Dictionary:
	return {"t": CHEST_CLICK, "slot": slot, "right": right, "shift": shift}


## What a chest a player opened holds (Inventory.contents).
static func chest(cell: Vector3i, chest_items: Inventory) -> Dictionary:
	return {"t": CHEST, "cell": cell, "chest": chest_items.contents(Inventory.CHEST)}


## The player opened the furnace standing in `cell` (until the screen
## closes, Msg.inventory_close).
static func open_furnace(cell: Vector3i) -> Dictionary:
	return {"t": OPEN_FURNACE, "cell": cell}


## A click on a slot of the furnace the player opened
## (Inventory.click_furnace).
static func furnace_click(slot: int, right: bool, shift: bool) -> Dictionary:
	return {"t": FURNACE_CLICK, "slot": slot, "right": right, "shift": shift}


## A furnace a player opened: its slots, fire and progress
## (Furnace.to_dict).
static func furnace(cell: Vector3i, state: Furnace) -> Dictionary:
	return {"t": FURNACE, "cell": cell, "furnace": state.to_dict()}


## The player takes what their crafting grid makes (shift: as many as
## possible, into the slots).
static func craft(shift: bool) -> Dictionary:
	return {"t": CRAFT, "shift": shift}


## A player's whole inventory (see Inventory.to_dict).
static func inventory(items: Inventory) -> Dictionary:
	return {"t": INVENTORY, "inventory": items.to_dict()}


## An item lies in the world (new, or its count changed).
static func item_spawn(dropped: DroppedItem) -> Dictionary:
	return {
		"t": ITEM_SPAWN,
		"id": dropped.id,
		"item": dropped.item,
		"count": dropped.count,
		"pos": dropped.position,
	}


static func item_move(dropped: DroppedItem) -> Dictionary:
	return {"t": ITEM_MOVE, "id": dropped.id, "pos": dropped.position}


## An item is gone: picked up by player `by` (0: it vanished).
static func item_remove(id: int, by: int) -> Dictionary:
	return {"t": ITEM_REMOVE, "id": id, "by": by}


## A voxel is now `voxel` (also the answer to a refused break or place:
## what is really there).
static func block_changed(cell: Vector3i, voxel: int) -> Dictionary:
	return {"t": BLOCK_CHANGED, "cell": cell, "voxel": voxel}


## The player paused: a good time to save the world.
static func save_request() -> Dictionary:
	return {"t": SAVE_REQUEST}


static func hello(player_name: String, view_distance: int) -> Dictionary:
	return {"t": HELLO, "name": player_name, "view_distance": view_distance}


## `height` is the feet height in levels (jumps, falls).
## Where the player is; `fell`: how far they fell (levels) when they landed
## since the last move (PlayerBody.take_fall; 0: no landing).
static func player_move(
	position: Vector2, facing: Vector2i, height := 0.0, fell := 0.0
) -> Dictionary:
	var message := {"t": PLAYER_MOVE, "pos": position, "facing": facing, "h": height}
	if fell > 0.0:
		message["fell"] = fell
	return message


## The player who passed out gets up again (at the spawn).
static func respawn() -> Dictionary:
	return {"t": RESPAWN}


## A player's vitality (Vitals): `hurt` when it just went down, and what
## hurt them (Vitals.Cause).
static func health(points: int, hurt := false, cause := Vitals.Cause.NONE) -> Dictionary:
	return {"t": HEALTH, "health": points, "hurt": hurt, "cause": cause}


## The player passed out (their vitality ran out), from `cause`
## (Vitals.Cause); what they carried lies where they fell.
static func died(cause: int) -> Dictionary:
	return {"t": DIED, "cause": cause}


## `mode` is a WorldClock.Mode; `value` is day minutes (NORMAL) or the
## frozen time of day in game seconds (FROZEN); unused for SYNCED.
static func set_time(mode: int, value: float) -> Dictionary:
	return {"t": SET_TIME, "mode": mode, "value": value}


## Debug: the pickaxe, axe and shovel of a tier (Items.Tier), until tools
## can be crafted.
static func debug_give_tools(tier: int) -> Dictionary:
	return {"t": DEBUG_GIVE_TOOLS, "tier": tier}


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


## The world was just saved (the client shows it).
static func world_saved() -> Dictionary:
	return {"t": WORLD_SAVED}


static func time_state(clock: WorldClock) -> Dictionary:
	return {"t": TIME_STATE, "clock": clock.to_dict()}


static func player_correction(position: Vector2, height: float) -> Dictionary:
	return {"t": PLAYER_CORRECTION, "pos": position, "h": height}


static func player_teleport(position: Vector2, height: float) -> Dictionary:
	return {"t": PLAYER_TELEPORT, "pos": position, "h": height}


## `png` is a PNG-encoded image.
static func map_data(png: PackedByteArray, center: Vector2i, row: int, scale: int) -> Dictionary:
	return {"t": MAP_DATA, "png": png, "center": center, "row": row, "scale": scale}
