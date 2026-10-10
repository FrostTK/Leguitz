class_name CompanionModels
extends RefCounted
## The dogs' and cats' voxel models (see CreatureModels: a body, a head,
## legs, and a tail that wags), each in its coat (Companions.COATS: DOGS,
## CATS) and, tame, wearing a red collar (a dog's with a tag, a cat's with
## a bell). Every coat has the same parts and joints (CreatureBody reads
## them from the first one).

## A dog's coats: fur (dark to light), belly, muzzle, legs (bottom, top),
## paws, ears (PRICKED, FLOPPY, FOLDED) and their color, the tail's tip,
## patches over the back (or "").
const DOGS := [
	{
		"fur": ["#4a4642", "#6e6a64", "#8e8a82", "#aaa49a"],
		"belly": "#c4bcb0",
		"muzzle": "#d8d2c6",
		"legs": ["#5a5652", "#8e8a82"],
		"paw": "#3c3a38",
		"ears": "pricked",
		"ear": "#4a4642",
		"tip": "#d8d2c6",
		"patch": "",
	},
	{
		"fur": ["#9a6224", "#b87a32", "#d0944a", "#e2b066"],
		"belly": "#ecc890",
		"muzzle": "#e2b066",
		"legs": ["#d0944a", "#b87a32"],
		"paw": "#8a5a22",
		"ears": "floppy",
		"ear": "#8a5520",
		"tip": "#ecc890",
		"patch": "",
	},
	{
		"fur": ["#141212", "#1e1c1c", "#2a2726", "#36322f"],
		"belly": "#ece8e0",
		"muzzle": "#ece8e0",
		"legs": ["#ece8e0", "#1e1c1c"],
		"paw": "#d8d2c6",
		"ears": "folded",
		"ear": "#141212",
		"tip": "#ece8e0",
		"patch": "",
	},
	{
		"fur": ["#3a2216", "#4e3020", "#62402a", "#74503a"],
		"belly": "#86604a",
		"muzzle": "#74503a",
		"legs": ["#4e3020", "#62402a"],
		"paw": "#2e1a10",
		"ears": "floppy",
		"ear": "#2e1a10",
		"tip": "#86604a",
		"patch": "",
	},
	{
		"fur": ["#d8d0c2", "#e8e2d6", "#f4f0e8", "#fcfaf4"],
		"belly": "#fcfaf4",
		"muzzle": "#f4f0e8",
		"legs": ["#f4f0e8", "#e8e2d6"],
		"paw": "#d8d0c2",
		"ears": "floppy",
		"ear": "#a8682c",
		"tip": "#fcfaf4",
		"patch": "#2a2420",
	},
]
## A cat's coats: fur (dark to light), stripes (or ""), belly, eyes, the
## points of a Siamese (or ""), patches of a calico (or "").
const CATS := [
	{
		"fur": ["#5e5a56", "#7a756e", "#948e86"],
		"stripe": "#403c38",
		"belly": "#b0aaa0",
		"eyes": "#a8c040",
		"points": "",
		"patches": [],
	},
	{
		"fur": ["#b0601e", "#c8762a", "#de9040"],
		"stripe": "#8a4612",
		"belly": "#ecc890",
		"eyes": "#d8b030",
		"points": "",
		"patches": [],
	},
	{
		"fur": ["#141318", "#1e1d24", "#2a2830"],
		"stripe": "",
		"belly": "#2a2830",
		"eyes": "#e0c030",
		"points": "",
		"patches": [],
	},
	{
		"fur": ["#d6d4ce", "#e8e6e0", "#f8f6f2"],
		"stripe": "",
		"belly": "#f8f6f2",
		"eyes": "#68a8e0",
		"points": "",
		"patches": [],
	},
	{
		"fur": ["#d6d4ce", "#e8e6e0", "#f8f6f2"],
		"stripe": "",
		"belly": "#f8f6f2",
		"eyes": "#a8c040",
		"points": "",
		"patches": ["#d07a2a", "#1e1d24"],
	},
	{
		"fur": ["#d4c4a4", "#e2d6bc", "#f0e8d6"],
		"stripe": "",
		"belly": "#f0e8d6",
		"eyes": "#68a8e0",
		"points": "#4a3a2e",
		"patches": [],
	},
]
const COLLAR := "#c03028"
const TAG := "#e8c040"
const NOSE := "#1a1614"
const CAT_NOSE := "#d88a8a"
const EAR_PINK := "#d8a0a0"
const WHISKER := "#f0ece4"

static var _built: Dictionary[int, Array] = {}


## The parts of a dog's or a cat's model in a coat, with a collar or not.
static func parts(kind: int, coat: int, collar: bool) -> Array:
	var coats: Array = DOGS if kind == Species.Id.DOG else CATS
	coat = clampi(coat, 0, coats.size() - 1)
	var key := kind * 64 + coat * 2 + (1 if collar else 0)
	if not _built.has(key):
		var look: Dictionary = coats[coat]
		_built[key] = _dog(look, collar) if kind == Species.Id.DOG else _cat(look, collar)
	return _built[key]


static func _v(code: String) -> int:
	return CreatureModels.voxel_of(code)


static func _part(name: String, grid: VoxelGrid, corner: Vector3, joint: Vector3) -> Variant:
	return CreatureModels.make_part(name, grid, corner, joint)


## A red ring round a body grid's slice `z` (what it covers), and its tag
## or bell under it.
static func _collar(grid: VoxelGrid, z: int) -> void:
	var low := grid.size.y
	var middle := grid.size.x / 2
	for y in grid.size.y:
		for x in grid.size.x:
			var p := Vector3i(x, y, z)
			if grid.get_voxel(p) != 0:
				grid.set_voxel(p, _v(COLLAR))
				if x == middle:
					low = mini(low, y)
	if low < grid.size.y:
		grid.set_voxel(Vector3i(middle, low, z + 1), _v(TAG))


# ---------------------------------------------------------------- dogs


## A dog: a sturdy body, a deep chest, a tail held up and curved (it wags:
## CreatureBody), a short muzzle, its ears pricked, floppy or folded.
static func _dog(look: Dictionary, collar: bool) -> Array:
	var legs: Array = look["legs"]
	var leg := CreatureModels.leg_grid(2, 5, legs, look["paw"])
	var parts: Array = CreatureModels.four_legs(leg, 1, 3, -6)
	var body := VoxelGrid.new(Vector3i(9, 8, 18))
	var fur := CreatureModels.shaded(look["fur"], 1.0, 7.0, 211)
	var belly := _v(look["belly"])
	var patch := String(look["patch"])
	var spots := _v(patch) if patch != "" else 0
	var paint := func(p: Vector3i) -> int:
		if p.y <= 1 or (p.z >= 13 and p.y <= 3):
			return belly
		if spots != 0 and p.y >= 4 and p.z >= 4 and p.z <= 13:
			# A saddle over the back.
			if CreatureModels.noise(p / 2, 223) > 0.3:
				return spots
		return fur.call(p)
	body.ellipsoid(Vector3(4.5, 3.8, 9.0), Vector3(3.4, 3.1, 6.8), paint)
	if collar:
		_collar(body, 13)
	parts.append(_part("body", body, Vector3(-4.5, 4.0, -9.0), Vector3(0.0, 4.0, 0.0)))
	var tail := VoxelGrid.new(Vector3i(3, 5, 7))
	var tail_color := _v(look["fur"][1])
	tail.line(Vector3(1.5, 0.5, 6.0), Vector3(1.5, 2.2, 3.5), 0.9, tail_color)
	tail.line(Vector3(1.5, 2.2, 3.5), Vector3(1.5, 3.5, 1.0), 0.8, tail_color)
	tail.box(Vector3i(1, 3, 0), Vector3i(1, 4, 1), _v(look["tip"]))
	parts.append(_part("tail", tail, Vector3(-1.5, 8.5, -12.5), Vector3(0.0, 9.0, -6.5)))
	parts.append(_dog_head(look))
	return parts


static func _dog_head(look: Dictionary) -> Variant:
	var head := VoxelGrid.new(Vector3i(7, 8, 8))
	head.box(
		Vector3i(1, 0, 0), Vector3i(5, 4, 4), CreatureModels.shaded(look["fur"], 0.0, 4.0, 227)
	)
	var muzzle := _v(look["muzzle"])
	head.box(Vector3i(2, 0, 5), Vector3i(4, 2, 6), muzzle)
	head.box(Vector3i(2, 0, 4), Vector3i(4, 1, 4), muzzle)
	head.box(Vector3i(3, 2, 7), Vector3i(3, 2, 7), _v(NOSE))
	head.box(Vector3i(2, 0, 7), Vector3i(4, 1, 7), muzzle)
	if look["muzzle"] == look["belly"] and look["fur"][0] != look["belly"]:
		# A blaze up the face.
		head.box(Vector3i(3, 3, 3), Vector3i(3, 4, 4), muzzle)
	CreatureModels.eyes(head, 1, 5, 3, 4)
	var ear := _v(look["ear"])
	match look["ears"]:
		"pricked":
			for x: int in [1, 4]:
				head.box(Vector3i(x, 5, 1), Vector3i(x + 1, 5, 1), ear)
			head.set_voxel(Vector3i(1, 6, 1), ear)
			head.set_voxel(Vector3i(5, 6, 1), ear)
		"folded":
			for x: int in [1, 4]:
				head.box(Vector3i(x, 5, 1), Vector3i(x + 1, 5, 1), ear)
			head.set_voxel(Vector3i(1, 5, 2), ear)
			head.set_voxel(Vector3i(5, 5, 2), ear)
		_:
			# Floppy: hanging down by the cheeks.
			for x: int in [0, 6]:
				head.box(Vector3i(x, 1, 1), Vector3i(x, 4, 2), ear)
			head.box(Vector3i(1, 5, 1), Vector3i(1, 5, 2), ear)
			head.box(Vector3i(5, 5, 1), Vector3i(5, 5, 2), ear)
	return _part("head", head, Vector3(-3.5, 7.0, 5.0), Vector3(0.0, 9.0, 6.0))


# ---------------------------------------------------------------- cats


## A cat: a slim body, a round head with pointed ears, whiskers, bright
## eyes, a long tail held up (it sways: CreatureBody); tabby stripes, a
## calico's patches, a Siamese's dark points.
static func _cat(look: Dictionary, collar: bool) -> Array:
	var points := String(look["points"])
	var leg_colors: Array = [points, points] if points != "" else [look["fur"][0], look["fur"][1]]
	var leg := CreatureModels.leg_grid(2, 4, leg_colors, look["fur"][0])
	var parts: Array = CreatureModels.four_legs(leg, 1, 2, -5)
	var body := VoxelGrid.new(Vector3i(7, 6, 14))
	var fur := CreatureModels.shaded(look["fur"], 1.0, 5.0, 233)
	var belly := _v(look["belly"])
	var stripe := String(look["stripe"])
	var stripes := _v(stripe) if stripe != "" else 0
	var patches: Array[int] = []
	for color: String in look["patches"]:
		patches.append(_v(color))
	var paint := func(p: Vector3i) -> int:
		if p.y <= 1:
			return belly
		if (
			stripes != 0
			and p.y >= 2
			and (p.z + int(CreatureModels.noise(p / 3, 239) * 2.0)) % 3 == 0
		):
			return stripes
		if not patches.is_empty():
			var n := CreatureModels.noise(p / 3, 241)
			if n > 0.62:
				return patches[0]
			if n < 0.22:
				return patches[1]
		return fur.call(p)
	body.ellipsoid(Vector3(3.5, 3.0, 7.0), Vector3(2.6, 2.4, 5.6), paint)
	if collar:
		_collar(body, 10)
	parts.append(_part("body", body, Vector3(-3.5, 3.0, -7.0), Vector3(0.0, 3.0, 0.0)))
	var tail := VoxelGrid.new(Vector3i(1, 6, 9))
	var tail_paint := func(p: Vector3i) -> int:
		if points != "":
			return _v(points)
		if stripes != 0 and p.y % 3 == 1:
			return stripes
		return _v(look["fur"][1])
	tail.line(Vector3(0.5, 0.5, 8.5), Vector3(0.5, 1.5, 4.5), 0.5, tail_paint)
	tail.line(Vector3(0.5, 1.5, 4.5), Vector3(0.5, 4.0, 1.5), 0.5, tail_paint)
	tail.line(Vector3(0.5, 4.0, 1.5), Vector3(0.5, 5.5, 0.5), 0.5, tail_paint)
	parts.append(_part("tail", tail, Vector3(-0.5, 6.5, -14.0), Vector3(0.0, 7.0, -5.5)))
	parts.append(_cat_head(look))
	return parts


static func _cat_head(look: Dictionary) -> Variant:
	var head := VoxelGrid.new(Vector3i(7, 7, 5))
	var points := String(look["points"])
	head.box(
		Vector3i(1, 0, 0), Vector3i(5, 4, 3), CreatureModels.shaded(look["fur"], 0.0, 4.0, 251)
	)
	if look["stripe"] != "":
		for x: int in [2, 4]:
			head.set_voxel(Vector3i(x, 4, 2), _v(look["stripe"]))
		head.set_voxel(Vector3i(3, 4, 1), _v(look["stripe"]))
	var muzzle := _v(points) if points != "" else _v(look["belly"])
	head.box(Vector3i(2, 0, 4), Vector3i(4, 1, 4), muzzle)
	head.set_voxel(Vector3i(3, 1, 4), _v(CAT_NOSE))
	var eyes := _v(look["eyes"])
	for x: int in [1, 5]:
		head.set_voxel(Vector3i(x, 3, 3), eyes)
	head.set_voxel(Vector3i(2, 3, 3), _v(CreatureModels.EYE))
	head.set_voxel(Vector3i(4, 3, 3), _v(CreatureModels.EYE))
	for x: int in [0, 6]:
		head.set_voxel(Vector3i(x, 1, 4), _v(WHISKER))
	var ear := _v(points) if points != "" else _v(look["fur"][0])
	for x: int in [1, 4]:
		head.box(Vector3i(x, 5, 1), Vector3i(x + 1, 5, 1), ear)
	head.set_voxel(Vector3i(1, 6, 1), ear)
	head.set_voxel(Vector3i(5, 6, 1), ear)
	head.set_voxel(Vector3i(2, 5, 1), _v(EAR_PINK))
	head.set_voxel(Vector3i(4, 5, 1), _v(EAR_PINK))
	return _part("head", head, Vector3(-3.5, 5.0, 4.0), Vector3(0.0, 7.0, 5.0))
