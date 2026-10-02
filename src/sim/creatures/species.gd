class_name Species
extends RefCounted
## The kinds of creatures, animals and monsters: their size, strength, pace,
## where they live and what they give; the monsters' blows. Ids are saved
## with the animals: only append to the enum, never renumber.

enum Id { SHEEP, BOAR, CHICKEN, DEER, LANTERN_MOTH, SHADE_LURKER, ROCK_MIMIC, WISP }

## The monsters (Monster), and those that fly.
const MONSTERS := {Id.LANTERN_MOTH: true, Id.SHADE_LURKER: true, Id.ROCK_MIMIC: true, Id.WISP: true}
const FLIERS := {Id.LANTERN_MOTH: true, Id.WISP: true}

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
}
## Monsters: tiles per second hunting (fliers: diving at the player), what
## their blow takes off, and what it is called when it makes a player pass
## out (Vitals.Cause).
const CHASE_SPEED := {
	Id.LANTERN_MOTH: 7.0,
	Id.SHADE_LURKER: 3.2,
	Id.ROCK_MIMIC: 2.2,
	Id.WISP: 6.0,
}
const DAMAGE := {
	Id.LANTERN_MOTH: 1,
	Id.SHADE_LURKER: 2,
	Id.ROCK_MIMIC: 3,
	Id.WISP: 2,
}
const CAUSE := {
	Id.LANTERN_MOTH: Vitals.Cause.MOTH,
	Id.SHADE_LURKER: Vitals.Cause.LURKER,
	Id.ROCK_MIMIC: Vitals.Cause.MIMIC,
	Id.WISP: Vitals.Cause.WISP,
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


static func is_monster(kind: int) -> bool:
	return MONSTERS.has(kind)


## The species living in a biome.
static func living_in(biome: int) -> Array[int]:
	var result: Array[int] = []
	for kind: int in BIOMES:
		if biome in BIOMES[kind]:
			result.append(kind)
	return result
