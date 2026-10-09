class_name Effects
extends RefCounted
## What dishes do besides feeding (shared): the effects a food gives
## (OF_FOOD: kind -> seconds, the default day's, paced by
## WorldClock.scale_duration when eaten), kept per player by the server
## (PlayerSession.effects: kind -> seconds left; saved, told with
## Msg.VITALS) and shown over the vitality: REGEN heals a point every
## REGEN_EVERY whatever the satiety; FED makes satiety go FED_SLOWER as
## fast; SWIFT walks SWIFT_SPEED times faster (the client); STRONG adds
## STRONG_DAMAGE to every blow (Creatures.attack); HASTE breaks HASTE_SPEED
## times faster (the client). A food with effects may be eaten full.

enum Kind { REGEN, FED, SWIFT, STRONG, HASTE }

const REGEN_EVERY := 3.0
const FED_SLOWER := 0.5
const SWIFT_SPEED := 1.2
const STRONG_DAMAGE := 2
const HASTE_SPEED := 1.3
## Translation keys of the effects' names and of what they do.
const NAME_KEYS := {
	Kind.REGEN: "EFFECT_REGEN",
	Kind.FED: "EFFECT_FED",
	Kind.SWIFT: "EFFECT_SWIFT",
	Kind.STRONG: "EFFECT_STRONG",
	Kind.HASTE: "EFFECT_HASTE",
}
const HOW_KEYS := {
	Kind.REGEN: "EFFECT_REGEN_HOW",
	Kind.FED: "EFFECT_FED_HOW",
	Kind.SWIFT: "EFFECT_SWIFT_HOW",
	Kind.STRONG: "EFFECT_STRONG_HOW",
	Kind.HASTE: "EFFECT_HASTE_HOW",
}
## Their colors on screen (VitalsBar draws their badges).
const COLORS := {
	Kind.REGEN: Color("e0506a"),
	Kind.FED: Color("e0a43a"),
	Kind.SWIFT: Color("6ac6e8"),
	Kind.STRONG: Color("c86a3a"),
	Kind.HASTE: Color("9ad05a"),
}
## The effects of each food: kind -> seconds.
const OF_FOOD := {
	Items.Id.APPLE_JUICE: {Kind.REGEN: 20.0},
	Items.Id.FRUIT_JUICE: {Kind.REGEN: 20.0},
	Items.Id.CIDER: {Kind.STRONG: 60.0},
	Items.Id.JAM: {Kind.REGEN: 15.0},
	Items.Id.CHEESE: {Kind.FED: 90.0},
	Items.Id.VEGETABLE_SOUP: {Kind.REGEN: 30.0},
	Items.Id.MEAT_STEW: {Kind.STRONG: 120.0, Kind.FED: 120.0},
	Items.Id.FRUIT_PIE: {Kind.SWIFT: 90.0},
	Items.Id.OMELETTE: {Kind.HASTE: 90.0},
	Items.Id.CAKE: {Kind.REGEN: 45.0, Kind.SWIFT: 60.0},
	Items.Id.CREPES: {Kind.SWIFT: 45.0},
	Items.Id.GRATIN: {Kind.FED: 180.0},
	Items.Id.TARTINE: {Kind.HASTE: 45.0},
	Items.Id.FISH_SOUP: {Kind.REGEN: 40.0},
	Items.Id.SUSHI: {Kind.SWIFT: 60.0, Kind.HASTE: 45.0},
	Items.Id.FRIED_FISH: {Kind.FED: 150.0},
}


static func of(item: int) -> Dictionary:
	return OF_FOOD.get(item, {})


## Whether a food gives effects (it may then be eaten full).
static func gives(item: int) -> bool:
	return OF_FOOD.has(item)


## Effects taken from a food into `effects` (kind -> seconds left), each
## lasting as long as the longer of the two; `scale` paces the food's
## seconds (WorldClock.scale_duration of 1).
static func take(effects: Dictionary, item: int, scale: float) -> void:
	var given: Dictionary = of(item)
	for kind: int in given:
		effects[kind] = maxf(effects.get(kind, 0.0), given[kind] * scale)


## The effects wear off by `delta` seconds; returns whether one ended.
static func wear(effects: Dictionary, delta: float) -> bool:
	var ended := false
	for kind: int in effects.keys():
		var left: float = effects[kind] - delta
		if left <= 0.0:
			effects.erase(kind)
			ended = true
		else:
			effects[kind] = left
	return ended


static func has(effects: Dictionary, kind: int) -> bool:
	return effects.get(kind, 0.0) > 0.0


## For saves and messages: kind -> seconds (whole kinds as ints).
static func to_dict(effects: Dictionary) -> Dictionary:
	var out := {}
	for kind: int in effects:
		out[kind] = float(effects[kind])
	return out


## From a save or a message (unknown kinds and spent ones left out).
static func from_dict(data: Dictionary) -> Dictionary:
	var out := {}
	for kind: Variant in data:
		var known := int(kind)
		var left := float(data[kind])
		if known >= 0 and known < Kind.size() and left > 0.0:
			out[known] = left
	return out
