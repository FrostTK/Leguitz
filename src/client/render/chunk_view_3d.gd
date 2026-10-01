class_name ChunkView3D
extends Node3D
## One chunk in the 3D world: the terrain mesh (tops + faces), its upright
## sprites (one MultiMesh) and the warm lights of its lava pools.

const LAVA_LIGHT_COLOR := Color(1.0, 0.45, 0.15)
const LAVA_LIGHT_RANGE := 6.0
## Lava lights are placed per 8x8 quarter of the chunk.
const LAVA_QUARTER := 8

var coord := Vector2i.ZERO
var terrain := MeshInstance3D.new()
var sprites := MultiMeshInstance3D.new()
var top_material: ShaderMaterial
var face_material: ShaderMaterial

var _data_image := Image.create(
	TerrainRenderer.DATA_SIZE, TerrainRenderer.DATA_SIZE, false, Image.FORMAT_RGBAF
)
var _data_texture := ImageTexture.create_from_image(_data_image)
var _lava_lights: Array[OmniLight3D] = []


func _init(base_top_material: ShaderMaterial, faces: ShaderMaterial, sprite_mesh: Mesh) -> void:
	top_material = base_top_material.duplicate()
	top_material.set_shader_parameter("chunk_data", _data_texture)
	face_material = faces
	add_child(terrain)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = sprite_mesh
	sprites.multimesh = multimesh
	add_child(sprites)


func set_sprite_material(material: ShaderMaterial) -> void:
	sprites.material_override = material


## Rebuilds the terrain (mesh + transition data). Cheap enough to redo when
## a neighbor arrives (borders change).
func build_terrain(chunk: ChunkData, neighbor: Callable) -> void:
	coord = chunk.coord
	position = Render3D.world_px_to_3d(Coords.chunk_to_world(coord), 0.0)
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


## Places the upright sprites (plants, trees, props) of the chunk.
func build_sprites(chunk: ChunkData) -> void:
	var entries: Array[Array] = []
	for index in GameConst.CHUNK_AREA:
		var block := chunk.blocks[index]
		if block == Tiles.Block.AIR or TileAtlas.is_wall(block):
			continue
		entries.append([index, block])
	var multimesh := sprites.multimesh
	multimesh.instance_count = entries.size()
	var cell_size := Vector2(TileAtlas.BLOCK_CELL) / Render3D.PIXELS_PER_UNIT
	var scale := Vector3(cell_size.x, cell_size.y * Render3D.sprite_y_scale, 1.0)
	for n in entries.size():
		var index: int = entries[n][0]
		var block: int = entries[n][1]
		var local := Vector2i(index % GameConst.CHUNK_SIZE, index / GameConst.CHUNK_SIZE)
		var base := Render3D.surface_height(chunk.ground[index], chunk.levels[index])
		var position_3d := Render3D.tile_center_3d(local, base + scale.y * 0.5)
		multimesh.set_instance_transform(n, Transform3D(Basis.from_scale(scale), position_3d))
		var cell := TileAtlas.block_cell(block)
		var sway := 1.0 if TileAtlas.SWAYING.has(block) else 0.0
		var no_shadow := 1.0 if TileAtlas.NO_SHADOW.has(block) else 0.0
		multimesh.set_instance_custom_data(n, Color(cell.x, cell.y, sway, no_shadow))
	_place_lava_lights(chunk)


## Lava lights up its surroundings: one warm light per lava-rich quarter.
func _place_lava_lights(chunk: ChunkData) -> void:
	var used := 0
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
			var light := _lava_light(used)
			var center := sum / count
			light.position = Vector3(center.x, Render3D.LEVEL_HEIGHT, center.y * Render3D.z_stretch)
			light.light_energy = clampf(0.8 + count * 0.05, 0.8, 2.2)
			light.visible = true
			used += 1
	for i in range(used, _lava_lights.size()):
		_lava_lights[i].visible = false


func _lava_light(index: int) -> OmniLight3D:
	while _lava_lights.size() <= index:
		var light := OmniLight3D.new()
		light.light_color = LAVA_LIGHT_COLOR
		light.omni_range = LAVA_LIGHT_RANGE
		light.omni_attenuation = 1.4
		add_child(light)
		_lava_lights.append(light)
	return _lava_lights[index]
