class_name CameraRig
extends Camera2D
## Smooth follow camera that keeps pixel art crisp.
##
## The world is drawn at `world_zoom` screen pixels per art pixel (always
## an integer). The UI is scaled separately through the window's content
## scale factor, so the camera zoom compensates for it. The camera position
## is snapped to the screen pixel grid so tiles never shimmer while
## scrolling.

const FOLLOW_SHARPNESS := 10.0

@export var target: Node2D

var world_zoom := 4
var _smoothed := Vector2.ZERO
var _has_position := false


func _ready() -> void:
	# Run after the player has moved this frame.
	process_priority = 100
	get_viewport().size_changed.connect(refresh_zoom)
	Settings.changed.connect(_on_settings_changed)
	refresh_zoom()


func refresh_zoom() -> void:
	var window := get_window()
	world_zoom = Settings.effective_world_zoom(window.size.y)
	# Settings applies the UI scale on resize before this runs.
	zoom = Vector2.ONE * (world_zoom / window.content_scale_factor)


func snap_to_target() -> void:
	if target != null:
		_smoothed = target.global_position
		_has_position = true
		global_position = _snapped(_smoothed)


func _process(delta: float) -> void:
	if target == null:
		return
	if not _has_position:
		snap_to_target()
	var weight := 1.0 - exp(-FOLLOW_SHARPNESS * delta)
	_smoothed = _smoothed.lerp(target.global_position, weight)
	global_position = _snapped(_smoothed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputBindings.ZOOM_IN):
		Settings.set_world_zoom(world_zoom + 1)
	elif event.is_action_pressed(InputBindings.ZOOM_OUT):
		Settings.set_world_zoom(maxi(1, world_zoom - 1))


func _snapped(world_position: Vector2) -> Vector2:
	return (world_position * world_zoom).round() / world_zoom


func _on_settings_changed(key: StringName) -> void:
	if key == &"world_zoom":
		refresh_zoom()
