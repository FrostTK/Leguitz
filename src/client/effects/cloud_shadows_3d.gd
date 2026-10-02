class_name CloudShadows3D
extends MeshInstance3D
## Cloud shadows drifting over the land with the wind: an invisible plane
## above the camera target, casting shadows only. Lives under the world
## root (local tile units).

const SHADER := preload("res://src/client/shaders/cloud_shadows.gdshader")
const ALTITUDE := 7.0
const SIZE := 220.0
## Cloud speed in tiles per second for a wind of strength 1.
const DRIFT_SPEED := 1.2
## The noise's scale (per tile): the sky's clouds (sky.gdshader) use it too.
const CLOUD_SCALE := 0.03

## The point the camera looks at (local units).
var target := Vector3.ZERO
## How far the clouds drifted (tiles) and how much of the sky they cover
## (the sky's clouds follow them).
var drift := Vector2.ZERO
var coverage := 0.35

var _material := ShaderMaterial.new()
var _wind := Vector2(1.0, 0.25)


func _ready() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(SIZE, SIZE)
	mesh = plane
	_material.shader = SHADER
	_material.set_shader_parameter("cloud_scale", CLOUD_SCALE)
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	# The plane is huge and above everything: never cull it.
	extra_cull_margin = 16384.0


func set_sky(wind: Vector2, cover: float) -> void:
	_wind = wind
	coverage = cover
	_material.set_shader_parameter("coverage", cover)


func _process(delta: float) -> void:
	drift += _wind * DRIFT_SPEED * delta
	_material.set_shader_parameter("drift", drift)
	position = Vector3(roundf(target.x), target.y + ALTITUDE, roundf(target.z))
	_material.set_shader_parameter("plane_origin", Vector2(position.x, position.z))
