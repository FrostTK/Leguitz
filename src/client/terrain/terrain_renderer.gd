class_name TerrainRenderer
extends RefCounted
## Terrain tables shared by the terrain and water shaders (ground
## priorities, kinds, water colors and clarity, cliff materials). The chunk
## data textures they read come from ChunkMesher.surface_map.

enum Kind { LAND, WATER, LAVA, ICE }
enum CliffMaterial { DIRT, STONE, SAND, SNOW }

const DATA_SIZE := GameConst.CHUNK_SIZE + 2

const GROUND_ATLAS := preload("res://assets/textures/tiles/ground_atlas.png")
const GROUND_NORMALS := preload("res://assets/textures/tiles/ground_atlas_n.png")
const WALL_ATLAS := preload("res://assets/textures/tiles/wall_atlas.png")
const WALL_NORMALS := preload("res://assets/textures/tiles/wall_atlas_n.png")
const WALL_EMISSION := preload("res://assets/textures/tiles/wall_atlas_e.png")

## Which ground spreads over which at their borders (higher wins).
const PRIORITY := {
	Tiles.Ground.DEEP_WATER: 0,
	Tiles.Ground.WATER: 1,
	Tiles.Ground.WARM_WATER: 1,
	Tiles.Ground.SWAMP_WATER: 1,
	Tiles.Ground.LAVA: 2,
	Tiles.Ground.ICE: 3,
	Tiles.Ground.MUD: 4,
	Tiles.Ground.SAND: 5,
	Tiles.Ground.RED_SAND: 5,
	Tiles.Ground.GRAVEL: 6,
	Tiles.Ground.STONE_FLOOR: 7,
	Tiles.Ground.DEEPSLATE_FLOOR: 7,
	Tiles.Ground.DIRT: 8,
	Tiles.Ground.FARMLAND: 8,
	Tiles.Ground.FARMLAND_WET: 8,
	Tiles.Ground.TERRACOTTA: 9,
	Tiles.Ground.TERRACOTTA_LIGHT: 9,
	Tiles.Ground.PODZOL: 10,
	Tiles.Ground.DRY_GRASS: 11,
	Tiles.Ground.SWAMP_GRASS: 11,
	Tiles.Ground.TAIGA_GRASS: 12,
	Tiles.Ground.FOREST_GRASS: 12,
	Tiles.Ground.GRASS: 13,
	Tiles.Ground.MEADOW_GRASS: 13,
	Tiles.Ground.JUNGLE_GRASS: 13,
	Tiles.Ground.MYCELIUM: 13,
	Tiles.Ground.SNOW: 14,
}
const KINDS := {
	Tiles.Ground.DEEP_WATER: Kind.WATER,
	Tiles.Ground.WATER: Kind.WATER,
	Tiles.Ground.WARM_WATER: Kind.WATER,
	Tiles.Ground.SWAMP_WATER: Kind.WATER,
	Tiles.Ground.LAVA: Kind.LAVA,
	Tiles.Ground.ICE: Kind.ICE,
}
## The water's own color: all of it shows over deep water.
const WATER_COLORS := {
	Tiles.Ground.DEEP_WATER: Color(0.17, 0.36, 0.66),
	Tiles.Ground.WATER: Color(0.24, 0.55, 0.84),
	Tiles.Ground.WARM_WATER: Color(0.2, 0.7, 0.78),
	Tiles.Ground.SWAMP_WATER: Color(0.3, 0.47, 0.36),
}
## How deep (levels) the eye sees into each water: tropical seas are very
## clear, rivers and lakes clear, the ocean bluer, swamps murky.
const WATER_CLARITY := {
	Tiles.Ground.DEEP_WATER: 4.5,
	Tiles.Ground.WATER: 6.0,
	Tiles.Ground.WARM_WATER: 10.0,
	Tiles.Ground.SWAMP_WATER: 1.5,
}
## Tint of the light coming up through each water.
const WATER_TINTS := {
	Tiles.Ground.DEEP_WATER: Color(0.62, 0.8, 1.0),
	Tiles.Ground.WATER: Color(0.6, 0.82, 1.0),
	Tiles.Ground.WARM_WATER: Color(0.72, 0.98, 0.95),
	Tiles.Ground.SWAMP_WATER: Color(0.78, 0.84, 0.55),
}
const STONE_GROUNDS := {
	Tiles.Ground.STONE_FLOOR: true,
	Tiles.Ground.GRAVEL: true,
	Tiles.Ground.DEEPSLATE_FLOOR: true,
}
const SAND_GROUNDS := {
	Tiles.Ground.SAND: true,
	Tiles.Ground.RED_SAND: true,
	Tiles.Ground.TERRACOTTA: true,
	Tiles.Ground.TERRACOTTA_LIGHT: true,
}
const SNOW_GROUNDS := {Tiles.Ground.SNOW: true, Tiles.Ground.ICE: true}
const MAX_GROUNDS := Voxels.BLOCK_BASE


static func cliff_material(ground: int) -> int:
	if STONE_GROUNDS.has(ground):
		return CliffMaterial.STONE
	if SAND_GROUNDS.has(ground):
		return CliffMaterial.SAND
	if SNOW_GROUNDS.has(ground):
		return CliffMaterial.SNOW
	return CliffMaterial.DIRT


## Sets the atlases and ground tables of a terrain top material.
static func configure_top(material: ShaderMaterial) -> void:
	_configure_grounds(material)
	material.set_shader_parameter("wall_atlas", WALL_ATLAS)
	material.set_shader_parameter("wall_normals", WALL_NORMALS)
	material.set_shader_parameter("wall_emission", WALL_EMISSION)
	material.set_shader_parameter("see_through_walls", TileAtlas.clear_wall_flags())


## Sets the ground and water tables of a water material.
static func configure_water(material: ShaderMaterial) -> void:
	_configure_grounds(material)
	var colors := PackedColorArray()
	var tints := PackedColorArray()
	var clarity := PackedFloat32Array()
	for ground in MAX_GROUNDS:
		colors.append(WATER_COLORS.get(ground, Color.BLACK))
		tints.append(WATER_TINTS.get(ground, Color.WHITE))
		clarity.append(WATER_CLARITY.get(ground, 1.0))
	material.set_shader_parameter("water_colors", colors)
	material.set_shader_parameter("water_tints", tints)
	material.set_shader_parameter("water_clarity", clarity)


static func _configure_grounds(material: ShaderMaterial) -> void:
	material.set_shader_parameter("ground_atlas", GROUND_ATLAS)
	material.set_shader_parameter("ground_normals", GROUND_NORMALS)
	var priority := PackedInt32Array()
	var kind := PackedInt32Array()
	for ground in MAX_GROUNDS:
		priority.append(PRIORITY.get(ground, 0))
		kind.append(KINDS.get(ground, Kind.LAND))
	material.set_shader_parameter("ground_priority", priority)
	material.set_shader_parameter("ground_kind", kind)
