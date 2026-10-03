class_name CreaturesView
extends Node3D
## The creatures the server shows this player (Msg.ENTITY_*), in the world
## root (local units): one CreatureBody each, the models' meshes shared by
## species; a will-o'-wisp also lights its surroundings (a light in world
## space, under `light_parent`: lights do not take the root's stretch).
## Finds the creature a ray meets (aiming, `pick`). A dead one tips over,
## fades, and bursts into bits (`burst`). Farm life (Husbandry): young ones
## are small, a shorn sheep shows its skin, one in love gives off pink bits
## (hearts), one on a lead is tied to its player's hand by a rope.

## Bits flying off a creature: where (local units), their color, how many.
signal burst(at: Vector3, color: Color, count: int)

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
## Pink bits over an animal in love, this often (seconds).
const HEART_COLOR := Color("ff6f9c")
const HEART_SECONDS := 0.7
## A lead: its color, thickness and segments (local units), how much it
## sags, where it ties on the animal (of its height) and the player's hand
## (levels over the feet).
const ROPE_COLOR := Color("9a7a4a")
const ROPE_THICKNESS := 0.05
const ROPE_SEGMENTS := 8
const ROPE_SAG := 0.35
const ROPE_ON_ANIMAL := 0.75
const ROPE_IN_HAND := 0.85

## Where the wisps' lights go (the 3D world, outside the stretched root).
var light_parent: Node
## The sky light of a cell (tile x, row, tile y; see WorldView3D.sky_at):
## bodies darken in caves.
var sky_at := Callable()
## This player (its id, PlayerSession.id): the leads it holds are drawn to
## its hand.
var player_id := -1
var player: LocalPlayer

var _bodies: Dictionary[int, CreatureBody] = {}
## Per species: part name -> mesh.
var _meshes: Dictionary[int, Dictionary] = {}
## Dead ones tipping over and fading.
var _dying: Array[CreatureBody] = []
## The wisps' lights, by creature id.
var _lights: Dictionary[int, OmniLight3D] = {}
## The leads: creature id -> the player leading it, and their ropes.
var _leads: Dictionary[int, int] = {}
var _ropes: Dictionary[int, Node3D] = {}
var _rope_material := StandardMaterial3D.new()
var _hearts := 0.0


func _ready() -> void:
	_rope_material.albedo_color = ROPE_COLOR
	_rope_material.roughness = 1.0


## A creature comes into view (Msg.ENTITY_SPAWN: its id, kind, feet in
## world pixels, height in levels, heading, state, flags, lead).
func spawn(message: Dictionary) -> void:
	var id: int = message["id"]
	var kind: int = message["kind"]
	if not Species.is_valid(kind):
		return
	if _bodies.has(id):
		_bodies[id].queue_free()
	var flags: int = message.get("flags", 0)
	var body := CreatureBody.new()
	body.setup(id, kind, _meshes_of(kind, flags & Animal.Flag.SHORN != 0), flags)
	add_child(body)
	_bodies[id] = body
	_place(body, message)
	body.snap()
	if kind == Species.Id.WISP and light_parent != null:
		var light := OmniLight3D.new()
		light.light_color = WISP_LIGHT
		light.omni_range = WISP_RANGE
		light.light_energy = WISP_ENERGY
		light_parent.add_child(light)
		_lights[id] = light


## A creature moved, turned or does something else (Msg.ENTITY_MOVE).
func move(message: Dictionary) -> void:
	var id: int = message["id"]
	var body: CreatureBody = _bodies.get(id)
	if body == null or body.dying:
		return
	var flags: int = message.get("flags", 0)
	if (flags ^ body.flags) & Animal.Flag.SHORN:
		# Shorn, or its wool grew back: another fleece, where it stands.
		var kind := body.kind
		var at := body.position
		var yaw := body.rotation.y
		body.queue_free()
		body = CreatureBody.new()
		body.setup(id, kind, _meshes_of(kind, flags & Animal.Flag.SHORN != 0), flags)
		add_child(body)
		_bodies[id] = body
		body.position = at
		body.rotation.y = yaw
	body.flags = flags
	_place(body, message)


## Something to tell about an animal (Msg.ANIMAL_NOTICE): its text (the
## species' name, and how much it loves, out of Husbandry.MAX_AFFECTION,
## when the text shows it).
func notice_text(message: Dictionary) -> String:
	var name := tr(Species.NAME_KEYS.get(message["kind"], ""))
	var text := tr(message["key"])
	if text.count("%d") == 2:
		return text % [name, message["value"], Husbandry.MAX_AFFECTION]
	return text % name


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
	_leads.erase(id)
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
	_leads.clear()


func has(id: int) -> bool:
	return _bodies.has(id)


## Whether the creature `id` shown is an animal (not a monster).
func is_animal(id: int) -> bool:
	var body: CreatureBody = _bodies.get(id)
	return body != null and not Species.is_monster(body.kind)


## The translated name of an animal's species ("" if not shown).
func name_of(id: int) -> String:
	var body: CreatureBody = _bodies.get(id)
	return tr(Species.NAME_KEYS[body.kind]) if body != null else ""


## The box of an animal as shown (local units).
func bounds_of(id: int) -> AABB:
	var body: CreatureBody = _bodies.get(id)
	if body == null:
		return AABB()
	var size := body.size()
	var across: Vector2 = Species.BOX[body.kind] / GameConst.TILE_SIZE * size
	var tall: float = Species.TALL[body.kind] * size
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
		if sky_at.is_valid():
			var at := body.target
			var cell := Vector3i(
				floori(at.x), floori(at.y + 0.5) + GameConst.SEA_LEVEL, floori(at.z)
			)
			body.sky_light = sky_at.call(cell) / float(LightField.MAX)
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
			burst.emit(body.position + Vector3(0.0, 0.4, 0.0), BITS[body.kind], 18)
			body.queue_free()
	_hearts += delta
	if _hearts >= HEART_SECONDS:
		_hearts = 0.0
		for body: CreatureBody in _bodies.values():
			if body.flags & Animal.Flag.LOVE:
				var top: float = Species.TALL[body.kind] * body.size() + 0.15
				burst.emit(body.position + Vector3(0.0, top, 0.0), HEART_COLOR, 3)
	_draw_leads()


func _place(body: CreatureBody, message: Dictionary) -> void:
	var box: Vector2 = Species.BOX[body.kind] * body.size()
	var feet: Vector2 = message["pos"]
	body.target = Render3D.world_px_to_local(feet - Vector2(0.0, box.y * 0.5), message["h"])
	body.heading = message["heading"]
	body.state = message["state"] as Creature.State
	var lead: int = message.get("lead", -1)
	if lead >= 0:
		_leads[body.id] = lead
	else:
		_leads.erase(body.id)


## Per species (and fleece, shorn or not): part name -> mesh.
func _meshes_of(kind: int, shorn := false) -> Dictionary:
	var key := kind * 2 + (1 if shorn else 0)
	if not _meshes.has(key):
		var meshes := {}
		for part: CreatureModels.Part in CreatureModels.parts(kind, shorn):
			meshes[part.name] = VoxelMesher.build(part.grid)
		_meshes[key] = meshes
	return _meshes[key]


## A rope from each animal on this player's lead to its hand, sagging.
func _draw_leads() -> void:
	for id: int in _ropes.keys():
		if _leads.get(id, -1) != player_id or not _bodies.has(id) or player == null:
			_ropes[id].queue_free()
			_ropes.erase(id)
	if player == null:
		return
	var hand := Render3D.world_px_to_local(player.position, player.height + ROPE_IN_HAND)
	for id: int in _leads:
		if _leads[id] != player_id or not _bodies.has(id):
			continue
		if not _ropes.has(id):
			_ropes[id] = _new_rope()
		var body := _bodies[id]
		var tie: float = Species.TALL[body.kind] * body.size() * ROPE_ON_ANIMAL
		_lay_rope(_ropes[id], body.position + Vector3(0.0, tie, 0.0), hand)


func _new_rope() -> Node3D:
	var rope := Node3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	box.material = _rope_material
	for i in ROPE_SEGMENTS:
		var segment := MeshInstance3D.new()
		segment.mesh = box
		segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rope.add_child(segment)
	add_child(rope)
	return rope


## Lays a rope's segments along a sagging line from `from` to `to`.
func _lay_rope(rope: Node3D, from: Vector3, to: Vector3) -> void:
	var sag := ROPE_SAG * clampf(from.distance_to(to) / 3.0, 0.3, 1.0)
	var points: Array[Vector3] = []
	for i in ROPE_SEGMENTS + 1:
		var t := float(i) / ROPE_SEGMENTS
		points.append(from.lerp(to, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t))
	for i in ROPE_SEGMENTS:
		var along := points[i + 1] - points[i]
		var length := along.length()
		var segment: MeshInstance3D = rope.get_child(i)
		segment.visible = length > 0.001
		if not segment.visible:
			continue
		var up := Vector3.UP if absf(along.y / length) < 0.99 else Vector3.RIGHT
		var basis := Basis.looking_at(along / length, up)
		basis *= Basis.from_scale(Vector3(ROPE_THICKNESS, ROPE_THICKNESS, length))
		segment.transform = Transform3D(basis, (points[i] + points[i + 1]) * 0.5)
