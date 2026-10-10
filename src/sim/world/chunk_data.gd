class_name ChunkData
extends RefCounted
## One 16 x 16 column of the world, WORLD_HEIGHT voxels tall (see Voxels).
##
## Voxels are stored column by column: index = (z * 16 + x) * HEIGHT + y,
## y being the row (SEA_LEVEL = level 0). Per column it also keeps the
## biome and the top of its terrain (highest cube or liquid voxel), which
## physics, rendering and spawning read without scanning.

## 4: voxels are ints (16-bit ids); before, bytes (read still: see
## ids_from_bytes).
const FORMAT_VERSION := 4
const SIZE := GameConst.CHUNK_SIZE
const HEIGHT := GameConst.WORLD_HEIGHT
## Water surfaces sit this far (levels) below the top of their voxel.
const WATER_DROP := 0.15
## A rug's voxel (see rugs).
const RUG := Voxels.BLOCK_BASE + Tiles.Block.RUG

var coord := Vector2i.ZERO
var voxels := PackedInt32Array()
var biome := PackedByteArray()
## Per column: 1 + row of the highest cube or liquid voxel (0 = none).
var tops := PackedByteArray()
## The columns (z * 16 + x) where something rises higher than a row over
## their terrain (hung on a wall up there): 1 + its row. Few have any.
var raised: Dictionary[int, int] = {}
## Set when a player changed the chunk (it must be saved, not regenerated).
var modified := false
## Server side: the chests standing in the chunk, by cell (their own
## Inventory; see WorldState.chest_at), saved with it, never sent.
var chests: Dictionary[Vector3i, Inventory] = {}
## Server side: the furnaces standing in the chunk (see
## WorldState.furnace_at), saved with it; the server runs them.
var furnaces: Dictionary[Vector3i, Furnace] = {}
## Server side: the cells where something may grow (see Growth), saved
## with it.
var growing: Dictionary[Vector3i, bool] = {}
## Server side: the farmland watered (a can, the rain), by cell: the
## seconds it stays wet (see Watering), saved with it.
var watered: Dictionary[Vector3i, float] = {}
## Server side: what the kitchen's machines and the fish traps hold, by cell
## (see Machines), saved with it.
var machines: Dictionary[Vector3i, Dictionary] = {}
## The cells tinted with paint (Tints.pack), by cell: saved with it and
## sent with it; a cell changing loses its tint (not curtains drawn or a
## gate swung: ObjectShapes.same_piece).
var tints: Dictionary[Vector3i, int] = {}
## The rugs lying under what was placed on them, by cell: their tint
## (Tints.pack; 0: none). Saved and sent with it. Something placed on a
## rug puts it there; when that goes (the cell set to air), the rug comes
## back (set_voxel: the server and the client's guesses alike).
var rugs: Dictionary[Vector3i, int] = {}


func _init(chunk_coord := Vector2i.ZERO) -> void:
	coord = chunk_coord
	# Packed arrays are values: resize each member directly.
	voxels.resize(GameConst.CHUNK_AREA * HEIGHT)
	biome.resize(GameConst.CHUNK_AREA)
	tops.resize(GameConst.CHUNK_AREA)


static func voxel_index(lx: int, y: int, lz: int) -> int:
	return (lz * SIZE + lx) * HEIGHT + y


func get_voxel(local: Vector3i) -> int:
	return voxels[voxel_index(local.x, local.y, local.z)]


func set_voxel(local: Vector3i, voxel: int) -> void:
	var index := voxel_index(local.x, local.y, local.z)
	var before := voxels[index]
	if not tints.is_empty() or not rugs.is_empty() or before == RUG:
		voxel = _keeps(local, before, voxel)
	voxels[index] = voxel
	var column := local.z * SIZE + local.x
	if Voxels.is_cube(voxel) or Voxels.is_liquid(voxel):
		tops[column] = maxi(tops[column], local.y + 1)
	elif local.y + 1 == tops[column]:
		tops[column] = _scan_top(local.x, local.z, local.y)
	if voxel != Voxels.AIR and not Voxels.is_cube(voxel) and local.y > tops[column]:
		raised[column] = maxi(raised.get(column, 0), local.y + 1)
	elif raised.get(column, 0) == local.y + 1:
		# The highest went: the next one under it, if any.
		raised.erase(column)
		var base := column * HEIGHT
		for y in range(local.y - 1, tops[column], -1):
			if voxels[base + y] != Voxels.AIR:
				raised[column] = y + 1
				break


## What a cell becomes when set to `voxel` (`before` there): a rug under
## what goes on it, back when that goes; a tint kept by the same piece.
func _keeps(local: Vector3i, before: int, voxel: int) -> int:
	var cell := Vector3i(coord.x * SIZE + local.x, local.y, coord.y * SIZE + local.z)
	if before == RUG and voxel != Voxels.AIR and voxel != RUG:
		rugs[cell] = tints.get(cell, 0)
		tints.erase(cell)
		return voxel
	if voxel == Voxels.AIR and rugs.has(cell):
		var tint: int = rugs[cell]
		rugs.erase(cell)
		tints.erase(cell)
		if tint != 0:
			tints[cell] = tint
		return RUG
	if tints.has(cell):
		if not ObjectShapes.same_piece(Voxels.block_of(before), Voxels.block_of(voxel)):
			tints.erase(cell)
	return voxel


## Row just above the terrain of a column (0 if the column is empty).
func top_row(local: Vector2i) -> int:
	return tops[local.y * SIZE + local.x]


## Height (levels) of the terrain surface of a column (water: a little
## lower than its voxel, flowing water lower still: Fluids.surface).
func surface_height(local: Vector2i) -> float:
	var row := top_row(local)
	var height := float(row - GameConst.SEA_LEVEL)
	if row > 0:
		var top := voxels[voxel_index(local.x, row - 1, local.y)]
		if Voxels.is_liquid(top):
			height -= 1.0 - Fluids.surface(top)
	return height


## The voxel at the top of a column's terrain (grass, sand, water...).
func surface_voxel(local: Vector2i) -> int:
	var row := top_row(local)
	return voxels[voxel_index(local.x, row - 1, local.y)] if row > 0 else Voxels.AIR


## The voxel standing on a column's terrain (tree, plant...) or air.
func object_on_surface(local: Vector2i) -> int:
	var row := top_row(local)
	return voxels[voxel_index(local.x, row, local.y)] if row < HEIGHT else Voxels.AIR


func get_biome(local: Vector2i) -> int:
	return biome[local.y * SIZE + local.x]


## Recomputes every column top (after filling the voxels directly), and
## what rises over them (raised).
func recompute_tops() -> void:
	var flags := Voxels.flag_table()
	var terrain := Voxels.FLAG_CUBE | Voxels.FLAG_LIQUID
	raised.clear()
	for column in GameConst.CHUNK_AREA:
		var base := column * HEIGHT
		var top := 0
		var highest := 0
		for y in range(HEIGHT - 1, -1, -1):
			var voxel := voxels[base + y]
			if voxel == Voxels.AIR:
				continue
			if flags[voxel] & terrain != 0:
				top = y + 1
				break
			if highest == 0:
				highest = y + 1
		tops[column] = top
		if highest > top + 1:
			raised[column] = highest


func duplicate_chunk() -> ChunkData:
	var copy := ChunkData.new(coord)
	copy.voxels = voxels.duplicate()
	copy.biome = biome.duplicate()
	copy.tops = tops.duplicate()
	copy.raised = raised.duplicate()
	copy.tints = tints.duplicate()
	copy.rugs = rugs.duplicate()
	copy.modified = modified
	return copy


func to_dict() -> Dictionary:
	return {
		"v": FORMAT_VERSION,
		"x": coord.x,
		"y": coord.y,
		"voxels": voxels,
		"biome": biome,
		"tops": tops,
		"raised": raised,
		"tints": tints,
		"rugs": rugs,
	}


static func from_dict(data: Dictionary) -> ChunkData:
	var chunk := ChunkData.new(Vector2i(data.get("x", 0), data.get("y", 0)))
	var voxels: Variant = data.get("voxels", PackedInt32Array())
	if voxels is PackedByteArray:
		voxels = ids_from_bytes(voxels)
	if (voxels as PackedInt32Array).size() == chunk.voxels.size():
		chunk.voxels = voxels
	var biome: PackedByteArray = data.get("biome", PackedByteArray())
	if biome.size() == GameConst.CHUNK_AREA:
		chunk.biome = biome
	var tops: PackedByteArray = data.get("tops", PackedByteArray())
	if tops.size() == GameConst.CHUNK_AREA:
		chunk.tops = tops
		var raised: Dictionary = data.get("raised", {})
		for column: int in raised:
			chunk.raised[int(column)] = int(raised[column])
	else:
		chunk.recompute_tops()
	for key: String in ["tints", "rugs"]:
		var cells: Dictionary = data.get(key, {})
		var into: Dictionary = chunk.tints if key == "tints" else chunk.rugs
		for cell: Variant in cells:
			if cell is Vector3i:
				into[cell] = int(cells[cell])
	return chunk


## Voxels saved one byte each (FORMAT_VERSION 3 and before: the ids were
## the same, below 255) as ids.
static func ids_from_bytes(bytes: PackedByteArray) -> PackedInt32Array:
	var ids := PackedInt32Array()
	ids.resize(bytes.size())
	for i in bytes.size():
		ids[i] = bytes[i]
	return ids


## 1 + the highest cube or liquid row below `below` in a column (0 = none).
func _scan_top(lx: int, lz: int, below: int) -> int:
	var base := (lz * SIZE + lx) * HEIGHT
	for y in range(below - 1, -1, -1):
		var voxel := voxels[base + y]
		if Voxels.is_cube(voxel) or Voxels.is_liquid(voxel):
			return y + 1
	return 0
