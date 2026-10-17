class_name Access
extends RefCounted
## Who may play on a dedicated server and what they may do (multiplayer,
## step 4; GameServer.access, saved in the world's folder by WorldStorage:
## access.cfg the roles, the whitelist and the bans, accounts.cfg the
## accounts). Only a dedicated server asks (a solo game is its player's).
## - Roles (Role): visitors look around (VISITORS_REFUSED: what would change
##   the world or take from it is refused, Guard), players play (the
##   default, `default_role`: ServerConfig's), moderators also kick and
##   send players around, admins do everything (WorldSettings.admins:
##   the world's own list, kept as before). Commands.LIST says each
##   command's role.
## - Accounts (`accounts_on`, ServerConfig.accounts): a name is its first
##   player's: the password they give the first time (the game sends only
##   `secret_of` it, never the password itself) is kept as a salted PBKDF2
##   digest (ITERATIONS); then only that password plays under that name
##   (Lobby; and an account proves its player: they take over their old
##   connection from anywhere). Players change theirs (Msg.SET_PASSWORD),
##   admins forget one (/account reset: the next to come chooses it).
##   MOST_TRIES wrong passwords within LOCK_SECONDS lock the name for
##   LOCK_SECONDS (REFUSED_ACCOUNT_LOCKED): passwords are not guessed by
##   trying them all.
## - The whitelist (`whitelist_on`: only its names join) and bans (by name,
##   and when asked by the address it came from; until a time, or for
##   ever; with a reason), refused with the time left (`refusal`).

enum Role { VISITOR, PLAYER, MODERATOR, ADMIN }

const ROLE_KEYS := {
	Role.VISITOR: "ROLE_VISITOR",
	Role.PLAYER: "ROLE_PLAYER",
	Role.MODERATOR: "ROLE_MODERATOR",
	Role.ADMIN: "ROLE_ADMIN",
}
## Role names in the config file and the commands (and Chat.names_of's).
const ROLE_NAMES := {
	"visitor": Role.VISITOR,
	"player": Role.PLAYER,
	"moderator": Role.MODERATOR,
	"admin": Role.ADMIN,
}
## What a visitor's game may not send.
const VISITORS_REFUSED: Array[String] = [
	Msg.BLOCK_BREAK,
	Msg.BLOCK_PLACE,
	Msg.DIG,
	Msg.TILL,
	Msg.FILL_CAN,
	Msg.WATER,
	Msg.COMPOST,
	Msg.SPREAD_COMPOST,
	Msg.PICK,
	Msg.TEND_ANIMAL,
	Msg.HARVEST_HIVE,
	Msg.USE_MACHINE,
	Msg.OPEN_CHEST,
	Msg.CHEST_CLICK,
	Msg.OPEN_FURNACE,
	Msg.FURNACE_CLICK,
	Msg.OPEN_YARD,
	Msg.BOAT_CLICK,
	Msg.BOAT_ACT,
	Msg.BOAT_HIT,
	Msg.BOAT_PAINT,
	Msg.NET,
	Msg.TINT,
	Msg.SHELF,
	Msg.STOKE,
	Msg.TURN_PICTURE,
	Msg.CATALOG_CLICK,
	Msg.PICK_BLOCK,
]
const ITERATIONS := 4096
const SALT_BYTES := 16
const MOST_TRIES := 5
const LOCK_SECONDS := 600.0

## name (lower case) -> Role, for those not admins (WorldSettings.admins).
var roles: Dictionary[String, int] = {}
var default_role: int = Role.PLAYER
var whitelist_on := false
## Names (lower case).
var whitelist: Array[String] = []
## name (lower case) -> {"reason", "until" (unix seconds; 0: for ever), "by",
## "ip" (the address it last came from: banned too)}.
var bans: Dictionary[String, Dictionary] = {}
var accounts_on := false
## name (lower case) -> {"salt", "digest" (hex), "ip" (last address)}.
var accounts: Dictionary[String, Dictionary] = {}
## name (lower case) -> [wrong tries, since when (unix seconds)] (not
## saved).
var _tries: Dictionary[String, Array] = {}


## What a game sends for `password` under `name` ("": none): it never
## leaves the player's machine as typed.
static func secret_of(player_name: String, password: String) -> String:
	if password.is_empty():
		return ""
	return ("leguitz account:%s:%s" % [player_name.to_lower(), password]).sha256_text()


## A player's role (`name`; the console's is ADMIN).
func role_of(server: GameServer, player_name: String) -> int:
	if is_admin_name(server, player_name):
		return Role.ADMIN
	return roles.get(player_name.to_lower(), default_role)


## A session's role (the console's: ADMIN).
func rank(server: GameServer, session: GameServer.PlayerSession) -> int:
	return Role.ADMIN if session.console else role_of(server, session.player_name)


static func is_admin_name(server: GameServer, player_name: String) -> bool:
	for name in server.settings.admins:
		if name.to_lower() == player_name.to_lower():
			return true
	return false


## Gives `player_name` a role (admins join the world's admins, and leave
## them; the last admin stays). False when it cannot be.
func set_role(server: GameServer, player_name: String, role: int) -> bool:
	var admins := server.settings.admins
	var was_admin := is_admin_name(server, player_name)
	if was_admin and role != Role.ADMIN:
		if admins.size() == 1:
			return false
		for i in range(admins.size() - 1, -1, -1):
			if admins[i].to_lower() == player_name.to_lower():
				admins.remove_at(i)
	if role == Role.ADMIN:
		if not was_admin:
			admins.append(player_name)
		roles.erase(player_name.to_lower())
	else:
		roles[player_name.to_lower()] = role
	return true


## Why `player_name` coming from `ip` with `secret` may not play here: a
## notice [key, args] (its args may hold {"minutes"}: the time left; see
## Chat.notice_text), or [] when they may. Expired bans go.
func refusal(player_name: String, secret: String, ip: String, now: float) -> Array:
	var ban := ban_of(player_name, ip, now)
	if not ban.is_empty():
		var until := float(ban.get("until", 0.0))
		var reason := str(ban.get("reason", ""))
		if until <= 0.0:
			return ["REFUSED_BANNED", [reason]]
		return ["REFUSED_BANNED_FOR", [{"minutes": ceili((until - now) / 60.0)}, reason]]
	if whitelist_on and not player_name.to_lower() in whitelist:
		return ["REFUSED_NOT_LISTED", []]
	if accounts_on:
		var key := player_name.to_lower()
		var account: Dictionary = accounts.get(key, {})
		var tries: Array = _tries.get(key, [0, now])
		if now - float(tries[1]) > LOCK_SECONDS:
			tries = [0, now]
		if tries[0] >= MOST_TRIES:
			var left := ceili((float(tries[1]) + LOCK_SECONDS - now) / 60.0)
			return ["REFUSED_ACCOUNT_LOCKED", [{"minutes": left}]]
		if account.is_empty() and secret.is_empty():
			return ["REFUSED_ACCOUNT_NEEDED", []]
		if not account.is_empty() and secret.is_empty():
			return ["REFUSED_ACCOUNT_PASSWORD", []]
		if not account.is_empty() and not _matches(account, secret):
			tries[0] += 1
			_tries[key] = tries
			return ["REFUSED_ACCOUNT_WRONG", []]
	return []


## Whether `secret` is the password of `player_name`'s account (any, with
## accounts off).
func proves(player_name: String, secret: String) -> bool:
	var account: Dictionary = accounts.get(player_name.to_lower(), {})
	return accounts_on and not account.is_empty() and _matches(account, secret)


## A player joins: their account is made (the first time) and remembers
## where they come from. True when something changed (to save).
func joined(player_name: String, secret: String, ip: String) -> bool:
	if not accounts_on or secret.is_empty():
		return false
	var key := player_name.to_lower()
	if not accounts.has(key):
		accounts[key] = _account(secret)
	accounts[key]["ip"] = ip
	return true


## A player changes their password: false if `old` is not the current one.
func change_password(player_name: String, old: String, new: String) -> bool:
	var account: Dictionary = accounts.get(player_name.to_lower(), {})
	if account.is_empty() or new.is_empty() or not _matches(account, old):
		return false
	var ip: String = account.get("ip", "")
	accounts[player_name.to_lower()] = _account(new)
	accounts[player_name.to_lower()]["ip"] = ip
	return true


## Forgets a player's account (the next to come under that name chooses
## its password). False if there was none.
func forget_account(player_name: String) -> bool:
	return accounts.erase(player_name.to_lower())


## Bans `player_name` (and `ip`, "" for none) for `minutes` (0: for ever).
func ban(player_name: String, minutes: int, reason: String, by: String, ip: String) -> void:
	var until := 0.0
	if minutes > 0:
		until = Time.get_unix_time_from_system() + minutes * 60.0
	bans[player_name.to_lower()] = {"reason": reason, "until": until, "by": by, "ip": ip}


## The address a player last came from ("": unknown; kept with accounts).
func address_of(player_name: String) -> String:
	return str(accounts.get(player_name.to_lower(), {}).get("ip", ""))


func unban(player_name: String) -> bool:
	return bans.erase(player_name.to_lower())


## The ban on `player_name` or on `ip`, {} if none (expired ones go).
func ban_of(player_name: String, ip: String, now: float) -> Dictionary:
	for name: String in bans.keys():
		var entry: Dictionary = bans[name]
		var until := float(entry.get("until", 0.0))
		if until > 0.0 and until <= now:
			bans.erase(name)
			continue
		var same_ip: bool = not ip.is_empty() and entry.get("ip", "") == ip
		if name == player_name.to_lower() or same_ip:
			return entry
	return {}


## A duration in the reader's language ("3 d 4 h", "2 h 5 min", "8 min").
static func duration_text(minutes: int) -> String:
	var days := minutes / (24 * 60)
	var hours := (minutes / 60) % 24
	var left := minutes % 60
	if days > 0:
		return TranslationServer.translate("DURATION_DAYS") % [days, hours]
	if hours > 0:
		return TranslationServer.translate("DURATION_HOURS") % [hours, left]
	return TranslationServer.translate("DURATION_MINUTES") % maxi(left, 1)


## A duration typed in a command ("30m", "2h", "3d", "1w"; a number alone:
## minutes) in minutes; -1 if it is none.
static func minutes_in(typed: String) -> int:
	var text := typed.to_lower().strip_edges()
	var units := {"m": 1, "min": 1, "h": 60, "d": 24 * 60, "j": 24 * 60, "w": 7 * 24 * 60}
	for unit: String in ["min", "m", "h", "d", "j", "w"]:
		var number := text.trim_suffix(unit)
		if number != text and number.is_valid_int() and int(number) > 0:
			return int(number) * units[unit]
	if text.is_valid_int() and int(text) > 0:
		return int(text)
	return -1


func to_dict() -> Dictionary:
	var plain_roles := {}
	for name in roles:
		plain_roles[name] = roles[name]
	var plain_bans := {}
	for name in bans:
		plain_bans[name] = bans[name].duplicate()
	return {
		"roles": plain_roles,
		"whitelist_on": whitelist_on,
		"whitelist": Array(whitelist),
		"bans": plain_bans,
	}


func accounts_dict() -> Dictionary:
	var plain := {}
	for name in accounts:
		plain[name] = accounts[name].duplicate()
	return plain


func load_dict(data: Dictionary) -> void:
	roles.clear()
	for name: Variant in data.get("roles", {}):
		roles[str(name)] = int(data["roles"][name])
	whitelist_on = bool(data.get("whitelist_on", false))
	whitelist.clear()
	for name: Variant in data.get("whitelist", []):
		whitelist.append(str(name).to_lower())
	bans.clear()
	for name: Variant in data.get("bans", {}):
		var entry: Variant = data["bans"][name]
		if entry is Dictionary:
			bans[str(name)] = entry


func load_accounts(data: Dictionary) -> void:
	accounts.clear()
	for name: Variant in data:
		var entry: Variant = data[name]
		if entry is Dictionary and entry.has("salt") and entry.has("digest"):
			accounts[str(name)] = entry


static func _account(secret: String) -> Dictionary:
	var salt := Crypto.new().generate_random_bytes(SALT_BYTES).hex_encode()
	return {"salt": salt, "digest": _derive(secret, salt)}


static func _matches(account: Dictionary, secret: String) -> bool:
	return _derive(secret, str(account.get("salt", ""))) == str(account.get("digest", ""))


## PBKDF2 (HMAC-SHA256, ITERATIONS, one block) of `secret` with `salt`.
static func _derive(secret: String, salt: String) -> String:
	var crypto := Crypto.new()
	var key := secret.to_utf8_buffer()
	var block := salt.hex_decode()
	block.append_array(PackedByteArray([0, 0, 0, 1]))
	var last := crypto.hmac_digest(HashingContext.HASH_SHA256, key, block)
	var result := last.duplicate()
	for i in ITERATIONS - 1:
		last = crypto.hmac_digest(HashingContext.HASH_SHA256, key, last)
		for b in result.size():
			result[b] = result[b] ^ last[b]
	return result.hex_encode()
