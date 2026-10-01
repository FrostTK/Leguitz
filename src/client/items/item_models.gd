class_name ItemModels
extends RefCounted
## Voxel models of the items that are not blocks (block items are cubes
## with the block's texture, see ItemLibrary): logs, lumps of ore, gems,
## plants... A dozen voxels across, one voxel being one art pixel.

const LOGS := {
	Items.Id.OAK_LOG: [TreeModels.OAK_BARK, ["#b98a55", "#d6a96c", "#8d6338"]],
	Items.Id.BIRCH_LOG: [TreeModels.BIRCH_BARK, ["#e3cf9a", "#f2e2b4", "#bfa16a"]],
	Items.Id.SPRUCE_LOG: [TreeModels.SPRUCE_BARK, ["#a8784a", "#c2925e", "#7d5531"]],
	Items.Id.DARK_OAK_LOG: [TreeModels.DARK_BARK, ["#7a5634", "#93693f", "#58391f"]],
	Items.Id.JUNGLE_LOG: [TreeModels.JUNGLE_BARK, ["#c08a5a", "#d9a46f", "#94643c"]],
	Items.Id.ACACIA_LOG: [TreeModels.ACACIA_BARK, ["#c86a3a", "#e0864e", "#9a4b25"]],
}
const LUMPS := {
	Items.Id.COAL: ["#1c1b1f", "#2e2d33", "#4a4852"],
	Items.Id.RAW_COPPER: ["#8a4a2a", "#c06d3c", "#e39a5f"],
	Items.Id.RAW_IRON: ["#7f6a58", "#b39880", "#d8c2aa"],
	Items.Id.RAW_GOLD: ["#a3721c", "#e0ad2e", "#ffe27a"],
}
const GEMS := {
	Items.Id.RUBY: ["#7d0f1f", "#c4223a", "#ff6b7d"],
	Items.Id.DIAMOND: ["#1f8a8f", "#4fd6d6", "#c8ffff"],
	Items.Id.EMERALD: ["#0f6b34", "#21b357", "#8af0ab"],
	Items.Id.LAPIS: ["#13286e", "#2649b8", "#6d8cf0"],
}
const FLOWERS := {
	Items.Id.FLOWER_RED: ["#b8202c", "#e23a44", "#f7d74a"],
	Items.Id.FLOWER_YELLOW: ["#d9a21c", "#f2c53d", "#8a5a20"],
	Items.Id.FLOWER_BLUE: ["#3550b8", "#4a6ee0", "#f7d74a"],
	Items.Id.FLOWER_WHITE: ["#d8d8d8", "#ffffff", "#f7d74a"],
	Items.Id.FLOWER_PINK: ["#d0587e", "#f07aa0", "#fff1a8"],
}
const STEM := "#3f7f2a"
const LEAF := "#5fa83d"


## The model of an item (null for block items).
static func build(item: int) -> VoxelGrid:
	if LOGS.has(item):
		return _log(LOGS[item][0], LOGS[item][1])
	if LUMPS.has(item):
		return _lump(LUMPS[item], item)
	if GEMS.has(item):
		return _flakes(GEMS[item]) if item == Items.Id.LAPIS else _gem(GEMS[item])
	if FLOWERS.has(item):
		return _flower(FLOWERS[item])
	match item:
		Items.Id.STICK:
			return _stick()
		Items.Id.SEEDS:
			return _seeds()
		Items.Id.BERRIES:
			return _berries()
		Items.Id.MUSHROOM_RED:
			return _mushroom(["#a8141e", "#d8303a"], true)
		Items.Id.MUSHROOM_BROWN:
			return _mushroom(["#7a5233", "#9c6d46"], false)
		Items.Id.CACTUS:
			return _cactus()
		Items.Id.SUGAR_CANE:
			return _sugar_cane()
		Items.Id.LILY_PAD:
			return _lily_pad()
		Items.Id.FERN:
			return _fern()
	return null


static func _v(hex: String, kind := VoxelGrid.Kind.SOLID) -> int:
	return VoxelGrid.voxel(Color(hex), kind)


## A short log lying down: bark around, rings at both ends.
static func _log(bark: Array, rings: Array) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(12, 9, 9))
	var middle := Vector2(4.5, 4.5)
	for x in 12:
		for y in 9:
			for z in 9:
				var d := Vector2(y + 0.5, z + 0.5).distance_to(middle)
				if d > 4.4:
					continue
				var p := Vector3i(x, y, z)
				if x == 0 or x == 11:
					var ring := int(d * 1.3) % 2
					grid.set_voxel(p, _v(rings[2] if d > 3.6 else rings[ring]))
				else:
					var shade := clampi(int(HashUtil.unit2(31, x / 2, y * 9 + z) * 3.0), 0, 2)
					grid.set_voxel(p, _v(bark[shade + 1] if d > 3.4 else rings[0]))
	return grid


static func _lump(colors: Array, salt: int) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(9, 7, 9))
	for x in 9:
		for y in 7:
			for z in 9:
				var d := (Vector3(x, y * 1.25, z) - Vector3(4, 3.5, 4)).length()
				var bump := HashUtil.unit2(salt, x * 7 + z, y) * 1.2
				if d < 3.6 + bump:
					var light := 2 if y >= 5 else (1 if (x + z + y) % 3 != 0 else 0)
					grid.set_voxel(Vector3i(x, y, z), _v(colors[light]))
	return grid


static func _gem(colors: Array) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(9, 11, 9))
	for y in 11:
		var r := 4.4 - absf(y - 6.5) * (0.9 if y > 6 else 0.7)
		for x in 9:
			for z in 9:
				var d := absf(x - 4.0) + absf(z - 4.0)
				if d <= r:
					var face := 2 if (y > 7 and x <= 4) else (0 if x + z > 9 else 1)
					grid.set_voxel(Vector3i(x, y, z), _v(colors[face]))
	return grid


static func _flakes(colors: Array) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(10, 4, 10))
	for i in 6:
		var center := Vector3(2.5 + (i % 3) * 2.5, 0.5 + (i / 3), 2.5 + (i * 7 % 5) * 1.3)
		grid.ellipsoid(center, Vector3(1.8, 0.8, 1.4), _v(colors[i % 3]))
	return grid


static func _flower(colors: Array) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(7, 13, 7))
	grid.box(Vector3i(3, 0, 3), Vector3i(3, 8, 3), _v(STEM, VoxelGrid.Kind.FOLIAGE))
	grid.box(Vector3i(4, 4, 3), Vector3i(5, 4, 3), _v(LEAF, VoxelGrid.Kind.FOLIAGE))
	for p: Vector3i in [
		Vector3i(2, 10, 3), Vector3i(4, 10, 3), Vector3i(3, 10, 2), Vector3i(3, 10, 4)
	]:
		grid.set_voxel(p, _v(colors[1], VoxelGrid.Kind.FOLIAGE))
	for p: Vector3i in [
		Vector3i(2, 11, 2), Vector3i(4, 11, 4), Vector3i(4, 9, 2), Vector3i(2, 9, 4)
	]:
		grid.set_voxel(p, _v(colors[0], VoxelGrid.Kind.FOLIAGE))
	grid.set_voxel(Vector3i(3, 10, 3), _v(colors[2], VoxelGrid.Kind.FOLIAGE))
	grid.set_voxel(Vector3i(3, 9, 3), _v(STEM, VoxelGrid.Kind.FOLIAGE))
	return grid


static func _stick() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(12, 12, 3))
	for i in 11:
		var p := Vector3i(i, i, 1)
		grid.set_voxel(p, _v("#7a5230" if i % 3 else "#5c3b1f"))
		grid.set_voxel(p + Vector3i(1, 0, 0), _v("#94683d"))
	return grid


static func _seeds() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(10, 3, 10))
	var spots: Array[Vector3i] = [
		Vector3i(2, 0, 3),
		Vector3i(5, 0, 2),
		Vector3i(7, 0, 5),
		Vector3i(3, 0, 6),
		Vector3i(6, 0, 8)
	]
	for spot in spots:
		grid.set_voxel(spot, _v("#c7b26a"))
		grid.set_voxel(spot + Vector3i(1, 0, 0), _v("#9c8a4a"))
		grid.set_voxel(spot + Vector3i(0, 1, 0), _v("#7aa04a"))
	return grid


static func _berries() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(9, 9, 9))
	for center: Vector3 in [
		Vector3(3, 2, 3), Vector3(6, 2, 4), Vector3(4, 2, 6), Vector3(4.5, 4.5, 4.5)
	]:
		grid.ellipsoid(center, Vector3.ONE * 1.7, _v("#c4283a"))
		grid.set_voxel(Vector3i(center) + Vector3i(0, 1, 0), _v("#e2484f"))
	grid.box(Vector3i(4, 6, 4), Vector3i(4, 7, 4), _v(STEM, VoxelGrid.Kind.FOLIAGE))
	grid.box(Vector3i(5, 7, 4), Vector3i(6, 7, 4), _v(LEAF, VoxelGrid.Kind.FOLIAGE))
	return grid


static func _mushroom(cap: Array, dots: bool) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(9, 9, 9))
	grid.box(Vector3i(3, 0, 3), Vector3i(5, 4, 5), _v("#efe6d4"))
	for y in range(4, 8):
		var r := 4.2 - (y - 4) * 0.9
		grid.disc(Vector2(4.5, 4.5), r, y, _v(cap[1] if y > 5 else cap[0]))
	if dots:
		for p: Vector3i in [
			Vector3i(2, 5, 3), Vector3i(6, 5, 5), Vector3i(4, 7, 4), Vector3i(4, 6, 1)
		]:
			grid.set_voxel(p, _v("#f4f0e6"))
	return grid


static func _cactus() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(9, 12, 6))
	var green := _v("#3f8f3a")
	grid.box(Vector3i(2, 0, 1), Vector3i(5, 11, 4), green)
	grid.box(Vector3i(6, 4, 2), Vector3i(7, 5, 3), green)
	grid.box(Vector3i(7, 5, 2), Vector3i(8, 8, 3), green)
	for y in range(1, 12, 3):
		grid.set_voxel(Vector3i(2, y, 1), _v("#d8e7a8"))
		grid.set_voxel(Vector3i(5, y + 1, 4), _v("#d8e7a8"))
	return grid


static func _sugar_cane() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(8, 13, 6))
	for stalk in 3:
		var x := 1 + stalk * 3
		var top := 10 + stalk % 2 * 2
		for y in top:
			var node := y % 4 == 3
			grid.set_voxel(
				Vector3i(x, y, 2 + stalk % 2),
				_v("#5a9a3f" if node else "#7fc45a", VoxelGrid.Kind.FOLIAGE)
			)
		grid.set_voxel(
			Vector3i(x + 1, top - 2, 2 + stalk % 2), _v("#94d468", VoxelGrid.Kind.FOLIAGE)
		)
	return grid


static func _lily_pad() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(11, 2, 11))
	grid.disc(Vector2(5.5, 5.5), 5.2, 0, _v("#3d8a37", VoxelGrid.Kind.FOLIAGE))
	grid.disc(Vector2(5.5, 5.5), 3.0, 0, _v("#4fa346", VoxelGrid.Kind.FOLIAGE))
	for i in 5:
		grid.set_voxel(Vector3i(5 + i, 0, 5), 0)
	return grid


static func _fern() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(11, 10, 11))
	var greens := [_v("#2f6a2e", VoxelGrid.Kind.FOLIAGE), _v("#4a8a3c", VoxelGrid.Kind.FOLIAGE)]
	for frond in 5:
		var angle := TAU * frond / 5.0
		var out := Vector3(cos(angle), 0.0, sin(angle))
		for step in 6:
			var p := (
				Vector3(5, 0, 5) + out * step * 0.9 + Vector3.UP * (step * 1.6 - step * step * 0.18)
			)
			grid.set_voxel(Vector3i(p.floor()), greens[step % 2])
	return grid
