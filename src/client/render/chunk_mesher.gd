class_name ChunkMesher
extends RefCounted
## Builds the 3D terrain mesh of a chunk, in local units (see Render3D):
## - surface 0: top faces (the ground of every tile, tops of rock walls,
##   stair steps of ramps), UV = chunk pixels / 256 for the top shader,
## - surface 1: vertical faces wherever a neighbor is lower (cliffs between
##   terrace levels, sides of rock walls, banks of water), on every side,
##   since the camera can turn around.
## Neighbor chunks give correct faces on chunk borders; a missing neighbor
## is treated as level with this chunk (the mesh is rebuilt when it comes).

enum Side { NORTH, EAST, SOUTH, WEST }

const SIZE := GameConst.CHUNK_SIZE
const SPAN := SIZE + 2
const EPSILON := 0.01
const RAMP_STEPS := 4
## Face texture pixels per local unit of height (one level = 16 px).
const FACE_PX_PER_UNIT := 16.0 / Render3D.LEVEL_HEIGHT
## Face kinds: cliff materials first, then wall kinds.
const WALL_KIND_OFFSET := 4

const SIDE_OFFSETS := {
	Side.NORTH: Vector2i(0, -1),
	Side.EAST: Vector2i(1, 0),
	Side.SOUTH: Vector2i(0, 1),
	Side.WEST: Vector2i(-1, 0),
}
const SIDE_SHAPES := {
	Side.NORTH: ChunkData.SHAPE_LOWER_N,
	Side.EAST: ChunkData.SHAPE_LOWER_E,
	Side.SOUTH: ChunkData.SHAPE_LOWER_S,
	Side.WEST: ChunkData.SHAPE_LOWER_W,
}
const SIDE_NORMALS := {
	Side.NORTH: Vector3.FORWARD,
	Side.EAST: Vector3.RIGHT,
	Side.SOUTH: Vector3.BACK,
	Side.WEST: Vector3.LEFT,
}


## Terrain columns of the chunk plus a 1-tile border.
class Columns:
	extends RefCounted
	var ground := PackedInt32Array()
	var block := PackedInt32Array()
	var shape := PackedInt32Array()
	## Height of the ground (without walls) and of the top (with walls).
	var base := PackedFloat32Array()
	var top := PackedFloat32Array()

	func _init() -> void:
		# Packed arrays are values: resize each member directly.
		ground.resize(SPAN * SPAN)
		block.resize(SPAN * SPAN)
		shape.resize(SPAN * SPAN)
		base.resize(SPAN * SPAN)
		top.resize(SPAN * SPAN)


class Surface:
	extends RefCounted
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	## Adds a quad from 4 corners (any consistent winding), all sharing data.
	func quad(
		corners: Array[Vector3],
		quad_uvs: Array[Vector2],
		normal: Vector3,
		tangent: Vector3,
		uv2 := Vector2.ZERO,
		color := Color.BLACK
	) -> void:
		var start := vertices.size()
		for i in 4:
			vertices.append(corners[i])
			normals.append(normal)
			tangents.append_array([tangent.x, tangent.y, tangent.z, 1.0])
			uvs.append(quad_uvs[i])
			uv2s.append(uv2)
			colors.append(color)
		indices.append_array([start, start + 1, start + 2, start, start + 2, start + 3])

	func is_empty() -> bool:
		return vertices.is_empty()

	func arrays() -> Array:
		var result := []
		result.resize(Mesh.ARRAY_MAX)
		result[Mesh.ARRAY_VERTEX] = vertices
		result[Mesh.ARRAY_NORMAL] = normals
		result[Mesh.ARRAY_TANGENT] = tangents
		result[Mesh.ARRAY_TEX_UV] = uvs
		result[Mesh.ARRAY_TEX_UV2] = uv2s
		result[Mesh.ARRAY_COLOR] = colors
		result[Mesh.ARRAY_INDEX] = indices
		return result


## Material of a vertical face: atlas kind, the ground hanging over its top
## (lip, 0 = none) and texture variants.
class FaceStyle:
	extends RefCounted
	var kind := 0
	var lip := 0
	var lip_variant := 0
	var variant := 0.0
	## Height where the face texture starts (its top row).
	var texture_top := 0.0

	func _init(face_kind: int, face_variant: float, top: float) -> void:
		kind = face_kind
		variant = face_variant
		texture_top = top


## Returns an ArrayMesh with the top surface (0) and the face surface (1).
## `neighbor` is a Callable(coord: Vector2i) -> ChunkData (or null).
static func build(chunk: ChunkData, neighbor: Callable) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	# Keep both surfaces (even empty) so surface indices stay stable.
	for surface in build_surfaces(chunk, neighbor):
		if surface.is_empty():
			_add_degenerate(surface)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface.arrays())
	return mesh


## The geometry of a chunk: [tops, faces].
static func build_surfaces(chunk: ChunkData, neighbor: Callable) -> Array[Surface]:
	var columns := gather(chunk, neighbor)
	var tops := Surface.new()
	var faces := Surface.new()
	var origin_tile := Coords.chunk_origin_tile(chunk.coord)
	for ly in SIZE:
		for lx in SIZE:
			var i := (ly + 1) * SPAN + (lx + 1)
			var ramp_side := _ramp_side(columns, i)
			if ramp_side >= 0:
				_add_stairs(tops, faces, columns, i, lx, ly, ramp_side, origin_tile)
			else:
				_add_top(tops, lx, ly, columns.top[i])
			for side: int in SIDE_OFFSETS:
				# Stairs build their own sides (they follow the steps).
				if ramp_side >= 0 and side != _opposite(ramp_side):
					continue
				var offset: Vector2i = SIDE_OFFSETS[side]
				var j := i + offset.y * SPAN + offset.x
				if columns.top[j] < columns.top[i] - EPSILON:
					_add_side(faces, columns, i, j, lx, ly, side, origin_tile)
	return [tops, faces]


## Heights and materials of the chunk and its border.
static func gather(chunk: ChunkData, neighbor: Callable) -> Columns:
	var columns := Columns.new()
	var neighbors := {}
	for gy in SPAN:
		for gx in SPAN:
			var lx := gx - 1
			var ly := gy - 1
			var source := chunk
			if lx < 0 or ly < 0 or lx >= SIZE or ly >= SIZE:
				var offset := Vector2i(floori(lx / float(SIZE)), floori(ly / float(SIZE)))
				if not neighbors.has(offset):
					neighbors[offset] = neighbor.call(chunk.coord + offset)
				var other: ChunkData = neighbors[offset]
				if other != null:
					source = other
					lx = posmod(lx, SIZE)
					ly = posmod(ly, SIZE)
				else:
					lx = clampi(lx, 0, SIZE - 1)
					ly = clampi(ly, 0, SIZE - 1)
			var index := ly * SIZE + lx
			var i := gy * SPAN + gx
			var ground := source.ground[index]
			var block := source.blocks[index]
			columns.ground[i] = ground
			columns.block[i] = block
			columns.shape[i] = source.shapes[index]
			columns.base[i] = Render3D.surface_height(ground, source.levels[index])
			columns.top[i] = (
				columns.base[i] + (Render3D.WALL_HEIGHT if TileAtlas.is_wall(block) else 0.0)
			)
	return columns


## Ground texture variant of a tile, as the top shader picks it
## (ground_atlas_pos in terrain3d_common.gdshaderinc).
static func ground_variant(tile: Vector2i) -> int:
	var qx := (tile.x + 16777216) & 0xFFFFFFFF
	var qy := (tile.y + 16777216) & 0xFFFFFFFF
	var h := (qx * 374761393 + qy * 668265263) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	h = h ^ (h >> 16)
	return h & 3


static func _add_top(tops: Surface, lx: int, ly: int, height: float) -> void:
	var corners: Array[Vector3] = [
		Vector3(lx, height, ly),
		Vector3(lx + 1, height, ly),
		Vector3(lx + 1, height, ly + 1),
		Vector3(lx, height, ly + 1),
	]
	tops.quad(corners, _top_uvs(lx, ly, Rect2(0, 0, 1, 1)), Vector3.UP, Vector3.RIGHT)


## UVs of a part of a tile (rect in tile units), in chunk pixels / 256.
static func _top_uvs(lx: int, ly: int, rect: Rect2) -> Array[Vector2]:
	var scale := 1.0 / GameConst.CHUNK_SIZE
	var origin := Vector2(lx, ly) + rect.position
	return [
		origin * scale,
		(origin + Vector2(rect.size.x, 0)) * scale,
		(origin + rect.size) * scale,
		(origin + Vector2(0, rect.size.y)) * scale,
	]


## Vertical face on `side` of tile i, down to the top of neighbor j. A wall
## standing on a cliff gets two segments: wall above its base, cliff below.
static func _add_side(
	faces: Surface,
	columns: Columns,
	i: int,
	j: int,
	lx: int,
	ly: int,
	side: int,
	origin_tile: Vector2i
) -> void:
	var low := columns.top[j]
	var base := columns.base[i]
	var top := columns.top[i]
	var world_tile := origin_tile + Vector2i(lx, ly)
	var variant := float(HashUtil.hash2(0xFACE, world_tile.x * 4 + side, world_tile.y) & 1)
	var ground := columns.ground[i]
	var block := columns.block[i]
	var rect := Rect2(lx, ly, 1, 1)
	var cliff := FaceStyle.new(TerrainRenderer.cliff_material(ground), variant, base)
	if not Tiles.is_water(ground):
		cliff.lip = ground + 1
		cliff.lip_variant = ground_variant(world_tile)
	if TileAtlas.is_wall(block):
		var wall_kind: int = WALL_KIND_OFFSET + TileAtlas.WALL_KINDS[block]
		var wall := FaceStyle.new(wall_kind, variant, top)
		_wall(faces, rect, side, side, maxf(low, base), top, wall, lx, ly)
		if low < base - EPSILON:
			_wall(faces, rect, side, side, low, base, cliff, lx, ly)
	else:
		_wall(faces, rect, side, side, low, top, cliff, lx, ly)


## Vertical quad on the `edge` side of `rect` (local units), facing
## `facing`, from `bottom` to `top`. Texture u runs left to right as seen
## from the front, aligned on the tile at (lx, ly).
static func _wall(
	faces: Surface,
	rect: Rect2,
	edge: int,
	facing: int,
	bottom: float,
	top: float,
	style: FaceStyle,
	lx: int,
	ly: int
) -> void:
	var x0 := rect.position.x
	var x1 := rect.end.x
	var z0 := rect.position.y
	var z1 := rect.end.y
	match edge:
		Side.NORTH:
			z1 = z0
		Side.SOUTH:
			z0 = z1
		Side.EAST:
			x0 = x1
		_:
			x1 = x0
	var a: Vector2
	var b: Vector2
	var u0: float
	match facing:
		Side.SOUTH:
			a = Vector2(x0, z0)
			b = Vector2(x1, z0)
			u0 = a.x - lx
		Side.NORTH:
			a = Vector2(x1, z0)
			b = Vector2(x0, z0)
			u0 = lx + 1 - a.x
		Side.EAST:
			a = Vector2(x0, z1)
			b = Vector2(x0, z0)
			u0 = ly + 1 - a.y
		_:
			a = Vector2(x0, z0)
			b = Vector2(x0, z1)
			u0 = a.y - ly
	u0 *= 16.0
	var u1 := u0 + a.distance_to(b) * 16.0
	var v_top := (style.texture_top - top) * FACE_PX_PER_UNIT
	var v_bottom := (style.texture_top - bottom) * FACE_PX_PER_UNIT
	var corners: Array[Vector3] = [
		Vector3(a.x, top, a.y),
		Vector3(b.x, top, b.y),
		Vector3(b.x, bottom, b.y),
		Vector3(a.x, bottom, a.y),
	]
	var uvs: Array[Vector2] = [
		Vector2(u0, v_top), Vector2(u1, v_top), Vector2(u1, v_bottom), Vector2(u0, v_bottom)
	]
	var along := b - a
	var tangent := Vector3(along.x, 0.0, along.y).normalized()
	var color := Color(style.variant, style.lip_variant / 3.0, 0.0)
	faces.quad(corners, uvs, SIDE_NORMALS[facing], tangent, Vector2(style.kind, style.lip), color)


## Direction a ramp tile descends towards (-1 if not a walkable ramp).
static func _ramp_side(columns: Columns, i: int) -> int:
	var shape := columns.shape[i]
	if shape & ChunkData.SHAPE_RAMP == 0 or TileAtlas.is_wall(columns.block[i]):
		return -1
	for side in [Side.SOUTH, Side.EAST, Side.WEST, Side.NORTH]:
		if shape & SIDE_SHAPES[side] != 0:
			var offset: Vector2i = SIDE_OFFSETS[side]
			var j := i + offset.y * SPAN + offset.x
			if columns.top[j] < columns.top[i] - EPSILON:
				return side
	return -1


static func _opposite(side: int) -> int:
	return (side + 2) % 4


## Stairs from the tile's height down to its lower neighbor on `side`.
static func _add_stairs(
	tops: Surface,
	faces: Surface,
	columns: Columns,
	i: int,
	lx: int,
	ly: int,
	side: int,
	origin_tile: Vector2i
) -> void:
	var offset: Vector2i = SIDE_OFFSETS[side]
	var high := columns.top[i]
	var low := columns.top[i + offset.y * SPAN + offset.x]
	var world_tile := origin_tile + Vector2i(lx, ly)
	var variant := float(HashUtil.hash2(0x57A1, world_tile.x, world_tile.y) & 1)
	var cliff := TerrainRenderer.cliff_material(columns.ground[i])
	var style := FaceStyle.new(cliff, variant, high)
	# The two sides along the stairs.
	var flanks: Array[int] = [(side + 1) % 4, (side + 3) % 4]
	for step in RAMP_STEPS:
		# The first step is flush with the top, the last riser goes down to
		# `low` on the tile's edge.
		var h := step_height(high, low, step)
		var next_h := step_height(high, low, step + 1) if step < RAMP_STEPS - 1 else low
		var part := _step_rect(side, float(step) / RAMP_STEPS, float(step + 1) / RAMP_STEPS)
		var rect := Rect2(part.position + Vector2(lx, ly), part.size)
		var corners: Array[Vector3] = [
			Vector3(rect.position.x, h, rect.position.y),
			Vector3(rect.end.x, h, rect.position.y),
			Vector3(rect.end.x, h, rect.end.y),
			Vector3(rect.position.x, h, rect.end.y),
		]
		tops.quad(corners, _top_uvs(lx, ly, part), Vector3.UP, Vector3.RIGHT)
		# Riser of this step, facing down the stairs.
		_wall(faces, rect, side, side, next_h, h, style, lx, ly)
		# Close the step's ends against the neighbors on both flanks.
		for flank in flanks:
			var flank_offset: Vector2i = SIDE_OFFSETS[flank]
			var beside := columns.top[i + flank_offset.y * SPAN + flank_offset.x]
			if beside > h + EPSILON:
				var wall_top := minf(beside, high)
				_wall(faces, rect, flank, _opposite(flank), h, wall_top, style, lx, ly)
			elif beside < h - EPSILON:
				_wall(faces, rect, flank, flank, beside, h, style, lx, ly)


## Height of stair step `step` (0 = the top one) between two levels.
static func step_height(high: float, low: float, step: int) -> float:
	return lerpf(high, low, float(step) / RAMP_STEPS)


## Part of the tile (tile units) covered by step [a, b] along the descent.
static func _step_rect(side: int, a: float, b: float) -> Rect2:
	match side:
		Side.SOUTH:
			return Rect2(0.0, a, 1.0, b - a)
		Side.NORTH:
			return Rect2(0.0, 1.0 - b, 1.0, b - a)
		Side.EAST:
			return Rect2(a, 0.0, b - a, 1.0)
		_:
			return Rect2(1.0 - b, 0.0, b - a, 1.0)


static func _add_degenerate(surface: Surface) -> void:
	var corners: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	var uvs: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	surface.quad(corners, uvs, Vector3.UP, Vector3.RIGHT)


## Local height of the ground under a point (world pixels), following the
## steps of ramps.
static func height_at(world: ClientWorld, world_px: Vector2) -> float:
	var tile := Coords.world_to_tile(world_px)
	var chunk := world.chunk_at(tile)
	if chunk == null:
		return 0.0
	var index := Coords.local_index(Coords.tile_to_local(tile))
	var height := Render3D.surface_height(chunk.ground[index], chunk.levels[index])
	var shape := chunk.shapes[index]
	if shape & ChunkData.SHAPE_RAMP == 0:
		return height
	var fraction := world_px / GameConst.TILE_SIZE - Vector2(tile)
	for side in [Side.SOUTH, Side.EAST, Side.WEST, Side.NORTH]:
		if shape & SIDE_SHAPES[side] == 0:
			continue
		var offset: Vector2i = SIDE_OFFSETS[side]
		var other := world.chunk_at(tile + offset)
		if other == null:
			continue
		var j := Coords.local_index(Coords.tile_to_local(tile + offset))
		var low := Render3D.surface_height(other.ground[j], other.levels[j])
		var progress: float
		match side:
			Side.SOUTH:
				progress = fraction.y
			Side.NORTH:
				progress = 1.0 - fraction.y
			Side.EAST:
				progress = fraction.x
			_:
				progress = 1.0 - fraction.x
		var step := clampi(floori(progress * RAMP_STEPS), 0, RAMP_STEPS - 1)
		return step_height(height, low, step)
	return height
