class_name DecorModels
extends RefCounted
## What players furnish their houses and gardens with, in voxels (16 per
## tile, front towards +z, standing on y = 0, centered on x and z):
## an iron torch bracket and curtains hung on a wall (their back against
## the tile's edge, z = 0), a glass pane, a sink, a toilet, a table, a
## chair, a fence (one version per set of sides it joins), a wicket gate
## and a big gate two tiles wide (shut and open), a campfire; the lights:
## a torch on the ground or in its bracket, a lantern on the ground, hung
## from a ceiling by a chain or on a wall from an arm (their flames and
## glass light themselves).

const WOOD := ["#5e3d22", "#7a5130", "#9a6a3c", "#b37f4b", "#c99560"]
## Furniture: a darker walnut, which stands out on plank floors.
const WALNUT := ["#3a2416", "#4e301c", "#664026", "#7d5232", "#94653f"]
const IRON := ["#2e2f35", "#4b4d55", "#6f727c", "#9a9ea8"]
const STONE := ["#85838e", "#a3a1ab", "#bdbcc4", "#d6d5db"]
const PORCELAIN := ["#aeb3b8", "#d2d6da", "#e9ecee", "#fbfcfd"]
const LINEN := ["#9e8f74", "#bfb194", "#d9cdb1", "#ece3cc"]
const GLASS := ["#9dc0ca", "#d4ebf0", "#f6fcfd"]
const WATER := ["#3f7fa8", "#6aa6c8"]
const FIRE := ["#b4280c", "#ea5a12", "#f99a1c", "#ffd04a", "#fff2b0"]
const EMBER := ["#3a1c10", "#7a2a10"]
const ASH := ["#4a4448", "#6a6468"]
## A torch's head, wrapped in coal-soaked cloth.
const WRAP := ["#241c18", "#3a2c24"]
## A lantern's glass, lit from inside.
const LANTERN_GLOW := ["#e8902c", "#ffc35a", "#ffe6a4"]


## The model of a block (its kind's; a fence's version: the sides it joins,
## ObjectShapes.FENCE_SIDES bits). Null: not one of these.
static func build(block: int, variant: int) -> VoxelGrid:
	match block:
		Tiles.Block.TORCH_BRACKET:
			return torch_bracket(false)
		Tiles.Block.TORCH_BRACKET_LIT:
			return torch_bracket(true)
		Tiles.Block.TORCH:
			return torch()
		Tiles.Block.LANTERN:
			return lantern(0)
		Tiles.Block.LANTERN_HANGING:
			return lantern_hanging()
		Tiles.Block.LANTERN_WALL:
			return lantern_wall()
		Tiles.Block.CURTAINS:
			return curtains()
		Tiles.Block.GLASS_PANE:
			return glass_pane()
		Tiles.Block.SINK:
			return sink()
		Tiles.Block.TOILET:
			return toilet()
		Tiles.Block.TABLE:
			return table()
		Tiles.Block.CHAIR:
			return chair()
		Tiles.Block.FENCE:
			return fence(variant)
		Tiles.Block.GATE:
			return gate(false)
		Tiles.Block.GATE_OPEN:
			return gate(true)
		Tiles.Block.BIG_GATE:
			return big_gate(false)
		Tiles.Block.BIG_GATE_OPEN:
			return big_gate(true)
		Tiles.Block.CAMPFIRE:
			return campfire()
	return null


## The model of an item placing one of these (its icon, in hand, on the
## ground): a fence joining both sides, gates shut. Null: not one.
static func item(item_id: int) -> VoxelGrid:
	match item_id:
		Items.Id.FENCE:
			return fence(2 | 8)
		Items.Id.GATE:
			return gate(false)
		Items.Id.BIG_GATE:
			return big_gate(false)
	var block: int = Items.PLACES_BLOCK.get(item_id, -1)
	return build(block, 0) if block != -1 else null


## The color of a block's chips (BlockColors).
static func color_of(kind: int) -> Color:
	match kind:
		Tiles.Block.TORCH_BRACKET:
			return Color(IRON[2])
		Tiles.Block.CURTAINS:
			return Color(LINEN[2])
		Tiles.Block.GLASS_PANE:
			return Color(GLASS[1])
		Tiles.Block.SINK, Tiles.Block.TOILET:
			return Color(PORCELAIN[2])
		Tiles.Block.CAMPFIRE, Tiles.Block.TORCH:
			return Color(FIRE[2])
		Tiles.Block.TORCH_BRACKET_LIT, Tiles.Block.LANTERN:
			return Color(IRON[2])
		Tiles.Block.LANTERN_HANGING, Tiles.Block.LANTERN_WALL:
			return Color(IRON[2])
		Tiles.Block.TABLE, Tiles.Block.CHAIR:
			return Color(WALNUT[3])
	return Color(WOOD[3])


static func _v(hex: String, kind := VoxelGrid.Kind.SOLID) -> int:
	return VoxelGrid.voxel(Color(hex), kind)


## Wood (`colors`, dark to light) with its grain here and there.
static func _wood(salt: int, colors: Array = WOOD) -> Callable:
	return func(p: Vector3i) -> int:
		var grain := HashUtil.unit2(salt, p.x / 3 + p.z * 7, p.y)
		if grain > 0.86:
			return _v(colors[4])
		return _v(colors[3] if grain > 0.3 else colors[2])


## An iron bracket hung on the wall: a riveted plate, an arm and a ring to
## hold a torch, a strut under it; `lit`: a torch in it.
static func torch_bracket(lit: bool) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 22 if lit else 16, 16))
	if lit:
		_torch(grid, Vector3i(7, 9, 5), 6)
	grid.box(Vector3i(6, 5, 0), Vector3i(9, 11, 0), _v(IRON[1]))
	grid.box(Vector3i(6, 11, 0), Vector3i(9, 11, 0), _v(IRON[2]))
	for x: int in [6, 9]:
		for y: int in [5, 11]:
			grid.set_voxel(Vector3i(x, y, 1), _v(IRON[3]))
	# The arm out of the plate, and the ring at its end.
	grid.box(Vector3i(7, 9, 1), Vector3i(8, 9, 3), _v(IRON[2]))
	for x in range(6, 10):
		for z in range(4, 8):
			var edge := x == 6 or x == 9 or z == 4 or z == 7
			if edge:
				grid.set_voxel(Vector3i(x, 9, z), _v(IRON[2] if z < 7 else IRON[1]))
	grid.box(Vector3i(7, 8, 5), Vector3i(8, 8, 6), _v(IRON[0]))
	# The strut from the plate's foot to under the ring.
	grid.line(Vector3(7.5, 5.5, 1.5), Vector3(7.5, 7.5, 5.0), 0.4, _v(IRON[1]))
	grid.line(Vector3(8.5, 5.5, 1.5), Vector3(8.5, 7.5, 5.0), 0.4, _v(IRON[0]))
	return grid


## A torch standing on the ground: a stick, its wrapped head, a flame.
static func torch() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 18, 16))
	_torch(grid, Vector3i(7, 0, 7), 9)
	return grid


## A torch (2 x 2 voxels) from `foot` up: `length` of stick, its head, its
## flame.
static func _torch(grid: VoxelGrid, foot: Vector3i, length: int) -> void:
	for y in length:
		grid.box(foot + Vector3i(0, y, 0), foot + Vector3i(0, y, 1), _v(WOOD[2]))
		grid.box(foot + Vector3i(1, y, 0), foot + Vector3i(1, y, 1), _v(WOOD[1]))
	var head := foot + Vector3i(0, length, 0)
	grid.box(head - Vector3i(1, 0, 1), head + Vector3i(2, 1, 2), _v(WRAP[0]))
	grid.box(head + Vector3i(-1, 1, -1), head + Vector3i(2, 1, 2), _v(WRAP[1]))
	var glow := VoxelGrid.Kind.GLOW
	grid.box(head + Vector3i(0, 1, 0), head + Vector3i(1, 1, 1), _v(EMBER[1], glow))
	# The flame: wide at its foot, a tongue leaning a little.
	grid.box(head + Vector3i(-1, 2, -1), head + Vector3i(2, 2, 2), _v(FIRE[1], glow))
	grid.box(head + Vector3i(-1, 3, 0), head + Vector3i(2, 3, 1), _v(FIRE[2], glow))
	grid.box(head + Vector3i(0, 3, -1), head + Vector3i(1, 3, 2), _v(FIRE[2], glow))
	grid.box(head + Vector3i(0, 4, 0), head + Vector3i(1, 4, 1), _v(FIRE[3], glow))
	grid.box(head + Vector3i(0, 5, 0), head + Vector3i(0, 5, 1), _v(FIRE[3], glow))
	grid.set_voxel(head + Vector3i(0, 6, 1), _v(FIRE[4], glow))


## A lantern standing on `base` (rows): an iron foot, four posts, glass lit
## from inside, a cap and a handle (13 rows in all).
static func lantern(base: int) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 16, 16))
	_lantern(grid, base)
	return grid


static func _lantern(grid: VoxelGrid, base: int) -> void:
	var glow := VoxelGrid.Kind.GLOW
	grid.box(Vector3i(5, base, 5), Vector3i(10, base + 1, 10), _v(IRON[1]))
	grid.box(Vector3i(5, base, 5), Vector3i(10, base, 10), _v(IRON[0]))
	for y in range(base + 2, base + 9):
		for x in range(5, 11):
			for z in range(5, 11):
				var post := (x == 5 or x == 10) and (z == 5 or z == 10)
				var side := x == 5 or x == 10 or z == 5 or z == 10
				if post:
					grid.set_voxel(Vector3i(x, y, z), _v(IRON[0]))
				elif side:
					# The glass glows brighter at its middle, where the flame is.
					var near_flame := absi(y - (base + 5)) <= 1
					var middle := near_flame and ((x > 6 and x < 9) or (z > 6 and z < 9))
					var shade := 2 if middle else (1 if y > base + 2 else 0)
					grid.set_voxel(Vector3i(x, y, z), _v(LANTERN_GLOW[shade], glow))
	grid.box(Vector3i(5, base + 9, 5), Vector3i(10, base + 9, 10), _v(IRON[2]))
	grid.box(Vector3i(6, base + 10, 6), Vector3i(9, base + 10, 9), _v(IRON[1]))
	# The handle: up from both sides, across the top.
	for z: int in [7, 8]:
		grid.set_voxel(Vector3i(6, base + 11, z), _v(IRON[2]))
		grid.set_voxel(Vector3i(9, base + 11, z), _v(IRON[2]))
		grid.box(Vector3i(7, base + 12, z), Vector3i(8, base + 12, z), _v(IRON[3]))


## A lantern hung from a ceiling by a short chain.
static func lantern_hanging() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 16, 16))
	_lantern(grid, 2)
	grid.box(Vector3i(7, 15, 7), Vector3i(8, 15, 8), _v(IRON[1]))
	grid.set_voxel(Vector3i(7, 14, 8), _v(IRON[2]))
	grid.set_voxel(Vector3i(8, 14, 7), _v(IRON[2]))
	return grid


## A lantern hung on a wall from an iron arm (the wall at z = 0).
static func lantern_wall() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 16, 16))
	_lantern(grid, 1)
	grid.box(Vector3i(6, 10, 0), Vector3i(9, 15, 0), _v(IRON[1]))
	grid.box(Vector3i(6, 15, 0), Vector3i(9, 15, 0), _v(IRON[2]))
	grid.box(Vector3i(7, 14, 1), Vector3i(8, 14, 8), _v(IRON[2]))
	grid.box(Vector3i(7, 13, 1), Vector3i(8, 13, 1), _v(IRON[0]))
	grid.line(Vector3(7.5, 11.5, 0.5), Vector3(7.5, 13.5, 4.0), 0.4, _v(IRON[1]))
	return grid


## Linen curtains on a wooden rod, drawn back to the sides (the window
## behind shows between them), in folds.
static func curtains() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 16, 16))
	grid.box(Vector3i(0, 14, 1), Vector3i(15, 14, 1), _v(WOOD[1]))
	grid.box(Vector3i(0, 14, 1), Vector3i(0, 15, 2), _v(WOOD[2]))
	grid.box(Vector3i(15, 14, 1), Vector3i(15, 15, 2), _v(WOOD[2]))
	for x in 16:
		var inner := x if x < 8 else 15 - x
		if inner > 5:
			continue
		# Each panel narrows towards its tie, a third of the way up.
		for y in range(1, 14):
			var tie := absi(y - 5)
			var width := 6 if y >= 9 else (3 + tie / 2 if y > 5 else 4)
			if inner >= width:
				continue
			var fold := (x + (1 if x >= 8 else 0)) % 3
			var z := 2 if fold == 1 else 1
			var shade: int = [1, 3, 2][fold]
			if y <= 1:
				shade = 0
			grid.set_voxel(Vector3i(x, y, z), _v(LINEN[shade]))
			if fold == 1:
				grid.set_voxel(Vector3i(x, y, 1), _v(LINEN[1]))
		# The ties, darker.
		if inner < 4:
			grid.set_voxel(Vector3i(x, 5, 2 if (x % 3) == 1 else 1), _v(LINEN[0]))
	return grid


## A glass pane across the middle of its tile: a pale frame, clear inside
## but for a few glints.
static func glass_pane() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 16, 16))
	for z in range(7, 9):
		grid.box(Vector3i(0, 0, z), Vector3i(15, 0, z), _v(GLASS[0]))
		grid.box(Vector3i(0, 15, z), Vector3i(15, 15, z), _v(GLASS[1]))
		grid.box(Vector3i(0, 0, z), Vector3i(0, 15, z), _v(GLASS[1]))
		grid.box(Vector3i(15, 0, z), Vector3i(15, 15, z), _v(GLASS[0]))
	for start: Vector2i in [Vector2i(3, 5), Vector2i(9, 12), Vector2i(10, 4)]:
		for i in 3:
			grid.set_voxel(Vector3i(start.x + i, start.y - i, 8), _v(GLASS[2]))
	return grid


## A sink: a wooden cupboard with two doors, a stone top with its basin,
## an iron tap at the back.
static func sink() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(14, 16, 12))
	grid.box(Vector3i(0, 0, 0), Vector3i(13, 9, 11), _wood(0x51C4, WALNUT))
	grid.box(Vector3i(0, 0, 11), Vector3i(13, 0, 11), _v(WALNUT[0]))
	# Two doors: a frame, a seam, knobs.
	grid.box(Vector3i(1, 2, 11), Vector3i(12, 8, 11), _v(WALNUT[2]))
	grid.box(Vector3i(6, 2, 11), Vector3i(7, 8, 11), _v(WALNUT[1]))
	for x: int in [1, 12]:
		grid.box(Vector3i(x, 2, 11), Vector3i(x, 8, 11), _v(WALNUT[3]))
	grid.set_voxel(Vector3i(5, 6, 11), _v(IRON[3]))
	grid.set_voxel(Vector3i(8, 6, 11), _v(IRON[3]))
	# The stone top, the basin dug in it, water at its bottom.
	grid.box(Vector3i(0, 10, 0), Vector3i(13, 11, 11), _v(STONE[2]))
	grid.box(Vector3i(0, 11, 11), Vector3i(13, 11, 11), _v(STONE[3]))
	for x in range(3, 11):
		for z in range(3, 10):
			grid.set_voxel(Vector3i(x, 11, z), 0)
			grid.set_voxel(Vector3i(x, 10, z), _v(STONE[0]))
	grid.box(Vector3i(5, 10, 5), Vector3i(8, 10, 7), _v(WATER[0]))
	grid.set_voxel(Vector3i(6, 10, 5), _v(WATER[1]))
	# The tap: up from the back, over the basin.
	grid.box(Vector3i(6, 12, 1), Vector3i(7, 14, 1), _v(IRON[2]))
	grid.box(Vector3i(6, 14, 2), Vector3i(7, 14, 4), _v(IRON[2]))
	grid.box(Vector3i(6, 13, 4), Vector3i(7, 13, 4), _v(IRON[1]))
	grid.box(Vector3i(5, 15, 1), Vector3i(8, 15, 1), _v(IRON[3]))
	return grid


## A toilet: a white bowl on its foot, water in it, a wooden seat, the
## tank behind with its lid and a button.
static func toilet() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(10, 16, 14))
	# The foot, the bowl widening up to the seat.
	grid.box(Vector3i(3, 0, 5), Vector3i(6, 3, 11), _v(PORCELAIN[1]))
	for y in range(3, 7):
		var radius := Vector2(3.4 + (y - 3) * 0.35, 3.8 + (y - 3) * 0.3)
		for x in 10:
			for z in range(3, 14):
				var d := (Vector2(x + 0.5, z + 0.5) - Vector2(5.0, 8.5)) / radius
				if d.length_squared() <= 1.0:
					grid.set_voxel(Vector3i(x, y, z), _v(PORCELAIN[2 if y < 6 else 3]))
	# Hollow inside, water at the bottom.
	for x in range(3, 7):
		for z in range(6, 12):
			grid.set_voxel(Vector3i(x, 6, z), 0)
			grid.set_voxel(Vector3i(x, 5, z), _v(WATER[1] if z == 8 else WATER[0]))
	# The seat: a wooden ring on the bowl.
	for x in 10:
		for z in range(4, 14):
			var d := (Vector2(x + 0.5, z + 0.5) - Vector2(5.0, 8.5)) / Vector2(4.6, 5.1)
			var hole := (Vector2(x + 0.5, z + 0.5) - Vector2(5.0, 8.8)) / Vector2(2.2, 3.0)
			if d.length_squared() <= 1.0 and hole.length_squared() > 1.0:
				grid.set_voxel(Vector3i(x, 7, z), _v(WOOD[3] if z > 6 else WOOD[2]))
	# The tank at the back, its lid and the button.
	grid.box(Vector3i(0, 4, 0), Vector3i(9, 13, 3), _v(PORCELAIN[2]))
	grid.box(Vector3i(0, 4, 3), Vector3i(9, 4, 3), _v(PORCELAIN[1]))
	grid.box(Vector3i(0, 14, 0), Vector3i(9, 14, 4), _v(PORCELAIN[3]))
	grid.box(Vector3i(4, 15, 1), Vector3i(5, 15, 2), _v(IRON[3]))
	return grid


## A table: a top of boards on four legs, an apron under the top.
static func table() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 14, 16))
	grid.box(Vector3i(0, 12, 0), Vector3i(15, 13, 15), _wood(0x7AB1, WALNUT))
	for x: int in [0, 15]:
		grid.box(Vector3i(x, 12, 0), Vector3i(x, 12, 15), _v(WALNUT[1]))
	for z: int in [0, 15]:
		grid.box(Vector3i(0, 12, z), Vector3i(15, 12, z), _v(WALNUT[1]))
	for x in range(0, 16, 4):
		grid.box(Vector3i(x, 13, 0), Vector3i(x, 13, 15), _v(WALNUT[2]))
	grid.box(Vector3i(1, 10, 1), Vector3i(14, 11, 14), _v(WALNUT[1]))
	for x in range(3, 13):
		for z in range(3, 13):
			for y in range(10, 12):
				grid.set_voxel(Vector3i(x, y, z), 0)
	for x: int in [1, 13]:
		for z: int in [1, 13]:
			grid.box(Vector3i(x, 0, z), Vector3i(x + 1, 11, z + 1), _v(WALNUT[2]))
			grid.box(Vector3i(x + 1, 0, z), Vector3i(x + 1, 11, z + 1), _v(WALNUT[1]))
	return grid


## A chair: a seat on four legs, a back of two posts and rails (the back
## at -z, the seat open towards +z).
static func chair() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(12, 22, 12))
	grid.box(Vector3i(0, 8, 0), Vector3i(11, 9, 11), _wood(0xC4A1, WALNUT))
	grid.box(Vector3i(0, 8, 11), Vector3i(11, 8, 11), _v(WALNUT[1]))
	for x: int in [0, 10]:
		for z: int in [0, 10]:
			grid.box(Vector3i(x, 0, z), Vector3i(x + 1, 7, z + 1), _v(WALNUT[2]))
			grid.box(Vector3i(x + 1, 0, z), Vector3i(x + 1, 7, z + 1), _v(WALNUT[1]))
	for x: int in [0, 10]:
		grid.box(Vector3i(x, 10, 0), Vector3i(x + 1, 21, 1), _v(WALNUT[2]))
		grid.box(Vector3i(x + 1, 10, 0), Vector3i(x + 1, 21, 1), _v(WALNUT[1]))
	for y: int in [14, 19]:
		grid.box(Vector3i(2, y, 0), Vector3i(9, y + 1, 1), _v(WALNUT[3]))
		grid.box(Vector3i(2, y, 1), Vector3i(9, y, 1), _v(WALNUT[1]))
	grid.box(Vector3i(0, 21, 0), Vector3i(11, 21, 1), _v(WALNUT[4]))
	return grid


## A fence: a post with a cap, and two rails out to each side it joins
## (`sides`: ObjectShapes.FENCE_SIDES bits, north, east, south, west).
static func fence(sides: int) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 24, 16))
	grid.box(Vector3i(6, 0, 6), Vector3i(9, 22, 9), _v(WOOD[2]))
	grid.box(Vector3i(9, 0, 6), Vector3i(9, 22, 9), _v(WOOD[1]))
	grid.box(Vector3i(6, 0, 9), Vector3i(9, 22, 9), _v(WOOD[1]))
	grid.box(Vector3i(6, 23, 6), Vector3i(9, 23, 9), _v(WOOD[4]))
	grid.box(Vector3i(6, 0, 6), Vector3i(9, 1, 9), _v(WOOD[0]))
	for bit in ObjectShapes.FENCE_SIDES.size():
		if sides & (1 << bit) == 0:
			continue
		var side: Vector2i = ObjectShapes.FENCE_SIDES[bit]
		for y: int in [7, 16]:
			var from := Vector3i(7, y, 7)
			var to := Vector3i(8, y + 2, 8)
			if side.x > 0:
				from.x = 10
				to.x = 15
			elif side.x < 0:
				from.x = 0
				to.x = 5
			elif side.y > 0:
				from.z = 10
				to.z = 15
			else:
				from.z = 0
				to.z = 5
			grid.box(from, to, _v(WOOD[3]))
			grid.box(Vector3i(from.x, y, from.z), Vector3i(to.x, y, to.z), _v(WOOD[1]))
			grid.box(Vector3i(from.x, y + 2, from.z), Vector3i(to.x, y + 2, to.z), _v(WOOD[4]))
	return grid


## A wicket gate: a frame of rails and pickets with a brace, hinged on its
## left post; shut across its tile, open along its left side.
static func gate(open: bool) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 22, 16))
	for along in 16:
		for y in 21:
			var value := _gate_leaf(along, y, 16)
			if value == 0:
				continue
			for thick in 2:
				var at := Vector3i(along, y, 7 + thick)
				if open:
					# Swung about its left post, along the tile's left edge.
					at = Vector3i(thick, y, 15 - along)
				var shade := value if thick == 0 else maxi(value - 1, 0)
				grid.set_voxel(at, _v(WOOD[shade]))
	# Iron hinges on the left post, a latch on the right one.
	for y: int in [5, 16]:
		var hinge := Vector3i(0, y, 9) if not open else Vector3i(2, y, 15)
		grid.set_voxel(hinge, _v(IRON[2]))
	if not open:
		grid.box(Vector3i(14, 11, 9), Vector3i(15, 12, 9), _v(IRON[1]))
	return grid


## The shade (WOOD index; 0: nothing) of a gate leaf `width` wide at
## (along, y): posts at its ends, rails, pickets with pointed tops, a brace
## from the bottom of the hinge to the top of the latch.
static func _gate_leaf(along: int, y: int, width: int) -> int:
	var last := width - 1
	if along <= 1 or along >= last - 1:
		return 3 if along in [0, last] else 2
	if (y >= 3 and y <= 4) or (y >= 16 and y <= 17):
		return 3
	var brace := roundi(3.0 + (along - 2.0) / (last - 4.0) * 13.0)
	if absi(y - brace) <= 0 and y >= 3 and y <= 17:
		return 4
	var picket := (along - 2) % 4
	if picket <= 1 and y >= 2 and y <= 19 - (1 if picket == 1 else 0):
		return 2 if picket == 0 else 1
	return 0


## A big gate two tiles wide (32 voxels; drawn over both tiles): two
## leaves between stout posts with caps, rising to the middle; shut across
## them, or swung open towards -z (the grid is two tiles deep: the open
## leaves reach over the tile behind).
static func big_gate(open: bool) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(32, 28, 32))
	for x: int in [0, 29]:
		grid.box(Vector3i(x, 0, 14), Vector3i(x + 2, 25, 17), _v(WOOD[1]))
		grid.box(Vector3i(x, 0, 17), Vector3i(x + 2, 25, 17), _v(WOOD[0]))
		grid.box(Vector3i(x, 26, 13), Vector3i(x + 2, 27, 18), _v(WOOD[3]))
		grid.box(Vector3i(x, 27, 13), Vector3i(x + 2, 27, 18), _v(WOOD[4]))
	for side in 2:
		var hinge := 3 if side == 0 else 28
		var inward := 1 if side == 0 else -1
		for along in 13:
			var rise := 18 + roundi(4.0 * sin(PI * 0.5 * along / 12.0))
			for y in rise + 1:
				var value := _big_leaf(along, y, rise)
				if value == 0:
					continue
				for thick in 2:
					var at := Vector3i(hinge + along * inward, y, 15 + thick)
					if open:
						at = Vector3i(hinge + thick * inward, y, 14 - along)
					var shade := value if thick == 0 else maxi(value - 1, 0)
					grid.set_voxel(at, _v(WOOD[shade]))
			# Iron straps across the leaf, on its outer face.
			for y: int in [5, 15]:
				var strap := Vector3i(hinge + along * inward, y, 17)
				if open:
					strap = Vector3i(hinge + 2 * inward, y, 14 - along)
				grid.set_voxel(strap, _v(IRON[1] if along % 4 else IRON[2]))
	return grid


## The shade of a big gate's leaf at (along its 13 voxels from the post,
## y): a frame, boards, a cross brace.
static func _big_leaf(along: int, y: int, rise: int) -> int:
	if y >= rise - 1 or y <= 1 or along <= 0 or along >= 12:
		return 3
	if absi(y - roundi(2.0 + along * (rise - 4.0) / 12.0)) == 0:
		return 4
	return 2 if along % 3 else 1


## A campfire: a ring of stones, logs leaning together, embers at its
## heart and flames rising from them (they light themselves).
static func campfire() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(14, 14, 14))
	var center := Vector2(7.0, 7.0)
	for i in 12:
		var angle := TAU * i / 12.0
		var at := center + Vector2(cos(angle), sin(angle)) * 6.0
		var stone := _v(STONE[i % 3])
		grid.box(
			Vector3i(floori(at.x), 0, floori(at.y)), Vector3i(floori(at.x), 1, floori(at.y)), stone
		)
		grid.set_voxel(
			Vector3i(floori(at.x), 2, floori(at.y)), _v(STONE[(i + 1) % 4]) if i % 2 else 0
		)
	grid.disc(center, 4.6, 0, _v(ASH[0]))
	grid.disc(center, 2.6, 1, _v(EMBER[1], VoxelGrid.Kind.GLOW))
	# Logs leaning together over the fire.
	for i in 4:
		var angle := TAU * i / 4.0 + PI * 0.25
		var foot := center + Vector2(cos(angle), sin(angle)) * 5.0
		var top := center + Vector2(cos(angle), sin(angle)) * 1.0
		grid.line(Vector3(foot.x, 1.0, foot.y), Vector3(top.x, 7.0, top.y), 0.75, _v(WOOD[1]))
		grid.line(Vector3(foot.x, 1.5, foot.y), Vector3(top.x, 7.5, top.y), 0.4, _v(WOOD[2]))
		grid.set_voxel(Vector3i(floori(foot.x), 1, floori(foot.y)), _v(WOOD[4]))
	# Flames: narrowing tongues, red at their foot, pale at their tips.
	for tongue in 5:
		var angle := TAU * tongue / 5.0
		var base := center + Vector2(cos(angle), sin(angle)) * (1.4 if tongue else 0.0)
		var height := 9 if tongue == 0 else 6 + tongue % 3
		for y in range(2, 2 + height):
			var t := float(y - 2) / height
			var radius := 1.5 * (1.0 - t) + 0.4
			var sway := sin(t * PI * 1.5 + tongue) * 0.6
			var color: String = FIRE[mini(int(t * 4.0) + (1 if tongue == 0 else 0), 4)]
			grid.disc(base + Vector2(sway, 0.0), radius, y, _v(color, VoxelGrid.Kind.GLOW))
	return grid
