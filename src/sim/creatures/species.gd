class_name Species
extends RefCounted
## The kinds of animals (and later monsters): their size, strength, pace,
## where they live and what they give. Ids are saved with the animals:
## only append to the enum, never renumber.

enum Id { SHEEP, BOAR, CHICKEN, DEER }

## Name keys (i18n), and where each lives in a word (the book).
const NAME_KEYS := {
	Id.SHEEP: "CREATURE_SHEEP",
	Id.BOAR: "CREATURE_BOAR",
	Id.CHICKEN: "CREATURE_CHICKEN",
	Id.DEER: "CREATURE_DEER",
}
const HOME_KEYS := {
	Id.SHEEP: "CREATURE_SHEEP_HOME",
	Id.BOAR: "CREATURE_BOAR_HOME",
	Id.CHICKEN: "CREATURE_CHICKEN_HOME",
	Id.DEER: "CREATURE_DEER_HOME",
}
## The body's box at the feet (world pixels, like PlayerBody.BOX) and its
## height (levels).
const BOX := {
	Id.SHEEP: Vector2(12.0, 12.0),
	Id.BOAR: Vector2(12.0, 12.0),
	Id.CHICKEN: Vector2(7.0, 7.0),
	Id.DEER: Vector2(11.0, 11.0),
}
const TALL := {
	Id.SHEEP: 1.1,
	Id.BOAR: 0.9,
	Id.CHICKEN: 0.7,
	Id.DEER: 1.5,
}
## Vitality (the player's points: a bare hand takes 1).
const HEALTH := {
	Id.SHEEP: 8,
	Id.BOAR: 10,
	Id.CHICKEN: 4,
	Id.DEER: 10,
}
## Tiles per second: wandering, and running away.
const WALK_SPEED := {
	Id.SHEEP: 1.3,
	Id.BOAR: 1.4,
	Id.CHICKEN: 1.2,
	Id.DEER: 1.6,
}
const FLEE_SPEED := {
	Id.SHEEP: 3.4,
	Id.BOAR: 3.8,
	Id.CHICKEN: 3.6,
	Id.DEER: 5.2,
}
## What each gives when it dies: [item, fewest, most].
const DROPS := {
	Id.SHEEP: [[Items.Id.WOOL, 1, 2], [Items.Id.RAW_MUTTON, 1, 2]],
	Id.BOAR: [[Items.Id.RAW_PORK, 1, 3], [Items.Id.HIDE, 0, 1]],
	Id.CHICKEN: [[Items.Id.RAW_CHICKEN, 1, 1], [Items.Id.FEATHER, 0, 2]],
	Id.DEER: [[Items.Id.RAW_VENISON, 1, 2], [Items.Id.HIDE, 0, 1]],
}
## Where herds are found, and how many in one.
const BIOMES := {
	Id.SHEEP: [Biomes.Id.PLAINS, Biomes.Id.MEADOW, Biomes.Id.SNOWY_PLAINS, Biomes.Id.GROVE],
	Id.BOAR: [Biomes.Id.FOREST, Biomes.Id.DARK_FOREST, Biomes.Id.OLD_GROWTH_TAIGA, Biomes.Id.SWAMP],
	Id.CHICKEN:
	[
		Biomes.Id.PLAINS,
		Biomes.Id.SAVANNA,
		Biomes.Id.JUNGLE,
		Biomes.Id.SPARSE_JUNGLE,
		Biomes.Id.FLOWER_FOREST,
	],
	Id.DEER:
	[
		Biomes.Id.FOREST,
		Biomes.Id.BIRCH_FOREST,
		Biomes.Id.FLOWER_FOREST,
		Biomes.Id.TAIGA,
		Biomes.Id.SNOWY_TAIGA,
		Biomes.Id.OLD_GROWTH_TAIGA,
		Biomes.Id.MEADOW,
	],
}
const HERD := {
	Id.SHEEP: Vector2i(2, 4),
	Id.BOAR: Vector2i(2, 3),
	Id.CHICKEN: Vector2i(2, 4),
	Id.DEER: Vector2i(1, 3),
}


static func is_valid(kind: int) -> bool:
	return kind >= 0 and kind < Id.size()


## The species living in a biome.
static func living_in(biome: int) -> Array[int]:
	var result: Array[int] = []
	for kind: int in BIOMES:
		if biome in BIOMES[kind]:
			result.append(kind)
	return result
