class_name HeldView
extends Node3D
## First person: the right arm and what it holds at the bottom right of the
## view (a child of the camera, camera space). Drawn with a field of view
## of its own (VIEW_FOV, whatever the player chose) and in front of the
## world (voxel_view.gdshader, held_block.gdshader): it never
## cuts into a wall, and keeps its size and place when the field of view
## changes. It sways with the walk and lags behind the look, comes up from
## below when what is in hand changes, and follows the arm's strokes
## (PlayerModel.stroke): a tool strikes down towards the middle of the
## view, a sword slashes across, a block, an item or the bare hand jabs;
## food goes to the mouth; a bow comes up in front and bends as it is
## drawn, an arrow on the string.

const VOXEL_SHADER := preload("res://src/client/shaders/voxel_view.gdshader")
const HELD_BLOCK_SHADER := preload("res://src/client/shaders/held_block.gdshader")
## The field of view (degrees, vertical) the arm is drawn with.
const VIEW_FOV := 70.0
## A voxel of the body (the arm) in camera units; tools are made of
## ToolModels.SCALE of one.
const VOXEL := 0.042
## Mesh units are 1/16 of a voxel of the world.
const MESH_SCALE := VOXEL * 16.0
## Blocks and other items: their size in hand (camera units, their box's
## longest side), held over the fist, turned to show their top and two
## sides.
const BLOCK_SIZE := 0.15
const ITEM_SIZE := 0.17
const ITEM_OVER := Vector3(-0.015, 0.075, -0.03)
const ITEM_TURN := Vector3(-0.3, -0.75, 0.12)
## The way the arm goes from the fist to the shoulder, off the bottom right
## of the view.
const ARM_WAY := Vector3(0.5, -0.72, 0.48)
## Poses: [fist, handle (the model's y), front (its striking side, z)],
## at rest, raised and struck. A tool is raised to the upper right and
## struck down onto the middle of the view (where it aims), a sword raised
## to the right and slashed across to the left, the hand jabs forward.
const TOOL_POSES := [
	[Vector3(0.27, -0.28, -0.5), Vector3(-0.32, 0.86, -0.4), Vector3(-0.6, -0.15, -0.75)],
	[Vector3(0.31, -0.2, -0.47), Vector3(0.05, 0.97, -0.22), Vector3(-0.5, 0.3, -0.8)],
	[Vector3(0.2, -0.33, -0.55), Vector3(-0.57, 0.66, -0.57), Vector3(0.0, -0.5, -0.85)],
]
const SWORD_POSES := [
	[Vector3(0.28, -0.3, -0.5), Vector3(-0.22, 0.88, -0.42), Vector3(-0.95, -0.2, 0.15)],
	[Vector3(0.36, -0.16, -0.48), Vector3(0.35, 0.9, 0.25), Vector3(-0.85, 0.3, -0.4)],
	[Vector3(0.05, -0.27, -0.55), Vector3(-0.95, -0.05, -0.3), Vector3(-0.1, -0.9, -0.4)],
]
const HAND_POSES := [
	[Vector3(0.3, -0.3, -0.5), Vector3(-0.2, 0.9, -0.35), Vector3(-0.4, 0.0, -0.9)],
	[Vector3(0.32, -0.22, -0.46), Vector3(-0.05, 0.95, -0.1), Vector3(-0.3, 0.3, -0.9)],
	[Vector3(0.18, -0.24, -0.62), Vector3(-0.35, 0.8, -0.5), Vector3(-0.4, -0.2, -0.9)],
]
## The bow in hand at rest, and drawn in front of the eye (its grip there,
## leaning to the right to show its curve, the arrow along the view).
const BOW_REST := [
	Vector3(0.27, -0.25, -0.5), Vector3(-0.3, 0.95, -0.1), Vector3(-0.85, -0.1, -0.5)
]
const BOW_DRAWN := [
	Vector3(-0.08, -0.1, -0.62), Vector3(0.55, 0.83, 0.0), Vector3(-0.4, 0.05, -0.92)
]
## Where food is eaten (in front of the mouth).
const EAT_AT := Vector3(0.09, -0.21, -0.36)
## The walk sways the hand (camera units at full speed, strides per tile);
## turning the view leaves it a little behind (camera units per radian a
## second, at most), and it catches up.
const BOB := Vector2(0.014, 0.02)
const BOB_STRIDE := 1.1
const LAG := 0.012
const LAG_MOST := 0.05
const LAG_SHARPNESS := 9.0
## A jab tips an item forward, a raised arm back (radians).
const ITEM_TIP := Vector2(-0.5, 0.3)
## Lowered this far when it changes, rising in RAISE_SECONDS; zooming in,
## lowered by ZOOM_DROP.
const DROP := 0.32
const RAISE_SECONDS := 0.22
const ZOOM_DROP := 0.45

var library: ItemLibrary
## For the arm's sleeves.
var armor: Array[int] = []

var _arm := Node3D.new()
var _arm_mesh := MeshInstance3D.new()
var _sleeves: Array[MeshInstance3D] = []
var _item := MeshInstance3D.new()
var _material := ShaderMaterial.new()
## Per item: the block's materials (held_block.gdshader).
var _block_materials: Dictionary[int, Array] = {}
var _shown := -1
var _holding := PlayerModel.Holding.NOTHING
var _grip := Vector3.ZERO
var _bow_stages: Array[Mesh] = []
var _cube := false
var _walk := 0.0
var _lag := Vector2.ZERO
var _look := Basis()
var _raise := 0.0
var _sky := -1.0
var _hurt := -1.0


func _ready() -> void:
	_material.shader = VOXEL_SHADER
	_material.set_shader_parameter("use_instance_data", false)
	_material.set_shader_parameter("cut_out", false)
	_material.set_shader_parameter("view_model_fov", VIEW_FOV)
	add_child(_arm)
	var path := VoxelModels.player_path("arm")
	if ResourceLoader.exists(path):
		_arm_mesh.mesh = load(path)
	_arm_mesh.position = Vector3(0.0, -8.0, 0.0) / 16.0
	_arm.add_child(_arm_mesh)
	add_child(_item)
	for mesh: MeshInstance3D in [_arm_mesh, _item]:
		_view_mesh(mesh)
	_arm_mesh.material_override = _material


## Shows `item` in hand (Items.Id.NONE: the bare hand).
func show_item(item: int) -> void:
	if item == _shown:
		return
	_shown = item
	_raise = 1.0
	_cube = false
	_item.material_override = null
	for i in _item.get_surface_override_material_count():
		_item.set_surface_override_material(i, null)
	_item.mesh = null
	_holding = PlayerModel.Holding.NOTHING
	if item == Items.Id.NONE:
		return
	if ToolModels.has(item):
		_grip = ToolModels.grip(item)
		if item == Items.Id.BOW:
			_holding = PlayerModel.Holding.BOW
			_bow_stages.clear()
			for stage in ToolModels.DRAW_STAGES:
				_bow_stages.append(library.held_mesh(item, stage))
		else:
			var sword := Items.tool_of(item) == Items.Tool.SWORD
			_holding = PlayerModel.Holding.SWORD if sword else PlayerModel.Holding.TOOL
		_item.mesh = library.held_mesh(item)
		_item.material_override = _material
		return
	_holding = PlayerModel.Holding.ITEM
	_item.mesh = library.mesh(item)
	# Blocks are cubes wearing their textures (ItemLibrary._cube).
	_cube = _item.mesh.surface_get_material(0) is StandardMaterial3D
	if _cube:
		var materials := _block_materials_of(item)
		for i in materials.size():
			_item.set_surface_override_material(i, materials[i])
	else:
		_item.material_override = _material


## Puts the arm and what it holds where they are now. `body`: the player's
## body (its strokes, the bow drawn), `speed`: tiles per second walked,
## `eating` and `eat_time` (seconds), `zoom` (0..1), `sky_light` (0..1),
## `hurt` (0..1).
func animate(
	delta: float,
	body: PlayerModel,
	speed: float,
	eating: bool,
	eat_time: float,
	zoom: float,
	sky_light: float,
	hurt: float
) -> void:
	_set_light(sky_light, hurt)
	_raise = maxf(_raise - delta / RAISE_SECONDS, 0.0)
	_walk += delta * speed * BOB_STRIDE * PI
	var walking := clampf(speed / 4.0, 0.0, 1.0)
	_follow_look(delta)
	var offset := Vector3(
		sin(_walk) * BOB.x * walking + _lag.x, -absf(sin(_walk)) * BOB.y * walking + _lag.y, 0.0
	)
	var lowered := smoothstep(0.0, 1.0, _raise) * DROP + smoothstep(0.0, 1.0, zoom) * ZOOM_DROP
	offset.y -= lowered
	var pose := _pose(body, eating, eat_time)
	var fist: Vector3 = pose[0] + offset
	_place_arm(fist, body)
	if _holding == PlayerModel.Holding.BOW:
		var stage := ToolModels.stage_of(body.draw) if body.aiming > 0.0 else 0
		_item.mesh = _bow_stages[stage]
	if _item.mesh == null:
		return
	if _holding == PlayerModel.Holding.ITEM:
		var box := _item.mesh.get_aabb()
		var size := (BLOCK_SIZE if _cube else ITEM_SIZE) / maxf(box.get_longest_axis_size(), 0.001)
		var tip := ITEM_TIP.x * maxf(body.stroke, 0.0) - ITEM_TIP.y * minf(body.stroke, 0.0)
		var basis := Basis.from_euler(ITEM_TURN + Vector3(tip, 0.0, 0.0))
		basis = basis.scaled(Vector3.ONE * size)
		_item.transform = Transform3D(basis, fist + ITEM_OVER - basis * box.get_center())
	else:
		var size := MESH_SCALE * ToolModels.SCALE
		_item.transform = ItemLibrary.in_hand(pose[1], pose[2], _grip, size, fist)


## The pose now [fist, handle, front]: at rest, through a stroke, eating,
## drawing the bow.
func _pose(body: PlayerModel, eating: bool, eat_time: float) -> Array:
	var poses := HAND_POSES
	if _holding == PlayerModel.Holding.TOOL:
		poses = TOOL_POSES
	elif _holding == PlayerModel.Holding.SWORD:
		poses = SWORD_POSES
	var at := body.stroke
	if _holding == PlayerModel.Holding.BOW:
		var drawn := smoothstep(0.0, 1.0, body.aiming)
		var pose := _between(BOW_REST, BOW_DRAWN, drawn)
		if ToolModels.stage_of(body.draw) == ToolModels.DRAW_STAGES - 1 and drawn > 0.0:
			# Held at full draw, it trembles a little.
			var time := Time.get_ticks_msec() * 0.001
			pose[0] += Vector3(sin(time * 23.0), cos(time * 19.0), 0.0) * 0.002
		return pose
	var pose := _between(poses[0], poses[1 if at < 0.0 else 2], absf(at))
	if eating:
		var munch := Vector3(0.0, sin(eat_time * 18.0) * 0.012, 0.0)
		pose = [EAT_AT + munch, pose[1], pose[2]]
	return pose


## The arm from the fist to the shoulder, off the view; hidden while a bow
## is drawn (the eye is at the string).
func _place_arm(fist: Vector3, body: PlayerModel) -> void:
	var drawn := body.aiming if _holding == PlayerModel.Holding.BOW else 0.0
	_arm.visible = drawn < 0.5
	var up := ARM_WAY.normalized()
	var front := (Vector3(-0.3, 0.2, -1.0) - up * Vector3(-0.3, 0.2, -1.0).dot(up)).normalized()
	var basis := Basis(up.cross(front), up, front).scaled(Vector3.ONE * MESH_SCALE)
	var shoulder := fist + up * 7.0 * VOXEL - Vector3(0.0, drawn * DROP, 0.0)
	_arm.transform = Transform3D(basis, shoulder)


## Turning the view leaves the hand a little behind, then it catches up.
func _follow_look(delta: float) -> void:
	if not is_inside_tree():
		return
	var look := global_transform.basis.orthonormalized()
	var turn := (_look.inverse() * look).get_euler()
	_look = look
	var wanted := Vector2(turn.y, -turn.x) / maxf(delta, 0.001) * LAG
	wanted = wanted.limit_length(LAG_MOST)
	_lag = _lag.lerp(wanted, 1.0 - exp(-LAG_SHARPNESS * delta))


## Between two poses (`t` 0..1): the fist moves, the handle and the front turn.
static func _between(from: Array, to: Array, t: float) -> Array:
	return [
		(from[0] as Vector3).lerp(to[0], t),
		(from[1] as Vector3).normalized().slerp((to[1] as Vector3).normalized(), t),
		(from[2] as Vector3).normalized().slerp((to[2] as Vector3).normalized(), t),
	]


## The armor's sleeves on the arm (Armor: the four slots worn).
func set_armor(items: Array[int]) -> void:
	if items == armor:
		return
	armor = items.duplicate()
	for sleeve in _sleeves:
		sleeve.queue_free()
	_sleeves.clear()
	for item in items:
		if item == Items.Id.NONE:
			continue
		var index := 0
		for part: Array in ArmorModels.worn(item):
			if part[0] == "arm_r":
				var sleeve := MeshInstance3D.new()
				sleeve.mesh = PlayerModel.armor_mesh(item, index, part[1])
				sleeve.material_override = _material
				sleeve.position = part[2] / 16.0
				_view_mesh(sleeve)
				_arm.add_child(sleeve)
				_sleeves.append(sleeve)
			index += 1


func _set_light(sky_light: float, hurt: float) -> void:
	if absf(sky_light - _sky) < 0.002 and absf(hurt - _hurt) < 0.002:
		return
	_sky = sky_light
	_hurt = hurt
	_material.set_shader_parameter("sky_light", sky_light)
	_material.set_shader_parameter("hurt", hurt)
	for materials: Array in _block_materials.values():
		for material: ShaderMaterial in materials:
			material.set_shader_parameter("sky_light", sky_light)
			material.set_shader_parameter("hurt", hurt)


## A block's cube drawn as the view model: its textures (ItemLibrary._cube)
## through held_block.gdshader.
func _block_materials_of(item: int) -> Array:
	if not _block_materials.has(item):
		var materials := []
		var model := library.mesh(item)
		for i in model.get_surface_count():
			var source := model.surface_get_material(i) as StandardMaterial3D
			var material := ShaderMaterial.new()
			material.shader = HELD_BLOCK_SHADER
			material.set_shader_parameter("view_model_fov", VIEW_FOV)
			if source != null:
				material.set_shader_parameter("albedo_texture", source.albedo_texture)
				var clear := source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
				material.set_shader_parameter("scissor", clear)
			materials.append(material)
		_block_materials[item] = materials
	return _block_materials[item]


## A mesh of the view: no shadow (the body's copy casts it), out of the
## lantern's shadows, never culled at the edges of a narrower world view.
static func _view_mesh(mesh: MeshInstance3D) -> void:
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.layers = PlayerModel.PLAYER_LAYER
	mesh.extra_cull_margin = 4.0
