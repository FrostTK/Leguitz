class_name DroppedItemsView
extends Node3D
## The items lying in the world (local units, in the world root): each one
## turns slowly and bobs a little; picked up, it flies into the player.

## Size of a lying item (local units: its model fitted in this box);
## flat ones (tools...) are bigger, or their handles would be too thin.
const SIZE := 0.32
const FLAT_SIZE := 0.5
const BOB := 0.05
const SPIN := 1.6
const FOLLOW_SHARPNESS := 14.0
## A picked-up item flies to the player this fast (units per second).
const FLY_SPEED := 9.0

var library: ItemLibrary
## The local player (where picked-up items fly to) and their id.
var local_player: LocalPlayer
var player_id := -1

var _items: Dictionary[int, Node3D] = {}
var _targets: Dictionary[int, Vector3] = {}
## Picked-up items flying to the player, to free once there.
var _flying: Array[Node3D] = []
var _time := 0.0


func spawn(id: int, item: int, count: int, at: Vector3) -> void:
	if _items.has(id):
		_items[id].queue_free()
	var holder := Node3D.new()
	holder.position = at
	var spin := Node3D.new()
	holder.add_child(spin)
	# Bigger stacks show a second model beside the first.
	for copy in 2 if count > 1 else 1:
		var model := MeshInstance3D.new()
		model.mesh = library.mesh(item)
		var scale_to := (FLAT_SIZE if ItemModels.is_flat(item) else SIZE) * library.fit(item)
		model.scale = Vector3.ONE * scale_to
		model.position = Vector3(
			copy * 0.08, -model.mesh.get_aabb().size.y * scale_to * 0.5 + copy * 0.05, copy * 0.06
		)
		spin.add_child(model)
	add_child(holder)
	_items[id] = holder
	_targets[id] = at


func move(id: int, at: Vector3) -> void:
	if _items.has(id):
		_targets[id] = at


## The item is gone: picked up by `by` (it flies to them if that is us).
func remove(id: int, by: int) -> void:
	var holder: Node3D = _items.get(id)
	if holder == null:
		return
	_items.erase(id)
	_targets.erase(id)
	if by == player_id and by > 0:
		_flying.append(holder)
	else:
		holder.queue_free()


func clear() -> void:
	for holder: Node3D in _items.values():
		holder.queue_free()
	_items.clear()
	_targets.clear()


func _process(delta: float) -> void:
	_time += delta
	var follow := 1.0 - exp(-FOLLOW_SHARPNESS * delta)
	for id: int in _items:
		var holder := _items[id]
		holder.position = holder.position.lerp(_targets[id], follow)
		var spin := holder.get_child(0) as Node3D
		spin.rotation.y = _time * SPIN + id
		spin.position.y = BOB * (1.0 + sin(_time * 2.2 + id))
	if local_player == null:
		return
	var feet := local_player.position / GameConst.TILE_SIZE
	var chest := Vector3(feet.x, local_player.height + 0.9, feet.y)
	for holder in _flying.duplicate():
		holder.position = holder.position.move_toward(chest, FLY_SPEED * delta)
		holder.scale = holder.scale * (1.0 - delta * 4.0)
		if holder.position.distance_to(chest) < 0.1 or holder.scale.x < 0.2:
			_flying.erase(holder)
			holder.queue_free()
