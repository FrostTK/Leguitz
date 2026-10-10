class_name RoofFaces
extends RefCounted
## The faces of a roof's pieces (RoofBlocks) for ChunkMesher, in the
## terrain's face meshes (terrain3d_faces.gdshader): their top, the
## triangles of the cell's 2 x 2 grid following the surface (one quad where
## it is one plane), wearing the covering's face texture down the slope
## (UV2.y ROOF_FACE: the shader lays the season's snow on it); the sides of
## their profile nothing covers (a gable's end wears the wall's texture
## under it), with a verge of raised tiles along the top of an open gable;
## a ridge's cap along its peak; their underside and back, seen from the
## attic, in boards (BOARDS). Thread-safe: only reads what it is given.

## UV2.y of what wears the covering out in the weather (the shader's roof
## branch: snow in winter).
const ROOF_FACE := -4.0
const HEIGHT := GameConst.WORLD_HEIGHT
const SEA := GameConst.SEA_LEVEL
const PX := 16.0
## The four sides: north, east, south, west.
const SIDES: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
## The grid the top follows (cell coordinates).
const GRID: Array[float] = [0.0, 0.5, 1.0]
## A verge's tiles: how far in from the gable, how high over the slope; a
## ridge's cap: half its width, how high over the peak (local units).
const VERGE_WIDTH := 2.0 / 16.0
const VERGE_RISE := 1.0 / 16.0
const CAP_HALF := 2.0 / 16.0
const CAP_RISE := 1.5 / 16.0
const EPSILON := 0.0001
## What the roof shows the attic under it: boards.
const BOARDS := Tiles.Block.SPRUCE_PLANKS
## What covers a side, along its two halves ([from, to] each): nothing, a
## whole cube.
const OPEN := [0.0, 0.0, 0.0, 0.0]
const SHUT := [1.0, 1.0, 1.0, 1.0]


## Adds the faces of the roof piece at (lx, y, lz) of a chunk being built
## (as ShapedFaces.build) to its face meshes (in a cave: the deep ones).
static func build(
	result: ChunkMesher.Result,
	voxels: PackedInt32Array,
	tops: PackedByteArray,
	tables: Array,
	column: int,
	lx: int,
	y: int,
	lz: int,
	origin: Vector2i
) -> void:
	var flags: PackedByteArray = tables[0]
	var kinds: PackedInt32Array = tables[1]
	var index := column * HEIGHT + y
	var rows := tops[column] - y
	var deep := rows > 1 and not ChunkMesher.sky_through(voxels, flags, tables[3], index, rows)
	var tile := origin + Vector2i(lx, lz)
	var variant := float(HashUtil.hash2(0xFACE, tile.x, tile.y + y * 131) & 1)
	# The sky light over it, beside it, under it: the piece keeps it out of
	# its own cell.
	var lights := PackedFloat32Array([_light(tables, index + 1, y + 1)])
	for side in SIDES:
		var step := side.x * ChunkMesher.STRIDE_X + side.y * ChunkMesher.STRIDE_Z
		lights.append(_light(tables, index + step, y))
	lights.append(_light(tables, index - 1, y - 1))
	var part := ChunkMesher.Part.DEEP_FACES if deep else ChunkMesher.Part.FACES
	add(result.parts[part], voxels, flags, kinds, Vector3i(lx, y, lz), variant, lights)


## Adds the faces of the roof piece in `cell` of a chunk (padded `voxels`,
## see ChunkMesher.pad_voxels) to `surface`.
static func add(
	surface: ChunkMesher.Surface,
	voxels: PackedInt32Array,
	flags: PackedByteArray,
	kinds: PackedInt32Array,
	cell: Vector3i,
	variant: float,
	lights: PackedFloat32Array
) -> void:
	var at := func(other: Vector3i) -> int: return ShapedFaces.voxel_at(voxels, other)
	var block := Voxels.block_of(at.call(cell))
	var kind: int = kinds[Voxels.of_block(RoofBlocks.material_of(block))]
	var under: int = at.call(cell + Vector3i.DOWN)
	var cube_under := flags[under] & Voxels.FLAG_CUBE != 0
	var covers := []
	for side in SIDES:
		covers.append(_cover(cell + Vector3i(side.x, 0, side.y), side, flags, at))
	var boards: int = kinds[Voxels.of_block(BOARDS)]
	var looks := [kind, kinds[under] if cube_under else kind, variant, boards]
	var branches := RoofBlocks.surface(block, cell, at)
	var peaks := RoofBlocks.peaks(block, cell, at)
	piece(surface, branches, cell, looks, lights, covers, not cube_under, peaks)


## The faces of a roof piece of `branches` (RoofBlocks.surface) in `cell`:
## `looks` [the covering's face kind, a gable's (the wall under it), the
## texture variant, the boards'], `lights` the sky light over it, on each
## of SIDES and under it (0 to 1), `covers` what covers each side (OPEN,
## SHUT or the heights of what is there), `bottom` whether its underside
## shows, `peaks` its cap's lines (RoofBlocks.peaks).
static func piece(
	surface: ChunkMesher.Surface,
	branches: Array[PackedVector3Array],
	cell: Vector3i,
	looks: Array,
	lights: PackedFloat32Array,
	covers: Array,
	bottom: bool,
	peaks: Array
) -> void:
	var floor := Vector3(cell.x, cell.y - SEA, cell.z)
	var kind: int = looks[0]
	var top := Color(looks[2], 0.0, lights[0])
	_top(surface, branches, floor, kind, top)
	for s in SIDES.size():
		var color := Color(looks[2], 0.0, lights[1 + s])
		_side(surface, branches, floor, SIDES[s], covers[s], looks, color, top)
	for peak: Array in peaks:
		_cap(surface, floor, peak, kind, top)
	if bottom:
		var corners: Array[Vector3] = []
		var uvs: Array[Vector2] = []
		for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			corners.append(floor + Vector3(corner.x, 0.0, corner.y))
			uvs.append(corner * PX)
		var under := Color(looks[2], 0.0, lights[5])
		var boards := Vector2(looks[3], 0.0)
		_emit(surface, corners, uvs, Vector3.DOWN, Vector3.RIGHT, boards, under)


## The sky light of a cell (0 to 1; over the world: the sky's).
static func _light(tables: Array, index: int, row: int) -> float:
	if row >= HEIGHT:
		return 1.0
	if row < 0:
		return 0.0
	return ChunkMesher.sky_level(tables, index) / float(LightField.MAX)


## What covers the side of a cell facing `side` from the cell `next`
## beside it: the heights along that side's halves (see OPEN).
static func _cover(next: Vector3i, side: Vector2i, flags: PackedByteArray, at: Callable) -> Array:
	var voxel: int = at.call(next)
	var block := Voxels.block_of(voxel)
	if flags[voxel] & Voxels.FLAG_CUBE != 0 or RoofBlocks.is_dormer(block):
		return SHUT
	if flags[voxel] & Voxels.FLAG_SHAPED == 0:
		return OPEN
	if Tiles.is_roof(block):
		var branches := RoofBlocks.surface(block, next, at)
		var heights := []
		for point in _edge(-side):
			heights.append(RoofBlocks.height_at(branches, point.x, point.y))
		return [heights[0], heights[1], heights[1], heights[2]]
	# Stairs or a slab: the octants against this side, by halves.
	var mask := ShapedBlocks.mask(block, next, at)
	var result := []
	for half in 2:
		var o := Vector2i(half, 1 if side.y < 0 else 0)
		if side.x != 0:
			o = Vector2i(1 if side.x < 0 else 0, half)
		var low := 1 << (o.x + o.y * 2)
		var height := 0.0
		if mask & low != 0:
			height = 1.0 if mask & (low << 4) != 0 else 0.5
		result.append_array([height, height])
	return result


## The three points (cell coordinates x, z) along a side of the cell, x or
## z growing.
static func _edge(side: Vector2i) -> Array[Vector2]:
	if side.y != 0:
		var z := 0.0 if side.y < 0 else 1.0
		return [Vector2(0.0, z), Vector2(0.5, z), Vector2(1.0, z)]
	var x := 0.0 if side.x < 0 else 1.0
	return [Vector2(x, 0.0), Vector2(x, 0.5), Vector2(x, 1.0)]


## The top: one quad if it is one plane, else each quarter of the cell
## split along the diagonal its surface creases on.
static func _top(
	surface: ChunkMesher.Surface,
	branches: Array[PackedVector3Array],
	floor: Vector3,
	kind: int,
	color: Color
) -> void:
	var heights := PackedFloat32Array()
	for z in GRID:
		for x in GRID:
			heights.append(RoofBlocks.height_at(branches, x, z))
	var origin := heights[0]
	var along_x := heights[2] - origin
	var along_z := heights[6] - origin
	var flat := true
	for i in 9:
		var expected := origin + along_x * GRID[i % 3] + along_z * GRID[i / 3]
		flat = flat and absf(expected - heights[i]) < EPSILON
	for center: Vector2 in [Vector2(0.25, 0.25), Vector2(0.75, 0.25), Vector2(0.25, 0.75)]:
		var expected := origin + along_x * center.x + along_z * center.y
		var real := RoofBlocks.height_at(branches, center.x, center.y)
		flat = flat and absf(expected - real) < EPSILON
	if flat:
		var corners := [Vector3(0, origin, 0), Vector3(1, heights[2], 0)]
		corners += [Vector3(1, heights[8], 1), Vector3(0, heights[6], 1)]
		_facet(surface, corners, floor, kind, color)
		return
	for qz in 2:
		for qx in 2:
			var p00 := Vector3(GRID[qx], heights[qz * 3 + qx], GRID[qz])
			var p10 := Vector3(GRID[qx + 1], heights[qz * 3 + qx + 1], GRID[qz])
			var p11 := Vector3(GRID[qx + 1], heights[qz * 3 + qx + 4], GRID[qz + 1])
			var p01 := Vector3(GRID[qx], heights[qz * 3 + qx + 3], GRID[qz + 1])
			var middle := RoofBlocks.height_at(branches, (qx + 0.5) * 0.5, (qz + 0.5) * 0.5)
			var one := absf((p00.y + p11.y) * 0.5 - middle)
			var other := absf((p10.y + p01.y) * 0.5 - middle)
			if absf(p00.y + p11.y - p10.y - p01.y) < EPSILON and one < EPSILON:
				_facet(surface, [p00, p10, p11, p01], floor, kind, color)
			elif one <= other:
				_facet(surface, [p00, p10, p11], floor, kind, color)
				_facet(surface, [p00, p11, p01], floor, kind, color)
			else:
				_facet(surface, [p10, p11, p01], floor, kind, color)
				_facet(surface, [p10, p01, p00], floor, kind, color)


## A flat piece of the top (points: cell x, height, cell z), its texture
## running down its slope: across it the covering's pixels, down it a
## tile's height a level (a gentle slope's a cell).
static func _facet(
	surface: ChunkMesher.Surface, points: Array, floor: Vector3, kind: int, color: Color
) -> void:
	var a: Vector3 = points[0]
	var normal := ((points[1] as Vector3) - a).cross((points[2] as Vector3) - a).normalized()
	if normal.y < 0.0:
		normal = -normal
	if normal.y < EPSILON or points.all(func(p: Vector3) -> bool: return p.y < EPSILON):
		return
	var down := Vector2(normal.x, normal.z)
	var facing := Vector2i(0, 1)
	if absf(down.x) > absf(down.y):
		facing = Vector2i(int(signf(down.x)), 0)
	elif absf(down.y) > EPSILON:
		facing = Vector2i(0, int(signf(down.y)))
	var rise := maxf(down.length() / normal.y, 0.25)
	var right := Vector2(facing.y, -facing.x)
	var corners: Array[Vector3] = []
	var uvs: Array[Vector2] = []
	for p: Vector3 in points:
		var at := floor + p
		corners.append(at)
		uvs.append(Vector2((right.x * at.x + right.y * at.z) * PX, (1.0 - p.y) / rise * PX))
	var tangent := Vector3(right.x, 0.0, right.y)
	_emit(surface, corners, uvs, normal, tangent, Vector2(kind, ROOF_FACE), color)


## A side's faces where they rise over what covers it (a gable's end in
## the wall's texture under it, the back of a slope in boards), and an
## open gable's verge.
static func _side(
	surface: ChunkMesher.Surface,
	branches: Array[PackedVector3Array],
	floor: Vector3,
	side: Vector2i,
	cover: Array,
	looks: Array,
	color: Color,
	top: Color
) -> void:
	var points := _edge(side)
	var heights := PackedFloat32Array()
	for point in points:
		heights.append(RoofBlocks.height_at(branches, point.x, point.y))
	var sloping := (
		absf(heights[0] - heights[2]) > EPSILON or absf(heights[1] - heights[0]) > EPSILON
	)
	var kind: int = looks[1] if sloping else looks[3]
	var normal := Vector3(side.x, 0.0, side.y)
	var tangent := Vector3(-side.y, 0.0, side.x)
	for half in 2:
		var high_a := heights[half]
		var high_b := heights[half + 1]
		var low_a := minf(cover[half * 2], high_a)
		var low_b := minf(cover[half * 2 + 1], high_b)
		if high_a - low_a < EPSILON and high_b - low_b < EPSILON:
			continue
		var a := points[half]
		var b := points[half + 1]
		var corners: Array[Vector3] = [
			floor + Vector3(a.x, high_a, a.y),
			floor + Vector3(b.x, high_b, b.y),
			floor + Vector3(b.x, low_b, b.y),
			floor + Vector3(a.x, low_a, a.y),
		]
		var uvs: Array[Vector2] = []
		for corner in corners:
			uvs.append(Vector2(_along(side, corner - floor) * PX, (1.0 - corner.y + floor.y) * PX))
		_emit(surface, corners, uvs, normal, tangent, Vector2(kind, 0.0), color)
	if sloping and cover == OPEN:
		_verge(surface, branches, floor, side, points, heights, looks[0], top)


## How far along a side a point of the cell lies (0 to 1), as a cube's
## side texture runs (left to right seen from out there).
static func _along(side: Vector2i, point: Vector3) -> float:
	if side.y > 0:
		return point.x
	if side.y < 0:
		return 1.0 - point.x
	return 1.0 - point.z if side.x > 0 else point.z


## Tiles raised along the top of an open gable (the verge).
static func _verge(
	surface: ChunkMesher.Surface,
	branches: Array[PackedVector3Array],
	floor: Vector3,
	side: Vector2i,
	points: Array[Vector2],
	heights: PackedFloat32Array,
	kind: int,
	color: Color
) -> void:
	var inward := Vector2(-side.x, -side.y) * VERGE_WIDTH
	var out := Vector3(side.x, 0.0, side.y)
	var tangent := Vector3(-side.y, 0.0, side.x)
	var rise := Vector3(0.0, VERGE_RISE, 0.0)
	for half in 2:
		if heights[half] < EPSILON and heights[half + 1] < EPSILON:
			continue
		var a := points[half]
		var b := points[half + 1]
		var ai := a + inward
		var bi := b + inward
		var edge_a := floor + Vector3(a.x, heights[half], a.y)
		var edge_b := floor + Vector3(b.x, heights[half + 1], b.y)
		var in_a := floor + Vector3(ai.x, RoofBlocks.height_at(branches, ai.x, ai.y), ai.y)
		var in_b := floor + Vector3(bi.x, RoofBlocks.height_at(branches, bi.x, bi.y), bi.y)
		var along_a := _along(side, edge_a - floor) * PX
		var along_b := _along(side, edge_b - floor) * PX
		var top: Array[Vector3] = [edge_a + rise, edge_b + rise, in_b + rise, in_a + rise]
		var normal := (top[1] - top[0]).cross(top[3] - top[0]).normalized()
		if normal.y < 0.0:
			normal = -normal
		var flat_uvs: Array[Vector2] = [
			Vector2(along_a, 0.0),
			Vector2(along_b, 0.0),
			Vector2(along_b, 2.0),
			Vector2(along_a, 2.0)
		]
		var uv2 := Vector2(kind, ROOF_FACE)
		_emit(surface, top, flat_uvs, normal, tangent, uv2, color)
		var outer: Array[Vector3] = [edge_a + rise, edge_b + rise, edge_b, edge_a]
		_emit(surface, outer, flat_uvs, out, tangent, uv2, color)
		var inner: Array[Vector3] = [in_a + rise, in_b + rise, in_b, in_a]
		_emit(surface, inner, flat_uvs, -out, tangent, uv2, color)


## A ridge's cap along one of its lines (RoofBlocks.peaks): two sloping
## faces over the peak, closed where it stops.
static func _cap(
	surface: ChunkMesher.Surface, floor: Vector3, peak: Array, kind: int, color: Color
) -> void:
	var from: Vector2 = peak[0]
	var to: Vector2 = peak[1]
	var way := (to - from).normalized()
	var across := Vector2(-way.y, way.x) * CAP_HALF
	var ridge := 0.5 + CAP_RISE
	var base := 0.5 - CAP_HALF
	var length := (to - from).length() * PX
	var uv2 := Vector2(kind, ROOF_FACE)
	var tangent := Vector3(way.x, 0.0, way.y)
	for side: float in [-1.0, 1.0]:
		var corners: Array[Vector3] = [
			floor + Vector3(from.x, ridge, from.y),
			floor + Vector3(to.x, ridge, to.y),
			floor + Vector3(to.x + across.x * side, base, to.y + across.y * side),
			floor + Vector3(from.x + across.x * side, base, from.y + across.y * side),
		]
		var normal := (corners[1] - corners[0]).cross(corners[3] - corners[0]).normalized()
		if normal.y < 0.0:
			normal = -normal
		var uvs: Array[Vector2] = [
			Vector2(0.0, 1.0), Vector2(length, 1.0), Vector2(length, 3.0), Vector2(0.0, 3.0)
		]
		_emit(surface, corners, uvs, normal, tangent, uv2, color)
	for end in 2:
		if not peak[2 + end]:
			continue
		var at: Vector2 = from if end == 0 else to
		var out := -way if end == 0 else way
		var corners: Array[Vector3] = [
			floor + Vector3(at.x + across.x, base, at.y + across.y),
			floor + Vector3(at.x, ridge, at.y),
			floor + Vector3(at.x - across.x, base, at.y - across.y),
		]
		var uvs: Array[Vector2] = [Vector2(0.0, 3.0), Vector2(2.0, 1.0), Vector2(4.0, 3.0)]
		var normal := Vector3(out.x, 0.0, out.y)
		_emit(surface, corners, uvs, normal, Vector3(-out.y, 0.0, out.x), uv2, color)


## Adds a quad or a triangle (3 corners) facing `normal` (its corners
## turned the way the face meshes are: clockwise seen from the front).
static func _emit(
	surface: ChunkMesher.Surface,
	corners: Array[Vector3],
	uvs: Array[Vector2],
	normal: Vector3,
	tangent: Vector3,
	uv2: Vector2,
	color: Color
) -> void:
	var turn := (corners[1] - corners[0]).cross(corners[2] - corners[0])
	if turn.dot(normal) > 0.0:
		corners.reverse()
		uvs.reverse()
	if corners.size() == 3:
		corners.append(corners[2])
		uvs.append(uvs[2])
	surface.quad(corners, uvs, normal, tangent, uv2, color)
