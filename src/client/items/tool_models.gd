class_name ToolModels
extends RefCounted
## The tools, the swords and the bow. Each is drawn once as a profile
## (`_paint`: what lies at (u, v), u along the handle from its butt, v
## across it, > 0 on the side that strikes, in model voxels: half a voxel
## of the body each, SCALE) with a thickness, then built two ways: straight
## for the hands (`held`: the handle along y, the side that strikes towards
## +z, centered on the grip) and on the diagonal of a 16 x 16 grid for the
## icon and the item lying on the ground (`icon`, like block games). The
## head takes its material's colors (ItemModels.TOOL_HEADS); wood is grained,
## the grips wrapped in leather, the edges and points bright where they are
## sharpened. The bow bends as it is drawn (`held` stages 0 to DRAW_STAGES -
## 1), an arrow on the string. The fishing rod (a bamboo pole, a cork grip,
## a reel hanging under it, rings along it for the line) carries its bobber
## hooked near the grip (stage 0) until it is cast (stage 1: the bobber is
## out, Angler draws the line to it); its line is thin boxes (rod_lines).

## What a profile paints (see _colors).
enum Paint {
	NONE,
	WOOD_DARK,
	WOOD,
	WOOD_LIGHT,
	END_GRAIN,
	WRAP_DARK,
	WRAP,
	HEAD_DARK,
	HEAD,
	HEAD_LIGHT,
	HEAD_SHINE,
	BAND,
	STRING,
	SHAFT,
	POINT,
	FLETCH,
	FLETCH_RED,
	CORK,
	CORK_DARK,
	BAMBOO_DARK,
	BAMBOO,
	REEL_DARK,
	REEL,
	REEL_LIGHT,
}

## The bow's kind and the fishing rod's (the tools': Items.Tool).
const BOW := -1
const ROD := -2
## The rod's stages: its bobber hooked near the grip, then cast.
const ROD_STAGES := 2
## In hand, a model voxel is this much of a voxel of the body.
const SCALE := 0.5
const DRAW_STAGES := 4
## Handles: dark, mid, light wood and the end grain; leather; iron bands.
const HANDLE := ["#4a2f19", "#6b4527", "#8c6340", "#b08a5e"]
const WRAP := ["#2f1d12", "#5c3b25"]
const BAND := "#45454d"
const BOW_WOOD := ["#5a3519", "#80522c", "#a8743f", "#c4945e"]
const STRING := "#ebe4cf"
const SHAFT := "#c49b5f"
const POINT := ["#5c5b66", "#9a99a6"]
const FLETCH := ["#f2efe8", "#d8442e"]
const CORK := ["#a87a4a", "#c89a62"]
const BAMBOO := ["#8a6a2e", "#c8a458", "#e0c47a"]
const REEL := ["#2e2e36", "#6a6a76", "#b4b4c0"]
const LINE := "#e8e6dc"
## Per kind: the length of the profile (u), the thickness of its widest
## part (x in hand), what it spans across (v, in hand) and where the hand
## holds it (u, v).
const LENGTH := {
	Items.Tool.PICKAXE: 25,
	Items.Tool.AXE: 26,
	Items.Tool.SHOVEL: 31,
	Items.Tool.SWORD: 31,
	Items.Tool.HOE: 28,
	BOW: 35,
	ROD: 72,
}
const WIDTH := {
	Items.Tool.PICKAXE: 4,
	Items.Tool.AXE: 4,
	Items.Tool.SHOVEL: 4,
	Items.Tool.SWORD: 4,
	Items.Tool.HOE: 6,
	BOW: 2,
	ROD: 3,
}
const SPAN := {
	Items.Tool.PICKAXE: Vector2i(-12, 12),
	Items.Tool.AXE: Vector2i(-5, 11),
	Items.Tool.SHOVEL: Vector2i(-5, 5),
	Items.Tool.SWORD: Vector2i(-7, 7),
	Items.Tool.HOE: Vector2i(-2, 8),
	BOW: Vector2i(-15, 9),
	ROD: Vector2i(-8, 4),
}
const GRIP := {
	Items.Tool.PICKAXE: Vector2(4.5, 0.0),
	Items.Tool.AXE: Vector2(4.5, 0.0),
	Items.Tool.SHOVEL: Vector2(4.5, 0.0),
	Items.Tool.SWORD: Vector2(5.5, 0.0),
	Items.Tool.HOE: Vector2(4.5, 0.0),
	BOW: Vector2(17.5, 2.5),
	ROD: Vector2(10.0, 0.0),
}
## The rod: where its rings are (u), where the bobber hangs hooked.
const RINGS: Array[float] = [24.0, 36.0, 47.0, 57.0, 66.0]
const HOOKED := Vector2(18.5, 2.0)
## The icon's diagonal (the 16 x 16 grid's) and the margin kept to its
## edges.
const DIAGONAL := 22.627417
const ICON_MARGIN := 0.35
const SQRT_HALF := 0.70710678

## Per kind: how the profile fits the icon's diagonal [scale, u0, shift].
static var _fits: Dictionary[int, Vector3] = {}


## The kind of an item drawn here (Items.Tool, BOW), Items.Tool.NONE for others.
static func kind_of(item: int) -> int:
	if item == Items.Id.BOW:
		return BOW
	if item == Items.Id.FISHING_ROD:
		return ROD
	return Items.tool_of(item)


static func has(item: int) -> bool:
	return kind_of(item) != Items.Tool.NONE


## The bow's stage for how far it is drawn (0..1).
static func stage_of(draw: float) -> int:
	if draw < 0.1:
		return 0
	return 1 if draw < 0.45 else (2 if draw < 0.85 else 3)


## The bow's string and, drawn, the arrow on it, as thin boxes in the
## model `held` builds (mesh units): [from, to, half thickness across the
## bow, half thickness in its plane, color].
static func bow_lines(stage: int) -> Array:
	var bend := 4.5 + 1.0 * stage
	var nock := 2.5 - bend * 0.9025
	var back := nock - 3.0 * stage
	var grip_v: float = GRIP[BOW].y
	var at := func(u: float, v: float) -> Vector3:
		return Vector3(0.0, u, v - grip_v) * VoxelMesher.VOXEL
	var low: Vector3 = at.call(17.5 - 0.95 * 17.5, nock)
	var high: Vector3 = at.call(17.5 + 0.95 * 17.5, nock)
	var middle: Vector3 = at.call(17.5, back)
	var string := Color(STRING)
	var thin := 0.3 * VoxelMesher.VOXEL
	var lines := [[low, middle, thin, thin, string], [middle, high, thin, thin, string]]
	if stage == 0:
		return [[low, high, thin, thin, string]]
	var front := 8.5
	var shaft := 0.45 * VoxelMesher.VOXEL
	lines.append([at.call(17.5, back), at.call(17.5, front - 2.5), shaft, shaft, Color(SHAFT)])
	var point := 0.9 * VoxelMesher.VOXEL
	lines.append([at.call(17.5, front - 3.0), at.call(17.5, front), point, point, Color(POINT[0])])
	var vane := 1.3 * VoxelMesher.VOXEL
	var flat := 0.12 * VoxelMesher.VOXEL
	for i in 2:
		var from: Vector3 = at.call(17.5, back + 0.5 + i * 1.8)
		var to: Vector3 = at.call(17.5, back + 2.2 + i * 1.8)
		var color := Color(FLETCH[i])
		lines.append([from, to, flat, vane, color])
		lines.append([from, to, vane, flat, color])
	return lines


## The rod's line, as thin boxes in the model `held` builds (see
## bow_lines): from the reel along the rings to the tip, and back from the
## tip to the bobber hooked near the grip (stage 0).
static func rod_lines(stage: int) -> Array:
	var at := func(u: float, v: float) -> Vector3:
		return Vector3(0.0, u, v - GRIP[ROD].y) * VoxelMesher.VOXEL
	var thin := 0.15 * VoxelMesher.VOXEL
	var color := Color(LINE)
	var points: Array[Vector3] = [at.call(10.0, -2.0)]
	for ring in RINGS:
		points.append(at.call(ring, -1.4))
	points.append(at.call(LENGTH[ROD] - 0.5, -0.4))
	if stage == 0:
		points.append(at.call(HOOKED.x + 1.2, HOOKED.y + 0.6))
	var lines := []
	for i in points.size() - 1:
		lines.append([points[i], points[i + 1], thin, thin, color])
	return lines


## The tip of the rod in the model `held` builds (mesh units).
static func rod_tip() -> Vector3:
	return Vector3(0.0, (LENGTH[ROD] - 0.5) * VoxelMesher.VOXEL, -0.4 * VoxelMesher.VOXEL)


## Where the hand holds the model `held` builds (local units of its mesh:
## VoxelMesher centers it on the grip across, y from its butt).
static func grip(item: int) -> Vector3:
	return Vector3(0.0, GRIP[kind_of(item)].x * VoxelMesher.VOXEL, 0.0)


## The model in hand: the handle along y, the side that strikes towards
## +z, the thickness along x; centered on the grip. `stage`: how far a bow
## is drawn (0 to DRAW_STAGES - 1); its string and arrow are not in it but
## thin lines (bow_lines).
static func held(item: int, stage := 0) -> VoxelGrid:
	var kind := kind_of(item)
	var span: Vector2i = SPAN[kind]
	var width: int = WIDTH[kind]
	var length: int = LENGTH[kind]
	var colors := _colors(item)
	var grid := VoxelGrid.new(Vector3i(width, length, span.y - span.x))
	var grip_at: Vector2 = GRIP[kind]
	grid.pivot = Vector2(width * 0.5, grip_at.y - span.x)
	for y in length:
		for z in span.y - span.x:
			var paint := _paint(kind, y + 0.5, span.x + z + 0.5, stage, 0.0)
			if paint.x != Paint.NONE:
				_fill(grid, Vector3i(-1, y, z), paint, width, colors)
	return grid


## The icon's model: the profile on the diagonal of a 16 x 16 grid, the
## handle from the bottom left, the head at the top right; its thickness
## along z.
static func icon(item: int) -> VoxelGrid:
	var kind := kind_of(item)
	var width: int = WIDTH[kind]
	var colors := _colors(item)
	var fit := _fit(kind)
	var grid := VoxelGrid.new(Vector3i(16, 16, width))
	for x in 16:
		for y in 16:
			var along := (x + y + 1.0) * SQRT_HALF
			var across := (y - x) * SQRT_HALF + 0.3535534
			var u := (along - fit.y) * fit.x
			var v := (across - fit.z) * fit.x
			var paint := _paint(kind, u, v, 0, fit.x)
			if paint.x != Paint.NONE:
				_fill(grid, Vector3i(x, y, -1), paint, width, colors)
	return grid


## Fills the thickness of a painted spot (the -1 of `at` along it),
## centered; thick parts are darker on their outer faces.
static func _fill(
	grid: VoxelGrid, at: Vector3i, paint: Vector2i, width: int, colors: Dictionary
) -> void:
	var thick := mini(paint.y, width)
	var first := (width - thick) / 2
	var axis := 0 if at.x < 0 else 2
	for i in thick:
		var shade := paint.x
		if thick >= 3 and (i == 0 or i == thick - 1):
			shade = _darker(shade)
		var cell := at
		cell[axis] = first + i
		grid.set_voxel(cell, colors[shade])


static func _darker(paint: int) -> int:
	match paint:
		Paint.HEAD_SHINE:
			return Paint.HEAD_LIGHT
		Paint.HEAD_LIGHT:
			return Paint.HEAD
		Paint.HEAD:
			return Paint.HEAD_DARK
		Paint.WOOD_LIGHT:
			return Paint.WOOD
		Paint.WOOD:
			return Paint.WOOD_DARK
	return paint


## The voxel of each paint for an item (its head's material).
static func _colors(item: int) -> Dictionary:
	var colors := {}
	var bow := item == Items.Id.BOW
	var wood: Array = BOW_WOOD if bow else HANDLE
	var head: Array = POINT if bow else ItemModels.TOOL_HEADS[maxi(Items.tier_of(item), 0)]
	var codes := {
		Paint.WOOD_DARK: wood[0],
		Paint.WOOD: wood[1],
		Paint.WOOD_LIGHT: wood[2],
		Paint.END_GRAIN: wood[3],
		Paint.WRAP_DARK: WRAP[0],
		Paint.WRAP: WRAP[1],
		Paint.HEAD_DARK: head[0],
		Paint.HEAD: head[1] if head.size() > 1 else head[0],
		Paint.HEAD_LIGHT: head[mini(2, head.size() - 1)],
		Paint.HEAD_SHINE: head[head.size() - 1],
		Paint.BAND: BAND,
		Paint.STRING: STRING,
		Paint.SHAFT: SHAFT,
		Paint.POINT: POINT[1],
		Paint.FLETCH: FLETCH[0],
		Paint.FLETCH_RED: FLETCH[1],
		Paint.CORK: CORK[1],
		Paint.CORK_DARK: CORK[0],
		Paint.BAMBOO_DARK: BAMBOO[0],
		Paint.BAMBOO: BAMBOO[1],
		Paint.REEL_DARK: REEL[0],
		Paint.REEL: REEL[1],
		Paint.REEL_LIGHT: REEL[2],
	}
	for paint: int in codes:
		colors[paint] = VoxelGrid.voxel(Color(codes[paint]))
	return colors


## How a kind's profile fits the icon's diagonal [scale, u0, shift]: as
## large as it can, centered, inside the diamond the 16 x 16 grid makes
## around the diagonal.
static func _fit(kind: int) -> Vector3:
	if _fits.has(kind):
		return _fits[kind]
	var points: Array[Vector2] = []
	var span: Vector2i = SPAN[kind]
	var length: int = LENGTH[kind]
	for i in length * 2:
		for j in (span.y - span.x) * 2:
			var u := i * 0.5 + 0.25
			var v := span.x + j * 0.5 + 0.25
			if _paint(kind, u, v, 0, 1.0).x != Paint.NONE:
				points.append(Vector2(u, v))
	var low := Vector2.INF
	var high := -Vector2.INF
	for point in points:
		low = low.min(point)
		high = high.max(point)
	var fit := Vector3(1.0, 0.0, 0.0)
	for step in 60:
		var scale := 0.9 + step * 0.05
		var u0 := (DIAGONAL - (high.x - low.x) / scale) * 0.5 - low.x / scale
		var shift := -(low.y + high.y) * 0.5 / scale
		var inside := true
		for point in points:
			var along := point.x / scale + u0
			var across := point.y / scale + shift
			if absf(across) > minf(along, DIAGONAL - along) - ICON_MARGIN:
				inside = false
				break
		fit = Vector3(scale, u0, shift)
		if inside:
			break
	_fits[kind] = fit
	return fit


## What lies at (u, v) of a kind's profile: [paint, thickness]. `fat`
## widens thin lines (the icon samples the profile `fat` apart; 0: no
## lines, drawn by bow_lines instead).
static func _paint(kind: int, u: float, v: float, stage: int, fat: float) -> Vector2i:
	match kind:
		Items.Tool.PICKAXE:
			return _pickaxe(u, v)
		Items.Tool.AXE:
			return _axe(u, v)
		Items.Tool.SHOVEL:
			return _shovel(u, v)
		Items.Tool.SWORD:
			return _sword(u, v)
		Items.Tool.HOE:
			return _hoe(u, v)
		BOW:
			return _bow(u, v, stage, fat)
		ROD:
			return _rod(u, v, stage, fat)
	return Vector2i.ZERO


## A wooden handle up to `top`: a dark knob at its butt, leather wrapped
## round where the hand holds it, grained wood above.
static func _handle(u: float, v: float, top: float) -> Vector2i:
	if u < 0.0 or u >= top or absf(v) >= 1.0:
		return Vector2i.ZERO
	if u < 1.0:
		return Vector2i(Paint.WOOD_DARK, 2)
	if u < 7.0:
		return Vector2i(Paint.WRAP_DARK if int(u) % 2 == 0 else Paint.WRAP, 2)
	if int(u * 0.5 + (0.0 if v > 0.0 else 1.5)) % 4 == 0:
		return Vector2i(Paint.WOOD_DARK, 2)
	return Vector2i(Paint.WOOD_LIGHT if v > 0.0 else Paint.WOOD, 2)


## A pickaxe: a curved bar across the top of the handle, its points bent
## down and sharpened, through an eye wedged with the handle's end grain.
static func _pickaxe(u: float, v: float) -> Vector2i:
	if u >= 20.0 and u < 25.0 and absf(v) < 2.0:
		var grain := u >= 24.0 and absf(v) < 1.0
		return Vector2i(Paint.END_GRAIN if grain else Paint.HEAD_DARK, 2 if grain else 4)
	var reach := absf(v) / 11.5
	if reach < 1.0:
		var middle := 22.4 - 0.045 * v * v
		var half := 0.6 + 1.3 * (1.0 - reach * reach)
		var d := u - middle
		if absf(d) < half:
			var paint := Paint.HEAD
			if d > half - 0.9:
				paint = Paint.HEAD_LIGHT
			elif d < -half + 0.9:
				paint = Paint.HEAD_DARK
			if reach > 0.8:
				paint = Paint.HEAD_SHINE if d > -0.3 else Paint.HEAD_LIGHT
			return Vector2i(paint, 2)
	return _handle(u, v, 24.0)


## An axe: a blade flaring down from the eye to a bright cutting edge (a
## bearded axe), a short poll behind.
static func _axe(u: float, v: float) -> Vector2i:
	if u >= 19.0 and u < 25.0 and v >= -2.0 and v < 2.0:
		var grain := u >= 24.0 and absf(v) < 1.0
		return Vector2i(Paint.END_GRAIN if grain else Paint.HEAD_DARK, 2 if grain else 4)
	if v >= 2.0 and v < 10.5:
		var top := 24.6 + 0.12 * (v - 2.0)
		var bottom := 20.5 - 0.55 * maxf(v - 3.5, 0.0)
		if u >= bottom and u < top:
			var paint := Paint.HEAD
			if v >= 9.5:
				paint = Paint.HEAD_SHINE
			elif v >= 8.5:
				paint = Paint.HEAD_LIGHT
			elif v < 3.0 or u < bottom + 0.8:
				paint = Paint.HEAD_DARK
			elif u > top - 0.9:
				paint = Paint.HEAD_LIGHT
			return Vector2i(paint, 2)
	if v >= -4.5 and v < -2.0 and u >= 20.0 and u < 24.0:
		return Vector2i(Paint.HEAD if v < -3.5 else Paint.HEAD_DARK, 4)
	return _handle(u, v, 24.0)


## A shovel: an iron collar, then a spade rounded at its tip, its edges
## rolled and its tip worn bright, a ridge down its middle.
static func _shovel(u: float, v: float) -> Vector2i:
	if u >= 18.0 and u < 21.0 and absf(v) < 2.0:
		return Vector2i(Paint.BAND if u < 19.0 else Paint.HEAD_DARK, 4 if u < 19.0 else 2)
	if u >= 21.0 and u < 31.0:
		var half := 4.5
		if u > 26.5:
			var t := (u - 26.5) / 4.5
			half = 4.5 * sqrt(maxf(1.0 - t * t, 0.0))
		if absf(v) < half:
			if absf(v) < 1.0 and u < 25.0:
				return Vector2i(Paint.HEAD_DARK, 2)
			var paint := Paint.HEAD
			if u > 29.5:
				paint = Paint.HEAD_SHINE
			elif absf(v) > half - 1.0:
				paint = Paint.HEAD_LIGHT
			return Vector2i(paint, 1)
	return _handle(u, v, 19.0)


## A sword: a round pommel, a grip wrapped in leather, a crossguard, then
## a blade with a dark fuller down its middle, bevelled bright edges and a
## shining point.
static func _sword(u: float, v: float) -> Vector2i:
	if u < 2.5:
		if absf(v) >= 2.0 or (u < 0.8 and absf(v) > 1.0) or u < 0.0:
			return Vector2i.ZERO
		return Vector2i(Paint.HEAD_DARK if u < 1.0 else Paint.HEAD, 4)
	if u < 8.5:
		if absf(v) >= 1.0:
			return Vector2i.ZERO
		return Vector2i(Paint.WRAP_DARK if int(u) % 2 == 0 else Paint.WRAP, 2)
	if u < 10.5:
		if absf(v) >= 6.0:
			return Vector2i.ZERO
		var paint := Paint.HEAD_DARK if u < 9.5 else Paint.HEAD
		if absf(v) >= 4.5:
			paint = Paint.HEAD_LIGHT
		return Vector2i(paint, 4 if absf(v) < 2.0 else 2)
	if u >= 31.0:
		return Vector2i.ZERO
	var half := 2.0 if u < 25.0 else 2.0 * (31.0 - u) / 6.0
	if absf(v) >= half:
		return Vector2i.ZERO
	var paint := Paint.HEAD
	if absf(v) >= 1.0:
		paint = Paint.HEAD_LIGHT
	elif u < 23.0:
		paint = Paint.HEAD_DARK
	if u > 28.5:
		paint = Paint.HEAD_SHINE
	return Vector2i(paint, 2)


## A hoe: an eye over the handle's end, a neck forward, then a blade
## turned down along the handle, as wide as the thickness, sharpened bright
## at its lower edge.
static func _hoe(u: float, v: float) -> Vector2i:
	if u >= 24.0 and u < 27.0 and absf(v) < 1.0:
		return Vector2i(Paint.HEAD_DARK, 4)
	if u >= 24.5 and u < 27.0 and v >= 1.0 and v < 6.0:
		return Vector2i(Paint.HEAD_DARK if v < 2.0 else Paint.HEAD, 2)
	if v >= 6.0 and v < 7.0 and u >= 19.0 and u < 27.0:
		var paint := Paint.HEAD
		if u < 20.0:
			paint = Paint.HEAD_SHINE
		elif u < 21.5:
			paint = Paint.HEAD_LIGHT
		return Vector2i(paint, 6)
	return _handle(u, v, 24.0)


## A bow, its grip at (17.5, 2.5): limbs tapering to the nocks at its
## tips, a leather grip, the string from tip to tip; drawn (`stage` > 0)
## the limbs bend back, the string comes back in a V and an arrow lies on
## it.
static func _bow(u: float, v: float, stage: int, fat: float) -> Vector2i:
	var x := (u - 17.5) / 17.5
	if absf(x) > 1.0:
		return Vector2i.ZERO
	var bend := 4.5 + 1.0 * stage
	var limb := 2.5 - bend * x * x
	var nock := 2.5 - bend * 0.9025
	var string_back := nock - 3.0 * stage
	var front := 2.5 + 6.0
	var off := absf(u - 17.5)
	var half := 1.5 if off < 2.5 else 1.15 - 0.6 * absf(x)
	if absf(v - limb) < half * maxf(fat * 0.8, 1.0):
		if off < 2.5:
			return Vector2i(Paint.WRAP_DARK if int(u) % 2 == 0 else Paint.WRAP, 2)
		if absf(x) > 0.92:
			return Vector2i(Paint.BAND, 2)
		return Vector2i(Paint.WOOD_LIGHT if v > limb else Paint.WOOD, 2)
	if fat <= 0.0:
		return Vector2i.ZERO
	var along := v - string_back
	if stage > 0 and off < 1.5 and along >= 0.0 and v < front:
		if v >= front - 3.0:
			if off < (front - v) * 0.5 + 0.2:
				return Vector2i(Paint.POINT, 1)
		elif along < 4.0:
			return Vector2i(Paint.FLETCH_RED if int(along) % 2 == 1 else Paint.FLETCH, 1)
		elif off < 0.5 * fat + 0.01:
			return Vector2i(Paint.SHAFT, 1)
	if absf(x) <= 0.95:
		var slope := (nock - string_back) / (0.95 * 17.5)
		var line := string_back + (nock - string_back) * absf(x) / 0.95
		if absf(v - line) < 0.5 * sqrt(1.0 + slope * slope) * fat:
			return Vector2i(Paint.STRING, 1)
	return Vector2i.ZERO


## A fishing rod: a dark butt, a cork grip, a reel hanging under it (its
## spool, a crank), a bamboo pole tapering to a red tip, darker at its
## nodes, rings under it for the line; at stage 0 the bobber (red over
## white) hooked over the pole near the grip.
static func _rod(u: float, v: float, stage: int, fat: float) -> Vector2i:
	if u < 0.0 or u >= LENGTH[ROD]:
		return Vector2i.ZERO
	var wide := maxf(fat * 0.5, 0.5)
	if stage == 0 and Vector2(u, v).distance_to(HOOKED) < maxf(1.3, fat * 0.6):
		return Vector2i(Paint.FLETCH_RED if u > HOOKED.x else Paint.FLETCH, 2)
	var reel := Vector2(u, v).distance_to(Vector2(10.0, -4.5))
	if reel < 2.6:
		return Vector2i(Paint.REEL_LIGHT if reel < 1.0 else Paint.REEL, 3)
	if absf(u - 10.0) < maxf(0.5, wide) and v > -2.2 and v < -1.0:
		return Vector2i(Paint.REEL_DARK, 1)
	if Vector2(u, v).distance_to(Vector2(11.8, -6.6)) < maxf(0.7, wide):
		return Vector2i(Paint.REEL_DARK, 2)
	for ring in RINGS:
		if absf(u - ring) < maxf(0.5, wide) and v > -1.9 and v <= -0.9:
			return Vector2i(Paint.REEL_LIGHT, 1)
	var half := 1.1 if u < 15.0 else lerpf(0.9, 0.45, (u - 15.0) / (LENGTH[ROD] - 15.0))
	if absf(v) > maxf(half, wide):
		return Vector2i.ZERO
	if u < 1.0:
		return Vector2i(Paint.REEL_DARK, 2)
	if u < 15.0:
		var speck := HashUtil.unit2(0x0C0, int(u * 2.0), int(v * 2.0 + 8.0)) < 0.3
		return Vector2i(Paint.CORK_DARK if speck else Paint.CORK, 2)
	if u >= LENGTH[ROD] - 2.0:
		return Vector2i(Paint.FLETCH_RED, 1)
	var thick := 2 if u < 40.0 else 1
	if fmod(u - 15.0, 11.0) < 1.0:
		return Vector2i(Paint.BAMBOO_DARK, thick)
	return Vector2i(Paint.BAMBOO, thick)
