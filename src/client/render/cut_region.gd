class_name CutRegion
extends RefCounted
## Where the view cut reaches (see GameClient._update_cut): everywhere
## (underground, under natural rock), or only over the building the player
## is in, so the world around keeps its mountains and its trees. That is
## the covered room around the player (the tiles a body could stand on at
## their height under a roof, joined to theirs; flood filled), and a tile
## around it (its walls), within SIZE tiles; a building too big for it is
## cut everywhere. The shaders read it as a mask (`cut_mask`, see
## see_through.gdshaderinc), the chunk meshes for their surface maps and
## caps (columns_of), the aiming for what it may meet (covers).

## The mask's side (tiles), around the player.
const SIZE := 64

## True: the cut reaches everywhere (cells unused).
var everywhere := true
## The tile of the mask's first cell, and per tile (SIZE x SIZE, row by
## row) 1 where the cut reaches.
var origin := Vector2i.ZERO
var cells := PackedByteArray()
## The tiles cut, as a rectangle (everywhere: empty).
var bounds := Rect2i()


## The region of a player standing at `height` on `tile`, under cover.
static func around(world: ClientWorld, tile: Vector2i, height: float) -> CutRegion:
	var region := CutRegion.new()
	if not under_building(world, tile, height):
		return region
	region.origin = tile - Vector2i(SIZE / 2, SIZE / 2)
	var room := PackedByteArray()
	room.resize(SIZE * SIZE)
	var head_row := floori(height + 0.01) + GameConst.SEA_LEVEL + 1
	var start := tile - region.origin
	room[start.y * SIZE + start.x] = 1
	var queue: Array[Vector2i] = [start]
	var steps: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	while not queue.is_empty():
		var at: Vector2i = queue.pop_back()
		for step in steps:
			var next: Vector2i = at + step
			var index := next.y * SIZE + next.x
			if room[index] != 0 or not _is_room(world, region.origin + next, head_row, height):
				continue
			if next.x <= 1 or next.y <= 1 or next.x >= SIZE - 2 or next.y >= SIZE - 2:
				# Too big a building: cut everywhere.
				return CutRegion.new()
			room[index] = 1
			queue.append(next)
	region.everywhere = false
	region.cells.resize(SIZE * SIZE)
	var low := Vector2i(SIZE, SIZE)
	var high := Vector2i(-1, -1)
	for y in range(1, SIZE - 1):
		for x in range(1, SIZE - 1):
			if room[y * SIZE + x] == 0:
				continue
			# The room and a tile around it: its walls.
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					region.cells[(y + dy) * SIZE + x + dx] = 1
			low = Vector2i(mini(low.x, x - 1), mini(low.y, y - 1))
			high = Vector2i(maxi(high.x, x + 1), maxi(high.y, y + 1))
	region.bounds = Rect2i(region.origin + low, high - low + Vector2i.ONE)
	return region


## Whether what covers a body at `height` on `tile` is a building's (the
## first cube over its head is a building block: TileAtlas.BUILDING_WALLS).
static func under_building(world: ClientWorld, tile: Vector2i, height: float) -> bool:
	var row := floori(height + 0.01) + GameConst.SEA_LEVEL + 1
	while row < GameConst.WORLD_HEIGHT:
		var voxel := world.voxel_at(Vector3i(tile.x, row, tile.y))
		if Voxels.is_cube(voxel):
			return TileAtlas.BUILDING_WALLS.has(Voxels.block_of(voxel))
		row += 1
	return false


## Whether the cut reaches a tile.
func covers(tile: Vector2i) -> bool:
	if everywhere:
		return true
	var at := tile - origin
	if at.x < 0 or at.y < 0 or at.x >= SIZE or at.y >= SIZE:
		return false
	return cells[at.y * SIZE + at.x] != 0


## Whether the cut reaches into a chunk (or the border its meshes read).
func touches(coord: Vector2i) -> bool:
	if everywhere:
		return true
	var size := GameConst.CHUNK_SIZE
	var chunk := Rect2i(coord * size - Vector2i.ONE, Vector2i.ONE * (size + 2))
	return chunk.intersects(bounds)


## The chunk's columns the cut reaches, with its one-column border (see
## ChunkMesher.pad): 1 where it does. Empty: everywhere.
func columns_of(coord: Vector2i) -> PackedByteArray:
	var columns := PackedByteArray()
	if everywhere:
		return columns
	var span := GameConst.CHUNK_SIZE + 2
	columns.resize(span * span)
	var corner := coord * GameConst.CHUNK_SIZE - Vector2i.ONE
	for z in span:
		for x in span:
			columns[z * span + x] = 1 if covers(corner + Vector2i(x, z)) else 0
	return columns


## Whether two regions cut the same tiles (wherever their masks lie).
func same_as(other: CutRegion) -> bool:
	if other == null or everywhere != other.everywhere:
		return false
	if everywhere:
		return true
	if bounds != other.bounds:
		return false
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			if covers(Vector2i(x, y)) != other.covers(Vector2i(x, y)):
				return false
	return true


## The mask for the shaders (SIZE x SIZE, white where the cut reaches).
func image() -> Image:
	if everywhere:
		return Image.create(SIZE, SIZE, false, Image.FORMAT_L8)
	return Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_L8, _bytes())


func _bytes() -> PackedByteArray:
	var bytes := cells.duplicate()
	for i in bytes.size():
		bytes[i] *= 255
	return bytes


## Whether a body at `height` could be on `tile` under cover: the head's
## row open (not a cube) and something over it.
static func _is_room(world: ClientWorld, tile: Vector2i, head_row: int, height: float) -> bool:
	if Voxels.is_cube(world.voxel_at(Vector3i(tile.x, head_row, tile.y))):
		return false
	return world.is_covered(tile, height)
