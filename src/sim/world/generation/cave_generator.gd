class_name CaveGenerator
extends RefCounted
## Caves under the surface, carved in 3D like Minecraft's noise caves:
## - "cheese" caves: large chambers, flatter than wide, with rock pillars
##   left inside,
## - "spaghetti" caves: long winding tunnels, where two noises are both
##   close to zero.
## Chamber floors may hold small lakes (upper rows) or lava (deep rows), and
## ores come in veins by depth, like Minecraft's ore features.
##
## The noises of a chunk are sampled all at once (Noise.get_image_3d: one
## native call per noise): calling them voxel by voxel is slow, and threads
## calling them slow each other down. Values are then bytes, 0..255 for
## -1..1, and a row y reads the noise at height round(y * stretch).

## Rows below this stay solid (the bottom of the world).
const MIN_ROW := 3
## Rows of rock kept between the caves and the terrain above.
const ROOF := 2
## Below this row, stone turns into deepslate (Minecraft's y < 0).
const DEEPSLATE_ROW := 30
const LAVA_BELOW_ROW := 20
const LAKES_FROM_ROW := 34
## Vertical stretch of the noises: chambers are 2.2 times flatter than
## wide, pillars stand tall, tunnels a little flat.
const CHEESE_STRETCH := 2.2
const PILLAR_STRETCH := 0.25
const SPAGHETTI_STRETCH := 1.4
## Rock opens into chambers above this cheese value (lower deeper down),
## where pillars are below PILLAR_VALUE; tunnels run where both spaghetti
## noises are within TUNNEL_WIDTH of zero.
const CHEESE_VALUE := 0.44
const CHEESE_DEEP_BONUS := 0.08
const PILLAR_VALUE := 0.55
const TUNNEL_WIDTH := 0.07

const SALT_BASE := 100

## [ore block, lowest row, highest row, veins per chunk, voxels per vein],
## rarest first.
const ORES := [
	[Tiles.Block.DIAMOND_ORE, 4, 22, 1, 4],
	[Tiles.Block.RUBY_ORE, 4, 30, 1, 5],
	[Tiles.Block.LAPIS_ORE, 10, 40, 2, 5],
	[Tiles.Block.GOLD_ORE, 4, 40, 2, 6],
	[Tiles.Block.IRON_ORE, 14, 64, 6, 7],
	[Tiles.Block.COPPER_ORE, 30, 70, 6, 7],
	[Tiles.Block.COAL_ORE, 30, 96, 10, 9],
]

const SIDES: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var _cheese: FastNoiseLite
var _pillars: FastNoiseLite
var _spaghetti_a: FastNoiseLite
var _spaghetti_b: FastNoiseLite
var _fluid: FastNoiseLite
var _decoration_seed := 0
var _ore_seed := 0


func _init(world_seed: int) -> void:
	_cheese = _noise(world_seed, SALT_BASE + 1, 1.0 / 70.0, 3)
	_pillars = _noise(world_seed, SALT_BASE + 2, 1.0 / 9.0, 1)
	_spaghetti_a = _noise(world_seed, SALT_BASE + 3, 1.0 / 90.0, 2)
	_spaghetti_b = _noise(world_seed, SALT_BASE + 4, 1.0 / 110.0, 2)
	_fluid = _noise(world_seed, SALT_BASE + 6, 1.0 / 50.0, 2)
	_decoration_seed = HashUtil.derive_seed(world_seed, SALT_BASE + 50)
	_ore_seed = HashUtil.derive_seed(world_seed, SALT_BASE + 60)


## Rock of a row: stone, or deepslate deep down.
static func rock_at(row: int) -> int:
	return Voxels.of_block(Tiles.Block.DEEPSLATE if row < DEEPSLATE_ROW else Tiles.Block.STONE)


## Carves the caves of a chunk whose terrain is already filled.
func carve(chunk: ChunkData) -> void:
	var origin := Coords.chunk_origin_tile(chunk.coord)
	var voxels := chunk.voxels
	var size := GameConst.CHUNK_SIZE
	var height := GameConst.WORLD_HEIGHT
	# Highest row carved in each column.
	var ceilings := PackedInt32Array()
	ceilings.resize(GameConst.CHUNK_AREA)
	var highest := MIN_ROW - 1
	for column in GameConst.CHUNK_AREA:
		var ceiling := _highest_rock(voxels, column * height, chunk.tops[column]) - ROOF
		ceilings[column] = ceiling
		highest = maxi(highest, ceiling)
	if highest >= MIN_ROW:
		var cheese := _rows(_cheese, origin, CHEESE_STRETCH, highest)
		var pillars := _rows(_pillars, origin, PILLAR_STRETCH, highest)
		var spaghetti_a := _rows(_spaghetti_a, origin, SPAGHETTI_STRETCH, highest)
		var spaghetti_b := _rows(_spaghetti_b, origin, SPAGHETTI_STRETCH, highest)
		var tunnel_low := _byte(-TUNNEL_WIDTH)
		var tunnel_high := _byte(TUNNEL_WIDTH)
		var pillar := _byte(PILLAR_VALUE)
		for y in range(MIN_ROW, highest + 1):
			var chamber := _byte(_cheese_value(y))
			var c: PackedByteArray = cheese[y]
			var p: PackedByteArray = pillars[y]
			var a: PackedByteArray = spaghetti_a[y]
			var b: PackedByteArray = spaghetti_b[y]
			for column in GameConst.CHUNK_AREA:
				if y > ceilings[column]:
					continue
				var open := c[column] > chamber and p[column] < pillar
				if not open:
					var va := a[column]
					var vb := b[column]
					open = va >= tunnel_low and va <= tunnel_high
					open = open and vb >= tunnel_low and vb <= tunnel_high
				if open:
					voxels[column * height + y] = Voxels.AIR
	_place_ores(chunk.coord, voxels)
	_furnish(chunk.coord, voxels, ceilings)
	chunk.voxels = voxels


## True where the cave noises open the rock (whatever the terrain above),
## voxel by voxel: the same as carve(), for a few voxels.
func is_open(tx: int, y: int, tz: int) -> bool:
	var c := _sample(_cheese, tx, tz, y, CHEESE_STRETCH)
	if (
		c > _byte(_cheese_value(y))
		and _sample(_pillars, tx, tz, y, PILLAR_STRETCH) < _byte(PILLAR_VALUE)
	):
		return true
	var low := _byte(-TUNNEL_WIDTH)
	var high := _byte(TUNNEL_WIDTH)
	var a := _sample(_spaghetti_a, tx, tz, y, SPAGHETTI_STRETCH)
	if a < low or a > high:
		return false
	var b := _sample(_spaghetti_b, tx, tz, y, SPAGHETTI_STRETCH)
	return b >= low and b <= high


## Cheese value above which a row opens: chambers grow larger deeper down.
static func _cheese_value(y: int) -> float:
	var depth := clampf(float(GameConst.SEA_LEVEL - y) / GameConst.SEA_LEVEL, 0.0, 1.0)
	return CHEESE_VALUE - depth * CHEESE_DEEP_BONUS


## Byte of a noise value, as Noise.get_image() stores it.
static func _byte(value: float) -> int:
	return clampi(int((value * 0.5 + 0.5) * 255.0), 0, 255)


## One noise value (byte) at a voxel: the same as a row of _rows() gives.
static func _sample(noise: FastNoiseLite, tx: int, tz: int, y: int, stretch: float) -> int:
	return _byte(noise.get_noise_3d(tx, tz, roundi(y * stretch)))


## A noise over the chunk, row by row up to `last`: rows[y] holds the 256
## bytes (z * 16 + x) of row y. One native call samples it all.
static func _rows(
	noise: FastNoiseLite, origin: Vector2i, stretch: float, last: int
) -> Array[PackedByteArray]:
	var first := roundi(MIN_ROW * stretch)
	var count := roundi(last * stretch) - first + 1
	# A copy: the offset must not move under the other threads' feet.
	var local := noise.duplicate() as FastNoiseLite
	local.offset = Vector3(origin.x, origin.y, first)
	var images := local.get_image_3d(
		GameConst.CHUNK_SIZE, GameConst.CHUNK_SIZE, count, false, false
	)
	var slices: Array[PackedByteArray] = []
	for image in images:
		slices.append(image.get_data())
	var rows: Array[PackedByteArray] = []
	rows.resize(last + 1)
	for y in range(MIN_ROW, last + 1):
		rows[y] = slices[roundi(y * stretch) - first]
	return rows


## Highest row of the rock mass of a column, under its terrain (a lone
## outcrop standing on the surface does not count: the rock below it must
## be rock too).
static func _highest_rock(voxels: PackedByteArray, base: int, top: int) -> int:
	var stone := Voxels.of_block(Tiles.Block.STONE)
	var deepslate := Voxels.of_block(Tiles.Block.DEEPSLATE)
	for y in range(top - 1, 0, -1):
		var voxel := voxels[base + y]
		var below := voxels[base + y - 1]
		if (voxel == stone or voxel == deepslate) and (below == stone or below == deepslate):
			return y
	return -1


## Ore veins: short random walks through the rock, the same for a chunk
## whatever the order of generation.
func _place_ores(coord: Vector2i, voxels: PackedByteArray) -> void:
	var size := GameConst.CHUNK_SIZE
	var height := GameConst.WORLD_HEIGHT
	var stone := Voxels.of_block(Tiles.Block.STONE)
	var deepslate := Voxels.of_block(Tiles.Block.DEEPSLATE)
	for i in ORES.size():
		var ore: Array = ORES[i]
		var voxel := Voxels.of_block(ore[0])
		var low: int = ore[1]
		var span: int = ore[2] - low + 1
		var chunk_seed := HashUtil.hash2(_ore_seed + i * 7919, coord.x, coord.y)
		for vein: int in ore[3]:
			var h := HashUtil.hash2(chunk_seed, vein, 0)
			var x := h & 15
			var z := (h >> 4) & 15
			var y := low + (h >> 8) % span
			for step: int in ore[4]:
				var index := (z * size + x) * height + y
				if voxels[index] == stone or voxels[index] == deepslate:
					voxels[index] = voxel
				var move := HashUtil.hash2(chunk_seed, vein, step + 1)
				x = clampi(x + (move % 3) - 1, 0, size - 1)
				y = clampi(y + ((move >> 4) % 3) - 1, low, low + span - 1)
				z = clampi(z + ((move >> 8) % 3) - 1, 0, size - 1)


## Cave floors, lakes, lava pools and the odd mushroom or rock.
func _furnish(coord: Vector2i, voxels: PackedByteArray, ceilings: PackedInt32Array) -> void:
	var size := GameConst.CHUNK_SIZE
	var height := GameConst.WORLD_HEIGHT
	var origin := Coords.chunk_origin_tile(coord)
	var stone := Voxels.of_block(Tiles.Block.STONE)
	var deepslate := Voxels.of_block(Tiles.Block.DEEPSLATE)
	for lz in size:
		for lx in size:
			var tx := origin.x + lx
			var tz := origin.y + lz
			var base := (lz * size + lx) * height
			for y in range(MIN_ROW - 1, ceilings[lz * size + lx]):
				var below := voxels[base + y]
				if (below != stone and below != deepslate) or voxels[base + y + 1] != Voxels.AIR:
					continue
				# Rock under cave air: a floor.
				var fluid := fluid_at(tx, y, tz)
				if (
					fluid != Voxels.AIR
					and y >= MIN_ROW
					and _holds_liquid(voxels, origin, lx, y, lz)
				):
					voxels[base + y] = fluid
					continue
				var deep := y < DEEPSLATE_ROW
				var floor_ground := (
					Tiles.Ground.DEEPSLATE_FLOOR if deep else Tiles.Ground.STONE_FLOOR
				)
				voxels[base + y] = Voxels.of_ground(floor_ground)
				voxels[base + y + 1] = Voxels.of_block(_decoration(tx, y, tz))


## Water near the top of the caves, lava deep down, or air.
func fluid_at(tx: int, y: int, tz: int) -> int:
	var fluid := _fluid.get_noise_2d(tx + y * 131.0, tz - y * 71.0)
	if y >= LAKES_FROM_ROW and fluid > 0.38:
		return Voxels.of_ground(Tiles.Ground.WATER)
	if y < LAVA_BELOW_ROW and fluid < -0.36:
		return Voxels.of_ground(Tiles.Ground.LAVA)
	return Voxels.AIR


## A floor voxel can hold a pool if no side of it opens onto a drop (the
## water does not flow yet). Outside the chunk the noises tell.
func _holds_liquid(voxels: PackedByteArray, origin: Vector2i, lx: int, y: int, lz: int) -> bool:
	var size := GameConst.CHUNK_SIZE
	for side in SIDES:
		var nx := lx + side.x
		var nz := lz + side.y
		if nx < 0 or nz < 0 or nx >= size or nz >= size:
			if is_open(origin.x + nx, y, origin.y + nz):
				return false
		elif voxels[(nz * size + nx) * GameConst.WORLD_HEIGHT + y] == Voxels.AIR:
			return false
	return true


func _decoration(tx: int, y: int, tz: int) -> int:
	var roll := HashUtil.unit2(_decoration_seed + y, tx, tz)
	if y >= LAKES_FROM_ROW and roll < 0.006:
		return Tiles.Block.MUSHROOM_BROWN
	if y >= 44 and roll > 0.996:
		return Tiles.Block.MUSHROOM_RED
	if roll > 0.985 and roll <= 0.996:
		return Tiles.Block.ROCK
	return Tiles.Block.AIR


static func _noise(world_seed: int, salt: int, frequency: float, octaves: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = HashUtil.derive_seed(world_seed, salt) & 0x7FFFFFFF
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	if octaves > 1:
		noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		noise.fractal_octaves = octaves
	else:
		noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	return noise
