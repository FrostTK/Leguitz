class_name Tints
extends RefCounted
## Colors given with a pot of paint (static, given the server; shared): the
## palette (COLORS, by Items.PAINTS: 16 soft colors of our own, the boats'
## too), and what a cell is tinted with (ChunkData.tints, saved with the
## region and sent with the chunk: `pack`ed, its glass's color and its
## frame's). What takes a tint: glass, panes and windows (Glass; a
## window's frame apart). A player's right click (Msg.TINT, `handle`)
## with a pot tints the glass (`frame`: the frame) and uses a coat (the
## last leaves its bottle); the watering can washes the glass, the axe
## scrapes the frame (it wears). Players having the chunk are told
## (Msg.TINTED).

## The palette (sRGB): red, yellow, blue, white, pink, green, black,
## orange, purple, then brown, grey, sky blue, soft green, ochre, burgundy,
## teal.
const COLORS: Array[String] = [
	"#b8483e",
	"#e6c25a",
	"#3e6aa8",
	"#efeae0",
	"#e391a8",
	"#4f8a4a",
	"#2e2c30",
	"#e08a3e",
	"#7d559a",
	"#7a5236",
	"#8a8a8e",
	"#8cbcdc",
	"#a6c86a",
	"#c8913a",
	"#7e2a38",
	"#3e8a8a",
]
## Packing: a color + 1 (0: none) in 5 bits, the glass's then the frame's.
const BITS := 5
const MASK := 31
const MESSAGES: Array[String] = [Msg.TINT]


## The color of a palette entry (-1: none, white).
static func color(index: int) -> Color:
	return Color(COLORS[index]) if index >= 0 and index < COLORS.size() else Color.WHITE


static func pack(glass: int, frame: int) -> int:
	return (glass + 1) | ((frame + 1) << BITS)


## The glass's color in a packed tint (-1: none).
static func glass_of(packed: int) -> int:
	return (packed & MASK) - 1


## The frame's color in a packed tint (-1: none).
static func frame_of(packed: int) -> int:
	return ((packed >> BITS) & MASK) - 1


## Whether a block takes a tint (and a frame's: windows).
static func tintable(block: int) -> bool:
	return Glass.is_glass(block)


## A cell's tint (packed; 0: none) in the loaded world.
static func at(world: WorldState, cell: Vector3i) -> int:
	var chunk: ChunkData = world.chunks.get(Coords.tile_to_chunk(Vector2i(cell.x, cell.z)))
	return chunk.tints.get(cell, 0) if chunk != null else 0


## Msg.TINT: a pot of paint, the watering can or the axe in a hotbar slot
## on a cell within reach (see the class). False: not this message.
static func handle(
	server: GameServer, session: GameServer.PlayerSession, message: Dictionary
) -> bool:
	if not message.get("t") in MESSAGES:
		return false
	var cell: Vector3i = message.get("cell", Vector3i.ZERO)
	var slot := clampi(int(message.get("slot", 0)), 0, Inventory.HOTBAR - 1)
	var frame := bool(message.get("frame", false))
	var world := server.world
	var block := Voxels.block_of(world.voxel_at(cell))
	if not session.joined or not session.alive() or not tintable(block):
		return true
	if Mining.reach_to(session.position, session.height, cell) > Mining.REACH + 1.0:
		return true
	frame = frame and Glass.is_window(block)
	var bag := session.inventory
	var held := bag.items[slot]
	var packed := at(world, cell)
	var glass := glass_of(packed)
	var trim := frame_of(packed)
	var paint := Items.PAINTS.find(held)
	if paint >= 0:
		if frame:
			trim = paint
		else:
			glass = paint
		if not GameModes.creative(server):
			bag.wear_out(slot)
			if bag.items[slot] == Items.Id.NONE and bag.add(Items.Id.GLASS_BOTTLE, 1) > 0:
				server.throw_item(session, Items.Id.GLASS_BOTTLE, 1)
	elif held == Items.Id.WATERING_CAN:
		glass = -1
	elif Items.tool_of(held) == Items.Tool.AXE and Glass.is_window(block):
		trim = -1
		if not GameModes.creative(server):
			bag.wear_out(slot)
	else:
		return true
	set_tint(server, cell, pack(glass, trim))
	session.transport.send(Msg.inventory(bag))
	return true


## Tints a cell (0: none), its chunk saved, its players told.
static func set_tint(server: GameServer, cell: Vector3i, packed: int) -> void:
	var tile := Vector2i(cell.x, cell.z)
	var coord := Coords.tile_to_chunk(tile)
	var chunk: ChunkData = server.world.chunks.get(coord)
	if chunk == null:
		return
	if packed == 0:
		chunk.tints.erase(cell)
	else:
		chunk.tints[cell] = packed
	server.world.contents_changed(cell)
	for session in server.sessions:
		if session.joined and session.sent_chunks.has(coord):
			session.transport.send(Msg.tinted(cell, packed))
