class_name Lobby
extends RefCounted
## Players coming and going (multiplayer, step 1; static, given the server).
## A player says hello (Msg.HELLO): a dedicated server refuses them
## (`refusal`: Msg.REFUSED, then lets them go) when their game speaks
## another version of the messages (Msg.PROTOCOL), the password is wrong
## (GameServer.password), their name is not one (NAME: 2 to 16 letters,
## digits, - or _; it names their save) or is already playing, or the
## server is full (GameServer.max_players). The same name from the same
## machine (Transport.ip) is the player back after their connection broke,
## before ENet noticed: their old session ends (`take_over`). A connection
## gone (its transport closed) ends their session (`leave`): off a boat,
## what they held open closed, saved, the others told (a dedicated
## server's chat). Everyone is told who plays when someone comes or goes
## (Peers.tell_roster). On a dedicated server only its admins change the
## world's time, seasons and game mode (`may_change_world`).

const NAME := "^[\\p{L}\\p{N}_-]{2,16}$"

static var _name := _compile()


## Why a player saying hello (on `session`) is refused ("": they are
## welcome).
static func refusal(
	server: GameServer, session: GameServer.PlayerSession, message: Dictionary
) -> String:
	if int(message.get("protocol", -1)) != Msg.PROTOCOL:
		return "REFUSED_VERSION"
	if server.password != "" and str(message.get("password", "")) != server.password:
		return "REFUSED_PASSWORD"
	var name := str(message.get("name", ""))
	if not is_name(name):
		return "REFUSED_NAME"
	var playing := Chat.find_player(server, name)
	var back := playing != null and _same_machine(playing, session)
	if playing != null and not back:
		return "REFUSED_NAME_TAKEN"
	var others := players(server) - (1 if back else 0)
	if server.max_players > 0 and others >= server.max_players:
		return "REFUSED_FULL"
	return ""


## A player welcome as `name` on `session`: if they still play on another
## connection (from the same machine: see refusal), that one ends.
static func take_over(server: GameServer, session: GameServer.PlayerSession, name: String) -> void:
	var playing := Chat.find_player(server, name)
	if playing != null and playing != session:
		leave(server, playing)


## Whether `name` may be a player's (NAME).
static func is_name(name: String) -> bool:
	return _name.search(name) != null


## How many players have joined.
static func players(server: GameServer) -> int:
	var count := 0
	for session in server.sessions:
		if session.joined:
			count += 1
	return count


## A player joined: on a dedicated server, everyone is told.
static func joined(server: GameServer, session: GameServer.PlayerSession) -> void:
	if server.dedicated:
		server.broadcast(Msg.chat_notice("CHAT_JOINED", [session.player_name], Chat.Tone.INFO))
	Peers.tell_roster(server)


## A player's connection is gone: their session ends (see the class).
static func leave(server: GameServer, session: GameServer.PlayerSession) -> void:
	server.sessions.erase(session)
	session.transport.close()
	if not session.joined:
		return
	server.boats.leave(server, session, false)
	session.line = null
	session.chest = GameServer.NO_CELL
	session.furnace = GameServer.NO_CELL
	session.sleeping = false
	for left in session.inventory.put_back_all():
		server.throw_item(session, left.x, left.y, left.z)
	if server.storage != null:
		server.storage.save_player(session.player_name, GameServer.player_state(session))
	session.joined = false
	if server.dedicated:
		server.broadcast(Msg.chat_notice("CHAT_LEFT", [session.player_name], Chat.Tone.INFO))
	Peers.tell_roster(server)


## Whether a player may change the world's time, seasons or game mode:
## anyone in solo, a dedicated server's admins.
static func may_change_world(server: GameServer, session: GameServer.PlayerSession) -> bool:
	return not server.dedicated or Chat.is_admin(server, session)


## Two connections from one machine (not over the network: never).
static func _same_machine(a: GameServer.PlayerSession, b: GameServer.PlayerSession) -> bool:
	return a.transport.ip() != "" and a.transport.ip() == b.transport.ip()


static func _compile() -> RegEx:
	var regex := RegEx.new()
	regex.compile(NAME)
	return regex
