class_name ChunkView3D
extends Node3D
## One chunk in the 3D world (local units, under the stretched world root):
## its terrain as seen from the sky, its caves (shown when the view cuts
## the world above the player), the surface of its water (the ground under
## it shows through; it casts no shadow), its 3D props (trees, plants,
## rocks...: one MultiMesh per model) and the warm lights of its lava pools,
## fires, torches and lanterns (flames flicker). Built from a
## ChunkMesher.Result.

const LAVA_LIGHT_RANGE := 7.0
## How much a flame's light wavers (a share of its energy).
const FLICKER := 0.12
## Flat on the water: no shadow worth drawing.
const NO_SHADOW := {Tiles.Block.LILY_PAD: true}

var coord := Vector2i.ZERO
var terrain := MeshInstance3D.new()
var caves := MeshInstance3D.new()
var water := MeshInstance3D.new()
var cave_water := MeshInstance3D.new()
## The tops of building blocks cut by the view (ChunkMesher caps), shown
## while the view cuts the world.
var caps := MeshInstance3D.new()
var top_material: ShaderMaterial
## The top material for the caps (see caps).
var cap_material: ShaderMaterial
var face_material: ShaderMaterial
var water_material: ShaderMaterial
var caves_shown := false
## Level of detail of the props shown (see WorldView3D.lod_of).
var props_lod := 0

var _data_image := Image.create(
	TerrainRenderer.DATA_SIZE, TerrainRenderer.DATA_SIZE, false, Image.FORMAT_RGBAF
)
var _data_texture := ImageTexture.create_from_image(_data_image)
var _props: Array[MultiMeshInstance3D] = []
## (block, variant) shown by each prop node in use.
var _prop_keys: Array[Vector2i] = []
var _lava_lights: Array[OmniLight3D] = []
## Local positions of the lava lights in use (lights do not support the
## root's stretch, so they are placed in world space), and which are in
## caves.
var _lava_spots: Array[Vector3] = []
var _lava_deep: Array[bool] = []
## Each light's energy and how much it flickers; whether any does.
var _lava_energy: Array[float] = []
var _lava_flicker: Array[float] = []
var _flickers := false


func _init(
	base_top_material: ShaderMaterial, faces: ShaderMaterial, base_water_material: ShaderMaterial
) -> void:
	top_material = base_top_material.duplicate()
	top_material.set_shader_parameter("chunk_data", _data_texture)
	cap_material = top_material.duplicate()
	cap_material.set_shader_parameter("cap", true)
	face_material = faces
	water_material = base_water_material.duplicate()
	water_material.set_shader_parameter("chunk_data", _data_texture)
	add_child(terrain)
	add_child(caves)
	caves.visible = false
	for node in [water, cave_water, caps]:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
	cave_water.visible = false
	caps.visible = false


## Shows a finished build: terrain, caves, props and lava lights.
func apply(result: ChunkMesher.Result, library: PropLibrary, lod: int) -> void:
	coord = result.coord
	position = Render3D.world_px_to_local(Coords.chunk_to_world(coord), 0.0)
	top_material.set_shader_parameter("chunk_origin_px", Coords.chunk_to_world(coord))
	cap_material.set_shader_parameter("chunk_origin_px", Coords.chunk_to_world(coord))
	water_material.set_shader_parameter("chunk_origin_px", Coords.chunk_to_world(coord))
	apply_surface_map(result.surface_map)
	var parts := result.parts
	terrain.mesh = _mesh(parts[ChunkMesher.Part.TOPS], parts[ChunkMesher.Part.FACES])
	caves.mesh = _mesh(parts[ChunkMesher.Part.DEEP_TOPS], parts[ChunkMesher.Part.DEEP_FACES])
	water.mesh = _water_mesh(parts[ChunkMesher.Part.WATER])
	cave_water.mesh = _water_mesh(parts[ChunkMesher.Part.DEEP_WATER])
	apply_caps(parts[ChunkMesher.Part.CAPS])
	props_lod = lod
	_apply_props(result.props, library, lod)
	_lava_spots = result.lava_spots
	_lava_deep = result.lava_deep
	_lava_energy = result.lava_strength
	_lava_flicker = result.lava_flicker
	_flickers = _lava_flicker.any(func(amount: float) -> bool: return amount > 0.0)
	for i in _lava_spots.size():
		var light := _lava_light(i)
		light.light_energy = result.lava_strength[i]
		light.light_color = result.lava_colors[i]
	for i in range(_lava_spots.size(), _lava_lights.size()):
		_lava_lights[i].visible = false
	show_caves(caves_shown)
	place_lights()


## The flames' lights waver (`time`: seconds, the same for every chunk).
func flicker(time: float) -> void:
	if not _flickers:
		return
	for i in _lava_spots.size():
		var amount := _lava_flicker[i]
		if amount <= 0.0:
			continue
		var phase := _lava_spots[i].x * 1.7 + _lava_spots[i].z * 2.3
		var waver := sin(time * 9.0 + phase) * 0.6 + sin(time * 23.0 + phase * 2.1) * 0.4
		_lava_lights[i].light_energy = _lava_energy[i] * (1.0 + waver * FLICKER * amount)


## The caps of the building blocks cut by the view (the cut moved).
func apply_caps(surface: ChunkMesher.Surface) -> void:
	var mesh := ArrayMesh.new()
	if not surface.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface.arrays())
		mesh.surface_set_material(0, cap_material)
	caps.mesh = mesh


## New data for the top shader (the view cut moved).
func apply_surface_map(values: PackedFloat32Array) -> void:
	_data_image.set_data(
		TerrainRenderer.DATA_SIZE,
		TerrainRenderer.DATA_SIZE,
		false,
		Image.FORMAT_RGBAF,
		values.to_byte_array()
	)
	_data_texture.update(_data_image)


## Caves (and their lava lights) only show under cover or in first person:
## from the sky they are hidden under the terrain anyway.
func show_caves(shown: bool) -> void:
	caves_shown = shown
	caves.visible = shown
	cave_water.visible = shown
	for i in _lava_spots.size():
		_lava_lights[i].visible = shown or not _lava_deep[i]


## Swaps the props for their finer or coarser copies (zoom changed).
func set_props_lod(library: PropLibrary, lod: int) -> void:
	if lod == props_lod:
		return
	props_lod = lod
	for i in _prop_keys.size():
		var key := _prop_keys[i]
		_props[i].multimesh.mesh = library.mesh(key.x, key.y, lod)


## Puts the lava lights at their place in the world (call again when the
## world root turns).
func place_lights() -> void:
	if not is_inside_tree():
		return
	for i in _lava_spots.size():
		_lava_lights[i].global_position = global_transform * _lava_spots[i]


func _mesh(tops: ChunkMesher.Surface, faces: ChunkMesher.Surface) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if not tops.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tops.arrays())
		mesh.surface_set_material(mesh.get_surface_count() - 1, top_material)
	if not faces.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, faces.arrays())
		mesh.surface_set_material(mesh.get_surface_count() - 1, face_material)
	return mesh


func _water_mesh(surface: ChunkMesher.Surface) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if not surface.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface.arrays())
		mesh.surface_set_material(0, water_material)
	return mesh


## Places the props, grouped by model.
func _apply_props(groups: Dictionary[Vector2i, Array], library: PropLibrary, lod: int) -> void:
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


func _lava_light(index: int) -> OmniLight3D:
	while _lava_lights.size() <= index:
		var light := OmniLight3D.new()
		light.omni_range = LAVA_LIGHT_RANGE
		light.omni_attenuation = 1.4
		light.top_level = true
		add_child(light)
		_lava_lights.append(light)
	return _lava_lights[index]
