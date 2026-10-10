class_name GlassFaces
extends RefCounted
## The faces of glass (Glass) for ChunkMesher, each drawn twice: in the
## face meshes the pixels of its art that are opaque (a window's frame, the
## lead, a border, old glass's bubbles: terrain3d_faces.gdshader, UV2.y
## under FRAME_PASS), and in the glass meshes (ChunkMesher.Part.GLASS,
## glass.gdshader) the clear ones, see-through and tinted. A face shows
## unless against a cube or the same glass in the same tint; side by side,
## clear, old and leaded glass lose the border between them (`edges`:
## which of the face's edges go on). Panes are thin glass across the
## middle of their cell, joining their neighbors (Glass.pane_sides). UV:
## the face's pixels (u along it, v down from its top; on tops and
## bottoms x and z), as a cube's sides and tops. Thread-safe.

## UV2.y of the opaque pass: FRAME_PASS - (edges + 16 if a top or bottom
## + 32 x (the frame's tint + 1) + TINTED_SHADOW if the glass is tinted).
const FRAME_PASS := -10.0
## Added to the opaque pass's bits when the glass is tinted: in the shadow
## pass it keeps its clear pixels too (the sun's white light stays out;
## glass_light.gdshaderinc brings it in, colored).
const TINTED_SHADOW := 1024
## UV2.y of the glass pass: edges + 16 if a top or bottom + 32 x (the
## glass's tint + 1) + 1024 x its style.
const STYLE_STEP := 1024
const SIZE := GameConst.CHUNK_SIZE
const HEIGHT := GameConst.WORLD_HEIGHT
const SEA := GameConst.SEA_LEVEL
const PX := 16.0
## A pane's thickness, from the middle of its cell (tiles).
const PANE_HALF := 1.0 / 16.0
## Edge bits: v's start (top), v's end, u's start, u's end.
const V_START := 1
const V_END := 2
const U_START := 4
const U_END := 8


## Adds the faces of the glass cube at (lx, y, lz) of a chunk being built
## (ChunkMesher.build's padded `voxels`, `tops`, `tables`, `column`).
static func build_cube(
	result: ChunkMesher.Result,
	job: ChunkJob,
	voxels: PackedInt32Array,
	tops: PackedByteArray,
	tables: Array,
	column: int,
	lx: int,
	y: int,
	lz: int
) -> void:
	var context := _context(result, job, voxels, tops, tables, column, lx, y, lz)
	var cell := Vector3i(lx, y, lz)
	var voxel: int = context["voxel"]
	for out: Vector3i in ShapedFaces.OUT:
		var next := ShapedFaces.voxel_at(voxels, cell + out)
		if (
			_hides(tables[0], next)
			or (next == voxel and _tint(context, cell + out) == context["tint"])
		):
			continue
		var low := Vector3(cell.x, cell.y - SEA, cell.z)
		_face(context, low, low + Vector3.ONE, out, _edges(context, cell, out))


## Adds the faces of the pane at (lx, y, lz): its arms to the sides it
## joins (or across the way it faces, alone).
static func build_pane(
	result: ChunkMesher.Result,
	job: ChunkJob,
	voxels: PackedInt32Array,
	tops: PackedByteArray,
	tables: Array,
	column: int,
	lx: int,
	y: int,
	lz: int
) -> void:
	var context := _context(result, job, voxels, tops, tables, column, lx, y, lz)
	var cell := Vector3i(lx, y, lz)
	var voxel: int = context["voxel"]
	var block := Voxels.block_of(voxel)
	var at := func(other: Vector3i) -> int: return ShapedFaces.voxel_at(voxels, other)
	var sides := Glass.pane_sides(block, cell, at)
	var floor_y := float(y - SEA)
	for axis in 2:
		var low_way := 3 if axis == 0 else 0
		var high_way := 1 if axis == 0 else 2
		var joins_low := sides & (1 << low_way) != 0
		var joins_high := sides & (1 << high_way) != 0
		if not joins_low and not joins_high:
			continue
		var from := 0.0 if joins_low else 0.5 - PANE_HALF
		var to := 1.0 if joins_high else 0.5 + PANE_HALF
		var low := Vector3(lx, floor_y, lz)
		var high := Vector3(lx, floor_y + 1.0, lz)
		if axis == 0:
			low += Vector3(from, 0.0, 0.5 - PANE_HALF)
			high += Vector3(to, 0.0, 0.5 + PANE_HALF)
		else:
			low += Vector3(0.5 - PANE_HALF, 0.0, from)
			high += Vector3(0.5 + PANE_HALF, 0.0, to)
		for out: Vector3i in ShapedFaces.OUT:
			var along := out.x != 0 if axis == 0 else out.z != 0
			var ends_low := (out.x < 0 if axis == 0 else out.z < 0) and joins_low
			var ends_high := (out.x > 0 if axis == 0 else out.z > 0) and joins_high
			if along and (ends_low or ends_high):
				continue
			if out.y != 0:
				var next := ShapedFaces.voxel_at(voxels, cell + out)
				if _hides(tables[0], next) or Glass.is_pane(Voxels.block_of(next)):
					continue
			var edges := 0
			if out.y == 0 and not along:
				edges = _pane_edges(context, cell, out, sides)
			_face(context, low, high, out, edges, not along and out.y == 0)


## What a build of a glass block needs (see build_cube).
static func _context(
	result: ChunkMesher.Result,
	job: ChunkJob,
	voxels: PackedInt32Array,
	tops: PackedByteArray,
	tables: Array,
	column: int,
	lx: int,
	y: int,
	lz: int
) -> Dictionary:
	var flags: PackedByteArray = tables[0]
	var kinds: PackedInt32Array = tables[1]
	var index := column * HEIGHT + y
	var rows := tops[column] - y
	var deep := rows > 1 and not ChunkMesher.sky_through(voxels, flags, tables[3], index, rows)
	var voxel := voxels[index]
	var block := Voxels.block_of(voxel)
	var art := Glass.pane_glass(block) if Glass.is_pane(block) else block
	var origin := Coords.chunk_origin_tile(job.coord)
	var cell := Vector3i(origin.x + lx, y, origin.y + lz)
	var tint: int = job.tints.get(cell, 0)
	var light := ChunkMesher.sky_level(tables, index) / float(LightField.MAX)
	return {
		"frames": result.parts[ChunkMesher.Part.DEEP_FACES if deep else ChunkMesher.Part.FACES],
		"glass": result.parts[ChunkMesher.Part.DEEP_GLASS if deep else ChunkMesher.Part.GLASS],
		"voxel": voxel,
		"padded": voxels,
		"kind": kinds[Voxels.of_block(art)],
		"style": Glass.style_of(block),
		"tint": tint,
		"tints": job.tints,
		"origin": origin,
		"color": Color(0.0, 0.0, light),
	}


## The tint of a chunk cell (x, row, z) in the build.
static func _tint(context: Dictionary, cell: Vector3i) -> int:
	var origin: Vector2i = context["origin"]
	return context["tints"].get(Vector3i(origin.x + cell.x, cell.y, origin.y + cell.z), 0)


## What hides a glass face: a cube (not glass).
static func _hides(flags: PackedByteArray, voxel: int) -> bool:
	return flags[voxel] & Voxels.FLAG_CUBE != 0


## Which edges of a cube's face looking `out` go on into the same glass in
## the same tint (clear, old, leaded glass: no border there).
static func _edges(context: Dictionary, cell: Vector3i, out: Vector3i) -> int:
	if context["style"] == Glass.Style.FRAMED:
		return 0
	var u: Vector3i
	var v: Vector3i
	if out.y != 0:
		u = Vector3i(1, 0, 0)
		v = Vector3i(0, 0, 1)
	else:
		u = Vector3i(out.z, 0, -out.x)
		v = Vector3i.DOWN
	var edges := 0
	var bits := [[-v, V_START], [v, V_END], [-u, U_START], [u, U_END]]
	for pair: Array in bits:
		if _same(context, cell + pair[0]):
			edges |= pair[1]
	return edges


## Which edges of a pane's broad side go on: into the same pane above or
## below, into the same pane it joins.
static func _pane_edges(context: Dictionary, cell: Vector3i, out: Vector3i, sides: int) -> int:
	if context["style"] == Glass.Style.FRAMED:
		return 0
	var edges := 0
	if _same(context, cell + Vector3i.UP):
		edges |= V_START
	if _same(context, cell + Vector3i.DOWN):
		edges |= V_END
	var u := Vector3i(out.z, 0, -out.x)
	for pair: Array in [[-u, U_START], [u, U_END]]:
		var way: Vector3i = pair[0]
		var bit := Glass.SIDES.find(Vector2i(way.x, way.z))
		if sides & (1 << bit) != 0 and _same(context, cell + way):
			edges |= pair[1]
	return edges


## Whether a cell holds the same glass as the one being built, tinted
## alike (a pane: a pane of its style, any way).
static func _same(context: Dictionary, cell: Vector3i) -> bool:
	var voxel: int = context["voxel"]
	var other := ShapedFaces.voxel_at(context["padded"], cell)
	if other != voxel:
		var block := Voxels.block_of(other)
		var panes := Glass.is_pane(block) and Glass.is_pane(Voxels.block_of(voxel))
		if not panes or Glass.style_of(block) != context["style"]:
			return false
	return _tint(context, cell) == context["tint"]


## A face of the box low..high (local units) looking `out`, in both passes;
## `broad`: a pane's side (else a thin edge of it: all border).
static func _face(
	context: Dictionary, low: Vector3, high: Vector3, out: Vector3i, edges: int, broad := true
) -> void:
	var base := Vector3(floorf(low.x), floorf(low.y + 0.001), floorf(low.z))
	var corners: Array[Vector3]
	var uvs: Array[Vector2] = []
	var tangent := Vector3.RIGHT
	var flat := out.y != 0
	if flat:
		var y := high.y if out.y > 0 else low.y
		corners = [
			Vector3(low.x, y, low.z),
			Vector3(high.x, y, low.z),
			Vector3(high.x, y, high.z),
			Vector3(low.x, y, high.z),
		]
		if out.y < 0:
			corners = [corners[3], corners[2], corners[1], corners[0]]
		for corner in corners:
			uvs.append(Vector2(corner.x - base.x, corner.z - base.z) * PX)
	else:
		var a: Vector2
		var b: Vector2
		if out.z > 0:
			a = Vector2(low.x, high.z)
			b = Vector2(high.x, high.z)
		elif out.z < 0:
			a = Vector2(high.x, low.z)
			b = Vector2(low.x, low.z)
		elif out.x > 0:
			a = Vector2(high.x, high.z)
			b = Vector2(high.x, low.z)
		else:
			a = Vector2(low.x, low.z)
			b = Vector2(low.x, high.z)
		corners = [
			Vector3(a.x, high.y, a.y),
			Vector3(b.x, high.y, b.y),
			Vector3(b.x, low.y, b.y),
			Vector3(a.x, low.y, a.y),
		]
		var along := Vector2(b - a).normalized()
		var start := _along(base, a, along)
		var end := start + (b - a).length() * PX
		var top := (base.y + 1.0 - high.y) * PX
		var bottom := (base.y + 1.0 - low.y) * PX
		uvs = [Vector2(start, top), Vector2(end, top), Vector2(end, bottom), Vector2(start, bottom)]
		tangent = Vector3(along.x, 0.0, along.y)
	if not broad:
		# A pane's thin edge: its border's pixels all along.
		for i in uvs.size():
			uvs[i] = Vector2(0.5, uvs[i].y) if not flat else Vector2(0.5, 0.5)
	var bits := edges + (16 if flat else 0)
	var kind: int = context["kind"]
	var frame := Tints.frame_of(context["tint"])
	var glass := Tints.glass_of(context["tint"])
	var color: Color = context["color"]
	var normal := Vector3(out)
	var frames: ChunkMesher.Surface = context["frames"]
	# Tinted glass: its frame pass casts its whole shadow (TINTED_SHADOW).
	var shadow := TINTED_SHADOW if glass >= 0 else 0
	var frame_info := FRAME_PASS - bits - 32 * (frame + 1) - shadow
	frames.quad(corners, uvs, normal, tangent, Vector2(kind, frame_info), color)
	var panes: ChunkMesher.Surface = context["glass"]
	var info := bits + 32 * (glass + 1) + STYLE_STEP * int(context["style"])
	panes.quad(corners, uvs, normal, tangent, Vector2(kind, info), color)


## How far (pixels) along a cell's side, from the corner its texture
## starts at, point `a` lies (the side `along` runs).
static func _along(base: Vector3, a: Vector2, along: Vector2) -> float:
	if along.x > 0.5:
		return (a.x - base.x) * PX
	if along.x < -0.5:
		return (base.x + 1.0 - a.x) * PX
	if along.y > 0.5:
		return (a.y - base.z) * PX
	return (base.z + 1.0 - a.y) * PX
