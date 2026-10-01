class_name PlayerModel
extends Node3D
## The player's 3D voxel body under the world root (local units): head,
## torso, arms and legs that swing while walking; it turns smoothly to face
## where it goes. Also carries the lantern (in world space: lights do not
## support the root's stretch).

const SHADER := preload("res://src/client/shaders/voxel.gdshader")
## Render layer of the body: the lantern it carries must not shadow it
## (only the sun and the moon do).
const PLAYER_LAYER := 2
const LANTERN_RANGE := 10.0
## Lantern height above the feet, in world units.
const LANTERN_HEIGHT := 4.6
## The chest (local units above the feet): what must stay visible.
const CHEST := Vector3(0, 0.9, 0)
const VOXEL := 1.0 / 16.0
const TURN_SHARPNESS := 14.0
## Strides per tile walked, and how far the limbs swing (radians).
const STRIDE := 0.9
const SWING := 0.75

var lantern := OmniLight3D.new()

var _body := Node3D.new()
var _arms: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _yaw := 0.0
var _phase := 0.0
var _swing := 0.0


func _ready() -> void:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("use_instance_data", false)
	material.set_shader_parameter("cut_out", false)
	add_child(_body)
	_part("torso", Vector3(0, 8, 0), _body, material)
	_part("head", Vector3(0, 16, 0), _body, material)
	for side: float in [-1.0, 1.0]:
		# Limbs hang from a pivot at the hip or the shoulder.
		var hip := Node3D.new()
		hip.position = Vector3(side * 2, 8, 0) * VOXEL
		_body.add_child(hip)
		_part("leg", Vector3(0, -8, 0), hip, material)
		_legs.append(hip)
		var shoulder := Node3D.new()
		shoulder.position = Vector3(side * 5, 16, 0) * VOXEL
		_body.add_child(shoulder)
		_part("arm", Vector3(0, -8, 0), shoulder, material)
		_arms.append(shoulder)

	lantern.top_level = true
	lantern.light_color = Color(1.0, 0.8, 0.52)
	lantern.omni_range = LANTERN_RANGE
	lantern.omni_attenuation = 1.0
	lantern.shadow_caster_mask = ~PLAYER_LAYER & 0xFFFFF
	lantern.light_energy = 0.0
	add_child(lantern)


## Places and animates the body. `feet` is local, `heading` the ground
## direction the player faces, `speed` tiles per second, `airborne` while
## jumping or falling.
func animate(feet: Vector3, heading: Vector2, speed: float, airborne: bool, delta: float) -> void:
	position = feet
	if heading != Vector2.ZERO:
		var target := atan2(heading.x, heading.y)
		_yaw = lerp_angle(_yaw, target, 1.0 - exp(-TURN_SHARPNESS * delta))
	_body.rotation.y = _yaw
	var walking := clampf(speed / 5.0, 0.0, 1.0)
	_phase += delta * speed * STRIDE * TAU / 2.0
	_swing = lerpf(_swing, walking * SWING, 1.0 - exp(-10.0 * delta))
	var stride := sin(_phase) * _swing
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		_legs[i].rotation.x = stride * side
		_arms[i].rotation.x = -stride * side * 0.8
		if airborne:
			_legs[i].rotation.x = 0.35 * side
			_arms[i].rotation.x = -1.1
	_body.position.y = absf(sin(_phase)) * _swing * VOXEL * 1.2
	if is_inside_tree():
		lantern.global_position = global_position + Vector3(0, LANTERN_HEIGHT, 0)
		# For the see-through hole (see see_through.gdshaderinc).
		var root := get_parent_node_3d().global_transform
		RenderingServer.global_shader_parameter_set(&"player_position", root * (feet + CHEST))
		RenderingServer.global_shader_parameter_set(&"player_feet", root * feet)


func _part(part: String, offset: Vector3, parent: Node3D, material: Material) -> void:
	var path := VoxelModels.player_path(part)
	var mesh := MeshInstance3D.new()
	if ResourceLoader.exists(path):
		mesh.mesh = load(path)
	mesh.material_override = material
	mesh.layers = PLAYER_LAYER
	# Meshes stand on their base: shift them so the pivot is at `offset`.
	mesh.position = offset * VOXEL
	parent.add_child(mesh)
