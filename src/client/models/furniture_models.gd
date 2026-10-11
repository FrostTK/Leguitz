class_name FurnitureModels
extends RefCounted
## The voxel models of the bedroom's and the living room's furniture (phase
## 8, step 7; see Furniture), DecorModels' ways (front +z, what hangs on a
## wall with its back at z = 0). A bed lies 32 deep over its two cells (its
## foot at +z, its pillow at its head), the tall furniture is 32 high, a
## sofa 32 wide over its two cells. Cloth (a bed's blanket, an armchair's
## and a sofa's cover, a tablecloth) is PAINT: it takes a tint.

const WALNUT := DecorModels.WALNUT
const OAK := DecorModels.WOOD
const LINEN := DecorModels.LINEN
const CLOTH := VoxelGrid.Kind.PAINT
const BRASS := ["#8a6a24", "#c9a24a", "#ecd27e"]
## Books' spines, plates.
const BOOKS := ["#7e2a38", "#3e6a58", "#2e4a7a", "#8a6a2a", "#5a3a5e", "#3a3a40", "#9a4a2a"]
const PLATE := ["#c9d2da", "#f2f5f7", "#5a7aa8"]
const WICKER := ["#8a6a34", "#b08a4a", "#cfa860"]
## The kinds of oak (the others are walnut, but the dyed and the basket).
const OAKEN := {
	Tiles.Block.DRESSER: true,
	Tiles.Block.WALL_CUPBOARD: true,
	Tiles.Block.CRATE: true,
	Tiles.Block.SHELF: true,
	Tiles.Block.BENCH: true,
	Tiles.Block.STOOL: true,
}
## Every kind with a model here.
const KINDS := [
	Tiles.Block.BED,
	Tiles.Block.WARDROBE,
	Tiles.Block.DRESSER,
	Tiles.Block.BOOKCASE,
	Tiles.Block.COMMODE,
	Tiles.Block.WALL_CUPBOARD,
	Tiles.Block.CRATE,
	Tiles.Block.BASKET,
	Tiles.Block.SHELF,
	Tiles.Block.ARMCHAIR,
	Tiles.Block.SOFA,
	Tiles.Block.BENCH,
	Tiles.Block.STOOL,
	Tiles.Block.ROCKING_CHAIR,
	Tiles.Block.COFFEE_TABLE,
	Tiles.Block.DESK,
	Tiles.Block.NIGHTSTAND,
	Tiles.Block.PEDESTAL_TABLE,
	Tiles.Block.TABLE_CLOTHED,
]


## The model of a block (null: not one of these).
static func build(block: int, _variant: int) -> VoxelGrid:
	var kind := ObjectShapes.kind_of(block)
	match kind if kind != -1 else block:
		Tiles.Block.BED:
			return bed()
		Tiles.Block.WARDROBE:
			return wardrobe()
		Tiles.Block.DRESSER:
			return dresser()
		Tiles.Block.BOOKCASE:
			return bookcase()
		Tiles.Block.COMMODE:
			return commode()
		Tiles.Block.WALL_CUPBOARD:
			return wall_cupboard()
		Tiles.Block.CRATE:
			return crate()
		Tiles.Block.BASKET:
			return basket()
		Tiles.Block.SHELF:
			return shelf()
		Tiles.Block.ARMCHAIR:
			return seat(16, true)
		Tiles.Block.SOFA:
			return seat(32, true)
		Tiles.Block.BENCH:
			return bench()
		Tiles.Block.STOOL:
			return stool()
		Tiles.Block.ROCKING_CHAIR:
			return rocking_chair()
		Tiles.Block.COFFEE_TABLE:
			return coffee_table()
		Tiles.Block.DESK:
			return desk()
		Tiles.Block.NIGHTSTAND:
			return nightstand()
		Tiles.Block.PEDESTAL_TABLE:
			return pedestal_table()
		Tiles.Block.TABLE_CLOTHED:
			return table_clothed()
	return null


## The color of a block's chips (BlockColors; Color(0, 0, 0, 0): not one).
static func color_of(kind: int) -> Color:
	if not kind in KINDS and kind != Tiles.Block.BED_HEAD:
		return Color(0, 0, 0, 0)
	if Furniture.DYED.has(kind):
		return Color(LINEN[2])
	if kind == Tiles.Block.BASKET:
		return Color(WICKER[1])
	return Color(OAK[2] if OAKEN.has(kind) else WALNUT[2])


## A bed: a walnut frame, a headboard and a lower footboard, a linen
## mattress, a pillow, a blanket (PAINT) over its foot half, folded back.
static func bed() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 16, 32))
	for x: int in [0, 15]:
		for z: int in [0, 31]:
			grid.box(Vector3i(x, 0, z), Vector3i(x, 3, z), _v(WALNUT[1]))
	grid.box(Vector3i(0, 3, 0), Vector3i(15, 15, 1), _grain(0xBED1, WALNUT))
	grid.box(Vector3i(2, 6, 1), Vector3i(13, 13, 1), _v(WALNUT[1]))
	grid.box(Vector3i(0, 3, 30), Vector3i(15, 9, 31), _grain(0xBED2, WALNUT))
	grid.box(Vector3i(1, 3, 2), Vector3i(14, 3, 29), _v(WALNUT[0]))
	grid.box(Vector3i(1, 4, 2), Vector3i(14, 7, 29), _v(LINEN[3]))
	grid.box(Vector3i(3, 8, 3), Vector3i(12, 9, 8), _v(LINEN[3]))
	grid.box(Vector3i(3, 9, 4), Vector3i(12, 9, 7), _v("#f6f2e8"))
	# The blanket over its foot, hanging down its sides; its folded edge.
	for z in range(11, 30):
		var hex: String = LINEN[2] if z % 3 else LINEN[1]
		grid.box(Vector3i(1, 8, z), Vector3i(14, 8, z), _v(hex, CLOTH))
		for x: int in [0, 15]:
			grid.box(Vector3i(x, 5, z), Vector3i(x, 8, z), _v(LINEN[1], CLOTH))
	grid.box(Vector3i(1, 9, 11), Vector3i(14, 9, 12), _v(LINEN[3], CLOTH))
	return grid


## A wardrobe two levels high: two panelled doors, brass knobs, a cornice.
static func wardrobe() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 32, 16))
	grid.box(Vector3i(1, 1, 2), Vector3i(14, 29, 14), _grain(0xA4D0, WALNUT))
	for door in 2:
		var x0 := 1 + door * 7
		grid.box(Vector3i(x0, 2, 15), Vector3i(x0 + 6, 28, 15), _v(WALNUT[2]))
		grid.box(Vector3i(x0 + 1, 4, 15), Vector3i(x0 + 5, 13, 15), _v(WALNUT[3]))
		grid.box(Vector3i(x0 + 1, 16, 15), Vector3i(x0 + 5, 26, 15), _v(WALNUT[3]))
		grid.set_voxel(Vector3i(x0 + (5 if door == 0 else 1), 15, 15), _v(BRASS[2]))
	grid.box(Vector3i(8, 2, 15), Vector3i(8, 28, 15), _v(WALNUT[0]))
	grid.box(Vector3i(0, 29, 1), Vector3i(15, 31, 15), _v(WALNUT[1]))
	grid.box(Vector3i(0, 31, 1), Vector3i(15, 31, 15), _v(WALNUT[3]))
	for x: int in [1, 13]:
		grid.box(Vector3i(x, 0, 3), Vector3i(x + 1, 0, 14), _v(WALNUT[0]))
	return grid


## A dresser: a cupboard under a counter, plates standing on the shelves
## of its rack above.
static func dresser() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 32, 16))
	grid.box(Vector3i(1, 0, 4), Vector3i(14, 12, 15), _grain(0xD4E5, OAK))
	for door in 2:
		var x0 := 2 + door * 6
		grid.box(Vector3i(x0, 2, 15), Vector3i(x0 + 5, 11, 15), _v(OAK[3]))
		grid.set_voxel(Vector3i(x0 + (4 if door == 0 else 1), 7, 15), _v(BRASS[2]))
	grid.box(Vector3i(0, 13, 3), Vector3i(15, 13, 15), _v(OAK[2]))
	grid.box(Vector3i(1, 14, 3), Vector3i(14, 31, 3), _v(OAK[1]))
	for x: int in [1, 14]:
		grid.box(Vector3i(x, 14, 4), Vector3i(x, 31, 7), _v(OAK[2]))
	grid.box(Vector3i(0, 30, 3), Vector3i(15, 31, 8), _v(OAK[3]))
	for shelf: int in [19, 25]:
		grid.box(Vector3i(2, shelf, 4), Vector3i(13, shelf, 7), _v(OAK[2]))
		# Plates leaning against the back, their rims and middles.
		for plate in 3:
			var cx := 4 + plate * 4
			for dy in range(1, 6):
				for dx in range(-2, 3):
					if dx * dx + (dy - 3) * (dy - 3) > 5:
						continue
					var rim := dx * dx + (dy - 3) * (dy - 3) >= 4
					var hex: String = PLATE[2] if rim and plate == 1 else PLATE[1 if not rim else 0]
					grid.set_voxel(Vector3i(cx + dx, shelf + dy, 4), _v(hex))
	return grid


## A bookcase two levels high, its shelves full of books.
static func bookcase() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 32, 16))
	grid.box(Vector3i(0, 0, 3), Vector3i(15, 31, 3), _v(WALNUT[1]))
	for x: int in [0, 15]:
		grid.box(Vector3i(x, 0, 3), Vector3i(x, 31, 14), _grain(0xB00C, WALNUT))
	for shelf: int in [0, 8, 16, 24, 31]:
		grid.box(Vector3i(0, shelf, 3), Vector3i(15, shelf, 14), _v(WALNUT[2]))
	for row in 4:
		var x := 1
		var book := row * 5
		while x < 15:
			var width := 1 + HashUtil.hash2(0xB0, book, row) % 2
			var tall := 4 + HashUtil.hash2(0xB1, book, row) % 3
			var hex: String = BOOKS[HashUtil.hash2(0xB2, book, row) % BOOKS.size()]
			var top := row * 8 + mini(tall, 7)
			var right := mini(x + width - 1, 14)
			grid.box(Vector3i(x, row * 8 + 1, 5), Vector3i(right, top, 13), _v(hex))
			# A gilt band across its spine.
			grid.box(Vector3i(x, top - 1, 13), Vector3i(right, top - 1, 13), _v(BRASS[1]))
			x += width
			book += 1
	return grid


## A chest of drawers: three drawers with brass knobs, on short feet.
static func commode() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 14, 16))
	grid.box(Vector3i(1, 1, 3), Vector3i(14, 13, 14), _grain(0xC0DE, WALNUT))
	grid.box(Vector3i(0, 13, 2), Vector3i(15, 13, 15), _v(WALNUT[3]))
	for drawer in 3:
		var y0 := 2 + drawer * 4
		grid.box(Vector3i(2, y0, 15), Vector3i(13, y0 + 2, 15), _v(WALNUT[2]))
		grid.set_voxel(Vector3i(5, y0 + 1, 15), _v(BRASS[2]))
		grid.set_voxel(Vector3i(10, y0 + 1, 15), _v(BRASS[2]))
	for x: int in [1, 13]:
		for z: int in [3, 13]:
			grid.box(Vector3i(x, 0, z), Vector3i(x + 1, 0, z + 1), _v(WALNUT[0]))
	return grid


## A kitchen's wall cupboard (on a wall, its back at z = 0): two doors.
static func wall_cupboard() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 16, 16))
	grid.box(Vector3i(1, 4, 0), Vector3i(14, 15, 8), _grain(0xCAB1, OAK))
	for door in 2:
		var x0 := 2 + door * 6
		grid.box(Vector3i(x0, 5, 9), Vector3i(x0 + 5, 14, 9), _v(OAK[3]))
		grid.box(Vector3i(x0 + 1, 7, 9), Vector3i(x0 + 4, 12, 9), _v(OAK[2]))
		grid.set_voxel(Vector3i(x0 + (4 if door == 0 else 1), 6, 9), _v(BRASS[2]))
	grid.box(Vector3i(0, 15, 0), Vector3i(15, 15, 9), _v(OAK[3]))
	return grid


## A crate: boards in a frame, a brace across each side.
static func crate() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 16, 16))
	var boards := func(p: Vector3i) -> int:
		var edge := int(p.x == 1 or p.x == 14) + int(p.y == 0 or p.y == 15)
		edge += int(p.z == 1 or p.z == 14)
		if edge >= 2:
			return _v(OAK[1])
		var along := p.x if p.z == 1 or p.z == 14 else p.z
		if absi(along - p.y) <= 1:
			return _v(OAK[2])
		return _v(OAK[3] if p.y % 4 else OAK[2])
	grid.box(Vector3i(1, 0, 1), Vector3i(14, 15, 14), boards)
	return grid


## A wicker basket with a handle.
static func basket() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 13, 16))
	for y in 7:
		for z in 16:
			for x in 16:
				var d := Vector2(x - 7.5, z - 7.5).length()
				var radius := 5.0 + y * 0.2
				if d > radius or (d < radius - 1.2 and y > 0):
					continue
				var hex: String = WICKER[(x + z + y) % 2 + (1 if y == 6 else 0)]
				grid.set_voxel(Vector3i(x, y, z), _v(hex))
	for x in range(3, 13):
		var rise := 12 - int(round(absf(x - 7.5) * 0.8))
		grid.set_voxel(Vector3i(x, rise, 8), _v(WICKER[1]))
	return grid


## A display shelf on a wall (its back at z = 0): a board on two brackets.
static func shelf() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 16, 16))
	grid.box(Vector3i(0, 6, 0), Vector3i(15, 7, 6), _grain(0x5E1F, OAK))
	grid.box(Vector3i(0, 7, 6), Vector3i(15, 7, 6), _v(OAK[4]))
	for x: int in [2, 13]:
		for y in range(1, 6):
			grid.box(Vector3i(x, y, 0), Vector3i(x, y, 6 - y), _v(OAK[1]))
	return grid


## An armchair (16 wide) or a sofa (32): a cover (PAINT) over its seat,
## back and arms, cushions, short walnut feet.
static func seat(width: int, arms: bool) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(width, 16, 16))
	var last := width - 1
	grid.box(Vector3i(1, 2, 2), Vector3i(last - 1, 6, 14), _v(LINEN[1], CLOTH))
	var cushions := func(p: Vector3i) -> int:
		var seam := p.x % 15 == 0 and width > 16
		return _v(LINEN[1] if seam or p.y == 7 else LINEN[2], CLOTH)
	grid.box(Vector3i(1, 7, 4), Vector3i(last - 1, 8, 14), cushions)
	var back := func(p: Vector3i) -> int: return _v(LINEN[2] if p.z == 4 else LINEN[1], CLOTH)
	grid.box(Vector3i(1, 7, 1), Vector3i(last - 1, 15, 4), back)
	if arms:
		for x: int in [0, last]:
			var inner := 1 if x == 0 else -1
			grid.box(Vector3i(x, 2, 2), Vector3i(x + inner * 2, 11, 14), _v(LINEN[2], CLOTH))
	for x: int in [1, last - 1]:
		for z: int in [2, 13]:
			grid.box(Vector3i(x, 0, z), Vector3i(x, 1, z), _v(WALNUT[1]))
	return grid


## A bench: a thick board on two slab legs.
static func bench() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 8, 16))
	grid.box(Vector3i(0, 6, 4), Vector3i(15, 7, 11), _grain(0xBE0C, OAK))
	for x: int in [2, 12]:
		grid.box(Vector3i(x, 0, 5), Vector3i(x + 1, 5, 10), _v(OAK[1]))
	grid.box(Vector3i(3, 2, 7), Vector3i(12, 2, 8), _v(OAK[2]))
	return grid


## A stool: a round seat on three legs.
static func stool() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 10, 16))
	grid.disc(Vector2(8, 8), 4.5, 8, _v(OAK[3]))
	grid.disc(Vector2(8, 8), 4.5, 9, _v(OAK[4]))
	for leg: Vector2i in [Vector2i(5, 5), Vector2i(10, 5), Vector2i(7, 11)]:
		grid.box(Vector3i(leg.x, 0, leg.y), Vector3i(leg.x, 7, leg.y), _v(OAK[1]))
	grid.box(Vector3i(5, 3, 5), Vector3i(10, 3, 5), _v(OAK[2]))
	return grid


## A rocking chair: a seat, a tall back of spindles, arms, curved rockers.
static func rocking_chair() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(14, 22, 16))
	for x: int in [1, 12]:
		for z in 16:
			var y := int(round(pow((z - 7.5) / 7.5, 2.0) * 2.0))
			grid.set_voxel(Vector3i(x, y, z), _v(WALNUT[1]))
		for z: int in [4, 11]:
			grid.box(Vector3i(x, 1, z), Vector3i(x, 6, z), _v(WALNUT[2]))
		grid.box(Vector3i(x, 10, 4), Vector3i(x, 10, 12), _v(WALNUT[3]))
		grid.box(Vector3i(x, 7, 11), Vector3i(x, 9, 11), _v(WALNUT[2]))
	grid.box(Vector3i(1, 7, 4), Vector3i(12, 8, 12), _grain(0x40C1, WALNUT))
	for x in range(1, 13):
		if x % 2 == 1 or x == 12:
			grid.box(Vector3i(x, 9, 3), Vector3i(x, 20, 3), _v(WALNUT[2]))
	grid.box(Vector3i(1, 20, 3), Vector3i(12, 21, 3), _v(WALNUT[3]))
	return grid


## A low coffee table.
static func coffee_table() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 7, 16))
	grid.box(Vector3i(1, 5, 2), Vector3i(14, 6, 13), _grain(0xC0FE, WALNUT))
	for x: int in [2, 12]:
		for z: int in [3, 11]:
			grid.box(Vector3i(x, 0, z), Vector3i(x + 1, 4, z + 1), _v(WALNUT[1]))
	grid.box(Vector3i(3, 1, 4), Vector3i(12, 1, 11), _v(WALNUT[2]))
	return grid


## A desk: a top over a drawer unit on its right, a leg on its left.
static func desk() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 14, 16))
	grid.box(Vector3i(0, 12, 2), Vector3i(15, 13, 15), _grain(0xDE5C, WALNUT))
	grid.box(Vector3i(9, 0, 3), Vector3i(14, 11, 14), _v(WALNUT[2]))
	for drawer in 3:
		var y0 := 1 + drawer * 4
		grid.box(Vector3i(10, y0, 15), Vector3i(13, y0 + 2, 15), _v(WALNUT[3]))
		grid.set_voxel(Vector3i(11, y0 + 1, 15), _v(BRASS[2]))
	grid.box(Vector3i(1, 0, 3), Vector3i(2, 11, 4), _v(WALNUT[1]))
	grid.box(Vector3i(1, 0, 13), Vector3i(2, 11, 14), _v(WALNUT[1]))
	grid.box(Vector3i(1, 4, 5), Vector3i(1, 5, 12), _v(WALNUT[2]))
	return grid


## A nightstand: a drawer, a shelf under it.
static func nightstand() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 11, 16))
	grid.box(Vector3i(3, 0, 4), Vector3i(12, 9, 13), _grain(0x4157, WALNUT))
	grid.box(Vector3i(3, 1, 13), Vector3i(12, 3, 13), _v(WALNUT[0]))
	grid.box(Vector3i(4, 5, 14), Vector3i(11, 8, 14), _v(WALNUT[3]))
	grid.set_voxel(Vector3i(7, 6, 15), _v(BRASS[2]))
	grid.box(Vector3i(2, 10, 3), Vector3i(13, 10, 14), _v(WALNUT[3]))
	return grid


## A round pedestal table on its foot.
static func pedestal_table() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 14, 16))
	grid.disc(Vector2(8, 8), 6.5, 12, _v(WALNUT[2]))
	grid.disc(Vector2(8, 8), 6.5, 13, _v(WALNUT[3]))
	grid.cylinder(Vector2(8, 8), 1.2, 2, 11, _v(WALNUT[1]))
	# Its four feet.
	grid.box(Vector3i(2, 0, 7), Vector3i(13, 0, 8), _v(WALNUT[0]))
	grid.box(Vector3i(7, 0, 2), Vector3i(8, 0, 13), _v(WALNUT[0]))
	grid.disc(Vector2(8, 8), 2.0, 1, _v(WALNUT[1]))
	return grid


## The table with a tablecloth (PAINT) over it, hanging down its sides.
static func table_clothed() -> VoxelGrid:
	var grid := DecorModels.table()
	for z in 16:
		for x in 16:
			grid.set_voxel(Vector3i(x, 13, z), _v(LINEN[3] if (x + z) % 7 else LINEN[2], CLOTH))
			if x == 0 or x == 15 or z == 0 or z == 15:
				for y in range(9, 13):
					var hex: String = LINEN[2] if (x + z + y) % 3 else LINEN[1]
					grid.set_voxel(Vector3i(x, y, z), _v(hex, CLOTH))
	return grid


## Wood grain in `colors` (dark to light): streaks along x.
static func _grain(salt: int, colors: Array) -> Callable:
	return func(p: Vector3i) -> int:
		var grain := HashUtil.unit2(salt, p.x / 3 + p.z * 7, p.y)
		if grain > 0.86:
			return _v(colors[4])
		return _v(colors[3] if grain > 0.3 else colors[2])


static func _v(hex: String, kind := VoxelGrid.Kind.SOLID) -> int:
	return VoxelGrid.voxel(Color(hex), kind)
