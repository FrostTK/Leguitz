class_name WorldView3D
extends Node3D
## Creates, rebuilds and recycles the 3D chunk views. Chunk meshes are
## built on worker threads (ChunkMesher), nearest first; finished builds
## are shown under a per-frame time budget so walking stays smooth while
## new chunks stream in. Terrain meshes depend on neighbor chunks (faces on
## borders), so each arrival also rebuilds its neighbors.
##
## When the player is under cover (a cave, a tunnel, a roof), the view
## cuts the world above their head (see set_view): caves show, and the top
## shader's surface maps are rebuilt for the cut.

const TOP_SHADER := preload("res://src/client/shaders/terrain3d_top.gdshader")
const FACE_SHADER := preload("res://src/client/shaders/terrain3d_faces.gdshader")
const WATER_SHADER := preload("res://src/client/shaders/water.gdshader")
const FACE_ATLAS := preload("res://assets/textures/tiles/face_atlas.png")
const FACE_NORMALS := preload("res://assets/textures/tiles/face_atlas_n.png")
const FACE_EMISSION := preload("res://assets/textures/tiles/face_atlas_e.png")
const MAX_POOLED_VIEWS := 48
## Ground area (tiles²) up to which props keep full detail, then half.
const FULL_DETAIL_AREA := 2500.0
const HALF_DETAIL_AREA := 12000.0
## Top-down view: props this far (tiles) out of the ground in view can
## still show in it: crowns spread over the sides, and the tallest trees
## rise into it from below the screen.
const VIEW_MARGIN_SIDES := 4.0
const VIEW_MARGIN_BELOW := 9.0
## First person: props keep full detail up to this distance (tiles, from
## the eye to the middle of their chunk), then half up to the next one.
const FIRST_PERSON_FULL_DETAIL := 20.0
const FIRST_PERSON_HALF_DETAIL := 40.0
## Reach of the props' detail per graphics quality (Low to Ultra): small
## graphics cards switch to the coarser copies sooner.
const DETAIL_BY_QUALITY: Array[float] = [0.5, 0.75, 1.0, 1.0]
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
## Where the player stands (tiles): first-person detail follows it.
var focus_tile := Vector2.ZERO
## Reach of the props' detail (see DETAIL_BY_QUALITY and set_detail).
var detail := 1.0
## Level of detail of the props (0 = full voxels, see set_lod).
var lod := 0
## First-person view: the props' detail follows each chunk's distance
## instead (see set_lod_by_distance).
var lod_by_distance := false
## Top-down view: the ground in view (tiles, see set_view_area).
var view_center := Vector2.ZERO
var view_half_size := Vector2.INF
var view_yaw := 0.0
## Row the top shader's surface maps are cut at (ChunkData.HEIGHT: none),
## and whether caves show (see set_view).
var cut_row := ChunkData.HEIGHT
var caves_shown := false
var top_material := ShaderMaterial.new()
var face_material := ShaderMaterial.new()
var water_material := ShaderMaterial.new()
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
## Position the props' distance-based detail was last set for.
var _lod_focus := Vector2.INF
## View area the props' detail was last set for (rounded, see set_view_area).
var _lod_area := PackedInt32Array()


func _ready() -> void:
	top_material.shader = TOP_SHADER
	TerrainRenderer.configure_top(top_material)
	water_material.shader = WATER_SHADER
	TerrainRenderer.configure_water(water_material)
	face_material.shader = FACE_SHADER
	face_material.set_shader_parameter("face_atlas", FACE_ATLAS)
	face_material.set_shader_parameter("face_normals", FACE_NORMALS)
	face_material.set_shader_parameter("face_emission", FACE_EMISSION)
	face_material.set_shader_parameter("see_through_walls", TileAtlas.clear_wall_flags())
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
	_refresh_lods()


## Reach of the props' detail (1 = normal, less = coarser copies sooner).
func set_detail(value: float) -> void:
	if value == detail:
		return
	detail = value
	_refresh_lods()


## In first person, near props keep full detail and far ones (small on
## screen) get coarser.
func set_lod_by_distance(enabled: bool) -> void:
	if enabled == lod_by_distance:
		return
	lod_by_distance = enabled
	_refresh_lods()


## Top-down view: the ground in view, a rectangle of `half_size` (tiles,
## across the screen and up it) around `center`, turned by the camera
## `yaw`. Props of chunks out of it only cast shadows into the view: they
## use their coarsest copies.
func set_view_area(center: Vector2, half_size: Vector2, yaw: float) -> void:
	view_center = center
	view_half_size = half_size
	view_yaw = yaw
	var area := PackedInt32Array(
		[
			roundi(center.x / 4.0),
			roundi(center.y / 4.0),
			roundi(half_size.x / 4.0),
			roundi(half_size.y / 4.0),
			roundi(yaw * 8.0)
		]
	)
	if area != _lod_area and not lod_by_distance:
		_lod_area = area
		_refresh_lods()


## Level of detail of the props of a chunk.
func lod_of(coord: Vector2i) -> int:
	if lod_by_distance:
		var size := float(GameConst.CHUNK_SIZE)
		var middle := (Vector2(coord) + Vector2.ONE * 0.5) * size
		var distance := middle.distance_to(focus_tile) / detail
		if distance <= FIRST_PERSON_FULL_DETAIL:
			return 0
		return 1 if distance <= FIRST_PERSON_HALF_DETAIL else VoxelModels.LODS - 1
	if not chunk_in_view(coord, view_center, view_half_size, view_yaw):
		return VoxelModels.LODS - 1
	return lod


## Whether props of a chunk can show in a top-down view of the ground
## around `center` (see set_view_area).
static func chunk_in_view(coord: Vector2i, center: Vector2, half_size: Vector2, yaw: float) -> bool:
	var size := float(GameConst.CHUNK_SIZE)
	var middle := (Vector2(coord) + Vector2.ONE * 0.5) * size
	var on_screen := Render3D.ground_to_screen(middle - center, yaw)
	# The chunk's own extent, whatever the turn.
	var extent := size * 0.71
	var sides := half_size.x + VIEW_MARGIN_SIDES + extent
	var above := half_size.y + VIEW_MARGIN_SIDES + extent
	var below := half_size.y + VIEW_MARGIN_BELOW + extent
	return absf(on_screen.x) <= sides and on_screen.y >= -above and on_screen.y <= below


## Level of detail for the ground in view (tiles x tiles): full voxels
## for normal views, coarser copies when zoomed far out on a big screen
## (that many props at full detail would be tens of millions of triangles).
## `reach` (see DETAIL_BY_QUALITY) shrinks the views kept at full detail.
static func lod_for_view(ground: Vector2, reach := 1.0) -> int:
	var area := ground.x * ground.y / (reach * reach)
	if area <= FULL_DETAIL_AREA:
		return 0
	return 1 if area <= HALF_DETAIL_AREA else 2


## Cuts the surface maps at `row` (ChunkData.HEIGHT: no cut; the shaders
## cut the world itself, see the `cut_height` global) and shows or hides
## the caves.
func set_view(row: int, caves: bool) -> void:
	if caves != caves_shown:
		caves_shown = caves
		for view: ChunkView3D in _views.values():
			view.show_caves(caves)
	if row == cut_row:
		return
	cut_row = row
	for coord: Vector2i in _views:
		if not _pending.has(coord):
			_mark_pending(coord, false)


## A voxel changed (mined, placed): its chunk is built again, and the
## neighbors whose border it lies on (their faces and surface maps see it).
func voxel_changed(cell: Vector3i) -> void:
	var touched := {}
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			touched[Coords.tile_to_chunk(Vector2i(cell.x + dx, cell.z + dy))] = true
	for coord: Vector2i in touched:
		if _views.has(coord):
			_mark_pending(coord, true)


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
	if lod_by_distance and focus_tile.distance_squared_to(_lod_focus) > 4.0:
		_refresh_lods()
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
			view.caves_shown = caves_shown
			view.apply(result, props, lod_of(result.coord))
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


func _refresh_lods() -> void:
	_lod_focus = focus_tile
	for coord: Vector2i in _views:
		_views[coord].set_props_lod(props, lod_of(coord))


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
	var view := ChunkView3D.new(top_material, face_material, water_material)
	add_child(view)
	return view
