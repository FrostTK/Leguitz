class_name BoatModels
extends RefCounted
## The boats' models. The shipyard (front +z, towards the water): posts on
## the bank holding a gantry and its winch, a slipway of two rails on
## cross ties sloping down into the water ahead on stilts, two chocks of a
## cradle on it; ObjectShapes.SUNK puts the bank at BANK in the model. A
## boat (`boat`, bow +z, its middle at the pivot, the keel at y 0, the
## water line at WATER_LINE): its hull of planks (tarred under the water
## line, a light gunwale) from its stern (a transom, a rudder and its
## tiller) through its sections to its bow rising to a stem post; a thwart
## for the pilot, a bench or a chest on each place; with an engine, a riveted
## iron boiler behind the pilot and its chimney. Its propeller and oars are
## models of their own (moved by BoatsView). Its strakes over the water
## line are PAINT voxels, its top strake, gunwale and stem STRIPE ones: the
## shader paints them (PAINT_COLORS, by Items.PAINTS). The net folded on
## its stern (`net_bundle`) or cast behind it (`net_cast`), floats on the
## water and its catch in it. The parts' items, the net, linseed oil, pots
## of paint.

const WOOD := ["#5a3a1e", "#76502c", "#946a3c", "#b08650"]
const RAIL := "#c89a5e"
const TAR := ["#2a2018", "#3a2c20"]
const IRON := ["#26262c", "#3e3e46", "#5e5e68"]
const BRASS := ["#8a6a1e", "#c49a32", "#e8c45a"]
const COPPER := ["#7a3a1c", "#b9612d", "#e2894a"]
const ROPE := "#c8b07a"
const CHEST_WOOD := ["#7a5130", "#9a6a3c", "#b37f4b"]
## The paints' colours (sRGB), in the order of Items.PAINTS.
const PAINT_COLORS := [
	"#b8322a",
	"#e2b42e",
	"#2e5aa8",
	"#ebe6dc",
	"#e07a9a",
	"#3e8a3a",
	"#2a2a2e",
	"#e0782a",
	"#7a3a9a"
]
const NET := ["#c8b98e", "#a8996e"]
const FLOATS := ["#e8a020", "#d8402a"]
const CAUGHT := ["#9aa8b0", "#b8a060", "#7e9eae"]
const OIL := ["#c89a28", "#e6bc40"]
const GLASS := ["#8eb4c6", "#c4dce6"]
## The water line, the gunwale and the benches (voxels over the keel).
const WATER_LINE := 3
const GUNWALE := 9
const BENCH := 6
const CHIMNEY := 19
## The shipyard: the bank's level in its model, how far its slipway goes.
const BANK := 16
const SLIPWAY := 48
const YARD_WIDTH := 26
## A cast net: how deep it hangs, where its floats lie (voxels).
const NET_DEPTH := 5


## The model of a boat block (null for others).
static func build(block: int) -> VoxelGrid:
	if block == Tiles.Block.SHIPYARD:
		return shipyard()
	return null


## The model of a boat item (null for others).
static func item(item_id: int) -> VoxelGrid:
	match item_id:
		Items.Id.SHIPYARD:
			return _yard_item()
		Items.Id.BOAT_BOW:
			return _part(0, 0, 1)
		Items.Id.BOAT_SECTION:
			return _part(0, 1, 0)
		Items.Id.BOAT_STERN:
			return _part(1, 0, 0)
		Items.Id.BOILER:
			return _boiler_item()
		Items.Id.PROPELLER:
			return propeller()
		Items.Id.COAL_ENGINE:
			return _engine_item()
		Items.Id.BOAT_BENCH:
			return _bench_item()
		Items.Id.FISHING_NET:
			return net_bundle(0)
		Items.Id.LINSEED_OIL:
			return _jar(OIL, false)
	if item_id in Items.PAINTS:
		var color: String = PAINT_COLORS[Items.PAINTS.find(item_id)]
		return _jar([Color(color).darkened(0.2).to_html(false), color], true)
	return null


static func _v(hex: String, kind := VoxelGrid.Kind.SOLID) -> int:
	return VoxelGrid.voxel(Color(hex), kind)


## A key for a boat's look (BoatsView builds each once).
static func key_of(boat: Boat) -> String:
	var places := PackedStringArray()
	for place in boat.places():
		places.append(str(boat.place_item(place)))
	var bow := 1 if boat.slots.items[Boat.BOW] == Items.Id.BOAT_BOW else 0
	var stern := 1 if boat.slots.items[Boat.STERN] == Items.Id.BOAT_STERN else 0
	var engine := 1 if boat.has_engine() else 0
	return "%d/%d/%d/%d/%s" % [stern, boat.sections(), bow, engine, ",".join(places)]


# ---------------------------------------------------------------- the boat


## A boat's whole model but its propeller and oars (see the class).
static func boat(of: Boat) -> VoxelGrid:
	var stern := 1 if of.slots.items[Boat.STERN] == Items.Id.BOAT_STERN else 0
	var bow := 1 if of.slots.items[Boat.BOW] == Items.Id.BOAT_BOW else 0
	var grid := _part(stern, of.sections(), bow)
	var length := grid.size.z
	if stern == 1:
		_thwart(grid, Boat.PILOT_AT)
	for place in of.places():
		var along := of.place_along(place) + of.length() * 0.5
		var z := roundi(along * 16.0)
		if z <= 0 or z >= length:
			continue
		match of.place_item(place):
			Items.Id.BOAT_BENCH:
				_thwart(grid, z)
			Items.Id.CHEST:
				_chest(grid, z)
	if of.has_engine() and stern == 1:
		_engine(grid, 2)
	grid.pivot = Vector2(Boat.WIDTH * 0.5, length * 0.5)
	return grid


## A hull of `stern` (0/1) stern, `sections` sections and `bow` (0/1) bow,
## stern first along z.
static func _part(stern: int, sections: int, bow: int) -> VoxelGrid:
	var length := Boat.STERN_LENGTH * stern + Boat.SECTION_LENGTH * sections + Boat.BOW_LENGTH * bow
	var grid := VoxelGrid.new(Vector3i(Boat.WIDTH, CHIMNEY + 1, maxi(length, 1)))
	grid.pivot = Vector2(Boat.WIDTH * 0.5, length * 0.5)
	var bow_from := length - Boat.BOW_LENGTH * bow
	for z in length:
		var half := Boat.WIDTH * 0.5 - 0.5
		var bottom := 0
		if bow == 1 and z >= bow_from:
			var t := (z - bow_from + 0.5) / Boat.BOW_LENGTH
			half *= pow(maxf(1.0 - pow(t, 2.2), 0.0), 0.6)
			bottom = roundi(4.0 * t * t)
		var transom := stern == 1 and z <= 1
		for x in Boat.WIDTH:
			var off := absf(x + 0.5 - Boat.WIDTH * 0.5)
			if off > half + 0.25:
				continue
			var side := off > half - 1.25 or transom
			for y in range(bottom, GUNWALE + 1):
				if not side and y > bottom and y != WATER_LINE:
					continue
				grid.set_voxel(Vector3i(x, y, z), _plank(x, y, z, side))
		if half < 2.5 and bow == 1 and z >= bow_from:
			# The stem post, up over the gunwale.
			var stem := _v(WOOD[1], VoxelGrid.Kind.STRIPE)
			grid.box(Vector3i(9, bottom, z), Vector3i(10, GUNWALE + 1, z), stem)
	if stern == 1:
		# The rudder behind the transom, its tiller forward over the stern.
		grid.box(Vector3i(9, 0, 0), Vector3i(10, 6, 0), _v(WOOD[0]))
		grid.line(Vector3(9.5, GUNWALE + 1, 0.5), Vector3(9.5, GUNWALE + 2, 5.5), 0.0, _v(WOOD[2]))
	return grid


## A plank of the hull: tarred under the water line, strakes above, the
## gunwale light; the floor's boards inside.
static func _plank(x: int, y: int, z: int, side: bool) -> int:
	if not side:
		return _v(WOOD[2] if (x + z / 4) % 3 else WOOD[1])
	if y < WATER_LINE:
		return _v(TAR[(z / 3 + y) % 2])
	if y == GUNWALE:
		return _v(RAIL, VoxelGrid.Kind.STRIPE)
	if y == GUNWALE - 1:
		return _v(WOOD[2], VoxelGrid.Kind.STRIPE)
	if (z / 6 + y) % 5 == 0:
		return _v(WOOD[0], VoxelGrid.Kind.PAINT)
	return _v(WOOD[2] if y % 3 == 0 else WOOD[1], VoxelGrid.Kind.PAINT)


## A thwart across the hull (a bench) at `z`.
static func _thwart(grid: VoxelGrid, z: int) -> void:
	grid.box(Vector3i(2, BENCH, z - 1), Vector3i(Boat.WIDTH - 3, BENCH, z + 1), _v(WOOD[3]))
	grid.box(Vector3i(3, WATER_LINE + 1, z), Vector3i(3, BENCH - 1, z), _v(WOOD[0]))
	grid.box(
		Vector3i(Boat.WIDTH - 4, WATER_LINE + 1, z),
		Vector3i(Boat.WIDTH - 4, BENCH - 1, z),
		_v(WOOD[0])
	)


## A small sea chest on the floor at `z`: planks, iron bands, a brass lock.
static func _chest(grid: VoxelGrid, z: int) -> void:
	var low := Vector3i(5, WATER_LINE + 1, z - 3)
	var high := Vector3i(Boat.WIDTH - 6, WATER_LINE + 7, z + 3)
	grid.box(low, high, _v(CHEST_WOOD[1]))
	grid.box(Vector3i(low.x, high.y, low.z), high, _v(CHEST_WOOD[2]))
	for x: int in [low.x, high.x]:
		grid.box(Vector3i(x, low.y, low.z), Vector3i(x, high.y, high.z), _v(IRON[1]))
	grid.box(Vector3i(low.x, high.y - 2, high.z), Vector3i(high.x, high.y - 2, high.z), _v(IRON[0]))
	grid.box(Vector3i(9, high.y - 3, high.z), Vector3i(10, high.y - 2, high.z), _v(BRASS[1]))


## The steam engine behind the pilot: a riveted iron boiler lying across
## the stern, a brass gauge, a black chimney with a brass ring.
static func _engine(grid: VoxelGrid, z: int) -> void:
	var boiler := func(p: Vector3i) -> int: return _v(IRON[2] if (p.x + p.y) % 4 == 0 else IRON[1])
	grid.box(
		Vector3i(3, WATER_LINE + 1, z), Vector3i(Boat.WIDTH - 4, WATER_LINE + 6, z + 3), boiler
	)
	grid.box(
		Vector3i(3, WATER_LINE + 7, z), Vector3i(Boat.WIDTH - 4, WATER_LINE + 7, z + 3), _v(IRON[0])
	)
	grid.cylinder(Vector2(6.5, z + 2.0), 1.4, WATER_LINE + 7, CHIMNEY - 1, _v(IRON[0]))
	grid.disc(Vector2(6.5, z + 2.0), 1.6, CHIMNEY - 3, _v(BRASS[1]))
	grid.disc(Vector2(6.5, z + 2.0), 1.4, CHIMNEY, _v(IRON[1]))
	grid.set_voxel(Vector3i(6, CHIMNEY, z + 1), 0)
	grid.box(Vector3i(13, WATER_LINE + 5, z + 4), Vector3i(14, WATER_LINE + 6, z + 4), _v(BRASS[2]))


## Where the chimney's mouth is in a boat's model (voxels from the keel's
## middle of its stern end).
static func chimney_top() -> Vector3:
	return Vector3(6.5 - Boat.WIDTH * 0.5, CHIMNEY + 1, 4.0)


## The propeller: three copper blades round a hub (in the x y plane).
static func propeller() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(7, 7, 2))
	grid.pivot = Vector2(3.5, 1.0)
	var center := Vector2(3.5, 3.5)
	for k in 3:
		var angle := TAU * k / 3.0
		var tip := center + Vector2(cos(angle), sin(angle)) * 3.0
		grid.line(
			Vector3(center.x, center.y, 0.5), Vector3(tip.x, tip.y, 0.5), 0.8, _v(COPPER[1 + k % 2])
		)
	grid.box(Vector3i(3, 3, 0), Vector3i(3, 3, 1), _v(BRASS[2]))
	return grid


## An oar: a shaft and a blade (along z, its grip at z 0).
static func oar() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(3, 1, 26))
	grid.pivot = Vector2(1.5, 8.0)
	grid.box(Vector3i(1, 0, 0), Vector3i(1, 0, 19), _v(WOOD[3]))
	grid.box(Vector3i(0, 0, 20), Vector3i(2, 0, 25), _v(WOOD[2]))
	return grid


## The net folded: a bundle of mesh, a row of floats on it, `caught`
## things showing (at most Nets.HOLD).
static func net_bundle(caught: int) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(12, 6, 8))
	grid.pivot = Vector2(6.0, 4.0)
	var mesh := func(p: Vector3i) -> int: return _v(NET[(p.x + p.y + p.z) % 2])
	grid.ellipsoid(Vector3(6.0, 2.0, 4.0), Vector3(5.6, 2.2, 3.4), mesh)
	for x in range(1, 11, 2):
		grid.set_voxel(Vector3i(x, 4, 2), _v(FLOATS[(x / 2) % 2]))
	for i in mini(caught, 4):
		grid.box(Vector3i(2 + i * 2, 3, 5), Vector3i(3 + i * 2, 3, 6), _v(CAUGHT[i % 3]))
	return grid


## The net cast behind the stern (its front at z 0, the water's surface at
## y FLOAT_LINE): a curve of floats on the water, the mesh hanging under
## it in a bag, `caught` things in it (at most Nets.HOLD).
static func net_cast(caught: int) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(28, NET_DEPTH + 2, 22))
	grid.pivot = Vector2(14.0, 0.0)
	var middle := 14.0
	for z in range(2, 22):
		var t := (z - 2.0) / 19.0
		var half := 12.5 * sin(t * PI * 0.5 + 0.3) * (1.0 - t * 0.45)
		for x: int in [roundi(middle - half), roundi(middle + half) - 1]:
			if z % 2 == 0:
				grid.set_voxel(Vector3i(x, NET_DEPTH, z), _v(FLOATS[(z / 2) % 2]))
			for y in range(1, NET_DEPTH):
				if (y + z) % 2 == 0:
					grid.set_voxel(Vector3i(x, y, z), _v(NET[1]))
		if z % 3 == 0:
			for x in range(roundi(middle - half), roundi(middle + half)):
				if x % 2 == 0:
					grid.set_voxel(Vector3i(x, 1 + int(absf(x - middle) / 4.0) % 2, z), _v(NET[0]))
	# The ropes from the stern to the net's ends.
	for side: float in [-1.0, 1.0]:
		grid.line(
			Vector3(middle + side * 2.0, NET_DEPTH + 1, 0.5),
			Vector3(middle + side * 10.0, NET_DEPTH, 3.5),
			0.0,
			_v(NET[1])
		)
	for i in mini(caught, Nets.HOLD):
		var at := Vector3i(roundi(middle) - 6 + (i % 4) * 3, 2 + i / 4, 12 + (i % 3) * 2)
		grid.box(at, at + Vector3i(2, 0, 0), _v(CAUGHT[i % 3]))
	return grid


## A glass jar of oil or paint (`colors`: dark, light), corked; paint has
## a brush in it.
static func _jar(colors: Array, brush: bool) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(8, 12, 8))
	var middle := Vector2(4.0, 4.0)
	grid.cylinder(middle, 3.2, 0, 6, _v(colors[0]))
	grid.disc(middle, 3.2, 6, _v(colors[1]))
	# A glint of the glass down one side.
	grid.box(Vector3i(6, 1, 5), Vector3i(6, 5, 5), _v(GLASS[1]))
	grid.cylinder(middle, 1.6, 7, 8, _v(GLASS[0]))
	if brush:
		grid.box(Vector3i(4, 7, 4), Vector3i(4, 11, 4), _v(WOOD[2]))
		grid.box(Vector3i(3, 7, 3), Vector3i(5, 8, 5), _v(colors[1]))
	else:
		grid.disc(middle, 1.4, 9, _v(CHEST_WOOD[1]))
	return grid


# ---------------------------------------------------------------- shipyard


## The shipyard (see the class).
static func shipyard() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(YARD_WIDTH, BANK + 20, SLIPWAY))
	grid.pivot = Vector2(YARD_WIDTH * 0.5, 8)
	var wood := func(p: Vector3i) -> int: return _v(WOOD[(p.y / 3 + p.z / 5) % 3 + 1])
	var right := YARD_WIDTH - 1
	# The slipway: two rails on cross ties from the bank down into the water,
	# on stilts.
	var top := BANK + 3
	var rails: Array[int] = [7, 8, right - 8, right - 7]
	for z in range(2, SLIPWAY):
		var y := roundi(lerpf(top, 3.0, (z - 2.0) / (SLIPWAY - 3.0)))
		for x in rails:
			grid.box(Vector3i(x, y - 1, z), Vector3i(x, y, z), wood)
		if z % 4 == 0:
			grid.box(Vector3i(5, y - 2, z), Vector3i(right - 5, y - 2, z), _v(WOOD[0]))
		if z % 12 == 6 and y > 2:
			for x: int in [rails[0], rails[3]]:
				grid.box(Vector3i(x, 0, z), Vector3i(x, y - 3, z), _v(WOOD[0]))
	# The cradle's chocks on the rails.
	for z: int in [14, 28]:
		var y := roundi(lerpf(top, 3.0, (z - 2.0) / (SLIPWAY - 3.0)))
		for x: int in [rails[0] - 1, rails[3]]:
			grid.box(Vector3i(x, y + 1, z), Vector3i(x + 1, y + 3, z + 1), _v(WOOD[1]))
	# The gantry on the bank, wider than a boat: two posts, a beam, the
	# winch's drum and crank, its rope down to the slipway.
	for x: int in [0, right - 1]:
		grid.box(Vector3i(x, BANK - 4, 0), Vector3i(x + 1, BANK + 17, 1), _v(WOOD[1]))
		grid.box(Vector3i(x, BANK, 2), Vector3i(x + 1, BANK + 6, 2), _v(WOOD[0]))
	grid.box(Vector3i(0, BANK + 17, 0), Vector3i(right, BANK + 18, 1), _v(WOOD[2]))
	for x in range(8, right - 7):
		grid.box(Vector3i(x, BANK + 13, 0), Vector3i(x, BANK + 15, 1), _v(IRON[1 + x % 2]))
	grid.box(Vector3i(right - 7, BANK + 14, 2), Vector3i(right - 6, BANK + 14, 3), _v(IRON[2]))
	var middle := YARD_WIDTH * 0.5
	grid.line(Vector3(middle, BANK + 13.0, 1.5), Vector3(middle, top + 1.0, 10.0), 0.0, _v(ROPE))
	# Planks on the bank under the gantry.
	grid.box(Vector3i(0, BANK - 1, 0), Vector3i(right, BANK - 1, 4), wood)
	return grid


# ---------------------------------------------------------------- items


## The shipyard's item: a short slipway with a small hull on it and the
## gantry behind.
static func _yard_item() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 16, 22))
	for z in 22:
		var y := roundi(lerpf(7.0, 0.0, z / 21.0))
		for x: int in [3, 12]:
			grid.box(Vector3i(x, y, z), Vector3i(x, y + 1, z), _v(WOOD[2]))
		if z % 4 == 1:
			grid.box(Vector3i(2, y, z), Vector3i(13, y, z), _v(WOOD[0]))
	for z in range(3, 19):
		var y := roundi(lerpf(7.0, 0.0, z / 21.0)) + 2
		var half := 5.5 if z < 15 else 5.5 * (19 - z) / 4.0
		for x in 16:
			if absf(x + 0.5 - 8.0) <= half:
				grid.box(
					Vector3i(x, y, z),
					Vector3i(x, y + 3, z),
					_plank(x, 3, z, absf(x + 0.5 - 8.0) > half - 1.0)
				)
	for x: int in [0, 15]:
		grid.box(Vector3i(x, 0, 0), Vector3i(x, 15, 1), _v(WOOD[1]))
	grid.box(Vector3i(0, 14, 0), Vector3i(15, 15, 1), _v(WOOD[2]))
	grid.box(Vector3i(5, 11, 0), Vector3i(10, 12, 1), _v(IRON[1]))
	return grid


static func _boiler_item() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(12, 9, 9))
	var boiler := func(p: Vector3i) -> int: return _v(IRON[2] if (p.x + p.y) % 3 == 0 else IRON[1])
	grid.box(Vector3i(0, 0, 0), Vector3i(11, 7, 8), boiler)
	grid.box(Vector3i(0, 8, 1), Vector3i(11, 8, 7), _v(IRON[0]))
	grid.box(Vector3i(5, 3, 8), Vector3i(6, 4, 8), _v(BRASS[2]))
	return grid


static func _engine_item() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(Boat.WIDTH, CHIMNEY + 1, 10))
	_engine(grid, 2)
	grid.box(Vector3i(9, 0, 6), Vector3i(10, 3, 7), _v(IRON[0]))
	var blades := propeller()
	for x in blades.size.x:
		for y in blades.size.y:
			var value := blades.get_voxel(Vector3i(x, y, 0))
			if value != 0:
				grid.set_voxel(Vector3i(x + 5, y, 8), value)
	return grid


static func _bench_item() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 5, 4))
	grid.box(Vector3i(0, 4, 0), Vector3i(15, 4, 3), _v(WOOD[3]))
	for x: int in [1, 14]:
		grid.box(Vector3i(x, 0, 1), Vector3i(x, 3, 2), _v(WOOD[1]))
	return grid
