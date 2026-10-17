class_name Peers
extends RefCounted
## The other players each player sees (multiplayer, step 2; static, given
## the server). A player's client tells where its body is and what it does
## (Msg.player_move: `take_look` keeps where it looks, its PlayerModel.Pose
## bits and its strokes counted); every tick `sync` sends each player the
## others standing in the chunks it has (PlayerSession.sent_chunks):
## Msg.PEER when one comes into view (their name and `state`: feet, height,
## yaw, pose, strokes, what they hold, the armor they wear), Msg.PEER_MOVE
## with what changed, Msg.PEER_GONE when one goes out of view or leaves. A
## spectator is seen by nobody. The roster (`roster`, Msg.PLAYERS: names,
## pings, admins) is told to everyone when a player joins or leaves (Lobby)
## and every ROSTER_TICKS (the pings change).

## What a body does, as the other players are told (bits: PlayerModel
## `pose` and `take_pose`; the bow's draw in the bits from DRAW_SHIFT, in
## DRAW_STEPS steps). The server adds what it knows: seated, lying down.
enum Pose {
	SWIM = 1,
	AIR = 2,
	SWING = 4,
	EAT = 8,
	AIM = 16,
	CAST = 32,
	SEATED = 64,
	ROW = 128,
	DOWN = 256,
}

const ROSTER_TICKS := GameConst.TICKS_PER_SECOND * 5
const DRAW_SHIFT := 12
const DRAW_STEPS := 15
## A pose and strokes are bits up to this.
const POSE_MASK := 0xFFFF


## Keeps what a player's client told of their body (Msg.player_move); what
## is no number is ignored.
static func take_look(session: GameServer.PlayerSession, message: Dictionary) -> void:
	var yaw: Variant = message.get("yaw")
	if yaw is float and is_finite(yaw):
		session.yaw = wrapf(yaw, -PI, PI)
	var pose: Variant = message.get("pose")
	if pose is int:
		session.pose = pose & POSE_MASK
	var swings: Variant = message.get("swings")
	if swings is int:
		session.swings = swings & POSE_MASK


## What the other players see of a player now.
static func state(session: GameServer.PlayerSession) -> Dictionary:
	var armor := []
	for piece in Armor.PIECES:
		armor.append(session.inventory.items[Inventory.ARMOR + piece])
	# What the server knows: seated, lying in bed or passed out.
	var pose := session.pose
	if session.sits_on != GameServer.NO_CELL:
		pose |= Pose.SEATED
	if session.sleeping or not session.alive():
		pose |= Pose.DOWN
	return {
		"pos": session.position,
		"h": session.height,
		"yaw": session.yaw,
		"pose": pose,
		"swings": session.swings,
		"held": session.inventory.held(),
		"armor": armor,
	}


## Tells each player about the others in their view (see the class).
static func sync(server: GameServer) -> void:
	var seen_by_all: Dictionary[int, GameServer.PlayerSession] = {}
	var states: Dictionary[int, Dictionary] = {}
	for session in server.sessions:
		if session.joined and not session.spectator:
			seen_by_all[session.id] = session
			states[session.id] = state(session)
	for viewer in server.sessions:
		if viewer.joined:
			_show(viewer, seen_by_all, states, server.tick_count)
	if server.tick_count % ROSTER_TICKS == 0:
		tell_roster(server)


## Who plays: [{id, name, ping (ms), admin, role (Access.Role)}], in the
## order they joined.
static func roster(server: GameServer) -> Array:
	var players := []
	for session in server.sessions:
		if not session.joined:
			continue
		var player := {
			"id": session.id,
			"name": session.player_name,
			"ping": session.transport.latency(),
			"admin": Chat.is_admin(server, session),
			"role": server.access.rank(server, session),
		}
		players.append(player)
	return players


## Tells every player who plays (Msg.PLAYERS).
static func tell_roster(server: GameServer) -> void:
	var message := Msg.players(roster(server))
	for session in server.sessions:
		if session.joined:
			session.transport.send(message)


static func _show(
	viewer: GameServer.PlayerSession,
	others: Dictionary[int, GameServer.PlayerSession],
	states: Dictionary[int, Dictionary],
	tick: int
) -> void:
	var seen := viewer.seen_peers
	for id: int in seen.keys():
		if not states.has(id) or not _in_view(viewer, states[id]):
			seen.erase(id)
			viewer.transport.send(Msg.peer_gone(id))
	for id: int in states:
		var now: Dictionary = states[id]
		if id == viewer.id or not _in_view(viewer, now):
			continue
		if not seen.has(id):
			viewer.transport.send(Msg.peer(id, others[id].player_name, now, tick))
		else:
			var changes := _changes(seen[id], now)
			if changes.is_empty():
				continue
			viewer.transport.send(Msg.peer_move(id, changes, tick))
		seen[id] = now


## Whether a player at `peer_state` stands in a chunk `viewer` has.
static func _in_view(viewer: GameServer.PlayerSession, peer_state: Dictionary) -> bool:
	return viewer.sent_chunks.has(Coords.world_to_chunk(peer_state["pos"]))


## What differs from `before` in `now` (their keys and new values).
static func _changes(before: Dictionary, now: Dictionary) -> Dictionary:
	var changes := {}
	for key: String in now:
		if before.get(key) != now[key]:
			changes[key] = now[key]
	return changes
