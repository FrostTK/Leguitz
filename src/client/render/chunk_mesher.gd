class_name ChunkMesher
extends RefCounted
## Builds the 3D terrain of a chunk from its voxels, in local units (see
## Render3D), on a worker thread. Everything it reads is in its Job.
##
## Surfaces (see Part):
## - tops: the top of every cube or lava voxel open to the air above, or
##   under clear water (lake beds), drawn by the top shader (organic ground
##   transitions...),
## - faces: the sides of cubes open to the air or to clear water (vertical
##   runs of the same material share one quad), and their undersides,
## - water: the surface of clear water (the ground under it shows through),
## each split into what can be seen from the sky (also through water,
## glass, or a building's roof: a house shows its rooms through its windows
## and doors) and what lies deeper, under rock (caves), shown only when the
## view cuts the world above the player.
## Undersides are never seen from the camera (it always looks down) but
## close the rock: seen from behind through the cut, they draw its section.
## Where the view cuts the world (`cut_row`), building blocks cut through
## (TileAtlas.BUILDING_WALLS) get a cap: their top at the cut (Part.CAPS,
## also in surface-map-only builds), so walls cut under a roof read as
## walls; natural rock shows its section in dark.
## Cubes one sees through (glass, TileAtlas.CLEAR_WALLS) draw their faces
## like the others (the shaders cut out their clear pixels) and do not hide
## the faces of their neighbors, but two of the same hide each other's.
## Also gathers the props (trees, plants... in object voxels), the lava
## spots that light their surroundings, and the surface map of the top
## shader (see surface_map).

enum Part { TOPS, FACES, DEEP_TOPS, DEEP_FACES, WATER, DEEP_WATER, CAPS }
enum Side { NORTH, EAST, SOUTH, WEST }

const SIZE := GameConst.CHUNK_SIZE
const SPAN := SIZE + 2
const HEIGHT := GameConst.WORLD_HEIGHT
const SEA := GameConst.SEA_LEVEL
## Strides in the padded voxels (see pad).
const STRIDE_X := HEIGHT
const STRIDE_Z := SPAN * HEIGHT
## Face texture pixels per local unit of height (one level = 16 px).
const FACE_PX_PER_UNIT := 16.0 / Render3D.LEVEL_HEIGHT
## Face kinds: cliff materials first, then wall kinds.
const WALL_KIND_OFFSET := 4
## Top material codes: grounds, then WALL_CODE + wall kind.
const WALL_CODE := 64
## Surface map level of a column with nothing below the cut.
const NO_LEVEL := -1000.0
## Lava lights are placed per 8x8 quarter of the chunk.
const LAVA_QUARTER := 8
## How bright a lit furnace's light is (lava's: 0.8 to 2.2).
const FIRE_LIGHT := 0.75

const CUBE := Voxels.FLAG_CUBE
const LIQUID := Voxels.FLAG_LIQUID
const TERRAIN := CUBE | LIQUID
## Flag of the cubes one sees through (instead of CUBE, see _build_flags).
const CLEAR_CUBE := 8
const ANY_CUBE := CUBE | CLEAR_CUBE
## Flag of the building blocks (TileAtlas.BUILDING_WALLS): roofs and floors
## of these never make what is under them a cave.
const BUILT := 16
## Natural cubes in a row over a face that make it a cave's (one is a roof
## a player made: caves keep two rows of rock over them, CaveGenerator.ROOF).
const THICK_COVER := 2

## Horizontal faces are gathered per row of the chunk before being merged
## into rectangles: tops, or undersides (see _record_flat).
const FLAT_UNDERSIDE := 1

## Face kind and top material code of every voxel id (see face_kind), and
## 1 for the liquids the eye sees through (water, not lava).
static var _face_kinds := _build_face_kinds()
static var _top_codes := _build_top_codes()
static var _clear := _build_clear()
## Voxels.flag_table() for meshing: see-through cubes are CLEAR_CUBE.
static var _flags := _build_flags()
## 1 for the building blocks capped at the view's cut.
static var _capped := _build_capped()


## What a build reads: the voxels and column tops of the chunk and of its
## 8 neighbors (3 x 3, row by row; empty arrays where not loaded).
class Job:
	extends RefCounted
	var coord := Vector2i.ZERO
	var voxels: Array[PackedInt32Array] = []
	var tops: Array[PackedByteArray] = []
	## The chunk's columns where something rises over the terrain (see
	## ChunkData.raised).
	var raised: Dictionary[int, int] = {}
	## Model variants per block (0 = not a prop), see PropLibrary.
	var variants := PackedByteArray()
	## Row the view cuts the world at (HEIGHT: no cut), for the surface map,
	## and the columns it cuts (chunk and border, SPAN x SPAN, 1 where it
	## does; empty: all, see CutRegion.columns_of).
	var cut_row := HEIGHT
	var cut_columns := PackedByteArray()
	## Surface map only (the cut moved): no geometry.
	var map_only := false
	## Bumped by every new build of the chunk: older results are dropped.
	var serial := 0

	static func of_chunk(chunk: ChunkData, neighbor: Callable) -> Job:
		var job := Job.new()
		job.coord = chunk.coord
		job.raised = chunk.raised.duplicate()
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var other: ChunkData = (
					chunk if dx == 0 and dz == 0 else neighbor.call(chunk.coord + Vector2i(dx, dz))
				)
				job.voxels.append(other.voxels if other != null else PackedInt32Array())
				job.tops.append(other.tops if other != null else PackedByteArray())
		return job


## What a build produces.
class Result:
	extends RefCounted
	var coord := Vector2i.ZERO
	var serial := 0
	var map_only := false
	var parts: Array[Surface] = []
	## (block, variant) -> [[Transform3D, Color], ...]
	var props: Dictionary[Vector2i, Array] = {}
	## Lava lights (and lit furnaces'): local position, whether they are in
	## a cave, how bright.
	var lava_spots: Array[Vector3] = []
	var lava_deep: Array[bool] = []
	var lava_strength: Array[float] = []
	var surface_map := PackedFloat32Array()


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
			tangents.append(tangent.x)
			tangents.append(tangent.y)
			tangents.append(tangent.z)
			tangents.append(1.0)
			uvs.append(quad_uvs[i])
			uv2s.append(uv2)
			colors.append(color)
		indices.append(start)
		indices.append(start + 1)
		indices.append(start + 2)
		indices.append(start)
		indices.append(start + 2)
		indices.append(start + 3)

	func quad_count() -> int:
		return vertices.size() / 4

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


## Builds a chunk (thread-safe: only reads the job).
static func build(job: Job) -> Result:
	var result := Result.new()
	result.coord = job.coord
	result.serial = job.serial
	result.map_only = job.map_only
	var voxels := pad_voxels(job.voxels)
	var tops := pad(job.tops, 1)
	var clear := _clear.duplicate()
	result.surface_map = surface_map(voxels, tops, job.cut_row, clear, job.cut_columns)
	for part in Part.size():
		result.parts.append(Surface.new())
	if job.map_only:
		var cap_flats := {}
		_record_caps(cap_flats, voxels, job.cut_row, job.cut_columns)
		_add_flats(result, cap_flats)
		return result
	var origin := Coords.chunk_origin_tile(job.coord)
	var lava_sums: Array[Vector3] = []
	var lava_counts := PackedInt32Array()
	lava_sums.resize(8)
	lava_counts.resize(8)
	# Local copies of the tables: shared statics are slow in tight loops,
	# more so on several threads.
	var flags := _flags.duplicate()
	var kinds := _face_kinds.duplicate()
	var codes := _top_codes.duplicate()
	var tables := [flags, kinds, codes, clear]
	# Horizontal faces of the chunk, merged at the end: see _record_flat.
	var flats := {}
	for lz in SIZE:
		for lx in SIZE:
			var column := (lz + 1) * SPAN + (lx + 1)
			var base := column * HEIGHT
			var last := mini(maxi(tops[column] + 1, job.raised.get(lz * SIZE + lx, 0)), HEIGHT)
			for y in last:
				var index := base + y
				var voxel := voxels[index]
				if voxel == Voxels.AIR:
					continue
				var flag := flags[voxel]
				if flag & ANY_CUBE != 0:
					# Most cubes are buried: cubes all around, nothing to draw.
					if (
						y > 0
						and y + 1 < HEIGHT
						and flags[voxels[index + 1]] & CUBE != 0
						and flags[voxels[index - 1]] & CUBE != 0
						and flags[voxels[index + STRIDE_X]] & CUBE != 0
						and flags[voxels[index - STRIDE_X]] & CUBE != 0
						and flags[voxels[index + STRIDE_Z]] & CUBE != 0
						and flags[voxels[index - STRIDE_Z]] & CUBE != 0
					):
						continue
					_add_cube(result, flats, voxels, tops, tables, column, lx, y, lz, origin)
				elif flag & LIQUID != 0:
					var above := voxels[base + y + 1] if y + 1 < HEIGHT else Voxels.AIR
					if flags[above] & TERRAIN != 0:
						continue
					var rows := tops[column] - y
					var deep := rows > 1 and not _sky_through(voxels, flags, clear, base + y, rows)
					var part := Part.DEEP_TOPS if deep else Part.TOPS
					if clear[voxel] != 0:
						part = Part.DEEP_WATER if deep else Part.WATER
					_record_flat(flats, y, voxel, part, 0, lx, lz)
					if voxel == Voxels.of_ground(Tiles.Ground.LAVA):
						var quarter := (
							(lz / LAVA_QUARTER) * 2 + lx / LAVA_QUARTER + (4 if deep else 0)
						)
						lava_sums[quarter] += Vector3(lx + 0.5, y + 2 - SEA, lz + 0.5)
						lava_counts[quarter] += 1
				else:
					_add_prop(result, job.variants, voxel, voxels, base, lx, y, lz, origin)
					var block := Voxels.block_of(voxel)
					if ObjectShapes.is_lit(block):
						# The fire shines out of the furnace's front.
						var front := Vector2(ObjectShapes.front_of(block)) * 0.9
						var fire := Vector3(lx + 0.5 + front.x, y - SEA + 0.5, lz + 0.5 + front.y)
						result.lava_spots.append(fire)
						var rows := tops[column] - y
						result.lava_deep.append(
							rows > 1 and not _sky_through(voxels, flags, clear, base + y, rows)
						)
						result.lava_strength.append(FIRE_LIGHT)
	_record_caps(flats, voxels, job.cut_row, job.cut_columns)
	_add_flats(result, flats)
	_add_world_bottom(result.parts[Part.DEEP_FACES])
	for quarter in 8:
		if lava_counts[quarter] >= 3:
			result.lava_spots.append(lava_sums[quarter] / lava_counts[quarter])
			result.lava_deep.append(quarter >= 4)
			result.lava_strength.append(clampf(0.8 + lava_counts[quarter] * 0.05, 0.8, 2.2))
	return result


## The chunk's arrays (`stride` bytes per column) plus a one-column border
## taken from its neighbors; missing neighbors repeat the chunk's own edge,
## so no false faces appear (the chunk is rebuilt when they come).
static func pad(arrays: Array[PackedByteArray], stride: int) -> PackedByteArray:
	var padded := PackedByteArray()
	var empty := arrays.map(_is_empty)
	for pz in SPAN:
		for px in SPAN:
			var from := _border_column(px, pz, empty)
			var start := from.y * stride
			padded.append_array(arrays[from.x].slice(start, start + stride))
	return padded


## The chunk's voxels plus a one-column border, as pad does.
static func pad_voxels(arrays: Array[PackedInt32Array]) -> PackedInt32Array:
	var padded := PackedInt32Array()
	var empty := arrays.map(_is_empty)
	for pz in SPAN:
		for px in SPAN:
			var from := _border_column(px, pz, empty)
			var start := from.y * HEIGHT
			padded.append_array(arrays[from.x].slice(start, start + HEIGHT))
	return padded


## Where a padded column (px, pz) comes from: x the array (of the 3 x 3,
## row by row; a missing neighbor gives way to the chunk itself, 4), y the
## column in it (`empty`: which arrays are missing).
static func _border_column(px: int, pz: int, empty: Array) -> Vector2i:
	var lx := px - 1
	var lz := pz - 1
	var ox := -1 if lx < 0 else (1 if lx >= SIZE else 0)
	var oz := -1 if lz < 0 else (1 if lz >= SIZE else 0)
	var source := (oz + 1) * 3 + ox + 1
	if empty[source]:
		source = 4
		lx = clampi(lx, 0, SIZE - 1)
		lz = clampi(lz, 0, SIZE - 1)
	else:
		lx = posmod(lx, SIZE)
		lz = posmod(lz, SIZE)
	return Vector2i(source, lz * SIZE + lx)


static func _is_empty(array: Variant) -> bool:
	return array.is_empty()


## The 18 x 18 data of the top and water shaders (RGBA floats per column,
## chunk plus border): ground id, wall kind + 1, level of the highest top
## below the cut (NO_LEVEL if none), and if that top is clear water, the
## bed under it (see bed_code), else 0. Tops at that level blend with their
## neighbors, beds with the beds around; other tops (hidden ledges) are
## drawn plainly. `clear`: see _build_clear; `cut_columns`: the columns
## the cut reaches (see Job; empty: all).
static func surface_map(
	voxels: PackedInt32Array,
	tops: PackedByteArray,
	cut_row: int,
	clear: PackedByteArray,
	cut_columns := PackedByteArray()
) -> PackedFloat32Array:
	var values := PackedFloat32Array()
	values.resize(SPAN * SPAN * 4)
	var every_column := cut_columns.is_empty()
	for column in SPAN * SPAN:
		var base := column * HEIGHT
		var out := column * 4
		values[out + 2] = NO_LEVEL
		var start := tops[column] - 1
		if every_column or cut_columns[column] != 0:
			start = mini(cut_row, tops[column]) - 1
		for y in range(start, -1, -1):
			var voxel := voxels[base + y]
			if not Voxels.is_cube(voxel) and not Voxels.is_liquid(voxel):
				continue
			values[out] = Voxels.ground_of(voxel)
			values[out + 1] = TileAtlas.wall_lookup[Voxels.block_of(voxel)]
			values[out + 2] = y + 1 - SEA
			if clear[voxel] != 0:
				var row := y - 1
				while row >= 0 and clear[voxels[base + row]] != 0:
					row -= 1
				if row >= 0 and Voxels.is_cube(voxels[base + row]):
					values[out + 3] = bed_code(voxels[base + row], row + 1 - SEA)
			break
	return values


## A bed under water for the shaders: its ground, wall kind + 1 and level
## in one exact float (see bed_of in terrain3d_surface.gdshaderinc).
static func bed_code(voxel: int, level: int) -> float:
	var wall: int = TileAtlas.wall_lookup[Voxels.block_of(voxel)]
	return float(((level + 256) * 64 + Voxels.ground_of(voxel)) * 256 + wall)


## How an object's model is turned on a tile (quarter turns).
static func prop_turn(tile: Vector2i) -> Basis:
	var h := HashUtil.hash2(ObjectShapes.SALT, tile.x, tile.y)
	return Basis(Vector3.UP, ((h >> 4) & 3) * PI * 0.5)


## Ground texture variant of a tile, as the top shader picks it
## (ground_atlas_pos in terrain3d_common.gdshaderinc).
static func ground_variant(tile: Vector2i) -> int:
	var qx := (tile.x + 16777216) & 0xFFFFFFFF
	var qy := (tile.y + 16777216) & 0xFFFFFFFF
	var h := (qx * 374761393 + qy * 668265263) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	h = h ^ (h >> 16)
	return h & 3


## Face kind of a cube voxel's sides (see the face atlas).
static func face_kind(voxel: int) -> int:
	return _face_kinds[voxel]


## Top material code of a cube or liquid voxel (see the top shader).
static func top_code(voxel: int) -> int:
	return _top_codes[voxel]


static func _build_face_kinds() -> PackedInt32Array:
	var kinds := PackedInt32Array()
	kinds.resize(Voxels.used_ids())
	for voxel in Voxels.used_ids():
		var block := Voxels.block_of(voxel)
		if TileAtlas.is_wall(block):
			kinds[voxel] = WALL_KIND_OFFSET + TileAtlas.WALL_KINDS[block]
		else:
			kinds[voxel] = TerrainRenderer.cliff_material(Voxels.ground_of(voxel))
	return kinds


static func _build_flags() -> PackedByteArray:
	var flags := Voxels.flag_table().slice(0, Voxels.used_ids())
	for block: int in TileAtlas.CLEAR_WALLS:
		var voxel := Voxels.of_block(block)
		flags[voxel] = (flags[voxel] & ~CUBE) | CLEAR_CUBE
	for block: int in TileAtlas.BUILDING_WALLS:
		flags[Voxels.of_block(block)] |= BUILT
	return flags


## Caps the building blocks just under the cut whose column goes on above
## it (they have no top of their own there), where the cut reaches.
static func _record_caps(
	flats: Dictionary, voxels: PackedInt32Array, cut_row: int, cut_columns: PackedByteArray
) -> void:
	var row := cut_row - 1
	if row < 0 or cut_row >= HEIGHT:
		return
	var capped := _capped
	var flags := _flags
	var every_column := cut_columns.is_empty()
	for lz in SIZE:
		for lx in SIZE:
			var column := (lz + 1) * SPAN + (lx + 1)
			if not every_column and cut_columns[column] == 0:
				continue
			var index := column * HEIGHT + row
			var voxel := voxels[index]
			if capped[voxel] != 0 and flags[voxels[index + 1]] & ANY_CUBE != 0:
				_record_flat(flats, row, _top_codes[voxel], Part.CAPS, 0, lx, lz)


static func _build_capped() -> PackedByteArray:
	var table := PackedByteArray()
	table.resize(Voxels.used_ids())
	for block: int in TileAtlas.BUILDING_WALLS:
		table[Voxels.of_block(block)] = 1
	return table


static func _build_clear() -> PackedByteArray:
	var table := PackedByteArray()
	table.resize(Voxels.used_ids())
	for ground: int in Tiles.Ground.values():
		if Tiles.is_water(ground):
			table[Voxels.of_ground(ground)] = 1
	return table


static func _build_top_codes() -> PackedInt32Array:
	var codes := PackedInt32Array()
	codes.resize(Voxels.used_ids())
	for voxel in Voxels.used_ids():
		var block := Voxels.block_of(voxel)
		if TileAtlas.is_wall(block):
			codes[voxel] = WALL_CODE + TileAtlas.WALL_KINDS[block]
		else:
			codes[voxel] = Voxels.ground_of(voxel)
	return codes


## Top, sides (merged with the voxels below when they match) and underside
## of a cube voxel. `tables` holds the local [flags, face kinds, top codes,
## clear liquids].
static func _add_cube(
	result: Result,
	flats: Dictionary,
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
	var codes: PackedInt32Array = tables[2]
	var clear: PackedByteArray = tables[3]
	var index := column * HEIGHT + y
	var voxel := voxels[index]
	var above := voxels[index + 1] if y + 1 < HEIGHT else Voxels.AIR
	if _open(flags, clear, above) and above != voxel:
		var rows := tops[column] - y
		var sky := rows <= 1 or _sky_through(voxels, flags, clear, index, rows)
		_record_flat(flats, y, codes[voxel], Part.TOPS if sky else Part.DEEP_TOPS, 0, lx, lz)
	if y > 0 and flags[voxels[index - 1]] & CUBE == 0 and voxels[index - 1] != voxel:
		_record_flat(flats, y, kinds[voxel], Part.DEEP_FACES, FLAT_UNDERSIDE, lx, lz)
	var kind := kinds[voxel]
	for side in 4:
		var dx := 0
		var dz := 0
		match side:
			Side.NORTH:
				dz = -1
			Side.EAST:
				dx = 1
			Side.SOUTH:
				dz = 1
			_:
				dx = -1
		var step := dx * STRIDE_X + dz * STRIDE_Z
		var other := column + dx + dz * SPAN
		var deep := _side_deep(voxels, tops, flags, clear, index, step, other, y)
		if deep < 0:
			continue
		# The run below took this voxel already: same material, open too.
		if (
			y > 0
			and _continues_run(voxels, tops, tables, index - 1, step, other, y - 1, kind, deep)
		):
			continue
		var bottom := y
		var top := y + 1
		while (
			top < HEIGHT
			and _continues_run(voxels, tops, tables, index + top - y, step, other, top, kind, deep)
		):
			top += 1
		var top_voxel := voxels[column * HEIGHT + top - 1]
		var top_above := voxels[column * HEIGHT + top] if top < HEIGHT else Voxels.AIR
		var ground := Voxels.ground_of(top_voxel)
		var lip := 0
		if ground != Tiles.Ground.NONE and _open(flags, clear, top_above):
			lip = ground + 1
		var tile := origin + Vector2i(lx, lz)
		var variant := float(HashUtil.hash2(0xFACE, tile.x * 4 + side, tile.y + bottom * 131) & 1)
		var part := Part.DEEP_FACES if deep == 1 else Part.FACES
		_add_side(
			result.parts[part],
			lx,
			lz,
			side,
			bottom - SEA,
			top - SEA,
			Vector2(kind, lip),
			Color(variant, ground_variant(tile) / 3.0, 0.0)
		)


## Whether a cube's side shows: -1 hidden, 0 seen from the sky (also
## through clear water), 1 in a cave. Sides facing lava only show at its
## surface (the bank above it). `other` is the neighbor column (padded
## index).
static func _side_deep(
	voxels: PackedInt32Array,
	tops: PackedByteArray,
	flags: PackedByteArray,
	clear: PackedByteArray,
	index: int,
	step: int,
	other: int,
	y: int
) -> int:
	var neighbor := voxels[index + step]
	var flag := flags[neighbor]
	if flag & CUBE != 0 or neighbor == voxels[index]:
		return -1
	if clear[neighbor] != 0:
		var rows := tops[other] - y
		return 0 if rows <= 1 or _sky_through(voxels, flags, clear, index + step, rows) else 1
	if flag & LIQUID != 0:
		var above := voxels[index + step + 1] if y + 1 < HEIGHT else Voxels.AIR
		if flags[above] & TERRAIN != 0:
			return -1
		return 0 if y + 1 >= tops[other] else 1
	if y < tops[other] and not _sky_through(voxels, flags, clear, index + step, tops[other] - y):
		return 1
	return 0


## True if the cube at `index` (row `y`) continues a run of side faces of
## `kind` open the `deep` way: same material, side open the same way. A run
## ends at the first voxel open to the sky, whose ground may hang over it
## as a lip.
static func _continues_run(
	voxels: PackedInt32Array,
	tops: PackedByteArray,
	tables: Array,
	index: int,
	step: int,
	other: int,
	y: int,
	kind: int,
	deep: int
) -> bool:
	var flags: PackedByteArray = tables[0]
	var kinds: PackedInt32Array = tables[1]
	var clear: PackedByteArray = tables[3]
	var voxel := voxels[index]
	if flags[voxel] & CUBE == 0 or kinds[voxel] != kind:
		return false
	return _side_deep(voxels, tops, flags, clear, index, step, other, y) == deep


## Whether the eye sees through a voxel from above: air, plants... or
## clear water (not cubes, not lava).
static func _open(flags: PackedByteArray, clear: PackedByteArray, voxel: int) -> bool:
	return flags[voxel] & TERRAIN == 0 or clear[voxel] != 0


## Whether what is at `index` (padded voxels) shows from the sky: the
## `rows` - 1 voxels above it, up to the column's top, let the eye through
## (air, plants, clear water, glass: a lake bed, a drowned bank, what
## stands under or behind glass) or are only thin covers (a building's
## roofs and floors, a single natural layer: seen through its windows and
## doors); THICK_COVER natural ones in a row (rock) hide it in a cave.
static func _sky_through(
	voxels: PackedInt32Array, flags: PackedByteArray, clear: PackedByteArray, index: int, rows: int
) -> bool:
	var run := 0
	for k in range(1, rows):
		var voxel := voxels[index + k]
		var flag := flags[voxel]
		if flag & BUILT == 0 and (flag & CUBE != 0 or (flag & LIQUID != 0 and clear[voxel] == 0)):
			run += 1
			if run >= THICK_COVER:
				return false
		else:
			run = 0
	return true


## Notes a horizontal face of voxel row `y` at (lx, lz): a top (`code`:
## its material) or an underside (`code`: its face kind). Faces of the same
## row, material and part are merged into rectangles by _add_flats.
static func _record_flat(
	flats: Dictionary, y: int, code: int, part: int, underside: int, lx: int, lz: int
) -> void:
	var key := Vector4i(y, code, part * 2 + underside, lz)
	flats[key] = flats.get(key, 0) | (1 << lx)


## Merges the recorded horizontal faces into rectangles: runs along x,
## stacked along z while the same run continues.
static func _add_flats(result: Result, flats: Dictionary) -> void:
	var groups := {}
	for key: Vector4i in flats:
		var group := Vector3i(key.x, key.y, key.z)
		if not groups.has(group):
			var masks := []
			masks.resize(SIZE + 1)
			masks.fill(0)
			groups[group] = masks
		groups[group][key.w] = flats[key]
	for group: Vector3i in groups:
		var masks: Array = groups[group]
		var open := {}
		for lz in SIZE + 1:
			var runs := _runs(masks[lz])
			for run: Vector2i in open.keys():
				if not runs.has(run):
					_add_flat(result, group, run, open[run], lz)
					open.erase(run)
			for run in runs:
				if not open.has(run):
					open[run] = lz


## Runs of consecutive set bits of a 16-bit mask: [first, last] pairs.
static func _runs(mask: int) -> Array[Vector2i]:
	var runs: Array[Vector2i] = []
	var x := 0
	while x < SIZE:
		if mask & (1 << x) == 0:
			x += 1
			continue
		var first := x
		while x < SIZE and mask & (1 << x) != 0:
			x += 1
		runs.append(Vector2i(first, x - 1))
	return runs


## A merged rectangle of tops or undersides: tiles run.x..run.y along x,
## z0 to z1 (excluded) along z.
static func _add_flat(result: Result, group: Vector3i, run: Vector2i, z0: int, z1: int) -> void:
	var y := group.x
	var code := group.y
	var surface := result.parts[group.z >> 1]
	var x0 := float(run.x)
	var x1 := float(run.y + 1)
	if group.z & FLAT_UNDERSIDE != 0:
		var bottom := float(y - SEA)
		var below: Array[Vector3] = [
			Vector3(x0, bottom, z1),
			Vector3(x1, bottom, z1),
			Vector3(x1, bottom, z0),
			Vector3(x0, bottom, z0),
		]
		# Ceilings show in first person: their texture repeats on every tile.
		var texels: Array[Vector2] = []
		for corner in below:
			texels.append(Vector2(corner.x, corner.z) * FACE_PX_PER_UNIT)
		surface.quad(below, texels, Vector3.DOWN, Vector3.RIGHT, Vector2(code, 0))
		return
	var level := y + 1 - SEA
	var height := float(level)
	if Voxels.is_liquid(code):
		height -= ChunkData.WATER_DROP
	if group.z >> 1 == Part.CAPS:
		# A hair under the cut, so the cut keeps it.
		height -= 0.002
	var corners: Array[Vector3] = [
		Vector3(x0, height, z0),
		Vector3(x1, height, z0),
		Vector3(x1, height, z1),
		Vector3(x0, height, z1),
	]
	# UVs in chunk pixels / 256 (the top shader works per art pixel).
	var uvs: Array[Vector2] = []
	for corner in corners:
		uvs.append(Vector2(corner.x, corner.z) / SIZE)
	surface.quad(corners, uvs, Vector3.UP, Vector3.RIGHT, Vector2(code, level))


## One underside under the whole chunk: the bottom of the world closes the
## rock (see the view cut). It is only ever seen from behind.
static func _add_world_bottom(surface: Surface) -> void:
	var bottom := float(-SEA)
	var corners: Array[Vector3] = [
		Vector3(0, bottom, SIZE),
		Vector3(SIZE, bottom, SIZE),
		Vector3(SIZE, bottom, 0),
		Vector3(0, bottom, 0),
	]
	var texels: Array[Vector2] = [Vector2(0, 0), Vector2(16, 0), Vector2(16, 16), Vector2(0, 16)]
	surface.quad(corners, texels, Vector3.DOWN, Vector3.RIGHT, Vector2(WALL_KIND_OFFSET, 0))


## Vertical quad on `side` of tile (lx, lz), facing out, from `bottom` to
## `top` (levels). Texture u runs left to right as seen from the front, v
## counts pixels down from the top.
static func _add_side(
	surface: Surface,
	lx: int,
	lz: int,
	side: int,
	bottom: float,
	top: float,
	uv2: Vector2,
	color: Color
) -> void:
	var x0 := float(lx)
	var x1 := x0 + 1.0
	var z0 := float(lz)
	var z1 := z0 + 1.0
	var a: Vector2
	var b: Vector2
	match side:
		Side.SOUTH:
			a = Vector2(x0, z1)
			b = Vector2(x1, z1)
		Side.NORTH:
			a = Vector2(x1, z0)
			b = Vector2(x0, z0)
		Side.EAST:
			a = Vector2(x1, z1)
			b = Vector2(x1, z0)
		_:
			a = Vector2(x0, z0)
			b = Vector2(x0, z1)
	var v_bottom := (top - bottom) * FACE_PX_PER_UNIT
	var corners: Array[Vector3] = [
		Vector3(a.x, top, a.y),
		Vector3(b.x, top, b.y),
		Vector3(b.x, bottom, b.y),
		Vector3(a.x, bottom, a.y),
	]
	var uvs: Array[Vector2] = [
		Vector2(0.0, 0.0), Vector2(16.0, 0.0), Vector2(16.0, v_bottom), Vector2(0.0, v_bottom)
	]
	var along := b - a
	var tangent := Vector3(along.x, 0.0, along.y).normalized()
	var normal := Vector3(-tangent.z, 0.0, tangent.x)
	surface.quad(corners, uvs, normal, tangent, uv2, color)


## A prop (tree, plant, rock...) standing in its voxel. Each gets a
## variant, a quarter turn and a slight tint from its tile, so the same
## seed always grows the same forest. A wide object (a workbench, a big
## gate) is drawn from its left end, turned the way it faces, over both
## its tiles; what players place keeps its turn (none, or the way it
## faces); a fence's version is the sides it joins.
static func _add_prop(
	result: Result,
	variants: PackedByteArray,
	voxel: int,
	voxels: PackedInt32Array,
	base: int,
	lx: int,
	y: int,
	lz: int,
	origin: Vector2i
) -> void:
	var block := Voxels.block_of(voxel)
	var count := variants[block]
	if count == 0:
		return
	var tile := origin + Vector2i(lx, lz)
	var h := HashUtil.hash2(ObjectShapes.SALT, tile.x, tile.y)
	var height := float(y - SEA)
	if y > 0 and Voxels.is_liquid(voxels[base + y - 1]):
		height -= ChunkData.WATER_DROP
	# Where it stands and which version: the same as physics (ObjectShapes).
	var offset := Vector2(ObjectShapes.offset_at(block, tile)) / 16.0
	var foot := Vector3(lx + 0.5 + offset.x, height, lz + 0.5 + offset.y)
	var turn := prop_turn(tile)
	if ObjectShapes.front_of(block) != Vector2i.ZERO:
		turn = Basis(Vector3.UP, ObjectShapes.turn_of(block))
	elif Mining.FLOOR_OBJECTS.has(block):
		turn = Basis()
	if ObjectShapes.is_wide_left(block):
		var right := ObjectShapes.wide_right(block)
		foot += Vector3(right.x, 0.0, right.y) * 0.5
	var shade := 0.93 + ((h >> 16) & 15) / 15.0 * 0.14
	var warmth := 0.97 + ((h >> 20) & 7) / 7.0 * 0.06
	var custom := Color(shade * warmth, shade, shade / warmth, ((h >> 24) & 255) / 255.0)
	var variant := ObjectShapes.variant_at(block, tile)
	if block == Tiles.Block.FENCE:
		variant = _fence_sides(voxels, base + y)
	var key := Vector2i(ObjectShapes.model_block(block), variant % count)
	if not result.props.has(key):
		result.props[key] = []
	result.props[key].append([Transform3D(turn, foot), custom])


## The sides a fence at `index` (padded voxels) joins (ObjectShapes.FENCE_SIDES
## bits: north, east, south, west).
static func _fence_sides(voxels: PackedInt32Array, index: int) -> int:
	var sides := 0
	for bit in ObjectShapes.FENCE_SIDES.size():
		var side: Vector2i = ObjectShapes.FENCE_SIDES[bit]
		if ObjectShapes.fence_joins(voxels[index + side.x * STRIDE_X + side.y * STRIDE_Z]):
			sides |= 1 << bit
	return sides
