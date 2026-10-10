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
const TILL := "till"
const FILL_CAN := "fill_can"
const WATER := "water"
const COMPOST := "compost"
const SPREAD_COMPOST := "spread_compost"
const PICK := "pick"
const TEND_ANIMAL := "tend_animal"
const HARVEST_HIVE := "harvest_hive"
const USE_MACHINE := "use_machine"
const CHAT := "chat"
const PICK_BLOCK := "pick_block"
const SELECT_SLOT := "select_slot"
const SLOT_CLICK := "slot_click"
const SLOT_SPREAD := "slot_spread"
const SLOT_COLLECT := "slot_collect"
const RESPAWN := "respawn"
const EAT := "eat"
const ITEM_DROP := "item_drop"
const INVENTORY_CLOSE := "inventory_close"
const DEBUG_GIVE_TOOLS := "debug_give_tools"
const CRAFT := "craft"
const OPEN_WORKBENCH := "open_workbench"
const OPEN_CHEST := "open_chest"
const CHEST_CLICK := "chest_click"
const OPEN_FURNACE := "open_furnace"
const FURNACE_CLICK := "furnace_click"
const SET_GAME_MODE := "set_game_mode"
const CATALOG_CLICK := "catalog_click"
const ATTACK := "attack"
const SHOOT := "shoot"
const CAST := "cast"
const REEL := "reel"
const OPEN_YARD := "open_yard"
const OPEN_BOAT := "open_boat"
const BOAT_CLICK := "boat_click"
const BOAT_ACT := "boat_act"
const BOARD := "board"
const LEAVE_BOAT := "leave_boat"
const BOAT_STEER := "boat_steer"
const BOAT_HIT := "boat_hit"
const NET := "net"
const BOAT_PAINT := "boat_paint"

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
const VITALS := "vitals"
const DIED := "died"
const FURNACE := "furnace"
const GAME_MODE := "game_mode"
const ENTITY_SPAWN := "entity_spawn"
const ENTITY_MOVE := "entity_move"
const ENTITY_HURT := "entity_hurt"
const ENTITY_REMOVE := "entity_remove"
const ANIMAL_NOTICE := "animal_notice"
const CHAT_LINE := "chat_line"
const PUSH := "push"
const LANTERN_OUT := "lantern_out"
const ARROW_SPAWN := "arrow_spawn"
const ARROW_REMOVE := "arrow_remove"
const SWING_GATE := "swing_gate"
const BOBBER := "bobber"
const CAUGHT := "caught"
const BOAT := "boat"
const BOAT_MOVE := "boat_move"
const BOAT_REMOVE := "boat_remove"
const BOAT_HURT := "boat_hurt"
const NOTICE := "notice"
const BOAT_SCREEN := "boat_screen"


## The player hits the creature `id` with the hotbar slot `slot` in hand
## (-1: nothing of it, the player's book).
static func attack(id: int, slot := -1) -> Dictionary:
	return {"t": ATTACK, "id": id, "slot": slot}


## The player shoots an arrow with the bow of hotbar slot `slot` along
## `direction` (local units), the bow drawn `power` (0..1, see Archery).
static func shoot(slot: int, direction: Vector3, power: float) -> Dictionary:
	return {"t": SHOOT, "slot": slot, "direction": direction, "power": power}


## An arrow leaves `from` at `velocity` (local units; see Archery.fly).
static func arrow_spawn(id: int, from: Vector3, velocity: Vector3) -> Dictionary:
	return {"t": ARROW_SPAWN, "id": id, "from": from, "velocity": velocity}


## An arrow stopped (in a creature, or a block).
static func arrow_remove(id: int) -> Dictionary:
	return {"t": ARROW_REMOVE, "id": id}


## A creature comes into a player's view: its kind (Species), its feet
## (world pixels) and their height (levels), where it looks, what it does
## (Creature.State).
static func entity_spawn(creature: Creature) -> Dictionary:
	var message := entity_move(creature)
	message["t"] = ENTITY_SPAWN
	message["kind"] = creature.species
	message["look"] = creature.look()
	return message


## A creature moved, turned or does something else.
static func entity_move(creature: Creature) -> Dictionary:
	return {
		"t": ENTITY_MOVE,
		"id": creature.id,
		"pos": creature.body.feet,
		"h": creature.body.height,
		"heading": creature.heading,
		"state": creature.state,
		"flags": creature.flags(),
		"lead": creature.led_by(),
	}


## A blow pushes the player back: `speed` along the ground (world pixels
## per second, fading), `hop` up (levels per second).
static func push(speed: Vector2, hop: float) -> Dictionary:
	return {"t": PUSH, "speed": speed, "hop": hop}


## The player's lantern goes out for `seconds` (a lantern moth's blow).
static func lantern_out(seconds: float) -> Dictionary:
	return {"t": LANTERN_OUT, "seconds": seconds}


## A creature was hurt.
static func entity_hurt(id: int) -> Dictionary:
	return {"t": ENTITY_HURT, "id": id}


## A creature leaves a player's view, or died.
static func entity_remove(id: int, died: bool) -> Dictionary:
	return {"t": ENTITY_REMOVE, "id": id, "died": died}


## The player asks for another game mode for the world (GameModes.set_mode).
static func set_game_mode(mode: int) -> Dictionary:
	return {"t": SET_GAME_MODE, "mode": mode}


## A click on an item of the creative catalog (GameModes.take_from_catalog).
static func catalog_click(item: int, right: bool, shift: bool) -> Dictionary:
	return {"t": CATALOG_CLICK, "item": item, "right": right, "shift": shift}


## The world's game mode (WorldSettings.GameMode), and whether this player
## only watches it (hardcore: their one life is over).
static func game_mode(mode: int, spectator: bool) -> Dictionary:
	return {"t": GAME_MODE, "mode": mode, "spectator": spectator}


## The player broke the voxel at `cell` (tile x, row, tile y) with the
## hotbar slot `slot` in hand (-1: nothing of it, the player's book).
static func block_break(cell: Vector3i, slot := -1) -> Dictionary:
	return {"t": BLOCK_BREAK, "cell": cell, "slot": slot}


## The player tilled `cell` with the hoe in hotbar slot `slot` (Farming).
static func till(cell: Vector3i, slot: int) -> Dictionary:
	return {"t": TILL, "cell": cell, "slot": slot}


## The player filled the watering can of hotbar slot `slot` at `cell`
## (water, a sink: Watering).
static func fill_can(cell: Vector3i, slot: int) -> Dictionary:
	return {"t": FILL_CAN, "cell": cell, "slot": slot}


## The player watered the farmland at `cell` with the can of hotbar slot
## `slot` (Watering).
static func water(cell: Vector3i, slot: int) -> Dictionary:
	return {"t": WATER, "cell": cell, "slot": slot}


## The player used the composter at `cell` with hotbar slot `slot` in hand
## (Composting.put).
static func compost(cell: Vector3i, slot: int) -> Dictionary:
	return {"t": COMPOST, "cell": cell, "slot": slot}


## The player spread the compost of hotbar slot `slot` on `cell`
## (Composting.spread).
static func spread_compost(cell: Vector3i, slot: int) -> Dictionary:
	return {"t": SPREAD_COMPOST, "cell": cell, "slot": slot}


## The player picked what grows at `cell` (Picking.pick).
static func pick(cell: Vector3i) -> Dictionary:
	return {"t": PICK, "cell": cell}


## The player used the animal `id` with hotbar slot `slot` in hand
## (Husbandry.tend: feeding, petting, shearing, milking, a lead).
static func tend_animal(id: int, slot: int) -> Dictionary:
	return {"t": TEND_ANIMAL, "id": id, "slot": slot}


## A line the player typed in the chat (a command when it starts with
## "/"; Chat.receive).
static func chat(text: String) -> Dictionary:
	return {"t": CHAT, "text": text}


## A player said `text` in the chat (to every player).
static func chat_said(from: String, text: String) -> Dictionary:
	return {"t": CHAT_LINE, "from": from, "text": text}


## The chat tells the player something: a translation key, its args (a
## Dictionary {"key": ...} is a word to translate too) and how it shows
## (Chat.Tone).
static func chat_notice(key: String, args: Array, tone: int) -> Dictionary:
	return {"t": CHAT_LINE, "key": key, "args": args, "tone": tone}


## The player harvested the full hive at `cell` with what is in hotbar
## slot `slot` (Apiary.harvest: a glass bottle, shears).
static func harvest_hive(cell: Vector3i, slot: int) -> Dictionary:
	return {"t": HARVEST_HIVE, "cell": cell, "slot": slot}


## The player opens the shipyard at `cell` (Boats).
static func open_yard(cell: Vector3i) -> Dictionary:
	return {"t": OPEN_YARD, "cell": cell}


## The player opens a boat's screen.
static func open_boat(id: int) -> Dictionary:
	return {"t": OPEN_BOAT, "id": id}


## A click on a slot of the open boat's screen (Boat.click).
static func boat_click(slot: int, right: bool, shift: bool) -> Dictionary:
	return {"t": BOAT_CLICK, "slot": slot, "right": right, "shift": shift}


## A button of the open boat's screen (Boats.Act; `place`: a chest's).
static func boat_act(act: int, place := -1) -> Dictionary:
	return {"t": BOAT_ACT, "act": act, "place": place}


static func board(id: int) -> Dictionary:
	return {"t": BOARD, "id": id}


static func leave_boat() -> Dictionary:
	return {"t": LEAVE_BOAT}


## The pilot's boat is where it went (BoatBody), what they ask of it.
static func boat_steer(boat: Boat) -> Dictionary:
	return {
		"t": BOAT_STEER,
		"at": boat.at,
		"yaw": boat.yaw,
		"speed": boat.speed,
		"throttle": boat.throttle,
		"full": boat.full,
	}


## A player aboard casts their boat's net or hauls it in (Nets).
static func net() -> Dictionary:
	return {"t": NET}


## The player paints a boat with the pot of hotbar slot `slot` (scrapes it
## with an axe): its hull, or its stripe.
static func boat_paint(id: int, slot: int, stripe: bool) -> Dictionary:
	return {"t": BOAT_PAINT, "id": id, "slot": slot, "stripe": stripe}


## The player strikes a boat with the hotbar slot `slot` in hand.
static func boat_hit(id: int, slot: int) -> Dictionary:
	return {"t": BOAT_HIT, "id": id, "slot": slot}


## A boat as it is now: its parts, chests, place, riders (Boat.to_dict).
static func boat(of: Boat) -> Dictionary:
	return {"t": BOAT, "boat": of.to_dict()}


## Where a boat is and how its coal burns; `correct`: its pilot's report
## was refused.
static func boat_move(of: Boat, correct := false) -> Dictionary:
	return {
		"t": BOAT_MOVE,
		"id": of.id,
		"at": of.at,
		"yaw": of.yaw,
		"speed": of.speed,
		"throttle": of.throttle,
		"burn": of.burn,
		"correct": correct,
	}


## A boat is gone (`burnt`: by lava).
static func boat_remove(id: int, burnt: bool) -> Dictionary:
	return {"t": BOAT_REMOVE, "id": id, "burnt": burnt}


static func boat_hurt(id: int) -> Dictionary:
	return {"t": BOAT_HURT, "id": id}


## Something to tell the player (a HUD key).
static func notice(key: String) -> Dictionary:
	return {"t": NOTICE, "key": key}


## The boat screen to show: a shipyard's (`yard`; NO_CELL: a boat's own)
## and the boat it shows (-1: none yet).
static func boat_screen(yard: Vector3i, id: int) -> Dictionary:
	return {"t": BOAT_SCREEN, "yard": yard, "id": id}


## The player casts with the rod of hotbar slot `slot` towards `target`
## (local units; see Fishing).
static func cast(slot: int, target: Vector3) -> Dictionary:
	return {"t": CAST, "slot": slot, "target": target}


## The player reels their line in.
static func reel() -> Dictionary:
	return {"t": REEL}


## A player's bobber (Fishing.State) is at `at` (local units), for `left`
## seconds (its flight, its bite); `missed`: a fish took the bait.
static func bobber(
	player: int, state: int, at: Vector3, left: float, missed := false
) -> Dictionary:
	return {"t": BOBBER, "player": player, "state": state, "at": at, "left": left, "missed": missed}


## The player caught `item`, `size` cm long (0: not a fish); `broke`: their
## rod with it.
static func caught(item: int, size: int, broke: bool) -> Dictionary:
	return {"t": CAUGHT, "item": item, "size": size, "broke": broke}


## The player used a kitchen machine (Machines) with hotbar slot `slot` in
## hand.
static func use_machine(cell: Vector3i, slot: int) -> Dictionary:
	return {"t": USE_MACHINE, "cell": cell, "slot": slot}


## Something to tell the player about an animal of `kind`: a HUD key
## taking the species' name and `value` (Husbandry).
static func animal_notice(key: String, kind: int, value: int) -> Dictionary:
	return {"t": ANIMAL_NOTICE, "key": key, "kind": kind, "value": value}


## The player placed the block of hotbar slot `slot` at `cell` (a
## workbench facing `front`, see Mining.placement).
## `front`: the way an object placed faces; `face`: the side of the cube
## aimed at (UP: its top; see Mining.placement).
static func block_place(
	cell: Vector3i, slot: int, front := Vector2i(0, 1), face := Vector3i.UP
) -> Dictionary:
	return {"t": BLOCK_PLACE, "cell": cell, "slot": slot, "front": front, "face": face}


## The player swings the gate in `cell` open or shut.
static func swing_gate(cell: Vector3i) -> Dictionary:
	return {"t": SWING_GATE, "cell": cell}


## The player took hotbar slot `slot` in hand.
static func select_slot(slot: int) -> Dictionary:
	return {"t": SELECT_SLOT, "slot": slot}


## The player picked `item` with the middle click (PickBlock).
static func pick_block(item: int) -> Dictionary:
	return {"t": PICK_BLOCK, "item": item}


## A click on an inventory slot (see Inventory.click).
static func slot_click(slot: int, right: bool, shift: bool) -> Dictionary:
	return {"t": SLOT_CLICK, "slot": slot, "right": right, "shift": shift}


## The player shared the cursor's stack between slots with a left drag
## (Inventory.spread; `targets`: Vector2i(Inventory.Holder, index)).
static func slot_spread(targets: Array) -> Dictionary:
	return {"t": SLOT_SPREAD, "targets": targets}


## The player double-clicked: the same items as the cursor's gather on it
## (Inventory.collect).
static func slot_collect() -> Dictionary:
	return {"t": SLOT_COLLECT}


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


## A player's vitality, satiety and air (Vitals): `hurt` when vitality
## just went down, and what hurt them (Vitals.Cause).
static func vitals(
	health: int,
	food: int,
	hurt := false,
	cause := Vitals.Cause.NONE,
	air := Vitals.MAX_AIR,
	effects := {}
) -> Dictionary:
	return {
		"t": VITALS,
		"health": health,
		"food": food,
		"hurt": hurt,
		"cause": cause,
		"air": air,
		"effects": Effects.to_dict(effects),
	}


## The player ate one of what hotbar slot `slot` holds (after holding the
## right button for Vitals.EAT_SECONDS).
static func eat(slot: int) -> Dictionary:
	return {"t": EAT, "slot": slot}


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
