class_name Angler
extends Node
## Fishing on the client. With a rod in hand, a right click (the left
## trigger) casts where the player aims (the water the mouse points at, the
## crosshair in first person, ahead with a gamepad; Fishing.within_reach)
## and, the bobber out, reels it in (Msg.CAST, Msg.REEL: the server decides
## what bites, see Fishing). Every player's bobber shows (Msg.BOBBER): it
## flies in an arc, rocks on the water, twitches while a fish nibbles, is
## pulled under when it bites (a splash), lies on the ground where nothing
## bites, comes back to the rod reeled in. The local player's line runs
## from the rod's tip to it (a line one pixel thin, sagging while slack,
## taut while a fish pulls); standing still, the player faces the bobber
## (top-down). What was caught shows over the hotbar
## (Msg.CAUGHT), and the bait about to be used when the rod comes in hand.

## The line's color, how many points draw it, how much it sags slack (per
## unit of its length).
const LINE_COLOR := Color("e8e6dc")
const LINE_POINTS := 16
const SAG := 0.1
## The bobber rocks on the water, dips while a fish nibbles, goes under
## when it bites (local units).
const ROCK := 0.02
const NIBBLE_DIP := 0.07
const BITE_DIP := 0.25
## A cast flies this high over its way (per tile), leaves the rod this
## long after the click (the arm swings first); reeled in, the bobber comes
## back in REEL_SECONDS. A cast the server did not answer goes after
## UNANSWERED seconds.
const ARC := 0.16
const CAST_DELAY := 0.2
const REEL_SECONDS := 0.25
const UNANSWERED := 1.5
## The bobber's water line (its model's voxels from the base).
const WATER_LINE := 2.5
## How far the mouse's and the crosshair's rays look for water.
const FAR := 128.0
## With a gamepad, casts go this far ahead.
const PAD_CAST := 8.0
const SPLASH := Color("a8d8f0")


## A bobber shown.
class Bobber:
	extends RefCounted
	var node := MeshInstance3D.new()
	var state := Fishing.State.FLYING
	## Where it flies from and lands (local units), how long its flight
	## lasts, seconds since what it does began.
	var from := Vector3.ZERO
	var at := Vector3.ZERO
	var flight := 0.0
	var time := 0.0
	## Coming back to the rod; the server spoke of it.
	var reeled := false
	var answered := false


var client: GameClient
## Player id -> their bobber.
var _bobbers: Dictionary[int, Bobber] = {}
var _model: Mesh
var _line := MeshInstance3D.new()
var _strip := ImmediateMesh.new()
var _held := Items.Id.NONE


func _ready() -> void:
	_model = VoxelMesher.build(FishingModels.bobber())
	_model.surface_set_material(0, client.items.voxel_material)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = LINE_COLOR
	_line.material_override = material
	_line.mesh = _strip
	_line.top_level = true
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	client.world_viewport.world_root().add_child(_line)


## The rod in hand is used (a right click): it casts, or reels in.
func use() -> void:
	var mine: Bobber = _bobbers.get(client.player_id)
	client.player_model.swing()
	if mine != null:
		if not mine.reeled:
			client.transport.send(Msg.reel())
			_reel(mine)
		return
	var player := client.local_player
	var flat := player.position / GameConst.TILE_SIZE
	var feet := Vector3(flat.x, player.height, flat.y)
	var target := Fishing.within_reach(feet, _target(feet))
	_face(target)
	client.transport.send(Msg.cast(client.inventory.selected, target))
	var landed := Fishing.landing(target, client.world.voxel_at)
	var bobber := _spawn(client.player_id, landed["at"])
	bobber.flight = maxf(Fishing.flight_of(feet, target) - CAST_DELAY, 0.15)
	bobber.time = -CAST_DELAY
	bobber.node.visible = false


## A bobber's news (Msg.BOBBER).
func on_bobber(message: Dictionary) -> void:
	var id: int = message["player"]
	var state: int = message["state"]
	var bobber: Bobber = _bobbers.get(id)
	if state == Fishing.State.GONE:
		if bobber != null and id != client.player_id:
			_remove(id)
		elif bobber != null and bobber.answered and not bobber.reeled:
			# (Not answered: the news is of a line out before this cast.)
			_reel(bobber)
		return
	if bobber == null:
		if id == client.player_id:
			return
		bobber = _spawn(id, message["at"])
		bobber.from = bobber.at + Vector3(0.0, 2.0, 0.0)
		bobber.flight = message["left"]
	bobber.answered = true
	bobber.at = message["at"]
	if state == Fishing.State.FLYING or bobber.reeled:
		return
	bobber.state = state as Fishing.State
	bobber.time = 0.0
	if id != client.player_id:
		return
	if state == Fishing.State.BITE:
		client.interaction.burst(bobber.at, SPLASH, 10)
	if message.get("missed", false):
		client.hotbar.announce(tr("HUD_FISH_TOOK_BAIT"))


## What the local player caught (Msg.CAUGHT).
func on_caught(message: Dictionary) -> void:
	var item: int = message["item"]
	var name := tr(Items.name_key(item))
	var size: int = message["size"]
	if size > 0:
		client.hotbar.announce(tr("HUD_CAUGHT") % [name, size])
	else:
		client.hotbar.announce(tr("HUD_FISHED_UP") % name)
	if message.get("broke", false):
		client.tool_broke(Items.Id.FISHING_ROD)


func clear() -> void:
	for id: int in _bobbers.keys():
		_remove(id)


func _process(delta: float) -> void:
	if client == null or not client.joined:
		return
	var held := client.held_item()
	if held != _held:
		_held = held
		if held == Items.Id.FISHING_ROD:
			_tell_bait()
	var mine: Bobber = _bobbers.get(client.player_id)
	if mine != null and held != Items.Id.FISHING_ROD:
		# The rod left the hand (the book does not tell the server).
		client.transport.send(Msg.reel())
		_remove(client.player_id)
		mine = null
	client.player_model.cast = mine != null and mine.node.visible
	if mine != null and client.local_player.speed < 0.1 and client.first_person < 1.0:
		# Standing still, the angler watches their bobber.
		_face(mine.at)
	for id: int in _bobbers.keys():
		var bobber := _bobbers[id]
		bobber.time += delta
		if id == client.player_id and not bobber.answered and bobber.time > UNANSWERED:
			_remove(id)
			continue
		if bobber.reeled and bobber.time >= REEL_SECONDS:
			_remove(id)
			continue
		_place(bobber, id == client.player_id)
	_draw_line(_bobbers.get(client.player_id))


func _spawn(id: int, at: Vector3) -> Bobber:
	_remove(id)
	var bobber := Bobber.new()
	bobber.node.mesh = _model
	bobber.node.layers = PlayerModel.PLAYER_LAYER
	bobber.at = at
	bobber.from = _tip_local()
	if bobber.from == Vector3.INF:
		bobber.from = at + Vector3(0.0, 2.0, 0.0)
	client.world_root.add_child(bobber.node)
	_bobbers[id] = bobber
	return bobber


func _remove(id: int) -> void:
	var bobber: Bobber = _bobbers.get(id)
	if bobber != null:
		bobber.node.queue_free()
		_bobbers.erase(id)


## Reeled in: the bobber comes back to the rod.
func _reel(bobber: Bobber) -> void:
	bobber.reeled = true
	bobber.from = bobber.node.position
	bobber.time = 0.0


## Puts a bobber where it is now (see the class).
func _place(bobber: Bobber, mine: bool) -> void:
	var node := bobber.node
	if bobber.time < 0.0:
		return
	node.visible = true
	var float_at := bobber.at - Vector3(0.0, WATER_LINE / 16.0, 0.0)
	if bobber.reeled:
		var tip := _tip_local() if mine else Vector3.INF
		if tip == Vector3.INF:
			tip = bobber.from + Vector3(0.0, 1.0, 0.0)
		node.position = bobber.from.lerp(tip, clampf(bobber.time / REEL_SECONDS, 0.0, 1.0))
		return
	match bobber.state:
		Fishing.State.FLYING:
			var t := clampf(bobber.time / maxf(bobber.flight, 0.01), 0.0, 1.0)
			var way := Vector2(bobber.at.x - bobber.from.x, bobber.at.z - bobber.from.z).length()
			var arc := ARC * way * 4.0 * t * (1.0 - t)
			node.position = bobber.from.lerp(float_at, t) + Vector3(0.0, arc, 0.0)
		Fishing.State.FLOATING:
			node.position = float_at + Vector3(0.0, sin(bobber.time * 2.2) * ROCK, 0.0)
		Fishing.State.NIBBLE:
			var twitch := pow(maxf(sin(bobber.time * 17.0), 0.0), 6.0)
			node.position = float_at - Vector3(0.0, twitch * NIBBLE_DIP, 0.0)
		Fishing.State.BITE:
			var under := smoothstep(0.0, 0.12, bobber.time) * BITE_DIP
			node.position = float_at - Vector3(0.0, under, 0.0)
		Fishing.State.GROUND:
			node.position = bobber.at


## Turns the player towards a point (local units).
func _face(point: Vector3) -> void:
	var player := client.local_player
	var towards := Vector2(point.x, point.z) * GameConst.TILE_SIZE - player.position
	if towards.length() > 2.0:
		player.heading = towards.normalized()


## The rod's tip, in local units (INF: no rod shown).
func _tip_local() -> Vector3:
	var tip := _tip()
	if tip == Vector3.INF:
		return tip
	return client.world_root.global_transform.affine_inverse() * tip


## The rod's tip (global): in first person the view's, else the body's.
func _tip() -> Vector3:
	if client.first_person >= 1.0:
		return client.held_view.rod_tip(client.world_viewport.camera.fov)
	return client.player_model.rod_tip()


## The local player's line, from the rod's tip to the bobber's top:
## sagging while slack, taut while a fish bites or it comes back.
func _draw_line(bobber: Bobber) -> void:
	_strip.clear_surfaces()
	var tip := _tip()
	if bobber == null or not bobber.node.visible or tip == Vector3.INF:
		return
	var top := bobber.node.position + Vector3(0.0, 5.0 / 16.0, 0.0)
	var end := client.world_root.global_transform * top
	var taut := bobber.reeled or bobber.state == Fishing.State.BITE
	var sag := 0.0 if taut else SAG * tip.distance_to(end)
	_strip.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in LINE_POINTS + 1:
		var t := float(i) / LINE_POINTS
		var point := tip.lerp(end, t) - Vector3(0.0, sag * 4.0 * t * (1.0 - t), 0.0)
		_strip.surface_add_vertex(point)
	_strip.surface_end()


## The water (or else what else) the player aims at to cast.
func _target(feet: Vector3) -> Vector3:
	if client.interaction.pad_aiming and client.first_person < 1.0:
		var heading := client.local_player.heading
		return feet + Vector3(heading.x, 0.0, heading.y) * PAD_CAST
	var ray := client.interaction.aim_ray()
	var origin: Vector3 = ray[0]
	var direction: Vector3 = ray[1]
	var watery := func(cell: Vector3i) -> int:
		var voxel := client.world.voxel_at(cell)
		return Voxels.of_block(Tiles.Block.STONE) if Voxels.is_water(voxel) else voxel
	var far := FAR if client.first_person < 1.0 else Fishing.CAST_RANGE + 8.0
	var hit := VoxelRay.cast(origin, direction, far, watery)
	if hit != null:
		return hit.point
	return origin + direction * minf(far, Fishing.CAST_RANGE)


## Says which bait the next cast takes (the first in the slots).
func _tell_bait() -> void:
	var slot := Fishing.bait_slot(client.inventory)
	if slot < 0:
		client.hotbar.announce(tr("HUD_ROD_NO_BAIT"))
		return
	var bait := client.inventory.items[slot]
	var count := 0
	for i in Inventory.SLOTS:
		if client.inventory.items[i] == bait:
			count += client.inventory.counts[i]
	client.hotbar.announce(tr("HUD_ROD_BAIT") % [tr(Items.name_key(bait)), count])
