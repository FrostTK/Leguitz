class_name WorldViewport
extends Node
## Renders the 3D world in its own SubViewport and shows it on screen.
##
## Pixel-art mode (default): the world is rendered at art resolution (one
## texel per art pixel) and upscaled by an integer factor. The camera is
## snapped to whole texels so nothing shimmers; the leftover sub-texel
## offset slides the displayed image, so scrolling stays perfectly smooth.
## HD mode renders at full screen resolution instead (sharper lighting and
## effects, same pixel-art textures).

## Extra texels rendered around the screen (room for the sub-texel slide).
const MARGIN := 2
## Distance of the camera from the target along its view axis.
const CAMERA_DISTANCE := 80.0
## Depth range around the target that is drawn (terrain far above or below
## the player is out of view anyway).
const DEPTH_ABOVE := 50.0
const DEPTH_BELOW := 70.0
const FOLLOW_SHARPNESS := 10.0

var viewport := SubViewport.new()
var camera := Camera3D.new()
var display := Sprite2D.new()
## Screen pixels per art pixel.
var world_zoom := 4
var hd := false
## The point the camera looks at (3D).
var target := Vector3.ZERO

var _smoothed := Vector3.ZERO
var _has_position := false
var _render_scale := 4


func _ready() -> void:
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.use_taa = false
	viewport.positional_shadow_atlas_size = 2048
	add_child(viewport)

	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.rotation = Vector3(deg_to_rad(-Render3D.PITCH_DEGREES), 0.0, 0.0)
	camera.near = CAMERA_DISTANCE - DEPTH_ABOVE
	camera.far = CAMERA_DISTANCE + DEPTH_BELOW
	viewport.add_child(camera)

	display.texture = viewport.get_texture()
	display.centered = true
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(display)

	get_viewport().size_changed.connect(refresh_size)
	Settings.changed.connect(_on_settings_changed)
	refresh_size()


## Parent for every 3D node of the world.
func world_root() -> Node:
	return viewport


func refresh_size() -> void:
	var window := get_window()
	var screen := window.size
	world_zoom = Settings.effective_world_zoom(screen.y)
	hd = Settings.hd_rendering
	_render_scale = 1 if hd else world_zoom
	viewport.size = Vector2i(
		ceili(float(screen.x) / _render_scale) + MARGIN * 2,
		ceili(float(screen.y) / _render_scale) + MARGIN * 2
	)
	var texels_per_unit := Render3D.PIXELS_PER_UNIT * world_zoom / _render_scale
	camera.size = viewport.size.y / texels_per_unit
	display.scale = Vector2.ONE * (_render_scale / window.content_scale_factor)


## Size of the visible area in 3D units (width, height across the view).
func view_size() -> Vector2:
	var aspect := float(viewport.size.x) / maxf(1.0, float(viewport.size.y))
	return Vector2(camera.size * aspect, camera.size)


func snap_to_target() -> void:
	_smoothed = target
	_has_position = true


func _process(delta: float) -> void:
	if not _has_position:
		snap_to_target()
	_smoothed = _smoothed.lerp(target, 1.0 - exp(-FOLLOW_SHARPNESS * delta))
	var basis := camera.global_basis
	var u := _smoothed.dot(basis.x)
	var v := _smoothed.dot(basis.y)
	var w := _smoothed.dot(basis.z)
	var texel := 1.0 / (Render3D.PIXELS_PER_UNIT * world_zoom / _render_scale)
	var snapped_u := u
	var snapped_v := v
	if not hd:
		snapped_u = roundf(u / texel) * texel
		snapped_v = roundf(v / texel) * texel
	camera.global_position = (
		basis.x * snapped_u + basis.y * snapped_v + basis.z * (w + CAMERA_DISTANCE)
	)
	# Slide the image by the part of a texel the camera did not move.
	var slide := Vector2(u - snapped_u, -(v - snapped_v)) / texel
	var center := get_viewport().get_visible_rect().size / 2.0
	display.position = center - slide * display.scale


func _on_settings_changed(key: StringName) -> void:
	if key in [&"world_zoom", &"hd_rendering"]:
		refresh_size()
