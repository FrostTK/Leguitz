class_name VoxelRay
extends RefCounted
## Walks a ray through the voxels cell by cell (Amanatides & Woo) in local
## units (1 tile across = 1 level up = 1 unit, see Render3D): the first
## cube or object it meets. Air and liquids let it through. Objects are
## met on their body as physics sees it (a tree on its trunk, all the way
## up; ObjectShapes), small plants on the lower part of their cell, stairs
## and slabs on their octants (ShapedBlocks; `box` is then the block's).

## Height (levels) of the small plants' body.
const PLANT_HEIGHT := 0.7
## How deep (local units) what hangs on a wall is met, against it (a
## lantern on its arm: deeper).
const WALL_SLICE := 0.3
const LANTERN_SLICE := 0.75
## Small lights met on a little body of their own, in the middle of their
## tile: [width, height, how high it starts] (local units).
const SMALL_BODIES := {
	Tiles.Block.TORCH: [0.3, 0.95, 0.0],
	Tiles.Block.LANTERN: [0.45, 0.85, 0.0],
	Tiles.Block.LANTERN_HANGING: [0.45, 0.85, 0.15],
}


class Hit:
	extends RefCounted
	## The voxel met (tile x, row, tile y) and what it holds; for an
	## object, the voxel it stands in.
	var cell := Vector3i.ZERO
	var voxel := 0
	## Side it was met on (zero when the ray starts inside it): a block
	## placed against it goes to cell + normal.
	var normal := Vector3i.ZERO
	var distance := 0.0
	## Where the ray met it, and what it met (the cell, or the object's
	## body), in local units.
	var point := Vector3.ZERO
	var box := AABB()


## The first cube or object along `direction` from `origin` (local units)
## within `max_distance`, or null. `voxel_at`: Callable(cell: Vector3i) ->
## int, as WorldState.voxel_at.
static func cast(
	origin: Vector3, direction: Vector3, max_distance: float, voxel_at: Callable
) -> Hit:
	if direction.length_squared() < 1e-12:
		return null
	var dir := direction.normalized()
	var pos := Vector3i(origin.floor())
	var step := Vector3i(
		signi(int(signf(dir.x))), signi(int(signf(dir.y))), signi(int(signf(dir.z)))
	)
	var t_delta := Vector3(
		absf(1.0 / dir.x) if dir.x != 0.0 else INF,
		absf(1.0 / dir.y) if dir.y != 0.0 else INF,
		absf(1.0 / dir.z) if dir.z != 0.0 else INF
	)
	var t_max := Vector3(
		_first_boundary(origin.x, pos.x, step.x, t_delta.x),
		_first_boundary(origin.y, pos.y, step.y, t_delta.y),
		_first_boundary(origin.z, pos.z, step.z, t_delta.z)
	)
	var t := 0.0
	var normal := Vector3i.ZERO
	while t <= max_distance:
		var cell := Vector3i(pos.x, pos.y + GameConst.SEA_LEVEL, pos.z)
		var voxel: int = voxel_at.call(cell)
		if Voxels.is_cube(voxel):
			var hit := Hit.new()
			hit.cell = cell
			hit.voxel = voxel
			hit.normal = normal
			hit.distance = t
			hit.point = origin + dir * t
			hit.box = AABB(Vector3(pos), Vector3.ONE)
			return hit
		# An object counts only where the ray meets its body inside this cell
		# (something closer, in the next cells, would hide it otherwise).
		var met := (
			_shaped_in(cell, voxel, origin, dir, voxel_at)
			if Voxels.is_shaped(voxel)
			else _object_in(cell, voxel, origin, dir, voxel_at)
		)
		if (
			met != null
			and met.distance <= minf(minf(t_max.x, minf(t_max.y, t_max.z)), max_distance)
		):
			return met
		if t_max.x < t_max.y and t_max.x < t_max.z:
			pos.x += step.x
			t = t_max.x
			t_max.x += t_delta.x
			normal = Vector3i(-step.x, 0, 0)
		elif t_max.y < t_max.z:
			pos.y += step.y
			t = t_max.y
			t_max.y += t_delta.y
			normal = Vector3i(0, -step.y, 0)
		else:
			pos.z += step.z
			t = t_max.z
			t_max.z += t_delta.z
			normal = Vector3i(0, 0, -step.z)
	return null


## Where the ray meets stairs or a slab in `cell` (its nearest octant box),
## null if it misses them.
static func _shaped_in(
	cell: Vector3i, voxel: int, origin: Vector3, dir: Vector3, voxel_at: Callable
) -> Hit:
	var block := Voxels.block_of(voxel)
	var best: Hit = null
	for box in ShapedBlocks.boxes(ShapedBlocks.mask(block, cell, voxel_at), cell):
		var hit := _hit_box(box, cell, voxel, origin, dir)
		if hit != null and (best == null or hit.distance < best.distance):
			best = hit
	if best != null:
		best.box = ShapedBlocks.bounds(block, cell)
	return best


## The body (local units) of an object standing in voxel `cell`: what
## hangs on a wall a slice of its tile against it, an open gate its tile.
static func object_box(block: int, cell: Vector3i) -> AABB:
	if ShapedBlocks.is_shaped(block):
		return ShapedBlocks.bounds(block, cell)
	var tile := Vector2i(cell.x, cell.z)
	var level := float(cell.y - GameConst.SEA_LEVEL)
	if SMALL_BODIES.has(block):
		var body: Array = SMALL_BODIES[block]
		var width: float = body[0]
		var low := Vector3(tile.x + 0.5 - width * 0.5, level + body[2], tile.y + 0.5 - width * 0.5)
		return AABB(low, Vector3(width, body[1], width))
	if ObjectShapes.is_wall_mounted(block):
		var back := -ObjectShapes.front_of(block)
		var slice := WALL_SLICE
		if ObjectShapes.kind_of(block) == Tiles.Block.LANTERN_WALL:
			slice = LANTERN_SLICE
		var low := Vector3(tile.x, level, tile.y)
		var size := Vector3(1.0, 1.0, 1.0)
		if back.x != 0:
			size.x = slice
			low.x += 1.0 - slice if back.x > 0 else 0.0
		else:
			size.z = slice
			low.z += 1.0 - slice if back.y > 0 else 0.0
		return AABB(low, size)
	if ObjectShapes.is_gate(block) and ObjectShapes.is_open(block):
		return AABB(Vector3(tile.x, level, tile.y), Vector3(1.0, 1.25, 1.0))
	var rect := ObjectShapes.footprint_rect(block, tile)
	if not rect.has_area():
		return AABB(Vector3(tile.x, level, tile.y), Vector3(1.0, PLANT_HEIGHT, 1.0))
	var levels := float(ObjectShapes.blocking_levels(block, ObjectShapes.variant_at(block, tile)))
	var size := GameConst.TILE_SIZE
	return AABB(
		Vector3(rect.position.x / size, level, rect.position.y / size),
		Vector3(rect.size.x / size, levels, rect.size.y / size)
	)


static func _first_boundary(start: float, cell: int, step: int, t_delta: float) -> float:
	if step > 0:
		return (cell + 1 - start) * t_delta
	if step < 0:
		return (start - cell) * t_delta
	return INF


## An object whose body fills (part of) `cell`: one standing in it, or a
## tree rising from below; null if none or if the ray misses its body.
static func _object_in(
	cell: Vector3i, voxel: int, origin: Vector3, dir: Vector3, voxel_at: Callable
) -> Hit:
	var level := float(cell.y - GameConst.SEA_LEVEL)
	var row := cell.y
	var below := voxel
	while row > maxi(0, cell.y - PlayerBody.MAX_OBJECT_LEVELS - 1):
		if Voxels.is_object(below):
			var base := Vector3i(cell.x, row, cell.z)
			var box := object_box(Voxels.block_of(below), base)
			if box.end.y <= level:
				return null
			return _hit_box(box, base, below, origin, dir)
		if Voxels.is_cube(below) or (Voxels.is_liquid(below) and row < cell.y):
			return null
		row -= 1
		below = voxel_at.call(Vector3i(cell.x, row, cell.z))
	return null


## Where the ray enters `box` (slab method), as a hit on the object.
static func _hit_box(box: AABB, cell: Vector3i, voxel: int, origin: Vector3, dir: Vector3) -> Hit:
	var t_near := -INF
	var t_far := INF
	var axis := -1
	for i in 3:
		if dir[i] == 0.0:
			if origin[i] < box.position[i] or origin[i] > box.end[i]:
				return null
			continue
		var t1 := (box.position[i] - origin[i]) / dir[i]
		var t2 := (box.end[i] - origin[i]) / dir[i]
		if t1 > t2:
			var swap := t1
			t1 = t2
			t2 = swap
		if t1 > t_near:
			t_near = t1
			axis = i
		t_far = minf(t_far, t2)
	if t_near > t_far or t_far < 0.0:
		return null
	var hit := Hit.new()
	hit.cell = cell
	hit.voxel = voxel
	hit.distance = maxf(t_near, 0.0)
	hit.point = origin + dir * hit.distance
	hit.box = box
	if t_near > 0.0 and axis >= 0:
		hit.normal[axis] = -1 if dir[axis] > 0.0 else 1
	return hit
