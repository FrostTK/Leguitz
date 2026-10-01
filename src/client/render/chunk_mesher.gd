class_name ChunkMesher
extends RefCounted
## Builds the 3D terrain mesh of a chunk:
## - surface 0: top faces (the ground of every tile, tops of rock walls,
##   stair steps of ramps), UV = chunk pixels / 256 for the top shader,
## - surface 1: vertical faces wherever a neighbor is lower (cliffs between
##   terrace levels, sides of rock walls, banks of water).
## Neighbor chunks give correct faces on chunk borders; a missing neighbor
## is treated as level with this chunk (the mesh is rebuilt when it comes).

enum Side { NORTH, EAST, SOUTH, WEST }

const SIZE := GameConst.CHUNK_SIZE
const SPAN := SIZE + 2
const EPSILON := 0.01
const RAMP_STEPS := 4
## Face texture pixels per world unit of height (one level = 16 px).
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
	var zs := Render3D.z_stretch
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
				if side == ramp_side:
					continue
				var offset: Vector2i = SIDE_OFFSETS[side]
				var j := i + offset.y * SPAN + offset.x
				if columns.top[j] < columns.top[i] - EPSILON:
					_add_side(faces, columns, i, j, lx, ly, side, origin_tile, zs)
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


static func _add_top(tops: Surface, lx: int, ly: int, height: float) -> void:
	var zs := Render3D.z_stretch
	var x0 := float(lx)
	var z0 := ly * zs
	var corners: Array[Vector3] = [
		Vector3(x0, height, z0),
		Vector3(x0 + 1.0, height, z0),
		Vector3(x0 + 1.0, height, z0 + zs),
		Vector3(x0, height, z0 + zs),
	]
	tops.quad(corners, _top_uvs(lx, ly, 0.0, 0.0, 1.0, 1.0), Vector3.UP, Vector3.RIGHT)


## UVs of a (sub-)rectangle of a tile, in chunk pixels / 256.
static func _top_uvs(
	lx: int, ly: int, fx0: float, fy0: float, fx1: float, fy1: float
) -> Array[Vector2]:
	var scale := 1.0 / GameConst.CHUNK_SIZE
	return [
		Vector2(lx + fx0, ly + fy0) * scale,
		Vector2(lx + fx1, ly + fy0) * scale,
		Vector2(lx + fx1, ly + fy1) * scale,
		Vector2(lx + fx0, ly + fy1) * scale,
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
	origin_tile: Vector2i,
	zs: float
) -> void:
	var low := columns.top[j]
	var base := columns.base[i]
	var top := columns.top[i]
	var world_tile := origin_tile + Vector2i(lx, ly)
	var variant := float(HashUtil.hash2(0xFACE, world_tile.x * 4 + side, world_tile.y) & 1)
	var ground := columns.ground[i]
	var block := columns.block[i]
	if TileAtlas.is_wall(block):
		var wall_kind: int = WALL_KIND_OFFSET + TileAtlas.WALL_KINDS[block]
		var wall_bottom := maxf(low, base)
		_face_segment(faces, lx, ly, side, wall_bottom, top, top, wall_kind, 0, variant, zs)
		if low < base - EPSILON:
			var cliff := TerrainRenderer.cliff_material(ground)
			_face_segment(faces, lx, ly, side, low, base, base, cliff, ground + 1, variant, zs)
	else:
		var cliff := TerrainRenderer.cliff_material(ground)
		var lip := ground + 1 if not Tiles.is_water(ground) else 0
		_face_segment(faces, lx, ly, side, low, top, top, cliff, lip, variant, zs)


static func _face_segment(
	faces: Surface,
	lx: int,
	ly: int,
	side: int,
	bottom: float,
	top: float,
	texture_top: float,
	kind: int,
	lip: int,
	variant: float,
	zs: float
) -> void:
	var x0 := float(lx)
	var x1 := x0 + 1.0
	var z0 := ly * zs
	var z1 := z0 + zs
	var v_top := (texture_top - top) * FACE_PX_PER_UNIT
	var v_bottom := (texture_top - bottom) * FACE_PX_PER_UNIT
	var corners: Array[Vector3]
	var normal: Vector3
	var tangent: Vector3
	match side:
		Side.SOUTH:
			corners = [
				Vector3(x0, top, z1),
				Vector3(x1, top, z1),
				Vector3(x1, bottom, z1),
				Vector3(x0, bottom, z1)
			]
			normal = Vector3.BACK
			tangent = Vector3.RIGHT
		Side.NORTH:
			corners = [
				Vector3(x1, top, z0),
				Vector3(x0, top, z0),
				Vector3(x0, bottom, z0),
				Vector3(x1, bottom, z0)
			]
			normal = Vector3.FORWARD
			tangent = Vector3.LEFT
		Side.EAST:
			corners = [
				Vector3(x1, top, z1),
				Vector3(x1, top, z0),
				Vector3(x1, bottom, z0),
				Vector3(x1, bottom, z1)
			]
			normal = Vector3.RIGHT
			tangent = Vector3.FORWARD
		_:
			corners = [
				Vector3(x0, top, z0),
				Vector3(x0, top, z1),
				Vector3(x0, bottom, z1),
				Vector3(x0, bottom, z0)
			]
			normal = Vector3.LEFT
			tangent = Vector3.BACK
	var uvs: Array[Vector2] = [
		Vector2(0.0, v_top), Vector2(16.0, v_top), Vector2(16.0, v_bottom), Vector2(0.0, v_bottom)
	]
	faces.quad(corners, uvs, normal, tangent, Vector2(kind, lip), Color(variant, 0, 0))


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
	var zs := Render3D.z_stretch
	var ground := columns.ground[i]
	var cliff := TerrainRenderer.cliff_material(ground)
	var world_tile := origin_tile + Vector2i(lx, ly)
	var variant := float(HashUtil.hash2(0x57A1, world_tile.x, world_tile.y) & 1)
	for step in RAMP_STEPS:
		# Step `step` spans [a, b] along the descent, at height h.
		var a := float(step) / RAMP_STEPS
		var b := float(step + 1) / RAMP_STEPS
		var h := lerpf(high, low, float(step + 1) / (RAMP_STEPS + 1))
		var next_h := (
			lerpf(high, low, float(step + 2) / (RAMP_STEPS + 1)) if step < RAMP_STEPS - 1 else low
		)
		var rect := _step_rect(side, a, b)
		var x0 := lx + rect.position.x
		var x1 := lx + rect.end.x
		var z0 := (ly + rect.position.y) * zs
		var z1 := (ly + rect.end.y) * zs
		var corners: Array[Vector3] = [
			Vector3(x0, h, z0), Vector3(x1, h, z0), Vector3(x1, h, z1), Vector3(x0, h, z1)
		]
		var uvs := _top_uvs(lx, ly, rect.position.x, rect.position.y, rect.end.x, rect.end.y)
		tops.quad(corners, uvs, Vector3.UP, Vector3.RIGHT)
		# Riser of this step, facing down the stairs.
		var riser := _riser(side, x0, x1, z0, z1)
		var v_top := (high - h) * FACE_PX_PER_UNIT
		var v_bottom := (high - next_h) * FACE_PX_PER_UNIT
		var riser_corners: Array[Vector3] = [
			Vector3(riser[0].x, h, riser[0].y),
			Vector3(riser[1].x, h, riser[1].y),
			Vector3(riser[1].x, next_h, riser[1].y),
			Vector3(riser[0].x, next_h, riser[0].y),
		]
		var riser_uvs: Array[Vector2] = [
			Vector2(0.0, v_top),
			Vector2(16.0, v_top),
			Vector2(16.0, v_bottom),
			Vector2(0.0, v_bottom)
		]
		var normal := Vector3(offset.x, 0.0, offset.y)
		faces.quad(
			riser_corners,
			riser_uvs,
			normal,
			Vector3(-offset.y, 0, offset.x),
			Vector2(cliff, 0),
			Color(variant, 0, 0)
		)


## Sub-rectangle (tile units) of step [a, b] along the descent direction.
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


## The two ground points (x, z) of a step's riser edge, left to right as seen
## from below the stairs.
static func _riser(side: int, x0: float, x1: float, z0: float, z1: float) -> Array[Vector2]:
	match side:
		Side.SOUTH:
			return [Vector2(x0, z1), Vector2(x1, z1)]
		Side.NORTH:
			return [Vector2(x1, z0), Vector2(x0, z0)]
		Side.EAST:
			return [Vector2(x1, z1), Vector2(x1, z0)]
		_:
			return [Vector2(x0, z0), Vector2(x0, z1)]


static func _add_degenerate(surface: Surface) -> void:
	var corners: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	var uvs: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	surface.quad(corners, uvs, Vector3.UP, Vector3.RIGHT)


## Height of the ground under a point (world pixels), following ramps.
static func height_at(world: ClientWorld, world_px: Vector2) -> float:
	var tile := Coords.world_to_tile(world_px)
	var chunk := world.chunk_at(tile)
	if chunk == null:
		return 0.0
	var local := Coords.tile_to_local(tile)
	var index := Coords.local_index(local)
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
		return lerpf(height, low, clampf(progress, 0.0, 1.0) * RAMP_STEPS / (RAMP_STEPS + 1.0))
	return height
