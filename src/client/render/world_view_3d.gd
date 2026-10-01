class_name WorldView3D
extends Node3D
## Creates, rebuilds and recycles the 3D chunk views. Chunk meshes are
## built on worker threads (ChunkMesher), nearest first; finished builds
## are shown under a per-frame time budget so walking stays smooth while
## new chunks stream in. Terrain meshes depend on neighbor chunks (faces on
## borders), so each arrival also rebuilds its neighbors.
##
## When the player is under cover (a cave, a tunnel, a roof), the view
## cuts the world above their head (see set_cut): caves show, and the top
## shader's surface maps are rebuilt for the cut.

const TOP_SHADER := preload("res://src/client/shaders/terrain3d_top.gdshader")
const FACE_SHADER := preload("res://src/client/shaders/terrain3d_faces.gdshader")
const FACE_ATLAS := preload("res://assets/textures/tiles/face_atlas.png")
const FACE_NORMALS := preload("res://assets/textures/tiles/face_atlas_n.png")
const FACE_EMISSION := preload("res://assets/textures/tiles/face_atlas_e.png")
const MAX_POOLED_VIEWS := 48
## Ground area (tiles²) up to which props keep full detail, then half.
const FULL_DETAIL_AREA := 8000.0
const HALF_DETAIL_AREA := 26000.0
## Milliseconds per frame spent showing finished builds.
const APPLY_BUDGET_MS := 6
## Builds running at once on the worker threads.
const MAX_JOBS := 24
## A chunk waits this many frames for its neighbors before being built
## anyway (each neighbor that comes later rebuilds it: border faces).
const NEIGHBOR_WAIT_FRAMES := 20

var client_world: ClientWorld
## Chunk the camera is over: pending builds closest to it go first.
var focus := Vector2i.ZERO
## Level of detail of the props (0 = full voxels, see set_lod).
var lod := 0
## Row the view cuts the world at (ChunkData.HEIGHT: no cut).
var cut_row := ChunkData.HEIGHT
var top_material := ShaderMaterial.new()
var face_material := ShaderMaterial.new()
var props := PropLibrary.new()

var _views: Dictionary[Vector2i, ChunkView3D] = {}
var _pool: Array[ChunkView3D] = []
## Chunks waiting for a build: true = full build, false = surface map only.
var _pending: Dictionary[Vector2i, bool] = {}
## Frame each pending chunk started waiting at.
var _pending_since: Dictionary[Vector2i, int] = {}
## Builds running: chunk -> worker task.
var _jobs: Dictionary[Vector2i, int] = {}
## Latest build asked for each chunk (older results are dropped).
var _serials: Dictionary[Vector2i, int] = {}
var _results: Array[ChunkMesher.Result] = []
var _results_mutex := Mutex.new()
var _variants := PackedByteArray()


func _ready() -> void:
	top_material.shader = TOP_SHADER
	TerrainRenderer.configure_top(top_material)
	face_material.shader = FACE_SHADER
	face_material.set_shader_parameter("face_atlas", FACE_ATLAS)
	face_material.set_shader_parameter("face_normals", FACE_NORMALS)
	face_material.set_shader_parameter("face_emission", FACE_EMISSION)
	face_material.set_shader_parameter("ground_atlas", TerrainRenderer.GROUND_ATLAS)
	face_material.set_shader_parameter("ground_normals", TerrainRenderer.GROUND_NORMALS)
	_variants.resize(256)
	for block: int in Tiles.Block.values():
		_variants[block] = props.variant_count(block)


func _exit_tree() -> void:
	wait_for_builds()


func show_chunk(chunk: ChunkData) -> void:
	if not _views.has(chunk.coord):
		var view: ChunkView3D = _pool.pop_back() if not _pool.is_empty() else _new_view()
		# Hidden until built (a recycled view still holds its old chunk).
		view.visible = false
		view.coord = chunk.coord
		_views[chunk.coord] = view
	_mark_pending(chunk.coord, true)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var other := chunk.coord + Vector2i(dx, dy)
			if other != chunk.coord and _views.has(other):
				_mark_pending(other, true)


## True when every chunk received so far is built and shown.
func is_up_to_date() -> bool:
	return _pending.is_empty() and _jobs.is_empty() and _results.is_empty()


func remove_chunk(coord: Vector2i) -> void:
	var view: ChunkView3D = _views.get(coord)
	if view == null:
		return
	_views.erase(coord)
	_pending.erase(coord)
	_pending_since.erase(coord)
	_serials.erase(coord)
	if _pool.size() < MAX_POOLED_VIEWS:
		view.visible = false
		_pool.append(view)
	else:
		view.queue_free()


func clear() -> void:
	for coord: Vector2i in _views.keys():
		remove_chunk(coord)


func visible_chunk_count() -> int:
	return _views.size()


## Zoomed far out, the props use coarser copies: far fewer triangles
## where there are many more of them on screen.
func set_lod(value: int) -> void:
	if value == lod:
		return
	lod = value
	for view: ChunkView3D in _views.values():
		view.set_props_lod(props, lod)


## Level of detail for the ground in view (tiles x tiles): full voxels
## for normal views, coarser copies when zoomed far out on a big screen
## (that many props at full detail would be tens of millions of triangles).
static func lod_for_view(ground: Vector2) -> int:
	var area := ground.x * ground.y
	if area <= FULL_DETAIL_AREA:
		return 0
	return 1 if area <= HALF_DETAIL_AREA else 2


## Cuts the world above `row` (ChunkData.HEIGHT: no cut): caves show and
## every surface map is rebuilt for the new cut.
func set_cut(row: int) -> void:
	if row == cut_row:
		return
	var was_cut := cut_row < ChunkData.HEIGHT
	cut_row = row
	var cut := cut_row < ChunkData.HEIGHT
	if cut != was_cut:
		for view: ChunkView3D in _views.values():
			view.show_caves(cut)
	for coord: Vector2i in _views:
		if not _pending.has(coord):
			_mark_pending(coord, false)


## Re-places the world-space lights after the world root turned.
func place_lights() -> void:
	for view: ChunkView3D in _views.values():
		view.place_lights()


## Blocks until the running builds are done (before quitting).
func wait_for_builds() -> void:
	for coord: Vector2i in _jobs:
		WorkerThreadPool.wait_for_task_completion(_jobs[coord])
	_jobs.clear()


func _process(_delta: float) -> void:
	_start_jobs()
	_apply_results()


func _start_jobs() -> void:
	var free_slots := MAX_JOBS - _jobs.size()
	if _pending.is_empty() or free_slots <= 0:
		return
	for coord in _nearest_pending(free_slots):
		var full := _pending[coord]
		_pending.erase(coord)
		_pending_since.erase(coord)
		var chunk := _chunk(coord)
		var view: ChunkView3D = _views.get(coord)
		if chunk == null or view == null:
			continue
		var job := ChunkMesher.Job.of_chunk(chunk, _chunk)
		job.variants = _variants
		job.cut_row = cut_row
		job.map_only = not full and view.visible
		job.serial = _serials.get(coord, 0) + 1
		_serials[coord] = job.serial
		_jobs[coord] = WorkerThreadPool.add_task(_build.bind(job), false, "Chunk mesh")


func _build(job: ChunkMesher.Job) -> void:
	var result := ChunkMesher.build(job)
	_results_mutex.lock()
	_results.append(result)
	_results_mutex.unlock()


func _apply_results() -> void:
	_results_mutex.lock()
	var finished := _results
	_results = []
	_results_mutex.unlock()
	var started := Time.get_ticks_msec()
	var left: Array[ChunkMesher.Result] = []
	for result in finished:
		var task: int = _jobs.get(result.coord, -1)
		if task >= 0 and WorkerThreadPool.is_task_completed(task):
			WorkerThreadPool.wait_for_task_completion(task)
			_jobs.erase(result.coord)
		if Time.get_ticks_msec() - started > APPLY_BUDGET_MS:
			left.append(result)
			continue
		var view: ChunkView3D = _views.get(result.coord)
		if view == null or result.serial != _serials.get(result.coord, -1):
			continue
		if result.map_only:
			view.apply_surface_map(result.surface_map)
		else:
			view.caves_shown = cut_row < ChunkData.HEIGHT
			view.apply(result, props, lod)
			view.visible = true
	if not left.is_empty():
		_results_mutex.lock()
		left.append_array(_results)
		_results = left
		_results_mutex.unlock()


## Up to `count` pending chunks closest to the focus, nearest first,
## skipping those still being built (they go again once done) and those
## still waiting for their neighbors.
func _nearest_pending(count: int) -> Array[Vector2i]:
	var best: Array[Vector2i] = []
	var distances := PackedInt32Array()
	var frame := Engine.get_process_frames()
	for coord: Vector2i in _pending:
		if _jobs.has(coord):
			continue
		var waited: int = frame - _pending_since.get(coord, frame)
		if waited < NEIGHBOR_WAIT_FRAMES and not _has_all_neighbors(coord):
			continue
		var distance := (coord - focus).length_squared()
		if best.size() == count and distance >= distances[count - 1]:
			continue
		var at := best.size()
		while at > 0 and distances[at - 1] > distance:
			at -= 1
		best.insert(at, coord)
		distances.insert(at, distance)
		if best.size() > count:
			best.pop_back()
			distances.resize(count)
	return best


func _mark_pending(coord: Vector2i, full: bool) -> void:
	_pending[coord] = full or _pending.get(coord, false)
	if not _pending_since.has(coord):
		_pending_since[coord] = Engine.get_process_frames()


func _has_all_neighbors(coord: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if not client_world.chunks.has(coord + Vector2i(dx, dy)):
				return false
	return true


func _chunk(coord: Vector2i) -> ChunkData:
	return client_world.chunks.get(coord)


func _new_view() -> ChunkView3D:
	var view := ChunkView3D.new(top_material, face_material)
	add_child(view)
	return view
