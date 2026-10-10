class_name ShapedFaces
extends RefCounted
## The faces of stairs and slabs (ShapedBlocks) for ChunkMesher: each
## filled octant's faces that show (not against another of its octants, a
## cube, or a filled octant of the stairs or slab next door), half-cell
## quads in the terrain's face meshes (terrain3d_faces.gdshader). Their
## sides wear the material's face texture as a cube's sides would (the
## same pixels where the octant lies), their tops its top texture (UV2.y
## TOP_FACE: the shader reads the wall atlas), their bottoms its face
## texture as undersides do. Thread-safe: only reads what it is given.

## UV2.y of a top (a cube's side has its lip ground + 1, at least 0).
const TOP_FACE := -2.0
const SIZE := GameConst.CHUNK_SIZE
const SPAN := SIZE + 2
const HEIGHT := GameConst.WORLD_HEIGHT
const SEA := GameConst.SEA_LEVEL
const PX := 16.0
## The six ways out of an octant: x, y, z.
const OUT: Array[Vector3i] = [
	Vector3i(1, 0, 0),
	Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0),
	Vector3i(0, -1, 0),
	Vector3i(0, 0, 1),
	Vector3i(0, 0, -1),
]


## Adds the faces of the stairs or slab at (lx, y, lz) of a chunk being
## built (ChunkMesher.build: its padded `voxels`, `tops`, `tables` and
## `column`) to its face meshes (in a cave: the deep ones), lit by the sky
## light in its cell.
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
	var light := ChunkMesher.sky_level(tables, index) / float(LightField.MAX)
	var block := Voxels.block_of(voxels[index])
	var kind := kinds[Voxels.of_block(ShapedBlocks.material_of(block))]
	var part := ChunkMesher.Part.DEEP_FACES if deep else ChunkMesher.Part.FACES
	add(result.parts[part], voxels, flags, kind, lx, y, lz, Color(variant, 0.0, light))


## Adds the faces of the stairs or slab at (lx, y, lz) of a chunk (padded
## `voxels`, see ChunkMesher.pad_voxels) to `surface`; `kind` the face kind
## of its material, `color` (variant, -, sky light) as a cube side's.
static func add(
	surface: ChunkMesher.Surface,
	voxels: PackedInt32Array,
	flags: PackedByteArray,
	kind: int,
	lx: int,
	y: int,
	lz: int,
	color: Color
) -> void:
	var at := func(cell: Vector3i) -> int: return voxel_at(voxels, cell)
	var cell := Vector3i(lx, y, lz)
	var block := Voxels.block_of(voxel_at(voxels, cell))
	var mask := ShapedBlocks.mask(block, cell, at)
	for octant in 8:
		if mask & (1 << octant) == 0:
			continue
		var o := Vector3i(octant & 1, (octant >> 2) & 1, (octant >> 1) & 1)
		for out in OUT:
			var next := o + out
			var inside := next.x >= 0 and next.x <= 1 and next.y >= 0 and next.y <= 1
			inside = inside and next.z >= 0 and next.z <= 1
			if inside:
				if mask & _bit(next) != 0:
					continue
			elif _covered(voxels, flags, cell + out, Vector3i(next.x & 1, next.y & 1, next.z & 1)):
				continue
			_face(surface, cell, o, out, kind, color)


## A voxel of the padded chunk at chunk cell (x, row, z) (AIR outside).
static func voxel_at(voxels: PackedInt32Array, cell: Vector3i) -> int:
	if cell.x < -1 or cell.x > SIZE or cell.z < -1 or cell.z > SIZE:
		return Voxels.AIR
	if cell.y < 0 or cell.y >= HEIGHT:
		return Voxels.AIR
	return voxels[((cell.z + 1) * SPAN + cell.x + 1) * HEIGHT + cell.y]


static func _bit(o: Vector3i) -> int:
	return 1 << (o.x + o.z * 2 + o.y * 4)


## Whether the octant `o` of the cell next door hides a face against it:
## a cube, or a filled octant of stairs or a slab.
static func _covered(
	voxels: PackedInt32Array, flags: PackedByteArray, cell: Vector3i, o: Vector3i
) -> bool:
	var voxel := voxel_at(voxels, cell)
	if flags[voxel] & Voxels.FLAG_CUBE != 0:
		return true
	if flags[voxel] & Voxels.FLAG_SHAPED == 0:
		return false
	var at := func(other: Vector3i) -> int: return voxel_at(voxels, other)
	return ShapedBlocks.mask(Voxels.block_of(voxel), cell, at) & _bit(o) != 0


## The face of octant `o` of `cell` looking `out`.
static func _face(
	surface: ChunkMesher.Surface,
	cell: Vector3i,
	o: Vector3i,
	out: Vector3i,
	kind: int,
	color: Color
) -> void:
	var low := Vector3(cell.x, cell.y - SEA, cell.z) + Vector3(o) * 0.5
	var high := low + Vector3.ONE * 0.5
	var floor_y := float(cell.y - SEA)
	if out.y != 0:
		var y := high.y if out.y > 0 else low.y
		var corners: Array[Vector3] = [
			Vector3(low.x, y, low.z),
			Vector3(high.x, y, low.z),
			Vector3(high.x, y, high.z),
			Vector3(low.x, y, high.z),
		]
		if out.y < 0:
			corners = [
				Vector3(low.x, y, high.z),
				Vector3(high.x, y, high.z),
				Vector3(high.x, y, low.z),
				Vector3(low.x, y, low.z),
			]
		var texels: Array[Vector2] = []
		for corner in corners:
			texels.append(Vector2(corner.x - cell.x, corner.z - cell.z) * PX)
		var top := Vector2(kind, TOP_FACE if out.y > 0 else 0.0)
		surface.quad(corners, texels, Vector3(out), Vector3.RIGHT, top, color)
		return
	# A side: from `a` to `b` as seen from out there (as ChunkMesher's).
	var a: Vector2
	var b: Vector2
	var edge: float
	if out.z > 0:
		a = Vector2(low.x, high.z)
		b = Vector2(high.x, high.z)
		edge = low.x - cell.x
	elif out.z < 0:
		a = Vector2(high.x, low.z)
		b = Vector2(low.x, low.z)
		edge = cell.x + 1 - high.x
	elif out.x > 0:
		a = Vector2(high.x, high.z)
		b = Vector2(high.x, low.z)
		edge = cell.z + 1 - high.z
	else:
		a = Vector2(low.x, low.z)
		b = Vector2(low.x, high.z)
		edge = low.z - cell.z
	var corners: Array[Vector3] = [
		Vector3(a.x, high.y, a.y),
		Vector3(b.x, high.y, b.y),
		Vector3(b.x, low.y, b.y),
		Vector3(a.x, low.y, a.y),
	]
	var down := (floor_y + 1.0 - high.y) * PX
	var uvs: Array[Vector2] = [
		Vector2(edge * PX, down),
		Vector2((edge + 0.5) * PX, down),
		Vector2((edge + 0.5) * PX, down + 0.5 * PX),
		Vector2(edge * PX, down + 0.5 * PX),
	]
	var along := b - a
	var tangent := Vector3(along.x, 0.0, along.y).normalized()
	var normal := Vector3(-tangent.z, 0.0, tangent.x)
	surface.quad(corners, uvs, normal, tangent, Vector2(kind, 0.0), color)
