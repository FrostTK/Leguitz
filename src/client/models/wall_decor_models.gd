class_name WallDecorModels
extends RefCounted
## The voxel models of what hangs on a house's walls (phase 8, step 8; see
## Decor), their back against the wall (z = 0), front +z: a wall sconce
## (lit, its candle and glass glow), paintings and portraits (a version per
## picture, PaintingArt's, in a gilt or a walnut frame), a wall clock (its
## hands drawn live, LiveProps, at CLOCK_FACE), a mirror, a framed map (its
## canvas, MAP_CANVAS at MAP_DEPTH, drawn live with the surroundings), a
## stag's and a bear's head, a tapestry hanging down a level (PAINT: it
## takes a tint), a spice rack, a coat rack, a window box of flowers (three
## versions).

const WALNUT := DecorModels.WALNUT
const OAK := DecorModels.WOOD
const IRON := DecorModels.IRON
const LINEN := DecorModels.LINEN
const CLOTH := VoxelGrid.Kind.PAINT
const GLOW := VoxelGrid.Kind.GLOW
const BRASS := AmbianceModels.BRASS
const GILT := ["#8a6424", "#b08a3a", "#d9b45a", "#f0d890"]
const MIRROR := ["#7a909c", "#a8bcc6", "#c8d8e0", "#eef6fa"]
const PARCHMENT := ["#b8a478", "#d9c79a"]
const FUR := ["#4a2e1c", "#6a4428", "#8a5a34", "#b07a4a"]
const BEAR := ["#2e2018", "#3e2c20", "#523a2a", "#6a4c36"]
const ANTLER := ["#a8946a", "#d8c8a0", "#efe4c6"]
const SPICES := ["#b8402a", "#d9a21c", "#5a8a3a", "#3a3030", "#efeae0", "#8a4a24"]
## A window box's flowers, by version: red and white, yellow and blue, pinks.
const BOX_FLOWERS := [["#c4283a", "#efeae0"], ["#e6c25a", "#4a6ee0"], ["#e391a8", "#f0b8c8"]]
## Where a wall clock's face is (voxels: its middle, in front).
const CLOCK_FACE := Vector3(8.0, 9.0, 2.2)
## A framed map's canvas (voxels: x, y, width, height) and how far it is
## from the wall (its front).
const MAP_CANVAS := Rect2i(1, 2, 14, 12)
const MAP_DEPTH := 1.0
const KINDS := [
	Tiles.Block.WALL_SCONCE,
	Tiles.Block.WALL_SCONCE_OUT,
	Tiles.Block.PAINTING,
	Tiles.Block.PORTRAIT,
	Tiles.Block.WALL_CLOCK,
	Tiles.Block.MIRROR,
	Tiles.Block.FRAMED_MAP,
	Tiles.Block.DEER_TROPHY,
	Tiles.Block.BEAR_TROPHY,
	Tiles.Block.TAPESTRY,
	Tiles.Block.SPICE_RACK,
	Tiles.Block.COAT_RACK,
	Tiles.Block.WINDOW_BOX,
]


## The model of a block (null: not one of these).
static func build(block: int, variant: int) -> VoxelGrid:
	match ObjectShapes.kind_of(block):
		Tiles.Block.WALL_SCONCE:
			return sconce(true)
		Tiles.Block.WALL_SCONCE_OUT:
			return sconce(false)
		Tiles.Block.PAINTING:
			return picture(PaintingArt.landscape(variant), variant % 2 == 0)
		Tiles.Block.PORTRAIT:
			return picture(PaintingArt.portrait(variant), true)
		Tiles.Block.WALL_CLOCK:
			return wall_clock()
		Tiles.Block.MIRROR:
			return mirror()
		Tiles.Block.FRAMED_MAP:
			return framed_map()
		Tiles.Block.DEER_TROPHY:
			return deer_trophy()
		Tiles.Block.BEAR_TROPHY:
			return bear_trophy()
		Tiles.Block.TAPESTRY:
			return tapestry()
		Tiles.Block.SPICE_RACK:
			return spice_rack()
		Tiles.Block.COAT_RACK:
			return coat_rack()
		Tiles.Block.WINDOW_BOX:
			return window_box(variant)
	return null


## The color of a block's chips (BlockColors; Color(0, 0, 0, 0): not one).
static func color_of(kind: int) -> Color:
	if not kind in KINDS:
		return Color(0, 0, 0, 0)
	match kind:
		Tiles.Block.WALL_SCONCE, Tiles.Block.WALL_SCONCE_OUT:
			return Color(BRASS[1])
		Tiles.Block.MIRROR:
			return Color(MIRROR[2])
		Tiles.Block.TAPESTRY:
			return Color(LINEN[2])
		Tiles.Block.BEAR_TROPHY:
			return Color(BEAR[2])
		Tiles.Block.PAINTING, Tiles.Block.PORTRAIT:
			return Color(GILT[2])
	return Color(WALNUT[2])


## A wall sconce: a brass plate, an arm, a candle in a glass tulip (lit:
## glowing).
static func sconce(lit: bool) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 16, 16))
	grid.box(Vector3i(6, 5, 0), Vector3i(9, 12, 0), _v(BRASS[1]))
	grid.box(Vector3i(7, 6, 0), Vector3i(8, 11, 0), _v(BRASS[2]))
	grid.box(Vector3i(7, 7, 1), Vector3i(8, 7, 3), _v(BRASS[0]))
	grid.box(Vector3i(6, 8, 3), Vector3i(9, 8, 6), _v(BRASS[1]))
	grid.box(Vector3i(7, 9, 4), Vector3i(8, 11, 5), _v(AmbianceModels.WAX[1]))
	grid.set_voxel(Vector3i(7, 12, 4), _v("#2a2420"))
	if lit:
		grid.set_voxel(Vector3i(7, 13, 4), _v(DecorModels.FIRE[3], GLOW))
		grid.set_voxel(Vector3i(7, 14, 4), _v(DecorModels.FIRE[4], GLOW))
	var glass := _v("#ffe6a4", GLOW) if lit else _v("#d4ebf0")
	for y in range(10, 15):
		for x: int in [5, 10]:
			grid.set_voxel(Vector3i(x, y, 4 + (y % 2)), glass)
		for z: int in [2, 7]:
			grid.set_voxel(Vector3i(7 + (y % 2), y, z), glass)
	return grid


## A picture (rows of colors, the top first) in a frame, gilt or walnut,
## standing out from the wall.
static func picture(rows: Array, gilt: bool) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 16, 16))
	var high := rows.size()
	var wide := (rows[0] as Array).size()
	var x0 := (16 - wide) / 2
	var y0 := 15 - high
	var frame: Array = GILT if gilt else WALNUT
	for y in range(y0 - 1, y0 + high + 1):
		for x in range(x0 - 1, x0 + wide + 1):
			var edge := y == y0 - 1 or y == y0 + high or x == x0 - 1 or x == x0 + wide
			if edge:
				var hex: String = frame[3] if y == y0 + high or x == x0 - 1 else frame[1]
				grid.box(Vector3i(x, y, 0), Vector3i(x, y, 1), _v(hex))
	for row in high:
		var colors: Array = rows[row]
		for x in wide:
			var color: Color = colors[x]
			grid.set_voxel(Vector3i(x0 + x, y0 + high - 1 - row, 0), VoxelGrid.voxel(color))
	return grid


## A round wall clock: a walnut case, a brass rim, a cream face and its
## hour marks (the hands: LiveProps).
static func wall_clock() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 16, 16))
	var center := Vector2(CLOCK_FACE.x, CLOCK_FACE.y)
	for y in 16:
		for x in 16:
			var d := (Vector2(x + 0.5, y + 0.5) - center).length()
			if d <= 6.4:
				grid.set_voxel(Vector3i(x, y, 0), _v(WALNUT[1]))
			if d <= 6.4 and d > 5.4:
				grid.set_voxel(Vector3i(x, y, 1), _v(BRASS[1] if y > center.y else BRASS[2]))
			elif d <= 5.4:
				grid.set_voxel(Vector3i(x, y, 1), _v("#f2ead6"))
	for mark: Vector2i in [Vector2i(0, 4), Vector2i(4, 0), Vector2i(0, -5), Vector2i(-5, 0)]:
		grid.set_voxel(Vector3i(8 + mark.x, 9 + mark.y, 1), _v("#2a2024"))
	grid.set_voxel(Vector3i(7, 8, 1), _v(BRASS[0]))
	return grid


## An oval mirror in a gilt frame: silvered glass catching the light.
static func mirror() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 16, 16))
	for y in 16:
		for x in 16:
			var d := Vector2((x + 0.5 - 8.0) / 5.5, (y + 0.5 - 8.5) / 7.5).length()
			if d > 1.0:
				continue
			if d > 0.84:
				grid.box(Vector3i(x, y, 0), Vector3i(x, y, 1), _v(GILT[1 + (x + y) % 2]))
				continue
			var streak := posmod(x + y, 9) in [0, 1] and absi(x - y) < 8
			var hex: String = MIRROR[3] if streak else MIRROR[2 if y > 8 else 1]
			grid.set_voxel(Vector3i(x, y, 0), _v(hex))
	grid.set_voxel(Vector3i(8, 15, 1), _v(GILT[3]))
	return grid


## A framed map: a walnut frame around a parchment canvas (its map:
## LiveProps).
static func framed_map() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 16, 16))
	var canvas := MAP_CANVAS
	grid.box(Vector3i(0, canvas.position.y - 1, 0), Vector3i(15, canvas.end.y, 1), _v(WALNUT[2]))
	grid.box(Vector3i(0, canvas.end.y, 0), Vector3i(15, canvas.end.y, 1), _v(WALNUT[3]))
	var paper := func(p: Vector3i) -> int: return _v(PARCHMENT[(p.x + p.y) % 2])
	for y in range(canvas.position.y, canvas.end.y):
		for x in range(canvas.position.x, canvas.end.x):
			grid.set_voxel(Vector3i(x, y, 1), 0)
			grid.set_voxel(Vector3i(x, y, 0), paper.call(Vector3i(x, y, 0)))
	return grid


## A stag's head on a walnut shield: its neck, muzzle, ears and antlers.
static func deer_trophy() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 16, 16))
	_shield(grid)
	grid.ellipsoid(Vector3(8, 7.5, 3.5), Vector3(2.6, 3.0, 2.2), _v(FUR[2]))
	grid.ellipsoid(Vector3(8, 8.5, 6.5), Vector3(2.2, 2.0, 2.4), _v(FUR[3]))
	grid.box(Vector3i(7, 7, 8), Vector3i(8, 8, 10), _v(FUR[2]))
	grid.box(Vector3i(7, 7, 11), Vector3i(8, 7, 11), _v("#2a2024"))
	grid.set_voxel(Vector3i(6, 9, 8), _v("#1e1a1c"))
	grid.set_voxel(Vector3i(9, 9, 8), _v("#1e1a1c"))
	for side: int in [-1, 1]:
		grid.set_voxel(Vector3i(8 + side * 3, 10, 6), _v(FUR[1]))
		var base := Vector3(8 + side * 1.5, 10.5, 6)
		grid.line(base, base + Vector3(side * 3.0, 3.0, 0.0), 0.0, _v(ANTLER[1]))
		grid.line(
			base + Vector3(side * 3.0, 3.0, 0),
			base + Vector3(side * 5.5, 5.0, 0),
			0.0,
			_v(ANTLER[2])
		)
		grid.line(
			base + Vector3(side * 2.0, 2.0, 0),
			base + Vector3(side * 2.0, 5.0, 0),
			0.0,
			_v(ANTLER[0])
		)
		grid.line(
			base + Vector3(side * 4.0, 4.0, 0),
			base + Vector3(side * 6.0, 3.0, 0),
			0.0,
			_v(ANTLER[1])
		)
	return grid


## A bear's head on a walnut shield: its round ears, muzzle, open mouth.
static func bear_trophy() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 16, 16))
	_shield(grid)
	grid.ellipsoid(Vector3(8, 8.5, 4.5), Vector3(4.3, 4.0, 3.6), _v(BEAR[2]))
	for side: int in [-1, 1]:
		grid.ellipsoid(Vector3(8 + side * 3.5, 12.0, 3.5), Vector3(1.4, 1.4, 1.0), _v(BEAR[1]))
		grid.set_voxel(Vector3i(8 + side * 2 - (1 if side < 0 else 0), 9, 7), _v("#e0b030"))
	grid.ellipsoid(Vector3(8, 6.5, 8.0), Vector3(2.4, 1.8, 2.0), _v(BEAR[3]))
	grid.box(Vector3i(7, 7, 9), Vector3i(8, 7, 10), _v("#1a1214"))
	grid.box(Vector3i(6, 4, 7), Vector3i(9, 5, 9), _v("#6a2a2a"))
	for x: int in [6, 9]:
		grid.set_voxel(Vector3i(x, 5, 9), _v("#f2eee2"))
		grid.set_voxel(Vector3i(x, 4, 9), _v("#f2eee2"))
	return grid


## A tapestry two levels long hanging from a rod: woven cloth (PAINT), its
## border and a tree of life in darker thread, a fringe.
static func tapestry() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 32, 16))
	grid.box(Vector3i(0, 30, 1), Vector3i(15, 30, 1), _v(WALNUT[2]))
	for x: int in [0, 15]:
		grid.set_voxel(Vector3i(x, 30, 2), _v(WALNUT[3]))
	var weave := func(p: Vector3i) -> int:
		var border := p.x <= 2 or p.x >= 13 or p.y <= 4 or p.y >= 27
		var trunk := absi(p.x * 2 - 15) <= 1 and p.y < 22
		var branch := absi(absi(p.x * 2 - 15) - (p.y - 12) * 1) <= 1 and p.y >= 12 and p.y < 22
		var crown := Vector2(p.x - 7.5, (p.y - 21.0) * 1.2).length() < 4.5
		var hex: String = LINEN[2 + (p.x + p.y) % 2]
		if border:
			hex = LINEN[1] if (p.x + p.y) % 4 else LINEN[0]
		elif trunk or branch:
			hex = LINEN[0]
		elif crown:
			hex = LINEN[1]
		return _v(hex, CLOTH)
	grid.box(Vector3i(1, 2, 0), Vector3i(14, 29, 0), weave)
	for x in range(1, 15, 2):
		grid.box(Vector3i(x, 0, 0), Vector3i(x, 1, 0), _v(LINEN[1], CLOTH))
	grid.keep_detail = true
	return grid


## A spice rack: two shelves of little jars, their colors and corks.
static func spice_rack() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 16, 16))
	grid.box(Vector3i(2, 3, 0), Vector3i(13, 14, 0), _v(OAK[2]))
	for shelf: int in [3, 9]:
		grid.box(Vector3i(2, shelf, 1), Vector3i(13, shelf, 3), _v(OAK[3]))
		grid.box(Vector3i(2, shelf + 2, 4), Vector3i(13, shelf + 2, 4), _v(OAK[1]))
		for jar in 4:
			var x := 3 + jar * 3
			var spice := _v(SPICES[(jar + shelf) % SPICES.size()])
			grid.box(Vector3i(x, shelf + 1, 1), Vector3i(x + 1, shelf + 3, 2), spice)
			grid.box(Vector3i(x, shelf + 4, 1), Vector3i(x + 1, shelf + 4, 2), _v("#b08a5a"))
	return grid


## A coat rack: a board of pegs, a coat, a striped scarf and a hat on them.
static func coat_rack() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 16, 16))
	grid.box(Vector3i(0, 11, 0), Vector3i(15, 12, 0), _v(OAK[2]))
	for x: int in [3, 8, 13]:
		grid.box(Vector3i(x, 11, 1), Vector3i(x, 11, 2), _v(OAK[1]))
	grid.box(Vector3i(1, 2, 1), Vector3i(5, 10, 2), _v("#7e2a38"))
	grid.box(Vector3i(2, 9, 3), Vector3i(4, 10, 3), _v("#6a2230"))
	grid.box(Vector3i(0, 4, 1), Vector3i(0, 9, 2), _v("#6a2230"))
	grid.box(Vector3i(6, 9, 1), Vector3i(6, 9, 2), _v("#e6c25a"))
	var stripes := func(p: Vector3i) -> int: return _v("#3e6aa8" if p.y % 2 else "#efeae0")
	grid.box(Vector3i(7, 3, 2), Vector3i(8, 10, 2), stripes)
	grid.box(Vector3i(11, 11, 1), Vector3i(15, 11, 5), _v("#4a3020"))
	grid.box(Vector3i(12, 12, 2), Vector3i(14, 14, 4), _v("#5a3a24"))
	grid.box(Vector3i(12, 12, 4), Vector3i(14, 12, 4), _v("#8a2a24"))
	return grid


## A window box under a window: a planter of earth and flowers (versions:
## red and white, yellow and blue, pink geraniums).
static func window_box(variant: int) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 20, 16))
	grid.box(Vector3i(0, 9, 0), Vector3i(15, 13, 5), _v(OAK[2]))
	grid.box(Vector3i(0, 13, 0), Vector3i(15, 13, 5), _v(OAK[3]))
	grid.box(Vector3i(1, 13, 1), Vector3i(14, 13, 4), _v(AmbianceModels.SOIL[0]))
	for x: int in [1, 14]:
		grid.box(Vector3i(x, 7, 0), Vector3i(x, 8, 2), _v(IRON[1]))
	var petals: Array = BOX_FLOWERS[posmod(variant, BOX_FLOWERS.size())]
	var leaf := _v(AmbianceModels.LEAF[2], VoxelGrid.Kind.FOLIAGE)
	for i in 7:
		var x := 1 + i * 2
		var z := 2 + (i % 2)
		var top := 16 + (i * 5) % 3
		grid.box(
			Vector3i(x, 14, z),
			Vector3i(x, top - 1, z),
			_v(AmbianceModels.LEAF[1], VoxelGrid.Kind.FOLIAGE)
		)
		grid.set_voxel(Vector3i(x + 1, 15, z), leaf)
		var color: String = petals[i % 2]
		for d: Vector3i in [
			Vector3i.ZERO, Vector3i.LEFT, Vector3i.RIGHT, Vector3i(0, 0, 1), Vector3i.UP
		]:
			grid.set_voxel(Vector3i(x, top, z) + d, _v(color, VoxelGrid.Kind.FOLIAGE))
	grid.sway = 0.4
	grid.sway_from = 14
	return grid


## A walnut shield a trophy hangs on.
static func _shield(grid: VoxelGrid) -> void:
	for y in range(2, 15):
		for x in range(3, 13):
			var narrow := maxi(0, 5 - y) if y < 5 else 0
			if x >= 3 + narrow and x <= 12 - narrow:
				grid.set_voxel(Vector3i(x, y, 0), _v(WALNUT[2 if (x + y) % 5 else 1]))
	grid.box(Vector3i(3, 14, 0), Vector3i(12, 14, 1), _v(WALNUT[3]))


static func _v(hex: String, kind := VoxelGrid.Kind.SOLID) -> int:
	return VoxelGrid.voxel(Color(hex), kind)
