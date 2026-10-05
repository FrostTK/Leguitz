class_name SurfaceBuilder
extends RefCounted
## Surface rules (which ground in which biome) and vegetation (which
## plants, trees and rocks stand on it), like Minecraft's surface rules
## and biome features.

const SALT_DECORATION := 30
const SALT_OUTCROPS := 31
const SALT_FLOWER_PATCHES := 32
const SALT_FLOWER_COLORS := 33
## Wild fruit trees and wild rice (their own draws: the rest stays as it
## was).
const SALT_ORCHARDS := 34
const SALT_WILD_RICE := 35

const SNOW_LINE := 78.0
## Voxels of filler (dirt under grass...) between the surface and the rock.
const FILLER_DEPTH := 3
## Mountains above this height get rock outcrops (solid stone and ores).
const OUTCROP_HEIGHT := 42.0

## Plants per biome: [[block, chance per tile], ...], tried in order. Trees
## and other solid objects are then thinned out so they never touch (see
## WorldGenerator._spaced): their chances are higher than what remains. The
## wild plants (WILD_PLANTS, WILD_FRUITS) come last: they only take tiles
## that had nothing before them.
const VEGETATION := {
	Biomes.Id.PLAINS:
	[
		[Tiles.Block.TALL_GRASS, 0.1],
		[Tiles.Block.OAK, 0.008],
		[Tiles.Block.BUSH, 0.006],
		[Tiles.Block.WILD_BEETROOT, 0.004],
		[Tiles.Block.WILD_CABBAGE, 0.003],
		[Tiles.Block.WILD_FLAX, 0.003],
		[Tiles.Block.PUMPKIN, 0.0012],
		[Tiles.Block.BEE_NEST, 0.0008],
	],
	Biomes.Id.SNOWY_PLAINS: [[Tiles.Block.SNOWY_SPRUCE, 0.006], [Tiles.Block.ROCK, 0.002]],
	Biomes.Id.DESERT:
	[[Tiles.Block.CACTUS, 0.006], [Tiles.Block.DEAD_BUSH, 0.01], [Tiles.Block.SANDSTONE, 0.002]],
	Biomes.Id.SWAMP:
	[
		[Tiles.Block.SWAMP_OAK, 0.09],
		[Tiles.Block.TALL_GRASS, 0.08],
		[Tiles.Block.FERN, 0.03],
		[Tiles.Block.MUSHROOM_BROWN, 0.01],
		[Tiles.Block.MUSHROOM_RED, 0.006],
	],
	Biomes.Id.FOREST:
	[
		[Tiles.Block.OAK, 0.3],
		[Tiles.Block.BIRCH, 0.06],
		[Tiles.Block.TALL_GRASS, 0.07],
		[Tiles.Block.BUSH, 0.02],
		[Tiles.Block.FERN, 0.01],
		[Tiles.Block.MUSHROOM_BROWN, 0.004],
		[Tiles.Block.WILD_STRAWBERRY, 0.008],
		[Tiles.Block.WILD_GRAPES, 0.002],
		[Tiles.Block.PUMPKIN, 0.001],
		[Tiles.Block.WILD_RASPBERRY, 0.004],
	],
	Biomes.Id.FLOWER_FOREST:
	[
		[Tiles.Block.OAK, 0.12],
		[Tiles.Block.BIRCH, 0.05],
		[Tiles.Block.TALL_GRASS, 0.05],
		[Tiles.Block.WILD_STRAWBERRY, 0.012],
		[Tiles.Block.WILD_GRAPES, 0.004],
		[Tiles.Block.BEE_NEST, 0.004],
	],
	Biomes.Id.BIRCH_FOREST:
	[
		[Tiles.Block.BIRCH, 0.34],
		[Tiles.Block.TALL_GRASS, 0.06],
		[Tiles.Block.BUSH, 0.01],
		[Tiles.Block.WILD_STRAWBERRY, 0.01],
		[Tiles.Block.WILD_RASPBERRY, 0.006],
	],
	Biomes.Id.DARK_FOREST:
	[
		[Tiles.Block.DARK_OAK, 0.55],
		[Tiles.Block.BIG_MUSHROOM, 0.012],
		[Tiles.Block.MUSHROOM_RED, 0.01],
		[Tiles.Block.MUSHROOM_BROWN, 0.012],
		[Tiles.Block.FERN, 0.03],
	],
	Biomes.Id.TAIGA:
	[
		[Tiles.Block.SPRUCE, 0.3],
		[Tiles.Block.FERN, 0.08],
		[Tiles.Block.BERRY_BUSH, 0.012],
		[Tiles.Block.ROCK, 0.004],
		[Tiles.Block.PUMPKIN, 0.002],
		[Tiles.Block.WILD_RASPBERRY, 0.006],
	],
	Biomes.Id.SNOWY_TAIGA: [[Tiles.Block.SNOWY_SPRUCE, 0.26], [Tiles.Block.FERN, 0.02]],
	Biomes.Id.OLD_GROWTH_TAIGA:
	[
		[Tiles.Block.SPRUCE, 0.42],
		[Tiles.Block.FERN, 0.1],
		[Tiles.Block.MOSSY_ROCK, 0.012],
		[Tiles.Block.MUSHROOM_BROWN, 0.008],
		[Tiles.Block.BERRY_BUSH, 0.008],
		[Tiles.Block.WILD_RASPBERRY, 0.008],
	],
	Biomes.Id.SAVANNA:
	[
		[Tiles.Block.ACACIA, 0.02],
		[Tiles.Block.TALL_GRASS, 0.2],
		[Tiles.Block.BUSH, 0.004],
		[Tiles.Block.WILD_CORN, 0.008],
		[Tiles.Block.MELON, 0.002],
	],
	Biomes.Id.SAVANNA_PLATEAU:
	[
		[Tiles.Block.ACACIA, 0.025],
		[Tiles.Block.TALL_GRASS, 0.15],
		[Tiles.Block.WILD_CORN, 0.006],
	],
	Biomes.Id.JUNGLE:
	[
		[Tiles.Block.JUNGLE_TREE, 0.5],
		[Tiles.Block.BUSH, 0.08],
		[Tiles.Block.FERN, 0.08],
		[Tiles.Block.TALL_GRASS, 0.05],
		[Tiles.Block.MELON, 0.004],
		[Tiles.Block.WILD_TOMATO, 0.004],
	],
	Biomes.Id.SPARSE_JUNGLE:
	[
		[Tiles.Block.JUNGLE_TREE, 0.12],
		[Tiles.Block.BUSH, 0.05],
		[Tiles.Block.TALL_GRASS, 0.1],
		[Tiles.Block.WILD_TOMATO, 0.01],
		[Tiles.Block.MELON, 0.004],
		[Tiles.Block.WILD_GRAPES, 0.003],
	],
	Biomes.Id.BADLANDS: [[Tiles.Block.DEAD_BUSH, 0.012], [Tiles.Block.CACTUS, 0.004]],
	Biomes.Id.MEADOW:
	[
		[Tiles.Block.TALL_GRASS, 0.2],
		[Tiles.Block.BIRCH, 0.004],
		[Tiles.Block.OAK, 0.002],
		[Tiles.Block.WILD_FLAX, 0.012],
		[Tiles.Block.WILD_BEETROOT, 0.004],
		[Tiles.Block.BEE_NEST, 0.003],
	],
	Biomes.Id.BEACH: [[Tiles.Block.WILD_CABBAGE, 0.006]],
	Biomes.Id.GROVE: [[Tiles.Block.SNOWY_SPRUCE, 0.22]],
	Biomes.Id.SNOWY_SLOPES: [[Tiles.Block.ROCK, 0.004]],
	Biomes.Id.FROZEN_PEAKS: [[Tiles.Block.PACKED_ICE, 0.01]],
	Biomes.Id.STONY_PEAKS: [[Tiles.Block.ROCK, 0.01]],
	Biomes.Id.STONY_SHORE: [[Tiles.Block.ROCK, 0.02]],
	Biomes.Id.MUSHROOM_FIELDS:
	[
		[Tiles.Block.BIG_MUSHROOM, 0.03],
		[Tiles.Block.MUSHROOM_RED, 0.03],
		[Tiles.Block.MUSHROOM_BROWN, 0.03],
	],
}

## The wild plants (they never stand for the undergrowth under a tree
## thinned out) and the wild fruits and bee nests (solid: kept only with no
## solid object around them, WorldGenerator._spaced).
const WILD_PLANTS := {
	Tiles.Block.WILD_BEETROOT: true,
	Tiles.Block.WILD_CABBAGE: true,
	Tiles.Block.WILD_CORN: true,
	Tiles.Block.WILD_TOMATO: true,
	Tiles.Block.WILD_STRAWBERRY: true,
	Tiles.Block.WILD_FLAX: true,
	Tiles.Block.WILD_RICE: true,
	Tiles.Block.WILD_GRAPES: true,
	Tiles.Block.WILD_RASPBERRY: true,
}
const WILD_FRUITS := {
	Tiles.Block.PUMPKIN: true, Tiles.Block.MELON: true, Tiles.Block.BEE_NEST: true
}
## Wild rice on the water: chance per tile.
const WILD_RICE := {Biomes.Id.SWAMP: 0.03, Biomes.Id.RIVER: 0.006}
## Wild fruit trees: [the tree they stand for, the fruit tree, chance],
## per biome (the chances of one tree add up). Half of them come in blossom
## (they grow their fruit: WorldGenerator notes them), half bearing fruit.
const ORCHARDS := {
	Biomes.Id.PLAINS:
	[
		[Tiles.Block.OAK, Tiles.Block.APPLE_TREE, 0.3],
		[Tiles.Block.OAK, Tiles.Block.PEACH_TREE, 0.15],
	],
	Biomes.Id.FOREST: [[Tiles.Block.OAK, Tiles.Block.APPLE_TREE, 0.04]],
	Biomes.Id.FLOWER_FOREST:
	[
		[Tiles.Block.OAK, Tiles.Block.APPLE_TREE, 0.1],
		[Tiles.Block.BIRCH, Tiles.Block.CHERRY_TREE, 0.35],
		[Tiles.Block.OAK, Tiles.Block.PEACH_TREE, 0.08],
	],
	Biomes.Id.BIRCH_FOREST: [[Tiles.Block.BIRCH, Tiles.Block.CHERRY_TREE, 0.03]],
	Biomes.Id.MEADOW:
	[
		[Tiles.Block.OAK, Tiles.Block.APPLE_TREE, 0.5],
		[Tiles.Block.BIRCH, Tiles.Block.CHERRY_TREE, 0.5],
	],
	Biomes.Id.SAVANNA:
	[
		[Tiles.Block.ACACIA, Tiles.Block.ORANGE_TREE, 0.15],
		[Tiles.Block.ACACIA, Tiles.Block.PEACH_TREE, 0.08],
	],
	Biomes.Id.SAVANNA_PLATEAU: [[Tiles.Block.ACACIA, Tiles.Block.ORANGE_TREE, 0.1]],
	Biomes.Id.SPARSE_JUNGLE: [[Tiles.Block.JUNGLE_TREE, Tiles.Block.ORANGE_TREE, 0.12]],
}

## Chance of a flower on a tile inside a flower patch.
const FLOWER_DENSITY := {
	Biomes.Id.PLAINS: 0.18,
	Biomes.Id.FOREST: 0.08,
	Biomes.Id.FLOWER_FOREST: 0.4,
	Biomes.Id.BIRCH_FOREST: 0.1,
	Biomes.Id.MEADOW: 0.35,
	Biomes.Id.SAVANNA: 0.04,
	Biomes.Id.SWAMP: 0.05,
	Biomes.Id.SPARSE_JUNGLE: 0.08,
}

## Biomes covered by a single ground.
const SIMPLE_GROUND := {
	Biomes.Id.BEACH: Tiles.Ground.SAND,
	Biomes.Id.DESERT: Tiles.Ground.SAND,
	Biomes.Id.SNOWY_BEACH: Tiles.Ground.SNOW,
	Biomes.Id.SNOWY_PLAINS: Tiles.Ground.SNOW,
	Biomes.Id.SNOWY_TAIGA: Tiles.Ground.SNOW,
	Biomes.Id.FOREST: Tiles.Ground.FOREST_GRASS,
	Biomes.Id.MEADOW: Tiles.Ground.MEADOW_GRASS,
	Biomes.Id.MUSHROOM_FIELDS: Tiles.Ground.MYCELIUM,
}

## Biomes with patches: [base ground, patch ground, detail threshold,
## patch above the threshold (true) or below it (false)].
const PATCHY_GROUND := {
	Biomes.Id.GROVE: [Tiles.Ground.SNOW, Tiles.Ground.STONE_FLOOR, -0.45, false],
	Biomes.Id.SNOWY_SLOPES: [Tiles.Ground.SNOW, Tiles.Ground.STONE_FLOOR, -0.45, false],
	Biomes.Id.JAGGED_PEAKS: [Tiles.Ground.SNOW, Tiles.Ground.STONE_FLOOR, -0.45, false],
	Biomes.Id.FROZEN_PEAKS: [Tiles.Ground.SNOW, Tiles.Ground.ICE, 0.3, true],
	Biomes.Id.STONY_PEAKS: [Tiles.Ground.STONE_FLOOR, Tiles.Ground.GRAVEL, 0.35, true],
	Biomes.Id.STONY_SHORE: [Tiles.Ground.STONE_FLOOR, Tiles.Ground.GRAVEL, 0.1, true],
	Biomes.Id.DARK_FOREST: [Tiles.Ground.FOREST_GRASS, Tiles.Ground.PODZOL, 0.3, true],
	Biomes.Id.TAIGA: [Tiles.Ground.TAIGA_GRASS, Tiles.Ground.PODZOL, 0.25, true],
	Biomes.Id.OLD_GROWTH_TAIGA: [Tiles.Ground.PODZOL, Tiles.Ground.TAIGA_GRASS, 0.3, true],
	Biomes.Id.SAVANNA: [Tiles.Ground.DRY_GRASS, Tiles.Ground.DIRT, 0.45, true],
	Biomes.Id.SAVANNA_PLATEAU: [Tiles.Ground.DRY_GRASS, Tiles.Ground.DIRT, 0.45, true],
	Biomes.Id.JUNGLE: [Tiles.Ground.JUNGLE_GRASS, Tiles.Ground.MUD, 0.55, true],
	Biomes.Id.SPARSE_JUNGLE: [Tiles.Ground.JUNGLE_GRASS, Tiles.Ground.MUD, 0.55, true],
	Biomes.Id.RIVER: [Tiles.Ground.SAND, Tiles.Ground.GRAVEL, 0.2, true],
	Biomes.Id.FROZEN_RIVER: [Tiles.Ground.SAND, Tiles.Ground.GRAVEL, 0.2, true],
}

## Filler under each surface ground (dirt by default).
const FILLERS := {
	Tiles.Ground.SAND: Tiles.Ground.SAND,
	Tiles.Ground.STONE_FLOOR: Tiles.Ground.STONE_FLOOR,
	Tiles.Ground.GRAVEL: Tiles.Ground.GRAVEL,
	Tiles.Ground.DEEPSLATE_FLOOR: Tiles.Ground.DEEPSLATE_FLOOR,
	Tiles.Ground.MUD: Tiles.Ground.MUD,
	Tiles.Ground.SWAMP_WATER: Tiles.Ground.MUD,
	Tiles.Ground.ICE: Tiles.Ground.ICE,
}
## Badlands grounds: their filler shows the colored strata of their rows.
const STRATA := {
	Tiles.Ground.RED_SAND: true,
	Tiles.Ground.TERRACOTTA: true,
	Tiles.Ground.TERRACOTTA_LIGHT: true,
}

## Biomes where sugar cane grows next to water.
const SUGAR_CANE_BIOMES := {
	Biomes.Id.PLAINS: true,
	Biomes.Id.BEACH: true,
	Biomes.Id.DESERT: true,
	Biomes.Id.SWAMP: true,
	Biomes.Id.FOREST: true,
	Biomes.Id.JUNGLE: true,
	Biomes.Id.SPARSE_JUNGLE: true,
	Biomes.Id.SAVANNA: true,
	Biomes.Id.RIVER: true,
}

var _decoration_seed := 0
var _flower_color_seed := 0
var _orchard_seed := 0
var _wild_rice_seed := 0
var _outcrops: FastNoiseLite
var _flower_patches: FastNoiseLite


func _init(world_seed: int) -> void:
	_decoration_seed = HashUtil.derive_seed(world_seed, SALT_DECORATION)
	_flower_color_seed = HashUtil.derive_seed(world_seed, SALT_FLOWER_COLORS)
	_orchard_seed = HashUtil.derive_seed(world_seed, SALT_ORCHARDS)
	_wild_rice_seed = HashUtil.derive_seed(world_seed, SALT_WILD_RICE)
	_outcrops = ClimateSampler.make_fbm(world_seed, SALT_OUTCROPS, 1.0 / 22.0, 1, 0.0)
	_flower_patches = ClimateSampler.make_fbm(world_seed, SALT_FLOWER_PATCHES, 1.0 / 28.0, 2, 0.0)


## Ground tile of a surface column. `detail` is the fine terrain noise.
func ground_for(biome: int, h: float, level: int, detail: float, water: bool) -> int:
	if water:
		return _water_ground(biome, h, detail)
	if h > SNOW_LINE and not biome in [Biomes.Id.STONY_PEAKS, Biomes.Id.BADLANDS]:
		return Tiles.Ground.SNOW
	if SIMPLE_GROUND.has(biome):
		return SIMPLE_GROUND[biome]
	if PATCHY_GROUND.has(biome):
		var rule: Array = PATCHY_GROUND[biome]
		var in_patch: bool = detail > rule[2] if rule[3] else detail < rule[2]
		return rule[1] if in_patch else rule[0]
	match biome:
		Biomes.Id.SWAMP:
			if detail < -0.3:
				return Tiles.Ground.SWAMP_WATER
			return Tiles.Ground.MUD if detail > 0.35 else Tiles.Ground.SWAMP_GRASS
		Biomes.Id.BADLANDS:
			return _badlands_ground(h, level)
	if h > OUTCROP_HEIGHT + 10.0 and detail < -0.4:
		return Tiles.Ground.STONE_FLOOR
	return Tiles.Ground.GRASS


## Voxel of filler at a row under a surface ground (`h`: terrain height).
func filler_for(ground: int, h: float, row: int) -> int:
	if STRATA.has(ground):
		return Voxels.of_ground(_badlands_ground(h, row - GameConst.SEA_LEVEL + 1))
	return Voxels.of_ground(FILLERS.get(ground, Tiles.Ground.DIRT))


## Voxel of the bed under water.
func bed_for(biome: int, detail: float) -> int:
	match biome:
		Biomes.Id.SWAMP:
			return Voxels.of_ground(Tiles.Ground.MUD)
		Biomes.Id.RIVER, Biomes.Id.FROZEN_RIVER, Biomes.Id.STONY_SHORE:
			return Voxels.of_ground(Tiles.Ground.GRAVEL if detail > 0.2 else Tiles.Ground.SAND)
		Biomes.Id.DEEP_OCEAN:
			return Voxels.of_ground(Tiles.Ground.GRAVEL)
	return Voxels.of_ground(Tiles.Ground.SAND)


## Block standing on a surface tile (air, plant, tree, rock, ore...).
func block_for(
	biome: int, ground: int, h: float, erosion: float, tx: int, ty: int, near_water: bool
) -> int:
	if Tiles.is_water(ground):
		return _water_block(biome, tx, ty)
	if ground == Tiles.Ground.ICE:
		return Tiles.Block.AIR
	var outcrop := _outcrop_block(biome, h, erosion, tx, ty)
	if outcrop != Tiles.Block.AIR:
		return outcrop
	var roll := HashUtil.unit2(_decoration_seed, tx, ty)
	if near_water and SUGAR_CANE_BIOMES.has(biome) and roll > 0.88:
		return Tiles.Block.SUGAR_CANE
	var flowers: float = FLOWER_DENSITY.get(biome, 0.0)
	if flowers > 0.0 and _flower_patches.get_noise_2d(tx, ty) > 0.18:
		var flower_roll := HashUtil.unit2(_decoration_seed ^ 0x5F3759DF, tx, ty)
		if flower_roll < flowers:
			return _flower_color(tx, ty)
	var cumulative := 0.0
	for entry: Array in VEGETATION.get(biome, []):
		cumulative += entry[1]
		if roll < cumulative:
			return entry[0]
	return Tiles.Block.AIR


## What grows on a tile where a tree was thinned out: the biome's small
## plants (grass, ferns, bushes...), or nothing.
func undergrowth_for(biome: int, tx: int, ty: int) -> int:
	var plants: Array[int] = []
	for entry: Array in VEGETATION.get(biome, []):
		if not Tiles.is_block_solid(entry[0]) and not WILD_PLANTS.has(entry[0]):
			plants.append(entry[0])
	var roll := HashUtil.unit2(_decoration_seed ^ 0x3C6EF372, tx, ty)
	if plants.is_empty() or roll > 0.5:
		return Tiles.Block.AIR
	return plants[int(roll * 2.0 * plants.size()) % plants.size()]


## The tree standing on a tile once spaced (WorldGenerator._spaced): now
## and then a wild fruit tree instead of one of the biome's (ORCHARDS), in
## blossom or bearing fruit.
func orchard_tree(biome: int, tree: int, tx: int, ty: int) -> int:
	var roll := HashUtil.unit2(_orchard_seed, tx, ty)
	var chance := 0.0
	for entry: Array in ORCHARDS.get(biome, []):
		if entry[0] != tree:
			continue
		chance += entry[2]
		if roll < chance:
			var bearing := HashUtil.unit2(_orchard_seed ^ 0x5EED, tx, ty) < 0.5
			return Growth.FRUITING[entry[1]] if bearing else entry[1]
	return tree


## A wild bee nest's honey (0 to Apiary.FULL), by its tile.
func nest_honey(tx: int, ty: int) -> int:
	return int(HashUtil.unit2(_orchard_seed ^ 0xB33, tx, ty) * (Apiary.FULL + 1))


## Mountain rock: solid stone patches with visible ore veins.
func _outcrop_block(biome: int, h: float, erosion: float, tx: int, ty: int) -> int:
	var mountain := biome in [Biomes.Id.JAGGED_PEAKS, Biomes.Id.FROZEN_PEAKS, Biomes.Id.STONY_PEAKS]
	if h < OUTCROP_HEIGHT and not mountain:
		return Tiles.Block.AIR
	if erosion > 0.1 and not mountain:
		return Tiles.Block.AIR
	var threshold := lerpf(0.42, 0.12, smoothstep(OUTCROP_HEIGHT, 110.0, h))
	if _outcrops.get_noise_2d(tx, ty) < threshold:
		return Tiles.Block.AIR
	var roll := HashUtil.unit2(_decoration_seed ^ 0x1234567, tx, ty)
	if h > 70.0 and roll < 0.012:
		return Tiles.Block.EMERALD_ORE
	if roll < 0.05:
		return Tiles.Block.IRON_ORE
	if roll < 0.08:
		return Tiles.Block.COPPER_ORE
	if roll < 0.15:
		return Tiles.Block.COAL_ORE
	return Tiles.Block.STONE


func _flower_color(tx: int, ty: int) -> int:
	# One dominant color per 12x12 area, with some mixing.
	var cell := HashUtil.hash2(_flower_color_seed, floori(tx / 12.0), floori(ty / 12.0))
	var mix := HashUtil.unit2(_flower_color_seed + 1, tx, ty)
	var index := cell % Tiles.FLOWERS.size()
	if mix > 0.8:
		index = (index + 1 + int(mix * 10.0)) % Tiles.FLOWERS.size()
	return Tiles.FLOWERS[index]


func _water_ground(biome: int, h: float, detail: float) -> int:
	match biome:
		Biomes.Id.FROZEN_OCEAN:
			return Tiles.Ground.ICE if detail > -0.25 else Tiles.Ground.WATER
		Biomes.Id.FROZEN_RIVER:
			return Tiles.Ground.ICE
		Biomes.Id.WARM_OCEAN:
			return Tiles.Ground.WARM_WATER
		Biomes.Id.SWAMP:
			return Tiles.Ground.SWAMP_WATER
	return Tiles.Ground.DEEP_WATER if h < Biomes.DEEP_OCEAN_HEIGHT else Tiles.Ground.WATER


func _water_block(biome: int, tx: int, ty: int) -> int:
	var chance := 0.0
	match biome:
		Biomes.Id.SWAMP:
			chance = 0.1
		Biomes.Id.RIVER:
			chance = 0.015
	if chance > 0.0 and HashUtil.unit2(_decoration_seed ^ 0x2468ACE, tx, ty) < chance:
		return Tiles.Block.LILY_PAD
	if HashUtil.unit2(_wild_rice_seed, tx, ty) < WILD_RICE.get(biome, 0.0):
		return Tiles.Block.WILD_RICE
	return Tiles.Block.AIR


static func _badlands_ground(h: float, level: int) -> int:
	if h < 8.0:
		return Tiles.Ground.RED_SAND
	match level % 3:
		0:
			return Tiles.Ground.TERRACOTTA
		1:
			return Tiles.Ground.TERRACOTTA_LIGHT
	return Tiles.Ground.RED_SAND
