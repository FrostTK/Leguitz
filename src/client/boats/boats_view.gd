class_name BoatsView
extends Node3D
## The boats, in the world root (local units): each kept as the server
## told (Msg.BOAT; `boats`), its model built for its parts once per look
## (BoatModels), on its shipyard's slipway or afloat, moved smoothly between
## the server's reports (Msg.BOAT_MOVE; the boat the local player pilots
## where Helm steps it), sliding down the slipway when launched (up when
## docked). While its engine runs its propeller turns and smoke puffs
## from its chimney; its oars row while its pilot rows; a wake follows it.
## It shakes when struck (Msg.BOAT_HURT) and bursts into planks (embers)
## when broken (burnt). `pick` finds a boat along a ray (aiming).

const SMOOTHING := 12.0
const SLIDE_SECONDS := 1.2
const SHAKE_SECONDS := 0.35
const PUFF_EVERY := 0.2
const PUFF_SECONDS := 1.6
const PUFF_RISE := 0.9
const WAKE_EVERY := 0.12
const PROPELLER_TURNS := 3.0
const ROW_STROKES := 0.8
const WAKE := Color("e8f4f8")
const SMOKE := Color("6e6a66")
const PLANKS := Color("946a3c")
const EMBERS := Color("f06a1e")
## A boat's box for aiming, over its keel (tiles).
const HEIGHT := 0.75
## On a slipway a boat lies along it, its bow down (radians).
const SLIPWAY_PITCH := 0.3

var client: GameClient
var boats: Dictionary[int, Boat] = {}

var _nodes: Dictionary[int, Node3D] = {}
var _keys: Dictionary[int, String] = {}
var _models: Dictionary[String, Mesh] = {}
var _propeller: Mesh
var _oar: Mesh
## id -> [at, yaw] the server last told; [from at, from yaw, seconds] of a
## slide; seconds left shaking.
var _goals: Dictionary[int, Array] = {}
var _slides: Dictionary[int, Array] = {}
var _shakes: Dictionary[int, float] = {}
var _turns: Dictionary[int, float] = {}
var _puffs: Array[Array] = []
var _puff_mesh := BoxMesh.new()
var _puff_material := StandardMaterial3D.new()
var _clock := 0.0


func _ready() -> void:
	_propeller = _mesh(BoatModels.propeller())
	_oar = _mesh(BoatModels.oar())
	_puff_mesh.size = Vector3.ONE * 0.2
	_puff_material.albedo_color = SMOKE
	_puff_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_puff_mesh.material = _puff_material


## The boat the local player is aboard (null: none), and their place (-1:
## the pilot's; see Boat.seats).
func mine() -> Boat:
	var me := client.player_id
	for boat: Boat in boats.values():
		if boat.pilot == me or me in boat.seats.values():
			return boat
	return null


## A boat as the server tells it (Msg.BOAT).
func on_boat(data: Dictionary) -> void:
	var boat := Boat.from_dict(data)
	var old: Boat = boats.get(boat.id)
	var me := client.player_id
	if old != null and old.pilot == me and boat.pilot == me and old.yard == Boat.NO_YARD:
		# Its pilot here steers it: where it is stays theirs.
		boat.at = old.at
		boat.yaw = old.yaw
		boat.speed = old.speed
		boat.throttle = old.throttle
		boat.full = old.full
	if old != null and old.yard != boat.yard and _nodes.has(boat.id):
		var node := _nodes[boat.id]
		_slides[boat.id] = [node.position, node.rotation.y, 0.0]
	boats[boat.id] = boat
	_goals[boat.id] = [boat.at, boat.yaw]
	_build(boat)
	if old == null:
		_place_now(boat)


## Where a boat went (Msg.BOAT_MOVE); its pilot's own report wins unless
## refused (`correct`).
func on_move(message: Dictionary) -> void:
	var boat: Boat = boats.get(message["id"])
	if boat == null:
		return
	boat.burn = message["burn"]
	var piloting := boat.pilot == client.player_id
	if piloting and not message["correct"]:
		return
	boat.at = message["at"]
	boat.yaw = message["yaw"]
	boat.speed = message["speed"]
	boat.throttle = message["throttle"]
	_goals[boat.id] = [boat.at, boat.yaw]
	if piloting:
		_place_now(boat)


func on_hurt(id: int) -> void:
	_shakes[id] = SHAKE_SECONDS
	var boat: Boat = boats.get(id)
	if boat != null:
		client.interaction.burst(boat.at + Vector3(0.0, 0.3, 0.0), PLANKS, 5)


func remove(id: int, burnt: bool) -> void:
	var boat: Boat = boats.get(id)
	if boat != null:
		client.interaction.burst(boat.at + Vector3(0.0, 0.3, 0.0), EMBERS if burnt else PLANKS)
	if _nodes.has(id):
		_nodes[id].queue_free()
	for kept: Dictionary in [boats, _nodes, _keys, _goals, _slides, _shakes, _turns]:
		kept.erase(id)


func clear() -> void:
	for id: int in boats.keys():
		remove(id, false)


## The boat along a ray (local units) within `far`: Vector2(id, distance)
## (x -1: none); `skip`: a boat not to see (the one aboard).
func pick(origin: Vector3, direction: Vector3, far: float, skip := -1) -> Vector2:
	var best := Vector2(-1.0, far)
	for boat: Boat in boats.values():
		if boat.id == skip or not _nodes.has(boat.id):
			continue
		var into := _nodes[boat.id].transform.affine_inverse()
		var from := into * origin
		var way := into.basis * direction
		var hit: Variant = _box(boat).intersects_ray(from, way)
		if hit != null:
			var along := ((hit as Vector3) - from).length() / maxf(way.length(), 0.0001)
			if along < best.y:
				best = Vector2(boat.id, along)
	return best


## A boat's box (local units, around the world's axes), for its frame.
func bounds_of(id: int) -> AABB:
	var boat: Boat = boats.get(id)
	if boat == null or not _nodes.has(id):
		return AABB()
	var placed := _nodes[id].transform * _box(boat)
	return placed


func _process(delta: float) -> void:
	_clock += delta
	for id: int in boats:
		var boat := boats[id]
		if not _nodes.has(id):
			continue
		_move(boat, _nodes[id], delta)
		_animate(boat, _nodes[id], delta)
	_update_puffs(delta)


## Its box in its own space (over its keel, its length along z).
static func _box(boat: Boat) -> AABB:
	var half := Vector3(Boat.WIDTH * Boat.VOXEL * 0.5, 0.0, boat.length() * 0.5)
	var keel := -BoatModels.WATER_LINE * Boat.VOXEL
	return AABB(Vector3(-half.x, keel, -half.z), Vector3(half.x * 2.0, HEIGHT, half.z * 2.0))


## The node of a boat with its model for its look (built once per look).
func _build(boat: Boat) -> void:
	var key := BoatModels.key_of(boat)
	if _keys.get(boat.id, "") == key:
		return
	_keys[boat.id] = key
	if not _models.has(key):
		_models[key] = _mesh(BoatModels.boat(boat))
	var node: Node3D = _nodes.get(boat.id)
	if node == null:
		node = Node3D.new()
		add_child(node)
		_nodes[boat.id] = node
		for part in ["hull", "propeller", "oar_left", "oar_right"]:
			var mesh := MeshInstance3D.new()
			mesh.name = part
			node.add_child(mesh)
		# The propeller turns about its middle.
		var blades := MeshInstance3D.new()
		blades.name = "blades"
		blades.mesh = _propeller
		blades.position = Vector3(0.0, -3.5 * Boat.VOXEL, 0.0)
		node.get_node("propeller").add_child(blades)
	var hull := node.get_node("hull") as MeshInstance3D
	hull.mesh = _models[key]
	hull.position = Vector3(0.0, -BoatModels.WATER_LINE * Boat.VOXEL, 0.0)
	var stern := -boat.length() * 0.5
	var propeller := node.get_node("propeller") as Node3D
	propeller.position = Vector3(0.0, -4.5 * Boat.VOXEL, stern + 0.05)
	propeller.visible = boat.has_engine()
	for side: int in [-1, 1]:
		var oar := node.get_node("oar_left" if side < 0 else "oar_right") as MeshInstance3D
		oar.mesh = _oar
		var gunwale := (BoatModels.GUNWALE - BoatModels.WATER_LINE + 1) * Boat.VOXEL
		var x := side * (Boat.WIDTH * 0.5 - 1.0) * Boat.VOXEL
		oar.position = Vector3(x, gunwale, boat.place_along(-1) + 0.35)
		oar.visible = boat.complete() and not boat.has_engine()


func _mesh(grid: VoxelGrid) -> Mesh:
	var model := VoxelMesher.build(grid)
	if model.get_surface_count() > 0:
		model.surface_set_material(0, client.items.voxel_material)
	return model


func _place_now(boat: Boat) -> void:
	var node: Node3D = _nodes.get(boat.id)
	if node != null:
		node.position = boat.at
		node.rotation.y = boat.yaw


## Where a boat's node goes: its pilot's boat where it is, the others
## easing towards the server's word, sliding along a slipway.
func _move(boat: Boat, node: Node3D, delta: float) -> void:
	var goal: Array = _goals.get(boat.id, [boat.at, boat.yaw])
	var at: Vector3 = goal[0]
	var yaw: float = goal[1]
	if boat.pilot == client.player_id and boat.yard == Boat.NO_YARD:
		at = boat.at
		yaw = boat.yaw
		node.position = at
		node.rotation.y = yaw
	else:
		var ease := 1.0 - exp(-SMOOTHING * delta)
		node.position = node.position.lerp(at, ease)
		node.rotation.y = lerp_angle(node.rotation.y, yaw, ease)
	if _slides.has(boat.id):
		var slide: Array = _slides[boat.id]
		slide[2] += delta
		var t := smoothstep(0.0, 1.0, slide[2] / SLIDE_SECONDS)
		node.position = (slide[0] as Vector3).lerp(at, t)
		node.rotation.y = lerp_angle(slide[1], yaw, t)
		if slide[2] >= SLIDE_SECONDS:
			_slides.erase(boat.id)
	var docked := boat.yard != Boat.NO_YARD
	var pitch := SLIPWAY_PITCH if docked else 0.0
	node.rotation.x = lerpf(node.rotation.x, pitch, 1.0 - exp(-SMOOTHING * delta))
	if docked and not _slides.has(boat.id):
		# Its stern on the slipway's top, its bow down along it.
		node.position.y = at.y - boat.length() * 0.5 * sin(node.rotation.x)
	var shake: float = _shakes.get(boat.id, 0.0)
	node.rotation.z = sin(_clock * 45.0) * 0.06 * shake / SHAKE_SECONDS
	if shake > 0.0:
		_shakes[boat.id] = maxf(shake - delta, 0.0)


## The propeller, the oars, the smoke and the wake.
func _animate(boat: Boat, node: Node3D, delta: float) -> void:
	var afloat := boat.yard == Boat.NO_YARD
	var pushing := afloat and boat.pilot >= 0 and boat.throttle != 0.0
	var powered := boat.powered()
	var turn: float = _turns.get(boat.id, 0.0)
	if pushing and powered:
		turn += delta * TAU * PROPELLER_TURNS * absf(boat.throttle) * signf(boat.throttle)
	_turns[boat.id] = turn
	(node.get_node("propeller") as Node3D).rotation.z = turn
	var stroke := sin(_clock * TAU * ROW_STROKES) if pushing and not powered else 0.0
	for side: int in [-1, 1]:
		var oar := node.get_node("oar_left" if side < 0 else "oar_right") as Node3D
		var out := side * (PI * 0.5 - 0.25 + stroke * 0.45)
		oar.rotation = Vector3(0.3 + absf(stroke) * 0.12, out, 0.0)
	if not afloat:
		return
	var key := float(boat.id) * 0.37
	if pushing and powered and fposmod(_clock + key, PUFF_EVERY) < delta:
		var top := BoatModels.chimney_top() * Boat.VOXEL
		var mouth := Vector3(top.x, top.y - BoatModels.WATER_LINE * Boat.VOXEL, top.z)
		mouth.z -= boat.length() * 0.5
		_puff(node.transform * mouth)
	if absf(boat.speed) > 0.8 and fposmod(_clock + key, WAKE_EVERY) < delta:
		var stern := node.transform * Vector3(0.0, 0.0, -boat.length() * 0.5 * signf(boat.speed))
		client.interaction.burst(stern, WAKE, 2)


## A puff of smoke at a point (local units): it rises, swells and fades
## away (shrinks); drawn outside the stretched world root.
func _puff(at: Vector3) -> void:
	var puff := MeshInstance3D.new()
	puff.mesh = _puff_mesh
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	puff.top_level = true
	client.world_viewport.world_root().add_child(puff)
	puff.global_position = client.world_root.global_transform * at
	_puffs.append([puff, 0.0, at])


func _update_puffs(delta: float) -> void:
	for i in range(_puffs.size() - 1, -1, -1):
		var puff: Array = _puffs[i]
		var node := puff[0] as MeshInstance3D
		puff[1] += delta
		var t: float = puff[1] / PUFF_SECONDS
		if t >= 1.0:
			node.queue_free()
			_puffs.remove_at(i)
			continue
		puff[2] += Vector3(0.15, PUFF_RISE, 0.05) * delta
		node.global_position = client.world_root.global_transform * (puff[2] as Vector3)
		node.scale = Vector3.ONE * (0.6 + 1.8 * t) * (1.0 - t * t)
