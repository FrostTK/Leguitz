class_name Vitals
extends RefCounted
## A player's vitality and satiety: how much they have (MAX_HEALTH and
## MAX_FOOD points, kept by the server and saved), what hurts (falls from
## higher than FALL_SAFE levels, unless into water; lava; starving; a raw
## red mushroom; drowning once their air runs out), how satiety goes (with time, walking, mining and
## healing), how vitality comes back (slowly, only well fed) and what is
## said of a death. The server runs it on its player sessions (Survival);
## clients show it (VitalsBar).

## What hurt a player (said when they pass out).
enum Cause { NONE, FALL, LAVA, STARVATION, POISON, DROWNING }

const MAX_HEALTH := 20
## Falls up to this many levels are harmless; each level more costs a
## point.
const FALL_SAFE := 3.0
## Standing in lava: so many points every LAVA_SECONDS (real seconds: a
## danger the player sees, not paced by the day).
const LAVA_DAMAGE := 2
const LAVA_SECONDS := 0.5
## After a hurt nothing else hurts for this long (real seconds).
const HURT_IMMUNITY := 0.4
## A point comes back every REGEN_SECONDS, once nothing hurt for
## REGEN_DELAY, to players fed at least FED (authored for the default day,
## see WorldClock.scale_duration); each point healed costs HEAL_EFFORT.
const REGEN_SECONDS := 4.0
const REGEN_DELAY := 6.0
const FED := 14
## Satiety: MAX_FOOD points, one spent per point of effort. Effort comes
## with time (a point every FOOD_SECONDS, paced), walking (per tile),
## breaking blocks and healing.
const MAX_FOOD := 20
const FOOD_SECONDS := 50.0
const WALK_EFFORT := 0.012
const BREAK_EFFORT := 0.03
const HEAL_EFFORT := 0.5
## Hungry under HUNGRY points (the gauge throbs); too weak to run under
## WEAK; at 0 starving: a point of vitality lost every STARVE_SECONDS
## (paced).
const HUNGRY := 6
const WEAK := 4
const STARVE_SECONDS := 6.0
## Eating one takes EAT_SECONDS (real seconds, the right button held).
const EAT_SECONDS := 1.4
## Air: MAX_AIR seconds with the eye under water (real seconds), refilled
## AIR_REFILL times as fast out of it; without air, DROWN_DAMAGE points
## every DROWN_SECONDS.
const MAX_AIR := 12.0
const AIR_REFILL := 6.0
const DROWN_DAMAGE := 2
const DROWN_SECONDS := 1.0
## Air is told to the player in steps this small (seconds).
const AIR_STEP := 0.25
## Foods that make one sick raw: the vitality they cost.
const POISONS := {Items.Id.MUSHROOM_RED: 2, Items.Id.RAW_CHICKEN: 1}
## Translation keys of the causes.
const CAUSE_KEYS := {
	Cause.NONE: "DEATH_CAUSE_NONE",
	Cause.FALL: "DEATH_CAUSE_FALL",
	Cause.LAVA: "DEATH_CAUSE_LAVA",
	Cause.STARVATION: "DEATH_CAUSE_STARVATION",
	Cause.POISON: "DEATH_CAUSE_POISON",
	Cause.DROWNING: "DEATH_CAUSE_DROWNING",
}


## Points a fall of `levels` (from its highest point) costs.
static func fall_damage(levels: float) -> int:
	return maxi(floori(levels - FALL_SAFE + 0.01), 0)
