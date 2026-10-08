class_name WildModels
extends RefCounted
## The wild animals' and the pests' voxel models, in parts that move (see
## CreatureModels: a body, a head, legs, wings, a fish's tail), and their
## blocks and items: the scarecrow, a molehill, a beaver dam, turtle eggs
## (hatching: cracked), the raw and cooked fish.

const WOLF := ["#4a4642", "#6e6a64", "#8e8a82", "#aaa49a"]
const BEAR := ["#3a2618", "#523620", "#6a4a2c", "#7e5a36"]
const FROG := ["#3e6a2a", "#548a34", "#6aa83e"]
const SHELL := ["#3e4a22", "#56602c", "#6e7638"]
const BEAVER := ["#4a301c", "#644226", "#7a5432"]
const FISH := ["#5a7a8e", "#7e9eae", "#a8c4ce"]
const MOLE := ["#24201e", "#36302c", "#48403a"]
const CROW := ["#121418", "#1e2228", "#2c323a"]
const FUZZ := ["#c08a1c", "#e0a82a", "#f4c84a"]
const GLOW := "#ffe27a"
const SKIN := "#e8a8a0"
const STRAW := ["#a8823a", "#c8a04c", "#e0bc64"]
const POLE := ["#5a3e24", "#7a5634"]
const PUMPKIN := ["#b85a14", "#d8761e", "#ee9632"]
const DIRT := ["#4a3220", "#5e4028", "#735034"]
const STICKS := ["#4a321c", "#6a4a2a", "#8a6238"]
const EGG := ["#d8d4c4", "#ece8da", "#faf8f0"]
const SPOT := "#8a8a6a"
const CRACK := "#4a4438"


static func has(kind: int) -> bool:
	return (
		kind
		in [
			Species.Id.WOLF,
			Species.Id.BEAR,
			Species.Id.FROG,
			Species.Id.TURTLE,
			Species.Id.BEAVER,
			Species.Id.FISH,
			Species.Id.MOLE,
			Species.Id.CROW,
			Species.Id.LANTERN_BUMBLEBEE,
		]
	)


## The parts of a wild animal's or a pest's model.
static func parts(kind: int) -> Array:
	match kind:
		Species.Id.WOLF:
			return _wolf()
		Species.Id.BEAR:
			return _bear()
		Species.Id.FROG:
			return _frog()
		Species.Id.TURTLE:
			return _turtle()
		Species.Id.BEAVER:
			return _beaver()
		Species.Id.FISH:
			return _fish()
		Species.Id.MOLE:
			return _mole()
		Species.Id.CROW:
			return _crow()
	return _bumblebee()


## The model of a block of theirs (null for others).
static func build(block: int) -> VoxelGrid:
	match block:
		Tiles.Block.SCARECROW:
			return scarecrow()
		Tiles.Block.MOLEHILL:
			return _molehill()
		Tiles.Block.BEAVER_DAM:
			return _dam()
		Tiles.Block.TURTLE_EGGS:
			return _eggs(0)
		Tiles.Block.TURTLE_EGGS_1:
			return _eggs(1)
		Tiles.Block.TURTLE_EGGS_2:
			return _eggs(2)
	return null


## The model of an item of theirs (null for others).
static func item(item_id: int) -> VoxelGrid:
	match item_id:
		Items.Id.RAW_FISH:
			return _fish_item(false)
		Items.Id.COOKED_FISH:
			return _fish_item(true)
		Items.Id.SCARECROW:
			return scarecrow()
		Items.Id.TURTLE_EGG:
			return _egg_item()
	return null


static func _v(code: String) -> int:
	return CreatureModels.voxel_of(code)


static func _part(name: String, grid: VoxelGrid, corner: Vector3, joint: Vector3) -> Variant:
	return CreatureModels.make_part(name, grid, corner, joint)


# ---------------------------------------------------------------- animals


## A grey wolf: a long lean body, a pale belly, a bushy tail held low, a
## pointed muzzle and ears.
static func _wolf() -> Array:
	var leg := CreatureModels.leg_grid(2, 6, ["#3c3a38", "#6e6a64"], "#26221f")
	var parts: Array = CreatureModels.four_legs(leg, 1, 3, -6)
	var body := VoxelGrid.new(Vector3i(9, 9, 21))
	body.ellipsoid(
		Vector3(4.5, 4.2, 13.0), Vector3(3.6, 3.4, 7.2), CreatureModels.shaded(WOLF, 1.0, 8.0, 101)
	)
	body.box(Vector3i(3, 1, 9), Vector3i(5, 1, 17), _v("#b8b0a4"))
	# The tail, bushy, hanging back and down, its tip pale.
	body.line(Vector3(4.5, 5.5, 6.5), Vector3(4.5, 2.5, 1.5), 1.1, _v(WOLF[1]))
	body.box(Vector3i(4, 1, 0), Vector3i(4, 2, 1), _v(WOLF[3]))
	parts.append(_part("body", body, Vector3(-4.5, 5.0, -13.0), Vector3(0.0, 5.0, 0.0)))
	var head := VoxelGrid.new(Vector3i(7, 8, 9))
	head.box(Vector3i(1, 0, 0), Vector3i(5, 4, 4), CreatureModels.shaded(WOLF, 0.0, 4.0, 103))
	head.box(Vector3i(2, 0, 5), Vector3i(4, 2, 8), _v(WOLF[2]))
	head.box(Vector3i(2, 0, 7), Vector3i(4, 0, 8), _v("#d8d2c6"))
	head.set_voxel(Vector3i(3, 2, 8), _v("#1a1614"))
	CreatureModels.eyes(head, 1, 5, 3, 4)
	# Pointed ears.
	for x: int in [1, 4]:
		head.box(Vector3i(x, 5, 1), Vector3i(x + 1, 5, 1), _v(WOLF[0]))
	head.set_voxel(Vector3i(1, 6, 1), _v(WOLF[0]))
	head.set_voxel(Vector3i(5, 6, 1), _v(WOLF[0]))
	parts.append(_part("head", head, Vector3(-3.5, 8.0, 5.5), Vector3(0.0, 10.0, 6.5)))
	return parts


## A brown bear: heavy, a hump over the shoulders, short round ears, a pale
## muzzle; it rears up to warn (CreatureBody).
static func _bear() -> Array:
	var leg := CreatureModels.leg_grid(4, 6, [BEAR[0], BEAR[1]], "#20160e")
	var parts: Array = CreatureModels.four_legs(leg, 2, 4, -9)
	var body := VoxelGrid.new(Vector3i(15, 14, 22))
	body.ellipsoid(
		Vector3(7.5, 6.5, 11.0),
		Vector3(6.4, 6.0, 10.0),
		CreatureModels.shaded(BEAR, 1.0, 12.0, 107)
	)
	# The hump.
	body.ellipsoid(Vector3(7.5, 11.0, 15.0), Vector3(4.0, 2.5, 4.0), _v(BEAR[2]))
	parts.append(_part("body", body, Vector3(-7.5, 4.0, -11.0), Vector3(0.0, 4.0, 0.0)))
	var head := VoxelGrid.new(Vector3i(9, 9, 10))
	head.box(Vector3i(1, 0, 0), Vector3i(7, 6, 5), CreatureModels.shaded(BEAR, 0.0, 6.0, 109))
	head.box(Vector3i(3, 0, 6), Vector3i(5, 3, 8), _v("#a07a54"))
	head.box(Vector3i(3, 2, 9), Vector3i(5, 3, 9), _v("#1a120c"))
	CreatureModels.eyes(head, 2, 6, 4, 5)
	for x: int in [1, 7]:
		head.box(Vector3i(x, 7, 2), Vector3i(x, 8, 3), _v(BEAR[0]))
	parts.append(_part("head", head, Vector3(-4.5, 9.0, 8.5), Vector3(0.0, 12.0, 9.5)))
	return parts


## A frog: a squat green body, its strong hind legs folded at its sides,
## bulging eyes on top.
static func _frog() -> Array:
	var parts: Array = []
	var body := VoxelGrid.new(Vector3i(7, 4, 7))
	body.ellipsoid(
		Vector3(3.5, 1.8, 3.5), Vector3(2.8, 1.8, 3.0), CreatureModels.shaded(FROG, 0.0, 3.0, 113)
	)
	body.box(Vector3i(2, 0, 2), Vector3i(4, 0, 5), _v("#c8d07a"))
	for x: int in [0, 6]:
		body.box(Vector3i(x, 0, 0), Vector3i(x, 1, 3), _v(FROG[0]))
	parts.append(_part("body", body, Vector3(-3.5, 0.0, -3.5), Vector3(0.0, 0.0, 0.0)))
	var head := VoxelGrid.new(Vector3i(5, 4, 4))
	head.box(Vector3i(0, 0, 0), Vector3i(4, 1, 3), _v(FROG[1]))
	for x: int in [0, 4]:
		head.set_voxel(Vector3i(x, 2, 1), _v(FROG[2]))
		head.set_voxel(Vector3i(x, 3, 1), _v(CreatureModels.EYE))
	head.box(Vector3i(1, 0, 3), Vector3i(3, 0, 3), _v("#2a3a1a"))
	parts.append(_part("head", head, Vector3(-2.5, 1.5, 2.0), Vector3(0.0, 2.0, 2.0)))
	for spot in [["leg_fl", -2.5], ["leg_fr", 1.5]]:
		var leg := VoxelGrid.new(Vector3i(1, 2, 1))
		leg.box(Vector3i.ZERO, Vector3i(0, 1, 0), _v(FROG[0]))
		var corner := Vector3(spot[1], 0.0, 2.0)
		parts.append(_part(spot[0], leg, corner, corner + Vector3(0.5, 2.0, 0.5)))
	return parts


## A sea turtle: a domed shell in plates, flippers, a small head.
static func _turtle() -> Array:
	var flipper := VoxelGrid.new(Vector3i(3, 1, 3))
	flipper.box(Vector3i.ZERO, Vector3i(2, 0, 2), _v("#6a7a5a"))
	var parts: Array = CreatureModels.four_legs(flipper, 3, 3, -6)
	var shell := VoxelGrid.new(Vector3i(11, 6, 12))
	var plates := func(p: Vector3i) -> int:
		var edge := (p.x + p.z) % 4 == 0 or (p.x - p.z + 40) % 4 == 0
		return _v(SHELL[0] if edge else SHELL[1 + int(CreatureModels.noise(p / 2, 127) * 1.9)])
	shell.ellipsoid(Vector3(5.5, 1.0, 6.0), Vector3(5.0, 4.5, 5.6), plates)
	shell.box(Vector3i(2, 0, 2), Vector3i(8, 0, 9), _v("#c8b882"))
	parts.append(_part("body", shell, Vector3(-5.5, 0.5, -6.0), Vector3(0.0, 0.5, 0.0)))
	var head := VoxelGrid.new(Vector3i(3, 3, 4))
	head.box(Vector3i.ZERO, Vector3i(2, 2, 3), _v("#7a8a62"))
	head.set_voxel(Vector3i(0, 2, 2), _v(CreatureModels.EYE))
	head.set_voxel(Vector3i(2, 2, 2), _v(CreatureModels.EYE))
	parts.append(_part("head", head, Vector3(-1.5, 1.0, 5.5), Vector3(0.0, 2.0, 6.0)))
	return parts


## A beaver: a round brown body, a broad flat dark tail, orange teeth.
static func _beaver() -> Array:
	var leg := CreatureModels.leg_grid(2, 2, [BEAVER[0]], "#2a1a10")
	var parts: Array = CreatureModels.four_legs(leg, 1, 2, -3)
	var body := VoxelGrid.new(Vector3i(9, 7, 14))
	body.ellipsoid(
		Vector3(4.5, 3.4, 9.0), Vector3(3.8, 3.2, 4.8), CreatureModels.shaded(BEAVER, 0.0, 6.0, 131)
	)
	# The tail: broad, flat, scaled.
	for z in range(0, 5):
		var color := "#2a2420" if (z % 2) == 0 else "#3a322c"
		body.box(Vector3i(2, 1, z), Vector3i(6, 1, z), _v(color))
	parts.append(_part("body", body, Vector3(-4.5, 1.5, -8.5), Vector3(0.0, 1.5, 0.0)))
	var head := VoxelGrid.new(Vector3i(5, 5, 5))
	head.box(Vector3i(0, 0, 0), Vector3i(4, 3, 3), _v(BEAVER[1]))
	head.box(Vector3i(1, 0, 4), Vector3i(3, 1, 4), _v(BEAVER[2]))
	head.box(Vector3i(2, 0, 4), Vector3i(2, 0, 4), _v("#e8862a"))
	head.set_voxel(Vector3i(2, 1, 4), _v("#1a120c"))
	CreatureModels.eyes(head, 0, 4, 2, 3)
	head.set_voxel(Vector3i(0, 4, 1), _v(BEAVER[0]))
	head.set_voxel(Vector3i(4, 4, 1), _v(BEAVER[0]))
	parts.append(_part("head", head, Vector3(-2.5, 3.5, 4.0), Vector3(0.0, 5.0, 4.5)))
	return parts


## A fish: a slim silver-blue body, a dark stripe, a tail fin that sweeps
## (CreatureBody).
static func _fish() -> Array:
	var parts: Array = []
	var body := VoxelGrid.new(Vector3i(3, 5, 8))
	body.ellipsoid(
		Vector3(1.5, 2.5, 4.0), Vector3(1.4, 2.2, 3.8), CreatureModels.shaded(FISH, 0.0, 4.0, 137)
	)
	body.box(Vector3i(0, 2, 1), Vector3i(2, 2, 6), _v("#3e5866"))
	body.set_voxel(Vector3i(0, 3, 6), _v(CreatureModels.EYE))
	body.set_voxel(Vector3i(2, 3, 6), _v(CreatureModels.EYE))
	body.set_voxel(Vector3i(1, 5 - 1, 3), _v(FISH[0]))
	parts.append(_part("body", body, Vector3(-1.5, 0.0, -3.0), Vector3(0.0, 2.0, 0.0)))
	var tail := VoxelGrid.new(Vector3i(1, 5, 3))
	tail.box(Vector3i(0, 1, 2), Vector3i(0, 3, 2), _v(FISH[1]))
	tail.box(Vector3i(0, 0, 0), Vector3i(0, 4, 1), _v(FISH[0]))
	parts.append(_part("tail", tail, Vector3(-0.5, 0.0, -6.0), Vector3(0.0, 2.5, -3.0)))
	return parts


## A mole: velvet dark fur, a pink snout, broad pink digging hands.
static func _mole() -> Array:
	var parts: Array = []
	var body := VoxelGrid.new(Vector3i(7, 5, 9))
	body.ellipsoid(
		Vector3(3.5, 2.4, 4.5), Vector3(3.0, 2.3, 4.0), CreatureModels.shaded(MOLE, 0.0, 4.0, 139)
	)
	parts.append(_part("body", body, Vector3(-3.5, 0.0, -4.5), Vector3(0.0, 0.0, 0.0)))
	var head := VoxelGrid.new(Vector3i(5, 3, 4))
	head.box(Vector3i(1, 0, 0), Vector3i(3, 2, 2), _v(MOLE[1]))
	head.box(Vector3i(2, 0, 3), Vector3i(2, 1, 3), _v(SKIN))
	parts.append(_part("head", head, Vector3(-2.5, 1.0, 3.5), Vector3(0.0, 2.0, 4.0)))
	for spot in [["leg_fl", -4.0], ["leg_fr", 2.0]]:
		var hand := VoxelGrid.new(Vector3i(2, 2, 2))
		hand.box(Vector3i.ZERO, Vector3i(1, 1, 1), _v(SKIN))
		var corner := Vector3(spot[1], 0.0, 2.0)
		parts.append(_part(spot[0], hand, corner, corner + Vector3(1.0, 2.0, 1.0)))
	return parts


## A crow: glossy black, a grey beak, legs and wings like a fowl's.
static func _crow() -> Array:
	var parts: Array = []
	var leg := VoxelGrid.new(Vector3i(3, 3, 3))
	leg.box(Vector3i(1, 1, 1), Vector3i(1, 2, 1), _v("#2a2a2a"))
	leg.box(Vector3i(0, 0, 1), Vector3i(2, 0, 2), _v("#2a2a2a"))
	for spot in [["leg_fl", -2.5], ["leg_fr", -0.5]]:
		var corner := Vector3(spot[1], 0.0, -1.5)
		parts.append(_part(spot[0], leg, corner, corner + Vector3(1.5, 3.0, 1.5)))
	var body := VoxelGrid.new(Vector3i(7, 6, 10))
	body.ellipsoid(
		Vector3(3.5, 2.8, 5.5), Vector3(2.6, 2.4, 4.0), CreatureModels.shaded(CROW, 0.0, 5.0, 149)
	)
	body.box(Vector3i(3, 3, 0), Vector3i(3, 4, 2), _v(CROW[0]))
	parts.append(_part("body", body, Vector3(-3.5, 2.0, -5.0), Vector3(0.0, 2.0, 0.0)))
	for side in [["wing_l", -3.5, -0.5], ["wing_r", 2.5, 0.5]]:
		var wing := VoxelGrid.new(Vector3i(1, 3, 6))
		wing.box(Vector3i(0, 0, 0), Vector3i(0, 2, 5), _v(CROW[1]))
		var corner := Vector3(side[1], 3.0, -3.0)
		parts.append(_part(side[0], wing, corner, corner + Vector3(0.5 - side[2], 3.0, 3.0)))
	var head := VoxelGrid.new(Vector3i(3, 4, 6))
	head.box(Vector3i(0, 0, 0), Vector3i(2, 2, 2), _v(CROW[2]))
	head.box(Vector3i(1, 0, 3), Vector3i(1, 1, 5), _v("#5a5a5e"))
	head.set_voxel(Vector3i(0, 2, 2), _v("#c8c0a0"))
	head.set_voxel(Vector3i(2, 2, 2), _v("#c8c0a0"))
	parts.append(_part("head", head, Vector3(-1.5, 5.0, 3.0), Vector3(0.0, 5.0, 3.5)))
	return parts


## A lantern bumblebee: a round fuzzy body in golden and dark bands, its
## tail glowing warm, pale wings that never stop.
static func _bumblebee() -> Array:
	var parts: Array = []
	var body := VoxelGrid.new(Vector3i(5, 5, 7))
	var bands := func(p: Vector3i) -> int:
		if p.z <= 1:
			return VoxelGrid.voxel(Color(GLOW), VoxelGrid.Kind.GLOW)
		if p.z % 2 == 1:
			return _v("#2a1e14")
		return _v(FUZZ[clampi(p.y - 1, 0, 2)])
	body.ellipsoid(Vector3(2.5, 2.5, 3.5), Vector3(2.4, 2.3, 3.4), bands)
	body.box(Vector3i(1, 1, 6), Vector3i(3, 3, 6), _v("#1e1610"))
	parts.append(_part("body", body, Vector3(-2.5, 0.5, -3.5), Vector3(0.0, 0.5, 0.0)))
	for side in [["wing_l", -2.5, -0.5], ["wing_r", 2.5, 0.5]]:
		var wing := VoxelGrid.new(Vector3i(1, 1, 4))
		wing.box(Vector3i.ZERO, Vector3i(0, 0, 3), _v("#eef4ff"))
		var corner := Vector3(side[1] - 0.5, 5.5, -2.0)
		parts.append(_part(side[0], wing, corner, corner + Vector3(0.5 - side[2], 0.0, 2.0)))
	return parts


# ---------------------------------------------------------------- blocks


## A scarecrow, two levels tall: a pole and a crossbar, a patched shirt
## stuffed with straw, a pumpkin head with a carved face, an old hat.
static func scarecrow() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 32, 16))
	grid.pivot = Vector2(8, 8)
	grid.box(Vector3i(7, 0, 7), Vector3i(8, 22, 8), _v(POLE[0]))
	grid.box(Vector3i(2, 17, 7), Vector3i(13, 18, 8), _v(POLE[1]))
	# The shirt, patched, and the straw sticking out.
	var shirt := func(p: Vector3i) -> int:
		if (p.x + p.y) % 7 == 0:
			return _v("#c8b080")
		return _v("#8a3a2a" if (p.x / 2 + p.y / 2) % 2 == 0 else "#6a2a20")
	grid.box(Vector3i(5, 10, 6), Vector3i(10, 19, 9), shirt)
	for x: int in [2, 13]:
		grid.box(Vector3i(x, 15, 7), Vector3i(x, 16, 8), _v(STRAW[2]))
	grid.box(Vector3i(6, 8, 7), Vector3i(9, 9, 8), _v(STRAW[1]))
	# The head: a pumpkin, carved.
	var pumpkin := func(p: Vector3i) -> int:
		return _v(PUMPKIN[0] if p.x % 2 == 0 else PUMPKIN[1 + int(p.y > 23)])
	grid.ellipsoid(Vector3(8.0, 23.5, 8.0), Vector3(3.6, 3.0, 3.4), pumpkin)
	for at: Vector3i in [
		Vector3i(6, 24, 11), Vector3i(9, 24, 11), Vector3i(7, 22, 11), Vector3i(8, 22, 11)
	]:
		grid.set_voxel(at, _v("#2a1608"))
	# The hat, small and tipped back: the pumpkin shows from above.
	grid.box(Vector3i(5, 26, 4), Vector3i(10, 26, 8), _v(STRAW[0]))
	grid.box(Vector3i(6, 27, 4), Vector3i(9, 28, 7), _v(STRAW[1]))
	grid.box(Vector3i(6, 27, 4), Vector3i(9, 27, 7), _v("#5a3a20"))
	return grid


## A molehill: a heap of crumbled earth.
static func _molehill() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 6, 16))
	grid.pivot = Vector2(8, 8)
	var earth := func(p: Vector3i) -> int:
		return _v(DIRT[int(HashUtil.unit2(0x3011, p.x + p.y * 17, p.z) * 2.99)])
	grid.ellipsoid(Vector3(8.0, 0.0, 8.0), Vector3(5.0, 4.5, 5.0), earth)
	for i in 6:
		var x := 3 + int(HashUtil.unit2(0x3012, i, 1) * 10.0)
		var z := 3 + int(HashUtil.unit2(0x3012, i, 2) * 10.0)
		grid.set_voxel(Vector3i(x, 0, z), _v(DIRT[2]))
	return grid


## A beaver dam: built up from the riverbed (a level), mud packed between
## sticks heaped across, poking out of the water.
static func _dam() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 18, 16))
	grid.pivot = Vector2(8, 8)
	var mud := func(p: Vector3i) -> int:
		return _v(["#2e2216", "#3a2a1a", "#4a3622"][int(CreatureModels.noise(p / 2, 0xDA3) * 2.99)])
	grid.box(Vector3i(0, 0, 0), Vector3i(15, 11, 15), mud)
	# An uneven top, heaped higher in the middle.
	for z in 16:
		for x in 16:
			var heap := 12 + int(HashUtil.unit2(0xDA5, x / 3, z / 3) * 2.5)
			heap += 1 if absf(x - 7.5) < 4.0 else 0
			grid.box(Vector3i(x, 12, z), Vector3i(x, heap, z), mud)
	for i in 30:
		var y := 9.0 + HashUtil.unit2(0xDA4, i, 0) * 7.0
		var a := Vector3(HashUtil.unit2(0xDA4, i, 1) * 15.0, y, HashUtil.unit2(0xDA4, i, 2) * 15.0)
		var b := Vector3(HashUtil.unit2(0xDA4, i, 3) * 15.0, y, HashUtil.unit2(0xDA4, i, 4) * 15.0)
		grid.line(a, b, 0.5, _v(STICKS[i % 3]))
	return grid


## Turtle eggs in the sand, cracking as they hatch (`stage` 0 to 2).
static func _eggs(stage: int) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 5, 16))
	grid.pivot = Vector2(8, 8)
	var spots: Array[Vector3] = [
		Vector3(5.5, 0, 6), Vector3(10, 0, 6.5), Vector3(8, 0, 10.5), Vector3(4.5, 0, 10.5)
	]
	for i in spots.size():
		var at := spots[i]
		var shell := func(p: Vector3i) -> int:
			return _v(EGG[2] if p.y >= 3 else (EGG[1] if p.y >= 1 else EGG[0]))
		grid.ellipsoid(at + Vector3(0, 1.4, 0), Vector3(2.3, 2.2, 2.3), shell)
		grid.set_voxel(Vector3i(at + Vector3(0, 3, 0)), _v(EGG[2]))
		grid.set_voxel(Vector3i(at + Vector3(1, 1, 0)), _v(SPOT))
		if i < stage * 2:
			grid.set_voxel(Vector3i(at + Vector3(0, 2, 1)), _v(CRACK))
			grid.set_voxel(Vector3i(at + Vector3(1, 3, 0)), _v(CRACK))
	# The nest scraped in the sand around them.
	var rim := _v("#c8ac72")
	for z in 16:
		for x in 16:
			var d := Vector2(x + 0.5 - 7.5, z + 0.5 - 8.0).length()
			if d > 5.2 and d < 6.4:
				grid.set_voxel(Vector3i(x, 0, z), rim)
	return grid


# ---------------------------------------------------------------- items


## A fish lying flat: silver raw, browned cooked.
static func _fish_item(cooked: bool) -> VoxelGrid:
	var colors := ["#8a5a32", "#a8743e", "#c8945a"] if cooked else FISH
	var grid := VoxelGrid.new(Vector3i(13, 4, 6))
	grid.ellipsoid(
		Vector3(5.5, 1.5, 3.0), Vector3(4.6, 1.6, 2.4), CreatureModels.shaded(colors, 0.0, 3.0, 151)
	)
	grid.box(Vector3i(10, 0, 1), Vector3i(12, 1, 4), CreatureModels.voxel_of(colors[0]))
	if not cooked:
		grid.set_voxel(Vector3i(2, 2, 2), _v(CreatureModels.EYE))
	return grid


static func _egg_item() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(5, 6, 5))
	grid.ellipsoid(Vector3(2.5, 2.8, 2.5), Vector3(2.2, 2.8, 2.2), _v(EGG[1]))
	grid.set_voxel(Vector3i(3, 3, 4), _v(SPOT))
	grid.set_voxel(Vector3i(1, 4, 4), _v(SPOT))
	return grid
