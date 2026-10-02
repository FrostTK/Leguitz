class_name ArrowsView
extends Node3D
## The arrows in flight (Msg.ARROW_SPAWN), in the world root (local units):
## each flies as the server's does (Archery.fly), turned along its way,
## and stays stuck where it meets a block until the server takes it away
## (Msg.ARROW_REMOVE).

## An arrow's size (local units: its model's diagonal fitted in this).
const SIZE := 0.7
## The model's tip points this way (ItemModels lays it on the diagonal).
const TIP := Vector3(0.70710678, 0.70710678, 0.0)

var library: ItemLibrary
var client_world: ClientWorld

## id -> [node, from, launch velocity, seconds flown, stuck].
var _arrows: Dictionary[int, Array] = {}


func spawn(id: int, from: Vector3, velocity: Vector3) -> void:
	remove(id)
	var holder := Node3D.new()
	var model := MeshInstance3D.new()
	model.mesh = library.mesh(Items.Id.ARROW)
	var scale_to := SIZE * library.fit(Items.Id.ARROW)
	model.scale = Vector3.ONE * scale_to
	# The mesh stands on its base: its middle to the holder's origin.
	model.position = -model.mesh.get_aabb().get_center() * scale_to
	holder.add_child(model)
	add_child(holder)
	_arrows[id] = [holder, from, velocity, 0.0, false]
	_place(_arrows[id])


func remove(id: int) -> void:
	if _arrows.has(id):
		_arrows[id][0].queue_free()
		_arrows.erase(id)


func clear() -> void:
	for id: int in _arrows.keys():
		remove(id)


func _process(delta: float) -> void:
	for id: int in _arrows:
		var arrow := _arrows[id]
		if arrow[4]:
			continue
		arrow[3] += delta
		_place(arrow)
		var at: Vector3 = (arrow[0] as Node3D).position
		var cell := Vector3i(floori(at.x), floori(at.y) + GameConst.SEA_LEVEL, floori(at.z))
		var voxel := client_world.voxel_at(cell)
		if Voxels.is_solid(voxel) and not Voxels.is_liquid(voxel):
			arrow[4] = true


func _place(arrow: Array) -> void:
	var holder: Node3D = arrow[0]
	var time: float = arrow[3]
	holder.position = Archery.fly(arrow[1], arrow[2], time)
	var velocity: Vector3 = arrow[2] + Vector3(0.0, -Archery.GRAVITY * time, 0.0)
	if velocity.length() > 0.01:
		holder.basis = Basis(Quaternion(TIP, velocity.normalized()))
