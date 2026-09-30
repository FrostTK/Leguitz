class_name WorldView
extends Node2D
## Creates, recycles and removes chunk visuals as chunks arrive and leave,
## and keeps each chunk's terrain data (including its neighbors' borders)
## up to date.

const MAX_POOLED_VIEWS := 64
const SWAY_SHADER := preload("res://src/client/shaders/sway.gdshader")
const SHADOW_SHADER := preload("res://src/client/shaders/shadow.gdshader")

@export var terrain_root: Node2D
@export var shadow_root: Node2D
@export var entity_root: Node2D
## Canvas layer above the lit world for glowing things (not darkened).
@export var emission_root: Node2D

var renderer := TerrainRenderer.new()
var sway_material := ShaderMaterial.new()
var shadow_material := ShaderMaterial.new()
var client_world: ClientWorld

var _tile_set := TileAtlas.build_tile_set()
var _views: Dictionary[Vector2i, ChunkView] = {}
var _pool: Array[ChunkView] = []
var _materials := {}
var _roots := {}


func _ready() -> void:
	var cells := Vector2(TileAtlas.BLOCK_COLUMNS, TileAtlas.block_rows())
	sway_material.shader = SWAY_SHADER
	sway_material.set_shader_parameter("cells", cells)
	sway_material.set_shader_parameter("cell_px", Vector2(TileAtlas.BLOCK_CELL))
	shadow_material.shader = SHADOW_SHADER
	shadow_material.set_shader_parameter("cells", cells)
	shadow_material.set_shader_parameter("block_px", Vector2(TileAtlas.BLOCK_CELL))
	shadow_material.set_shader_parameter("shadow_px", Vector2(TileAtlas.SHADOW_CELL))
	shadow_material.set_shader_parameter("block_atlas", TileAtlas.BLOCK_TEXTURE)
	_materials = {
		"terrain": renderer.terrain_material,
		"emission": renderer.emission_material,
		"sway": sway_material,
		"shadow": shadow_material,
	}
	_roots = {
		"terrain": terrain_root,
		"shadow": shadow_root,
		"entities": entity_root,
		"emission": emission_root,
	}


func show_chunk(chunk: ChunkData) -> void:
	var view: ChunkView = _views.get(chunk.coord)
	if view == null:
		view = _pool.pop_back() if not _pool.is_empty() else _new_view()
		_views[chunk.coord] = view
	view.show_chunk(chunk)
	# This chunk's data, then its neighbors' borders which now know it.
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			_refresh_terrain(chunk.coord + Vector2i(dx, dy))


func remove_chunk(key: Vector3i) -> void:
	var coord := Vector2i(key.x, key.y)
	var view: ChunkView = _views.get(coord)
	if view == null:
		return
	_views.erase(coord)
	if _pool.size() < MAX_POOLED_VIEWS:
		view.hide_chunk()
		_pool.append(view)
	else:
		view.free_nodes()


func clear() -> void:
	for coord: Vector2i in _views.keys():
		remove_chunk(Vector3i(coord.x, coord.y, 0))


func visible_chunk_count() -> int:
	return _views.size()


## Wind and rain for the plant and terrain shaders.
func set_weather(wind: Vector2, wetness: float, rain: float) -> void:
	sway_material.set_shader_parameter("wind_strength", wind.length())
	renderer.set_weather(wetness, rain, wind)


## Sun direction for projected shadows; strength 0 hides them.
func set_sun_shadows(offset: Vector2, strength: float) -> void:
	shadow_material.set_shader_parameter("sun", offset)
	shadow_material.set_shader_parameter("strength", strength)
	shadow_root.visible = strength > 0.001


func _refresh_terrain(coord: Vector2i) -> void:
	var view: ChunkView = _views.get(coord)
	var chunk := _chunk(coord)
	if view == null or chunk == null:
		return
	view.set_terrain_data(TerrainRenderer.build_data(chunk, _chunk))


func _chunk(coord: Vector2i) -> ChunkData:
	return client_world.chunks.get(Vector3i(coord.x, coord.y, client_world.layer))


func _new_view() -> ChunkView:
	var view := ChunkView.new(_tile_set, _materials)
	view.attach(_roots)
	return view
