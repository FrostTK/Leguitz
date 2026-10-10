class_name CreatureBody
extends Node3D
## One creature as the client shows it (local units, under the world
## root): the parts of its model (CreatureModels) on joints that move. It
## glides to where the server says it is and turns to where it looks; its
## legs swing as it walks or runs (four in a trot, two in turn, a mimic's
## six), its head dips to graze, a fowl's wings flap when it runs or falls
## and a moth's all the time, a lurker's arms reach out to strike and it
## pales, still, in the light, a mimic sits as a rock while dormant (legs
## and face hidden), a wisp pulses; it reddens when hurt and, dead, tips
## over and fades away. A young one is smaller (Animal.Flag.BABY); asleep,
## an animal lies down, legs folded and head low. A dog or a cat sits
## (State.SIT: on its haunches, front legs straight), wags or sways its
## tail, a dog lifts its muzzle to bark (Flag.BARK, State.ALERT), both
## lunge to bite (a cat leaps), a cat crouches stalking.

const SHADER := preload("res://src/client/shaders/voxel.gdshader")
const VOXEL := 1.0 / 16.0
const FOLLOW_SHARPNESS := 12.0
const TURN_SHARPNESS := 7.0
## How fast the body's light follows the sky light it walks into.
const SKY_SHARPNESS := 4.0
## Farther than this (local units) from where it should be: it jumps there.
const SNAP_DISTANCE := 4.0
## Strides per tile walked, how far the legs swing (radians), how low the
## head dips to graze.
const STRIDE := 1.1
const SWING := 0.7
const GRAZE_PITCH := 0.95
const HURT_SECONDS := 0.35
const DEATH_SECONDS := 1.2
## A dormant mimic sinks this many voxels (onto its folded legs).
const MIMIC_SINK := 5.0
## A lurker in the light pales this much (dithered away).
const FROZEN_FADE := 0.35
## Asleep: legs folded this far (radians), the body this low (of its
## height), the head this low (radians).
const FOLD := 1.4
const LIE_SINK := 0.3
const SLEEP_PITCH := 0.55
## A bear warning rears up this far (radians), lifted this much (levels);
## a wolf's or a bear's blow lunges this far forward (levels).
const REAR_PITCH := 0.75
const REAR_LIFT := 0.45
const LUNGE := 0.3
## Sitting, the body leans back this far (radians); a cat's leap lifts it
## this much (levels), its crouch lowers it this much.
const SIT_PITCH := 0.45
const LEAP := 0.25
const CROUCH := 0.06

var id := 0
var kind := Species.Id.SHEEP
## Where its feet should be (local units: the middle of its box, on the
## ground), where it looks (ground direction) and what it does
## (Creature.State).
var target := Vector3.ZERO
var heading := Vector2.DOWN
var state := Creature.State.IDLE
## What else it shows (Animal.Flag): young, shorn, in love, tame, barking;
## a dog's or a cat's coat.
var flags := 0
var look := 0
## Dead: it tips over and fades; `finished` once gone.
var dying := false
var finished := false
## The sky light it stands in (0..1, see LightField): it darkens in a cave
## (smoothly, as it walks).
var sky_light := 1.0
## Seconds since it was last animated (CreaturesView may skip frames).
var waited := 0.0

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
var _sink := 0.0
var _fade := 0.0
var _sky := -1.0
var _rest := 0.0
var _rear := 0.0
var _lunge := 0.0
var _sit := 0.0
var _crouch := 0.0
var _meshes: Array[MeshInstance3D] = []
var _shadowed := true
## The shader's parameters as last set (set again only when they change).
var _parameters: Dictionary[StringName, float] = {}


## Builds the model of `animal_kind` from `meshes` (part name -> mesh).
func setup(animal_id: int, animal_kind: int, meshes: Dictionary, animal_flags := 0) -> void:
	id = animal_id
	kind = animal_kind as Species.Id
	flags = animal_flags
	_material.shader = SHADER
	_material.set_shader_parameter("use_instance_data", false)
	add_child(_root)
	var head_joint := Vector3.ZERO
	for part: CreatureModels.Part in CreatureModels.parts(kind):
		if part.name == "head":
			head_joint = part.joint
	for part: CreatureModels.Part in CreatureModels.parts(kind):
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
		_meshes.append(mesh)
		mesh.position = part.offset * VOXEL
		joint.add_child(mesh)
		_joints[part.name] = joint


## Whether its parts cast a shadow (CreaturesView spares small ones').
func set_shadow(on: bool) -> void:
	if on == _shadowed:
		return
	_shadowed = on
	var cast := (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if on
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	for mesh in _meshes:
		mesh.cast_shadow = cast


## Puts it at once where it should be.
func snap() -> void:
	position = target
	_yaw = atan2(heading.x, heading.y)
	rotation.y = _yaw
	_last = position


func hurt() -> void:
	_hurt = 1.0


## Its size (a young one is smaller).
func size() -> float:
	return Animal.BABY_SIZE if flags & Animal.Flag.BABY else 1.0


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
	if state == Creature.State.FROZEN:
		_swing = 0.0
	scale = Vector3.ONE * size()
	var asleep := state == Creature.State.SLEEP and not dying
	_rest = move_toward(_rest, 1.0 if asleep else 0.0, delta * 2.0)
	_animate_legs()
	_root.position.y = absf(sin(_phase)) * _swing * VOXEL * 1.5
	if kind in [Species.Id.RABBIT, Species.Id.FROG]:
		# It hops.
		_root.position.y = absf(sin(_phase * 0.5)) * _swing * VOXEL * 6.0
	_root.position.y -= _rest * Species.TALL[kind] * LIE_SINK
	if Species.FLIERS.has(kind) and not _landed():
		_root.position.y = sin(_time * 3.0 + id) * VOXEL * 1.5
		_root.rotation.x = lerpf(
			_root.rotation.x, 0.5 if state == Creature.State.STRIKE else 0.0, 0.2
		)
	_animate_head(delta)
	_animate_wings()
	_animate_monster(delta)
	_animate_wild(delta)
	_animate_companion(delta)
	_hurt = maxf(_hurt - delta / HURT_SECONDS, 0.0)
	_set_parameter(&"hurt", _hurt)
	var fade := _fade
	if dying:
		_death = minf(_death + delta / DEATH_SECONDS, 1.0)
		_root.rotation.z = smoothstep(0.0, 0.4, _death) * PI * 0.5
		fade = maxf(fade, smoothstep(0.45, 1.0, _death))
		finished = _death >= 1.0
	_set_parameter(&"fade", fade)
	_sky = sky_light if _sky < 0.0 else lerpf(_sky, sky_light, 1.0 - exp(-SKY_SHARPNESS * delta))
	_set_parameter(&"sky_light", _sky)


## Diagonal pairs of legs swing together (a trot); a fowl's or a lurker's
## two in turn, its arms against them; a mimic's six in two sets.
func _animate_legs() -> void:
	var stride := sin(_phase) * _swing
	for name: String in ["leg_fl", "leg_br", "leg_l", "leg_1", "leg_3", "leg_5"]:
		if _joints.has(name):
			_joints[name].rotation.x = stride
	for name: String in ["leg_fr", "leg_bl", "leg_r", "leg_2", "leg_4", "leg_6"]:
		if _joints.has(name):
			_joints[name].rotation.x = -stride
	if _rest > 0.0:
		# Lying down: the legs fold under the body.
		for name: String in _joints:
			if name.begins_with("leg_"):
				var fold := -FOLD if name.begins_with("leg_b") else FOLD
				_joints[name].rotation.x = lerpf(_joints[name].rotation.x, fold, _rest)
	if _joints.has("arm_l"):
		var reach := -1.5 if state == Creature.State.STRIKE else 0.0
		_joints["arm_l"].rotation.x = lerpf(_joints["arm_l"].rotation.x, reach - stride * 0.6, 0.3)
		_joints["arm_r"].rotation.x = lerpf(_joints["arm_r"].rotation.x, reach + stride * 0.6, 0.3)


## Grazing, the head dips and nibbles; walking, it nods.
func _animate_head(delta: float) -> void:
	var head: Node3D = _joints.get("head")
	if head == null:
		return
	var pitch := sin(_phase * 2.0) * _swing * 0.12
	if state == Creature.State.GRAZE and not dying:
		pitch = GRAZE_PITCH + sin(_time * 9.0) * 0.06
	pitch = lerpf(pitch, SLEEP_PITCH, _rest)
	if Species.COMPANIONS.has(kind):
		# Level while sitting (the body leans back); a dog's muzzle up barking.
		pitch += _sit * SIT_PITCH * (1.0 - _rest)
		var barking := flags & Animal.Flag.BARK != 0 or state == Creature.State.ALERT
		if barking and kind == Species.Id.DOG and not dying:
			pitch -= 0.25 + absf(sin(_time * 11.0)) * 0.2
	head.rotation.x = lerpf(head.rotation.x, pitch, 1.0 - exp(-6.0 * delta))


## Running or in the air, a fowl flaps its wings; a moth all the time.
func _animate_wings() -> void:
	if not _joints.has("wing_l"):
		return
	var moth := kind == Species.Id.LANTERN_MOTH
	var flapping := moth or state == Creature.State.FLEE or absf(_climb) > 1.0
	if kind == Species.Id.CROW:
		flapping = not _landed()
	var open := (0.5 + sin(_time * 28.0) * 0.5) * 0.9 if flapping else 0.0
	if moth:
		open = sin(_time * 16.0 + id) * 0.8
	elif kind in [Species.Id.BEE, Species.Id.LANTERN_BUMBLEBEE]:
		open = sin(_time * 60.0 + id) * 0.7
	_joints["wing_l"].rotation.z = -open
	_joints["wing_r"].rotation.z = open


## A mimic sits as a rock while dormant (its legs and face hidden), rises
## on its legs awake; a wisp pulses; a lurker pales in the light.
func _animate_monster(delta: float) -> void:
	match kind:
		Species.Id.ROCK_MIMIC:
			var dormant := state == Creature.State.DORMANT and not dying
			_sink = move_toward(_sink, 1.0 if dormant else 0.0, delta * 4.0)
			_root.position.y -= _sink * MIMIC_SINK * VOXEL
			for name: String in _joints:
				if name.begins_with("leg_") or name == "face":
					_joints[name].visible = _sink < 0.9
		Species.Id.WISP:
			var pulse := 1.0 + sin(_time * 6.0 + id) * 0.08
			_joints["body"].scale = Vector3.ONE * pulse
		Species.Id.SHADE_LURKER:
			var pale := FROZEN_FADE if state == Creature.State.FROZEN else 0.0
			_fade = move_toward(_fade, pale, delta * 2.0)


## A bear warning rears up on its hind legs; a wolf's or a bear's blow
## lunges; a fish's tail sweeps; a mole stays out of sight under its field
## until it comes up.
func _animate_wild(delta: float) -> void:
	match kind:
		Species.Id.WOLF, Species.Id.BEAR:
			var alert := state == Creature.State.ALERT and not dying
			_rear = move_toward(_rear, 1.0 if alert else 0.0, delta * 4.0)
			_root.rotation.x = -_rear * REAR_PITCH
			_root.position.y += _rear * REAR_LIFT
			for name: String in ["leg_fl", "leg_fr"]:
				_joints[name].rotation.x = lerpf(_joints[name].rotation.x, -1.2, _rear)
			var striking := state == Creature.State.STRIKE and not dying
			_lunge = move_toward(_lunge, 1.0 if striking else 0.0, delta * 8.0)
			_root.position.z = _lunge * LUNGE
		Species.Id.FISH:
			var beat := 6.0 + _swing * 14.0
			_joints["tail"].rotation.y = sin(_time * beat + id) * 0.5
		Species.Id.MOLE:
			var up := state == Creature.State.IDLE or dying
			_sink = move_toward(_sink, 0.0 if up else 1.0, delta * 3.0)
			_root.position.y -= _sink * Species.TALL[kind] * 1.2
			_root.visible = _sink < 0.95


## A dog or a cat: sitting on its haunches (the body leaning back, front
## legs upright, hind legs folded forward, head level), its tail wagging
## (a dog's; quicker when tame) or swaying (a cat's), a dog's muzzle up
## barking, a lunge to bite (a cat leaps), a cat's crouch when stalking.
func _animate_companion(delta: float) -> void:
	if not Species.COMPANIONS.has(kind):
		return
	var sitting := state == Creature.State.SIT and not dying
	_sit = move_toward(_sit, 1.0 if sitting else 0.0, delta * 4.0)
	var pitch := _sit * SIT_PITCH
	var shoulder: Vector3 = _joints["leg_fl"].position / VOXEL
	var lower := shoulder.y * cos(pitch) + shoulder.z * sin(pitch) - shoulder.y
	_root.rotation.x = -pitch
	_root.position.y -= lower * VOXEL
	for name: String in ["leg_fl", "leg_fr"]:
		_joints[name].rotation.x = lerpf(_joints[name].rotation.x, pitch, _sit)
	for name: String in ["leg_bl", "leg_br"]:
		_joints[name].rotation.x = lerpf(_joints[name].rotation.x, pitch - PI * 0.5, _sit)
	var striking := state == Creature.State.STRIKE and not dying
	_lunge = move_toward(_lunge, 1.0 if striking else 0.0, delta * 8.0)
	_root.position.z = _lunge * LUNGE
	var stalking := kind == Species.Id.CAT and state == Creature.State.CHASE and not dying
	_crouch = move_toward(_crouch, 1.0 if stalking else 0.0, delta * 4.0)
	_root.position.y -= _crouch * CROUCH
	if kind == Species.Id.CAT:
		_root.position.y += _lunge * LEAP
	var tail: Node3D = _joints["tail"]
	var sway := 0.0
	if _rest < 0.5 and not dying:
		if kind == Species.Id.DOG:
			var happy := (
				flags & Animal.Flag.TAME != 0
				and state in [Creature.State.IDLE, Creature.State.SIT, Creature.State.WANDER]
			)
			sway = sin(_time * (16.0 if happy else 5.0) + id) * (0.55 if happy else 0.2)
		else:
			sway = sin(_time * 2.2 + id) * 0.35
	tail.rotation.y = sway
	# Low: lying back on the ground sitting or asleep, down stalking.
	var low := -0.35 * _sit - 0.6 * _crouch - 0.6 * _rest
	tail.rotation.x = lerpf(tail.rotation.x, low, 0.2)


## A crow pecking on the ground (not flying).
func _landed() -> bool:
	return kind == Species.Id.CROW and state == Creature.State.GRAZE


## Sets a shader parameter when its value changed.
func _set_parameter(name: StringName, value: float) -> void:
	if absf(_parameters.get(name, -1.0) - value) > 0.001:
		_parameters[name] = value
		_material.set_shader_parameter(name, value)
