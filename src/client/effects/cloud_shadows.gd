class_name CloudShadows
extends Node2D
## Cloud shadows over the visible part of the world.

const SHADER := preload("res://src/client/shaders/clouds.gdshader")
const MARGIN := 32.0

var camera: Camera2D
var _size := Vector2.ZERO
var _travel := 0.0
var _shader_material := ShaderMaterial.new()


func _ready() -> void:
	_shader_material.shader = SHADER
	material = _shader_material


## `wind` drives the drift, `coverage` (0..1) how cloudy, `strength` how dark.
func set_sky(wind: Vector2, coverage: float, strength: float) -> void:
	_shader_material.set_shader_parameter("wind", wind)
	_shader_material.set_shader_parameter("coverage", lerpf(0.72, 0.38, coverage))
	_shader_material.set_shader_parameter("strength", strength)


func _process(delta: float) -> void:
	if camera == null:
		return
	_travel += delta * 0.012
	_shader_material.set_shader_parameter("travel", _travel)
	var view := get_viewport_rect().size / camera.zoom + Vector2(MARGIN, MARGIN) * 2.0
	global_position = (camera.get_screen_center_position() - view / 2.0).floor()
	if view != _size:
		_size = view
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, _size), Color.WHITE)
