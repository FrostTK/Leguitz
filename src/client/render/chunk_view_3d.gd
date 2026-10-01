class_name ChunkView3D
extends Node3D
## One chunk in the 3D world (local units, under the stretched world root):
## the terrain mesh (tops + faces), its 3D props (trees, plants, rocks...:
## one MultiMesh per model) and the warm lights of its lava pools.

const LAVA_LIGHT_COLOR := Color(1.0, 0.45, 0.15)
const LAVA_LIGHT_RANGE := 7.0
## Small plants stand anywhere in their tile (whole voxels), not centered.
const WANDERING := {
	Tiles.Block.TALL_GRASS: true,
	Tiles.Block.FERN: true,
	Tiles.Block.DEAD_BUSH: true,
	Tiles.Block.FLOWER_RED: true,
	Tiles.Block.FLOWER_YELLOW: true,
	Tiles.Block.FLOWER_BLUE: true,
	Tiles.Block.FLOWER_WHITE: true,
	Tiles.Block.FLOWER_PINK: true,
	Tiles.Block.MUSHROOM_RED: true,
	Tiles.Block.MUSHROOM_BROWN: true,
	Tiles.Block.LILY_PAD: true,
	Tiles.Block.ROCK: true,
	Tiles.Block.MOSSY_ROCK: true,
}
## Flat on the water: no shadow worth drawing.
const NO_SHADOW := {Tiles.Block.LILY_PAD: true}
## Lava lights are placed per 8x8 quarter of the chunk.
const LAVA_QUARTER := 8

var coord := Vector2i.ZERO
var terrain := MeshInstance3D.new()
var top_material: ShaderMaterial
var face_material: ShaderMaterial

var _data_image := Image.create(
	TerrainRenderer.DATA_SIZE, TerrainRenderer.DATA_SIZE, false, Image.FORMAT_RGBAF
)
var _data_texture := ImageTexture.create_from_image(_data_image)
var _props: Array[MultiMeshInstance3D] = []
## (block, variant) shown by each prop node in use.
var _prop_keys: Array[Vector2i] = []
var _lava_lights: Array[OmniLight3D] = []
## Local positions of the lava lights in use (lights do not support the
## root's stretch, so they are placed in world space).
var _lava_spots: Array[Vector3] = []


func _init(base_top_material: ShaderMaterial, faces: ShaderMaterial) -> void:
	top_material = base_top_material.duplicate()
	top_material.set_shader_parameter("chunk_data", _data_texture)
	face_material = faces
	add_child(terrain)


## Rebuilds the terrain (mesh + transition data). Cheap enough to redo when
## a neighbor arrives (borders change).
func build_terrain(chunk: ChunkData, neighbor: Callable) -> void:
	coord = chunk.coord
	position = Render3D.world_px_to_local(Coords.chunk_to_world(coord), 0.0)
	var mesh := ChunkMesher.build(chunk, neighbor)
	mesh.surface_set_material(0, top_material)
	mesh.surface_set_material(1, face_material)
	terrain.mesh = mesh
	var values := TerrainRenderer.build_data(chunk, neighbor)
	_data_image.set_data(
		TerrainRenderer.DATA_SIZE,
		TerrainRenderer.DATA_SIZE,
		false,
		Image.FORMAT_RGBAF,
		values.to_byte_array()
	)
	_data_texture.update(_data_image)
	top_material.set_shader_parameter("chunk_origin_px", Coords.chunk_to_world(coord))


## Places the 3D props (trees, plants, rocks...) of the chunk, grouped by
## model. Each gets a variant, a quarter turn and a slight tint from its
## tile, so the same seed always grows the same forest.
func build_props(chunk: ChunkData, library: PropLibrary, lod: int) -> void:
	var groups: Dictionary[Vector2i, Array] = {}
	var origin := Coords.chunk_origin_tile(coord)
	for index in GameConst.CHUNK_AREA:
		var block := chunk.blocks[index]
		var variants := library.variant_count(block)
		if variants == 0:
			continue
		var local := Vector2i(index % GameConst.CHUNK_SIZE, index / GameConst.CHUNK_SIZE)
		var tile := origin + local
		var h := HashUtil.hash2(0x9A0B, tile.x, tile.y)
		var foot := Render3D.tile_center_local(
			local, Render3D.surface_height(chunk.ground[index], chunk.levels[index])
		)
		if WANDERING.has(block):
			foot.x += ((h >> 8) % 7 - 3) / 16.0
			foot.z += ((h >> 12) % 7 - 3) / 16.0
		var turn := Basis(Vector3.UP, ((h >> 4) & 3) * PI * 0.5)
		var shade := 0.93 + ((h >> 16) & 15) / 15.0 * 0.14
		var warmth := 0.97 + ((h >> 20) & 7) / 7.0 * 0.06
		var custom := Color(shade * warmth, shade, shade / warmth, ((h >> 24) & 255) / 255.0)
		var key := Vector2i(block, h % variants)
		if not groups.has(key):
			groups[key] = []
		groups[key].append([Transform3D(turn, foot), custom])
	var used := 0
	_prop_keys.clear()
	for key: Vector2i in groups:
		var node := _prop_node(used, library)
		used += 1
		_prop_keys.append(key)
		var entries: Array = groups[key]
		var multimesh := node.multimesh
		multimesh.instance_count = 0
		multimesh.mesh = library.mesh(key.x, key.y, lod)
		multimesh.instance_count = entries.size()
		for n in entries.size():
			multimesh.set_instance_transform(n, entries[n][0])
			multimesh.set_instance_custom_data(n, entries[n][1])
		node.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if NO_SHADOW.has(key.x)
			else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		)
		node.visible = true
	for i in range(used, _props.size()):
		_props[i].visible = false
		_props[i].multimesh.instance_count = 0
	_place_lava_lights(chunk)


## Swaps the props for their finer or coarser copies (zoom changed).
func set_props_lod(library: PropLibrary, lod: int) -> void:
	for i in _prop_keys.size():
		var key := _prop_keys[i]
		_props[i].multimesh.mesh = library.mesh(key.x, key.y, lod)


func _prop_node(index: int, library: PropLibrary) -> MultiMeshInstance3D:
	while _props.size() <= index:
		var node := MultiMeshInstance3D.new()
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_custom_data = true
		node.multimesh = multimesh
		node.material_override = library.material
		add_child(node)
		_props.append(node)
	return _props[index]


## Lava lights up its surroundings: one warm light per lava-rich quarter.
func _place_lava_lights(chunk: ChunkData) -> void:
	_lava_spots.clear()
	for qy in 2:
		for qx in 2:
			var sum := Vector2.ZERO
			var count := 0
			for ly in range(qy * LAVA_QUARTER, (qy + 1) * LAVA_QUARTER):
				for lx in range(qx * LAVA_QUARTER, (qx + 1) * LAVA_QUARTER):
					if chunk.ground[ly * GameConst.CHUNK_SIZE + lx] == Tiles.Ground.LAVA:
						sum += Vector2(lx + 0.5, ly + 0.5)
						count += 1
			if count < 3:
				continue
			var light := _lava_light(_lava_spots.size())
			var center := sum / count
			var level: int = chunk.levels[int(center.y) * GameConst.CHUNK_SIZE + int(center.x)]
			_lava_spots.append(Vector3(center.x, level + 1.0, center.y))
			light.light_energy = clampf(0.8 + count * 0.05, 0.8, 2.2)
			light.visible = true
	for i in range(_lava_spots.size(), _lava_lights.size()):
		_lava_lights[i].visible = false
	place_lights()


## Puts the lava lights at their place in the world (call again when the
## world root turns).
func place_lights() -> void:
	if not is_inside_tree():
		return
	for i in _lava_spots.size():
		_lava_lights[i].global_position = global_transform * _lava_spots[i]


func _lava_light(index: int) -> OmniLight3D:
	while _lava_lights.size() <= index:
		var light := OmniLight3D.new()
		light.light_color = LAVA_LIGHT_COLOR
		light.omni_range = LAVA_LIGHT_RANGE
		light.omni_attenuation = 1.4
		light.top_level = true
		add_child(light)
		_lava_lights.append(light)
	return _lava_lights[index]
