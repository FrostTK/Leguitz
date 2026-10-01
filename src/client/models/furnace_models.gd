class_name FurnaceModels
extends RefCounted
## The furnaces (SIZE voxels, their front towards +z). The food furnace is
## a bread oven: a dome of fired clay bricks on a plinth of fieldstones,
## an arched mouth, a chimney at the back and a loaf cooling on its
## ledge. The factory furnace is a block of dark bricks bound in iron, an
## iron door with a grate, an ash drawer and a stovepipe. Lit, fire burns
## inside (VoxelGrid.Kind.GLOW voxels light themselves); a food furnace
## that melted ore is broken: its dome burst open and cracked, its chimney
## fallen, cooled metal spilled from its mouth.

const SIZE := Vector3i(14, 18, 14)
const FIELDSTONE := ["#4a464c", "#625d66", "#7a757f", "#958f99"]
const CLAY := ["#7e4c33", "#9c6343", "#b87c54", "#cf9868"]
const ARCH := ["#5e3123", "#7a412d", "#94553a"]
const SOOT := ["#161313", "#262020", "#352d2c"]
const ASH := ["#57524f", "#736d69", "#8c8682"]
const FIRE := ["#b8301a", "#ee6420", "#ffa634", "#ffe27a"]
const BRICK := ["#2d2629", "#3f3539", "#52464b", "#64575d"]
const IRON := ["#24252a", "#3c3e45", "#5b5e67", "#868a94"]
const LOAF := ["#8a5222", "#b8762f", "#d99a48"]
const SLAG := ["#4c4038", "#6e5c4c", "#9a7f63", "#c79a62"]
## The plinth's height and the dome over it (center, radii).
const PLINTH := 4
const DOME_CENTER := Vector3(7.0, 4.0, 6.0)
const DOME := Vector3(7.0, 9.6, 6.0)
const INSIDE := Vector3(4.6, 7.0, 3.8)
## The mouth: its half width by height above the plinth.
const MOUTH := [3.0, 3.0, 3.0, 3.0, 2.0, 1.0]
## The factory furnace's body (its door stands a voxel proud of it).
const BODY_TOP := 13
const BODY_FRONT := 12


## The food furnace: unlit, lit, or broken (ore melted in it).
static func food(lit: bool, broken := false) -> VoxelGrid:
	var grid := VoxelGrid.new(SIZE)
	grid.box(Vector3i.ZERO, Vector3i(13, PLINTH - 1, 13), _fieldstones())
	grid.ellipsoid(DOME_CENTER, DOME, _clay(false))
	# The inside: a sooty shell around the hollow, ash or fire on its floor.
	grid.ellipsoid(DOME_CENTER, INSIDE + Vector3.ONE, _clay(true))
	_carve_ellipsoid(grid, DOME_CENTER, INSIDE)
	for x in range(3, 11):
		for z in range(3, 10):
			var p := Vector3i(x, PLINTH - 1, z)
			if grid.get_voxel(p + Vector3i.UP) == 0:
				grid.set_voxel(p, _v(SOOT[1] if (x + z) % 3 else SOOT[2]))
	_mouth(grid)
	if not broken:
		_chimney(grid, 16)
		# A loaf cooling on the ledge.
		grid.box(Vector3i(9, PLINTH, 12), Vector3i(11, PLINTH, 13), _v(LOAF[1]))
		grid.box(Vector3i(10, PLINTH + 1, 12), Vector3i(11, PLINTH + 1, 13), _v(LOAF[2]))
		grid.set_voxel(Vector3i(9, PLINTH, 13), _v(LOAF[0]))
	if lit and not broken:
		_oven_fire(grid)
	elif not broken:
		_ashes(grid)
	if broken:
		_burst(grid)
	return grid


## The factory furnace, unlit or lit.
static func factory(lit: bool) -> VoxelGrid:
	var grid := VoxelGrid.new(SIZE)
	grid.box(Vector3i.ZERO, Vector3i(13, BODY_TOP, BODY_FRONT), _bricks())
	# Iron: the base and top plates, angle irons at the corners, rivets.
	grid.box(Vector3i.ZERO, Vector3i(13, 0, BODY_FRONT), _v(IRON[1]))
	grid.box(Vector3i(0, BODY_TOP, 0), Vector3i(13, BODY_TOP, BODY_FRONT), _v(IRON[2]))
	grid.box(Vector3i(0, BODY_TOP, BODY_FRONT), Vector3i(13, BODY_TOP, BODY_FRONT), _v(IRON[1]))
	for x: int in [0, 13]:
		for z: int in [0, BODY_FRONT]:
			grid.box(Vector3i(x, 0, z), Vector3i(x, BODY_TOP, z), _v(IRON[1]))
			for y in range(2, BODY_TOP, 3):
				grid.set_voxel(Vector3i(x, y, z), _v(IRON[3]))
	# A band of iron around the middle.
	grid.box(Vector3i(0, 7, 0), Vector3i(13, 7, 0), _v(IRON[1]))
	grid.box(Vector3i(0, 7, 0), Vector3i(0, 7, BODY_FRONT), _v(IRON[1]))
	grid.box(Vector3i(13, 7, 0), Vector3i(13, 7, BODY_FRONT), _v(IRON[1]))
	# The door: a frame, a plate, a grate showing the fire, a handle.
	var front := BODY_FRONT + 1
	grid.box(Vector3i(3, 5, front), Vector3i(10, 12, front), _v(IRON[1]))
	grid.box(Vector3i(4, 6, front), Vector3i(9, 11, front), _v(IRON[2]))
	for x in range(5, 9):
		for y in range(8, 11):
			var bar := x % 2 == 1
			var inside := _v(FIRE[2 if y == 9 else 1], VoxelGrid.Kind.GLOW) if lit else _v(SOOT[0])
			grid.set_voxel(Vector3i(x, y, front), _v(IRON[0]) if bar else inside)
	grid.box(Vector3i(9, 7, front), Vector3i(9, 8, front), _v(IRON[3]))
	for y: int in [6, 11]:
		grid.set_voxel(Vector3i(3, y, front), _v(IRON[3]))
	for x: int in [4, 9]:
		grid.set_voxel(Vector3i(x, 12, front), _v(IRON[3]))
	# The ash drawer under the door: embers glowing when lit.
	grid.box(Vector3i(4, 1, front), Vector3i(9, 3, front), _v(IRON[1]))
	for x in range(5, 9):
		var ember := _v(FIRE[0] if x % 2 else FIRE[1], VoxelGrid.Kind.GLOW)
		grid.set_voxel(Vector3i(x, 2, BODY_FRONT), ember if lit else _v(ASH[0]))
		grid.set_voxel(Vector3i(x, 2, front), 0)
	grid.box(Vector3i(6, 3, front), Vector3i(7, 3, front), _v(IRON[3]))
	# The stovepipe, at the back on the right, and a hatch on the top.
	grid.cylinder(Vector2(10.0, 3.0), 2.1, BODY_TOP + 1, SIZE.y - 1, _v(IRON[1]))
	grid.disc(Vector2(10.0, 3.0), 2.1, BODY_TOP + 2, _v(IRON[2]))
	grid.disc(Vector2(10.0, 3.0), 2.1, SIZE.y - 1, _v(IRON[0]))
	grid.disc(Vector2(10.0, 3.0), 1.0, SIZE.y - 1, _v(SOOT[0]))
	for p: Vector3i in [Vector3i(8, 15, 3), Vector3i(11, 15, 2), Vector3i(10, 15, 4)]:
		grid.set_voxel(p, _v(IRON[3]))
	grid.box(Vector3i(2, BODY_TOP + 1, 5), Vector3i(5, BODY_TOP + 1, 9), _v(IRON[1]))
	grid.box(Vector3i(3, BODY_TOP + 1, 6), Vector3i(4, BODY_TOP + 1, 8), _v(IRON[2]))
	grid.set_voxel(Vector3i(3, BODY_TOP + 2, 7), _v(IRON[3]))
	return grid


static func _v(hex: String, kind := VoxelGrid.Kind.SOLID) -> int:
	return VoxelGrid.voxel(Color(hex), kind)


## Fieldstones of a few sizes and shades, mortar between them.
static func _fieldstones() -> Callable:
	return func(p: Vector3i) -> int:
		var course := p.y / 2
		var shift := course * 3
		var along := p.x + p.z
		if (along + shift) % 5 == 0 or (p.y % 2 == 1 and p.y != PLINTH - 1):
			return _v(FIELDSTONE[0])
		var stone := HashUtil.unit2(0xF1E7, (along + shift) / 5, course)
		var light := 3 if p.y == PLINTH - 1 and stone > 0.4 else (2 if stone > 0.45 else 1)
		return _v(FIELDSTONE[light])


## Fired clay bricks in courses (lighter higher up), or the soot inside.
static func _clay(sooty: bool) -> Callable:
	return func(p: Vector3i) -> int:
		if p.y < PLINTH:
			return 0
		if sooty:
			return _v(SOOT[1] if HashUtil.unit2(0x5007, p.x + p.z * 16, p.y) > 0.3 else SOOT[2])
		var course := (p.y - PLINTH) / 2
		var along := p.x + p.z + course * 2
		if along % 4 == 0 and (p.y - PLINTH) % 2 == 0:
			return _v(CLAY[0])
		var brick := HashUtil.unit2(0xC1A7, along / 4, course)
		var light := 1 if brick < 0.3 else (2 if brick < 0.8 else 3)
		if p.y >= 11 and light < 3 and brick > 0.5:
			light += 1
		return _v(CLAY[light])


## Dark bricks in staggered courses, mortar lines between.
static func _bricks() -> Callable:
	return func(p: Vector3i) -> int:
		var course := p.y / 2
		var along := p.x + p.z + (2 if course % 2 else 0)
		if p.y % 2 == 1 or along % 4 == 0:
			return _v(BRICK[0])
		var brick := HashUtil.unit2(0xB21C, along / 4, course)
		return _v(BRICK[3] if brick > 0.8 else (BRICK[2] if brick > 0.35 else BRICK[1]))


static func _carve_ellipsoid(grid: VoxelGrid, center: Vector3, radii: Vector3) -> void:
	for z in SIZE.z:
		for y in range(PLINTH, SIZE.y):
			for x in SIZE.x:
				var d := (Vector3(x, y, z) + Vector3.ONE * 0.5 - center) / radii
				if d.length_squared() <= 1.0:
					grid.set_voxel(Vector3i(x, y, z), 0)


## The arched mouth through the front of the dome, ringed with dark bricks.
static func _mouth(grid: VoxelGrid) -> void:
	for row in MOUTH.size():
		var y: int = PLINTH + row
		var half: float = MOUTH[row]
		for x in SIZE.x:
			var off := absf(x + 0.5 - 7.0)
			for z in range(7, SIZE.z):
				var p := Vector3i(x, y, z)
				if off < half:
					grid.set_voxel(p, 0)
				elif off < half + 1.0 and grid.get_voxel(p) != 0:
					grid.set_voxel(p, _v(ARCH[1] if (y + x) % 3 else ARCH[2]))
	for x in range(5, 9):
		_paint_front(grid, Vector2i(x, PLINTH + MOUTH.size()), _v(ARCH[0 if x % 2 else 1]))


static func _chimney(grid: VoxelGrid, top: int) -> void:
	for y in range(9, top + 1):
		for x in range(6, 9):
			for z in range(1, 4):
				var edge := y == top
				var p := Vector3i(x, y, z)
				if edge and x == 7 and z == 2:
					grid.set_voxel(p, _v(SOOT[0]))
				else:
					grid.set_voxel(p, _v(ARCH[0] if edge or (y + x + z) % 4 == 0 else ARCH[2]))


## Logs burning on the oven's floor, embers around them, flames licking up.
static func _oven_fire(grid: VoxelGrid) -> void:
	for x in range(4, 10):
		for z in range(4, 10):
			var p := Vector3i(x, PLINTH, z)
			if grid.get_voxel(p) == 0:
				var heat := HashUtil.unit2(0xF12E, x, z)
				grid.set_voxel(p, _v(FIRE[0] if heat < 0.45 else FIRE[1], VoxelGrid.Kind.GLOW))
	for x in range(5, 9):
		grid.set_voxel(Vector3i(x, PLINTH + 1, 6), _v("#3a2416"))
	for p: Vector3i in [
		Vector3i(5, 5, 7),
		Vector3i(6, 5, 7),
		Vector3i(7, 5, 7),
		Vector3i(8, 5, 6),
		Vector3i(6, 6, 7),
		Vector3i(7, 6, 6),
		Vector3i(6, 7, 6),
		Vector3i(7, 5, 8),
	]:
		var hot := FIRE[3] if p.y >= 6 else FIRE[2]
		grid.set_voxel(p, _v(hot, VoxelGrid.Kind.GLOW))


## Cold ashes and a charred log end on the oven's floor.
static func _ashes(grid: VoxelGrid) -> void:
	for x in range(4, 10):
		for z in range(4, 10):
			var p := Vector3i(x, PLINTH, z)
			if grid.get_voxel(p) == 0 and HashUtil.unit2(0xA5E5, x, z) > 0.35:
				grid.set_voxel(p, _v(ASH[1] if (x + z) % 2 else ASH[0]))
	grid.box(Vector3i(5, PLINTH, 6), Vector3i(7, PLINTH, 6), _v("#2a1d16"))


## Broken: a hole burst through the dome, cracks, a stump of chimney,
## fallen bricks and cooled metal spilled out of the mouth.
static func _burst(grid: VoxelGrid) -> void:
	for z in SIZE.z:
		for y in range(9, SIZE.y):
			for x in SIZE.x:
				var d := Vector2(x - 8.5, z - 6.5).length() + (y - 9) * 0.6
				if d + HashUtil.unit2(0xB0B5, x + z * 16, y) * 2.0 < 5.0:
					grid.set_voxel(Vector3i(x, y, z), 0)
	# Cracks running from the mouth over the dome's front.
	for at: Vector2i in [
		Vector2i(4, 10),
		Vector2i(4, 11),
		Vector2i(3, 11),
		Vector2i(4, 12),
		Vector2i(9, 10),
		Vector2i(10, 9),
		Vector2i(11, 8),
		Vector2i(11, 7),
		Vector2i(12, 6),
	]:
		_paint_front(grid, at, _v(SOOT[0]))
	_chimney(grid, 10)
	for p: Vector3i in [Vector3i(0, 4, 12), Vector3i(12, 4, 0), Vector3i(0, 4, 1)]:
		grid.box(p, p + Vector3i(1, 0, 0), _v(CLAY[2]))
	grid.set_voxel(Vector3i(2, 5, 12), _v(ARCH[1]))
	# Cooled metal: a crusted puddle in the oven, over the ledge.
	for x in range(4, 10):
		for z in range(4, SIZE.z):
			var p := Vector3i(x, PLINTH, z)
			var spill := absf(x - 6.5) < (2.6 if z < 11 else 1.6 - (z - 11) * 0.4)
			if spill and grid.get_voxel(p) == 0:
				var shine := HashUtil.unit2(0x51A6, x, z)
				grid.set_voxel(p, _v(SLAG[3] if shine > 0.85 else SLAG[2 if shine > 0.4 else 1]))


## Paints the voxel of a column (x, y) seen first from the front.
static func _paint_front(grid: VoxelGrid, at: Vector2i, value: int) -> void:
	for z in range(SIZE.z - 1, -1, -1):
		var p := Vector3i(at.x, at.y, z)
		if grid.get_voxel(p) != 0:
			grid.set_voxel(p, value)
			return
