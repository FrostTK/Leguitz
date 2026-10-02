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
##
## The camera orbits around its target: `yaw` turns around the vertical
## axis, `pitch` tilts between Render3D.MIN_PITCH and MAX_PITCH. It can
## also dive into the player's head for the first-person view (see
## first_person and dive_frame): a perspective camera there, without the
## texel snapping.

## Extra texels rendered around the screen (room for the sub-texel slide).
const MARGIN := 2
## Depth drawn above and below the ground around the target: terrain far
## above the player is out of view anyway; below, the view reaches the
## bottom of the world (it closes the rock seen through the view cut).
const DEPTH_ABOVE := 50.0
const DEPTH_BELOW := 240.0
## How fast the view catches up with orbit changes.
const ORBIT_SHARPNESS := 18.0
## First-person camera: vertical field of view (degrees) and depth range.
const FIRST_PERSON_FOV := 70.0
## First person, zoomed in (InputBindings.ZOOM_VIEW held).
const ZOOM_FOV := 20.0
## How fast the zoom comes and goes.
const ZOOM_SHARPNESS := 14.0
const FIRST_PERSON_NEAR := 0.05
const FIRST_PERSON_FAR := 240.0
## The dive starts with a nearly orthographic perspective (this narrow
## field of view, from far away) and closes in on the player's head (this
## much height in view, in world units) before entering it.
const DIVE_START_FOV := 1.0
const DIVE_END_HEIGHT := 1.6

var viewport := SubViewport.new()
var camera := Camera3D.new()
var display := Sprite2D.new()
## Screen pixels per art pixel.
var world_zoom := 4
var hd := false
## The point the camera looks at (3D world space; the caller smooths it).
var target := Vector3.ZERO
## Orbit angles (radians) the camera is heading to, and its current ones.
var yaw := 0.0
var pitch := deg_to_rad(Render3D.DEFAULT_PITCH)
var current_yaw := 0.0
var current_pitch := deg_to_rad(Render3D.DEFAULT_PITCH)
## Distance of the camera from the target along its view axis: it backs
## away when the view is larger or flatter, so nothing gets clipped.
var camera_distance := 80.0
## 0 = top-down view, 1 = first person, in between during the dive.
var first_person := 0.0
## First-person eye (world space) and look angles (radians: `look_pitch`
## > 0 looks up).
var eye := Vector3.ZERO
var look_yaw := 0.0
var look_pitch := 0.0
## First person: how far it is zoomed in (0: not at all, 1: ZOOM_FOV).
var zoom := 0.0

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
	camera.basis = Basis.from_euler(Vector3(-current_pitch, current_yaw, 0.0))
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


## Size of the ground in view, in tiles: across the screen and along the
## camera's view on the ground (before turning by the yaw).
func ground_size() -> Vector2:
	var size := view_size()
	var depth := size.y / sin(current_pitch) / Render3D.depth_stretch(current_pitch)
	return Vector2(size.x, depth)


## While the game is paused the world does not move: keep showing the
## last frame instead of drawing it again and again.
func set_paused(paused: bool) -> void:
	viewport.render_target_update_mode = (
		SubViewport.UPDATE_DISABLED if paused else SubViewport.UPDATE_ALWAYS
	)


## Draws one frame while paused (a setting changed the look).
func request_frame() -> void:
	if viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## Turns the camera around the target (radians).
func orbit(delta_yaw: float, delta_pitch: float) -> void:
	yaw = wrapf(yaw + delta_yaw, -PI, PI)
	# Keep the current angle on the same turn as the target.
	current_yaw = yaw - wrapf(yaw - current_yaw, -PI, PI)
	pitch = clampf(
		pitch + delta_pitch, deg_to_rad(Render3D.MIN_PITCH), deg_to_rad(Render3D.MAX_PITCH)
	)


## Puts the camera at an orbit angle right away (degrees).
func set_orbit_degrees(yaw_degrees: float, pitch_degrees: float) -> void:
	yaw = 0.0
	pitch = deg_to_rad(Render3D.DEFAULT_PITCH)
	orbit(deg_to_rad(yaw_degrees), deg_to_rad(pitch_degrees) - pitch)
	current_yaw = yaw
	current_pitch = pitch


## Back to the default view (north up, pixel-perfect angle).
func reset_orbit() -> void:
	orbit(-yaw, deg_to_rad(Render3D.DEFAULT_PITCH) - pitch)


## Moves the current orbit angles towards the wanted ones. Called by the
## client before it places the world (the world root follows the yaw).
func update_orbit(delta: float) -> void:
	var turn := 1.0 - exp(-ORBIT_SHARPNESS * delta)
	current_yaw = lerpf(current_yaw, yaw, turn)
	current_pitch = lerpf(current_pitch, pitch, turn)
	if absf(current_yaw - yaw) < 0.0005 and absf(current_pitch - pitch) < 0.0005:
		current_yaw = yaw
		current_pitch = pitch


## Distance from the camera to the ground at the top of the screen (at the
## target's height).
func far_ground_distance() -> float:
	return camera_distance + _ground_spread()


## How much farther (and closer) than the target the ground at the top
## (and bottom) of the screen is.
func _ground_spread() -> float:
	return camera.size * 0.5 / tan(current_pitch)


## Eases the first-person zoom towards `to` (0 or 1).
func zoom_towards(to: float, delta: float) -> void:
	zoom = lerpf(zoom, to, 1.0 - exp(-ZOOM_SHARPNESS * delta))
	if absf(zoom - to) < 0.002:
		zoom = to


## How much slower looking around turns the eye at the current zoom (the
## view moves on screen as fast as unzoomed).
func look_scale() -> float:
	return lerpf(FIRST_PERSON_FOV, ZOOM_FOV, zoom) / FIRST_PERSON_FOV


## Camera of the dive between the top-down view and the first-person one.
## `amount` 0: the top-down view (`top_basis`), seen through a nearly
## orthographic perspective showing `view_height` units at `target`;
## 1: at `eye`, looking along `look_basis`. Depths in front of the target
## (`front`) and behind it (`back`) stay in view. Returns [Transform3D,
## field of view (degrees), near, far].
static func dive_frame(
	amount: float,
	top_basis: Basis,
	target: Vector3,
	view_height: float,
	look_basis: Basis,
	eye_position: Vector3,
	front: float,
	back: float
) -> Array:
	var a := smoothstep(0.0, 1.0, amount)
	var basis := top_basis.slerp(look_basis, a)
	var fov := lerpf(DIVE_START_FOV, FIRST_PERSON_FOV, a)
	# The height in view shrinks steadily (in ratio) down to the head.
	var height := view_height * pow(DIVE_END_HEIGHT / view_height, a)
	var distance := height / (2.0 * tan(deg_to_rad(fov) * 0.5))
	var end_distance := DIVE_END_HEIGHT / (2.0 * tan(deg_to_rad(FIRST_PERSON_FOV) * 0.5))
	# Ends looking at a point just ahead of the eye, from the eye.
	var focus := target.lerp(eye_position - look_basis.z * end_distance, a)
	var near := lerpf(maxf(FIRST_PERSON_NEAR, distance - front), FIRST_PERSON_NEAR, a)
	var far := distance + lerpf(back, FIRST_PERSON_FAR, a)
	return [Transform3D(basis, focus + basis.z * distance), fov, near, far]


func _process(_delta: float) -> void:
	var spread := _ground_spread()
	camera_distance = DEPTH_ABOVE + spread + 10.0
	var top_basis := Basis.from_euler(Vector3(-current_pitch, current_yaw, 0.0))
	var center := get_viewport().get_visible_rect().size / 2.0
	if first_person > 0.0:
		var look_basis := Basis.from_euler(Vector3(look_pitch, look_yaw, 0.0))
		var frame := dive_frame(
			first_person,
			top_basis,
			target,
			camera.size,
			look_basis,
			eye,
			camera_distance - 1.0,
			spread + DEPTH_BELOW
		)
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.global_transform = frame[0]
		camera.fov = lerpf(frame[1], ZOOM_FOV, zoom)
		camera.near = frame[2]
		camera.far = frame[3]
		display.position = center
		return
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.basis = top_basis
	camera.near = 1.0
	camera.far = camera_distance + spread + DEPTH_BELOW
	var u := target.dot(top_basis.x)
	var v := target.dot(top_basis.y)
	var w := target.dot(top_basis.z)
	var texel := 1.0 / (Render3D.PIXELS_PER_UNIT * world_zoom / _render_scale)
	var snapped_u := u
	var snapped_v := v
	if not hd:
		snapped_u = roundf(u / texel) * texel
		snapped_v = roundf(v / texel) * texel
	camera.global_position = (
		top_basis.x * snapped_u + top_basis.y * snapped_v + top_basis.z * (w + camera_distance)
	)
	# Slide the image by the part of a texel the camera did not move.
	var slide := Vector2(u - snapped_u, -(v - snapped_v)) / texel
	display.position = center - slide * display.scale


func _on_settings_changed(key: StringName) -> void:
	if key in [&"world_zoom", &"hd_rendering"]:
		refresh_size()
	request_frame()
