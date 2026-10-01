class_name WorldView3D
extends Node3D
## Creates, rebuilds and recycles the 3D chunk views. Terrain meshes depend
## on neighbor chunks (faces on borders), so each arrival also schedules its
## neighbors. Builds run under a per-frame time budget, nearest first, so
## walking stays smooth while new chunks stream in.

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
## Chunk the camera is over: pending builds closest to it go first.
var focus := Vector2i.ZERO
var top_material := ShaderMaterial.new()
var face_material := ShaderMaterial.new()
var sprite_material := ShaderMaterial.new()

var _sprite_mesh := QuadMesh.new()
var _views: Dictionary[Vector2i, ChunkView3D] = {}
var _pool: Array[ChunkView3D] = []
## Chunks waiting for a build: true = terrain and sprites, false = terrain
## only (a neighbor changed its borders).
var _pending: Dictionary[Vector2i, bool] = {}


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
	sprite_material.set_shader_parameter("sprite_px", Vector2(TileAtlas.BLOCK_CELL))
	sprite_material.set_shader_parameter("vertical_scale", Render3D.vertical_scale)


func show_chunk(chunk: ChunkData) -> void:
	if not _views.has(chunk.coord):
		var view: ChunkView3D = _pool.pop_back() if not _pool.is_empty() else _new_view()
		# Hidden until built (a recycled view still holds its old chunk).
		view.visible = false
		_views[chunk.coord] = view
	_pending[chunk.coord] = true
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var other := chunk.coord + Vector2i(dx, dy)
			if other != chunk.coord and _views.has(other) and not _pending.has(other):
				_pending[other] = false


## True when every chunk received so far has been built.
func is_up_to_date() -> bool:
	return _pending.is_empty()


func remove_chunk(key: Vector3i) -> void:
	var coord := Vector2i(key.x, key.y)
	var view: ChunkView3D = _views.get(coord)
	if view == null:
		return
	_views.erase(coord)
	_pending.erase(coord)
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


## Re-places the world-space lights after the world root turned.
func place_lights() -> void:
	for view: ChunkView3D in _views.values():
		view.place_lights()


func _process(_delta: float) -> void:
	var started := Time.get_ticks_msec()
	while not _pending.is_empty():
		var coord := _nearest_pending()
		var full := _pending[coord]
		_pending.erase(coord)
		var view: ChunkView3D = _views.get(coord)
		var chunk := _chunk(coord)
		if view != null and chunk != null:
			view.build_terrain(chunk, _chunk)
			if full:
				view.build_sprites(chunk)
			view.visible = true
		if Time.get_ticks_msec() - started > REBUILD_BUDGET_MS:
			break


func _nearest_pending() -> Vector2i:
	var best := Vector2i.ZERO
	var best_distance := 1 << 30
	for coord: Vector2i in _pending:
		var distance := (coord - focus).length_squared()
		if distance < best_distance:
			best = coord
			best_distance = distance
	return best


func _chunk(coord: Vector2i) -> ChunkData:
	return client_world.chunks.get(Vector3i(coord.x, coord.y, client_world.layer))


func _new_view() -> ChunkView3D:
	var view := ChunkView3D.new(top_material, face_material, _sprite_mesh)
	view.set_sprite_material(sprite_material)
	add_child(view)
	return view
