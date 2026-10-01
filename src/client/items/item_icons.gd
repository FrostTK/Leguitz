class_name ItemIcons
extends Node
## Renders the icon of every item off screen, one per frame, into the
## ItemLibrary: its 3D model seen from above at an angle, lit from the
## upper left, on a transparent background.

const SIZE := 32
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
		var item: int = _queue.pop_front()
		_model.mesh = library.mesh(item)
		var box := _model.mesh.get_aabb()
		# Centered, filling most of the icon whatever the item's size.
		_model.position = -box.get_center()
		var radius := box.size.length() * 0.5
		_camera.size = radius * 2.0 * 1.04
		_camera.position = _camera.basis.z * (radius + 2.0)
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		var image := _viewport.get_texture().get_image()
		library.set_icon(item, ImageTexture.create_from_image(image))
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
