class_name ItemModels
extends RefCounted
## Voxel models of the items that are not blocks (block items are cubes
## with the block's texture, see ItemLibrary): logs, lumps of ore, gems,
## plants, tools... A dozen voxels across, one voxel being one art pixel.

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
## Tools: the head's colors by material (Items.Tier: dark, mid, light,
## shine); the handle is a stick.
const TOOL_HEADS := {
	Items.Tier.WOOD: ["#6e4b25", "#a07a46", "#c49b5f", "#ddb97c"],
	Items.Tier.STONE: ["#4a4a50", "#76767c", "#9b9ba1", "#bdbdc2"],
	Items.Tier.COPPER: ["#7a3a1c", "#b9612d", "#e2894a", "#f9b67e"],
	Items.Tier.IRON: ["#66666c", "#aeaeb4", "#d6d6da", "#fbfbfb"],
	Items.Tier.GOLD: ["#94640f", "#dda72a", "#f6cd47", "#fff2a0"],
	Items.Tier.DIAMOND: ["#11757b", "#35c2c6", "#86eeee", "#e2ffff"],
}
const HANDLE := ["#5c3b1f", "#7a5230", "#94683d"]
const SQRT_HALF := 0.70710678
## Across the handle, from the middle of its 2-voxel staircase.
const HANDLE_MIDDLE := 0.3535534
## A brick (fired mud, see Smelting): shaped like an ingot.
const BRICK := ["#6e2f20", "#9a4a34", "#b8644a", "#d4886a"]
## Ingots: the colors of their metal (the tools' heads).
const INGOTS := {
	Items.Id.COPPER_INGOT: Items.Tier.COPPER,
	Items.Id.IRON_INGOT: Items.Tier.IRON,
	Items.Id.GOLD_INGOT: Items.Tier.GOLD,
}
## Meat (dark, base, light), raw and roasted, by item; bones and fat.
const MEATS := {
	Items.Id.RAW_MUTTON: ["#9e3b40", "#c9545a", "#e07a7a"],
	Items.Id.COOKED_MUTTON: ["#6e3a1c", "#9a5a2c", "#c08048"],
	Items.Id.RAW_PORK: ["#c97275", "#e8999a", "#f6c2bf"],
	Items.Id.COOKED_PORK: ["#7a4320", "#a8622f", "#cf8f55"],
	Items.Id.RAW_CHICKEN: ["#d49880", "#ecbba4", "#f8d9c8"],
	Items.Id.COOKED_CHICKEN: ["#8a4e22", "#b8742f", "#dca159"],
	Items.Id.RAW_VENISON: ["#6b1d22", "#8f2a2e", "#b4474b"],
	Items.Id.COOKED_VENISON: ["#4a2a16", "#6e4022", "#94603a"],
}
const BONE := ["#cfc4aa", "#f2ead8"]
const FAT := "#f4e8dc"
## Tools lie on the diagonal of a TOOL_SIZE grid, like the icons of block
## games: the handle from the bottom left, the head at the top right. The
## hand holds the handle at TOOL_GRIP (grid units), its axis TOOL_AXIS;
## the axe's blade is on the TOOL_SIDE of it.
const TOOL_SIZE := Vector3i(16, 16, 3)
const TOOL_GRIP := Vector3(3.1, 2.6, 1.5)
const TOOL_AXIS := Vector3(SQRT_HALF, SQRT_HALF, 0.0)
const TOOL_SIDE := Vector3(-SQRT_HALF, SQRT_HALF, 0.0)


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
	if Items.TOOLS.has(item):
		return _tool(Items.tool_of(item), TOOL_HEADS[Items.tier_of(item)])
	if INGOTS.has(item):
		return _ingot(TOOL_HEADS[INGOTS[item]])
	if MEATS.has(item):
		return _meat(item)
	if Armor.is_armor(item):
		return ArmorModels.icon(item)
	var decor := DecorModels.item(item)
	if decor != null:
		return decor
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
		Items.Id.GUIDE_BOOK:
			return _book()
		Items.Id.WORKBENCH:
			return WorkbenchModel.build()
		Items.Id.CHEST:
			return ChestModel.build()
		Items.Id.FOOD_FURNACE:
			return FurnaceModels.food(false)
		Items.Id.FACTORY_FURNACE:
			return FurnaceModels.factory(false)
		Items.Id.DRIED_BERRIES:
			return _dried_berries()
		Items.Id.MUSHROOM_STEW:
			return _stew()
		Items.Id.CHARCOAL:
			return _charcoal()
		Items.Id.CHARRED_FOOD:
			return _charred()
		Items.Id.BRICK:
			return _ingot(BRICK)
		Items.Id.FEATHER:
			return _feather()
		Items.Id.HIDE:
			return _hide()
		Items.Id.MOTH_DUST:
			return _moth_dust()
		Items.Id.SHADE_ESSENCE:
			return _shade_essence()
		Items.Id.WISP_EMBER:
			return _wisp_ember()
		Items.Id.BOW:
			return _bow()
		Items.Id.ARROW:
			return _arrow()
		Items.Id.STRING:
			return _string()
	return null


## Thin flat items (tools, sticks, armor): their icon faces the camera.
static func is_flat(item: int) -> bool:
	return (
		Items.TOOLS.has(item)
		or Armor.is_armor(item)
		or item in [Items.Id.STICK, Items.Id.FEATHER, Items.Id.BOW, Items.Id.ARROW]
	)


static func _v(hex: String, kind := VoxelGrid.Kind.SOLID) -> int:
	return VoxelGrid.voxel(Color(hex), kind)


## An ingot: a bar narrowing to its top, shining along its upper edge.
static func _ingot(colors: Array) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(12, 3, 7))
	grid.box(Vector3i(0, 0, 0), Vector3i(11, 0, 6), _v(colors[0]))
	grid.box(Vector3i(1, 0, 1), Vector3i(10, 1, 5), _v(colors[1]))
	grid.box(Vector3i(2, 2, 1), Vector3i(9, 2, 5), _v(colors[2]))
	grid.box(Vector3i(2, 2, 1), Vector3i(9, 2, 1), _v(colors[3]))
	grid.box(Vector3i(1, 1, 1), Vector3i(10, 1, 1), _v(colors[2]))
	return grid


## A tool on the diagonal: the handle, a stick from the bottom left, and
## the head at the top right, three voxels deep where it holds the handle,
## one at its points and edges.
static func _tool(kind: int, head: Array) -> VoxelGrid:
	var grid := VoxelGrid.new(TOOL_SIZE)
	var handle_end: float = (
		{Items.Tool.PICKAXE: 15.0, Items.Tool.AXE: 15.3, Items.Tool.SWORD: 5.4}.get(kind, 12.0)
	)
	for x in TOOL_SIZE.x:
		for y in TOOL_SIZE.y:
			# Along the handle (u) and across it (v, > 0 on the upper left).
			var u := (x + y + 1.0) * SQRT_HALF
			var v := (y - x) * SQRT_HALF + HANDLE_MIDDLE
			var shade := _tool_head(kind, u, v)
			if shade.x >= 0:
				for z in range(1 - shade.y, 2 + shade.y):
					grid.set_voxel(Vector3i(x, y, z), _v(head[shade.x]))
			elif u > 1.4 and u < handle_end and absf(v) < 0.4:
				var dark := int(u * SQRT_HALF) % 3 == 0
				var color: String = HANDLE[2] if v < 0.0 else HANDLE[0 if dark else 1]
				grid.set_voxel(Vector3i(x, y, 1), _v(color))
	return grid


## The head of a tool at (u, v) (see _tool): [its color (index in the
## head's colors, -1: not the head), 1 if three voxels deep else 0].
static func _tool_head(kind: int, u: float, v: float) -> Vector2i:
	match kind:
		Items.Tool.PICKAXE:
			# A curved bar across the top of the handle, pointed at both ends.
			var reach := absf(v) / 7.6
			var half := 1.75 - 1.15 * reach * reach
			var d := Vector2(u - 6.4, v).length() - 9.8
			if reach > 1.0 or absf(d) > half:
				return Vector2i(-1, 0)
			var shade := 1
			if d > half * 0.35:
				shade = 2
			elif d < -half * 0.4:
				shade = 0
			if reach > 0.82 or (d > half * 0.6 and reach < 0.35):
				shade = 3
			return Vector2i(shade, 1 if absf(v) < 2.2 else 0)
		Items.Tool.AXE:
			# A blade on the upper left of the handle's top, flaring towards
			# its edge, and a short poll on the other side.
			if v >= 0.0 and v <= 6.3:
				var flare := maxf(v - 1.8, 0.0) * 0.5
				if u < 9.8 - flare or u > 14.0 + flare:
					return Vector2i(-1, 0)
				var shade := 1
				if v > 5.7:
					shade = 3
				elif v > 5.0:
					shade = 2
				elif v < 1.0:
					shade = 0
				return Vector2i(shade, 1 if v < 2.6 else 0)
			if v < 0.0 and v > -2.0 and u > 11.0 and u < 13.4:
				return Vector2i(0 if v > -1.0 else 1, 1)
		Items.Tool.SWORD:
			# A crossguard over the grip, then a blade tapering to its point,
			# a ridge down its middle and bright edges.
			if u >= 5.0 and u < 6.5 and absf(v) <= 2.4:
				return Vector2i(0, 1)
			if u < 6.5 or u > 21.2:
				return Vector2i(-1, 0)
			var tip := maxf(u - 18.4, 0.0) / 2.8
			var half := 1.3 * (1.0 - tip)
			if absf(v) > half + 0.1:
				return Vector2i(-1, 0)
			var shade := 1
			if absf(v) > half - 0.45:
				shade = 3
			elif absf(v) < 0.3:
				shade = 2
			return Vector2i(shade, 1 if u < 8.0 else 0)
		Items.Tool.SHOVEL:
			# A spade rounded at its tip, behind a collar on the handle.
			if u >= 11.4 and u < 12.8 and absf(v) <= 1.25:
				return Vector2i(0, 1)
			if u < 12.8 or u > 20.6:
				return Vector2i(-1, 0)
			var tip := maxf(u - 17.8, 0.0) / 2.8
			var half := 2.85 * sqrt(maxf(1.0 - tip * tip, 0.0))
			if absf(v) > half:
				return Vector2i(-1, 0)
			var shade := 1
			if u > 20.1:
				shade = 3
			elif absf(v) > half - 0.75 or u > 19.6:
				shade = 2
			elif absf(v) < 0.4 and u < 16.5:
				shade = 0
			return Vector2i(shade, 0)
	return Vector2i(-1, 0)


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


## Berries dried in the food furnace: smaller, dark and wrinkled, on a
## dry stem.
static func _dried_berries() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(9, 7, 9))
	var spots: Array[Vector3] = [
		Vector3(2.5, 1.2, 3.0),
		Vector3(5.8, 1.2, 3.4),
		Vector3(3.6, 1.2, 6.0),
		Vector3(6.2, 1.2, 6.4),
		Vector3(4.4, 3.0, 4.6),
	]
	for i in spots.size():
		grid.ellipsoid(spots[i], Vector3(1.4, 1.1, 1.4), _v("#5a1622" if i % 2 else "#6e1d2a"))
		grid.set_voxel(Vector3i(spots[i]) + Vector3i(0, 1, 0), _v("#8f3442"))
		grid.set_voxel(Vector3i(spots[i]) + Vector3i(1, 0, 0), _v("#3e0f18"))
	grid.box(Vector3i(4, 4, 4), Vector3i(4, 5, 4), _v("#7a5a30"))
	grid.set_voxel(Vector3i(5, 5, 4), _v("#94703c"))
	return grid


## A wooden bowl of mushroom stew, bits of mushroom floating in it.
static func _stew() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(11, 6, 11))
	var middle := Vector2(5.5, 5.5)
	grid.disc(middle, 3.0, 0, _v("#5c3b1f"))
	grid.disc(middle, 4.2, 1, _v("#7a5230"))
	for y in range(2, 5):
		grid.disc(middle, 5.4, y, _v("#94683d" if y == 4 else "#7a5230"))
	grid.disc(middle, 4.4, 4, _v("#8a4a2a"))
	grid.disc(middle, 3.0, 4, _v("#a65f35"))
	for p: Vector3i in [Vector3i(4, 5, 4), Vector3i(7, 5, 6), Vector3i(5, 5, 7)]:
		grid.set_voxel(p, _v("#efe6d4"))
	grid.set_voxel(Vector3i(6, 5, 4), _v("#c7302f"))
	grid.set_voxel(Vector3i(3, 5, 6), _v("#9c6d46"))
	return grid


## Meat by the animal it comes from: a leg of mutton, a pork chop with its
## fat, a drumstick, a venison steak; roasted, browned with a crust.
static func _meat(item: int) -> VoxelGrid:
	var colors: Array = MEATS[item]
	var cooked := not String(Items.Id.find_key(item)).begins_with("RAW")
	var paint := func(p: Vector3i) -> int:
		var n := HashUtil.unit2(item * 31, p.x + p.z * 13, p.y)
		var index := 1
		if p.y == 0 or n < 0.22:
			index = 0
		elif n > 0.8 or (cooked and p.y >= 2 and n > 0.55):
			index = 2
		return _v(colors[index])
	var grid: VoxelGrid
	match item:
		Items.Id.RAW_MUTTON, Items.Id.COOKED_MUTTON:
			grid = VoxelGrid.new(Vector3i(13, 6, 7))
			grid.ellipsoid(Vector3(5.0, 2.7, 3.5), Vector3(4.6, 2.7, 3.1), paint)
			_bone(grid, Vector3(8.5, 2.6, 3.5), Vector3(11.6, 3.0, 3.5))
		Items.Id.RAW_CHICKEN, Items.Id.COOKED_CHICKEN:
			grid = VoxelGrid.new(Vector3i(12, 6, 6))
			grid.ellipsoid(Vector3(4.0, 2.7, 3.0), Vector3(3.7, 2.7, 2.7), paint)
			grid.ellipsoid(Vector3(7.0, 2.4, 3.0), Vector3(2.0, 1.6, 1.6), paint)
			_bone(grid, Vector3(8.5, 2.4, 3.0), Vector3(10.6, 2.6, 3.0))
		Items.Id.RAW_PORK, Items.Id.COOKED_PORK:
			grid = VoxelGrid.new(Vector3i(12, 4, 10))
			grid.ellipsoid(Vector3(6.0, 1.2, 5.0), Vector3(5.6, 1.9, 4.6), paint)
			var rim := _v(FAT if not cooked else colors[2])
			for x in 12:
				for y in 3:
					for z in range(6, 10):
						var p := Vector3i(x, y, z)
						var next := p + Vector3i(0, 0, 1)
						if grid.get_voxel(p) != 0 and grid.get_voxel(next) == 0:
							grid.set_voxel(p, rim)
			_bone(grid, Vector3(2.0, 1.5, 3.0), Vector3(3.0, 1.5, 4.5))
		_:
			grid = VoxelGrid.new(Vector3i(12, 4, 9))
			grid.ellipsoid(Vector3(6.0, 1.3, 4.5), Vector3(5.4, 1.8, 3.9), paint)
			# Marbled raw; roasted, the grill's marks across the top.
			for i in 3:
				var x := 3 + i * 3
				for z in range(1, 8):
					var p := Vector3i(x + z / 3, 2, z)
					if grid.get_voxel(p) != 0:
						grid.set_voxel(p, _v(colors[0] if cooked else "#d98c8c"))
	return grid


## A bone from `from` to `to`, a knob at its end.
static func _bone(grid: VoxelGrid, from: Vector3, to: Vector3) -> void:
	grid.line(from, to, 0.6, _v(BONE[1]))
	grid.ellipsoid(to + Vector3(0.4, 0.0, 0.0), Vector3(0.9, 1.1, 1.4), _v(BONE[1]))
	grid.set_voxel(Vector3i(to.floor()) + Vector3i(0, -1, 0), _v(BONE[0]))


## A feather, white with a brown tip, lying on the diagonal like a tool.
static func _feather() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(13, 13, 1))
	for i in range(1, 12):
		grid.set_voxel(Vector3i(i, i, 0), _v("#d9cfb8"))
		if i < 3:
			continue
		var tip := i >= 9
		var vane := _v("#6e4a2c" if tip else ("#f2efe8" if i % 2 else "#dcd7cc"))
		grid.set_voxel(Vector3i(i - 1, i, 0), vane)
		grid.set_voxel(Vector3i(i, i - 1, 0), vane)
		if i > 3 and i < 11:
			grid.set_voxel(Vector3i(i - 2, i, 0), vane)
			grid.set_voxel(Vector3i(i, i - 2, 0), _v("#c9c3b6" if not tip else "#4e331e"))
	return grid


## A hide: a pelt, fur on top, its leather showing at a folded corner.
static func _hide() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(12, 3, 10))
	for x in 12:
		for z in 10:
			var corner := Vector2(x, z).distance_to(Vector2(0, 0)) < 2.5
			corner = corner or Vector2(x, z).distance_to(Vector2(11, 9)) < 2.0
			if corner:
				continue
			var n := HashUtil.unit2(0x41DE, x, z)
			grid.set_voxel(Vector3i(x, 0, z), _v("#6a4a2c"))
			grid.set_voxel(Vector3i(x, 1, z), _v("#8a6440" if n > 0.7 else "#755232"))
	# A corner folded over: the pale leather side up.
	for x in range(7, 12):
		for z in range(0, 12 - x):
			grid.set_voxel(Vector3i(x, 2, z), _v("#c9a477" if (x + z) % 3 else "#b8935f"))
	return grid


## Along the diagonal of a TOOL_SIZE grid like the tools (`u` along it,
## `v` across), with `paint(u, v)` giving a voxel or 0.
static func _diagonal(paint: Callable) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(TOOL_SIZE.x, TOOL_SIZE.y, 1))
	for x in TOOL_SIZE.x:
		for y in TOOL_SIZE.y:
			var u := (x + y + 1.0) * SQRT_HALF
			var v := (y - x) * SQRT_HALF
			var value: int = paint.call(u, v)
			if value != 0:
				grid.set_voxel(Vector3i(x, y, 0), value)
	return grid


## A bow on the diagonal: a limb bending towards the upper left, wrapped
## in leather at its grip, and its string straight across.
static func _bow() -> VoxelGrid:
	return _diagonal(
		func(u: float, v: float) -> int:
			if u < 1.6 or u > 21.0:
				return 0
			var bend := 3.6 * sin(PI * (u - 1.6) / 19.4)
			if absf(v - bend) < 0.75:
				if absf(u - 11.3) < 1.6:
					return _v("#5c3b1f")
				return _v("#8a5a30" if v > bend else "#b07a44")
			if absf(v) < 0.4 and u > 2.2 and u < 20.4:
				return _v("#e8e2d2")
			return 0
	)


## An arrow on the diagonal: a stone head, a shaft, white fletching.
static func _arrow() -> VoxelGrid:
	return _diagonal(
		func(u: float, v: float) -> int:
			if u > 17.0 and u < 21.4 and absf(v) < (21.4 - u) * 0.45 + 0.3:
				return _v("#7c7b87" if v > 0.0 else "#5c5b66")
			if u > 2.0 and u <= 17.0 and absf(v) < 0.4:
				return _v("#c49b5f" if v > 0.0 else "#a07a46")
			if u > 1.6 and u < 6.5 and absf(v) < (6.5 - u) * 0.38 + 0.4:
				return _v("#f2efe8" if int(u) % 2 else "#d8442e")
			return 0
	)


## A hank of string: a few loose loops.
static func _string() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(10, 3, 10))
	for loop in 3:
		var radius := 3.6 - loop * 0.6
		for i in 40:
			var angle := TAU * i / 40.0
			var at := Vector3(
				4.5 + cos(angle) * radius, loop * 0.8, 4.5 + sin(angle) * radius * 0.8
			)
			grid.set_voxel(Vector3i(at.round()), _v("#e8e2d2" if loop % 2 else "#cfc8b4"))
	return grid


## A little heap of a lantern moth's wing dust: pale, glinting blue.
static func _moth_dust() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(10, 4, 10))
	for x in 10:
		for z in 10:
			var d := Vector2(x - 4.5, z - 4.5).length()
			var height := int(3.4 - d * 0.75)
			for y in height:
				var n := HashUtil.unit2(0x307D, x * 5 + y, z)
				if n > 0.86:
					grid.set_voxel(Vector3i(x, y, z), _v("#bfe8ff", VoxelGrid.Kind.GLOW))
				else:
					grid.set_voxel(Vector3i(x, y, z), _v("#d8d2c4" if n > 0.4 else "#b9b2a4"))
	return grid


## A shade lurker's essence: a shard of night, violet light in its heart.
static func _shade_essence() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(7, 10, 7))
	for y in 10:
		var radius := 2.8 - absf(y - 3.5) * 0.45
		grid.disc(Vector2(3.5, 3.5), maxf(radius, 0.6), y, _v("#1d1426" if y % 3 else "#2c1f3a"))
	grid.box(Vector3i(3, 2, 3), Vector3i(3, 5, 3), _v("#9a62e0", VoxelGrid.Kind.GLOW))
	grid.set_voxel(Vector3i(4, 4, 4), _v("#c9a0ff", VoxelGrid.Kind.GLOW))
	return grid


## A will-o'-wisp's ember: a glowing coal, green-gold at its heart.
static func _wisp_ember() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(8, 6, 8))
	grid.ellipsoid(Vector3(4, 2.6, 4), Vector3(3.2, 2.4, 3.2), _v("#3a2a1e"))
	grid.ellipsoid(Vector3(4, 2.8, 4), Vector3(2.2, 2.0, 2.2), _v("#c8e05a", VoxelGrid.Kind.GLOW))
	grid.set_voxel(Vector3i(4, 4, 4), _v("#f4ffb0", VoxelGrid.Kind.GLOW))
	grid.set_voxel(Vector3i(2, 4, 3), _v("#e8a030", VoxelGrid.Kind.GLOW))
	return grid


## A stub of charred wood: black, its rings still showing at its ends.
static func _charcoal() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(10, 5, 6))
	for x in 10:
		for y in 5:
			for z in 6:
				var d := Vector2(y - 2.0, z - 2.5).length()
				var bite := HashUtil.unit2(0xC4A2, x, y * 6 + z) * 0.8
				if d < 2.6 - bite * (1.0 if x == 0 or x == 9 else 0.4):
					var end := x == 0 or x == 9
					var ring := end and int(d) % 2 == 1
					var hex := "#3a302a" if ring else ("#1a1716" if (x + y) % 3 else "#2a2422")
					grid.set_voxel(Vector3i(x, y, z), _v(hex))
	return grid


## Food burnt black in the factory furnace, a spark still glowing in it.
static func _charred() -> VoxelGrid:
	var grid := _lump(["#0e0c0c", "#1f1a19", "#36292a"], Items.Id.CHARRED_FOOD)
	grid.set_voxel(Vector3i(3, 5, 4), _v("#b8301a", VoxelGrid.Kind.GLOW))
	grid.set_voxel(Vector3i(5, 4, 6), _v("#7a2016"))
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


## The player's book, closed: a leather cover with gold corners and an
## emblem, gold bands on the spine, the pages' edges showing on three sides.
static func _book() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(11, 4, 13))
	var leather := _v("#7a2a1e")
	var dark := _v("#521911")
	var gold := _v("#e3b24c")
	grid.box(Vector3i(0, 0, 0), Vector3i(10, 0, 12), leather)
	grid.box(Vector3i(0, 3, 0), Vector3i(10, 3, 12), leather)
	grid.box(Vector3i(0, 1, 0), Vector3i(0, 2, 12), dark)
	grid.box(Vector3i(1, 1, 1), Vector3i(9, 2, 11), _v("#f2e7ca"))
	for z in range(2, 11, 2):
		grid.set_voxel(Vector3i(9, 1, z), _v("#d8c79e"))
	for x in range(2, 9, 2):
		grid.set_voxel(Vector3i(x, 2, 11), _v("#d8c79e"))
	for z: int in [3, 9]:
		grid.box(Vector3i(0, 1, z), Vector3i(0, 2, z), gold)
	# The top cover: a darker rim, gold corners and a gold emblem.
	for x in 11:
		for z in 13:
			if x == 10 or z == 0 or z == 12:
				grid.set_voxel(Vector3i(x, 3, z), dark)
	for corner: Vector3i in [
		Vector3i(9, 3, 1), Vector3i(9, 3, 11), Vector3i(1, 3, 1), Vector3i(1, 3, 11)
	]:
		grid.set_voxel(corner, gold)
	for p: Vector3i in [
		Vector3i(5, 3, 4),
		Vector3i(4, 3, 5),
		Vector3i(6, 3, 5),
		Vector3i(3, 3, 6),
		Vector3i(7, 3, 6)
	]:
		grid.set_voxel(p, gold)
	for p: Vector3i in [Vector3i(4, 3, 7), Vector3i(6, 3, 7), Vector3i(5, 3, 8)]:
		grid.set_voxel(p, gold)
	grid.set_voxel(Vector3i(5, 3, 6), _v("#c4283a"))
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
