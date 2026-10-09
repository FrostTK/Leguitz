class_name FishingModels
extends RefCounted
## Fishing's models: the fish trap at each stage (a wicker basket lying
## under the water, ObjectShapes.SUNK puts the surface at SURFACE in the
## model; on the surface a cork float, once baited a red and white float on
## a stick, and with a catch a yellow flag on it and fish in the basket),
## the bobber (Angler), the fish raw and grilled (`fish`, drawn from LOOKS,
## lying on their side), crayfish and crabs, the baits, seaweed, driftwood
## and the fish dishes.

const SURFACE := 12
const WICKER := ["#5e4020", "#7e5a2e", "#a07a44", "#bc9a5e"]
const ROPE := "#b8a070"
const CORK := ["#8a5e34", "#b8844e"]
const FLOAT := ["#d8302a", "#f2f0e8"]
const FLAG := "#f2c43a"
const STICK := "#5a3e24"
const COOKED := ["#7a4620", "#b87a3e", "#e2ac66"]
const GRILL := "#341a0a"
const EYE := "#101014"
const COOKED_EYE := "#e8e0cc"
const GLOW := "#8ef0ff"
## Per fish: [length, height, thickness, back, side, belly, fins, pattern,
## its color, tail]. Patterns: "" none, "bars", "spots", "stripes" (wavy,
## on the back), "scales", "lights" (glowing along the belly), "pale" (no
## eyes); tails: "fork", "square", "round", "crescent", "eel" (none).
const LOOKS := {
	Items.Id.PERCH:
	[11, 5, 3, "#3e5a2a", "#8a9a3a", "#d8d0a0", "#d8642a", "bars", "#26361a", "fork"],
	Items.Id.TROUT:
	[13, 4, 3, "#4a5a48", "#a8a88e", "#ece4d2", "#8a8a70", "spots", "#2a2a24", "square"],
	Items.Id.CARP:
	[14, 6, 4, "#5e4a1c", "#b08a2a", "#e8d08a", "#a07428", "scales", "#8a6a20", "fork"],
	Items.Id.PIKE:
	[16, 4, 3, "#34441e", "#6a8a3a", "#dcdcb4", "#7a6a2a", "spots", "#c8d08a", "fork"],
	Items.Id.CATFISH: [16, 5, 4, "#2a2620", "#565044", "#a8a090", "#38322a", "", "", "round"],
	Items.Id.EEL: [16, 3, 2, "#262618", "#565636", "#b8b07e", "#46462a", "", "", "eel"],
	Items.Id.SALMON:
	[15, 5, 3, "#465868", "#c0c8cc", "#f2ece2", "#66768a", "spots", "#26303c", "fork"],
	Items.Id.SARDINE:
	[9, 3, 2, "#284a6a", "#b8c8d8", "#eef2f6", "#8a9aa8", "spots", "#1e3a56", "fork"],
	Items.Id.MACKEREL:
	[12, 4, 3, "#1c5a48", "#a8c0c0", "#eef0ee", "#5a7070", "stripes", "#0e2c26", "fork"],
	Items.Id.COD:
	[15, 5, 4, "#665c3c", "#a89a70", "#e8e2d0", "#766c4c", "spots", "#4a422a", "square"],
	Items.Id.SEA_BASS: [14, 5, 3, "#465664", "#b8c4cc", "#eef0f2", "#687480", "", "", "fork"],
	Items.Id.TUNA: [16, 6, 5, "#1a2a58", "#7a8aa8", "#d8dce4", "#e8c040", "", "", "crescent"],
	Items.Id.LANTERNFISH:
	[9, 4, 2, "#18182a", "#38385a", "#66668a", "#28283a", "lights", GLOW, "fork"],
	Items.Id.CAVE_FISH: [10, 3, 2, "#d8c4c4", "#f0e2de", "#fff4f0", "#f0c8c8", "pale", "", "round"],
}
## Grilled, some keep their own flesh.
const COOKED_SIDE := {Items.Id.SALMON: "#e8845a", Items.Id.TROUT: "#dc9a6a"}
const CRAB := [["#4a3a22", "#6a5430", "#8a7040"], ["#a8301a", "#d8502a", "#f07a4a"]]
const CRAYFISH := [["#3a3424", "#5a4a2a", "#7a6a3a"], ["#b8381e", "#e0582a", "#f08a4a"]]


## The model of a fishing block (null for others).
static func build(block: int) -> VoxelGrid:
	match block:
		Tiles.Block.FISH_TRAP:
			return trap(0)
		Tiles.Block.FISH_TRAP_BAITED:
			return trap(1)
		Tiles.Block.FISH_TRAP_FULL:
			return trap(2)
	return null


## The model of a fishing item (null for others).
static func item(item_id: int) -> VoxelGrid:
	if LOOKS.has(item_id):
		return fish(item_id, false)
	var raw: Variant = Smelting.FOOD.find_key(item_id)
	if raw != null and LOOKS.has(raw):
		return fish(raw, true)
	match item_id:
		Items.Id.CRAB:
			return _crab(false)
		Items.Id.COOKED_CRAB:
			return _crab(true)
		Items.Id.CRAYFISH:
			return _crayfish(false)
		Items.Id.COOKED_CRAYFISH:
			return _crayfish(true)
		Items.Id.FISH_TRAP:
			return trap(0)
		Items.Id.WORM:
			return _worm()
		Items.Id.BAIT_BALL:
			return _bait_ball()
		Items.Id.FISH_BAIT:
			return _fish_bait()
		Items.Id.SEAWEED:
			return _seaweed()
		Items.Id.DRIFTWOOD:
			return _driftwood()
		Items.Id.FISH_SOUP:
			return KitchenModels.bowl(
				["#c8642a", "#e0843a", "#f0a458"], ["#f4f0e0", "#d83a2a", "#4a8a2a"]
			)
		Items.Id.SUSHI:
			return _sushi()
		Items.Id.FRIED_FISH:
			return _fried_fish()
	return null


static func _v(hex: String, kind := VoxelGrid.Kind.SOLID) -> int:
	return VoxelGrid.voxel(Color(hex), kind)


# ---------------------------------------------------------------- the trap


## The fish trap: a wicker basket lying under the surface (ribs along it,
## rings around it, gaps between: one sees in), closed at one end, a
## funnel at the other; a rope up to the float. `stage`: 0 empty (a cork
## float), 1 baited (a bait inside, a red and white float on a stick), 2
## with a catch (fish inside, a yellow flag on the stick).
static func trap(stage: int) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 16, 16))
	grid.pivot = Vector2(8, 8)
	var axis := Vector2(6.0, 8.0)
	for x in range(2, 14):
		for y in 12:
			for z in 16:
				var off := Vector2(y + 0.5, z + 0.5) - axis
				var radius := off.length()
				var funnel := x >= 12
				var outer := 4.5 - (0.6 if funnel else 0.0)
				if radius > outer or radius < outer - 1.0:
					continue
				var angle := fposmod(atan2(off.y, off.x), TAU)
				var rib := fposmod(angle / (TAU / 8.0), 1.0) < 0.3
				var ring := x % 3 == 2 or x == 2 or x == 13
				if rib or ring:
					var shade: String = WICKER[2 if rib and ring else (1 if rib else 3)]
					grid.set_voxel(Vector3i(x, y, z), _v(shade))
	# The closed end, and the funnel's dark mouth.
	for y in 12:
		for z in 16:
			var radius := (Vector2(y + 0.5, z + 0.5) - axis).length()
			if radius < 4.0:
				grid.set_voxel(Vector3i(2, y, z), _v(WICKER[(y + z) % 2]))
			if radius < 3.6 and radius > 1.6:
				grid.set_voxel(Vector3i(13, y, z), _v(WICKER[0]))
	if stage == 1:
		grid.box(Vector3i(7, 4, 7), Vector3i(8, 4, 8), _v("#d87a6a"))
	elif stage == 2:
		for fish: Array in [[Vector3i(4, 4, 6), "#9aa8b0"], [Vector3i(7, 6, 9), "#b8a060"]]:
			var at: Vector3i = fish[0]
			grid.box(at, at + Vector3i(4, 1, 1), _v(fish[1]))
			grid.set_voxel(at + Vector3i(-1, 0, 0), _v(fish[1]))
			grid.set_voxel(at + Vector3i(4, 1, 1), _v(EYE))
	# The rope up to the float on the surface.
	for y in range(10, SURFACE):
		grid.set_voxel(Vector3i(8, y, 8), _v(ROPE))
	if stage == 0:
		grid.cylinder(Vector2(8.5, 8.5), 1.6, SURFACE - 1, SURFACE, _v(CORK[1]))
		grid.disc(Vector2(8.5, 8.5), 1.6, SURFACE, _v(CORK[0]))
		return grid
	grid.cylinder(Vector2(8.5, 8.5), 1.5, SURFACE - 1, SURFACE - 1, _v(FLOAT[1]))
	grid.cylinder(Vector2(8.5, 8.5), 1.5, SURFACE, SURFACE, _v(FLOAT[0]))
	grid.disc(Vector2(8.5, 8.5), 0.9, SURFACE + 1, _v(FLOAT[1]))
	for y in range(SURFACE + 2, 16):
		grid.set_voxel(Vector3i(8, y, 8), _v(STICK))
	if stage == 2:
		grid.box(Vector3i(8, 14, 9), Vector3i(8, 15, 11), _v(FLAG))
	return grid


## The bobber: a white bulb under the water line (its third voxel), a red
## cap over it, a stick with a yellow tip.
static func bobber() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(4, 7, 4))
	grid.pivot = Vector2(2, 2)
	var middle := Vector2(2.0, 2.0)
	grid.disc(middle, 1.2, 0, _v(FLOAT[1]))
	grid.disc(middle, 1.9, 1, _v(FLOAT[1]))
	grid.disc(middle, 1.9, 2, _v(FLOAT[1]))
	grid.disc(middle, 1.9, 3, _v(FLOAT[0]))
	grid.disc(middle, 1.2, 4, _v(FLOAT[0]))
	grid.set_voxel(Vector3i(2, 5, 2), _v(STICK))
	grid.set_voxel(Vector3i(2, 6, 2), _v(FLAG))
	return grid


# ---------------------------------------------------------------- fish


## A fish lying on its side (x along it, the head at +x; z its height, y
## its thickness, thinner at its edges): its back, side and belly colors,
## its pattern on top, fins on its back and under it, its tail; grilled,
## browned with dark grill marks, its eye white.
static func fish(item_id: int, cooked: bool) -> VoxelGrid:
	var look: Array = LOOKS[item_id]
	var length: int = look[0]
	var height: int = look[1]
	var thick: int = look[2]
	var tail_kind: String = look[9]
	var tail := 0 if tail_kind == "eel" else 3
	var grid := VoxelGrid.new(Vector3i(length + tail + 1, thick, height + 6))
	var middle := (height + 6) * 0.5
	var colors: Array = [look[3], look[4], look[5]]
	var fin: String = look[6]
	if cooked:
		colors = [COOKED[0], COOKED_SIDE.get(item_id, COOKED[1]), COOKED[2]]
		fin = COOKED[0]
	for x in length:
		var t := (x + 0.5) / length
		var half := height * 0.5 * _profile(t, tail_kind, item_id)
		for z in grid.size.z:
			var across := (z + 0.5 - middle) / maxf(half, 0.01)
			if absf(across) > 1.0:
				continue
			var depth := thick if absf(across) < 0.6 else maxi(1, thick - 1)
			if absf(across) > 0.85:
				depth = 1
			var at := Vector3i(x + tail, 0, z)
			for y in depth:
				var shade := _skin(look, colors, at, across, t, cooked, y == depth - 1)
				grid.set_voxel(Vector3i(at.x, y, z), shade)
	_fins(grid, look, tail, middle, fin, cooked)
	# The eye, near the head, over the middle (none in the dark caves).
	if look[7] != "pale":
		var eye := Vector3i(length + tail - 2, thick - 1, roundi(middle + height * 0.15))
		grid.set_voxel(eye, _v(COOKED_EYE if cooked else EYE))
		if item_id == Items.Id.LANTERNFISH:
			grid.set_voxel(eye + Vector3i(-1, 0, 0), _v(EYE))
	if item_id == Items.Id.LANTERNFISH and not cooked:
		var lure := Vector3i(length + tail, thick - 1, roundi(middle + height * 0.5 + 1))
		grid.set_voxel(lure, _v(GLOW, VoxelGrid.Kind.GLOW))
	return grid


## How high a fish is along it (`t` from the tail to the head; 1 its
## height): fullest in its middle, an eel and a pike long and slender.
static func _profile(t: float, tail_kind: String, item_id: int) -> float:
	if tail_kind == "eel":
		return 0.85 - 0.35 * absf(t - 0.6)
	var body := pow(sin(PI * clampf(t * 0.88 + 0.1, 0.0, 1.0)), 0.6)
	if item_id == Items.Id.PIKE and t > 0.8:
		body *= 0.7
	return maxf(body, 0.35)


## The color of a voxel of a fish's skin: its back, side or belly by
## `across` (-1 the belly to 1 the back); its pattern on the top layer.
static func _skin(
	look: Array, colors: Array, at: Vector3i, across: float, t: float, cooked: bool, top: bool
) -> int:
	var band := 1
	if across > 0.45:
		band = 0
	elif across < -0.35:
		band = 2
	var color: String = colors[band]
	if cooked:
		if top and (at.x - at.z) % 4 == 0 and t > 0.15:
			return _v(GRILL)
		return _v(color)
	if not top:
		return _v(colors[mini(band, 1)])
	var pattern: String = look[7]
	var dots := HashUtil.unit2(0xF15, at.x, at.z)
	match pattern:
		"bars":
			if at.x % 3 == 0 and across > -0.4 and t > 0.25 and t < 0.85:
				return _v(look[8])
		"spots":
			if dots < 0.18 and across > -0.3:
				return _v(look[8])
		"stripes":
			if across > 0.1 and (at.x + int(across * 4.0)) % 3 == 0:
				return _v(look[8])
		"scales":
			if (at.x + at.z) % 2 == 0 and absf(across) < 0.7:
				return _v(look[8])
		"lights":
			if across < -0.2 and across > -0.75 and at.x % 2 == 0:
				return _v(look[8], VoxelGrid.Kind.GLOW)
	return _v(color)


## A fish's fins: on its back and under it, and its tail (forked, square,
## round, a crescent; none for an eel, whose fin runs along it).
static func _fins(
	grid: VoxelGrid, look: Array, tail: int, middle: float, fin: String, cooked: bool
) -> void:
	var length: int = look[0]
	var height: int = look[1]
	var paint := _v(fin)
	var top := roundi(middle + height * 0.5)
	var bottom := roundi(middle - height * 0.5) - 1
	if look[9] == "eel":
		for x in range(1, length - 3):
			grid.set_voxel(Vector3i(x, 0, top - 1), paint)
		return
	for x in range(roundi(length * 0.35), roundi(length * 0.68)):
		grid.set_voxel(Vector3i(x + tail, 0, top), paint)
		if x % 2 == 0 and not cooked:
			grid.set_voxel(Vector3i(x + tail, 0, top + 1), paint)
	for x in range(roundi(length * 0.2), roundi(length * 0.35)):
		grid.set_voxel(Vector3i(x + tail, 0, bottom), paint)
	# The tail fin, spreading from the tail's end.
	for x in tail:
		var spread := (tail - x) * height * 0.22 + 0.6
		for z in grid.size.z:
			var off := absf(z + 0.5 - middle)
			if off > spread:
				continue
			match look[9]:
				"fork":
					if x == 0 and off < spread * 0.45:
						continue
				"crescent":
					if off < spread * 0.6 and x < tail - 1:
						continue
				"round":
					if off > spread * 0.8 and x == 0:
						continue
			grid.set_voxel(Vector3i(x, 0, z), paint)
	if look[0] == 16 and look[9] == "round":
		# A catfish's barbels, drooping back under its chin.
		for i in 3:
			grid.set_voxel(Vector3i(length + tail - 2 - i, 0, bottom - i), _v(fin))


## A crab: a round shell, claws ahead, legs out on both sides, eyes on
## stalks; brown raw, red cooked.
static func _crab(cooked: bool) -> VoxelGrid:
	var colors: Array = CRAB[1 if cooked else 0]
	var grid := VoxelGrid.new(Vector3i(12, 4, 12))
	grid.ellipsoid(Vector3(5.5, 1.2, 6.0), Vector3(3.6, 1.4, 3.2), _v(colors[1]))
	grid.disc(Vector2(5.5, 6.0), 2.2, 2, _v(colors[2]))
	for side: int in [-1, 1]:
		for i in 3:
			var x := 3 + i * 2
			var from := Vector3(x, 0.5, 6.0 + side * 2.8)
			grid.line(from, from + Vector3(-0.5, 0.0, side * 2.5), 0.0, _v(colors[0]))
		var claw := Vector3(9.5, 1.0, 6.0 + side * 2.2)
		grid.line(Vector3(8.0, 1.0, 6.0 + side * 1.5), claw, 0.0, _v(colors[0]))
		grid.box(
			Vector3i(claw) + Vector3i(0, 0, -1), Vector3i(claw) + Vector3i(1, 1, 0), _v(colors[1])
		)
		grid.set_voxel(Vector3i(8, 2, 6 + side), _v(EYE))
	return grid


## A crayfish: a segmented tail fanning out behind, a head with long
## antennae, big claws ahead; olive raw, red cooked.
static func _crayfish(cooked: bool) -> VoxelGrid:
	var colors: Array = CRAYFISH[1 if cooked else 0]
	var grid := VoxelGrid.new(Vector3i(15, 3, 9))
	for x in range(1, 10):
		var half := 1.3 if x < 5 else 1.8
		for z in 9:
			if absf(z + 0.5 - 4.5) < half:
				var shade: String = colors[2 if x % 2 == 0 else 1]
				grid.box(Vector3i(x, 0, z), Vector3i(x, 1, z), _v(shade))
	grid.box(Vector3i(0, 0, 2), Vector3i(0, 0, 6), _v(colors[1]))
	for side: int in [-1, 1]:
		grid.line(
			Vector3(9.5, 0.5, 4.5 + side), Vector3(12.0, 0.5, 4.5 + side * 3.0), 0.0, _v(colors[0])
		)
		grid.box(Vector3i(12, 0, 4 + side * 3), Vector3i(13, 1, 4 + side * 3), _v(colors[1]))
		grid.line(
			Vector3(10.0, 1.5, 4.5 + side * 0.5),
			Vector3(14.5, 1.5, 4.5 + side * 2.0),
			0.0,
			_v(colors[0])
		)
		grid.set_voxel(Vector3i(9, 2, 4 + side), _v(EYE))
	return grid


# ---------------------------------------------------------------- others


## An earthworm, curled.
static func _worm() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(8, 2, 6))
	var last := Vector3(1.0, 0.5, 4.5)
	for i in 12:
		var t := i / 11.0
		var at := Vector3(1.0 + t * 5.5, 0.5, 3.0 + sin(t * TAU * 0.9) * 2.0)
		grid.line(last, at, 0.0, _v("#c87a7a" if i % 3 else "#a85a5a"))
		last = at
	grid.set_voxel(Vector3i(roundi(last.x), 1, roundi(last.z)), _v("#d89090"))
	return grid


## A ball of bait dough, grains of corn in it.
static func _bait_ball() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(6, 5, 6))
	grid.ellipsoid(Vector3(3.0, 2.3, 3.0), Vector3(2.6, 2.3, 2.6), _v("#d8c8a0"))
	for i in 5:
		var x := 1 + int(HashUtil.unit2(0xBA1, i, 0) * 4.0)
		var z := 1 + int(HashUtil.unit2(0xBA1, i, 1) * 4.0)
		grid.set_voxel(Vector3i(x, 4, z), _v("#f0c040"))
	return grid


## Pieces of fish cut for bait: pink flesh, a silver skin.
static func _fish_bait() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(9, 3, 7))
	for at: Vector3i in [Vector3i(0, 0, 0), Vector3i(5, 0, 1), Vector3i(2, 0, 4)]:
		grid.box(at, at + Vector3i(2, 1, 2), _v("#d87a6a"))
		grid.box(at + Vector3i(0, 2, 0), at + Vector3i(2, 2, 0), _v("#a8b8c0"))
	return grid


## Seaweed: three wavy fronds lying.
static func _seaweed() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(13, 2, 9))
	var greens := ["#2a5a2a", "#3a7a32", "#5a9a3a"]
	for k in 3:
		var last := Vector3(0.5, 0.5, 2.0 + k * 2.5)
		for i in 12:
			var at := Vector3(0.5 + i, 0.5, 2.0 + k * 2.5 + sin(i * 0.9 + k) * 1.2)
			grid.line(last, at, 0.0, _v(greens[(i + k) % 3]))
			last = at
	return grid


## Driftwood: a pale twisted branch bleached by the water, dark knots.
static func _driftwood() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(14, 2, 6))
	for x in 14:
		var z := 2 + roundi(sin(x * 0.7) * 1.2)
		var shade := "#c8c0b0" if x % 4 else "#a8a090"
		grid.box(Vector3i(x, 0, z), Vector3i(x, 1, z + 1), _v(shade))
	grid.box(Vector3i(7, 0, 4), Vector3i(9, 0, 5), _v("#b4ac9a"))
	grid.set_voxel(Vector3i(4, 1, 1), _v("#6a6252"))
	grid.set_voxel(Vector3i(11, 1, 2), _v("#6a6252"))
	return grid


## Sushi: three rolls on a wooden board (seaweed round, rice, fish).
static func _sushi() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(14, 4, 7))
	grid.box(Vector3i(0, 0, 0), Vector3i(13, 0, 6), _v("#b8905a"))
	for k in 3:
		var middle := Vector2(2.5 + k * 4.0, 3.5)
		grid.cylinder(middle, 1.9, 1, 3, _v("#1e3a1e"))
		grid.disc(middle, 1.4, 3, _v("#f4f2ea"))
		grid.disc(middle, 0.7, 3, _v("#f08a6a" if k != 1 else "#e8b04a"))
	return grid


## Fried fish and chips on a checked paper.
static func _fried_fish() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(13, 3, 10))
	var paper := func(p: Vector3i) -> int:
		return _v("#d84a3a" if (p.x / 2 + p.z / 2) % 3 == 0 else "#ece6d8")
	grid.box(Vector3i(0, 0, 0), Vector3i(12, 0, 9), paper)
	grid.ellipsoid(Vector3(5.0, 1.3, 3.5), Vector3(4.2, 1.0, 2.0), _v("#d8a03a"))
	grid.set_voxel(Vector3i(3, 2, 3), _v("#e8b84a"))
	grid.set_voxel(Vector3i(6, 2, 4), _v("#b8822a"))
	for i in 6:
		var x := 2 + i * 2 - (i % 2)
		var z := 6 + i % 3
		grid.box(Vector3i(x, 1, z), Vector3i(x, 1, mini(z + 2, 9)), _v("#f0d060"))
	return grid
