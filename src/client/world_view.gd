class_name WorldView
extends Node2D
## Creates, recycles and removes chunk visuals as chunks arrive and leave.

const MAX_POOLED_VIEWS := 64

@export var ground_root: Node2D
@export var entity_root: Node2D

var _tile_set := TileAtlas.build_tile_set()
var _views: Dictionary[Vector2i, ChunkView] = {}
var _pool: Array[ChunkView] = []


func show_chunk(chunk: ChunkData) -> void:
	var view: ChunkView = _views.get(chunk.coord)
	if view == null:
		view = _pool.pop_back() if not _pool.is_empty() else _new_view()
		_views[chunk.coord] = view
	view.show_chunk(chunk)


func remove_chunk(coord: Vector2i) -> void:
	var view: ChunkView = _views.get(coord)
	if view == null:
		return
	_views.erase(coord)
	if _pool.size() < MAX_POOLED_VIEWS:
		view.hide_chunk()
		_pool.append(view)
	else:
		view.free_nodes()


func visible_chunk_count() -> int:
	return _views.size()


func _new_view() -> ChunkView:
	var view := ChunkView.new(_tile_set)
	view.attach(ground_root, entity_root)
	return view
