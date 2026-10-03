class_name TreeModels
extends RefCounted
## Procedural voxel trees, detailed but still pixel art (one voxel is one
## art pixel). Trunks taper, lean and waver, flaring at the foot over
## spreading roots; branches fork towards the light; leaves grow in
## clusters at their tips, lit from above and darker inside, with gaps that
## show the branches; bark has grooves, knots and moss.
##
## Trunk sizes come from ObjectShapes (physics blocks the trunk drawn).
## Every version of a tree differs in size and shape. Fruit trees are small
## orchard trees, in blossom or bearing fruit (the same tree: see build).

## How blossoms and fruit sit on a crown (_dot_crown).
enum Dot { SINGLE, PAIR, BALL }

const OAK_LEAVES := ["#1d4626", "#285d31", "#377739", "#529343", "#7cbb55"]
const BIRCH_LEAVES := ["#3b6a24", "#51862e", "#6ca33b", "#91c152", "#bcdd7a"]
const DARK_LEAVES := ["#11291a", "#183a21", "#21502a", "#316834", "#4a8443"]
const JUNGLE_LEAVES := ["#124620", "#1b5f2d", "#287b3a", "#41994a", "#70c262"]
const SWAMP_LEAVES := ["#233a20", "#304f2a", "#426536", "#5a7f47", "#7b9a5e"]
const ACACIA_LEAVES := ["#465d25", "#5a752e", "#73903a", "#92ad4b", "#b6ca69"]
const SPRUCE_LEAVES := ["#0d2a1d", "#143b28", "#1c5034", "#286642", "#3b7f55"]

const OAK_BARK := ["#2f1d12", "#4a2e1b", "#654027", "#835736"]
const BIRCH_BARK := ["#9d978c", "#c3beb3", "#ddd9cf", "#f2efe8"]
const DARK_BARK := ["#1c120b", "#2d1d12", "#40291a", "#553724"]
const JUNGLE_BARK := ["#3b2b1c", "#56402a", "#71563a", "#8e7150"]
const SWAMP_BARK := ["#211a12", "#33281c", "#473828", "#5e4c37"]
const ACACIA_BARK := ["#4c4136", "#65584a", "#807261", "#9d8e7c"]
const SPRUCE_BARK := ["#2a170c", "#3f2414", "#57331d", "#6f4429"]
const MOSS := ["#33502a", "#4a6c34"]
const HANGING_MOSS := ["#5f6f50", "#7b8b6a", "#97a585"]
const VINES := ["#245019", "#336d22", "#468a2e"]
const SNOW := ["#c7d4e4", "#e1e9f3", "#f6f9fc"]

## Leaves never grow below this height (voxels, 2 levels) nor hanging
## strands below STRAND_FLOOR: in first person the eye (1.35 levels) stays
## out of the crowns, and walking under trees shows their trunks.
const LEAF_FLOOR := 32
const STRAND_FLOOR := 30
## A young tree's (Growth) come lower: it is small, and blocks bodies anyway.
const YOUNG_LEAF_FLOOR := 10
const YOUNG_STRAND_FLOOR := 8

## Leaves while a crown is being shaped, before the lighting pass paints
## them.
static var _leaf := VoxelGrid.voxel(Color("#00ff00"), VoxelGrid.Kind.FOLIAGE)
## The floors of the tree being built (see build; models are built one at
## a time, by tools/gen_models.gd).
static var _leaf_floor := LEAF_FLOOR
static var _strand_floor := STRAND_FLOOR


## The working space of a tree: a grid larger than needed (cropped at the
## end), the foot of the trunk and the tips where leaves grow.
class Sketch:
	extends RefCounted
	var grid: VoxelGrid
	var base := Vector3.ZERO
	var tips: Array[Vector3] = []
	## Box holding every leaf (passes over the leaves stay inside it).
	var leaf_low := Vector3i.MAX
	var leaf_high := Vector3i.MIN

	func _init(width: int, height: int) -> void:
		var half := floori(width / 2.0)
		grid = VoxelGrid.new(Vector3i(width, height, width))
		base = Vector3(half, 0, half)
		# The trunk's foot stands on the tile's center.
		grid.pivot = Vector2(half, half)

	func add_leaf_box(low: Vector3i, high: Vector3i) -> void:
		var last := grid.size - Vector3i.ONE
		leaf_low = leaf_low.min(low).clamp(Vector3i.ZERO, last)
		leaf_high = leaf_high.max(high).clamp(Vector3i.ZERO, last)


static func build(block: int, variant: int) -> VoxelGrid:
	var rng := RandomNumberGenerator.new()
	# A fruit tree bearing fruit grows the crown of the same tree in
	# blossom (ObjectShapes.BEARING).
	rng.seed = HashUtil.hash2(0x7EE5, ObjectShapes.BEARING.get(block, block), variant)
	var trunk := ObjectShapes.trunk(block, variant)
	var young := Growth.YOUNG.has(block)
	_leaf_floor = YOUNG_LEAF_FLOOR if young else LEAF_FLOOR
	_strand_floor = YOUNG_STRAND_FLOOR if young else STRAND_FLOOR
	# A young tree is its species' with a small trunk (ObjectShapes.TREES).
	var species: int = Growth.YOUNG.get(block, block)
	species = ObjectShapes.BEARING.get(species, species)
	if OrchardColors.TREES.has(species):
		var state := 0 if young else (2 if ObjectShapes.BEARING.has(block) else 1)
		return _fruit_tree(rng, trunk, species, state)
	match species:
		Tiles.Block.BIRCH:
			return _birch(rng, trunk)
		Tiles.Block.DARK_OAK:
			return _dark_oak(rng, trunk)
		Tiles.Block.JUNGLE_TREE:
			return _jungle(rng, trunk)
		Tiles.Block.SWAMP_OAK:
			return _swamp_oak(rng, trunk)
		Tiles.Block.ACACIA:
			return _acacia(rng, trunk)
		Tiles.Block.SPRUCE:
			return _spruce(rng, trunk, false)
		Tiles.Block.SNOWY_SPRUCE:
			return _spruce(rng, trunk, true)
	return _oak(rng, trunk)


# ---------------------------------------------------------------- species


## Broad and gnarly: the trunk splits into a few heavy limbs that fork
## again, under a round crown of dense clusters.
static func _oak(rng: RandomNumberGenerator, trunk: Vector2i) -> VoxelGrid:
	var w := trunk.x
	var h := trunk.y
	var scale := h / 55.0
	var sketch := Sketch.new(int(110 * scale) + w * 2, h + int(60 * scale))
	var salt := rng.randi()
	var centers := _trunk_centers(sketch, rng, w, h, rng.randf_range(0.0, 3.0), 1.5)
	var bark := _bark_paint(centers, OAK_BARK, 7.0, salt, 0.35)
	_paint_trunk(sketch, centers, w, 0.62, 0.55, bark)
	_roots(sketch, rng, w, rng.randi_range(4, 6), w * 1.6, w * 0.45, bark)
	var wood := _wood_paint(OAK_BARK, salt)
	var top := _top_of(centers)
	var limbs := rng.randi_range(3, 4)
	for i in limbs:
		var angle := TAU * (i + rng.randf_range(-0.25, 0.25)) / limbs
		var up := rng.randf_range(0.55, 1.0)
		var dir := Vector3(cos(angle), up, sin(angle)).normalized()
		var start := top - Vector3(0, rng.randf_range(0.0, 0.3) * h, 0)
		var spec := {"spread": 0.75, "rise": 0.45, "children": Vector2i(2, 3)}
		_grow(sketch, rng, start, dir, h * rng.randf_range(0.36, 0.48), w * 0.36, 2, spec, wood)
	sketch.tips.append(top + Vector3(0, h * 0.28, 0))
	var size := Vector3(11, 7.5, 11) * scale
	_crown(sketch, rng, size, 0.25, salt)
	_light_leaves(sketch, OAK_LEAVES, salt)
	return _finish(sketch, h)


## Tall and slender, white bark with black marks, many thin branches going
## up and small airy clusters.
static func _birch(rng: RandomNumberGenerator, trunk: Vector2i) -> VoxelGrid:
	var w := trunk.x
	var h := trunk.y
	var scale := h / 70.0
	var sketch := Sketch.new(int(70 * scale) + w * 2, h + int(40 * scale))
	var salt := rng.randi()
	var centers := _trunk_centers(sketch, rng, w, h, rng.randf_range(0.0, 2.5), 1.0)
	var bark := _birch_paint(centers, salt)
	_paint_trunk(sketch, centers, w, 0.72, 0.35, bark)
	_roots(sketch, rng, w, rng.randi_range(3, 4), w * 1.2, w * 0.35, bark)
	var wood := _wood_paint(["#3a332c", "#57504a", "#8a847a"], salt)
	var branches := rng.randi_range(7, 10)
	for i in branches:
		var t := lerpf(0.42, 0.95, float(i) / (branches - 1)) + rng.randf_range(-0.03, 0.03)
		var y := int(h * t)
		var angle := i * 2.4 + rng.randf_range(-0.4, 0.4)
		var dir := Vector3(cos(angle), rng.randf_range(0.9, 1.6), sin(angle)).normalized()
		var from := Vector3(centers[y].x, y, centers[y].y)
		var spec := {"spread": 0.6, "rise": 0.5, "children": Vector2i(1, 2)}
		var length := h * rng.randf_range(0.16, 0.26) * (1.15 - t * 0.4)
		_grow(sketch, rng, from, dir, length, 1.2, 1, spec, wood)
	sketch.tips.append(_top_of(centers) + Vector3(0, 6 * scale, 0))
	_crown(sketch, rng, Vector3(7, 6, 7) * scale, 0.4, salt)
	_light_leaves(sketch, BIRCH_LEAVES, salt)
	return _finish(sketch, h)


## Massive: several stems merged at the foot, thick roots, long limbs
## spreading under a broad, flat and dense canopy.
static func _dark_oak(rng: RandomNumberGenerator, trunk: Vector2i) -> VoxelGrid:
	var w := trunk.x
	var h := trunk.y
	var scale := h / 48.0
	var sketch := Sketch.new(int(120 * scale) + w * 2, h + int(56 * scale))
	var salt := rng.randi()
	var centers := _trunk_centers(sketch, rng, w, h, rng.randf_range(0.0, 2.0), 1.0)
	var bark := _bark_paint(centers, DARK_BARK, 9.0, salt, 0.5)
	_paint_trunk(sketch, centers, w, 0.7, 0.7, bark)
	# Secondary stems leaning out of the main one.
	for i in rng.randi_range(1, 3):
		var angle := rng.randf() * TAU
		var dir := Vector3(cos(angle), 2.6, sin(angle)).normalized()
		var from := sketch.base + Vector3(cos(angle), 0, sin(angle)) * w * 0.25
		_limb(sketch.grid, rng, from, from + dir * h * 0.8, w * 0.32, w * 0.24, bark)
	_roots(sketch, rng, w, rng.randi_range(6, 8), w * 1.5, w * 0.5, bark)
	var wood := _wood_paint(DARK_BARK, salt)
	var top := _top_of(centers)
	var limbs := rng.randi_range(4, 6)
	for i in limbs:
		var angle := TAU * (i + rng.randf_range(-0.3, 0.3)) / limbs
		var dir := Vector3(cos(angle), rng.randf_range(0.35, 0.6), sin(angle)).normalized()
		var start := top - Vector3(0, rng.randf_range(0.0, 0.35) * h, 0)
		var spec := {"spread": 0.7, "rise": 0.25, "children": Vector2i(2, 3)}
		var length := 37.0 * scale * rng.randf_range(0.6, 0.8)
		_grow(sketch, rng, start, dir, length, w * 0.3, 2, spec, wood)
	sketch.tips.append(top + Vector3(0, h * 0.3, 0))
	_crown(sketch, rng, Vector3(13, 6.5, 13) * scale, 0.18, salt)
	_light_leaves(sketch, DARK_LEAVES, salt)
	_mushrooms_at_foot(sketch, rng, w)
	return _finish(sketch, h)


## Very tall and straight on big buttress roots, branching only near the
## top into a wide canopy, with vines hanging down.
static func _jungle(rng: RandomNumberGenerator, trunk: Vector2i) -> VoxelGrid:
	var w := trunk.x
	var h := trunk.y
	var scale := h / 108.0
	var sketch := Sketch.new(int(100 * scale) + w * 2, h + int(44 * scale))
	var salt := rng.randi()
	var centers := _trunk_centers(sketch, rng, w, h, rng.randf_range(0.0, 4.0), 2.0)
	var bark := _bark_paint(centers, JUNGLE_BARK, 6.0, salt, 0.45)
	_paint_trunk(sketch, centers, w, 0.6, 0.6, bark)
	_buttresses(sketch, rng, w, rng.randi_range(4, 6), w * 2.0, w * 1.6, bark)
	var wood := _wood_paint(JUNGLE_BARK, salt)
	var top := _top_of(centers)
	var limbs := rng.randi_range(4, 6)
	for i in limbs:
		var angle := TAU * (i + rng.randf_range(-0.3, 0.3)) / limbs
		var dir := Vector3(cos(angle), rng.randf_range(0.45, 0.9), sin(angle)).normalized()
		var start := top - Vector3(0, rng.randf_range(0.0, 0.18) * h, 0)
		var spec := {"spread": 0.7, "rise": 0.35, "children": Vector2i(1, 2)}
		_grow(sketch, rng, start, dir, h * rng.randf_range(0.22, 0.3), w * 0.3, 2, spec, wood)
	sketch.tips.append(top + Vector3(0, h * 0.1, 0))
	_crown(sketch, rng, Vector3(13, 7.5, 13) * scale, 0.22, salt)
	_light_leaves(sketch, JUNGLE_LEAVES, salt)
	_hang(sketch, rng, VINES, 0.05, int(40 * scale))
	_climbing_vines(sketch, rng, centers, w)
	return _finish(sketch, h)


## Twisted and leaning over the water, flared roots, wide drooping limbs
## dripping with moss.
static func _swamp_oak(rng: RandomNumberGenerator, trunk: Vector2i) -> VoxelGrid:
	var w := trunk.x
	var h := trunk.y
	var scale := h / 54.0
	var sketch := Sketch.new(int(110 * scale) + w * 2, h + int(48 * scale))
	var salt := rng.randi()
	var centers := _trunk_centers(sketch, rng, w, h, rng.randf_range(3.0, 7.0), 3.5)
	var bark := _bark_paint(centers, SWAMP_BARK, 8.0, salt, 0.7)
	_paint_trunk(sketch, centers, w, 0.6, 0.9, bark)
	_roots(sketch, rng, w, rng.randi_range(6, 8), w * 2.2, w * 0.5, bark)
	var wood := _wood_paint(SWAMP_BARK, salt)
	var top := _top_of(centers)
	var limbs := rng.randi_range(4, 5)
	for i in limbs:
		var angle := TAU * (i + rng.randf_range(-0.3, 0.3)) / limbs
		var dir := Vector3(cos(angle), rng.randf_range(0.2, 0.45), sin(angle)).normalized()
		var start := top - Vector3(0, rng.randf_range(0.0, 0.3) * h, 0)
		var spec := {"spread": 0.7, "rise": -0.15, "children": Vector2i(2, 3)}
		var length := 41.0 * scale * rng.randf_range(0.55, 0.75)
		_grow(sketch, rng, start, dir, length, w * 0.32, 2, spec, wood)
	sketch.tips.append(top + Vector3(0, h * 0.2, 0))
	_crown(sketch, rng, Vector3(10, 5.5, 10) * scale, 0.25, salt)
	_light_leaves(sketch, SWAMP_LEAVES, salt)
	_hang(sketch, rng, HANGING_MOSS, 0.09, int(30 * scale))
	return _finish(sketch, h)


## The savanna's umbrella: the trunk forks low into leaning limbs, each
## holding a flat, layered crown.
static func _acacia(rng: RandomNumberGenerator, trunk: Vector2i) -> VoxelGrid:
	var w := trunk.x
	var h := trunk.y
	var scale := h / 42.0
	var sketch := Sketch.new(int(100 * scale) + w * 2, h + int(24 * scale))
	var salt := rng.randi()
	var fork := int(h * rng.randf_range(0.3, 0.42))
	var centers := _trunk_centers(sketch, rng, w, fork, rng.randf_range(0.0, 2.0), 0.8)
	var bark := _bark_paint(centers, ACACIA_BARK, 10.0, salt, 0.0)
	_paint_trunk(sketch, centers, w, 0.85, 0.4, bark)
	_roots(sketch, rng, w, rng.randi_range(3, 4), w * 1.4, w * 0.4, bark)
	var top := _top_of(centers)
	var limbs := rng.randi_range(2, 3)
	var turn := rng.randf() * TAU
	for i in limbs:
		var angle := turn + TAU * (i + rng.randf_range(-0.15, 0.15)) / limbs
		var reach := h * rng.randf_range(0.25, 0.38)
		var end := top + Vector3(cos(angle) * reach, h - fork, sin(angle) * reach)
		end.y -= rng.randf_range(0.0, 0.15) * h
		_limb(sketch.grid, rng, top, end, w * 0.42, w * 0.25, bark)
		_umbrella(sketch, rng, end, rng.randf_range(13.0, 18.0) * scale)
		# A smaller crown on a side branch.
		if rng.randf() < 0.7:
			var side := top.lerp(end, rng.randf_range(0.5, 0.75))
			var out := side + Vector3(cos(angle + 0.9), 0.5, sin(angle + 0.9)) * reach * 0.45
			_limb(sketch.grid, rng, side, out, w * 0.22, w * 0.15, bark)
			_umbrella(sketch, rng, out, rng.randf_range(8.0, 11.0) * scale)
	_light_leaves(sketch, ACACIA_LEAVES, salt)
	return _finish(sketch, h)


## A tall straight trunk with whorls of drooping boughs, wide at the bottom
## and narrowing to a spike: a ragged cone of dark needles.
static func _spruce(rng: RandomNumberGenerator, trunk: Vector2i, snowy: bool) -> VoxelGrid:
	var w := trunk.x
	var h := trunk.y
	var scale := h / 102.0
	var reach_max := h * rng.randf_range(0.26, 0.32)
	var sketch := Sketch.new(int(reach_max * 2.4) + w * 2, h + 10)
	var salt := rng.randi()
	var centers := _trunk_centers(sketch, rng, w, h, rng.randf_range(0.0, 2.0), 0.6)
	var bark := _bark_paint(centers, SPRUCE_BARK, 6.0, salt, 0.25)
	_paint_trunk(sketch, centers, w, 0.2, 0.45, bark)
	_roots(sketch, rng, w, rng.randi_range(3, 5), w * 1.3, w * 0.4, bark)
	var wood := _wood_paint(SPRUCE_BARK, salt)
	sketch.add_leaf_box(Vector3i.ZERO, sketch.grid.size)
	# The lowest whorl starts at the height leaves may grow from.
	var first := maxi(int(h * rng.randf_range(0.1, 0.16)), _leaf_floor + 2)
	var y := float(first)
	var angle := rng.randf() * TAU
	while y < h - 3:
		var t := (y - first) / (h - first)
		var reach := reach_max * pow(1.0 - t, 0.95) + 3.0
		var boughs := rng.randi_range(6, 9)
		for i in boughs:
			angle += 2.39996 + rng.randf_range(-0.3, 0.3)
			var length := reach * rng.randf_range(0.75, 1.05)
			var from := Vector3(centers[int(y)].x, y, centers[int(y)].y)
			_bough(sketch.grid, rng, from, angle, length, wood)
		y += rng.randf_range(6.0, 9.0) * clampf(1.1 - t * 0.4, 0.6, 1.1)
	# The leader at the top.
	var top := _top_of(centers)
	_cluster(sketch, top + Vector3(0, 2, 0), Vector3(2, 6, 2), salt)
	_smooth_leaves(sketch)
	_light_leaves(sketch, SPRUCE_LEAVES, salt)
	if snowy:
		_snow(sketch.grid)
	return _finish(sketch, h)


## A small orchard tree: a short trunk forking into a few spreading limbs
## under a round crown, in blossom (`state` 1) or bearing its fruit (2);
## young, leaves only (0). The blossoms and the fruit come last, from the
## crown's own noise: the same tree either way.
static func _fruit_tree(
	rng: RandomNumberGenerator, trunk: Vector2i, species: int, state: int
) -> VoxelGrid:
	var palettes: Array = OrchardColors.TREES[species]
	var w := trunk.x
	var h := trunk.y
	var scale := h / 40.0
	var sketch := Sketch.new(int(70 * scale) + w * 2, h + int(34 * scale))
	var salt := rng.randi()
	var centers := _trunk_centers(sketch, rng, w, h, rng.randf_range(0.5, 2.5), 1.2)
	var bark := _bark_paint(centers, palettes[0], 6.0, salt, 0.15)
	_paint_trunk(sketch, centers, w, 0.65, 0.5, bark)
	_roots(sketch, rng, w, rng.randi_range(3, 4), w * 1.3, w * 0.4, bark)
	var wood := _wood_paint(palettes[0], salt)
	var top := _top_of(centers)
	var limbs := rng.randi_range(3, 4)
	for i in limbs:
		var angle := TAU * (i + rng.randf_range(-0.25, 0.25)) / limbs
		var dir := Vector3(cos(angle), rng.randf_range(0.5, 0.8), sin(angle)).normalized()
		var start := top - Vector3(0, rng.randf_range(0.0, 0.2) * h, 0)
		var spec := {"spread": 0.8, "rise": 0.3, "children": Vector2i(2, 3)}
		_grow(sketch, rng, start, dir, h * rng.randf_range(0.32, 0.42), w * 0.35, 1, spec, wood)
	sketch.tips.append(top + Vector3(0, h * 0.2, 0))
	_crown(sketch, rng, Vector3(9, 6.5, 9) * scale, 0.15, salt)
	_light_leaves(sketch, palettes[1], salt)
	if state == 1:
		_dot_crown(sketch, palettes[2], OrchardColors.BLOSSOMS[species], salt, Dot.SINGLE)
	elif state == 2:
		var shape := Dot.PAIR if species == Tiles.Block.CHERRY_TREE else Dot.BALL
		_dot_crown(sketch, palettes[3], OrchardColors.FRUITS[species], salt, shape)
	return _finish(sketch, h)


## Blossoms or fruit on the crown's outer leaves (`share` of them), by
## `shape` (Dot): a voxel each, a hanging pair (cherries) or a ball two
## voxels wide hanging from the leaf, lit on top.
static func _dot_crown(sketch: Sketch, palette: Array, share: float, salt: int, shape: int) -> void:
	var grid := sketch.grid
	var colors: Array[int] = []
	for hex: String in palette:
		colors.append(VoxelGrid.voxel(Color(hex), VoxelGrid.Kind.FOLIAGE))
	var sides: Array[Vector3i] = [
		Vector3i.LEFT, Vector3i.RIGHT, Vector3i.UP, Vector3i.FORWARD, Vector3i.BACK
	]
	var spots: Array[Vector3i] = []
	for z in range(sketch.leaf_low.z, sketch.leaf_high.z + 1):
		for y in range(sketch.leaf_low.y, sketch.leaf_high.y + 1):
			for x in range(sketch.leaf_low.x, sketch.leaf_high.x + 1):
				var p := Vector3i(x, y, z)
				var value := grid.get_voxel(p)
				if value == 0 or VoxelGrid.kind_of(value) != VoxelGrid.Kind.FOLIAGE:
					continue
				if _noise(p, salt + 29) >= share:
					continue
				for side in sides:
					if grid.get_voxel(p + side) == 0:
						spots.append(p)
						break
	var paint_over := func(at: Vector3i, color: int) -> void:
		var there := grid.get_voxel(at)
		if there == 0 or VoxelGrid.kind_of(there) == VoxelGrid.Kind.FOLIAGE:
			grid.set_voxel(at, color)
	for p in spots:
		if shape == Dot.PAIR:
			paint_over.call(p, colors[2])
			paint_over.call(p + Vector3i.DOWN, colors[1])
			paint_over.call(p + Vector3i(1, -1, 0), colors[0])
		elif shape == Dot.SINGLE:
			paint_over.call(p, colors[int(_noise(p, salt + 31) * colors.size()) % colors.size()])
		else:
			for dz in 2:
				for dy in 2:
					for dx in 2:
						var shade := 2 if dy == 0 else (1 if dx + dz < 2 else 0)
						paint_over.call(p + Vector3i(dx, -dy, dz), colors[shade])


# ---------------------------------------------------------------- trunks


## The center of every slice of a trunk, bottom up: it leans one way and
## wavers a little.
static func _trunk_centers(
	sketch: Sketch, rng: RandomNumberGenerator, width: int, height: int, lean: float, waver: float
) -> Array[Vector2]:
	var centers: Array[Vector2] = []
	var lean_dir := Vector2.from_angle(rng.randf() * TAU)
	var phase := Vector2(rng.randf() * TAU, rng.randf() * TAU)
	var frequency := rng.randf_range(0.04, 0.08) * 6.0 / maxf(4.0, width)
	var foot := Vector2(sketch.base.x, sketch.base.z)
	for y in height + 1:
		var t := float(y) / maxf(1.0, height)
		var wobble := Vector2(sin(y * frequency + phase.x), cos(y * frequency * 1.3 + phase.y))
		centers.append(foot + lean_dir * lean * pow(t, 1.6) + wobble * waver * t)
	return centers


## Fills a trunk: discs tapering to `taper` of `width` at the top, flared
## at the foot by `flare`.
static func _paint_trunk(
	sketch: Sketch, centers: Array[Vector2], width: int, taper: float, flare: float, bark: Callable
) -> void:
	var height := centers.size() - 1
	for y in centers.size():
		var t := float(y) / maxf(1.0, height)
		var radius := width * 0.5 * lerpf(1.0, taper, t)
		radius += width * 0.5 * flare * exp(-y / maxf(1.0, width * 0.7))
		sketch.grid.disc(centers[y], radius, y, bark)


## The top of a trunk (a point in the middle of its last slice).
static func _top_of(centers: Array[Vector2]) -> Vector3:
	var top: Vector2 = centers[centers.size() - 1]
	return Vector3(top.x, centers.size() - 1, top.y)


## Roots creeping out from the foot, sinking into the ground as they go.
static func _roots(
	sketch: Sketch,
	rng: RandomNumberGenerator,
	width: int,
	count: int,
	reach: float,
	rise: float,
	bark: Callable
) -> void:
	var foot := Vector2(sketch.base.x, sketch.base.z)
	for i in count:
		var angle := TAU * (i + rng.randf_range(-0.3, 0.3)) / count
		var dir := Vector2.from_angle(angle)
		var side := Vector2(-dir.y, dir.x)
		var length := reach * rng.randf_range(0.7, 1.2)
		var bend := rng.randf_range(-0.25, 0.25)
		var steps := ceili(length * 2.0)
		for s in steps + 1:
			var t := float(s) / steps
			var spot := foot + dir * (width * 0.35 + t * length) + side * bend * t * t * length
			var top := rise * pow(1.0 - t, 1.6)
			var thick := lerpf(width * 0.2, 0.5, t)
			sketch.grid.cylinder(spot, thick, 0, int(top), bark)


## Tall plank roots holding up a jungle giant.
static func _buttresses(
	sketch: Sketch,
	rng: RandomNumberGenerator,
	width: int,
	count: int,
	reach: float,
	rise: float,
	bark: Callable
) -> void:
	var foot := Vector2(sketch.base.x, sketch.base.z)
	for i in count:
		var angle := TAU * (i + rng.randf_range(-0.25, 0.25)) / count
		var dir := Vector2.from_angle(angle)
		var length := reach * rng.randf_range(0.8, 1.2)
		var steps := ceili(length * 2.0)
		for s in steps + 1:
			var t := float(s) / steps
			var spot := foot + dir * (width * 0.3 + t * length)
			var top := rise * pow(1.0 - t, 1.3)
			sketch.grid.cylinder(spot, lerpf(1.6, 0.6, t), 0, int(top), bark)


# ---------------------------------------------------------------- branches


## A gently bent limb from `from` to `to`, thinning from `r0` to `r1`.
static func _limb(
	grid: VoxelGrid,
	rng: RandomNumberGenerator,
	from: Vector3,
	to: Vector3,
	r0: float,
	r1: float,
	wood: Callable
) -> void:
	var length := from.distance_to(to)
	if length < 0.5:
		return
	var across := (to - from).cross(Vector3.UP)
	if across.length_squared() < 0.001:
		across = Vector3.RIGHT
	var bend := across.normalized() * rng.randf_range(-0.12, 0.12) * length
	var middle := from.lerp(to, 0.5) + bend + Vector3.UP * length * 0.05
	var steps := maxi(2, ceili(length * 1.5))
	for i in steps + 1:
		var t := float(i) / steps
		var p := from.lerp(middle, t).lerp(middle.lerp(to, t), t)
		var radius := lerpf(r0, r1, t)
		if radius < 0.7:
			var cell := Vector3i(p.floor())
			grid.set_voxel(cell, wood.call(cell))
		else:
			grid.ellipsoid(p, Vector3.ONE * radius, wood)


## A branch and its sub-branches (`depth` more forks), towards the light.
## `spec`: spread (how far forks turn away), rise (pull upwards, negative
## droops) and children (fewest, most). Leaves grow at the tips.
static func _grow(
	sketch: Sketch,
	rng: RandomNumberGenerator,
	from: Vector3,
	dir: Vector3,
	length: float,
	radius: float,
	depth: int,
	spec: Dictionary,
	wood: Callable
) -> void:
	var to := from + dir * length
	_limb(sketch.grid, rng, from, to, radius, maxf(0.5, radius * 0.7), wood)
	if depth <= 0 or radius < 0.7:
		sketch.tips.append(to)
		return
	var children: Vector2i = spec["children"]
	for i in rng.randi_range(children.x, children.y):
		var start := from.lerp(to, rng.randf_range(0.6, 1.0))
		var turn: Vector3 = _random_direction(rng) * float(spec["spread"])
		var child := (dir + turn + Vector3.UP * float(spec["rise"])).normalized()
		var child_length := length * rng.randf_range(0.55, 0.75)
		_grow(sketch, rng, start, child, child_length, radius * 0.66, depth - 1, spec, wood)
	if rng.randf() < 0.5:
		sketch.tips.append(to)


## A spruce bough: a drooping branch with needles hanging along it.
static func _bough(
	grid: VoxelGrid,
	rng: RandomNumberGenerator,
	from: Vector3,
	angle: float,
	length: float,
	wood: Callable
) -> void:
	var out := Vector3(cos(angle), 0.0, sin(angle))
	var droop := rng.randf_range(0.15, 0.35)
	var steps := maxi(2, ceili(length * 1.5))
	for i in steps + 1:
		var t := float(i) / steps
		# Out and slightly down, sagging more towards the tip.
		var p := from + out * t * length + Vector3.DOWN * (droop * t + 0.25 * t * t) * length * 0.6
		var voxel := Vector3i(p.floor())
		if t < 0.6:
			grid.set_voxel(voxel, wood.call(voxel))
		# Needles: a flat layer hanging around the branch, thinner at the tip.
		var width := lerpf(3.4, 1.2, t) + rng.randf_range(-0.4, 0.4)
		var side := Vector3(-out.z, 0.0, out.x)
		for k in range(-ceili(width), ceili(width) + 1):
			if absf(k) > width:
				continue
			for dy in range(-2, 1):
				var spot := Vector3i((p + side * k + Vector3(0, dy, 0)).floor())
				if spot.y < _leaf_floor or grid.get_voxel(spot) != 0:
					continue
				if _noise(spot / 2, 41) > 0.1:
					grid.set_voxel(spot, _leaf)


static func _random_direction(rng: RandomNumberGenerator) -> Vector3:
	var z := rng.randf_range(-1.0, 1.0)
	var a := rng.randf() * TAU
	var r := sqrt(1.0 - z * z)
	return Vector3(r * cos(a), z, r * sin(a))


# ---------------------------------------------------------------- leaves


## Leaf clusters at every tip (radii `size`, varying), then gaps carved
## through them (`gaps`: how much) so branches show inside.
static func _crown(
	sketch: Sketch, rng: RandomNumberGenerator, size: Vector3, gaps: float, salt: int
) -> void:
	for tip in sketch.tips:
		var radii := size * rng.randf_range(0.7, 1.15)
		var center := tip + Vector3(0, radii.y * 0.25, 0)
		_cluster(sketch, center, radii, salt + int(tip.x * 31 + tip.z * 17))
	_carve(sketch, salt, gaps)


## A lumpy, flattened ball of leaves (does not cover the wood).
static func _cluster(sketch: Sketch, center: Vector3, radii: Vector3, salt: int) -> void:
	var grid := sketch.grid
	var low := Vector3i((center - radii * 1.2).floor())
	var high := Vector3i((center + radii * 1.2).ceil())
	low.y = maxi(low.y, _leaf_floor)
	sketch.add_leaf_box(low, high)
	for z in range(low.z, high.z + 1):
		for y in range(low.y, high.y + 1):
			for x in range(low.x, high.x + 1):
				var p := Vector3i(x, y, z)
				var d := (Vector3(p) + Vector3.ONE * 0.5 - center) / radii
				var bumps := (_smooth_noise(Vector3(p) / 6.0, salt) - 0.5) * 0.6
				if d.length_squared() <= 1.0 + bumps and grid.get_voxel(p) == 0:
					grid.set_voxel(p, _leaf)


## A flat, layered acacia crown: wide discs with ragged edges.
static func _umbrella(
	sketch: Sketch, rng: RandomNumberGenerator, center: Vector3, radius: float
) -> void:
	var salt := rng.randi()
	var reach := Vector3i(ceili(radius) + 3, 0, ceili(radius) + 3)
	sketch.add_leaf_box(Vector3i(center) - reach, Vector3i(center) + reach + Vector3i(0, 6, 0))
	for layer in 3:
		var r := radius * (1.0 - layer * 0.22)
		var y := int(center.y) + layer * 2
		for z in range(int(center.z - r) - 2, int(center.z + r) + 3):
			for x in range(int(center.x - r) - 2, int(center.x + r) + 3):
				var d := Vector2(x + 0.5 - center.x, z + 0.5 - center.z).length()
				var edge := r * (0.85 + _smooth_noise(Vector3(x, y, z) / 4.0, salt) * 0.3)
				if d > edge:
					continue
				var thick := 2 if d < edge - 3.0 else 1
				for dy in thick:
					var p := Vector3i(x, y + dy, z)
					if p.y >= _leaf_floor and sketch.grid.get_voxel(p) == 0:
						sketch.grid.set_voxel(p, _leaf)


## Removes leaves where a smooth noise is high: round gaps through the
## crown. Then smooths what is left.
static func _carve(sketch: Sketch, salt: int, amount: float) -> void:
	var grid := sketch.grid
	var threshold := 1.0 - amount
	for z in range(sketch.leaf_low.z, sketch.leaf_high.z + 1):
		for y in range(sketch.leaf_low.y, sketch.leaf_high.y + 1):
			for x in range(sketch.leaf_low.x, sketch.leaf_high.x + 1):
				var index := x + grid.size.x * (y + grid.size.y * z)
				if grid.voxels[index] != _leaf:
					continue
				if _smooth_noise(Vector3(x, y, z) / 6.0, salt + 7) > threshold:
					grid.voxels[index] = 0
	_smooth_leaves(sketch)


## Rounds off the crown's surface: lone leaves and thin spikes go, small
## dents fill up (a voxel surface with fewer steps is also a lighter mesh).
static func _smooth_leaves(sketch: Sketch) -> void:
	var grid := sketch.grid
	var stride_y := grid.size.x
	var stride_z := grid.size.x * grid.size.y
	var offsets: Array[int] = [1, -1, stride_y, -stride_y, stride_z, -stride_z]
	var changes: Dictionary[int, int] = {}
	for z in range(maxi(1, sketch.leaf_low.z), mini(grid.size.z - 1, sketch.leaf_high.z + 1)):
		for y in range(maxi(1, sketch.leaf_low.y), mini(grid.size.y - 1, sketch.leaf_high.y + 1)):
			for x in range(
				maxi(1, sketch.leaf_low.x), mini(grid.size.x - 1, sketch.leaf_high.x + 1)
			):
				var index := x + stride_y * y + stride_z * z
				var value := grid.voxels[index]
				if value != 0 and value != _leaf:
					continue
				var leaves := 0
				for offset in offsets:
					if grid.voxels[index + offset] == _leaf:
						leaves += 1
				if value == _leaf and leaves <= 1:
					changes[index] = 0
				elif value == 0 and leaves >= 4 and y >= _leaf_floor:
					changes[index] = _leaf
	for index in changes:
		grid.voxels[index] = changes[index]


## Paints the leaves with light: brighter where open to the sky and high in
## the crown, darker underneath and inside, in small leafy patches (patches
## of one color also keep the mesh light).
static func _light_leaves(sketch: Sketch, palette: Array, salt: int) -> void:
	var grid := sketch.grid
	var colors: Array[int] = []
	for hex: String in palette:
		colors.append(VoxelGrid.voxel(Color(hex), VoxelGrid.Kind.FOLIAGE))
	var box_low := sketch.leaf_low
	var box_high := sketch.leaf_high
	var low := box_high.y
	var high := box_low.y
	for z in range(box_low.z, box_high.z + 1):
		for y in range(box_low.y, box_high.y + 1):
			for x in range(box_low.x, box_high.x + 1):
				if grid.voxels[x + grid.size.x * (y + grid.size.y * z)] == _leaf:
					low = mini(low, y)
					high = maxi(high, y)
	var span := maxf(1.0, high - low)
	var sides: Array[Vector3i] = [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]
	var last := colors.size() - 1
	for z in range(box_low.z, box_high.z + 1):
		for y in range(box_low.y, box_high.y + 1):
			for x in range(box_low.x, box_high.x + 1):
				var index := x + grid.size.x * (y + grid.size.y * z)
				if grid.voxels[index] != _leaf:
					continue
				var p := Vector3i(x, y, z)
				var sky := 0
				for k in range(1, 7):
					if grid.get_voxel(p + Vector3i(0, k, 0)) != 0:
						break
					sky += 1
				var open := 0
				for side in sides:
					if grid.get_voxel(p + side) == 0 or grid.get_voxel(p + side * 2) == 0:
						open += 1
				var light := (
					0.42 * (y - low) / span + 0.38 * (sky / 3) / 2.0 + 0.2 * (open / 2) / 2.0
				)
				light += (_noise(p / 3, salt) - 0.5) * 0.34
				var shade := clampi(int(light * (last + 0.6)), 0, last)
				# The lightest leaves only catch the sun on top.
				if shade == last and sky < 6:
					shade = last - 1
				grid.voxels[index] = colors[shade]


## Long strands hanging under the crown (vines, moss).
static func _hang(
	sketch: Sketch, rng: RandomNumberGenerator, palette: Array, chance: float, longest: int
) -> void:
	var grid := sketch.grid
	var colors: Array[int] = []
	for hex: String in palette:
		colors.append(VoxelGrid.voxel(Color(hex), VoxelGrid.Kind.FOLIAGE))
	for z in range(sketch.leaf_low.z, sketch.leaf_high.z + 1):
		for x in range(sketch.leaf_low.x, sketch.leaf_high.x + 1):
			for y in range(1, sketch.leaf_high.y + 1):
				var value := grid.get_voxel(Vector3i(x, y, z))
				if value == 0:
					continue
				if VoxelGrid.kind_of(value) == VoxelGrid.Kind.FOLIAGE and rng.randf() < chance:
					# One color per strand: its sides are single long faces.
					var color := colors[rng.randi_range(0, colors.size() - 1)]
					var length := rng.randi_range(longest / 4, longest)
					for k in range(1, length):
						var p := Vector3i(x, y - k, z)
						if y - k < _strand_floor or grid.get_voxel(p) != 0:
							break
						grid.set_voxel(p, color)
				break


## Vines climbing the trunk.
static func _climbing_vines(
	sketch: Sketch, rng: RandomNumberGenerator, centers: Array[Vector2], width: int
) -> void:
	var colors: Array[int] = []
	for hex: String in VINES:
		colors.append(VoxelGrid.voxel(Color(hex), VoxelGrid.Kind.FOLIAGE))
	for strand in rng.randi_range(2, 4):
		var angle := rng.randf() * TAU
		for y in range(2, centers.size() - 4):
			angle += rng.randf_range(-0.12, 0.12)
			var c: Vector2 = centers[y]
			var r := width * 0.5 + 0.6
			var p := Vector3i(floori(c.x + cos(angle) * r), y, floori(c.y + sin(angle) * r))
			if sketch.grid.get_voxel(p) == 0:
				sketch.grid.set_voxel(p, colors[(y / 4 + strand) % colors.size()])


## Snow on the leaves open to the sky, in small patches, sometimes two
## voxels deep.
static func _snow(grid: VoxelGrid) -> void:
	var colors: Array[int] = []
	for hex: String in SNOW:
		colors.append(VoxelGrid.voxel(Color(hex), VoxelGrid.Kind.FOLIAGE))
	for z in grid.size.z:
		for x in grid.size.x:
			for y in range(grid.size.y - 1, -1, -1):
				var p := Vector3i(x, y, z)
				var value := grid.get_voxel(p)
				if value == 0:
					continue
				if VoxelGrid.kind_of(value) == VoxelGrid.Kind.FOLIAGE:
					var patch := p / 2
					grid.set_voxel(p, colors[1 if _noise(patch, 0x5A0) < 0.6 else 2])
					var below := p + Vector3i.DOWN
					if grid.get_voxel(below) != 0 and _noise(patch, 0x5A1) < 0.45:
						grid.set_voxel(below, colors[0])
				break


## A few small mushrooms between the roots.
static func _mushrooms_at_foot(sketch: Sketch, rng: RandomNumberGenerator, width: int) -> void:
	var cap := VoxelGrid.voxel(Color("#8a5a3a"))
	var light := VoxelGrid.voxel(Color("#a8744a"))
	var stem := VoxelGrid.voxel(Color("#efe6d4"))
	for i in rng.randi_range(2, 4):
		var angle := rng.randf() * TAU
		var d := width * 0.5 + rng.randf_range(2.0, 6.0)
		var x := floori(sketch.base.x + cos(angle) * d)
		var z := floori(sketch.base.z + sin(angle) * d)
		var y := 0
		while sketch.grid.get_voxel(Vector3i(x, y, z)) != 0 and y < 6:
			y += 1
		sketch.grid.set_voxel(Vector3i(x, y, z), stem)
		for p: Vector3i in [
			Vector3i(0, 1, 0),
			Vector3i(1, 1, 0),
			Vector3i(-1, 1, 0),
			Vector3i(0, 1, 1),
			Vector3i(0, 1, -1)
		]:
			if sketch.grid.get_voxel(Vector3i(x, y, z) + p) == 0:
				sketch.grid.set_voxel(
					Vector3i(x, y, z) + p, light if p == Vector3i(0, 1, 0) else cap
				)


# ---------------------------------------------------------------- bark


## Bark with vertical grooves around the trunk, knots, and moss low on the
## north side (`moss`: how much).
static func _bark_paint(
	centers: Array[Vector2], palette: Array, grooves: float, salt: int, moss: float
) -> Callable:
	var colors: Array[int] = []
	for hex: String in palette:
		colors.append(VoxelGrid.voxel(Color(hex)))
	var mosses: Array[int] = []
	for hex: String in MOSS:
		mosses.append(VoxelGrid.voxel(Color(hex)))
	var top := centers.size() - 1
	return func(p: Vector3i) -> int:
		var c: Vector2 = centers[clampi(p.y, 0, top)]
		var d := Vector2(p.x + 0.5, p.z + 0.5) - c
		var n := _noise(Vector3i(p.x / 2, p.y / 5, p.z / 2), salt)
		var groove := sin(d.angle() * grooves + n * 2.4 + p.y * 0.035)
		var index := 2
		if groove > 0.6:
			index = 0
		elif groove > 0.15:
			index = 1
		elif groove < -0.75:
			index = 3
		if _noise(Vector3i(p.x / 3, p.y / 6, p.z / 3), salt + 9) > 0.94:
			index = 0
		var low := 1.0 - p.y / 22.0
		if moss > 0.0 and d.y < -0.5 and low > 0.0 and _noise(p / 2, salt + 5) < moss * low:
			return mosses[1 if _noise(p / 3, salt + 6) < 0.5 else 0]
		return colors[index]


## White birch bark: horizontal black marks, darker and rougher at the foot.
static func _birch_paint(centers: Array[Vector2], salt: int) -> Callable:
	var colors: Array[int] = []
	for hex: String in BIRCH_BARK:
		colors.append(VoxelGrid.voxel(Color(hex)))
	var black := VoxelGrid.voxel(Color("#2a2622"))
	var dark := VoxelGrid.voxel(Color("#5a544c"))
	var top := centers.size() - 1
	return func(p: Vector3i) -> int:
		var c: Vector2 = centers[clampi(p.y, 0, top)]
		var d := Vector2(p.x + 0.5, p.z + 0.5) - c
		var sector := int(floor((d.angle() + PI) * 3.0))
		# Short horizontal dashes (lenticels).
		if _noise(Vector3i(sector, p.y / 2, 0), salt) > 0.82 and p.y % 2 == 0:
			return black
		if p.y < 8 and _noise(p, salt + 1) < 0.5 - p.y / 16.0:
			return dark if _noise(p, salt + 2) < 0.5 else black
		var shade := clampi(int(_noise(Vector3i(p.x / 2, p.y / 3, p.z / 2), salt + 3) * 4.0), 0, 3)
		return colors[shade]


## Branch wood: the bark's colors in small patches.
static func _wood_paint(palette: Array, salt: int) -> Callable:
	var colors: Array[int] = []
	for hex: String in palette:
		colors.append(VoxelGrid.voxel(Color(hex)))
	return func(p: Vector3i) -> int:
		return colors[clampi(int(_noise(p / 2, salt + 11) * 2.0) + 1, 0, colors.size() - 1)]


# ---------------------------------------------------------------- finishing


## Crops the tree to its voxels, with wind above the lower trunk (and no
## corner shading on the leaves, see VoxelGrid.foliage_ao).
static func _finish(sketch: Sketch, trunk_height: int) -> VoxelGrid:
	sketch.grid.sway = 0.6
	sketch.grid.sway_from = int(trunk_height * 0.55)
	sketch.grid.foliage_ao = false
	return sketch.grid.cropped()


## Random-looking but fixed value in 0..1 for a voxel.
static func _noise(p: Vector3i, salt: int) -> float:
	return HashUtil.unit2(salt + p.z * 7919, p.x, p.y)


## Smooth value noise in 0..1 (trilinear between hashed lattice points).
static func _smooth_noise(p: Vector3, salt: int) -> float:
	var i := Vector3i(p.floor())
	var f := p - Vector3(i)
	f = f * f * (Vector3.ONE * 3.0 - f * 2.0)
	var c000 := _noise(i, salt)
	var c100 := _noise(i + Vector3i(1, 0, 0), salt)
	var c010 := _noise(i + Vector3i(0, 1, 0), salt)
	var c110 := _noise(i + Vector3i(1, 1, 0), salt)
	var c001 := _noise(i + Vector3i(0, 0, 1), salt)
	var c101 := _noise(i + Vector3i(1, 0, 1), salt)
	var c011 := _noise(i + Vector3i(0, 1, 1), salt)
	var c111 := _noise(i + Vector3i(1, 1, 1), salt)
	var x00 := lerpf(c000, c100, f.x)
	var x10 := lerpf(c010, c110, f.x)
	var x01 := lerpf(c001, c101, f.x)
	var x11 := lerpf(c011, c111, f.x)
	return lerpf(lerpf(x00, x10, f.y), lerpf(x01, x11, f.y), f.z)
