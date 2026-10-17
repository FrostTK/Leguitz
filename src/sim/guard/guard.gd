class_name Guard
extends RefCounted
## What a dedicated server checks of every player's messages (multiplayer,
## step 3; static, given the server; a solo game trusts its own client).
## `admits` drops what does not look right: before joining anything but a
## hello; a cell that is no Vector3i, out of the world or farther than
## MESSAGE_REACH from the player (a far one would make the server generate
## chunks); a slot, an id or a move's number that is no int; a position or
## a height that is no finite number. And what comes too often: every
## message draws from one bucket (RATE a second, BURST at once), some kinds
## from their own as well (LIMITS: chat lines, blocks placed, digs, maps);
## the chat says so to whoever talks too fast (CHAT_TOO_FAST); KICK_DROPS
## dropped within DROP_WINDOW gets them kicked (`kick`: Msg.KICKED,
## KICKED_FLOOD). A visitor's game may not send what would change the
## world (Access.VISITORS_REFUSED: HUD_VISITOR now and then, the block and
## the slots told again). `report` tells the console what it caught (once every
## REPORT_SECONDS for a player and a kind, with how many since). Each
## player's Watch (PlayerSession.guard) holds their buckets, reports,
## MoveCheck's track and Digging's.

const RATE := 150.0
const BURST := 300.0
const KICK_DROPS := 600
const DROP_WINDOW := 10.0
## Kind -> [a second, at once].
const LIMITS := {
	Msg.CHAT: [0.6, 6.0],
	Msg.BLOCK_PLACE: [12.0, 20.0],
	Msg.DIG: [30.0, 40.0],
	Msg.MAP_REQUEST: [1.0, 3.0],
}
## Tiles from the player's feet a cell in a message may be.
const MESSAGE_REACH := 12.0
const REPORT_SECONDS := 10.0
## Fields that must be whole numbers when given.
const INTS: Array[String] = ["slot", "id", "seq", "pose", "swings"]


## Takes `rate` a second, at most `most` at once.
class Bucket:
	extends RefCounted
	var rate := 0.0
	var most := 0.0
	var tokens := 0.0
	var last := -INF

	func _init(per_second: float, at_once: float) -> void:
		rate = per_second
		most = at_once
		tokens = at_once

	## Takes one at `now` (seconds); false when none is left.
	func take(now: float) -> bool:
		if last != -INF:
			tokens = minf(most, tokens + (now - last) * rate)
		last = now
		if tokens < 1.0:
			return false
		tokens -= 1.0
		return true


## What the server watches of one player.
class Watch:
	extends RefCounted
	var all := Bucket.new(RATE, BURST)
	var kinds: Dictionary[String, Bucket] = {}
	## When messages were dropped lately (seconds).
	var drops: Array[float] = []
	## Kind -> [when last told, how many since].
	var reported: Dictionary[String, Array] = {}
	var move := MoveCheck.Track.new()
	## The block being broken (Vector3i.MAX: none), since when, and when
	## the last one broke (Digging).
	var dig_cell := Vector3i.MAX
	var dig_since := -INF
	var last_break := -INF


## Whether the server takes `message` from `session` (see the class).
static func admits(
	server: GameServer, session: GameServer.PlayerSession, message: Dictionary
) -> bool:
	if not server.dedicated:
		return true
	var kind: Variant = message.get("t")
	if not session.joined:
		return kind == Msg.HELLO
	var now := server.now()
	var watch := session.guard
	if not watch.all.take(now):
		_dropped(server, session, now)
		return false
	if LIMITS.has(kind):
		if not watch.kinds.has(kind):
			var limit: Array = LIMITS[kind]
			watch.kinds[kind] = Bucket.new(limit[0], limit[1])
		if not watch.kinds[kind].take(now):
			if kind == Msg.CHAT:
				session.transport.send(Msg.chat_notice("CHAT_TOO_FAST", [], Chat.Tone.ERROR))
			return false
	if not well_formed(session, message):
		report(server, session, "GUARD_MALFORMED", [str(kind)])
		return false
	if kind in Access.VISITORS_REFUSED:
		if server.access.rank(server, session) == Access.Role.VISITOR:
			_keep_out(server, session, message)
			return false
	return true


## Whether a message's usual fields are what they should be (see the
## class).
static func well_formed(session: GameServer.PlayerSession, message: Dictionary) -> bool:
	if message.has("cell"):
		var cell: Variant = message["cell"]
		if not cell is Vector3i or cell.y < 0 or cell.y >= ChunkData.HEIGHT:
			return false
		var feet := session.position / GameConst.TILE_SIZE
		var at := Vector3(feet.x, session.height + GameConst.SEA_LEVEL, feet.y)
		if at.distance_to(Vector3(cell) + Vector3.ONE * 0.5) > MESSAGE_REACH:
			return false
	for key in INTS:
		if message.has(key) and not message[key] is int:
			return false
	if message.has("facing") and not message["facing"] is Vector2i:
		return false
	if message.has("pos"):
		var pos: Variant = message["pos"]
		if not pos is Vector2 or not pos.is_finite():
			return false
	if message.has("h"):
		var height: Variant = message["h"]
		if not (height is float or height is int) or not is_finite(float(height)):
			return false
	return true


## Tells the console what a player did (`key`: a translation taking their
## name, how many times since it last told, then `args`), at most once
## every REPORT_SECONDS for that kind.
static func report(
	server: GameServer, session: GameServer.PlayerSession, key: String, args := []
) -> void:
	var now := server.now()
	var told: Array = session.guard.reported.get(key, [-INF, 0])
	told[1] += 1
	if now - float(told[0]) >= REPORT_SECONDS:
		if server.console != null:
			var said := [session.player_name, told[1]] + args
			server.console.send(Msg.chat_notice(key, said, Chat.Tone.INFO))
		told = [now, 0]
	session.guard.reported[key] = told


## Sends a player away (`reason`: a translation key; Msg.KICKED, then the
## connection closes and they leave as any).
static func kick(server: GameServer, session: GameServer.PlayerSession, reason: String) -> void:
	session.transport.send(Msg.kicked(reason))
	session.transport.close()
	if server.console != null:
		var said := [session.player_name, Chat.word(reason)]
		var line := Msg.chat_notice("GUARD_KICKED", said, Chat.Tone.INFO)
		server.console.send(line)


## A visitor's game tried to change something: it is told how things are
## (the block, the slots) and the player, now and then, why.
static func _keep_out(
	server: GameServer, session: GameServer.PlayerSession, message: Dictionary
) -> void:
	var cell: Variant = message.get("cell")
	if cell is Vector3i:
		var voxel := server.world.loaded_voxel_at(cell)
		if voxel != Voxels.UNKNOWN:
			session.transport.send(Msg.block_changed(cell, voxel))
	session.transport.send(Msg.inventory(session.inventory))
	var told: Array = session.guard.reported.get("visitor", [-INF, 0])
	if server.now() - float(told[0]) >= REPORT_SECONDS:
		session.guard.reported["visitor"] = [server.now(), 0]
		session.transport.send(Msg.notice("HUD_VISITOR"))


static func _dropped(server: GameServer, session: GameServer.PlayerSession, now: float) -> void:
	var drops := session.guard.drops
	drops.append(now)
	while not drops.is_empty() and now - drops[0] > DROP_WINDOW:
		drops.pop_front()
	if drops.size() >= KICK_DROPS:
		drops.clear()
		kick(server, session, "KICKED_FLOOD")
