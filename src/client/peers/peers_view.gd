class_name PeersView
extends Node3D
## The other players in view (multiplayer, step 2), under the world root
## (local units): a PlayerModel each (`peer`), from Msg.PEER, PEER_MOVE and
## PEER_GONE (Peers, on the server). Each message is stamped with the
## server's tick: a player is drawn where they were DELAY seconds before
## the latest news, between the two moves around that moment, so they
## glide even when messages come bunched (`_origin` maps ticks to this
## machine's time, from the fastest delivery seen). A move longer than SNAP
## (a teleport) is not glided. They take the pose they are told
## (PlayerModel.take_pose), each single stroke counted (swings), hold and
## wear what they do, come into view and go fading (FADE_SECONDS); their
## lantern lights in the dark (the night, or their own sky light: under
## rock). PeerNames draws their names (`labels`).

## How far behind the latest news a player is drawn (seconds): it rides out
## the network's unevenness.
const DELAY := 0.1
## A move longer than this (tiles) is a jump, not glided.
const SNAP := 4.0
const FADE_SECONDS := 0.4
## Moves kept per player (more than DELAY's worth).
const MOST_MOVES := 16
## How fast the bow comes up, a body lies down and the sky light follows
## (per second), and the walk's speed.
const EASE := 8.0
const SPEED_EASE := 12.0
## Where a name floats over the feet (levels).
const NAME_HEIGHT := 2.25
## Under cover the lantern hangs this high over the feet (levels), not high
## over the head (inside the rock).
const LANTERN_UNDER_COVER := 1.8
## The tick clock (`_origin`) drifts later this much a second (msec), so
## that it follows deliveries growing slower; a faster one pulls it back.
const CLOCK_DRIFT := 20.0
const TICK_MSEC := GameConst.TICK_DELTA * 1000.0


class Peer:
	extends RefCounted
	var id := 0
	var name := ""
	var model := PlayerModel.new()
	## [server tick, feet (world pixels), height (levels), yaw (radians)].
	var moves: Array[Array] = []
	var pose := 0
	var swings := 0
	## 1: unseen (coming or leaving), 0: shown.
	var fade := 1.0
	var leaving := false
	var sky := 1.0
	var aiming := 0.0
	var down := 0.0
	var speed := 0.0
	## Where it was drawn last frame (local units; INF: nowhere yet).
	var feet := Vector3.INF


var library: ItemLibrary
var client_world: ClientWorld
var world_view: WorldView3D
var lighting: LightingController
var peers: Dictionary[int, Peer] = {}

## This machine's time (msec) of the server's tick 0, as best seen.
var _origin := INF


## A player comes into view (Msg.PEER).
func on_peer(message: Dictionary) -> void:
	var id := int(message["id"])
	var peer: Peer = peers.get(id)
	if peer == null:
		peer = Peer.new()
		peer.id = id
		peer.model.peer = true
		add_child(peer.model)
		peers[id] = peer
	peer.leaving = false
	peer.name = str(message.get("name", ""))
	peer.moves.clear()
	peer.feet = Vector3.INF
	peer.swings = int(message.get("swings", 0))
	_take(peer, message)


## What changed of a player in view (Msg.PEER_MOVE).
func on_move(message: Dictionary) -> void:
	var peer: Peer = peers.get(int(message["id"]))
	if peer == null or peer.leaving:
		return
	if message.has("swings") and int(message["swings"]) != peer.swings:
		peer.swings = int(message["swings"])
		peer.model.swing()
	_take(peer, message)


## A player went out of view (Msg.PEER_GONE): they fade away.
func gone(id: int) -> void:
	if peers.has(id):
		peers[id].leaving = true


## The players' names to draw: [name, where over the head (global), how
## visible (0..1), their feet (local units)].
func labels() -> Array:
	var shown := []
	for peer: Peer in peers.values():
		if peer.feet != Vector3.INF and peer.fade < 1.0:
			var head := to_global(peer.feet + Vector3(0.0, NAME_HEIGHT - peer.down, 0.0))
			shown.append([peer.name, head, 1.0 - peer.fade, peer.feet])
	return shown


func _process(delta: float) -> void:
	if _origin != INF:
		_origin += CLOCK_DRIFT * delta
	var at := (Time.get_ticks_msec() - DELAY * 1000.0 - _origin) / TICK_MSEC
	for id: int in peers.keys():
		var peer := peers[id]
		peer.fade = move_toward(peer.fade, 1.0 if peer.leaving else 0.0, delta / FADE_SECONDS)
		if peer.leaving and peer.fade >= 1.0:
			peer.model.queue_free()
			peers.erase(id)
			continue
		if not peer.moves.is_empty():
			_animate(peer, at, delta)


## Takes what a message tells of a player: a move (stamped with its tick),
## the pose, what they hold and wear.
func _take(peer: Peer, message: Dictionary) -> void:
	var tick := int(message.get("tick", 0))
	var now := Time.get_ticks_msec() - tick * TICK_MSEC
	_origin = minf(_origin, now)
	if message.has("pos") or message.has("h") or message.has("yaw"):
		_add_move(peer, tick, message)
	if message.has("pose"):
		peer.pose = int(message["pose"])
		peer.model.take_pose(peer.pose)
	if message.has("held"):
		peer.model.hold_item(int(message["held"]), library)
	if message.has("armor"):
		var worn: Array[int] = []
		for item: Variant in message["armor"]:
			worn.append(int(item))
		peer.model.set_armor(worn)


## A move at `tick`: what it does not tell stays as it was. Unchanged
## since an older move, the player stood there until the tick before.
func _add_move(peer: Peer, tick: int, message: Dictionary) -> void:
	var move := [tick, Vector2.ZERO, 0.0, 0.0]
	if not peer.moves.is_empty():
		var last: Array = peer.moves.back()
		move = [tick, last[1], last[2], last[3]]
		if tick - int(last[0]) > 1:
			peer.moves.append([tick - 1, last[1], last[2], last[3]])
	move[1] = message.get("pos", move[1])
	move[2] = float(message.get("h", move[2]))
	move[3] = float(message.get("yaw", move[3]))
	if not peer.moves.is_empty():
		var last: Array = peer.moves.back()
		var step: Vector2 = (move[1] - last[1]) / GameConst.TILE_SIZE
		if step.length() > SNAP or absf(move[2] - last[2]) > SNAP:
			peer.moves.clear()
			peer.feet = Vector3.INF
	peer.moves.append(move)
	while peer.moves.size() > MOST_MOVES:
		peer.moves.pop_front()


## Draws a player where they were at tick `at` (fractional), doing what
## they do.
func _animate(peer: Peer, at: float, delta: float) -> void:
	var move := sample(peer.moves, at)
	var pos: Vector2 = move[0]
	var height: float = move[1]
	var feet := Render3D.world_px_to_local(pos, height)
	var speed := 0.0
	if peer.feet != Vector3.INF:
		speed = Vector2(feet.x - peer.feet.x, feet.z - peer.feet.z).length() / maxf(delta, 0.001)
	peer.feet = feet
	peer.speed = lerpf(peer.speed, speed, 1.0 - exp(-SPEED_EASE * delta))
	var ease := 1.0 - exp(-EASE * delta)
	var aiming := 1.0 if peer.pose & PlayerModel.Pose.AIM else 0.0
	peer.aiming = lerpf(peer.aiming, aiming, ease)
	peer.model.aiming = peer.aiming if peer.aiming > 0.02 else 0.0
	var down := 1.0 if peer.pose & PlayerModel.Pose.DOWN else 0.0
	peer.down = move_toward(peer.down, down, delta * 2.0)
	peer.model.set_down(smoothstep(0.0, 1.0, peer.down))
	var tile := Coords.world_to_tile(pos - Vector2(0, 1))
	peer.sky = lerpf(peer.sky, world_view.sky_of_body(tile, height), ease)
	peer.model.set_sky_light(peer.sky)
	peer.model.set_fade(peer.fade)
	_light(peer, tile, height, feet)
	var yaw: float = move[2]
	var airborne := peer.pose & PlayerModel.Pose.AIR != 0
	peer.model.animate(feet, Vector2(sin(yaw), cos(yaw)), peer.speed, airborne, delta)


## Their lantern: lit in the dark (the night's, or under rock their own),
## under a roof hung low.
func _light(peer: Peer, tile: Vector2i, height: float, feet: Vector3) -> void:
	var lantern := peer.model.lantern
	var dark := maxf(lighting.dusk, 1.0 - smoothstep(0.0, 1.0, peer.sky))
	lantern.light_energy = LightingController.lantern_energy(dark) * (1.0 - peer.fade)
	lantern.visible = lantern.light_energy > 0.02
	lantern.shadow_enabled = lighting.lantern.shadow_enabled
	peer.model.lantern_override = Vector3.INF
	if client_world.is_covered(tile, height):
		peer.model.lantern_override = to_global(feet + Vector3(0.0, LANTERN_UNDER_COVER, 0.0))


## Where `moves` put a player at tick `at`: [feet (world pixels), height,
## yaw], between the two moves around it (the first before them all, the
## last after).
static func sample(moves: Array[Array], at: float) -> Array:
	var last: Array = moves.back()
	if moves.size() == 1 or at >= float(last[0]):
		return [last[1], last[2], last[3]]
	var first: Array = moves[0]
	if at <= float(first[0]):
		return [first[1], first[2], first[3]]
	for i in range(moves.size() - 2, -1, -1):
		var before: Array = moves[i]
		if float(before[0]) <= at:
			var after: Array = moves[i + 1]
			var t := (at - float(before[0])) / maxf(float(after[0]) - float(before[0]), 1.0)
			var pos: Vector2 = (before[1] as Vector2).lerp(after[1], t)
			var yaw := lerp_angle(float(before[3]), float(after[3]), t)
			return [pos, lerpf(before[2], after[2], t), yaw]
	return [first[1], first[2], first[3]]
