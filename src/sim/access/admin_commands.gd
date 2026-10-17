class_name AdminCommands
extends RefCounted
## The commands that keep a server (multiplayer, step 4; Commands; static,
## given the server): kick (moderators), ban, unban, whitelist, role,
## account and backup (admins). What they change is saved at once
## (GameServer.keep_access). Players are named as they play (or played:
## bans, roles and the whitelist take names of players away). Each returns
## false when its words do not fit (Commands then shows its usage).

const ON_WORDS := ["on", "oui"]
const OFF_WORDS := ["off", "non"]
const RESET_WORDS := ["reset", "oublie"]
const IP_WORDS := ["ip", "adresse"]
## Role words: Access.ROLE_NAMES and their French.
const ROLE_WORDS := {
	"visitor": Access.Role.VISITOR,
	"visiteur": Access.Role.VISITOR,
	"player": Access.Role.PLAYER,
	"joueur": Access.Role.PLAYER,
	"moderator": Access.Role.MODERATOR,
	"moderateur": Access.Role.MODERATOR,
	"admin": Access.Role.ADMIN,
}


## kick <player> [reason]: sent away (Msg.KICKED), everyone told.
static func kick(server: GameServer, session: GameServer.PlayerSession, args: Array) -> bool:
	if args.is_empty():
		return false
	var other := Chat.find_player(server, args[0])
	if other == null:
		Chat.tell(session, "CHAT_NO_PLAYER", [args[0]], Chat.Tone.ERROR)
		return true
	if not _outranks(server, session, other):
		Chat.tell(session, "CMD_KICK_HIGHER", [other.player_name], Chat.Tone.ERROR)
		return true
	var reason := " ".join(PackedStringArray(args.slice(1)))
	other.transport.send(Msg.kicked("KICKED_BY", [session.player_name, reason]))
	other.transport.close()
	server.broadcast(Msg.chat_notice("CMD_KICK_DONE", [other.player_name], Chat.Tone.INFO))
	return true


## ban <player> [time] [ip] [reason] | ban list: banned, sent away if
## here; `time` as Access.minutes_in, for ever without; with "ip" the
## address they come from too (asked for only: a household or a mobile
## network shares one).
static func ban(server: GameServer, session: GameServer.PlayerSession, args: Array) -> bool:
	if args.is_empty():
		return false
	if args.size() == 1 and Commands.is_word(args[0], PlayerCommands.LIST_WORDS):
		_list_bans(server, session)
		return true
	var name: String = args[0]
	var other := Chat.find_player(server, name)
	if other != null:
		name = other.player_name
		if not _outranks(server, session, other):
			Chat.tell(session, "CMD_KICK_HIGHER", [name], Chat.Tone.ERROR)
			return true
	var rest := args.slice(1)
	var minutes := Access.minutes_in(rest[0]) if not rest.is_empty() else -1
	if minutes > 0:
		rest = rest.slice(1)
	var ip := ""
	if not rest.is_empty() and Commands.is_word(rest[0], IP_WORDS):
		rest = rest.slice(1)
		ip = server.access.address_of(name)
		if other != null:
			ip = other.transport.ip()
	var reason := " ".join(PackedStringArray(rest))
	server.access.ban(name, maxi(minutes, 0), reason, session.player_name, ip)
	server.keep_access()
	var how_long: Variant = {"minutes": minutes} if minutes > 0 else Chat.word("CMD_BAN_FOREVER")
	if other != null:
		var told := ["KICKED_BANNED", [session.player_name, how_long, reason]]
		other.transport.send(Msg.kicked(told[0], told[1]))
		other.transport.close()
	server.broadcast(Msg.chat_notice("CMD_BAN_DONE", [name, how_long], Chat.Tone.INFO))
	return true


## unban <player>.
static func unban(server: GameServer, session: GameServer.PlayerSession, args: Array) -> bool:
	if args.size() != 1:
		return false
	if not server.access.unban(args[0]):
		Chat.tell(session, "CMD_UNBAN_NOT", [args[0]], Chat.Tone.ERROR)
		return true
	server.keep_access()
	Chat.tell(session, "CMD_UNBAN_DONE", [args[0]], Chat.Tone.DONE)
	return true


## whitelist on | off | add <player> | remove <player> | list.
static func whitelist(server: GameServer, session: GameServer.PlayerSession, args: Array) -> bool:
	var access := server.access
	if args.size() == 1 and Commands.is_word(args[0], PlayerCommands.LIST_WORDS):
		var state := Chat.word("CMD_WHITELIST_ON" if access.whitelist_on else "CMD_WHITELIST_OFF")
		Chat.tell(session, "CMD_WHITELIST_LIST", [state, ", ".join(access.whitelist)])
		return true
	if args.size() == 1 and (Commands.is_word(args[0], ON_WORDS + OFF_WORDS)):
		access.whitelist_on = Commands.is_word(args[0], ON_WORDS)
		if access.whitelist_on:
			# Those playing stay on it.
			for other in server.sessions:
				if other.joined and not other.player_name.to_lower() in access.whitelist:
					access.whitelist.append(other.player_name.to_lower())
		server.keep_access()
		var key := "CMD_WHITELIST_ON" if access.whitelist_on else "CMD_WHITELIST_OFF"
		Chat.tell(session, key, [], Chat.Tone.DONE)
		return true
	if args.size() != 2:
		return false
	var name := String(args[1]).to_lower()
	if Commands.is_word(args[0], PlayerCommands.ADD_WORDS):
		if not name in access.whitelist:
			access.whitelist.append(name)
		server.keep_access()
		Chat.tell(session, "CMD_WHITELIST_ADDED", [args[1]], Chat.Tone.DONE)
		return true
	if Commands.is_word(args[0], PlayerCommands.REMOVE_WORDS):
		access.whitelist.erase(name)
		server.keep_access()
		Chat.tell(session, "CMD_WHITELIST_REMOVED", [args[1]], Chat.Tone.DONE)
		return true
	return false


## role <player> [visitor | player | moderator | admin]: tells it, or
## gives it (Access.set_role; the roster tells everyone).
static func role(server: GameServer, session: GameServer.PlayerSession, args: Array) -> bool:
	if args.is_empty() or args.size() > 2:
		return false
	var name: String = args[0]
	var other := Chat.find_player(server, name)
	if other != null:
		name = other.player_name
	var access := server.access
	if args.size() == 1:
		var now := Chat.word(Access.ROLE_KEYS[access.role_of(server, name)])
		Chat.tell(session, "CMD_ROLE_IS", [name, now])
		return true
	var wanted: Variant = ROLE_WORDS.get(Chat.plain(args[1]))
	if wanted == null:
		return false
	if not access.set_role(server, name, wanted):
		Chat.tell(session, "CMD_ADMIN_LAST", [], Chat.Tone.ERROR)
		return true
	server.keep_access()
	var given := Chat.word(Access.ROLE_KEYS[wanted])
	Chat.tell(session, "CMD_ROLE_DONE", [name, given], Chat.Tone.DONE)
	if other != null and other != session:
		Chat.tell(other, "CMD_ROLE_YOU", [session.player_name, given], Chat.Tone.DONE)
	Peers.tell_roster(server)
	return true


## account reset <player>: their password forgotten (the next to come under
## that name chooses it).
static func account(server: GameServer, session: GameServer.PlayerSession, args: Array) -> bool:
	if args.size() != 2 or not Commands.is_word(args[0], RESET_WORDS):
		return false
	if not server.access.forget_account(args[1]):
		Chat.tell(session, "CMD_ACCOUNT_NONE", [args[1]], Chat.Tone.ERROR)
		return true
	server.keep_access()
	Chat.tell(session, "CMD_ACCOUNT_RESET", [args[1]], Chat.Tone.DONE)
	return true


## backup: a backup of the world now (a dedicated server's: Backups).
static func backup(server: GameServer, session: GameServer.PlayerSession) -> bool:
	if not server.backup_request.is_valid():
		Chat.tell(session, "CMD_BACKUP_NONE", [], Chat.Tone.ERROR)
		return true
	var started: bool = server.backup_request.call()
	var key := "CMD_BACKUP_STARTED" if started else "CMD_BACKUP_BUSY"
	Chat.tell(session, key, [], Chat.Tone.DONE if started else Chat.Tone.ERROR)
	return true


## Whether `session` may send `other` away: a higher role (the console:
## anyone).
static func _outranks(
	server: GameServer, session: GameServer.PlayerSession, other: GameServer.PlayerSession
) -> bool:
	return (
		session.console or server.access.rank(server, other) < server.access.rank(server, session)
	)


static func _list_bans(server: GameServer, session: GameServer.PlayerSession) -> void:
	var now := Time.get_unix_time_from_system()
	var bans := server.access.bans
	Chat.tell(session, "CMD_BAN_LIST", [bans.size()])
	for name: String in bans:
		var entry: Dictionary = bans[name]
		var until := float(entry.get("until", 0.0))
		var how_long: Variant = Chat.word("CMD_BAN_FOREVER")
		if until > 0.0:
			how_long = {"minutes": ceili((until - now) / 60.0)}
		Chat.tell(session, "CMD_BAN_ENTRY", [name, how_long, str(entry.get("reason", ""))])
