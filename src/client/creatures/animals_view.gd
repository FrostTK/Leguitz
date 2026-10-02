class_name AnimalsView
extends Node3D
## The animals the server shows this player (Msg.ENTITY_*), in the world
## root (local units): one AnimalBody each, the models' meshes shared by
## species. Finds the animal a ray meets (aiming, `pick`). A dead one tips
## over, fades, and bursts into tufts (`burst`).

## Bits flying off a dead animal: where (local units) and their color.
signal burst(at: Vector3, color: Color)

## The color of the bits of each species.
const BITS := {
	Species.Id.SHEEP: Color("efe8d8"),
	Species.Id.BOAR: Color("3b2a20"),
	Species.Id.CHICKEN: Color("b55428"),
	Species.Id.DEER: Color("b0804f"),
}

var _bodies: Dictionary[int, AnimalBody] = {}
## Per species: part name -> mesh.
var _meshes: Dictionary[int, Dictionary] = {}
## Dead ones tipping over and fading.
var _dying: Array[AnimalBody] = []


## An animal comes into view (`feet`: world pixels, `height`: levels).
func spawn(id: int, kind: int, feet: Vector2, height: float, heading: Vector2, state: int) -> void:
	if not Species.is_valid(kind):
		return
	if _bodies.has(id):
		_bodies[id].queue_free()
	var body := AnimalBody.new()
	body.setup(id, kind, _meshes_of(kind))
	add_child(body)
	_bodies[id] = body
	_place(body, feet, height, heading, state)
	body.snap()


func move(id: int, feet: Vector2, height: float, heading: Vector2, state: int) -> void:
	var body: AnimalBody = _bodies.get(id)
	if body != null and not body.dying:
		_place(body, feet, height, heading, state)


func hurt(id: int) -> void:
	var body: AnimalBody = _bodies.get(id)
	if body != null:
		body.hurt()


## The animal leaves the view, or died (it tips over and fades).
func remove(id: int, died: bool) -> void:
	var body: AnimalBody = _bodies.get(id)
	if body == null:
		return
	_bodies.erase(id)
	if died:
		body.die()
		body.hurt()
		_dying.append(body)
	else:
		body.queue_free()


func clear() -> void:
	for body: AnimalBody in _bodies.values():
		body.queue_free()
	_bodies.clear()


func has(id: int) -> bool:
	return _bodies.has(id)


## The translated name of an animal's species ("" if not shown).
func name_of(id: int) -> String:
	var body: AnimalBody = _bodies.get(id)
	return tr(Species.NAME_KEYS[body.kind]) if body != null else ""


## The box of an animal as shown (local units).
func bounds_of(id: int) -> AABB:
	var body: AnimalBody = _bodies.get(id)
	if body == null:
		return AABB()
	var across: Vector2 = Species.BOX[body.kind] / GameConst.TILE_SIZE
	var tall: float = Species.TALL[body.kind]
	return AABB(
		body.position - Vector3(across.x * 0.5, 0.0, across.y * 0.5),
		Vector3(across.x, tall, across.y)
	)


## The first animal a ray meets within `length` (local units): Vector2(id,
## distance), id -1 if none.
func pick(origin: Vector3, direction: Vector3, length: float) -> Vector2:
	var best := Vector2(-1.0, INF)
	for id: int in _bodies:
		var hit: Variant = bounds_of(id).intersects_ray(origin, direction)
		if hit == null:
			continue
		var distance := (hit as Vector3 - origin).dot(direction)
		if distance <= length and distance < best.y:
			best = Vector2(id, distance)
	return best


func _process(delta: float) -> void:
	for body: AnimalBody in _bodies.values():
		body.animate(delta)
	for body in _dying.duplicate():
		body.animate(delta)
		if body.finished:
			_dying.erase(body)
			burst.emit(body.position + Vector3(0.0, 0.4, 0.0), BITS[body.kind])
			body.queue_free()


func _place(body: AnimalBody, feet: Vector2, height: float, heading: Vector2, state: int) -> void:
	var box: Vector2 = Species.BOX[body.kind]
	body.target = Render3D.world_px_to_local(feet - Vector2(0.0, box.y * 0.5), height)
	body.heading = heading
	body.state = state as Animal.State


func _meshes_of(kind: int) -> Dictionary:
	if not _meshes.has(kind):
		var meshes := {}
		for part: AnimalModels.Part in AnimalModels.parts(kind):
			meshes[part.name] = VoxelMesher.build(part.grid)
		_meshes[kind] = meshes
	return _meshes[kind]
