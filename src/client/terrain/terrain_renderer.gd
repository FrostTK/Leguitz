class_name TerrainRenderer
extends RefCounted
## Owns the shared terrain materials and turns chunks into the small data
## textures the terrain shader reads (see terrain_common.gdshaderinc).

enum Kind { LAND, WATER, LAVA, ICE }
enum CliffMaterial { DIRT, STONE, SAND, SNOW }

const TERRAIN_SHADER := preload("res://src/client/shaders/terrain.gdshader")
const EMISSION_SHADER := preload("res://src/client/shaders/terrain_emission.gdshader")

const DATA_SIZE := GameConst.CHUNK_SIZE + 2

const GROUND_ATLAS := preload("res://assets/textures/tiles/ground_atlas.png")
const GROUND_NORMALS := preload("res://assets/textures/tiles/ground_atlas_n.png")
const WALL_ATLAS := preload("res://assets/textures/tiles/wall_atlas.png")
const WALL_NORMALS := preload("res://assets/textures/tiles/wall_atlas_n.png")
const WALL_EMISSION := preload("res://assets/textures/tiles/wall_atlas_e.png")
const CLIFF_ATLAS := preload("res://assets/textures/tiles/cliff_atlas.png")
const CLIFF_NORMALS := preload("res://assets/textures/tiles/cliff_atlas_n.png")

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
const WATER_COLORS := {
	Tiles.Ground.DEEP_WATER: Color(0.17, 0.36, 0.66),
	Tiles.Ground.WATER: Color(0.24, 0.55, 0.84),
	Tiles.Ground.WARM_WATER: Color(0.2, 0.7, 0.78),
	Tiles.Ground.SWAMP_WATER: Color(0.3, 0.47, 0.36),
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
const MAX_GROUNDS := 32

var terrain_material := ShaderMaterial.new()
var emission_material := ShaderMaterial.new()


func _init() -> void:
	terrain_material.shader = TERRAIN_SHADER
	emission_material.shader = EMISSION_SHADER
	for material in [terrain_material, emission_material]:
		_configure(material)


func set_weather(wetness: float, rain: float, wind: Vector2) -> void:
	for material in [terrain_material, emission_material]:
		material.set_shader_parameter("wetness", wetness)
		material.set_shader_parameter("rain", rain)
		material.set_shader_parameter("wind", wind)


static func cliff_material(ground: int) -> int:
	if STONE_GROUNDS.has(ground):
		return CliffMaterial.STONE
	if SAND_GROUNDS.has(ground):
		return CliffMaterial.SAND
	if SNOW_GROUNDS.has(ground):
		return CliffMaterial.SNOW
	return CliffMaterial.DIRT


## Builds the 18x18 RGBA float data of a chunk (floats, because 8-bit
## textures get gamma-converted in HDR 2D and would lose exact ids). `neighbor` is a
## Callable(coord: Vector2i) -> ChunkData (null if not loaded); missing
## neighbors repeat the chunk's own edge so no false edges appear.
static func build_data(chunk: ChunkData, neighbor: Callable) -> PackedFloat32Array:
	var values := PackedFloat32Array()
	values.resize(DATA_SIZE * DATA_SIZE * 4)
	var size := GameConst.CHUNK_SIZE
	var lookup := TileAtlas.wall_lookup
	var neighbors := {}
	var out := 0
	for gy in DATA_SIZE:
		for gx in DATA_SIZE:
			var lx := gx - 1
			var ly := gy - 1
			var source := chunk
			if lx < 0 or ly < 0 or lx >= size or ly >= size:
				var offset := Vector2i(floori(lx / float(size)), floori(ly / float(size)))
				if not neighbors.has(offset):
					neighbors[offset] = neighbor.call(chunk.coord + offset)
				var other: ChunkData = neighbors[offset]
				if other != null:
					source = other
					lx = posmod(lx, size)
					ly = posmod(ly, size)
				else:
					lx = clampi(lx, 0, size - 1)
					ly = clampi(ly, 0, size - 1)
			var index := ly * size + lx
			values[out] = source.ground[index]
			values[out + 1] = lookup[source.blocks[index]]
			values[out + 2] = source.levels[index]
			values[out + 3] = source.shapes[index]
			out += 4
	return values


## True if the chunk has something that glows (lava, gem ores).
static func has_emission(chunk: ChunkData) -> bool:
	for index in GameConst.CHUNK_AREA:
		if chunk.ground[index] == Tiles.Ground.LAVA:
			return true
		if TileAtlas.GLOWING_WALLS.has(chunk.blocks[index]):
			return true
	return false


func _configure(material: ShaderMaterial) -> void:
	material.set_shader_parameter("ground_atlas", GROUND_ATLAS)
	material.set_shader_parameter("ground_normals", GROUND_NORMALS)
	material.set_shader_parameter("wall_atlas", WALL_ATLAS)
	material.set_shader_parameter("wall_normals", WALL_NORMALS)
	material.set_shader_parameter("wall_emission", WALL_EMISSION)
	material.set_shader_parameter("cliff_atlas", CLIFF_ATLAS)
	material.set_shader_parameter("cliff_normals", CLIFF_NORMALS)
	var priority := PackedInt32Array()
	var kind := PackedInt32Array()
	var cliffs := PackedInt32Array()
	var water := PackedColorArray()
	for ground in MAX_GROUNDS:
		priority.append(PRIORITY.get(ground, 0))
		kind.append(KINDS.get(ground, Kind.LAND))
		cliffs.append(cliff_material(ground))
		# Shaders work in linear space with HDR 2D.
		water.append(WATER_COLORS.get(ground, Color.BLACK).srgb_to_linear())
	material.set_shader_parameter("ground_priority", priority)
	material.set_shader_parameter("ground_kind", kind)
	material.set_shader_parameter("cliff_material", cliffs)
	material.set_shader_parameter("water_colors", water)
