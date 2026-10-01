class_name CloudShadows3D
extends MeshInstance3D
## Cloud shadows drifting over the land with the wind: an invisible plane
## above the camera target, casting shadows only.

const SHADER := preload("res://src/client/shaders/cloud_shadows.gdshader")
const ALTITUDE := 14.0
const SIZE := 260.0
## Cloud speed in tiles per second for a wind of strength 1.
const DRIFT_SPEED := 1.2

## The point the camera looks at (3D).
var target := Vector3.ZERO

var _material := ShaderMaterial.new()
var _wind := Vector2(1.0, 0.25)
var _drift := Vector2.ZERO


func _ready() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(SIZE, SIZE)
	mesh = plane
	_material.shader = SHADER
	_material.set_shader_parameter("z_stretch", Render3D.z_stretch)
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	# The plane is huge and above everything: never cull it.
	extra_cull_margin = 16384.0


func set_sky(wind: Vector2, coverage: float) -> void:
	_wind = wind
	_material.set_shader_parameter("coverage", coverage)


func _process(delta: float) -> void:
	_drift += _wind * DRIFT_SPEED * delta
	_material.set_shader_parameter("drift", _drift)
	position = Vector3(roundf(target.x), target.y + ALTITUDE, roundf(target.z))
