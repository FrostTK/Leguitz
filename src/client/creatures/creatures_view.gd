class_name CreaturesView
extends Node3D
## The creatures the server shows this player (Msg.ENTITY_*), in the world
## root (local units): one CreatureBody each, the models' meshes shared by
## species; a will-o'-wisp also lights its surroundings (a light in world
## space, under `light_parent`: lights do not take the root's stretch).
## Finds the creature a ray meets (aiming, `pick`). A dead one tips over,
## fades, and bursts into bits (`burst`).

## Bits flying off a dead creature: where (local units) and their color.
signal burst(at: Vector3, color: Color)

## The color of the bits of each species.
const BITS := {
	Species.Id.SHEEP: Color("efe8d8"),
	Species.Id.BOAR: Color("3b2a20"),
	Species.Id.CHICKEN: Color("b55428"),
	Species.Id.DEER: Color("b0804f"),
	Species.Id.LANTERN_MOTH: Color("e6dcc4"),
	Species.Id.SHADE_LURKER: Color("1f1830"),
	Species.Id.ROCK_MIMIC: Color("7c7b87"),
	Species.Id.WISP: Color("c8ff8a"),
}
## A wisp's light: its color, how far and how bright, and how it flickers.
const WISP_LIGHT := Color(0.6, 1.0, 0.45)
const WISP_RANGE := 6.0
const WISP_ENERGY := 1.6

## Where the wisps' lights go (the 3D world, outside the stretched root).
var light_parent: Node

var _bodies: Dictionary[int, CreatureBody] = {}
## Per species: part name -> mesh.
var _meshes: Dictionary[int, Dictionary] = {}
## Dead ones tipping over and fading.
var _dying: Array[CreatureBody] = []
## The wisps' lights, by creature id.
var _lights: Dictionary[int, OmniLight3D] = {}


## An animal comes into view (`feet`: world pixels, `height`: levels).
func spawn(id: int, kind: int, feet: Vector2, height: float, heading: Vector2, state: int) -> void:
	if not Species.is_valid(kind):
		return
	if _bodies.has(id):
		_bodies[id].queue_free()
	var body := CreatureBody.new()
	body.setup(id, kind, _meshes_of(kind))
	add_child(body)
	_bodies[id] = body
	_place(body, feet, height, heading, state)
	body.snap()
	if kind == Species.Id.WISP and light_parent != null:
		var light := OmniLight3D.new()
		light.light_color = WISP_LIGHT
		light.omni_range = WISP_RANGE
		light.light_energy = WISP_ENERGY
		light_parent.add_child(light)
		_lights[id] = light


func move(id: int, feet: Vector2, height: float, heading: Vector2, state: int) -> void:
	var body: CreatureBody = _bodies.get(id)
	if body != null and not body.dying:
		_place(body, feet, height, heading, state)


func hurt(id: int) -> void:
	var body: CreatureBody = _bodies.get(id)
	if body != null:
		body.hurt()


## The animal leaves the view, or died (it tips over and fades).
func remove(id: int, died: bool) -> void:
	var body: CreatureBody = _bodies.get(id)
	if body == null:
		return
	_bodies.erase(id)
	if _lights.has(id):
		_lights[id].queue_free()
		_lights.erase(id)
	if died:
		body.die()
		body.hurt()
		_dying.append(body)
	else:
		body.queue_free()


func clear() -> void:
	for body: CreatureBody in _bodies.values():
		body.queue_free()
	_bodies.clear()
	for light: OmniLight3D in _lights.values():
		light.queue_free()
	_lights.clear()


func has(id: int) -> bool:
	return _bodies.has(id)


## The translated name of an animal's species ("" if not shown).
func name_of(id: int) -> String:
	var body: CreatureBody = _bodies.get(id)
	return tr(Species.NAME_KEYS[body.kind]) if body != null else ""


## The box of an animal as shown (local units).
func bounds_of(id: int) -> AABB:
	var body: CreatureBody = _bodies.get(id)
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
	for body: CreatureBody in _bodies.values():
		body.animate(delta)
	if not _lights.is_empty() and is_inside_tree():
		var root := global_transform
		var time := Time.get_ticks_msec() * 0.001
		for id: int in _lights:
			var light := _lights[id]
			light.global_position = root * (_bodies[id].position + Vector3(0.0, 0.25, 0.0))
			light.light_energy = WISP_ENERGY * (0.85 + 0.15 * sin(time * 11.0 + id))
	for body in _dying.duplicate():
		body.animate(delta)
		if body.finished:
			_dying.erase(body)
			burst.emit(body.position + Vector3(0.0, 0.4, 0.0), BITS[body.kind])
			body.queue_free()


func _place(body: CreatureBody, feet: Vector2, height: float, heading: Vector2, state: int) -> void:
	var box: Vector2 = Species.BOX[body.kind]
	body.target = Render3D.world_px_to_local(feet - Vector2(0.0, box.y * 0.5), height)
	body.heading = heading
	body.state = state as Creature.State


func _meshes_of(kind: int) -> Dictionary:
	if not _meshes.has(kind):
		var meshes := {}
		for part: CreatureModels.Part in CreatureModels.parts(kind):
			meshes[part.name] = VoxelMesher.build(part.grid)
		_meshes[kind] = meshes
	return _meshes[kind]
