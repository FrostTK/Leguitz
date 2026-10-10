class_name Species
extends RefCounted
## The kinds of creatures, animals and monsters: their size, strength, pace,
## where they live and what they give; the monsters' blows. Ids are saved
## with the animals: only append to the enum, never renumber.

enum Id {
	SHEEP,
	BOAR,
	CHICKEN,
	DEER,
	LANTERN_MOTH,
	SHADE_LURKER,
	ROCK_MIMIC,
	WISP,
	COW,
	GOAT,
	DUCK,
	RABBIT,
	PIG,
	BEE,
	WOLF,
	BEAR,
	FROG,
	TURTLE,
	BEAVER,
	FISH,
	MOLE,
	CROW,
	LANTERN_BUMBLEBEE,
	DOG,
	CAT,
}

## The monsters (Monster), those that fly, and the animals that swim
## (their ways go over water: Pathfinder). Predators (Predator: wolves and
## bears) hunt what PREY lists and, provoked or at night, players; fish
## live under water (Fish); pests come to players' fields (Pests: the mole,
## the crow, the lantern bumblebee); companions (Companion: the dog, a
## tamed wolf, and the cat) follow their player.
const MONSTERS := {Id.LANTERN_MOTH: true, Id.SHADE_LURKER: true, Id.ROCK_MIMIC: true, Id.WISP: true}
const FLIERS := {
	Id.LANTERN_MOTH: true,
	Id.WISP: true,
	Id.BEE: true,
	Id.CROW: true,
	Id.LANTERN_BUMBLEBEE: true,
}
const SWIMMERS := {Id.DUCK: true, Id.FROG: true, Id.TURTLE: true, Id.BEAVER: true}
const PREDATORS := {Id.WOLF: true, Id.BEAR: true}
const PREY := {
	Id.RABBIT: true,
	Id.CHICKEN: true,
	Id.SHEEP: true,
	Id.DEER: true,
	Id.DUCK: true,
	Id.GOAT: true,
	Id.PIG: true,
}
const AQUATIC := {Id.FISH: true}
const PESTS := {Id.MOLE: true, Id.CROW: true, Id.LANTERN_BUMBLEBEE: true}
const COMPANIONS := {Id.DOG: true, Id.CAT: true}

## Name keys (i18n), and where each lives in a word (the book).
const NAME_KEYS := {
	Id.SHEEP: "CREATURE_SHEEP",
	Id.BOAR: "CREATURE_BOAR",
	Id.CHICKEN: "CREATURE_CHICKEN",
	Id.DEER: "CREATURE_DEER",
	Id.LANTERN_MOTH: "CREATURE_LANTERN_MOTH",
	Id.SHADE_LURKER: "CREATURE_SHADE_LURKER",
	Id.ROCK_MIMIC: "CREATURE_ROCK_MIMIC",
	Id.WISP: "CREATURE_WISP",
	Id.COW: "CREATURE_COW",
	Id.GOAT: "CREATURE_GOAT",
	Id.DUCK: "CREATURE_DUCK",
	Id.RABBIT: "CREATURE_RABBIT",
	Id.PIG: "CREATURE_PIG",
	Id.BEE: "CREATURE_BEE",
	Id.WOLF: "CREATURE_WOLF",
	Id.BEAR: "CREATURE_BEAR",
	Id.FROG: "CREATURE_FROG",
	Id.TURTLE: "CREATURE_TURTLE",
	Id.BEAVER: "CREATURE_BEAVER",
	Id.FISH: "CREATURE_FISH",
	Id.MOLE: "CREATURE_MOLE",
	Id.CROW: "CREATURE_CROW",
	Id.LANTERN_BUMBLEBEE: "CREATURE_LANTERN_BUMBLEBEE",
	Id.DOG: "CREATURE_DOG",
	Id.CAT: "CREATURE_CAT",
}
## Monsters: how they hunt, in words (the book).
const HOW_KEYS := {
	Id.LANTERN_MOTH: "CREATURE_LANTERN_MOTH_HOW",
	Id.SHADE_LURKER: "CREATURE_SHADE_LURKER_HOW",
	Id.ROCK_MIMIC: "CREATURE_ROCK_MIMIC_HOW",
	Id.WISP: "CREATURE_WISP_HOW",
}
const HOME_KEYS := {
	Id.SHEEP: "CREATURE_SHEEP_HOME",
	Id.BOAR: "CREATURE_BOAR_HOME",
	Id.CHICKEN: "CREATURE_CHICKEN_HOME",
	Id.DEER: "CREATURE_DEER_HOME",
	Id.LANTERN_MOTH: "CREATURE_LANTERN_MOTH_HOME",
	Id.SHADE_LURKER: "CREATURE_SHADE_LURKER_HOME",
	Id.ROCK_MIMIC: "CREATURE_ROCK_MIMIC_HOME",
	Id.WISP: "CREATURE_WISP_HOME",
	Id.COW: "CREATURE_COW_HOME",
	Id.GOAT: "CREATURE_GOAT_HOME",
	Id.DUCK: "CREATURE_DUCK_HOME",
	Id.RABBIT: "CREATURE_RABBIT_HOME",
	Id.PIG: "CREATURE_PIG_HOME",
	Id.BEE: "CREATURE_BEE_HOME",
	Id.WOLF: "CREATURE_WOLF_HOME",
	Id.BEAR: "CREATURE_BEAR_HOME",
	Id.FROG: "CREATURE_FROG_HOME",
	Id.TURTLE: "CREATURE_TURTLE_HOME",
	Id.BEAVER: "CREATURE_BEAVER_HOME",
	Id.FISH: "CREATURE_FISH_HOME",
	Id.MOLE: "CREATURE_MOLE_HOME",
	Id.CROW: "CREATURE_CROW_HOME",
	Id.LANTERN_BUMBLEBEE: "CREATURE_LANTERN_BUMBLEBEE_HOME",
	Id.DOG: "CREATURE_DOG_HOME",
	Id.CAT: "CREATURE_CAT_HOME",
}
## The body's box at the feet (world pixels, like PlayerBody.BOX) and its
## height (levels).
const BOX := {
	Id.SHEEP: Vector2(12.0, 12.0),
	Id.BOAR: Vector2(12.0, 12.0),
	Id.CHICKEN: Vector2(7.0, 7.0),
	Id.DEER: Vector2(11.0, 11.0),
	Id.LANTERN_MOTH: Vector2(10.0, 10.0),
	Id.SHADE_LURKER: Vector2(10.0, 8.0),
	Id.ROCK_MIMIC: Vector2(13.0, 13.0),
	Id.WISP: Vector2(6.0, 6.0),
	Id.COW: Vector2(13.0, 13.0),
	Id.GOAT: Vector2(10.0, 10.0),
	Id.DUCK: Vector2(7.0, 7.0),
	Id.RABBIT: Vector2(6.0, 6.0),
	Id.PIG: Vector2(12.0, 12.0),
	Id.BEE: Vector2(4.0, 4.0),
	Id.WOLF: Vector2(10.0, 10.0),
	Id.BEAR: Vector2(15.0, 15.0),
	Id.FROG: Vector2(6.0, 6.0),
	Id.TURTLE: Vector2(10.0, 10.0),
	Id.BEAVER: Vector2(9.0, 9.0),
	Id.FISH: Vector2(6.0, 6.0),
	Id.MOLE: Vector2(7.0, 7.0),
	Id.CROW: Vector2(7.0, 7.0),
	Id.LANTERN_BUMBLEBEE: Vector2(6.0, 6.0),
	Id.DOG: Vector2(9.0, 9.0),
	Id.CAT: Vector2(6.0, 6.0),
}
const TALL := {
	Id.SHEEP: 1.1,
	Id.BOAR: 0.9,
	Id.CHICKEN: 0.7,
	Id.DEER: 1.5,
	Id.LANTERN_MOTH: 0.6,
	Id.SHADE_LURKER: 1.8,
	Id.ROCK_MIMIC: 0.9,
	Id.WISP: 0.5,
	Id.COW: 1.3,
	Id.GOAT: 1.1,
	Id.DUCK: 0.6,
	Id.RABBIT: 0.55,
	Id.PIG: 0.9,
	Id.BEE: 0.35,
	Id.WOLF: 0.95,
	Id.BEAR: 1.4,
	Id.FROG: 0.4,
	Id.TURTLE: 0.45,
	Id.BEAVER: 0.6,
	Id.FISH: 0.3,
	Id.MOLE: 0.4,
	Id.CROW: 0.55,
	Id.LANTERN_BUMBLEBEE: 0.45,
	Id.DOG: 0.9,
	Id.CAT: 0.6,
}
## Vitality (the player's points: a bare hand takes 1).
const HEALTH := {
	Id.SHEEP: 8,
	Id.BOAR: 10,
	Id.CHICKEN: 4,
	Id.DEER: 10,
	Id.LANTERN_MOTH: 6,
	Id.SHADE_LURKER: 16,
	Id.ROCK_MIMIC: 20,
	Id.WISP: 6,
	Id.COW: 10,
	Id.GOAT: 8,
	Id.DUCK: 4,
	Id.RABBIT: 3,
	Id.PIG: 10,
	Id.BEE: 2,
	Id.WOLF: 10,
	Id.BEAR: 24,
	Id.FROG: 3,
	Id.TURTLE: 10,
	Id.BEAVER: 6,
	Id.FISH: 2,
	Id.MOLE: 3,
	Id.CROW: 3,
	Id.LANTERN_BUMBLEBEE: 2,
	Id.DOG: 14,
	Id.CAT: 8,
}
## Tiles per second: wandering, and running away (monsters: drawing back).
const WALK_SPEED := {
	Id.SHEEP: 1.3,
	Id.BOAR: 1.4,
	Id.CHICKEN: 1.2,
	Id.DEER: 1.6,
	Id.LANTERN_MOTH: 2.0,
	Id.SHADE_LURKER: 1.0,
	Id.ROCK_MIMIC: 1.0,
	Id.WISP: 1.2,
	Id.COW: 1.1,
	Id.GOAT: 1.4,
	Id.DUCK: 1.0,
	Id.RABBIT: 1.6,
	Id.PIG: 1.2,
	Id.BEE: 1.8,
	Id.WOLF: 1.6,
	Id.BEAR: 1.1,
	Id.FROG: 1.2,
	Id.TURTLE: 0.5,
	Id.BEAVER: 1.0,
	Id.FISH: 1.4,
	Id.MOLE: 1.0,
	Id.CROW: 3.0,
	Id.LANTERN_BUMBLEBEE: 1.4,
	Id.DOG: 1.7,
	Id.CAT: 1.3,
}
const FLEE_SPEED := {
	Id.SHEEP: 3.4,
	Id.BOAR: 3.8,
	Id.CHICKEN: 3.6,
	Id.DEER: 5.2,
	Id.LANTERN_MOTH: 5.0,
	Id.SHADE_LURKER: 3.0,
	Id.ROCK_MIMIC: 2.0,
	Id.WISP: 3.0,
	Id.COW: 3.2,
	Id.GOAT: 4.2,
	Id.DUCK: 3.2,
	Id.RABBIT: 5.5,
	Id.PIG: 3.4,
	Id.BEE: 3.0,
	Id.WOLF: 4.5,
	Id.BEAR: 3.0,
	Id.FROG: 3.5,
	Id.TURTLE: 0.8,
	Id.BEAVER: 2.8,
	Id.FISH: 4.0,
	Id.MOLE: 2.0,
	Id.CROW: 5.0,
	Id.LANTERN_BUMBLEBEE: 2.5,
	Id.DOG: 5.0,
	Id.CAT: 4.6,
}
## Monsters: tiles per second hunting (fliers: diving at the player), what
## their blow takes off, and what it is called when it makes a player pass
## out (Vitals.Cause); companions: going for what they hunt, their bite.
const CHASE_SPEED := {
	Id.LANTERN_MOTH: 7.0,
	Id.SHADE_LURKER: 3.2,
	Id.ROCK_MIMIC: 2.2,
	Id.WISP: 6.0,
	Id.WOLF: 4.6,
	Id.BEAR: 3.8,
	Id.DOG: 5.2,
	Id.CAT: 4.8,
}
const DAMAGE := {
	Id.LANTERN_MOTH: 1,
	Id.SHADE_LURKER: 2,
	Id.ROCK_MIMIC: 3,
	Id.WISP: 2,
	Id.WOLF: 3,
	Id.BEAR: 6,
	Id.DOG: 3,
	Id.CAT: 3,
}
const CAUSE := {
	Id.LANTERN_MOTH: Vitals.Cause.MOTH,
	Id.SHADE_LURKER: Vitals.Cause.LURKER,
	Id.ROCK_MIMIC: Vitals.Cause.MIMIC,
	Id.WISP: Vitals.Cause.WISP,
	Id.WOLF: Vitals.Cause.WOLF,
	Id.BEAR: Vitals.Cause.BEAR,
}
## What each gives when it dies: [item, fewest, most].
const DROPS := {
	Id.SHEEP: [[Items.Id.WOOL, 1, 2], [Items.Id.RAW_MUTTON, 1, 2]],
	Id.BOAR: [[Items.Id.RAW_PORK, 1, 3], [Items.Id.HIDE, 0, 1]],
	Id.CHICKEN: [[Items.Id.RAW_CHICKEN, 1, 1], [Items.Id.FEATHER, 0, 2]],
	Id.DEER: [[Items.Id.RAW_VENISON, 1, 2], [Items.Id.HIDE, 0, 1]],
	Id.LANTERN_MOTH: [[Items.Id.MOTH_DUST, 1, 2]],
	Id.SHADE_LURKER: [[Items.Id.SHADE_ESSENCE, 0, 1]],
	Id.ROCK_MIMIC: [[Items.Id.STONE, 2, 4], [Items.Id.RAW_IRON, 0, 1]],
	Id.WISP: [[Items.Id.WISP_EMBER, 1, 1]],
	Id.COW: [[Items.Id.RAW_BEEF, 1, 3], [Items.Id.HIDE, 0, 2]],
	Id.GOAT: [[Items.Id.RAW_MUTTON, 1, 2], [Items.Id.HIDE, 0, 1]],
	Id.DUCK: [[Items.Id.RAW_DUCK, 1, 1], [Items.Id.FEATHER, 0, 2]],
	Id.RABBIT: [[Items.Id.RAW_RABBIT, 1, 1], [Items.Id.HIDE, 0, 1]],
	Id.PIG: [[Items.Id.RAW_PORK, 2, 3]],
	Id.BEE: [[Items.Id.HONEYCOMB, 0, 0]],
	Id.WOLF: [[Items.Id.HIDE, 0, 2]],
	Id.BEAR: [[Items.Id.HIDE, 2, 3], [Items.Id.RAW_BEEF, 1, 3]],
	Id.FROG: [],
	Id.TURTLE: [],
	Id.BEAVER: [[Items.Id.HIDE, 0, 1], [Items.Id.STICK, 1, 3]],
	Id.FISH: [[Items.Id.RAW_FISH, 1, 1]],
	Id.MOLE: [[Items.Id.HIDE, 0, 1]],
	Id.CROW: [[Items.Id.FEATHER, 1, 2]],
	Id.LANTERN_BUMBLEBEE: [],
	Id.DOG: [],
	Id.CAT: [],
}
## Where herds are found, and how many in one (pigs are born on farms to
## boars, bees come out of hives, pests come to fields, dogs are tamed
## wolves: none in the wild).
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
	Id.COW: [Biomes.Id.PLAINS, Biomes.Id.MEADOW, Biomes.Id.SAVANNA],
	Id.GOAT:
	[
		Biomes.Id.SNOWY_SLOPES,
		Biomes.Id.GROVE,
		Biomes.Id.STONY_PEAKS,
		Biomes.Id.JAGGED_PEAKS,
	],
	Id.DUCK: [Biomes.Id.RIVER, Biomes.Id.SWAMP],
	Id.RABBIT:
	[
		Biomes.Id.FOREST,
		Biomes.Id.BIRCH_FOREST,
		Biomes.Id.FLOWER_FOREST,
		Biomes.Id.TAIGA,
		Biomes.Id.SNOWY_PLAINS,
		Biomes.Id.SNOWY_TAIGA,
		Biomes.Id.DESERT,
	],
	Id.PIG: [],
	Id.BEE: [],
	Id.WOLF:
	[
		Biomes.Id.FOREST,
		Biomes.Id.TAIGA,
		Biomes.Id.SNOWY_TAIGA,
		Biomes.Id.OLD_GROWTH_TAIGA,
		Biomes.Id.GROVE,
		Biomes.Id.SNOWY_PLAINS,
	],
	Id.BEAR: [Biomes.Id.TAIGA, Biomes.Id.SNOWY_TAIGA, Biomes.Id.OLD_GROWTH_TAIGA],
	Id.FROG: [Biomes.Id.SWAMP, Biomes.Id.RIVER],
	Id.TURTLE: [Biomes.Id.BEACH],
	Id.BEAVER: [Biomes.Id.RIVER, Biomes.Id.SWAMP],
	Id.FISH:
	[
		Biomes.Id.RIVER,
		Biomes.Id.OCEAN,
		Biomes.Id.DEEP_OCEAN,
		Biomes.Id.WARM_OCEAN,
		Biomes.Id.COLD_OCEAN,
		Biomes.Id.SWAMP,
	],
	Id.MOLE: [],
	Id.CROW: [],
	Id.LANTERN_BUMBLEBEE: [],
	Id.DOG: [],
	Id.CAT:
	[
		Biomes.Id.PLAINS,
		Biomes.Id.FLOWER_FOREST,
		Biomes.Id.SAVANNA,
		Biomes.Id.SPARSE_JUNGLE,
		Biomes.Id.JUNGLE,
	],
}
const HERD := {
	Id.SHEEP: Vector2i(2, 4),
	Id.BOAR: Vector2i(2, 3),
	Id.CHICKEN: Vector2i(2, 4),
	Id.DEER: Vector2i(1, 3),
	Id.COW: Vector2i(2, 4),
	Id.GOAT: Vector2i(2, 3),
	Id.DUCK: Vector2i(2, 4),
	Id.RABBIT: Vector2i(1, 3),
	Id.PIG: Vector2i(1, 1),
	Id.BEE: Vector2i(1, 1),
	Id.WOLF: Vector2i(3, 5),
	Id.BEAR: Vector2i(1, 1),
	Id.FROG: Vector2i(2, 4),
	Id.TURTLE: Vector2i(2, 3),
	Id.BEAVER: Vector2i(1, 2),
	Id.FISH: Vector2i(3, 6),
	Id.MOLE: Vector2i(1, 1),
	Id.CROW: Vector2i(1, 1),
	Id.LANTERN_BUMBLEBEE: Vector2i(1, 1),
	Id.DOG: Vector2i(1, 1),
	Id.CAT: Vector2i(1, 2),
}


static func is_valid(kind: int) -> bool:
	return kind >= 0 and kind < Id.size()


static func is_monster(kind: int) -> bool:
	return MONSTERS.has(kind)


## The species living in a biome.
static func living_in(biome: int) -> Array[int]:
	var result: Array[int] = []
	for kind: int in BIOMES:
		if biome in BIOMES[kind]:
			result.append(kind)
	return result
