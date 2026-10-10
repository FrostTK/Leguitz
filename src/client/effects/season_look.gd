class_name SeasonLook
extends RefCounted
## How the seasons look, on the client (WeatherEffects runs it every frame;
## the voxel and terrain shaders read its global uniforms). The deciduous
## trees (DECIDUOUS) turn their leaves gold, orange and red in autumn and
## lose them (season_autumn, season_bare); snow covers the open ground and
## what faces the sky in winter where winters bite (season_snow; on what is
## built, season_built_snow, where the player stands); at winter's end it
## melts and the buds open, so spring starts green (a new world, seasons
## turned on); grass and foliage take the
## season's tint (season_grass: fresh in spring, deep in summer, tawny in
## autumn, dull in winter). The values follow the season and how far into
## it the world is (`goals`) and ease towards them (EASE), so a season set
## by a command settles in a few seconds. Small plants (WITHERING) are
## buried by the snow. ChunkMesher gives each prop its
## bits (`prop_bits`): deciduous, and where winters bite.

## The trees whose leaves turn and fall (the young ones too).
const DECIDUOUS := {
	Tiles.Block.OAK: true,
	Tiles.Block.BIRCH: true,
	Tiles.Block.DARK_OAK: true,
	Tiles.Block.SWAMP_OAK: true,
	Tiles.Block.APPLE_TREE: true,
	Tiles.Block.APPLE_TREE_FRUIT: true,
	Tiles.Block.CHERRY_TREE: true,
	Tiles.Block.CHERRY_TREE_FRUIT: true,
	Tiles.Block.PEACH_TREE: true,
	Tiles.Block.PEACH_TREE_FRUIT: true,
	Tiles.Block.YOUNG_OAK: true,
	Tiles.Block.YOUNG_BIRCH: true,
	Tiles.Block.YOUNG_DARK_OAK: true,
	Tiles.Block.YOUNG_SWAMP_OAK: true,
	Tiles.Block.YOUNG_APPLE_TREE: true,
	Tiles.Block.YOUNG_CHERRY_TREE: true,
	Tiles.Block.YOUNG_PEACH_TREE: true,
}
## The small plants the snow buries in winter.
const WITHERING := {
	Tiles.Block.TALL_GRASS: true,
	Tiles.Block.FERN: true,
	Tiles.Block.FLOWER_RED: true,
	Tiles.Block.FLOWER_YELLOW: true,
	Tiles.Block.FLOWER_BLUE: true,
	Tiles.Block.FLOWER_WHITE: true,
	Tiles.Block.FLOWER_PINK: true,
}
## The season's tint of grass and foliage (on linear colors).
const GRASS := {
	WorldClock.Season.SPRING: Vector3(1.06, 1.12, 0.76),
	WorldClock.Season.SUMMER: Vector3(0.94, 0.97, 0.92),
	WorldClock.Season.AUTUMN: Vector3(1.14, 0.95, 0.7),
	WorldClock.Season.WINTER: Vector3(0.84, 0.86, 0.84),
}
## How fast the look eases towards the season's (per second).
const EASE := 0.6
## Winter thaws from this far into it; the leaves still to come when
## spring starts.
const THAW := 0.8
const LAST_BARE := 0.25

var autumn := 0.0
var bare := 0.0
var snow := 0.0
var built_snow := 0.0
var grass := Vector3.ONE

var _settled := false


## A prop's season bits (ChunkMesher, INSTANCE_CUSTOM.a): 16 deciduous, 32
## where winters bite, 64 a small plant snow buries.
static func prop_bits(block: int, biome: int) -> int:
	var bits := 16 if DECIDUOUS.has(block) else 0
	if not Seasons.mild(biome):
		bits += 32 + (64 if WITHERING.has(block) else 0)
	return bits


## The look of `season` at `progress` (0 to 1 into it): [autumn, bare,
## snow, grass].
static func goals(season: int, progress: float) -> Array:
	var p := clampf(progress, 0.0, 1.0)
	match season:
		WorldClock.Season.SPRING:
			return [
				0.0,
				LAST_BARE * (1.0 - smoothstep(0.0, 0.2, p)),
				0.0,
				_grass(WorldClock.Season.WINTER, WorldClock.Season.SPRING, smoothstep(0.0, 0.3, p)),
			]
		WorldClock.Season.SUMMER:
			return [
				0.0,
				0.0,
				0.0,
				_grass(WorldClock.Season.SPRING, WorldClock.Season.SUMMER, smoothstep(0.0, 0.3, p)),
			]
		WorldClock.Season.AUTUMN:
			return [
				smoothstep(0.0, 0.5, p),
				smoothstep(0.45, 1.0, p) * 0.85,
				0.0,
				_grass(WorldClock.Season.SUMMER, WorldClock.Season.AUTUMN, smoothstep(0.0, 0.5, p)),
			]
	# Winter: bare and snowy; at its end the snow melts and green buds open.
	var thaw := smoothstep(THAW, 1.0, p)
	return [
		1.0 - thaw,
		lerpf(0.85 + 0.15 * smoothstep(0.0, 0.1, p), LAST_BARE, thaw),
		smoothstep(0.0, 0.2, p) * (1.0 - smoothstep(THAW - 0.05, 0.95, p)),
		_grass(WorldClock.Season.AUTUMN, WorldClock.Season.WINTER, smoothstep(0.0, 0.3, p)),
	]


## Eases towards the look of the clock's season (none: summer's) and gives
## it to the shaders; `biome` is where the player stands (what is built
## takes snow where winters bite).
func update(clock: WorldClock, biome: int, delta: float) -> void:
	var goal := [0.0, 0.0, 0.0, Vector3.ONE]
	if clock != null and Seasons.on(clock):
		goal = goals(Seasons.season(clock), Seasons.progress(clock))
	var built: float = goal[2] if not Seasons.mild(biome) else 0.0
	var step := 1.0 if not _settled else EASE * delta
	_settled = true
	autumn = move_toward(autumn, goal[0], step)
	bare = move_toward(bare, goal[1], step)
	snow = move_toward(snow, goal[2], step)
	built_snow = move_toward(built_snow, built, step)
	grass = grass.move_toward(goal[3], step)
	RenderingServer.global_shader_parameter_set(&"season_autumn", autumn)
	RenderingServer.global_shader_parameter_set(&"season_bare", bare)
	RenderingServer.global_shader_parameter_set(&"season_snow", snow)
	RenderingServer.global_shader_parameter_set(&"season_built_snow", built_snow)
	RenderingServer.global_shader_parameter_set(&"season_grass", grass)


static func _grass(from: int, to: int, t: float) -> Vector3:
	return (GRASS[from] as Vector3).lerp(GRASS[to], t)
