class_name PlayerModel
extends Node3D
## The player's 3D voxel body under the world root (local units): head,
## torso, arms and legs that swing while walking; it turns smoothly to face
## where it goes. Also carries the lantern (in world space: lights do not
## support the root's stretch).

## What the right hand holds.
enum Holding { NOTHING, ITEM, TOOL, SWORD, BOW }
## A stroke of the right arm: a tool or the hand striking down (breaking,
## a blow), a sword slashing across, a quick jab (placing, using).
enum Stroke { MINE, SLASH, JAB }

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
## How long a stroke lasts (seconds; held, they follow one another).
const STROKE_SECONDS := {Stroke.MINE: 0.5, Stroke.SLASH: 0.38, Stroke.JAB: 0.26}
## The fist, in the arm's space (from the shoulder, body voxels): a little
## outwards, so that what it swings passes beside the head, never through
## it. Tools are held by their grip there (ToolModels), in the arm's plane:
## the handle along the wrist's angle, the side that strikes towards it.
const FIST := Vector3(-0.5, -7.0, 0.0) * VOXEL
## The arm's poses through a stroke [pitch, roll inwards, wrist] (radians):
## at rest, raised, struck. A tool strikes down in front, the handle in
## line with the arm; a sword slashes down and across; the hand jabs.
const MINE_POSES: Array[Vector3] = [
	Vector3(-0.35, 0.0, 0.15), Vector3(-2.6, 0.0, 0.0), Vector3(-0.9, 0.0, -1.43)
]
const SLASH_POSES: Array[Vector3] = [
	Vector3(-0.4, 0.0, 0.25), Vector3(-2.3, -0.45, 0.2), Vector3(-0.85, 0.55, -1.1)
]
const HAND_POSES: Array[Vector3] = [
	Vector3(-0.3, 0.0, 0.0), Vector3(-1.9, 0.0, 0.0), Vector3(-0.7, 0.0, 0.0)
]
const JAB_POSES: Array[Vector3] = [
	Vector3(-0.3, 0.0, 0.0), Vector3(-0.3, 0.0, 0.0), Vector3(-1.25, 0.15, -0.35)
]
## A bow drawn (`aiming`) lies across in front of the chest (its grip
## there, body voxels), its back forward, the string pulled to the chest:
## seen from above as a bow, tipped BOW_TILT (radians) towards the front
## so that it shows from the front too.
const BOW_AT := Vector3(0.0, 17.0, 7.0)
const BOW_TILT := 0.3
## In hand at rest, the bow stands upright (in the arm's space, leaning a
## little forward), its back towards the body and its string outwards: seen
## face on from the front, not edge on.
const BOW_LIMBS := Vector3(0.0, 1.0, 0.15)

## The armor's meshes, built once: (item, part) -> mesh.
static var _armor_meshes: Dictionary[Vector2i, Mesh] = {}

var lantern := OmniLight3D.new()
## Set by the first-person view: the lantern is carried at the eye instead,
## and under cover under the ceiling (world space; INF: high above the
## head, an even circle of light seen from above).
var lantern_override := Vector3.INF
## The right arm strikes again and again (breaking a block, hitting).
var swinging := false
## Where the right arm is in its stroke: 0 at rest, -1 raised, 1 struck
## (read by HeldView), and the stroke's kind.
var stroke := 0.0
var stroke_kind := Stroke.MINE
## How far the bow is drawn (0..1, Archer): it bends.
var draw := 0.0
## Eating: the right hand at the mouth, munching.
var eating := false
## Swimming: arms sweeping, legs kicking.
var swimming := false
## Drawing a bow (0..1): both arms raised towards the front.
var aiming := 0.0
## How red a hurt makes the body (0..1, see set_hurt; HeldView follows).
var hurt := 0.0
## What the right hand holds (see hold, hold_tool, hold_bow).
var holding := Holding.NOTHING

var _body := Node3D.new()
## What the right hand holds (an item's model; see hold).
var _held := MeshInstance3D.new()
## Where a held item (not a tool) rests in the hand (see hold).
var _held_rest := Transform3D()
## A tool's or the bow's grip (model units), the bow's stages.
var _grip := Vector3.ZERO
var _bow_stages: Array[Mesh] = []
## The armor worn (its meshes, and the items they show).
var _armor: Array[MeshInstance3D] = []
var _armor_items: Array[int] = []
var _arms: Array[Node3D] = []
## The right arm (the body faces +z: its right is -x) and the left one.
var _right: Node3D
var _left: Node3D
var _legs: Array[Node3D] = []
var _yaw := 0.0
var _phase := 0.0
var _swing := 0.0
var _material := ShaderMaterial.new()
## Munching (eating).
var _strike := 0.0
var _swim_time := 0.0
## How far the stroke going on is (0..1; -1: none) and whether a single
## one is asked (swing).
var _stroke_time := -1.0
var _single := false


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
	_right = _arms[0]
	_left = _arms[1]
	# In the right hand, at the end of the arm.
	# Like the body, out of the lantern's shadows (held close to it, what is
	# in hand would throw a huge one); the sun's and the moon's stay.
	_held.layers = PLAYER_LAYER
	_right.add_child(_held)

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
	_swim_time += delta
	var walking := clampf(speed / 5.0, 0.0, 1.0)
	_phase += delta * speed * STRIDE * TAU / 2.0
	_swing = lerpf(_swing, walking * SWING, 1.0 - exp(-10.0 * delta))
	var stride := sin(_phase) * _swing
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		_legs[i].rotation.x = stride * side
		_arms[i].rotation.x = -stride * side * 0.8
		if swimming:
			var stroke := sin(_phase * 0.5 + _swim_time * 4.0)
			_legs[i].rotation.x = sin(_swim_time * 9.0) * 0.35 * side
			_arms[i].rotation.x = -1.6 + stroke * 0.9
		elif airborne:
			_legs[i].rotation.x = 0.35 * side
			_arms[i].rotation.x = -1.1
	_advance_stroke(delta)
	var pose := Vector3(_right.rotation.x, 0.0, MINE_POSES[0].z)
	if holding in [Holding.TOOL, Holding.SWORD] and not swimming and not airborne:
		# Held a little forward, swinging less with the walk.
		pose.x = arm_pose(stroke_kind, holding, 0.0).x + _right.rotation.x * 0.4
	if _stroke_time >= 0.0:
		pose = arm_pose(stroke_kind, holding, stroke)
	if aiming > 0.0:
		_left.rotation.x = lerpf(_left.rotation.x, -1.5, aiming)
		pose.x = lerpf(pose.x, -1.6 - aiming * 0.2, aiming)
	if eating:
		_strike += delta * 18.0
		pose = Vector3(-2.1 + sin(_strike) * 0.12, 0.0, 0.0)
	_right.rotation.x = pose.x
	_right.rotation.z = pose.y
	_place_held(pose.z)
	_body.position.y = absf(sin(_phase)) * _swing * VOXEL * 1.2
	if is_inside_tree():
		var above := global_position + Vector3(0, LANTERN_HEIGHT, 0)
		lantern.global_position = above if lantern_override == Vector3.INF else lantern_override
		# For the see-through hole (see see_through.gdshaderinc).
		var root := get_parent_node_3d().global_transform
		RenderingServer.global_shader_parameter_set(&"player_position", root * (feet + CHEST))
		RenderingServer.global_shader_parameter_set(&"player_feet", root * feet)


## Puts on the armor `items` (Armor: the four slots, Items.Id.NONE where
## nothing is worn): their pieces over the head, the torso and the arms,
## the legs (ArmorModels).
func set_armor(items: Array[int]) -> void:
	if items == _armor_items:
		return
	_armor_items = items.duplicate()
	for mesh in _armor:
		mesh.queue_free()
	_armor.clear()
	var anchors := {
		"body": _body, "arm_r": _right, "arm_l": _left, "leg_r": _legs[0], "leg_l": _legs[1]
	}
	for item in items:
		if item == Items.Id.NONE:
			continue
		var index := 0
		for part: Array in ArmorModels.worn(item):
			var mesh := MeshInstance3D.new()
			mesh.mesh = armor_mesh(item, index, part[1])
			mesh.material_override = _material
			mesh.layers = PLAYER_LAYER
			mesh.position = part[2] * VOXEL
			anchors[part[0]].add_child(mesh)
			_armor.append(mesh)
			index += 1


## The mesh of a piece of armor's part (built once; HeldView shows the
## sleeves too).
static func armor_mesh(item: int, index: int, grid: VoxelGrid) -> Mesh:
	var key := Vector2i(item, index)
	if not _armor_meshes.has(key):
		_armor_meshes[key] = VoxelMesher.build(grid)
	return _armor_meshes[key]


## Puts an item's model in the right hand (null: empty hand), `size` its
## size (local units).
func hold(model: Mesh, size: float) -> void:
	_held.mesh = model
	holding = Holding.ITEM if model != null else Holding.NOTHING
	if model != null:
		_held_rest = Transform3D(
			Basis.from_euler(Vector3(-0.5, 0.0, 0.0)).scaled(Vector3.ONE * size),
			FIST + Vector3(0.0, -1.5 * VOXEL - model.get_aabb().size.y * size * 0.5, 1.5 * VOXEL)
		)
		_held.transform = _held_rest


## Puts a tool or a sword (ToolModels.held) in the right hand, held by its
## grip (model units).
func hold_tool(model: Mesh, grip: Vector3, sword: bool) -> void:
	_held.mesh = model
	_grip = grip
	holding = Holding.SWORD if sword else Holding.TOOL


## Puts the bow in the right hand: its model at each stage of the draw
## (ToolModels.DRAW_STAGES), held by its grip.
func hold_bow(stages: Array[Mesh], grip: Vector3) -> void:
	_bow_stages = stages
	_held.mesh = stages[0]
	_grip = grip
	holding = Holding.BOW


## One stroke of the right arm (placing a block, using something).
func swing() -> void:
	_single = true


## The arm's pose [pitch, roll inwards, wrist] for a stroke of `kind` at
## `at` (see stroke) holding `what`.
static func arm_pose(kind: int, what: int, at: float) -> Vector3:
	var poses := HAND_POSES
	if kind == Stroke.JAB:
		poses = JAB_POSES
	elif kind == Stroke.SLASH:
		poses = SLASH_POSES
	elif what in [Holding.TOOL, Holding.SWORD]:
		poses = MINE_POSES
	if at < 0.0:
		return poses[0].lerp(poses[1], -at)
	return poses[0].lerp(poses[2], at)


## Where the arm is through a stroke (`t` 0..1): a tool or a sword is
## raised, struck down fast and brought back; a jab goes out and back.
static func stroke_curve(t: float, kind: int) -> float:
	if kind == Stroke.JAB:
		if t < 0.35:
			var out := t / 0.35
			return 1.0 - (1.0 - out) * (1.0 - out)
		return 1.0 - smoothstep(0.35, 1.0, t)
	if t < 0.35:
		return -smoothstep(0.0, 0.35, t)
	if t < 0.55:
		var down := (t - 0.35) / 0.2
		return -1.0 + 2.0 * down * down
	return 1.0 - smoothstep(0.55, 1.0, t)


## Strokes follow one another while `swinging`; a single one when asked.
func _advance_stroke(delta: float) -> void:
	if _stroke_time < 0.0:
		var kind := -1
		if swinging:
			kind = Stroke.SLASH if holding == Holding.SWORD else Stroke.MINE
		elif _single:
			kind = _use_stroke()
		_single = false
		if kind < 0:
			stroke = 0.0
			return
		stroke_kind = kind as Stroke
		_stroke_time = 0.0
	_stroke_time += delta / STROKE_SECONDS[stroke_kind]
	if _stroke_time >= 1.0:
		_stroke_time = -1.0
		stroke = 0.0
	else:
		stroke = stroke_curve(_stroke_time, stroke_kind)


## The stroke of a single use: a tool strikes, a sword slashes, the bow
## none (it shoots), anything else jabs.
func _use_stroke() -> int:
	match holding:
		Holding.TOOL:
			return Stroke.MINE
		Holding.SWORD:
			return Stroke.SLASH
		Holding.BOW:
			return -1
	return Stroke.JAB


## Places what is in hand: a tool by its grip at the fist, turned by the
## wrist (`wrist`, radians: 0 the handle forward, > 0 up); the bow leaning
## in hand (BOW_LIMBS), or across the chest drawn; an item resting in the
## hand.
func _place_held(wrist: float) -> void:
	if _held.mesh == null:
		return
	match holding:
		Holding.TOOL, Holding.SWORD:
			var handle := Vector3(0.0, sin(wrist), cos(wrist))
			var front := Vector3(0.0, -cos(wrist), sin(wrist))
			_held.transform = ItemLibrary.in_hand(handle, front, _grip, ToolModels.SCALE, FIST)
		Holding.BOW:
			var stage := ToolModels.stage_of(draw) if aiming > 0.0 else 0
			_held.mesh = _bow_stages[stage]
			var rest := ItemLibrary.in_hand(BOW_LIMBS, Vector3.RIGHT, _grip, ToolModels.SCALE, FIST)
			_held.transform = rest
			if aiming > 0.0:
				var drawn := _right.transform.affine_inverse() * _bow_pose()
				_held.transform = rest.interpolate_with(drawn, aiming)
		_:
			_held.transform = _held_rest


## Where a drawn bow is, in the body's space (see BOW_AT): its limbs across,
## its back forward and tipped up, the string towards the chest.
func _bow_pose() -> Transform3D:
	var front := Vector3(0.0, sin(BOW_TILT), cos(BOW_TILT))
	return ItemLibrary.in_hand(Vector3.RIGHT, front, _grip, ToolModels.SCALE, BOW_AT * VOXEL)


## Dithers the body away (0 = shown, 1 = gone; its shadow stays, and so
## does the shadow of what it holds, drawn in first person by the view).
## Reddens the body (0: not at all; a hurt flashes it).
func set_hurt(amount: float) -> void:
	hurt = amount
	_material.set_shader_parameter("hurt", amount)


## The sky light the body stands in (0..1, see LightField): it darkens in
## a cave.
func set_sky_light(amount: float) -> void:
	_material.set_shader_parameter("sky_light", amount)


## Hides the body (a spectator is unseen; their lantern still lights).
func set_ghost(ghost: bool) -> void:
	_body.visible = not ghost


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
