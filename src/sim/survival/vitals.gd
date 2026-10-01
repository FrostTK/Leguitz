class_name Vitals
extends RefCounted
## A player's vitality: how much they have (MAX_HEALTH points, kept by the
## server and saved), what hurts (falls from higher than FALL_SAFE levels,
## unless into water; lava), how it comes back (slowly, paced by the day's
## length) and what is said of a death. The server runs it on its player
## sessions (GameServer); clients show it (VitalsBar).

## What hurt a player (said when they pass out).
enum Cause { NONE, FALL, LAVA }

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
## REGEN_DELAY (authored for the default day, see WorldClock.scale_duration).
const REGEN_SECONDS := 4.0
const REGEN_DELAY := 6.0
## Translation keys of the causes.
const CAUSE_KEYS := {
	Cause.NONE: "DEATH_CAUSE_NONE",
	Cause.FALL: "DEATH_CAUSE_FALL",
	Cause.LAVA: "DEATH_CAUSE_LAVA",
}


## Points a fall of `levels` (from its highest point) costs.
static func fall_damage(levels: float) -> int:
	return maxi(floori(levels - FALL_SAFE + 0.01), 0)
