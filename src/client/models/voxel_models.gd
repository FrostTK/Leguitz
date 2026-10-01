class_name VoxelModels
extends RefCounted
## Procedural voxel models of everything that stands in the world: trees,
## bushes, grass, flowers, sugar cane, mushrooms, cacti, rocks... and the
## player. Each block has VARIANTS versions. tools/gen_models.gd turns them
## into meshes saved under assets/models/ (models are made once, offline).
##
## Sizes are in voxels (16 per tile, 16 per level). Every model stands on
## y = 0 and is centered on x and z; sizes are even so voxels stay aligned
## on the art-pixel grid.

const VARIANTS := 3
## Coarser copies for far views (zoomed out) and for shadows: level n is
## 2^n voxels per voxel.
const LODS := 3
const BLOCK_DIR := "res://assets/models/blocks/"
const PLAYER_DIR := "res://assets/models/player/"
const PLAYER_PARTS: Array[String] = ["head", "torso", "arm", "leg"]

const LEAVES := {
	"oak": ["#24542c", "#31733a", "#46963f", "#7cc255"],
	"birch": ["#4a7d2c", "#63a03b", "#86c24f", "#b8e27a"],
	"dark": ["#15341e", "#1d4a28", "#2a6331", "#3f7f3a"],
	"jungle": ["#175a28", "#227a36", "#34a046", "#6ccc5a"],
	"acacia": ["#50682a", "#6a8a32", "#8aab44", "#b8cf66"],
	"swamp": ["#2c4526", "#3b5a30", "#50753c", "#779652"],
	"spruce": ["#123524", "#1a4a31", "#255f3f", "#33754e"],
	"bush": ["#2c6a2c", "#3f8c38", "#5daf48", "#95d566"],
	"grass": ["#356f24", "#4b8f33", "#5fa83d", "#7cc255"],
}
const BARK := ["#4a2d1a", "#6e4326", "#8e5c35"]
const DARK_BARK := ["#2e1d12", "#43291a", "#5a3923"]
const BIRCH_BARK := ["#b9b3a8", "#d4cfc4", "#ece8df"]
const ACACIA_BARK := ["#65584a", "#8a7a6a", "#a89886"]
const SPRUCE_BARK := ["#3d2414", "#5a3620", "#744a2c"]
const STONE := ["#4a4954", "#5c5b66", "#7c7b87", "#9d9ca7"]
const SNOW := ["#c9d6e6", "#e2eaf4", "#f6f9fc"]
const VINE := ["#2c5a1e", "#3f7a2a"]
const SKIN := "#f3c49b"
const SKIN_SHADE := "#d99c77"
const HAIR := "#7a4524"
const HAIR_SHADE := "#56301a"
const SHIRT := "#d6524a"
const SHIRT_SHADE := "#a63a37"
const PANTS := "#3d5a99"
const PANTS_SHADE := "#2c4373"
const SHOES := "#4a3020"


## Every block that is drawn as a model (not air, not cube blocks).
static func modeled_blocks() -> Array[int]:
	var result: Array[int] = []
	for block in Tiles.Block.size():
		if block != Tiles.Block.AIR and not Tiles.is_cube(block):
			result.append(block)
	return result


static func block_path(block: int, variant: int, lod := 0) -> String:
	var name := String(Tiles.Block.find_key(block)).to_lower()
	var suffix := "" if lod == 0 else "_lod%d" % lod
	return "%s%s_%d%s.res" % [BLOCK_DIR, name, variant, suffix]


static func player_path(part: String) -> String:
	return "%s%s.res" % [PLAYER_DIR, part]


static func build(block: int, variant: int) -> VoxelGrid:
	var rng := RandomNumberGenerator.new()
	rng.seed = HashUtil.hash2(0x7E5E, block, variant)
	match block:
		Tiles.Block.OAK:
			return _broadleaf(rng, 4, 24, BARK, "oak", Vector3(12, 9, 12), 6)
		Tiles.Block.BIRCH:
			var birch := _broadleaf(rng, 3, 30, BIRCH_BARK, "birch", Vector3(9, 11, 9), 4)
			_birch_marks(birch, rng)
			return birch
		Tiles.Block.DARK_OAK:
			return _broadleaf(rng, 6, 17, DARK_BARK, "dark", Vector3(16, 8, 16), 7)
		Tiles.Block.JUNGLE_TREE:
			var jungle := _broadleaf(rng, 4, 44, BARK, "jungle", Vector3(13, 8, 13), 6)
			_vines(jungle, rng, 0.06, 14)
			return jungle
		Tiles.Block.SWAMP_OAK:
			var swamp := _broadleaf(rng, 4, 20, DARK_BARK, "swamp", Vector3(14, 7.5, 14), 6)
			_vines(swamp, rng, 0.1, 12)
			return swamp
		Tiles.Block.ACACIA:
			return _acacia(rng)
		Tiles.Block.SPRUCE:
			return _spruce(rng, false)
		Tiles.Block.SNOWY_SPRUCE:
			return _spruce(rng, true)
		Tiles.Block.BUSH:
			return _bush(rng, [])
		Tiles.Block.BERRY_BUSH:
			return _bush(rng, ["#c4283a", "#e2484f", "#8e1a2c"])
		Tiles.Block.ROCK:
			return _rock(rng, false)
		Tiles.Block.MOSSY_ROCK:
			return _rock(rng, true)
		Tiles.Block.TALL_GRASS:
			return _tall_grass(rng)
		Tiles.Block.FERN:
			return _fern(rng)
		Tiles.Block.DEAD_BUSH:
			return _dead_bush(rng)
		Tiles.Block.FLOWER_RED:
			return _flowers(rng, ["#b8202c", "#e23a44", "#ff6b6b"], "#f7d74a")
		Tiles.Block.FLOWER_YELLOW:
			return _flowers(rng, ["#d9a21c", "#f2c53d", "#ffe680"], "#8a5a20")
		Tiles.Block.FLOWER_BLUE:
			return _flowers(rng, ["#3550b8", "#4a6ee0", "#8aa6ff"], "#f7d74a")
		Tiles.Block.FLOWER_WHITE:
			return _flowers(rng, ["#d8d8d8", "#f2f2f2", "#ffffff"], "#f7d74a")
		Tiles.Block.FLOWER_PINK:
			return _flowers(rng, ["#d0587e", "#f07aa0", "#ffb0c8"], "#fff1a8")
		Tiles.Block.MUSHROOM_RED:
			return _small_mushrooms(rng, ["#9c1f24", "#c7302f", "#e0483f"], true)
		Tiles.Block.MUSHROOM_BROWN:
			return _small_mushrooms(rng, ["#6a432a", "#8a5a3a", "#a8744a"], false)
		Tiles.Block.BIG_MUSHROOM:
			return _big_mushroom(rng)
		Tiles.Block.CACTUS:
			return _cactus(rng, variant)
		Tiles.Block.SUGAR_CANE:
			return _sugar_cane(rng)
		Tiles.Block.LILY_PAD:
			return _lily_pad(rng, variant)
	return VoxelGrid.new()


## The player, in parts that move (Minecraft-like proportions, 25 voxels
## tall). Front = +Z.
static func build_player_part(part: String) -> VoxelGrid:
	match part:
		"head":
			return _player_head()
		"torso":
			return _player_torso()
		"arm":
			return _player_arm()
		_:
			return _player_leg()


# ---------------------------------------------------------------- painting


static func _v(hex: String, kind := VoxelGrid.Kind.SOLID) -> int:
	return VoxelGrid.voxel(Color(hex), kind)


## Random-looking but fixed value in 0..1 for a voxel.
static func _noise(p: Vector3i, salt: int) -> float:
	return HashUtil.unit2(salt + p.z * 7919, p.x, p.y)


## Paints from a palette (dark to light): lighter higher up, in small
## blocky patches like pixel-art clusters.
static func _shaded(
	palette: Array, low: float, high: float, salt: int, kind := VoxelGrid.Kind.SOLID, patch := 3
) -> Callable:
	var values: Array[int] = []
	for hex: String in palette:
		values.append(_v(hex, kind))
	var last := values.size() - 1
	return func(p: Vector3i) -> int:
		var t := clampf((p.y - low) / maxf(1.0, high - low), 0.0, 1.0)
		var n := _noise(p / patch, salt)
		var index := clampi(int(t * last + (n - 0.5) * 1.8 + 0.5), 0, last)
		return values[index]


## Breaks up smooth foliage: removes some surface voxels, adds tufts.
static func _roughen(
	grid: VoxelGrid, rng: RandomNumberGenerator, remove: float, add: float
) -> void:
	var sides: Array[Vector3i] = [
		Vector3i.LEFT, Vector3i.RIGHT, Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK
	]
	var surface: Array[Vector3i] = []
	for z in grid.size.z:
		for y in grid.size.y:
			for x in grid.size.x:
				var p := Vector3i(x, y, z)
				var value := grid.get_voxel(p)
				if value == 0 or VoxelGrid.kind_of(value) != VoxelGrid.Kind.FOLIAGE:
					continue
				for side in sides:
					if grid.get_voxel(p + side) == 0:
						surface.append(p)
						break
	for p in surface:
		var roll := rng.randf()
		if roll < remove:
			grid.set_voxel(p, 0)
		elif roll < remove + add:
			var side: Vector3i = sides[rng.randi_range(0, sides.size() - 1)]
			if side != Vector3i.DOWN and grid.get_voxel(p + side) == 0:
				grid.set_voxel(p + side, grid.get_voxel(p))


# ---------------------------------------------------------------- trees


static func _trunk(
	grid: VoxelGrid, width: int, height: int, bark: Array, rng: RandomNumberGenerator
) -> void:
	var x0 := grid.size.x / 2 - width / 2
	var z0 := grid.size.z / 2 - width / 2
	var paint := _shaded(bark, 0, width, rng.randi(), VoxelGrid.Kind.SOLID, 2)
	grid.box(Vector3i(x0, 0, z0), Vector3i(x0 + width - 1, height, z0 + width - 1), paint)
	# Roots flaring at the base.
	for i in 4:
		var side: Vector2i = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)][i]
		if rng.randf() < 0.75:
			var along := rng.randi_range(0, width - 1)
			var x := x0 - 1 if side.x < 0 else (x0 + width if side.x > 0 else x0 + along)
			var z := z0 - 1 if side.y < 0 else (z0 + width if side.y > 0 else z0 + along)
			grid.box(Vector3i(x, 0, z), Vector3i(x, rng.randi_range(0, 2), z), _v(bark[0]))


static func _broadleaf(
	rng: RandomNumberGenerator,
	trunk_width: int,
	base_height: int,
	bark: Array,
	leaves: String,
	base_radius: Vector3,
	blobs: int
) -> VoxelGrid:
	# Every variant grows a little differently.
	var radius := base_radius * rng.randf_range(0.86, 1.1)
	var trunk_height := int(base_height * rng.randf_range(0.85, 1.15))
	var half := ceili(radius.x * 1.45) + 1
	var size := Vector3i(half * 2, trunk_height + ceili(radius.y * 2.3) + 3, half * 2)
	var grid := VoxelGrid.new(size)
	var center := Vector3(size.x * 0.5, trunk_height + radius.y * 0.75, size.z * 0.5)
	_trunk(grid, trunk_width, trunk_height, bark, rng)
	var wood := _v(bark[1])
	var clusters: Array[Array] = [[center, radius]]
	for i in blobs:
		var angle := TAU * (i + rng.randf_range(-0.3, 0.3)) / blobs
		var reach := rng.randf_range(0.5, 0.78)
		var blob := (
			center
			+ Vector3(
				cos(angle) * radius.x * reach,
				rng.randf_range(-0.35, 0.45) * radius.y,
				sin(angle) * radius.z * reach
			)
		)
		clusters.append([blob, radius * rng.randf_range(0.48, 0.64)])
		# A branch from the trunk to the cluster, seen under the leaves.
		var fork := Vector3(size.x * 0.5, trunk_height - rng.randi_range(1, 4), size.z * 0.5)
		grid.line(fork, blob, 0.0, wood)
	var paint := _shaded(
		LEAVES[leaves],
		center.y - radius.y,
		center.y + radius.y * 1.1,
		rng.randi(),
		VoxelGrid.Kind.FOLIAGE,
		4
	)
	for cluster in clusters:
		grid.ellipsoid(cluster[0], cluster[1], paint)
	_roughen(grid, rng, 0.2, 0.1)
	grid.sway = 0.7
	grid.sway_from = int(trunk_height * 0.5)
	return grid


static func _birch_marks(grid: VoxelGrid, rng: RandomNumberGenerator) -> void:
	var dark := _v("#2e2a26")
	for z in grid.size.z:
		for y in grid.size.y:
			for x in grid.size.x:
				var p := Vector3i(x, y, z)
				var value := grid.get_voxel(p)
				if value == 0 or VoxelGrid.kind_of(value) != VoxelGrid.Kind.SOLID:
					continue
				if y % 3 == 0 and rng.randf() < 0.3:
					grid.set_voxel(p, dark)


static func _vines(
	grid: VoxelGrid, rng: RandomNumberGenerator, chance: float, longest: int
) -> void:
	var vine0 := _v(VINE[0], VoxelGrid.Kind.FOLIAGE)
	var vine1 := _v(VINE[1], VoxelGrid.Kind.FOLIAGE)
	for z in grid.size.z:
		for x in grid.size.x:
			# The underside of the canopy: lowest foliage voxel of a column.
			for y in grid.size.y:
				var value := grid.get_voxel(Vector3i(x, y, z))
				if value == 0:
					continue
				if VoxelGrid.kind_of(value) == VoxelGrid.Kind.FOLIAGE and rng.randf() < chance:
					var length := rng.randi_range(3, longest)
					for k in range(1, length):
						if y - k < 1 or grid.get_voxel(Vector3i(x, y - k, z)) != 0:
							break
						grid.set_voxel(Vector3i(x, y - k, z), vine0 if k % 3 else vine1)
				break


static func _acacia(rng: RandomNumberGenerator) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(42, 46, 42))
	var middle := Vector3(21, 0, 21)
	_trunk(grid, 3, 20, ACACIA_BARK, rng)
	var wood := _v(ACACIA_BARK[1])
	var paint := _shaded(LEAVES["acacia"], 32, 42, rng.randi(), VoxelGrid.Kind.FOLIAGE)
	var angle := rng.randf() * TAU
	for i in 2:
		var a := angle + PI * i + rng.randf_range(-0.4, 0.4)
		var reach := rng.randf_range(6.0, 9.0)
		var top := middle + Vector3(cos(a) * reach, rng.randf_range(32.0, 37.0), sin(a) * reach)
		grid.line(middle + Vector3(0, 19, 0), top, 1.0, wood)
		grid.ellipsoid(top + Vector3(0, 2.5, 0), Vector3(12, 3.5, 12), paint)
	_roughen(grid, rng, 0.15, 0.08)
	grid.sway = 0.6
	grid.sway_from = 18
	return grid


static func _spruce(rng: RandomNumberGenerator, snowy: bool) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(30, 72, 30))
	var greens: Array[int] = []
	for hex: String in LEAVES["spruce"]:
		greens.append(_v(hex, VoxelGrid.Kind.FOLIAGE))
	var tall := rng.randf_range(1.12, 1.32)
	var wide := rng.randf_range(0.95, 1.18)
	var tiers: Array[Array] = []
	for tier: Array in [[6, 22, 12.0], [15, 33, 10.0], [25, 43, 7.5], [35, 52, 5.0]]:
		tiers.append([int(tier[0] * tall), int(tier[1] * tall), tier[2] * wide])
	_trunk(grid, 2, int(48 * tall), SPRUCE_BARK, rng)
	var twist := rng.randf() * TAU
	for y in grid.size.y:
		for tier: Array in tiers:
			var base: int = tier[0]
			var top: int = tier[1]
			if y < base or y > top:
				continue
			var t := float(y - base) / (top - base)
			var radius: float = tier[2] * pow(1.0 - t, 0.85) + 0.6
			for z in grid.size.z:
				for x in grid.size.x:
					var d := Vector2(x + 0.5 - 15.0, z + 0.5 - 15.0)
					var boughs := 0.8 + 0.2 * sin(d.angle() * 7.0 + y * 0.8 + twist)
					if d.length() > radius * boughs:
						continue
					# Darker at the bottom of each tier, under the next one.
					var shade := clampi(
						int(t * 3.5 + _noise(Vector3i(x, y, z) / 2, 31) - 0.3), 0, 3
					)
					grid.set_voxel(Vector3i(x, y, z), greens[shade])
	if snowy:
		_snow_cover(grid, rng)
	grid.sway = 0.5
	grid.sway_from = 16
	return grid


## Snow on every upward-facing foliage voxel (and some just below).
static func _snow_cover(grid: VoxelGrid, rng: RandomNumberGenerator) -> void:
	for z in grid.size.z:
		for x in grid.size.x:
			for y in range(grid.size.y - 1, -1, -1):
				var p := Vector3i(x, y, z)
				var value := grid.get_voxel(p)
				if value == 0:
					continue
				if VoxelGrid.kind_of(value) == VoxelGrid.Kind.FOLIAGE:
					grid.set_voxel(p, _v(SNOW[rng.randi_range(1, 2)], VoxelGrid.Kind.FOLIAGE))
					if rng.randf() < 0.4 and grid.get_voxel(p + Vector3i.DOWN) != 0:
						grid.set_voxel(p + Vector3i.DOWN, _v(SNOW[0], VoxelGrid.Kind.FOLIAGE))
				break


# ---------------------------------------------------------------- bushes, rocks


static func _bush(rng: RandomNumberGenerator, berries: Array) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(20, 14, 20))
	var paint := _shaded(LEAVES["bush"], 0, 12, rng.randi(), VoxelGrid.Kind.FOLIAGE, 2)
	grid.ellipsoid(Vector3(10, 4.5, 10), Vector3(7.5, 5, 7.5), paint)
	for i in 3:
		var a := TAU * i / 3.0 + rng.randf()
		var blob := Vector3(10 + cos(a) * 3.5, rng.randf_range(4.0, 6.5), 10 + sin(a) * 3.5)
		grid.ellipsoid(blob, Vector3(4.5, 4.5, 4.5), paint)
	_roughen(grid, rng, 0.15, 0.12)
	if not berries.is_empty():
		_dot_surface(grid, rng, berries, 0.12, Vector3i.ZERO)
	grid.sway = 0.35
	return grid


## Colors random visible voxels (berries, spots, spines...). Voxels facing
## `away` are skipped (Vector3i.ZERO: any side).
static func _dot_surface(
	grid: VoxelGrid, rng: RandomNumberGenerator, palette: Array, chance: float, away: Vector3i
) -> void:
	for z in grid.size.z:
		for y in grid.size.y:
			for x in grid.size.x:
				var p := Vector3i(x, y, z)
				if grid.get_voxel(p) == 0:
					continue
				var exposed := false
				for side: Vector3i in [
					Vector3i.LEFT, Vector3i.RIGHT, Vector3i.UP, Vector3i.FORWARD, Vector3i.BACK
				]:
					if side != away and grid.get_voxel(p + side) == 0:
						exposed = true
						break
				if exposed and rng.randf() < chance:
					grid.set_voxel(p, _v(palette[rng.randi_range(0, palette.size() - 1)]))


static func _lumpy(
	grid: VoxelGrid, center: Vector3, radius: Vector3, paint: Callable, salt: int
) -> void:
	var low := Vector3i((center - radius * 1.3).floor())
	var high := Vector3i((center + radius * 1.3).ceil())
	for z in range(low.z, high.z + 1):
		for y in range(maxi(low.y, 0), high.y + 1):
			for x in range(low.x, high.x + 1):
				var p := Vector3i(x, y, z)
				var d := (Vector3(p) + Vector3.ONE * 0.5 - center) / radius
				var bumps := (_noise(p / 2, salt) - 0.5) * 0.35
				if d.length() <= 1.0 + bumps:
					grid.set_voxel(p, paint.call(p))


static func _rock(rng: RandomNumberGenerator, mossy: bool) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(20, 12, 20))
	var paint := _shaded(STONE, 0, 10, rng.randi(), VoxelGrid.Kind.SOLID, 2)
	var main := Vector3(10 + rng.randf_range(-1, 1), 2.5, 10 + rng.randf_range(-1, 1))
	_lumpy(grid, main, Vector3(rng.randf_range(6, 7.5), 6.5, rng.randf_range(5, 6.5)), paint, 1)
	if rng.randf() < 0.7:
		var side := Vector3(rng.randf_range(3, 5), 1.5, rng.randf_range(3, 17))
		_lumpy(grid, side, Vector3(3.5, 3.5, 3.5), paint, 2)
	if mossy:
		var moss: Array[int] = [_v("#4a7f30"), _v("#5e9a3a"), _v("#7cb04c")]
		for z in grid.size.z:
			for x in grid.size.x:
				for y in range(grid.size.y - 1, -1, -1):
					var p := Vector3i(x, y, z)
					if grid.get_voxel(p) != 0:
						if _noise(p / 2, 77) < 0.75:
							grid.set_voxel(p, moss[rng.randi_range(0, 2)])
						break
	return grid


# ---------------------------------------------------------------- small plants


static func _tall_grass(rng: RandomNumberGenerator) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(14, 12, 14))
	var greens: Array = LEAVES["grass"]
	for i in rng.randi_range(9, 13):
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 5.0
		var x := int(7 + cos(a) * r)
		var z := int(7 + sin(a) * r)
		var height := rng.randi_range(4, 11)
		var lean := Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))
		for y in height:
			var bent := lean if y >= height - 2 else Vector2i.ZERO
			var shade := clampi(y * 4 / height + rng.randi_range(-1, 0), 0, 3)
			grid.set_voxel(
				Vector3i(x + bent.x, y, z + bent.y), _v(greens[shade], VoxelGrid.Kind.FOLIAGE)
			)
	grid.sway = 1.0
	return grid


static func _fern(rng: RandomNumberGenerator) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(20, 10, 20))
	var dark := _v("#2f6a2e", VoxelGrid.Kind.FOLIAGE)
	var light := _v("#5a9f48", VoxelGrid.Kind.FOLIAGE)
	var fronds := rng.randi_range(5, 7)
	for i in fronds:
		var a := TAU * (i + rng.randf_range(-0.2, 0.2)) / fronds
		var direction := Vector2(cos(a), sin(a))
		for t in 9:
			var height := 1.0 + t * 1.1 - t * t * 0.1
			var spot := Vector2(10, 10) + direction * t
			var p := Vector3i(int(spot.x), int(height), int(spot.y))
			grid.set_voxel(p, dark)
			if t % 2 == 0 and t > 1:
				var side := Vector2(-direction.y, direction.x)
				for s: int in [-1, 1]:
					var leaflet := spot + side * s
					grid.set_voxel(Vector3i(int(leaflet.x), int(height), int(leaflet.y)), light)
	grid.sway = 0.8
	return grid


static func _dead_bush(rng: RandomNumberGenerator) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(14, 10, 14))
	var twig := _v("#8a6a3e")
	var dark := _v("#6e5230")
	for i in rng.randi_range(4, 6):
		var a := rng.randf() * TAU
		var tip := Vector3(7 + cos(a) * 5, rng.randf_range(5, 9), 7 + sin(a) * 5)
		grid.line(Vector3(7, 0, 7), tip, 0.0, twig if i % 2 else dark)
		var mid := Vector3(7, 0, 7).lerp(tip, 0.6)
		grid.line(mid, mid + Vector3(rng.randf_range(-2, 2), 2, rng.randf_range(-2, 2)), 0.0, twig)
	grid.sway = 0.25
	return grid


static func _flowers(rng: RandomNumberGenerator, petals: Array, heart: String) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(12, 12, 12))
	var stem := _v("#3f7f2a", VoxelGrid.Kind.FOLIAGE)
	var leaf := _v("#5fa83d", VoxelGrid.Kind.FOLIAGE)
	var spots: Array[Vector2i] = [Vector2i(4, 4), Vector2i(8, 7), Vector2i(5, 9)]
	for i in rng.randi_range(2, 3):
		var s: Vector2i = spots[i] + Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))
		var height := rng.randi_range(5, 9)
		grid.box(Vector3i(s.x, 0, s.y), Vector3i(s.x, height - 1, s.y), stem)
		var leaf_side: Vector2i = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN][
			rng.randi_range(0, 3)
		]
		grid.set_voxel(Vector3i(s.x + leaf_side.x, 2, s.y + leaf_side.y), leaf)
		grid.set_voxel(Vector3i(s.x + leaf_side.x * 2, 3, s.y + leaf_side.y * 2), leaf)
		var outer := _v(petals[0], VoxelGrid.Kind.FOLIAGE)
		var inner := _v(petals[1], VoxelGrid.Kind.FOLIAGE)
		var tip := _v(petals[2], VoxelGrid.Kind.FOLIAGE)
		# A small cup of petals around a bright heart.
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			grid.set_voxel(Vector3i(s.x + d.x, height, s.y + d.y), inner)
			grid.set_voxel(Vector3i(s.x + d.x, height + 1, s.y + d.y), tip)
		for d: Vector2i in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			grid.set_voxel(Vector3i(s.x + d.x, height, s.y + d.y), outer)
		grid.set_voxel(Vector3i(s.x, height, s.y), _v(heart))
	grid.sway = 1.0
	return grid


static func _small_mushrooms(rng: RandomNumberGenerator, cap: Array, spotted: bool) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(12, 9, 12))
	var stem := _v("#efe6d4")
	var spots: Array[Vector2] = [Vector2(4.5, 5.5), Vector2(8, 7.5), Vector2(6.5, 3)]
	for i in rng.randi_range(1, 3):
		var s := spots[i] + Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5))
		var size := rng.randf_range(0.7, 1.0) if i == 0 else rng.randf_range(0.45, 0.7)
		var height := int(round(3.0 * size)) + 1
		grid.cylinder(s, 0.8, 0, height - 1, stem)
		var paint := _shaded(cap, height, height + 3.0 * size, rng.randi(), VoxelGrid.Kind.SOLID, 1)
		var radius := Vector3(3.2, 2.4, 3.2) * size
		var center := Vector3(s.x, height, s.y)
		var dome := func(p: Vector3i) -> int: return paint.call(p) if p.y >= height else 0
		grid.ellipsoid(center, radius, dome)
	if spotted:
		_dot_surface(grid, rng, ["#ffffff"], 0.18, Vector3i.ZERO)
	return grid


static func _big_mushroom(rng: RandomNumberGenerator) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(38, 44, 38))
	var center := Vector2(19, 19)
	var stem_top := rng.randi_range(26, 33)
	var cap_radius := rng.randf_range(14.0, 17.0)
	var stem := _shaded(
		["#cfc3ad", "#efe6d4", "#fff8ea"], 0, 4, rng.randi(), VoxelGrid.Kind.SOLID, 1
	)
	grid.cylinder(center, 4.0, 0, stem_top, stem)
	grid.disc(center, 5.5, stem_top - 8, _v("#e8dcc4"))
	var cap := _shaded(
		["#9c1f24", "#c7302f", "#e0483f"],
		stem_top,
		stem_top + 6,
		rng.randi(),
		VoxelGrid.Kind.SOLID,
		3
	)
	# A wide, flat-topped cap with a rim hanging down.
	var top := func(p: Vector3i) -> int: return cap.call(p) if p.y >= stem_top else 0
	grid.ellipsoid(
		Vector3(center.x, stem_top - 1, center.y), Vector3(cap_radius, 5.5, cap_radius), top
	)
	var rim := func(p: Vector3i) -> int:
		var d := Vector2(p.x + 0.5, p.z + 0.5).distance_to(center)
		return cap.call(p) if d > cap_radius - 2.5 else 0
	grid.cylinder(center, cap_radius - 0.5, stem_top - 2, stem_top - 1, rim)
	# Gills under the cap.
	grid.disc(center, cap_radius - 2.5, stem_top - 1, _v("#e8d8b8"))
	grid.cylinder(center, 4.0, stem_top - 3, stem_top, stem)
	_dot_surface(grid, rng, ["#ffffff", "#f4ece4"], 0.07, Vector3i.ZERO)
	return grid


static func _cactus(rng: RandomNumberGenerator, variant: int) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(16, 32, 16))
	var height := rng.randi_range(22, 29)
	var ribs := func(p: Vector3i) -> int:
		var stripe := (p.x + p.z) % 2 == 0
		return _v("#5ead45" if stripe else "#3f8530")
	# A rounded column (corners trimmed).
	grid.box(Vector3i(5, 0, 6), Vector3i(10, height, 9), ribs)
	grid.box(Vector3i(6, 0, 5), Vector3i(9, height, 10), ribs)
	for i in rng.randi_range(1, 2):
		var side := 1 if (i + variant) % 2 == 0 else -1
		var y := rng.randi_range(8, 14)
		var x0 := 11 if side > 0 else 1
		grid.box(Vector3i(x0, y, 7), Vector3i(x0 + 3, y + 2, 8), ribs)
		var up_x := 13 if side > 0 else 1
		grid.box(Vector3i(up_x, y, 7), Vector3i(up_x + 1, y + rng.randi_range(5, 9), 8), ribs)
	_dot_surface(grid, rng, ["#e8e2b0"], 0.08, Vector3i.ZERO)
	if variant == 0:
		grid.box(Vector3i(7, height + 1, 7), Vector3i(8, height + 1, 8), _v("#f07aa0"))
	return grid


static func _sugar_cane(rng: RandomNumberGenerator) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(14, 34, 14))
	var cane := _v("#7fc45a", VoxelGrid.Kind.FOLIAGE)
	var node := _v("#5a9a3f", VoxelGrid.Kind.FOLIAGE)
	var leaf := _v("#94d468", VoxelGrid.Kind.FOLIAGE)
	var spots: Array[Vector2i] = [Vector2i(4, 4), Vector2i(8, 5), Vector2i(5, 8), Vector2i(9, 9)]
	for i in rng.randi_range(3, 4):
		var s: Vector2i = spots[i]
		var height := rng.randi_range(20, 32)
		for y in height:
			var paint := node if y % 5 == 4 else cane
			grid.box(Vector3i(s.x, y, s.y), Vector3i(s.x + 1, y, s.y + 1), paint)
			if y % 5 == 4 and y > 6 and rng.randf() < 0.6:
				var d: Vector2i = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN][
					rng.randi_range(0, 3)
				]
				for k in range(1, 4):
					var leaf_spot := Vector2i(s.x, s.y) + d * (k + (1 if d.x > 0 or d.y > 0 else 0))
					grid.set_voxel(Vector3i(leaf_spot.x, y + k / 2, leaf_spot.y), leaf)
	grid.sway = 0.8
	return grid


static func _lily_pad(rng: RandomNumberGenerator, variant: int) -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(14, 4, 14))
	var notch := rng.randf() * TAU
	var paint := func(p: Vector3i) -> int:
		var d := Vector2(p.x + 0.5 - 7.0, p.z + 0.5 - 7.0)
		if absf(angle_difference(d.angle(), notch)) < 0.3:
			return 0
		return _v("#5fb84a" if d.length() > 5.0 else ("#3f9a3a" if (p.x + p.z) % 3 else "#4aa83f"))
	grid.disc(Vector2(7, 7), 6.2, 0, paint)
	if variant == 2:
		var petal := _v("#f2a0c0")
		grid.box(Vector3i(6, 1, 6), Vector3i(7, 1, 7), petal)
		grid.box(Vector3i(6, 2, 6), Vector3i(7, 2, 7), _v("#fff1a8"))
		for d: Vector3i in [
			Vector3i(-1, 1, 0), Vector3i(2, 1, 1), Vector3i(0, 1, -1), Vector3i(1, 1, 2)
		]:
			grid.set_voxel(Vector3i(6, 0, 6) + d, petal)
	return grid


# ---------------------------------------------------------------- player


static func _player_head() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(8, 8, 8))
	grid.box(Vector3i(0, 0, 0), Vector3i(7, 7, 7), _v(SKIN))
	grid.box(Vector3i(0, 0, 0), Vector3i(7, 0, 7), _v(SKIN_SHADE))
	# Hair: top, back and sides, with a fringe.
	grid.box(Vector3i(0, 5, 0), Vector3i(7, 7, 7), _v(HAIR))
	grid.box(Vector3i(0, 1, 0), Vector3i(7, 7, 1), _v(HAIR))
	grid.box(Vector3i(0, 2, 0), Vector3i(0, 7, 5), _v(HAIR_SHADE))
	grid.box(Vector3i(7, 2, 0), Vector3i(7, 7, 5), _v(HAIR_SHADE))
	grid.box(Vector3i(1, 5, 7), Vector3i(3, 5, 7), _v(HAIR_SHADE))
	# Face (front = +Z): eyes and a smile.
	grid.set_voxel(Vector3i(2, 3, 7), _v("#2a1d18"))
	grid.set_voxel(Vector3i(5, 3, 7), _v("#2a1d18"))
	grid.set_voxel(Vector3i(2, 4, 7), _v("#ffffff"))
	grid.set_voxel(Vector3i(5, 4, 7), _v("#ffffff"))
	grid.box(Vector3i(3, 1, 7), Vector3i(4, 1, 7), _v("#b5615a"))
	return grid


static func _player_torso() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(8, 8, 4))
	grid.box(Vector3i(0, 0, 0), Vector3i(7, 7, 3), _v(SHIRT))
	grid.box(Vector3i(0, 0, 0), Vector3i(7, 1, 3), _v(PANTS_SHADE))
	grid.box(Vector3i(0, 1, 0), Vector3i(7, 1, 3), _v("#3a2a20"))
	grid.box(Vector3i(3, 1, 3), Vector3i(4, 1, 3), _v("#d9b44a"))
	grid.box(Vector3i(0, 2, 0), Vector3i(7, 2, 0), _v(SHIRT_SHADE))
	grid.box(Vector3i(3, 6, 3), Vector3i(4, 7, 3), _v(SKIN))
	return grid


static func _player_arm() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(2, 8, 2))
	grid.box(Vector3i(0, 0, 0), Vector3i(1, 1, 1), _v(SKIN))
	grid.box(Vector3i(0, 2, 0), Vector3i(1, 7, 1), _v(SHIRT))
	grid.box(Vector3i(0, 2, 0), Vector3i(1, 2, 1), _v(SHIRT_SHADE))
	return grid


static func _player_leg() -> VoxelGrid:
	var grid := VoxelGrid.new(Vector3i(4, 8, 4))
	grid.box(Vector3i(0, 0, 0), Vector3i(3, 1, 3), _v(SHOES))
	grid.box(Vector3i(0, 2, 0), Vector3i(3, 7, 3), _v(PANTS))
	grid.box(Vector3i(0, 2, 0), Vector3i(3, 2, 3), _v(PANTS_SHADE))
	return grid
