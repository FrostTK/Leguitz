class_name Commands
extends RefCounted
## The chat's commands (static, given the server): a line typed after "/"
## is a command's name (English, or its French alias; accents and case do
## not matter) and its words. LIST says the least role that may use each
## (Access.Role: visitors and up, moderators, admins; Access.rank); each
## has its usage and help in the translations (CMD_<NAME>_USAGE,
## CMD_<NAME>_HELP: help lists them). Those for everyone run here; travel
## and the world's are WorldCommands', items (give, clear), creatures and
## admins PlayerCommands', keeping a server AdminCommands'. Answers go to
## the chat (Chat.tell).

const EVERYONE := Access.Role.VISITOR
const MODERATORS := Access.Role.MODERATOR
const ADMINS := Access.Role.ADMIN
## The commands, in the order help lists them.
const LIST: Array[Dictionary] = [
	{"name": "help", "alias": "aide", "role": EVERYONE},
	{"name": "players", "alias": "joueurs", "role": EVERYONE},
	{"name": "msg", "alias": "mp", "role": EVERYONE},
	{"name": "where", "alias": "ou", "role": EVERYONE},
	{"name": "seed", "alias": "graine", "role": EVERYONE},
	{"name": "clear", "alias": "vide", "role": EVERYONE},
	{"name": "tp", "alias": "tp", "role": MODERATORS},
	{"name": "kick", "alias": "expulse", "role": MODERATORS},
	{"name": "time", "alias": "heure", "role": ADMINS},
	{"name": "season", "alias": "saison", "role": ADMINS},
	{"name": "weather", "alias": "meteo", "role": ADMINS},
	{"name": "gamemode", "alias": "mode", "role": ADMINS},
	{"name": "give", "alias": "donne", "role": ADMINS},
	{"name": "summon", "alias": "invoque", "role": ADMINS},
	{"name": "heal", "alias": "soigne", "role": ADMINS},
	{"name": "admin", "alias": "admin", "role": ADMINS},
	{"name": "role", "alias": "role", "role": ADMINS},
	{"name": "ban", "alias": "bannis", "role": ADMINS},
	{"name": "unban", "alias": "gracie", "role": ADMINS},
	{"name": "whitelist", "alias": "listeblanche", "role": ADMINS},
	{"name": "account", "alias": "compte", "role": ADMINS},
	{"name": "backup", "alias": "sauvegarde", "role": ADMINS},
]
## How help names who may use a command (by its role).
const WHO_KEYS := {
	EVERYONE: "CHAT_FOR_EVERYONE", MODERATORS: "CHAT_FOR_MODERATORS", ADMINS: "CHAT_FOR_ADMINS"
}


## Runs the command `line` (what follows "/") for a player.
static func run(server: GameServer, session: GameServer.PlayerSession, line: String) -> void:
	var words := line.strip_edges().split(" ", false)
	if words.is_empty():
		Chat.tell(session, "CHAT_HOW", [], Chat.Tone.ERROR)
		return
	var command := find(words[0])
	if command.is_empty():
		Chat.tell(session, "CHAT_UNKNOWN", [words[0]], Chat.Tone.ERROR)
		return
	if server.access.rank(server, session) < command["role"]:
		var who := Chat.word(WHO_KEYS[command["role"]])
		Chat.tell(session, "CHAT_NOT_ALLOWED", ["/" + words[0], who], Chat.Tone.ERROR)
		return
	var args := Array(words.slice(1))
	var done := false
	match command["name"]:
		"help":
			done = _help(server, session, args)
		"players":
			done = _players(server, session)
		"msg":
			done = _whisper(server, session, args)
		"where":
			done = _where(server, session)
		"seed":
			Chat.tell(session, "CMD_SEED_DONE", [str(server.settings.world_seed)])
			done = true
		"clear":
			done = PlayerCommands.clear(server, session, args)
		"tp":
			done = WorldCommands.teleport(server, session, args)
		"time":
			done = WorldCommands.time(server, session, args)
		"season":
			done = WorldCommands.season(server, session, args)
		"weather":
			done = WorldCommands.weather(server, session, args)
		"gamemode":
			done = WorldCommands.game_mode(server, session, args)
		"give":
			done = PlayerCommands.give(server, session, args)
		"summon":
			done = PlayerCommands.summon(server, session, args)
		"heal":
			done = PlayerCommands.heal(server, session)
		"admin":
			done = PlayerCommands.admin(server, session, args)
		"kick":
			done = AdminCommands.kick(server, session, args)
		"ban":
			done = AdminCommands.ban(server, session, args)
		"unban":
			done = AdminCommands.unban(server, session, args)
		"whitelist":
			done = AdminCommands.whitelist(server, session, args)
		"role":
			done = AdminCommands.role(server, session, args)
		"account":
			done = AdminCommands.account(server, session, args)
		"backup":
			done = AdminCommands.backup(server, session)
	if not done:
		Chat.tell(session, "CHAT_USAGE", [Chat.word(usage_key(command))], Chat.Tone.ERROR)


## The command called `typed` (its name or alias), {} if none.
static func find(typed: String) -> Dictionary:
	var wanted := Chat.plain(typed)
	for command in LIST:
		if wanted == command["name"] or wanted == command["alias"]:
			return command
	return {}


## The commands a player may use.
static func available(server: GameServer, session: GameServer.PlayerSession) -> Array[Dictionary]:
	var rank := server.access.rank(server, session)
	var commands: Array[Dictionary] = []
	for command in LIST:
		if rank >= command["role"]:
			commands.append(command)
	return commands


static func usage_key(command: Dictionary) -> String:
	return "CMD_%s_USAGE" % String(command["name"]).to_upper()


static func help_key(command: Dictionary) -> String:
	return "CMD_%s_HELP" % String(command["name"]).to_upper()


## Whether `typed` is one of `words` (plain: no accents, any case).
static func is_word(typed: String, words: Array) -> bool:
	return Chat.plain(typed) in words


## help: the commands the player may use, or one of them in detail.
static func _help(server: GameServer, session: GameServer.PlayerSession, args: Array) -> bool:
	if not args.is_empty():
		var command := find(args[0])
		if command.is_empty():
			Chat.tell(session, "CHAT_UNKNOWN", [args[0]], Chat.Tone.ERROR)
			return true
		var who: String = WHO_KEYS[command["role"]]
		Chat.tell(session, "CHAT_HELP_LINE", [Chat.word(usage_key(command)), Chat.word(who)])
		Chat.tell(session, help_key(command))
		return true
	Chat.tell(session, "CHAT_HELP_TITLE")
	for command in available(server, session):
		Chat.tell(
			session, "CHAT_HELP_LINE", [Chat.word(usage_key(command)), Chat.word(help_key(command))]
		)
	return true


## players: who is here (admins marked ★, moderators ☆).
static func _players(server: GameServer, session: GameServer.PlayerSession) -> bool:
	var names := PackedStringArray()
	for other in server.sessions:
		if other.joined:
			var role := server.access.rank(server, other)
			var mark: String = {Access.Role.ADMIN: " ★", Access.Role.MODERATOR: " ☆"}.get(role, "")
			names.append(other.player_name + mark)
	Chat.tell(session, "CMD_PLAYERS_DONE", [names.size(), ", ".join(names)])
	return true


## msg <player> <text>: only that player reads it.
static func _whisper(server: GameServer, session: GameServer.PlayerSession, args: Array) -> bool:
	if args.size() < 2:
		return false
	var other := Chat.find_player(server, args[0])
	if other == null:
		Chat.tell(session, "CHAT_NO_PLAYER", [args[0]], Chat.Tone.ERROR)
		return true
	var text := " ".join(PackedStringArray(args.slice(1)))
	Chat.tell(other, "CMD_MSG_FROM", [session.player_name, text], Chat.Tone.WHISPER)
	Chat.tell(session, "CMD_MSG_TO", [other.player_name, text], Chat.Tone.WHISPER)
	return true


## where: the player's tile, level and biome.
static func _where(server: GameServer, session: GameServer.PlayerSession) -> bool:
	var tile := Coords.world_to_tile(session.position)
	var biome := server.world.generator.sample_column(tile.x, tile.y).biome
	Chat.tell(
		session,
		"CMD_WHERE_DONE",
		[tile.x, roundi(session.height), tile.y, Chat.word(Biomes.name_key(biome))]
	)
	return true
