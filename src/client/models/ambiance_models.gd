class_name AmbianceModels
extends RefCounted
## The voxel models of a house's ambiance (phase 8, step 8; see Decor,
## Hearths), DecorModels' ways (front +z, standing on y = 0): lights (a
## candle, a candelabra, a chandelier hanging from the top of its cell, a
## bedside lamp with a shade of cloth; lit, their flames and glass light
## themselves: GLOW), a fireplace two tiles wide and a stove (a fire
## burning in them, lit; logs and ash, out), a cushion, a flower pot (its
## versions: empty, then holding each plant of Decor.POTTED, the plant's
## own model), house plants, a bathtub two tiles wide, a shower (two levels
## high; running, its water falls), a washbasin, a grandfather clock (two
## levels), a toy chest, a piano two tiles wide, a cradle, a folding screen
## (two levels). Cloth (PAINT) takes a tint. The hands of the clocks, the
## pendulum and the shower's drops are drawn live (LiveProps), at
## TALL_CLOCK_FACE, PENDULUM and SHOWER_HEAD (model voxels).

const WALNUT := DecorModels.WALNUT
const OAK := DecorModels.WOOD
const IRON := DecorModels.IRON
const STONE := DecorModels.STONE
const PORCELAIN := DecorModels.PORCELAIN
const LINEN := DecorModels.LINEN
const FIRE := DecorModels.FIRE
const ASH := DecorModels.ASH
const EMBER := DecorModels.EMBER
const CLOTH := VoxelGrid.Kind.PAINT
const GLOW := VoxelGrid.Kind.GLOW
const BRASS := ["#8a6a24", "#c9a24a", "#ecd27e"]
const WAX := ["#d9cba6", "#efe4c6", "#fbf5e2"]
const BRICK := ["#7a3424", "#98432c", "#b45a3a"]
const MORTAR := "#b9ad9c"
const CLAY := ["#93432a", "#b45a36", "#cf7546"]
const SOIL := ["#3a2a1e", "#4e3828"]
const LEAF := ["#2f6a2e", "#3f8a3a", "#5aa848", "#7cc65a"]
const WATER := ["#5a9ec8", "#8cc4e4"]
const KEYS := ["#f4f1e8", "#1e1c20"]
## Where the live parts of the models are (voxels).
const TALL_CLOCK_FACE := Vector3(8.0, 25.0, 12.0)
const PENDULUM := Vector3(8.0, 19.5, 11.5)
const SHOWER_HEAD := Vector3(8.0, 26.0, 7.0)
## Every kind with a model here.
const KINDS := [
	Tiles.Block.CANDLE,
	Tiles.Block.CANDLE_OUT,
	Tiles.Block.CANDELABRA,
	Tiles.Block.CANDELABRA_OUT,
	Tiles.Block.CHANDELIER,
	Tiles.Block.CHANDELIER_OUT,
	Tiles.Block.BEDSIDE_LAMP,
	Tiles.Block.BEDSIDE_LAMP_OFF,
	Tiles.Block.FIREPLACE,
	Tiles.Block.FIREPLACE_LIT,
	Tiles.Block.STOVE,
	Tiles.Block.STOVE_LIT,
	Tiles.Block.CUSHION,
	Tiles.Block.FLOWER_POT,
	Tiles.Block.HOUSEPLANT,
	Tiles.Block.BATHTUB,
	Tiles.Block.SHOWER,
	Tiles.Block.SHOWER_ON,
	Tiles.Block.WASHBASIN,
	Tiles.Block.GRANDFATHER_CLOCK,
	Tiles.Block.TOY_CHEST,
	Tiles.Block.PIANO,
	Tiles.Block.CRADLE,
	Tiles.Block.FOLDING_SCREEN,
]


## The model of a block (null: not one of these).
static func build(block: int, variant: int) -> VoxelGrid:
	var kind := ObjectShapes.kind_of(block)
	match kind if kind != -1 else block:
		Tiles.Block.CANDLE, Tiles.Block.CANDLE_OUT:
			return candle(block == Tiles.Block.CANDLE)
		Tiles.Block.CANDELABRA, Tiles.Block.CANDELABRA_OUT:
			return candelabra(block == Tiles.Block.CANDELABRA)
		Tiles.Block.CHANDELIER, Tiles.Block.CHANDELIER_OUT:
			return chandelier(block == Tiles.Block.CHANDELIER)
		Tiles.Block.BEDSIDE_LAMP, Tiles.Block.BEDSIDE_LAMP_OFF:
			return bedside_lamp(block == Tiles.Block.BEDSIDE_LAMP)
		Tiles.Block.FIREPLACE:
			return fireplace(false)
		Tiles.Block.FIREPLACE_LIT:
			return fireplace(true)
		Tiles.Block.STOVE:
			return stove(false)
		Tiles.Block.STOVE_LIT:
			return stove(true)
		Tiles.Block.CUSHION:
			return cushion()
		Tiles.Block.FLOWER_POT:
			return flower_pot(variant)
		Tiles.Block.HOUSEPLANT:
			return houseplant(variant)
		Tiles.Block.BATHTUB:
			return bathtub()
		Tiles.Block.SHOWER:
			return shower(false)
		Tiles.Block.SHOWER_ON:
			return shower(true)
		Tiles.Block.WASHBASIN:
			return washbasin()
		Tiles.Block.GRANDFATHER_CLOCK:
			return grandfather_clock()
		Tiles.Block.TOY_CHEST:
			return toy_chest()
		Tiles.Block.PIANO:
			return piano()
		Tiles.Block.CRADLE:
			return cradle()
		Tiles.Block.FOLDING_SCREEN:
			return folding_screen()
	return null


## The color of a block's chips (BlockColors; Color(0, 0, 0, 0): not one).
static func color_of(kind: int) -> Color:
	if not kind in KINDS:
		return Color(0, 0, 0, 0)
	match kind:
		Tiles.Block.CANDLE, Tiles.Block.CANDLE_OUT:
			return Color(WAX[1])
		Tiles.Block.FIREPLACE, Tiles.Block.FIREPLACE_LIT:
			return Color(BRICK[1])
		Tiles.Block.STOVE, Tiles.Block.STOVE_LIT:
			return Color(IRON[1])
		Tiles.Block.FLOWER_POT:
			return Color(CLAY[1])
		Tiles.Block.HOUSEPLANT:
			return Color(LEAF[1])
		Tiles.Block.BATHTUB, Tiles.Block.WASHBASIN, Tiles.Block.SHOWER, Tiles.Block.SHOWER_ON:
			return Color(PORCELAIN[1])
	if Furniture.DYED.has(kind):
		return Color(LINEN[2])
	if kind in [Tiles.Block.CANDELABRA, Tiles.Block.CHANDELIER, Tiles.Block.CANDELABRA_OUT]:
		return Color(BRASS[1])
	return Color(WALNUT[2])


## A candle in a brass dish; lit, its flame.
static func candle(lit: bool) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 11, 16))
	grid.disc(Vector2(8, 8), 2.6, 0, _v(BRASS[1]))
	_ring(grid, Vector2(8, 8), 2.6, 1, _v(BRASS[2]))
	grid.box(Vector3i(7, 1, 7), Vector3i(8, 6, 8), _wax())
	_wick(grid, Vector3i(7, 7, 7), lit)
	return grid


## A brass candelabra of three branches, a candle on each.
static func candelabra(lit: bool) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 15, 16))
	grid.disc(Vector2(8, 8), 3.0, 0, _v(BRASS[0]))
	grid.disc(Vector2(8, 8), 2.0, 1, _v(BRASS[1]))
	grid.box(Vector3i(7, 2, 7), Vector3i(8, 6, 8), _v(BRASS[1]))
	grid.box(Vector3i(3, 6, 7), Vector3i(12, 6, 8), _v(BRASS[2]))
	for x: int in [2, 7, 12]:
		var up := 2 if x == 7 else 0
		grid.box(Vector3i(x, 7, 7), Vector3i(x + 1, 7 + up, 8), _v(BRASS[1]))
		grid.box(Vector3i(x, 8 + up, 7), Vector3i(x + 1, 10 + up, 8), _wax())
		_wick(grid, Vector3i(x, 11 + up, 7), lit)
	return grid


## A chandelier hanging from the top of its cell by a chain: an iron ring
## of six candles.
static func chandelier(lit: bool) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 16, 16))
	for y in range(10, 16):
		var link := Vector3i(7 + (y % 2), y, 7 + ((y + 1) % 2))
		grid.box(link, link + Vector3i(0, 0, 1), _v(IRON[2] if y % 2 else IRON[1]))
	grid.disc(Vector2(8, 8), 1.6, 9, _v(IRON[1]))
	grid.disc(Vector2(8, 8), 1.0, 8, _v(IRON[0]))
	for i in 6:
		var a := TAU * (i + 0.5) / 6.0
		var out := Vector2(8, 8) + Vector2(cos(a), sin(a)) * 6.0
		grid.line(Vector3(8, 8.5, 8), Vector3(out.x, 5.5, out.y), 0.0, _v(IRON[1]))
	_ring(grid, Vector2(8, 8), 6.3, 5, _v(IRON[2]))
	for i in 6:
		var a := TAU * (i + 0.5) / 6.0
		var at := Vector2(8, 8) + Vector2(cos(a), sin(a)) * 6.0
		var cell := Vector3i(int(at.x), 6, int(at.y))
		grid.set_voxel(cell, _v(BRASS[1]))
		grid.box(cell + Vector3i.UP, cell + Vector3i(0, 3, 0), _wax())
		_wick(grid, cell + Vector3i(0, 4, 0), lit)
	return grid


## A bedside oil lamp: a brass foot and stem, a shade of cloth (PAINT)
## glowing from inside when lit.
static func bedside_lamp(lit: bool) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 14, 16))
	grid.disc(Vector2(8, 8), 2.8, 0, _v(BRASS[0]))
	grid.disc(Vector2(8, 8), 2.0, 1, _v(BRASS[1]))
	grid.box(Vector3i(7, 2, 7), Vector3i(8, 7, 8), _v(BRASS[2]))
	var bulb := _v("#ffe6a4", GLOW) if lit else _v("#e8e2d0")
	grid.box(Vector3i(7, 8, 7), Vector3i(8, 9, 8), bulb)
	for y in range(7, 13):
		var radius := 4.6 - (y - 7) * 0.32
		var hex: String = LINEN[3] if (y == 7 or y == 12) else LINEN[2]
		_ring(grid, Vector2(8, 8), radius, y, _v(hex, CLOTH))
	return grid


## A fireplace two tiles wide (32): brick jambs and lintel, a stone mantel
## shelf and hearth, a sooted firebox; lit, logs burning, else logs in
## ash.
static func fireplace(lit: bool) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(32, 16, 16))
	var bricks := _bricks()
	for x0: int in [0, 27]:
		grid.box(Vector3i(x0, 0, 3), Vector3i(x0 + 4, 12, 13), bricks)
	grid.box(Vector3i(5, 10, 3), Vector3i(26, 12, 13), bricks)
	grid.box(Vector3i(5, 0, 3), Vector3i(26, 9, 4), _v("#2a2426"))
	grid.box(Vector3i(5, 0, 5), Vector3i(26, 0, 12), _v(ASH[0]))
	grid.box(Vector3i(0, 13, 2), Vector3i(31, 15, 15), _stone())
	grid.box(Vector3i(0, 15, 2), Vector3i(31, 15, 15), _v(STONE[3]))
	grid.box(Vector3i(2, 0, 13), Vector3i(29, 0, 15), _stone())
	# Andirons and logs.
	for x: int in [10, 21]:
		grid.box(Vector3i(x, 1, 7), Vector3i(x, 2, 11), _v(IRON[0]))
	for log_x: int in [11, 15]:
		grid.box(Vector3i(log_x, 2, 7), Vector3i(log_x + 6, 3, 8), _v(WALNUT[1]))
	grid.box(Vector3i(12, 3, 9), Vector3i(19, 4, 10), _v(WALNUT[2]))
	if not lit:
		for x in range(9, 23):
			grid.set_voxel(Vector3i(x, 1, 6 + (x % 3)), _v(ASH[x % 2]))
		return grid
	for x in range(9, 23):
		grid.set_voxel(Vector3i(x, 1, 8 + (x % 2)), _v(EMBER[1], GLOW))
		var rise := (
			4 + int(round(sin(x * 1.7) * 1.5 + cos(x * 0.6) * 1.5)) + (2 if x % 4 == 1 else 0)
		)
		for y in range(4, 4 + rise):
			var t := float(y - 4) / maxf(rise - 1, 1)
			var hex: String = FIRE[clampi(int((1.0 - t) * 4.0), 0, 4)]
			grid.set_voxel(Vector3i(x, y, 8 + ((x + y) % 2)), _v(hex, GLOW))
	return grid


## A cast-iron stove on legs: a door with a window (the fire in it, lit), a
## top plate, its pipe rising at the back.
static func stove(lit: bool) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 16, 16))
	for x: int in [3, 12]:
		for z: int in [4, 12]:
			grid.box(Vector3i(x, 0, z), Vector3i(x, 1, z), _v(IRON[0]))
	grid.box(Vector3i(3, 2, 4), Vector3i(12, 11, 12), _v(IRON[1]))
	grid.box(Vector3i(2, 11, 3), Vector3i(13, 12, 13), _v(IRON[2]))
	grid.box(Vector3i(4, 3, 13), Vector3i(11, 10, 13), _v(IRON[0]))
	for y in range(5, 9):
		for x in range(5, 11):
			var glow: String = FIRE[clampi(3 - (y - 5) + (x % 2), 0, 4)]
			grid.set_voxel(Vector3i(x, y, 13), _v(glow, GLOW) if lit else _v("#3a3638"))
	grid.box(Vector3i(5, 9, 13), Vector3i(10, 9, 13), _v(IRON[2]))
	grid.set_voxel(Vector3i(11, 6, 14), _v(BRASS[2]))
	grid.box(Vector3i(7, 13, 5), Vector3i(8, 15, 6), _v(IRON[0]))
	return grid


## A round floor cushion (PAINT), its seam and its button.
static func cushion() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 6, 16))
	var cloth := func(p: Vector3i) -> int:
		var hex: String = LINEN[1] if p.y == 2 else LINEN[2 + (p.x + p.z) % 2]
		return _v(hex, CLOTH)
	grid.ellipsoid(Vector3(8, 2.4, 8), Vector3(6.3, 2.8, 6.3), cloth)
	grid.box(Vector3i(7, 4, 7), Vector3i(8, 4, 8), _v(LINEN[0], CLOTH))
	return grid


## A terracotta flower pot (version 0 empty), then holding each plant of
## Decor.POTTED (its own model, standing on the earth).
static func flower_pot(variant: int) -> VoxelGrid:
	var plant: VoxelGrid = null
	if variant > 0 and variant <= Decor.POTTED.size():
		var block: int = Decor.POTTED.values()[variant - 1]
		plant = VoxelModels.build(block, 0).cropped()
	var tall := 7 + (plant.size.y if plant != null else 0)
	var grid := VoxelGrid.new(Vector3i(16, tall, 16))
	_pot(grid, 3.3, 6)
	if plant == null:
		return grid
	var center := plant.pivot if plant.pivot.x >= 0.0 else Vector2(plant.size.x, plant.size.z) * 0.5
	for z in plant.size.z:
		for y in plant.size.y:
			for x in plant.size.x:
				var value := plant.get_voxel(Vector3i(x, y, z))
				if value != 0:
					var at := Vector3i(x - int(center.x) + 8, y + 6, z - int(center.y) + 8)
					grid.set_voxel(at, value)
	grid.sway = plant.sway * 0.5
	grid.sway_from = 7
	return grid


## A big pot of a house plant: a fern (0), a rubber plant (1), a little
## palm (2).
static func houseplant(variant: int) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 26, 16))
	_pot(grid, 4.4, 7)
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x9A17 + variant
	match variant % 3:
		0:
			for i in 9:
				var a := TAU * (i + rng.randf_range(-0.2, 0.2)) / 9.0
				var way := Vector2(cos(a), sin(a))
				for t in 9:
					var at := Vector2(8, 8) + way * t * 0.85
					var y := 8.0 + t * 1.4 - t * t * 0.13
					var hex: String = LEAF[1 + (t % 3)]
					grid.set_voxel(
						Vector3i(int(at.x), int(y), int(at.y)), _v(hex, VoxelGrid.Kind.FOLIAGE)
					)
		1:
			grid.box(Vector3i(7, 7, 7), Vector3i(8, 21, 8), _v(WALNUT[1]))
			for i in 8:
				var a := rng.randf() * TAU
				var y := 10 + i * 1.6
				var at := Vector2(8, 8) + Vector2(cos(a), sin(a)) * 3.0
				var leaf := _v(LEAF[(i % 2) + 1], VoxelGrid.Kind.FOLIAGE)
				grid.ellipsoid(Vector3(at.x, y, at.y), Vector3(2.4, 1.0, 2.4), leaf)
		_:
			grid.box(Vector3i(7, 7, 7), Vector3i(8, 15, 8), _v("#8a6a3e"))
			for i in 7:
				var a := TAU * i / 7.0 + 0.3
				var way := Vector2(cos(a), sin(a))
				for t in 8:
					var at := Vector2(8, 8) + way * t
					var y := 16.0 + t * 0.9 - t * t * 0.16
					var hex: String = LEAF[2 if t % 2 else 1]
					grid.set_voxel(
						Vector3i(int(at.x), int(y), int(at.y)), _v(hex, VoxelGrid.Kind.FOLIAGE)
					)
	grid.sway = 0.35
	grid.sway_from = 8
	return grid


## A bathtub two tiles long (32): porcelain on brass feet, water in it, a
## tap at its head.
static func bathtub() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(32, 12, 16))
	for x: int in [3, 27]:
		for z: int in [3, 11]:
			grid.box(Vector3i(x, 0, z), Vector3i(x + 1, 1, z + 1), _v(BRASS[1]))
	var shell := func(p: Vector3i) -> int:
		var round_end := absf(p.x - 15.5) > 13.0 and absf(p.z - 7.5) > 5.0
		var inside := p.x > 2 and p.x < 29 and p.z > 2 and p.z < 13 and p.y > 3
		if round_end or inside:
			return 0
		if p.y == 9:
			return _v(PORCELAIN[3])
		return _v(PORCELAIN[1] if p.y < 8 else PORCELAIN[2])
	grid.box(Vector3i(1, 2, 1), Vector3i(30, 9, 14), shell)
	var water := func(p: Vector3i) -> int:
		return _v(WATER[1] if p.y == 6 and (p.x + p.z) % 5 == 0 else WATER[0])
	grid.box(Vector3i(3, 4, 3), Vector3i(28, 6, 12), water)
	grid.box(Vector3i(1, 10, 7), Vector3i(1, 11, 8), _v(BRASS[1]))
	grid.box(Vector3i(2, 11, 7), Vector3i(4, 11, 8), _v(BRASS[2]))
	return grid


## A shower two levels high against a wall: a tiled tray, a copper pipe up
## the back to a rose; running, water streaks down from it.
static func shower(running: bool) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 32, 16))
	var tiles := func(p: Vector3i) -> int:
		return _v(PORCELAIN[1] if (p.x / 3 + p.z / 3) % 2 else PORCELAIN[2])
	grid.box(Vector3i(1, 0, 1), Vector3i(14, 0, 14), tiles)
	var rim := func(p: Vector3i) -> int:
		var edge := p.x == 1 or p.x == 14 or p.z == 1 or p.z == 14
		return _v(PORCELAIN[3]) if edge else 0
	grid.box(Vector3i(1, 1, 1), Vector3i(14, 1, 14), rim)
	grid.disc(Vector2(8, 8), 1.2, 1, _v(IRON[1]))
	grid.box(Vector3i(8, 2, 1), Vector3i(8, 26, 1), _v(BRASS[1]))
	grid.box(Vector3i(8, 26, 2), Vector3i(8, 26, 6), _v(BRASS[1]))
	grid.disc(Vector2(8.5, 7.5), 1.8, 25, _v(BRASS[2]))
	grid.box(Vector3i(7, 14, 2), Vector3i(9, 15, 2), _v(BRASS[2]))
	# A curtain rail over the tray's front, the curtain drawn to one side.
	grid.box(Vector3i(1, 29, 14), Vector3i(14, 29, 14), _v(IRON[2]))
	for x in range(1, 5):
		grid.box(Vector3i(x, 4, 14), Vector3i(x, 28, 14), _v(LINEN[2 + x % 2]))
	if running:
		for i in 14:
			var spread := 0.5 + (i % 4) * 0.5
			var at := Vector2(8, 7) + Vector2(cos(i * 2.4), sin(i * 2.4)) * spread
			var from := Vector3i(int(at.x), 3 + (i * 7) % 9, int(at.y))
			grid.box(from, from + Vector3i(0, 4 + i % 5, 0), _v(WATER[1]))
	return grid


## A washbasin on a pedestal: a porcelain basin, a brass tap.
static func washbasin() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 14, 16))
	grid.cylinder(Vector2(8, 7), 2.0, 0, 8, _v(PORCELAIN[1]))
	grid.disc(Vector2(8, 7), 3.0, 0, _v(PORCELAIN[0]))
	for y in range(9, 13):
		grid.disc(
			Vector2(8, 8), 4.5 + (y - 9) * 0.6, y, _v(PORCELAIN[2] if y == 12 else PORCELAIN[1])
		)
	grid.disc(Vector2(8, 8), 3.8, 12, _v(PORCELAIN[0]))
	grid.disc(Vector2(8, 8), 3.0, 11, _v(WATER[0]))
	grid.box(Vector3i(7, 12, 2), Vector3i(8, 13, 3), _v(BRASS[1]))
	grid.box(Vector3i(7, 13, 4), Vector3i(8, 13, 5), _v(BRASS[2]))
	return grid


## A grandfather clock two levels high: a walnut case, a pendulum window, a
## hood with its face (the hands and the pendulum: LiveProps).
static func grandfather_clock() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 32, 16))
	grid.box(Vector3i(3, 0, 5), Vector3i(12, 4, 12), _grain(0x6C10))
	grid.box(Vector3i(4, 5, 6), Vector3i(11, 20, 11), _grain(0x6C11))
	grid.box(Vector3i(5, 8, 12), Vector3i(10, 18, 12), _v("#2a2024"))
	grid.box(Vector3i(5, 8, 12), Vector3i(10, 8, 12), _v(WALNUT[3]))
	grid.box(Vector3i(3, 21, 5), Vector3i(12, 29, 12), _grain(0x6C12))
	for y in range(22, 29):
		for x in range(4, 12):
			var d := Vector2(x + 0.5 - 8.0, y + 0.5 - 25.0).length()
			if d <= 3.6:
				grid.set_voxel(Vector3i(x, y, 12), _v("#f2ead6" if d < 3.0 else BRASS[1]))
	grid.box(Vector3i(2, 30, 4), Vector3i(13, 31, 13), _v(WALNUT[3]))
	grid.box(Vector3i(7, 31, 8), Vector3i(8, 31, 9), _v(BRASS[2]))
	return grid


## A toy chest painted blue and red, a teddy bear on its lid, a ball.
static func toy_chest() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 16, 16))
	var painted := func(p: Vector3i) -> int: return _v("#3e6aa8" if p.y < 8 else "#2e528a")
	grid.box(Vector3i(1, 0, 3), Vector3i(14, 8, 13), painted)
	grid.box(Vector3i(1, 9, 2), Vector3i(14, 10, 14), _v("#b8483e"))
	for x: int in [1, 14]:
		grid.box(Vector3i(x, 0, 3), Vector3i(x, 8, 13), _v("#e6c25a"))
	grid.set_voxel(Vector3i(7, 6, 14), _v(BRASS[2]))
	# A teddy bear sitting on the lid.
	var fur := _v("#9a6a3c")
	grid.ellipsoid(Vector3(10, 13, 8), Vector3(2.2, 2.4, 1.8), fur)
	grid.ellipsoid(Vector3(10, 15.5, 8.5), Vector3(1.7, 1.5, 1.5), fur)
	grid.set_voxel(Vector3i(9, 16, 8), fur)
	grid.set_voxel(Vector3i(11, 16, 8), fur)
	grid.set_voxel(Vector3i(10, 15, 10), _v("#3a2416"))
	grid.ellipsoid(Vector3(4.5, 12.5, 7.5), Vector3(1.6, 1.6, 1.6), _v("#e23a44"))
	return grid


## An upright piano two tiles wide (32): its case, the keyboard (black
## and white keys), a music rest, pedals.
static func piano() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(32, 16, 16))
	grid.box(Vector3i(1, 0, 2), Vector3i(30, 15, 7), _grain(0x9140))
	grid.box(Vector3i(1, 15, 2), Vector3i(30, 15, 8), _v(WALNUT[3]))
	grid.box(Vector3i(2, 6, 8), Vector3i(29, 7, 11), _v(WALNUT[1]))
	for x in range(3, 29):
		grid.box(Vector3i(x, 8, 8), Vector3i(x, 8, 11), _v(KEYS[0]))
		if x % 7 != 2 and x % 7 != 5 and x % 2 == 0:
			grid.box(Vector3i(x, 9, 8), Vector3i(x, 9, 9), _v(KEYS[1]))
	grid.box(Vector3i(1, 0, 8), Vector3i(2, 8, 11), _v(WALNUT[2]))
	grid.box(Vector3i(29, 0, 8), Vector3i(30, 8, 11), _v(WALNUT[2]))
	grid.box(Vector3i(9, 10, 8), Vector3i(22, 13, 8), _v(WALNUT[1]))
	grid.box(Vector3i(11, 11, 9), Vector3i(20, 13, 9), _v("#efe6d4"))
	for x: int in [14, 17]:
		grid.box(Vector3i(x, 0, 8), Vector3i(x, 0, 9), _v(BRASS[2]))
	return grid


## A cradle on rockers, its blanket (PAINT) and a little pillow.
static func cradle() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 13, 16))
	for z: int in [2, 13]:
		for x in 16:
			var y := int(round(pow((x - 7.5) / 7.5, 2.0) * 2.0))
			grid.set_voxel(Vector3i(x, y, z), _v(OAK[1]))
		grid.box(Vector3i(7, 1, z), Vector3i(8, 3, z), _v(OAK[2]))
	grid.box(Vector3i(1, 3, 2), Vector3i(14, 3, 13), _v(OAK[2]))
	for x: int in [1, 14]:
		grid.box(Vector3i(x, 4, 2), Vector3i(x, 9, 13), _v(OAK[3]))
	for z: int in [2, 13]:
		for x in range(1, 15, 2):
			grid.box(Vector3i(x, 4, z), Vector3i(x, 8, z), _v(OAK[3]))
		grid.box(Vector3i(1, 9, z), Vector3i(14, 9, z), _v(OAK[4]))
	grid.box(Vector3i(2, 4, 3), Vector3i(13, 5, 12), _v(LINEN[3]))
	grid.box(Vector3i(3, 6, 3), Vector3i(12, 6, 5), _v("#f6f2e8"))
	var blanket := func(p: Vector3i) -> int:
		return _v(LINEN[2] if (p.x + p.z) % 3 else LINEN[1], CLOTH)
	grid.box(Vector3i(2, 6, 6), Vector3i(13, 7, 12), blanket)
	# A hood over its head.
	for x in range(1, 15):
		grid.box(Vector3i(x, 10, 2), Vector3i(x, 12, 4), _v(LINEN[2 + x % 2], CLOTH))
	return grid


## A folding screen two levels high: three panels folded in a zigzag,
## their cloth (PAINT) painted with a branch, in walnut frames.
static func folding_screen() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 28, 16))
	for x in range(1, 16):
		var panel := (x - 1) / 5
		var t := ((x - 1) % 5) / 4.0
		var z := 5 + int(round(5.0 * (t if panel % 2 == 0 else 1.0 - t)))
		var edge := (x - 1) % 5 == 0 or x == 15
		for y in 28:
			var frame := edge or y <= 1 or y >= 26
			var branch := absi((y + panel * 7) % 9 - ((x - 1) % 5) * 2) == 0 and y > 10
			var hex: String = LINEN[0] if branch else LINEN[2 + y % 2]
			grid.set_voxel(Vector3i(x, y, z), _v(WALNUT[1]) if frame else _v(hex, CLOTH))
	return grid


static func _pot(grid: VoxelGrid, radius: float, height: int) -> void:
	for y in height:
		var r := radius - 0.9 + y * 0.9 / maxf(height - 1, 1)
		grid.disc(Vector2(8, 8), r, y, _v(CLAY[1 if y % 3 else 0]))
	_ring(grid, Vector2(8, 8), radius + 0.4, height - 1, _v(CLAY[2]))
	grid.disc(Vector2(8, 8), radius - 0.6, height - 1, _v(SOIL[0]))
	grid.disc(Vector2(8, 8), radius - 1.4, height - 1, _v(SOIL[1]))


## A wick and, lit, a flame over it (GLOW).
static func _wick(grid: VoxelGrid, at: Vector3i, lit: bool) -> void:
	grid.set_voxel(at, _v("#2a2420"))
	if lit:
		grid.set_voxel(at + Vector3i.UP, _v(FIRE[3], GLOW))
		grid.set_voxel(at + Vector3i(0, 2, 0), _v(FIRE[4], GLOW))
		grid.set_voxel(at + Vector3i(0, 3, 0), _v(FIRE[2], GLOW))


static func _wax() -> Callable:
	return func(p: Vector3i) -> int: return _v(WAX[1 + (p.x + p.z) % 2] if p.y % 4 else WAX[0])


## A horizontal ring (radius, its row).
static func _ring(grid: VoxelGrid, center: Vector2, radius: float, y: int, paint: int) -> void:
	for z in range(floori(center.y - radius - 1), ceili(center.y + radius) + 2):
		for x in range(floori(center.x - radius - 1), ceili(center.x + radius) + 2):
			var d := (Vector2(x + 0.5, z + 0.5) - center).length()
			if d <= radius + 0.5 and d > radius - 0.7:
				grid.set_voxel(Vector3i(x, y, z), paint)


## Bricks laid in rows, mortar between.
static func _bricks() -> Callable:
	return func(p: Vector3i) -> int:
		if p.y % 3 == 2:
			return _v(MORTAR)
		var along := p.x if p.z >= 13 or p.z <= 3 else p.z
		if (along + (p.y / 3) * 3) % 6 == 0:
			return _v(MORTAR)
		return _v(BRICK[HashUtil.hash2(0xB71C, along / 6 + p.y * 3, p.x * 7 + p.z) % 3])


static func _stone() -> Callable:
	return func(p: Vector3i) -> int:
		return _v(STONE[1 + HashUtil.hash2(0x5707, p.x / 3, p.z / 3) % 2])


static func _grain(salt: int) -> Callable:
	return func(p: Vector3i) -> int:
		var grain := HashUtil.unit2(salt, p.x / 3 + p.z * 7, p.y)
		return _v(WALNUT[4] if grain > 0.86 else (WALNUT[3] if grain > 0.3 else WALNUT[2]))


static func _v(hex: String, kind := VoxelGrid.Kind.SOLID) -> int:
	return VoxelGrid.voxel(Color(hex), kind)
