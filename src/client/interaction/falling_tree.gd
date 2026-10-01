class_name FallingTree
extends Node3D
## A felled tree toppling over (local units, in the world root, standing at
## its foot), then bursting into leaves and splinters.

## Angular acceleration (radians per second squared) and the angle it
## lies down at.
const FALL_ACCELERATION := 3.2
const DOWN_ANGLE := 1.45

var debris: Debris
var leaves := Color.GREEN
var wood := Color.SADDLE_BROWN
## Height of the tree (local units), for where the leaves burst.
var height := 4.0

var _axis := Vector3.RIGHT
var _towards := Vector3.FORWARD
var _angle := 0.0
var _speed := 0.0


## `model`: the tree's mesh (turned like its prop) and its material;
## `towards`: the ground direction it falls to.
func setup(model: Mesh, turn: Basis, material: Material, towards: Vector2) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = model
	mesh.basis = turn
	mesh.material_override = material
	add_child(mesh)
	_towards = Vector3(towards.x, 0.0, towards.y).normalized()
	if _towards == Vector3.ZERO:
		_towards = Vector3.FORWARD
	_axis = Vector3.UP.cross(_towards).normalized()


func _process(delta: float) -> void:
	_speed += FALL_ACCELERATION * delta
	_angle = minf(_angle + _speed * delta, DOWN_ANGLE)
	basis = Basis(_axis, _angle)
	if _angle >= DOWN_ANGLE:
		_burst()
		queue_free()


func _burst() -> void:
	if debris == null or not is_inside_tree():
		return
	var root := get_parent_node_3d().global_transform
	for k in 6:
		var along := position + _towards * height * (0.35 + k * 0.12)
		var at := root * (along + Vector3.UP * 0.3)
		debris.throw(at, leaves if k > 1 else wood, 10, 0.5)
