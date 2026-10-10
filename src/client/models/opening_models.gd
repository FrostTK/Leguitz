class_name OpeningModels
extends RefCounted
## The voxel models of doors, trapdoors, ladders, shutters, bars and
## railings (phase 8, step 4; see Openings). DecorModels' ways: front +z,
## what hangs on a wall with its back at z = 0. A door is two levels tall
## (16 x 32), its board at the front of its cell (flush with the wall it
## stands in, on the side it was placed from), hung on its left (version
## 0) or right (1, the other half of a double door); open, it stands along
## that side. A trapdoor lies at the top of its cell, open it stands
## against its cube. Shutters' leaves are cloth-like PAINT (dyed with a
## tint); open they lie on the wall either side of the window (32 wide).
## Bars and railings join their neighbors (FENCE_SIDES bits, as fences).

## Each door's wood (dark to light, as DecorModels.WOOD), or iron.
const WOODS := {
	"OAK": ["#5e3d22", "#8a6034", "#b8874f", "#d3a56c", "#e4bd86"],
	"BIRCH": ["#8f7a4c", "#b39a62", "#dcc68f", "#efdcab", "#f8ead0"],
	"SPRUCE": ["#4c3119", "#714c29", "#9c6e42", "#b98a5b", "#cda177"],
	"DARK_OAK": ["#2e1c0e", "#4a2f19", "#6e4a2b", "#87603b", "#a07650"],
	"JUNGLE": ["#5e3b22", "#8a5c39", "#b9825a", "#d29d74", "#e2b48f"],
	"ACACIA": ["#6c2e13", "#924522", "#c0663a", "#d9845a", "#e9a27c"],
	"GLAZED": ["#5e3d22", "#8a6034", "#b8874f", "#d3a56c", "#e4bd86"],
	"IRON": ["#1e1f24", "#2e2f35", "#4b4d55", "#6f727c", "#9a9ea8"],
}
const GLASS := ["#8fb3be", "#b9d6de", "#e2f1f4"]
const BRASS := ["#8a6a24", "#c9a24a", "#ecd27e"]
## Shutters undyed: a soft grey-green paint over wood.
const SHUTTER := ["#4e5a4c", "#6b7a68", "#8a9a86", "#a8b6a3"]
const HINGE := "#2e2f35"
## A door's board: its depth (voxels) from the back of its cell.
const BOARD := [12, 14]


## The model of a block (null: not one of these).
static func build(block: int, variant: int) -> VoxelGrid:
	if Openings.is_door(block):
		var kind := ObjectShapes.pair_of(ObjectShapes.base_kind(block))
		var material := String(Tiles.Block.find_key(kind)).trim_suffix("_DOOR")
		return door(material, variant == 1, ObjectShapes.is_open(block))
	if Openings.is_trapdoor(block):
		var iron := ObjectShapes.pair_of(ObjectShapes.base_kind(block)) == Tiles.Block.IRON_TRAPDOOR
		return trapdoor(iron, ObjectShapes.is_open(block))
	if Openings.is_ladder(block):
		return ladder()
	var kind := ObjectShapes.kind_of(block)
	if kind == Tiles.Block.SHUTTERS or kind == Tiles.Block.SHUTTERS_CLOSED:
		return shutters(kind == Tiles.Block.SHUTTERS_CLOSED)
	match block:
		Tiles.Block.IRON_BARS:
			return bars(variant)
		Tiles.Block.WOOD_RAILING:
			return railing(false, variant)
		Tiles.Block.IRON_RAILING:
			return railing(true, variant)
	return null


## The color of a block's chips (BlockColors; Color(0, 0, 0, 0): not one).
static func color_of(kind: int) -> Color:
	if Openings.is_door(kind):
		var name := String(Tiles.Block.find_key(ObjectShapes.pair_of(kind)))
		return Color(WOODS.get(name.trim_suffix("_DOOR"), WOODS["OAK"])[2])
	if Openings.is_trapdoor(kind) or Openings.is_ladder(kind):
		return Color(WOODS["OAK"][2])
	if ObjectShapes.kind_of(kind) in [Tiles.Block.SHUTTERS, Tiles.Block.SHUTTERS_CLOSED]:
		return Color(SHUTTER[2])
	if kind in [Tiles.Block.IRON_BARS, Tiles.Block.IRON_RAILING]:
		return Color(WOODS["IRON"][2])
	if kind == Tiles.Block.WOOD_RAILING:
		return Color(WOODS["OAK"][2])
	return Color(0, 0, 0, 0)


static func _v(hex: String, kind := VoxelGrid.Kind.SOLID) -> int:
	return VoxelGrid.voxel(Color(hex), kind)


## A door of `material` (WOODS' names), hung on its right (else left),
## open (swung in, along its hinge's side) or shut (at the front of its
## cell).
static func door(material: String, right: bool, open: bool) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 32, 16))
	grid.keep_detail = true
	var wood: Array = WOODS[material]
	for y in 32:
		for x in 16:
			var hex := _door_pixel(material, wood, x, y)
			if hex == "":
				continue
			for z in range(BOARD[0], BOARD[1] + 1):
				var shade: String = hex if z == BOARD[0] or z == BOARD[1] else wood[1]
				_put_door(grid, x, y, z, _v(shade), right, open)
	# Knobs on both sides, away from the hinge.
	var knob := _v(BRASS[1] if material != "IRON" else wood[4])
	for y: int in [14, 15]:
		for z: int in [BOARD[0] - 1, BOARD[1] + 1]:
			_put_door(grid, 12, y, z, knob, right, open)
	return grid


## Puts a voxel of a door's board, given shut and hung on its left, where
## it goes hung on its `right` or `open` (turned about its hinge).
static func _put_door(
	grid: VoxelGrid, x: int, y: int, z: int, voxel: int, right: bool, open: bool
) -> void:
	var at := Vector3i(x, y, z)
	if open:
		# Turned about its hinge, the front corner on its left.
		at = Vector3i(15 - z, y, 15 - x)
	if right:
		at.x = 15 - at.x
	grid.set_voxel(at, voxel)


## A door's front pixel (x from its hinge, y up; "" for none: its glass or
## grille's gaps): each wood its own design.
static func _door_pixel(material: String, wood: Array, x: int, y: int) -> String:
	var frame := x <= 1 or x >= 14 or y <= 1 or y >= 30
	if frame:
		return wood[1] if x == 0 or y == 0 else wood[2]
	match material:
		"OAK":
			# Four raised panels.
			var rail := y == 15 or y == 16 or x == 7 or x == 8
			if rail:
				return wood[2]
			var edge := x == 2 or x == 9 or y == 2 or y == 17
			return wood[3] if edge else wood[1]
		"BIRCH":
			# Boards, a small window up high.
			if x >= 5 and x <= 10 and y >= 22 and y <= 27:
				return GLASS[1] if (x + y) % 5 else GLASS[2]
			if x >= 4 and x <= 11 and y >= 21 and y <= 28:
				return wood[1]
			return wood[2] if x % 4 == 1 else wood[3]
		"SPRUCE":
			# Rustic boards, battens and a brace (a Z).
			if y == 5 or y == 6 or y == 25 or y == 26:
				return wood[3]
			if absi(x - (2 + (y - 7) * 11 / 17)) <= 1 and y > 6 and y < 25:
				return wood[3]
			return wood[1] if x % 3 == 2 else wood[2]
		"DARK_OAK":
			# Two tall panels, iron studs.
			if (y == 4 or y == 27) and x % 3 == 1:
				return WOODS["IRON"][3]
			if x == 7 or x == 8:
				return wood[2]
			return wood[1] if x == 2 or x == 13 or y == 2 or y == 29 else wood[0]
		"JUNGLE":
			# Slats in two frames.
			if y == 15 or y == 16:
				return wood[2]
			return wood[3] if y % 2 == 0 else wood[1]
		"ACACIA":
			# Two panels, the upper one with a round-topped window.
			var dx := x - 7.5
			if (
				y >= 18
				and y <= 27
				and absf(dx) <= 3.5
				and (y < 25 or dx * dx + (y - 24) * (y - 24) <= 14.0)
			):
				return GLASS[1] if (x + y) % 4 else GLASS[2]
			if y == 15 or y == 16:
				return wood[2]
			return wood[3] if x == 2 or x == 13 or y == 2 else wood[1]
		"GLAZED":
			# A panel below, six panes above.
			if y >= 12 and y <= 29:
				var bar := x == 7 or x == 8 or y == 12 or y == 18 or y == 19 or y == 24 or y == 25
				if bar:
					return wood[2]
				return GLASS[1] if (x + 2 * y) % 7 else GLASS[2]
			return wood[3] if x == 2 or x == 13 or y == 2 or y == 11 else wood[1]
		"IRON":
			# Riveted plates, a grille up high.
			if y >= 21 and y <= 28 and x >= 3 and x <= 12:
				return "" if x % 3 != 0 else wood[2]
			if (x == 3 or x == 12) and y % 4 == 2:
				return wood[4]
			return wood[2] if y == 15 or y == 16 else wood[1]
	return wood[2]


## A trapdoor (wood or `iron`) at the top of its cell, its hinge at the
## back (its cube); `open`, it stands against that cube.
static func trapdoor(iron: bool, open: bool) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 16, 16))
	grid.keep_detail = true
	var wood: Array = WOODS["IRON" if iron else "OAK"]
	for z in 16:
		for x in 16:
			var hex: String = wood[2]
			if x <= 0 or x >= 15 or z <= 0 or z >= 15:
				hex = wood[1]
			elif iron:
				hex = wood[4] if (x == 3 or x == 12) and z % 4 == 2 else wood[1]
			elif z == 3 or z == 12:
				hex = wood[3]
			elif x % 4 == 0:
				hex = wood[1]
			for y in range(13, 16):
				var at := Vector3i(x, y, z)
				if open:
					at = Vector3i(x, 15 - z, 15 - y)
				grid.set_voxel(at, _v(hex if y == 15 or y == 13 else wood[1]))
	# A ring to pull it by, at its free edge.
	var ring := Vector3i(7, 12, 13) if not open else Vector3i(7, 2, 3)
	grid.box(ring, ring + Vector3i(1, 0, 0), _v(WOODS["IRON"][3]))
	return grid


## A ladder against a wall: two rails, rungs.
static func ladder() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 16, 16))
	grid.keep_detail = true
	var wood: Array = WOODS["OAK"]
	for x: int in [2, 13]:
		grid.box(Vector3i(x, 0, 0), Vector3i(x, 15, 1), _v(wood[1]))
		grid.box(Vector3i(x, 0, 1), Vector3i(x, 15, 1), _v(wood[2]))
	for y: int in [2, 6, 10, 14]:
		grid.box(Vector3i(3, y, 1), Vector3i(12, y, 1), _v(wood[3]))
		grid.box(Vector3i(3, y, 0), Vector3i(12, y, 0), _v(wood[1]))
	return grid


## Shutters outside a window: two louvered leaves (PAINT: dyed), `drawn`
## across it, else open on the wall either side (the grid is 32 wide,
## its middle on the window).
static func shutters(drawn: bool) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(32, 16, 16))
	grid.keep_detail = true
	grid.pivot = Vector2(16.0, 8.0)
	var cloth := VoxelGrid.Kind.PAINT
	for leaf in 2:
		var from := 8 + leaf * 8 if drawn else (0 if leaf == 0 else 24)
		for y in range(0, 16):
			for x in range(from, from + 8):
				var u := x - from
				var hex: String = SHUTTER[2]
				if u == 0 or u == 7 or y == 0 or y == 15:
					hex = SHUTTER[1]
				elif y % 2 == 1:
					hex = SHUTTER[3]
				var depth := 1 if not (u > 0 and u < 7 and y > 0 and y < 15 and y % 2 == 1) else 2
				for z in range(0, depth + 1):
					grid.set_voxel(Vector3i(x, y, z), _v(hex if z == depth else SHUTTER[0], cloth))
		# Iron hinges on the leaf's outer side.
		var hinge_x := (
			(from if leaf == 0 else from + 7) if drawn else (from + 7 if leaf == 0 else from)
		)
		for y: int in [3, 12]:
			grid.set_voxel(Vector3i(hinge_x, y, 2), _v(HINGE))
	return grid


## Wrought iron bars: a post, and bars towards the sides they join
## (`sides`: FENCE_SIDES bits; none: across east to west).
static func bars(sides: int) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 16, 16))
	grid.keep_detail = true
	var iron: Array = WOODS["IRON"]
	if sides == 0:
		sides = 2 | 8
	grid.box(Vector3i(7, 0, 7), Vector3i(8, 15, 8), _v(iron[2]))
	for bit in ObjectShapes.FENCE_SIDES.size():
		if sides & (1 << bit) == 0:
			continue
		var side: Vector2i = ObjectShapes.FENCE_SIDES[bit]
		for step in range(1, 9):
			var at := Vector2i(7, 7) + side * step
			if side.x > 0 or side.y > 0:
				at = Vector2i(8, 8) + side * step
			at = at.clamp(Vector2i.ZERO, Vector2i(15, 15))
			for y: int in [1, 14]:
				grid.set_voxel(Vector3i(at.x, y, at.y), _v(iron[1]))
			if step % 3 == 0:
				grid.box(Vector3i(at.x, 0, at.y), Vector3i(at.x, 15, at.y), _v(iron[2]))
				grid.set_voxel(Vector3i(at.x, 15, at.y), _v(iron[3]))
	return grid


## A railing (wood, or wrought `iron`): a post, a handrail and balusters
## towards the sides it joins (none: east to west).
static func railing(iron: bool, sides: int) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 16, 16))
	grid.keep_detail = true
	var wood: Array = WOODS["IRON" if iron else "OAK"]
	if sides == 0:
		sides = 2 | 8
	var top := 13 if not iron else 12
	grid.box(Vector3i(7, 0, 7), Vector3i(8, top + 1, 8), _v(wood[1]))
	grid.box(Vector3i(7, top + 1, 7), Vector3i(8, top + 1, 8), _v(wood[3]))
	for bit in ObjectShapes.FENCE_SIDES.size():
		if sides & (1 << bit) == 0:
			continue
		var side: Vector2i = ObjectShapes.FENCE_SIDES[bit]
		for step in range(1, 9):
			var at := Vector2i(7, 7) + side * step
			if side.x > 0 or side.y > 0:
				at = Vector2i(8, 8) + side * step
			at = at.clamp(Vector2i.ZERO, Vector2i(15, 15))
			# The handrail, two voxels wide in wood.
			grid.set_voxel(Vector3i(at.x, top, at.y), _v(wood[3]))
			grid.set_voxel(Vector3i(at.x, top - 1, at.y), _v(wood[2]))
			grid.set_voxel(Vector3i(at.x, 1, at.y), _v(wood[1]))
			if step % 3 == 0:
				grid.box(Vector3i(at.x, 2, at.y), Vector3i(at.x, top - 2, at.y), _v(wood[2]))
				if iron:
					# A scroll between the balusters.
					var mid := at - side
					grid.set_voxel(Vector3i(mid.x, 5, mid.y), _v(wood[3]))
					grid.set_voxel(Vector3i(mid.x, 8, mid.y), _v(wood[3]))
	return grid
