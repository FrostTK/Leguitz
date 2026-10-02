class_name Combat
extends RefCounted
## Players' blows (on animals and monsters): how far a player reaches, how
## often, and what the item in hand takes off. What is hit is thrown back
## and cannot be hurt again for a moment (Creature.hurt_by). Arrows:
## Archery; armor: Armor.

## From the eye to the body's box (local units), and the leeway the server
## allows (players move while messages travel).
const REACH := 3.5
const REACH_LEEWAY := 1.0
## Seconds between two blows (the server allows a little less).
const BLOW_SECONDS := 0.45
const BLOW_LEEWAY := 0.1
## What a bare hand (or anything but a tool) takes off, and the tools by
## kind and Items.Tier (swords are made for it; an axe hits hard too).
const HAND_DAMAGE := 1
const TOOL_DAMAGE := {
	Items.Tool.SWORD: [4, 5, 5, 6, 4, 7],
	Items.Tool.AXE: [3, 3, 4, 4, 3, 5],
	Items.Tool.PICKAXE: [2, 2, 3, 3, 2, 4],
	Items.Tool.SHOVEL: [2, 2, 2, 3, 2, 3],
	Items.Tool.HOE: [1, 2, 2, 2, 1, 3],
}


## What a blow with `item` in hand takes off.
static func damage_of(item: int) -> int:
	var tool := Items.tool_of(item)
	if tool == Items.Tool.NONE:
		return HAND_DAMAGE
	return TOOL_DAMAGE[tool][Items.tier_of(item)]
