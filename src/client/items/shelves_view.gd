class_name ShelvesView
extends Node3D
## What lies on the display shelves (Shelves; the client's chunks'
## ChunkData.shelves): each thing a small model standing on its shelf's
## board, side by side along it, in local units (in the world root).

## Size of a thing on a shelf (local units: its model fitted in this box).
const SIZE := 0.26
## Where the things stand: over the shelf's floor, out from the wall, apart
## (local units; FurnitureModels.shelf).
const BOARD := 0.5
const FROM_WALL := 0.22
const APART := 0.31

var library: ItemLibrary
var world: ClientWorld

var _shown: Dictionary[Vector3i, Node3D] = {}


## A chunk came: its shelves show what they hold.
func show_chunk(chunk: ChunkData) -> void:
	for cell: Vector3i in chunk.shelves:
		refresh(cell)


## A chunk went: so do its shelves' things.
func remove_chunk(coord: Vector2i) -> void:
	for cell: Vector3i in _shown.keys():
		if Coords.tile_to_chunk(Vector2i(cell.x, cell.z)) == coord:
			_shown[cell].queue_free()
			_shown.erase(cell)


## A shelf's things changed (or it came): shown again.
func refresh(cell: Vector3i) -> void:
	if _shown.has(cell):
		_shown[cell].queue_free()
		_shown.erase(cell)
	var chunk := world.chunk_at(Vector2i(cell.x, cell.z))
	var block := Voxels.block_of(world.voxel_at(cell))
	if chunk == null or not chunk.shelves.has(cell) or not Furniture.is_shelf(block):
		return
	var front := ObjectShapes.front_of(block)
	var right := ObjectShapes.wide_right(block)
	var holder := Node3D.new()
	var wall := Vector3(-front.x, 0.0, -front.y) * (0.5 - FROM_WALL)
	holder.position = (
		Vector3(cell.x + 0.5, cell.y - GameConst.SEA_LEVEL + BOARD, cell.z + 0.5) + wall
	)
	var items: PackedInt32Array = chunk.shelves[cell]
	for slot in items.size():
		if items[slot] == Items.Id.NONE:
			continue
		var model := MeshInstance3D.new()
		model.mesh = library.mesh(items[slot])
		model.scale = Vector3.ONE * SIZE * library.fit(items[slot])
		var along := (slot - (items.size() - 1) * 0.5) * APART
		model.position = Vector3(right.x, 0.0, right.y) * along
		model.rotation.y = atan2(front.x, front.y)
		holder.add_child(model)
	add_child(holder)
	_shown[cell] = holder
