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
## Tools are held by the handle at TOOL_HAND, upright (turned TOOL_ROLL
## about the handle: their flat side to the side, the axe's blade
## forward), a voxel of the model being TOOL_SCALE of a voxel of the
## world; the wrist lifts the head TOOL_REST (radians) at rest, and
## through a stroke from the first angle (arm raised) to the second
## (striking down).
const TOOL_HAND := Vector3(0.0, -7.5, 0.5) * VOXEL
const TOOL_SCALE := 0.75
const TOOL_ROLL := PI * 0.25
const TOOL_REST := 1.25
const TOOL_STROKE := Vector2(0.35, -0.8)

var lantern := OmniLight3D.new()
## Set by the first-person view: the lantern is carried at the eye instead
## (world space; INF: above the head as usual).
var lantern_override := Vector3.INF
## The right arm strikes again and again (breaking a block).
var swinging := false
## Where the right arm is in its stroke: 0 raised, 1 striking down (-1: no
## stroke going on).
var strike_phase := -1.0

var _body := Node3D.new()
## What the right hand holds (an item's model; see hold), and whether it
## is a tool (held by its handle, see hold_tool).
var _held := MeshInstance3D.new()
var _holds_tool := false
var _arms: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _yaw := 0.0
var _phase := 0.0
var _swing := 0.0
var _material := ShaderMaterial.new()
## Phase of the strokes, and how long a single stroke (placing) lasts.
var _strike := 0.0
var _strike_left := 0.0


func _ready() -> void:
	var material := _material
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
	# In the right hand, at the end of the arm.
	# Like the body, out of the lantern's shadows (held close to it, what is
	# in hand would throw a huge one); the sun's and the moon's stay.
	_held.layers = PLAYER_LAYER
	_arms[0].add_child(_held)

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
	strike_phase = -1.0
	if swinging or _strike_left > 0.0:
		_strike += delta * 13.0
		_strike_left -= delta
		_arms[0].rotation.x = -1.3 + sin(_strike) * 0.7
		strike_phase = (sin(_strike) + 1.0) * 0.5
	if _holds_tool:
		var pitch := TOOL_REST
		if strike_phase >= 0.0:
			pitch = lerpf(TOOL_STROKE.x, TOOL_STROKE.y, strike_phase)
		_held.transform = ItemLibrary.held_tool(Basis(), TOOL_HAND, pitch, TOOL_SCALE, TOOL_ROLL)
	_body.position.y = absf(sin(_phase)) * _swing * VOXEL * 1.2
	if is_inside_tree():
		var above := global_position + Vector3(0, LANTERN_HEIGHT, 0)
		lantern.global_position = above if lantern_override == Vector3.INF else lantern_override
		# For the see-through hole (see see_through.gdshaderinc).
		var root := get_parent_node_3d().global_transform
		RenderingServer.global_shader_parameter_set(&"player_position", root * (feet + CHEST))
		RenderingServer.global_shader_parameter_set(&"player_feet", root * feet)


## Puts an item's model in the right hand (null: empty hand), `size` its
## size (local units).
func hold(model: Mesh, size: float) -> void:
	_held.mesh = model
	_holds_tool = false
	if model != null:
		_held.rotation = Vector3(-0.5, 0.0, 0.0)
		_held.scale = Vector3.ONE * size
		_held.position = Vector3(
			0.0, -8.5 * VOXEL - model.get_aabb().size.y * size * 0.5, 2 * VOXEL
		)


## Puts a tool in the right hand, held by its handle (see ItemLibrary.held_tool).
func hold_tool(model: Mesh) -> void:
	_held.mesh = model
	_holds_tool = true


## One stroke of the right arm (placing a block).
func swing() -> void:
	_strike_left = 0.25


## Dithers the body away (0 = shown, 1 = gone; its shadow stays, and so
## does the shadow of what it holds, drawn in first person by the view).
## Reddens the body (0: not at all; a hurt flashes it).
func set_hurt(amount: float) -> void:
	_material.set_shader_parameter("hurt", amount)


## Lays the body down on its back (1: passed out, 0: standing).
func set_down(amount: float) -> void:
	_body.rotation.x = -PI * 0.5 * amount


func set_fade(amount: float) -> void:
	_material.set_shader_parameter("fade", amount)
	var shadow := (
		GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		if amount > 0.5
		else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	)
	if _held.cast_shadow != shadow:
		_held.cast_shadow = shadow


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
