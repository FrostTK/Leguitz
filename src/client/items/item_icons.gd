class_name ItemIcons
extends Node
## Renders the icon of every item off screen, one per frame, into the
## ItemLibrary: its 3D model seen from above at an angle (flat items, like
## tools, turned to face it), lit from the upper left, on a transparent
## background. The icons already asked for (ItemLibrary.take_wanted: the
## hotbar's, an open screen's) come first; a dark one is marked so
## (DARK_LUMA).

const SIZE := 32
## An icon whose pixels are this dark on average (luma, 0..1) gets a halo
## on slots (ItemSlot.draw_stack): coal, stone, deepslate...
const DARK_LUMA := 0.3
## The view: turned and tilted like the icons of block games.
const VIEW_YAW := deg_to_rad(45.0)
const VIEW_PITCH := deg_to_rad(-32.0)

var library: ItemLibrary

var _viewport := SubViewport.new()
var _camera := Camera3D.new()
var _model := MeshInstance3D.new()
var _queue: Array[int] = []


func _ready() -> void:
	_viewport.size = Vector2i(SIZE, SIZE)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.basis = Basis.from_euler(Vector3(VIEW_PITCH, VIEW_YAW, 0.0))
	_viewport.add_child(_camera)
	var sun := DirectionalLight3D.new()
	sun.basis = Basis.from_euler(Vector3(deg_to_rad(-55.0), deg_to_rad(20.0), 0.0))
	sun.light_energy = 1.1
	_viewport.add_child(sun)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.8, 0.8, 0.85)
	environment.ambient_light_energy = 0.55
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_viewport.add_child(world_environment)
	_viewport.add_child(_model)
	for item in range(1, Items.Id.size()):
		_queue.append(item)
	_render_queue()


func _render_queue() -> void:
	while not _queue.is_empty():
		var item: int = library.take_wanted()
		if item != Items.Id.NONE and _queue.has(item):
			_queue.erase(item)
		else:
			item = _queue.pop_front()
		_model.mesh = library.mesh(item)
		var flat := ItemModels.is_flat(item)
		_model.rotation.y = VIEW_YAW if flat else 0.0
		var box := Transform3D(_model.basis, Vector3.ZERO) * _model.mesh.get_aabb()
		# Centered, filling most of the icon whatever the item's size (flat
		# items fill it up to their own outline).
		_model.position = -box.get_center()
		var radius := box.size.length() * 0.5
		_camera.size = radius * 2.0 * 1.04
		if flat:
			_camera.size = _outline_size(_model.mesh.get_aabb(), _model.basis) * 1.08
		_camera.position = _camera.basis.z * (radius + 2.0)
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		var image := _viewport.get_texture().get_image()
		library.set_icon(item, ImageTexture.create_from_image(image), luma(image) < DARK_LUMA)
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


## The width or height (the larger) of a model's box, turned by `turn`,
## as the camera sees it.
func _outline_size(box: AABB, turn: Basis) -> float:
	var right := _camera.basis.x
	var up := _camera.basis.y
	var low := Vector2.INF
	var high := -Vector2.INF
	for corner in 8:
		var point := turn * box.get_endpoint(corner)
		var seen := Vector2(point.dot(right), point.dot(up))
		low = low.min(seen)
		high = high.max(seen)
	var size := high - low
	return maxf(size.x, size.y)


## How light an icon's drawn pixels are on average (luma, 0..1; every
## other pixel is enough).
static func luma(image: Image) -> float:
	var total := 0.0
	var seen := 0
	for y in range(0, image.get_height(), 2):
		for x in range(0, image.get_width(), 2):
			var pixel := image.get_pixel(x, y)
			if pixel.a > 0.5:
				total += pixel.r * 0.2126 + pixel.g * 0.7152 + pixel.b * 0.0722
				seen += 1
	return total / seen if seen > 0 else 1.0
