class_name WorldView3D
extends Node3D
## Creates, rebuilds and recycles the 3D chunk views. Terrain meshes depend
## on neighbor chunks (faces on borders), so each arrival also schedules its
## neighbors; rebuilds run under a per-frame time budget to stay smooth.

const TOP_SHADER := preload("res://src/client/shaders/terrain3d_top.gdshader")
const FACE_SHADER := preload("res://src/client/shaders/terrain3d_faces.gdshader")
const SPRITE_SHADER := preload("res://src/client/shaders/sprite3d.gdshader")
const FACE_ATLAS := preload("res://assets/textures/tiles/face_atlas.png")
const FACE_NORMALS := preload("res://assets/textures/tiles/face_atlas_n.png")
const FACE_EMISSION := preload("res://assets/textures/tiles/face_atlas_e.png")
const MAX_POOLED_VIEWS := 48
## Milliseconds per frame spent rebuilding chunk meshes.
const REBUILD_BUDGET_MS := 6

var client_world: ClientWorld
var top_material := ShaderMaterial.new()
var face_material := ShaderMaterial.new()
var sprite_material := ShaderMaterial.new()

var _sprite_mesh := QuadMesh.new()
var _views: Dictionary[Vector2i, ChunkView3D] = {}
var _pool: Array[ChunkView3D] = []
var _pending_terrain: Dictionary[Vector2i, bool] = {}


func _ready() -> void:
	top_material.shader = TOP_SHADER
	TerrainRenderer.configure_top(top_material)
	face_material.shader = FACE_SHADER
	face_material.set_shader_parameter("face_atlas", FACE_ATLAS)
	face_material.set_shader_parameter("face_normals", FACE_NORMALS)
	face_material.set_shader_parameter("face_emission", FACE_EMISSION)
	face_material.set_shader_parameter("ground_atlas", TerrainRenderer.GROUND_ATLAS)
	face_material.set_shader_parameter("ground_normals", TerrainRenderer.GROUND_NORMALS)
	sprite_material.shader = SPRITE_SHADER
	sprite_material.set_shader_parameter("atlas", TileAtlas.BLOCK_TEXTURE)
	sprite_material.set_shader_parameter("atlas_normals", TileAtlas.BLOCK_NORMALS)
	sprite_material.set_shader_parameter(
		"cells", Vector2(TileAtlas.BLOCK_COLUMNS, TileAtlas.block_rows())
	)
	sprite_material.set_shader_parameter("sprite_width_px", float(TileAtlas.BLOCK_CELL.x))


func show_chunk(chunk: ChunkData) -> void:
	var view: ChunkView3D = _views.get(chunk.coord)
	if view == null:
		view = _pool.pop_back() if not _pool.is_empty() else _new_view()
		_views[chunk.coord] = view
	view.visible = true
	view.build_sprites(chunk)
	# Its own terrain now, the neighbors' borders a bit later.
	view.build_terrain(chunk, _chunk)
	_pending_terrain.erase(chunk.coord)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var other := chunk.coord + Vector2i(dx, dy)
			if other != chunk.coord and _views.has(other):
				_pending_terrain[other] = true


func remove_chunk(key: Vector3i) -> void:
	var coord := Vector2i(key.x, key.y)
	var view: ChunkView3D = _views.get(coord)
	if view == null:
		return
	_views.erase(coord)
	_pending_terrain.erase(coord)
	if _pool.size() < MAX_POOLED_VIEWS:
		view.visible = false
		_pool.append(view)
	else:
		view.queue_free()


func clear() -> void:
	for coord: Vector2i in _views.keys():
		remove_chunk(Vector3i(coord.x, coord.y, 0))


func visible_chunk_count() -> int:
	return _views.size()


func _process(_delta: float) -> void:
	if _pending_terrain.is_empty():
		return
	var started := Time.get_ticks_msec()
	for coord: Vector2i in _pending_terrain.keys():
		_pending_terrain.erase(coord)
		var view: ChunkView3D = _views.get(coord)
		var chunk := _chunk(coord)
		if view != null and chunk != null:
			view.build_terrain(chunk, _chunk)
		if Time.get_ticks_msec() - started > REBUILD_BUDGET_MS:
			break


func _chunk(coord: Vector2i) -> ChunkData:
	return client_world.chunks.get(Vector3i(coord.x, coord.y, client_world.layer))


func _new_view() -> ChunkView3D:
	var view := ChunkView3D.new(top_material, face_material, _sprite_mesh)
	view.set_sprite_material(sprite_material)
	add_child(view)
	return view
