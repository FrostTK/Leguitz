class_name PropLights
extends RefCounted
## What a chunk build notes of its props besides their models (split from
## ChunkMesher; thread-safe): the light of what burns (a lit furnace, a
## campfire, torches, lanterns, the ambiance's candles, lamps and hearths:
## FLAMES), where chimneys smoke, and the props the client brings to life
## (Decor.LIVE: clocks, a framed map, a running shower; LiveProps).

const SEA := GameConst.SEA_LEVEL
## How bright a lit furnace's light is (lava's: 0.8 to 2.2).
const FIRE_LIGHT := 0.75
const LAVA_COLOR := Color(1.0, 0.45, 0.15)
const CANDLE_COLOR := Color(1.0, 0.7, 0.38)
## What else burns, by kind: where its flame is from the middle of its
## tile's floor (local units; z towards the way it faces), how bright, its
## color, and how much it flickers (flames do, a lantern's glass hardly). A
## wide hearth's is over the middle of its two tiles.
const FLAMES := {
	Tiles.Block.CAMPFIRE: [Vector3(0.0, 0.5, 0.0), 1.4, Color(1.0, 0.55, 0.22), 1.0],
	Tiles.Block.TORCH: [Vector3(0.0, 0.85, 0.0), 1.1, Color(1.0, 0.66, 0.32), 1.0],
	Tiles.Block.TORCH_BRACKET_LIT: [Vector3(0.0, 1.1, -0.16), 1.1, Color(1.0, 0.66, 0.32), 1.0],
	Tiles.Block.LANTERN: [Vector3(0.0, 0.4, 0.0), 1.25, Color(1.0, 0.76, 0.45), 0.25],
	Tiles.Block.LANTERN_HANGING: [Vector3(0.0, 0.5, 0.0), 1.25, Color(1.0, 0.76, 0.45), 0.25],
	Tiles.Block.LANTERN_WALL: [Vector3(0.0, 0.45, 0.0), 1.25, Color(1.0, 0.76, 0.45), 0.25],
	Tiles.Block.CANDLE: [Vector3(0.0, 0.5, 0.0), 0.55, CANDLE_COLOR, 1.0],
	Tiles.Block.CANDELABRA: [Vector3(0.0, 0.78, 0.0), 0.9, CANDLE_COLOR, 1.0],
	Tiles.Block.CHANDELIER: [Vector3(0.0, 0.55, 0.0), 1.6, CANDLE_COLOR, 0.7],
	Tiles.Block.BEDSIDE_LAMP: [Vector3(0.0, 0.62, 0.0), 0.9, Color(1.0, 0.78, 0.5), 0.15],
	Tiles.Block.WALL_SCONCE: [Vector3(0.0, 0.75, -0.2), 1.0, CANDLE_COLOR, 0.6],
	Tiles.Block.FIREPLACE_LIT: [Vector3(0.0, 0.3, 0.1), 1.9, Color(1.0, 0.55, 0.22), 1.0],
	Tiles.Block.STOVE_LIT: [Vector3(0.0, 0.35, 0.35), 1.0, Color(1.0, 0.55, 0.25), 0.8],
}


## The light of something burning in a tile (`floor`: the middle of its
## floor, local units; `below`: the voxel under it, a table drawing a
## candle down: Decor.sink): a lit furnace's shines out of its front. Not
## for a wide hearth's right end (its left end's light is over both).
static func add_flame(result: ChunkMesher.Result, block: int, floor: Vector3, below: int) -> bool:
	if ObjectShapes.is_wide_end(block):
		return false
	var flame: Array = FLAMES.get(
		ObjectShapes.base_kind(block), [Vector3(0.0, 0.5, 0.9), FIRE_LIGHT, LAVA_COLOR, 1.0]
	)
	var front := Vector2(ObjectShapes.front_of(block))
	var offset: Vector3 = flame[0]
	var at := (
		floor + Vector3(front.x * offset.z, offset.y - Decor.sink(block, below), front.y * offset.z)
	)
	if ObjectShapes.is_wide_left(block):
		var right := ObjectShapes.wide_right(block)
		at += Vector3(right.x, 0.0, right.y) * 0.5
	result.lava_spots.append(at)
	result.lava_strength.append(flame[1])
	result.lava_colors.append(flame[2])
	result.lava_flicker.append(flame[3])
	return true


## A chimney's top (`cell` of the chunk) smokes over a fire.
static func add_smoke(result: ChunkMesher.Result, voxels: PackedInt32Array, cell: Vector3i) -> void:
	var at := func(other: Vector3i) -> int: return ShapedFaces.voxel_at(voxels, other)
	if RoofBlocks.smokes(cell, at):
		result.smokes.append(Vector3(cell.x + 0.5, cell.y - SEA, cell.z + 0.5) + RoofModels.SMOKE)
