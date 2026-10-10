class_name Glass
extends RefCounted
## The glass of buildings (static tables, shared). Glass cubes in a Style:
## CLEAR (almost unseen, a soft sheen; side by side they make one pane: a
## border only where the glass stops), OLD (blown: greenish, wavy, a few
## bubbles), LEADED (diamonds set in lead). Thin panes of each (facing
## kinds; they join their neighbors as fences do: `pane_sides`). Windows
## (FRAMED cubes): a Design (FOUR panes, SMALL panes, a SASH, a ROUND eye)
## in a frame of FRAMES (the six woods, wrought iron), drawn by the art
## (tools/gen_art.py). The client draws them in two passes (GlassFaces):
## their frames, lead and borders opaque, their glass see-through, tinted
## (Tints).

enum Style { CLEAR, OLD, LEADED, FRAMED }
enum Design { FOUR, SMALL, SASH, ROUND }

## [name prefix, its material item] of each frame.
const FRAMES := [
	["OAK", Items.Id.OAK_PLANKS],
	["BIRCH", Items.Id.BIRCH_PLANKS],
	["SPRUCE", Items.Id.SPRUCE_PLANKS],
	["DARK_OAK", Items.Id.DARK_OAK_PLANKS],
	["JUNGLE", Items.Id.JUNGLE_PLANKS],
	["ACACIA", Items.Id.ACACIA_PLANKS],
	["IRON", Items.Id.IRON_INGOT],
]
## Each design's name suffix.
const DESIGNS := ["", "_SMALL", "_SASH", "_ROUND"]
const CUBES := {
	Tiles.Block.GLASS: Style.CLEAR,
	Tiles.Block.OLD_GLASS: Style.OLD,
	Tiles.Block.LEADED_GLASS: Style.LEADED,
}
## Each pane kind's style (its first block: facing south).
const PANES := {
	Tiles.Block.GLASS_PANE: Style.CLEAR,
	Tiles.Block.OLD_GLASS_PANE: Style.OLD,
	Tiles.Block.LEADED_GLASS_PANE: Style.LEADED,
}
## The ways a pane joins (ChunkMesher's order: north, east, south, west).
const SIDES: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

## window block -> [design, frame index]; pane block -> its kind.
static var _windows: Dictionary[int, Vector2i] = {}
static var _panes: Dictionary[int, int] = {}
static var _built := _build()


## Whether a block is glass of any kind: a cube, a pane, a window.
static func is_glass(block: int) -> bool:
	return CUBES.has(block) or _windows.has(block) or _panes.has(block)


static func is_window(block: int) -> bool:
	return _windows.has(block)


static func is_pane(block: int) -> bool:
	return _panes.has(block)


## A glass block's Style (-1: none).
static func style_of(block: int) -> int:
	if CUBES.has(block):
		return CUBES[block]
	if _panes.has(block):
		return PANES[_panes[block]]
	return Style.FRAMED if _windows.has(block) else -1


## A window's design and frame (FRAMES index).
static func window_of(block: int) -> Vector2i:
	return _windows.get(block, Vector2i(-1, -1))


## The window of a design in a frame (FRAMES index).
static func window(design: int, frame: int) -> int:
	if design == Design.FOUR and frame == 0:
		return Tiles.Block.WINDOW
	return Tiles.Block[FRAMES[frame][0] + "_WINDOW" + DESIGNS[design]]


## The glass cube a pane is cut from (its look: the same art).
static func pane_glass(block: int) -> int:
	var style: int = PANES.get(_panes.get(block, -1), Style.CLEAR)
	return CUBES.find_key(style)


## Which sides (SIDES bits) a pane at `cell` joins: panes, glass, cubes;
## alone, it lies across the way it faces.
static func pane_sides(block: int, cell: Vector3i, voxel_at: Callable) -> int:
	var sides := 0
	for bit in SIDES.size():
		var next: int = voxel_at.call(cell + Vector3i(SIDES[bit].x, 0, SIDES[bit].y))
		if Voxels.is_cube(next) or is_pane(Voxels.block_of(next)):
			sides |= 1 << bit
	if sides == 0:
		var front := ObjectShapes.front_of(block)
		sides = 0b1010 if front.x == 0 else 0b0101
	return sides


static func _build() -> bool:
	for frame in FRAMES.size():
		for design in DESIGNS.size():
			_windows[window(design, frame)] = Vector2i(design, frame)
	for kind: int in PANES:
		var name := String(Tiles.Block.find_key(kind))
		for way: String in ["", "_WEST", "_NORTH", "_EAST"]:
			_panes[Tiles.Block[name + way]] = kind
	return true
