class_name AnimalBody
extends Node3D
## One animal as the client shows it (local units, under the world root):
## the parts of its model (AnimalModels) on joints that move. It glides to
## where the server says it is and turns to where it looks; its legs swing
## as it walks or runs, its head dips to graze, a fowl's wings flap when it
## runs or falls; it reddens when hurt and, dead, tips over and fades away.

const SHADER := preload("res://src/client/shaders/voxel.gdshader")
const VOXEL := 1.0 / 16.0
const FOLLOW_SHARPNESS := 12.0
const TURN_SHARPNESS := 7.0
## Farther than this (local units) from where it should be: it jumps there.
const SNAP_DISTANCE := 4.0
## Strides per tile walked, how far the legs swing (radians), how low the
## head dips to graze.
const STRIDE := 1.1
const SWING := 0.7
const GRAZE_PITCH := 0.95
const HURT_SECONDS := 0.35
const DEATH_SECONDS := 1.2

var id := 0
var kind := Species.Id.SHEEP
## Where its feet should be (local units: the middle of its box, on the
## ground), where it looks (ground direction) and what it does
## (Animal.State).
var target := Vector3.ZERO
var heading := Vector2.DOWN
var state := Animal.State.IDLE
## Dead: it tips over and fades; `finished` once gone.
var dying := false
var finished := false

var _root := Node3D.new()
var _joints: Dictionary[String, Node3D] = {}
var _material := ShaderMaterial.new()
var _yaw := 0.0
var _phase := 0.0
var _swing := 0.0
var _hurt := 0.0
var _death := 0.0
var _time := 0.0
var _last := Vector3.INF
var _climb := 0.0


## Builds the model of `animal_kind` from `meshes` (part name -> mesh).
func setup(animal_id: int, animal_kind: int, meshes: Dictionary) -> void:
	id = animal_id
	kind = animal_kind as Species.Id
	_material.shader = SHADER
	_material.set_shader_parameter("use_instance_data", false)
	add_child(_root)
	var head_joint := Vector3.ZERO
	for part: AnimalModels.Part in AnimalModels.parts(kind):
		if part.name == "head":
			head_joint = part.joint
	for part: AnimalModels.Part in AnimalModels.parts(kind):
		# Antlers on stags only (one deer in two); they go with the head.
		if part.name == "antlers" and id % 2 == 1:
			continue
		var joint := Node3D.new()
		var parent := _root
		var at := part.joint
		if part.name == "antlers":
			parent = _joints["head"]
			at = part.joint - head_joint
		joint.position = at * VOXEL
		parent.add_child(joint)
		var mesh := MeshInstance3D.new()
		mesh.mesh = meshes[part.name]
		mesh.material_override = _material
		mesh.position = part.offset * VOXEL
		joint.add_child(mesh)
		_joints[part.name] = joint


## Puts it at once where it should be.
func snap() -> void:
	position = target
	_yaw = atan2(heading.x, heading.y)
	rotation.y = _yaw
	_last = position


func hurt() -> void:
	_hurt = 1.0


func die() -> void:
	dying = true


func animate(delta: float) -> void:
	_time += delta
	if position.distance_to(target) > SNAP_DISTANCE:
		snap()
	var before := position
	position = position.lerp(target, 1.0 - exp(-FOLLOW_SHARPNESS * delta))
	var flat := Vector2(position.x - before.x, position.z - before.z)
	var speed := flat.length() / maxf(delta, 0.001)
	_climb = (position.y - before.y) / maxf(delta, 0.001)
	if heading != Vector2.ZERO:
		_yaw = lerp_angle(_yaw, atan2(heading.x, heading.y), 1.0 - exp(-TURN_SHARPNESS * delta))
	rotation.y = _yaw
	var walking := clampf(speed / 2.5, 0.0, 1.0)
	_swing = lerpf(_swing, walking * SWING, 1.0 - exp(-10.0 * delta))
	_phase += delta * speed * STRIDE * TAU
	_animate_legs()
	_root.position.y = absf(sin(_phase)) * _swing * VOXEL * 1.5
	_animate_head(delta)
	_animate_wings()
	_hurt = maxf(_hurt - delta / HURT_SECONDS, 0.0)
	_material.set_shader_parameter("hurt", _hurt)
	if dying:
		_death = minf(_death + delta / DEATH_SECONDS, 1.0)
		_root.rotation.z = smoothstep(0.0, 0.4, _death) * PI * 0.5
		_material.set_shader_parameter("fade", smoothstep(0.45, 1.0, _death))
		finished = _death >= 1.0


## Diagonal pairs of legs swing together (a trot); a fowl's two in turn.
func _animate_legs() -> void:
	var stride := sin(_phase) * _swing
	for name: String in ["leg_fl", "leg_br"]:
		if _joints.has(name):
			_joints[name].rotation.x = stride
	for name: String in ["leg_fr", "leg_bl"]:
		if _joints.has(name):
			_joints[name].rotation.x = -stride


## Grazing, the head dips and nibbles; walking, it nods.
func _animate_head(delta: float) -> void:
	var head: Node3D = _joints.get("head")
	if head == null:
		return
	var pitch := sin(_phase * 2.0) * _swing * 0.12
	if state == Animal.State.GRAZE and not dying:
		pitch = GRAZE_PITCH + sin(_time * 9.0) * 0.06
	head.rotation.x = lerpf(head.rotation.x, pitch, 1.0 - exp(-6.0 * delta))


## Running or in the air, a fowl flaps its wings.
func _animate_wings() -> void:
	if not _joints.has("wing_l"):
		return
	var flapping := state == Animal.State.FLEE or absf(_climb) > 1.0
	var open := (0.5 + sin(_time * 28.0) * 0.5) * 0.9 if flapping else 0.0
	_joints["wing_l"].rotation.z = -open
	_joints["wing_r"].rotation.z = open
