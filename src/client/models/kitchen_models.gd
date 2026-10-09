class_name KitchenModels
extends RefCounted
## The kitchen's models: the kitchen counter (front +z: drawers and an oven
## glowing low, a tiled top with a cutting board, a hob and a copper pot),
## the mill, the butter churn, the barrel and the cheese cellar at each
## stage (empty, working: grain in the hopper, cream at the lid, fruit on the
## barrel, fresh cheeses; ready: a sack of flour, a pat of butter, a jug under
## the tap, aged cheeses), and the dishes and what the machines make.

const WOOD := ["#4e3220", "#6e4a2c", "#8a6038", "#a87a4a"]
const DARK_WOOD := ["#3a2416", "#523420"]
const STONE := ["#5e5e64", "#7c7c84", "#9c9ca4", "#babac0"]
const TILE := ["#d8d2c4", "#c4bcaa", "#9a9282"]
const IRON := ["#2e2e34", "#4a4a52", "#6a6a74"]
const BRASS := ["#8a6a1e", "#c49a32", "#e8c45a"]
const COPPER := ["#7a3a1c", "#b9612d", "#e2894a"]
const GRAIN := ["#b88a2a", "#d8aa44", "#f0cc6a"]
const FLOUR := ["#d8d0c0", "#ece6da", "#faf8f2"]
const SACK := ["#a08a62", "#bca67a", "#d4c094"]
const BUTTER := ["#d8b030", "#f0cc48", "#fae27a"]
const MILK := ["#e8e4da", "#f6f4ee"]
const FRESH_CHEESE := ["#e4e0d0", "#f4f0e2"]
const AGED_CHEESE := ["#c88a2a", "#e6b440", "#f4d468"]
const LINEN := ["#cfc6ae", "#e6dfca"]
const APPLE := ["#8a1a14", "#c42a20", "#e85a40"]
const GLASS := ["#8eb4c6", "#c4dce6", "#eef8fc"]
const CORK := ["#8a5e34", "#a87a4a"]
const GLOW := "#ff9a3a"
## The liquids in their jars: apple juice, fruit juice, cider (with its
## foam), jam.
const JUICES := {
	Items.Id.APPLE_JUICE: ["#c8901e", "#e4ae32", "#f6cc5a"],
	Items.Id.FRUIT_JUICE: ["#b8381e", "#dc5a2a", "#f28a44"],
	Items.Id.CIDER: ["#9a6214", "#c08424", "#e6b84a"],
	Items.Id.JAM: ["#6e0e1a", "#9a1a26", "#c43040"],
}


## The model of a kitchen block (null for others).
static func build(block: int) -> VoxelGrid:
	match block:
		Tiles.Block.KITCHEN:
			return kitchen()
		Tiles.Block.MILL:
			return mill(0)
		Tiles.Block.MILL_WORKING:
			return mill(1)
		Tiles.Block.MILL_READY:
			return mill(2)
		Tiles.Block.BUTTER_CHURN:
			return churn(0)
		Tiles.Block.BUTTER_CHURN_WORKING:
			return churn(1)
		Tiles.Block.BUTTER_CHURN_READY:
			return churn(2)
		Tiles.Block.BARREL:
			return barrel(0)
		Tiles.Block.BARREL_WORKING:
			return barrel(1)
		Tiles.Block.BARREL_READY:
			return barrel(2)
		Tiles.Block.CHEESE_CELLAR:
			return cellar(0)
		Tiles.Block.CHEESE_CELLAR_WORKING:
			return cellar(1)
		Tiles.Block.CHEESE_CELLAR_READY:
			return cellar(2)
	return null


## The model of a kitchen item (null for others).
static func item(item_id: int) -> VoxelGrid:
	match item_id:
		Items.Id.KITCHEN:
			return kitchen()
		Items.Id.MILL:
			return mill(0)
		Items.Id.BUTTER_CHURN:
			return churn(0)
		Items.Id.BARREL:
			return barrel(0)
		Items.Id.CHEESE_CELLAR:
			return cellar(0)
		Items.Id.FLOUR:
			return _flour()
		Items.Id.BUTTER:
			return _butter()
		Items.Id.CHEESE:
			return _cheese()
		Items.Id.APPLE_JUICE, Items.Id.FRUIT_JUICE, Items.Id.CIDER, Items.Id.JAM:
			return _jar(item_id)
		Items.Id.VEGETABLE_SOUP:
			return bowl(["#c8601e", "#e07a2a", "#f09a44"], ["#5a9a2a", "#e8c040"])
		Items.Id.MEAT_STEW:
			return bowl(["#5a2e14", "#7a4220", "#9a5a2c"], ["#c86a3a", "#e89a3a"])
		Items.Id.FRUIT_PIE:
			return _pie()
		Items.Id.OMELETTE:
			return _omelette()
		Items.Id.CAKE:
			return _cake()
		Items.Id.CREPES:
			return _crepes()
		Items.Id.GRATIN:
			return _gratin()
		Items.Id.TARTINE:
			return _tartine()
	return null


static func _v(hex: String, kind := VoxelGrid.Kind.SOLID) -> int:
	return VoxelGrid.voxel(Color(hex), kind)


## A paint picking a shade of a palette by a noise (wood grain, stone...).
static func _shades(palette: Array, salt: int, stretch := Vector3i(1, 1, 1)) -> Callable:
	return func(p: Vector3i) -> int:
		var at := Vector3i(p.x / stretch.x, p.y / stretch.y, p.z / stretch.z)
		var n := HashUtil.unit2(salt + at.z * 131, at.x, at.y)
		return _v(palette[mini(int(n * palette.size()), palette.size() - 1)])


# ---------------------------------------------------------------- blocks


## The kitchen counter: a wooden cabinet (two drawers on the left, an oven
## on the right glowing through its window), a tiled top overhanging the
## front, a cutting board with a knife and a carrot, two burners and a
## copper pot with its lid, a rail of utensils at the back.
static func kitchen() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 19, 16))
	grid.pivot = Vector2(8, 8)
	grid.box(Vector3i(0, 2, 0), Vector3i(15, 12, 14), _shades(WOOD, 0x4C1, Vector3i(1, 4, 1)))
	grid.box(Vector3i(1, 0, 1), Vector3i(14, 1, 13), _v(DARK_WOOD[0]))
	# The drawers: framed, a brass knob each.
	for y0: int in [3, 8]:
		grid.box(Vector3i(1, y0, 15), Vector3i(7, y0 + 3, 15), _v(WOOD[2]))
		grid.box(Vector3i(2, y0 + 1, 15), Vector3i(6, y0 + 2, 15), _v(WOOD[3]))
		grid.set_voxel(Vector3i(4, y0 + 2, 15), _v(BRASS[1]))
	grid.box(Vector3i(1, 2, 14), Vector3i(7, 2, 14), _v(DARK_WOOD[1]))
	# The oven: an iron door, a window glowing low, a handle.
	grid.box(Vector3i(8, 2, 15), Vector3i(14, 10, 15), _v(IRON[1]))
	grid.box(Vector3i(9, 4, 15), Vector3i(13, 7, 15), _v(IRON[0]))
	grid.box(Vector3i(10, 4, 15), Vector3i(12, 5, 15), _v(GLOW, VoxelGrid.Kind.GLOW))
	grid.box(Vector3i(9, 9, 15), Vector3i(13, 9, 15), _v(BRASS[2]))
	# The top: tiles in a checker, overhanging the front.
	var tiles := func(p: Vector3i) -> int:
		if p.z == 15:
			return _v(TILE[2])
		return _v(TILE[(p.x / 2 + p.z / 2) % 2])
	grid.box(Vector3i(0, 13, 0), Vector3i(15, 13, 15), tiles)
	# The cutting board, a knife and a carrot.
	grid.box(Vector3i(1, 14, 6), Vector3i(6, 14, 12), _v(WOOD[3]))
	grid.box(Vector3i(2, 15, 11), Vector3i(5, 15, 11), _v(IRON[2]))
	grid.box(Vector3i(6, 15, 11), Vector3i(7, 15, 11), _v(DARK_WOOD[1]))
	grid.box(Vector3i(2, 15, 8), Vector3i(4, 15, 8), _v("#e07a1e"))
	grid.set_voxel(Vector3i(5, 15, 8), _v("#4a8a2a"))
	# The burners and the pot.
	for z: int in [5, 11]:
		grid.disc(Vector2(11.5, z + 0.5), 2.2, 14, _v(IRON[0]))
		grid.disc(Vector2(11.5, z + 0.5), 1.0, 14, _v(IRON[1]))
	var copper := func(p: Vector3i) -> int: return _v(COPPER[2] if p.x < 11 else COPPER[1])
	grid.cylinder(Vector2(11.5, 5.5), 2.4, 15, 17, copper)
	grid.disc(Vector2(11.5, 5.5), 2.4, 18, _v(COPPER[0]))
	grid.set_voxel(Vector3i(11, 18, 5), _v(BRASS[2]))
	for x: int in [8, 14]:
		grid.set_voxel(Vector3i(x, 17, 5), _v(COPPER[0]))
	# The rail of utensils at the back.
	grid.box(Vector3i(1, 17, 0), Vector3i(7, 17, 0), _v(IRON[1]))
	for x: int in [2, 5]:
		grid.box(Vector3i(x, 14, 1), Vector3i(x, 16, 1), _v(IRON[2]))
	grid.box(Vector3i(1, 14, 1), Vector3i(3, 14, 1), _v(IRON[2]))
	return grid


## The mill: two millstones on a wooden stand, a crank, a spout at the
## front. `stage` 1: grain in the eye of the upper stone; 2: a sack of
## flour under the stand and a little heap by the spout.
static func mill(stage: int) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 16, 16))
	grid.pivot = Vector2(8, 8)
	for x: int in [2, 12]:
		for z: int in [2, 12]:
			grid.box(Vector3i(x, 0, z), Vector3i(x + 1, 5, z + 1), _v(WOOD[1]))
	grid.box(Vector3i(1, 6, 1), Vector3i(14, 7, 14), _shades(WOOD, 0x311, Vector3i(4, 1, 1)))
	grid.box(Vector3i(3, 3, 3), Vector3i(12, 3, 3), _v(WOOD[0]))
	grid.cylinder(Vector2(8, 8), 5.6, 8, 9, _shades(STONE, 0x312))
	grid.cylinder(Vector2(8, 8), 5.0, 10, 11, _shades([STONE[2], STONE[3]], 0x313))
	grid.disc(Vector2(8, 8), 1.3, 11, _v(STONE[0]))
	# Grooves on the upper stone.
	for i in 4:
		var angle := i * PI * 0.5 + 0.4
		var from := Vector3(8 + cos(angle) * 1.8, 11.5, 8 + sin(angle) * 1.8)
		var to := Vector3(8 + cos(angle) * 4.4, 11.5, 8 + sin(angle) * 4.4)
		grid.line(from, to, 0.4, _v(STONE[1]))
	# The crank.
	grid.box(Vector3i(12, 12, 8), Vector3i(12, 14, 8), _v(WOOD[2]))
	grid.set_voxel(Vector3i(12, 15, 8), _v(WOOD[3]))
	# The spout.
	grid.box(Vector3i(7, 8, 14), Vector3i(8, 8, 15), _v(WOOD[0]))
	if stage >= 1:
		grid.ellipsoid(Vector3(8, 11.6, 8), Vector3(1.8, 1.4, 1.8), _shades(GRAIN, 0x314))
		for i in 5:
			var x := 4 + int(HashUtil.unit2(0x315, i, 0) * 8.0)
			var z := 4 + int(HashUtil.unit2(0x315, i, 1) * 8.0)
			grid.set_voxel(Vector3i(x, 12, z), _v(GRAIN[2]))
	if stage == 2:
		grid.ellipsoid(Vector3(7.5, 8.4, 13.5), Vector3(1.6, 0.9, 1.4), _v(FLOUR[2]))
		grid.ellipsoid(Vector3(8, 2.0, 9.5), Vector3(3.2, 2.6, 2.6), _shades(SACK, 0x316))
		grid.box(Vector3i(7, 4, 9), Vector3i(8, 4, 10), _v(SACK[0]))
		grid.ellipsoid(Vector3(8, 5.0, 9.5), Vector3(1.4, 0.8, 1.2), _v(FLOUR[1]))
	return grid


## The butter churn: a tapered barrel of staves with iron hoops, a lid and
## its dasher. `stage` 1: cream showing round the lid; 2: a pat of butter
## on a plate beside it.
static func churn(stage: int) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 20, 16))
	grid.pivot = Vector2(8, 8)
	var staves := func(p: Vector3i) -> int:
		var angle := atan2(p.z - 7.5, p.x - 7.5)
		var stave := int((angle + PI) / TAU * 12.0)
		return _v(WOOD[2] if stave % 2 == 0 else WOOD[1])
	for y in 13:
		var radius := 4.6 - y * 0.08
		grid.disc(Vector2(8, 8), radius, y, staves)
	for y: int in [1, 10]:
		grid.disc(Vector2(8, 8), 4.8 - y * 0.08, y, _v(IRON[1]))
	grid.disc(Vector2(8, 8), 3.9, 13, _v(WOOD[3]))
	grid.disc(Vector2(8, 8), 1.0, 13, _v(WOOD[0]))
	grid.box(Vector3i(7, 14, 7), Vector3i(8, 18, 8), _v(WOOD[3]))
	grid.box(Vector3i(6, 19, 7), Vector3i(9, 19, 8), _v(WOOD[2]))
	if stage >= 1:
		for i in 10:
			var angle := TAU * i / 10.0
			var at := Vector3i(roundi(7.5 + cos(angle) * 3.9), 13, roundi(7.5 + sin(angle) * 3.9))
			grid.set_voxel(at, _v(MILK[i % 2]))
		grid.set_voxel(Vector3i(11, 12, 8), _v(MILK[1]))
		grid.set_voxel(Vector3i(11, 11, 8), _v(MILK[0]))
	if stage == 2:
		grid.disc(Vector2(13, 13), 2.4, 0, _v(TILE[0]))
		grid.box(Vector3i(12, 1, 12), Vector3i(14, 2, 14), _shades(BUTTER, 0x317))
	return grid


## The barrel: bellied staves, iron hoops, a lid, a brass tap at the front.
## `stage` 1: fruit on the lid; 2: a jug under the tap, a drop falling.
static func barrel(stage: int) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 16, 16))
	grid.pivot = Vector2(8, 8)
	var staves := func(p: Vector3i) -> int:
		var angle := atan2(p.z - 7.5, p.x - 7.5)
		var stave := int((angle + PI) / TAU * 14.0)
		return _v(WOOD[2] if stave % 2 == 0 else WOOD[1])
	for y in 14:
		var radius := 5.0 + sin(PI * (y + 0.5) / 14.0) * 1.2
		grid.disc(Vector2(8, 8), radius, y, staves)
	for y: int in [1, 4, 9, 12]:
		grid.disc(Vector2(8, 8), 5.2 + sin(PI * (y + 0.5) / 14.0) * 1.2, y, _v(IRON[1]))
	grid.disc(Vector2(8, 8), 5.2, 14, _shades([WOOD[2], WOOD[3]], 0x318, Vector3i(1, 1, 3)))
	grid.box(Vector3i(7, 3, 14), Vector3i(8, 3, 15), _v(BRASS[1]))
	grid.set_voxel(Vector3i(7, 4, 15), _v(BRASS[2]))
	grid.set_voxel(Vector3i(8, 2, 15), _v(BRASS[0]))
	if stage == 1:
		for at: Vector3 in [Vector3(6, 15.6, 7), Vector3(9.5, 15.6, 6.5), Vector3(8, 15.6, 9.8)]:
			grid.ellipsoid(at, Vector3(1.3, 1.1, 1.3), _shades(APPLE, 0x319))
	if stage == 2:
		grid.set_voxel(Vector3i(8, 1, 15), _v(JUICES[Items.Id.APPLE_JUICE][2]))
		grid.cylinder(Vector2(12.5, 13.5), 1.4, 0, 2, _v(GLASS[1]))
		grid.disc(Vector2(12.5, 13.5), 0.9, 2, _v(JUICES[Items.Id.APPLE_JUICE][1]))
	return grid


## The cheese cellar: a cabinet on short legs, its door a lattice of linen
## over two shelves. `stage` 1: fresh white cheeses on the shelves; 2:
## aged golden ones, their rinds darker.
static func cellar(stage: int) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 17, 16))
	grid.pivot = Vector2(8, 8)
	for x: int in [1, 13]:
		for z: int in [3, 12]:
			grid.box(Vector3i(x, 0, z), Vector3i(x + 1, 1, z), _v(DARK_WOOD[0]))
	var wood := _shades(WOOD, 0x31A, Vector3i(1, 5, 1))
	grid.box(Vector3i(1, 2, 3), Vector3i(14, 16, 13), wood)
	# Hollow inside: shelves.
	for x in range(2, 14):
		for y in range(3, 16):
			for z in range(4, 13):
				grid.set_voxel(Vector3i(x, y, z), 0)
	for y: int in [3, 9]:
		grid.box(Vector3i(2, y, 4), Vector3i(13, y, 12), _v(WOOD[3]))
	# The door: a frame and a lattice of linen.
	grid.box(Vector3i(1, 2, 13), Vector3i(14, 16, 13), _v(WOOD[2]))
	for x in range(3, 13):
		for y in range(4, 15):
			if (x + y) % 3 == 0 or (x - y + 30) % 3 == 0:
				grid.set_voxel(Vector3i(x, y, 13), _v(LINEN[(x + y) % 2]))
			else:
				grid.set_voxel(Vector3i(x, y, 13), 0)
	grid.box(Vector3i(13, 9, 14), Vector3i(13, 10, 14), _v(BRASS[1]))
	grid.box(Vector3i(0, 16, 2), Vector3i(15, 16, 14), _v(WOOD[1]))
	if stage >= 1:
		var colors: Array = FRESH_CHEESE if stage == 1 else AGED_CHEESE
		for shelf: int in [4, 10]:
			for spot: Vector2 in [Vector2(5, 8), Vector2(10, 8)]:
				var rind := func(p: Vector3i) -> int:
					var edge := Vector2(p.x + 0.5, p.z + 0.5).distance_to(spot) > 1.8
					return _v(colors[0] if edge else colors[colors.size() - 1])
				grid.cylinder(spot, 2.5, shelf, shelf + 1, rind)
	return grid


# ---------------------------------------------------------------- items


## A small sack of flour, open, the flour heaped at its mouth.
static func _flour() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(9, 10, 9))
	grid.ellipsoid(Vector3(4.5, 3.5, 4.5), Vector3(3.8, 3.6, 3.6), _shades(SACK, 0x320))
	grid.cylinder(Vector2(4.5, 4.5), 2.6, 6, 7, _v(SACK[1]))
	grid.ellipsoid(Vector3(4.5, 7.6, 4.5), Vector3(2.4, 1.4, 2.4), _shades(FLOUR, 0x321))
	grid.box(Vector3i(1, 5, 4), Vector3i(1, 5, 5), _v(SACK[0]))
	return grid


## A pat of butter on its paper.
static func _butter() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(10, 5, 8))
	grid.box(Vector3i(0, 0, 0), Vector3i(9, 0, 7), _v("#ece6d6"))
	grid.box(Vector3i(2, 1, 2), Vector3i(7, 3, 5), _shades(BUTTER, 0x322))
	grid.box(Vector3i(2, 3, 2), Vector3i(7, 3, 5), _v(BUTTER[2]))
	grid.box(Vector3i(3, 4, 3), Vector3i(4, 4, 3), _v(BUTTER[1]))
	return grid


## A wedge of cheese, its holes, its rind.
static func _cheese() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(11, 6, 9))
	for x in 11:
		var deep := roundi(8.0 * (1.0 - x / 11.0))
		if deep < 1:
			continue
		grid.box(Vector3i(x, 0, 0), Vector3i(x, 5, deep), _v(AGED_CHEESE[2]))
		grid.box(Vector3i(x, 0, 0), Vector3i(x, 5, 0), _v(AGED_CHEESE[0]))
	var holes: Array[Vector3i] = [
		Vector3i(2, 3, 3), Vector3i(4, 1, 5), Vector3i(1, 4, 6), Vector3i(5, 4, 2)
	]
	for hole in holes:
		grid.set_voxel(hole, _v(AGED_CHEESE[1]))
	return grid


## A glass jar of juice, cider (a head of foam) or jam (a cloth tied over
## it, checked red and white).
static func _jar(item_id: int) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(7, 10, 7))
	var liquid: Array = JUICES[item_id]
	var middle := Vector2(3.5, 3.5)
	for y in 6:
		var radius := 3.2 if y < 5 else 2.4
		grid.disc(middle, radius, y, _v(GLASS[1]))
		if y < 5:
			grid.disc(middle, radius - 0.6, y, _v(liquid[mini(y / 2, 2)]))
	for y in range(1, 5):
		grid.set_voxel(Vector3i(1, y, 2), _v(GLASS[2]))
		grid.set_voxel(Vector3i(5, y, 4), _v(GLASS[0]))
	if item_id == Items.Id.JAM:
		var cloth := func(p: Vector3i) -> int:
			return _v("#d8303a" if (p.x + p.z) % 2 == 0 else "#f4ece0")
		grid.cylinder(middle, 3.0, 6, 6, cloth)
		grid.disc(middle, 2.2, 7, cloth)
		grid.disc(middle, 2.5, 5, _v("#8a5e34"))
		return grid
	if item_id == Items.Id.CIDER:
		grid.disc(middle, 2.0, 5, _v("#f8f0d8"))
	grid.cylinder(middle, 1.3, 6, 7, _v(GLASS[0]))
	grid.cylinder(middle, 1.3, 8, 9, _v(CORK[1]))
	grid.set_voxel(Vector3i(3, 9, 3), _v(CORK[0]))
	return grid


## A wooden bowl of soup (`soup`: dark to light) with bits floating
## (`bits`).
static func bowl(soup: Array, bits: Array) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(11, 5, 11))
	var middle := Vector2(5.5, 5.5)
	for y in 4:
		grid.disc(middle, 3.0 + y * 0.8, y, _v(WOOD[1 if y < 3 else 2]))
	grid.disc(middle, 4.4, 3, _shades(soup, 0x323))
	var rim := func(p: Vector3i) -> int:
		return _v(WOOD[2]) if Vector2(p.x + 0.5, p.z + 0.5).distance_to(middle) > 4.6 else 0
	grid.disc(middle, 5.4, 4, rim)
	for i in 7:
		var x := 3 + int(HashUtil.unit2(0x324, i, 0) * 5.0)
		var z := 3 + int(HashUtil.unit2(0x324, i, 1) * 5.0)
		grid.set_voxel(Vector3i(x, 4, z), _v(bits[i % bits.size()]))
	return grid


## A fruit pie: a golden crust, a lattice over red fruit.
static func _pie() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(12, 4, 12))
	var middle := Vector2(6, 6)
	grid.cylinder(middle, 5.6, 0, 1, _v("#b87a2a"))
	grid.disc(middle, 5.6, 2, _v("#d8a040"))
	grid.disc(middle, 4.6, 2, _v("#9a1a26"))
	var lattice := func(p: Vector3i) -> int:
		return _v("#e8b85a") if p.x % 3 == 0 or p.z % 3 == 0 else 0
	grid.disc(middle, 4.6, 3, lattice)
	for i in 6:
		var angle := TAU * i / 6.0
		grid.set_voxel(
			Vector3i(roundi(5.5 + cos(angle) * 5.0), 3, roundi(5.5 + sin(angle) * 5.0)),
			_v("#f0c86a")
		)
	return grid


## An omelette folded in two, browned in spots, a sprig of herbs.
static func _omelette() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(12, 4, 8))
	var paint := func(p: Vector3i) -> int:
		if HashUtil.unit2(0x325, p.x, p.z) > 0.82:
			return _v("#c8902a")
		return _v("#f0cc48" if p.y >= 2 else "#e4b83a")
	grid.ellipsoid(Vector3(6, 0.5, 1), Vector3(5.6, 2.8, 6.4), paint)
	grid.box(Vector3i(5, 3, 2), Vector3i(6, 3, 2), _v("#4a8a2a"))
	return grid


## A round cake: two sponge layers, cream between and on top, cherries.
static func _cake() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(12, 9, 12))
	var middle := Vector2(6, 6)
	grid.cylinder(middle, 5.2, 0, 2, _v("#d89a4a"))
	grid.cylinder(middle, 5.2, 3, 3, _v("#fbf3e4"))
	grid.cylinder(middle, 5.2, 4, 6, _v("#e2a85a"))
	grid.cylinder(middle, 5.4, 7, 7, _v("#fbf3e4"))
	for i in 5:
		var angle := TAU * i / 5.0 + 0.3
		var at := Vector3i(roundi(5.5 + cos(angle) * 3.4), 8, roundi(5.5 + sin(angle) * 3.4))
		grid.set_voxel(at, _v("#c41e2a"))
	grid.set_voxel(Vector3i(6, 8, 6), _v("#c41e2a"))
	return grid


## A stack of crêpes, the top one folded, a dusting of sugar.
static func _crepes() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(12, 5, 12))
	var middle := Vector2(6, 6)
	for y in 3:
		grid.disc(middle, 5.4 - y * 0.2, y, _v("#e6b464" if y % 2 == 0 else "#d49a4a"))
	var fold := func(p: Vector3i) -> int: return _v("#ecc06e") if p.z < 6 else 0
	grid.disc(middle, 5.0, 3, fold)
	for i in 6:
		var x := 3 + int(HashUtil.unit2(0x326, i, 0) * 6.0)
		var z := 2 + int(HashUtil.unit2(0x326, i, 1) * 3.0)
		grid.set_voxel(Vector3i(x, 4, z), _v("#fbf8f0"))
	return grid


## A gratin in its earthenware dish, the crust golden and browned.
static func _gratin() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(14, 5, 10))
	grid.box(Vector3i(0, 0, 0), Vector3i(13, 3, 9), _v("#a85a32"))
	grid.box(Vector3i(0, 3, 0), Vector3i(13, 3, 9), _v("#c87a4a"))
	var crust := func(p: Vector3i) -> int:
		var n := HashUtil.unit2(0x327, p.x, p.z)
		return _v("#a8641e" if n > 0.8 else ("#e8b84a" if n > 0.35 else "#f4d47a"))
	grid.box(Vector3i(1, 1, 1), Vector3i(12, 3, 8), crust)
	return grid


## A slice of bread, buttered, a stripe of jam.
static func _tartine() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(12, 3, 9))
	grid.box(Vector3i(0, 0, 0), Vector3i(11, 1, 8), _v("#b8742e"))
	grid.box(Vector3i(1, 1, 1), Vector3i(10, 1, 7), _v("#ecd29a"))
	grid.box(Vector3i(1, 2, 1), Vector3i(10, 2, 7), _v(BUTTER[2]))
	grid.box(Vector3i(2, 2, 3), Vector3i(9, 2, 5), _v("#b8202e"))
	return grid
