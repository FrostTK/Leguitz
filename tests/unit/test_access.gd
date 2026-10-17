extends TestCase
## Multiplayer, step 4: accounts (a name is its first player's, only their
## password plays under it, never kept as typed), changing and forgetting a
## password, bans (for a while, for ever, by address), the whitelist,
## roles (visitors change nothing, moderators kick, admins do all), all of
## it saved; backups made, listed, kept to so many, restored; the server's
## settings for them.

const FOLDER := "user://test_worlds/access"
const BACKUPS := "user://test_worlds/access_backups"


## A dedicated server with accounts, nobody on it.
func _server() -> GameServer:
	var settings := WorldSettings.create("Test", "42", WorldSettings.GameMode.SURVIVAL)
	var server := GameServer.new(settings, null, false)
	server.dedicated = true
	server.access.accounts_on = true
	server.creatures.living.clear()
	return server


## A player says hello: [their end, what came back].
func _hello(server: GameServer, name: String, password := "") -> Array:
	var transports := LocalTransport.create_pair()
	server.connect_client(transports[1])
	transports[0].send(Msg.hello(name, 2, "", Access.secret_of(name, password)))
	server.process_messages()
	return [transports[0], transports[0].poll()]


func _of(messages: Array, kind: String) -> Array:
	return messages.filter(func(m: Dictionary) -> bool: return m["t"] == kind)


func _refusal(messages: Array) -> String:
	var refused := _of(messages, Msg.REFUSED)
	return refused[0]["reason"] if not refused.is_empty() else ""


## What a player types; the chat lines it brings (only those).
func _type(server: GameServer, client: LocalTransport, text: String) -> Array:
	client.poll()
	client.send(Msg.chat(text))
	server.process_messages()
	return client.poll().filter(func(m: Dictionary) -> bool: return m["t"] == Msg.CHAT_LINE)


func test_a_name_is_its_first_players() -> void:
	var server := _server()
	assert_eq(_refusal(_hello(server, "Alex")[1]), "REFUSED_ACCOUNT_NEEDED", "a password first")
	var alex: LocalTransport = _hello(server, "Alex", "pomme")[0]
	assert_true(Chat.find_player(server, "Alex") != null, "in")
	var account: Dictionary = server.access.accounts["alex"]
	var secret := Access.secret_of("Alex", "pomme")
	assert_ne(secret, "pomme", "the password never leaves as typed")
	assert_false(account["digest"] in [secret, "pomme"], "nor is it kept")
	alex.close()
	server.process_messages()
	assert_eq(_refusal(_hello(server, "Alex", "poire")[1]), "REFUSED_ACCOUNT_WRONG")
	assert_eq(_refusal(_hello(server, "alex")[1]), "REFUSED_ACCOUNT_PASSWORD", "any case")
	var back := _hello(server, "Alex", "pomme")
	assert_eq(_of(back[1], Msg.WELCOME).size(), 1, "the right one")
	# The same password for another name: another salt, another digest.
	_hello(server, "Bea", "pomme")
	assert_ne(server.access.accounts["bea"]["digest"], server.access.accounts["alex"]["digest"])
	# Five wrong ones lock the name a while.
	for i in Access.MOST_TRIES:
		_hello(server, "Bea", "nope")
	var locked: Dictionary = _of(_hello(server, "Bea", "pomme")[1], Msg.REFUSED)[0]
	assert_eq(locked["reason"], "REFUSED_ACCOUNT_LOCKED", "even the right one, for now")
	assert_eq(locked["args"][0], {"minutes": 10})
	# Proving it, a player takes over their old connection from anywhere.
	var again := _hello(server, "Alex", "pomme")
	assert_eq(_of(again[1], Msg.WELCOME).size(), 1)
	assert_false(back[0].is_open(), "the old one ends")


func test_changing_and_forgetting_a_password() -> void:
	var server := _server()
	var alex: LocalTransport = _hello(server, "Alex", "pomme")[0]
	var bea: LocalTransport = _hello(server, "Bea", "kiwi")[0]
	var old := Access.secret_of("Alex", "pomme")
	var new := Access.secret_of("Alex", "cerise")
	alex.send(Msg.set_password(Access.secret_of("Alex", "nope"), new))
	server.process_messages()
	assert_false(_of(alex.poll(), Msg.PASSWORD_SET)[0]["done"], "the old one is wrong")
	alex.send(Msg.set_password(old, new))
	server.process_messages()
	assert_true(_of(alex.poll(), Msg.PASSWORD_SET)[0]["done"])
	alex.close()
	server.process_messages()
	assert_eq(_refusal(_hello(server, "Alex", "pomme")[1]), "REFUSED_ACCOUNT_WRONG")
	var back: LocalTransport = _hello(server, "Alex", "cerise")[0]
	# The admin (Alex, first here) forgets Bea's: the next Bea chooses.
	_type(server, back, "/compte oublie Bea")
	bea.close()
	server.process_messages()
	assert_eq(_of(_hello(server, "Bea", "melon")[1], Msg.WELCOME).size(), 1, "a new password")


func test_bans() -> void:
	var server := _server()
	server.access.accounts_on = false
	var alex: LocalTransport = _hello(server, "Alex")[0]
	var bea: LocalTransport = _hello(server, "Bea")[0]
	bea.poll()
	_type(server, alex, "/bannis Bea 2h triche")
	var kicked := _of(bea.poll(), Msg.KICKED)
	assert_eq(kicked.size(), 1, "sent away")
	assert_eq(server.access.bans["bea"]["ip"], "", "not the address unless asked")
	assert_eq(kicked[0]["reason"], "KICKED_BANNED")
	server.process_messages()
	assert_eq(Chat.find_player(server, "Bea"), null)
	var refused := _of(_hello(server, "Bea")[1], Msg.REFUSED)
	assert_eq(refused[0]["reason"], "REFUSED_BANNED_FOR")
	assert_eq(refused[0]["args"][0], {"minutes": 120}, "two hours left")
	assert_eq(refused[0]["args"][1], "triche")
	var text := Chat.notice_text({"key": refused[0]["reason"], "args": refused[0]["args"]})
	assert_true(Access.duration_text(120) in text, "told in words")
	_type(server, alex, "/gracie Bea")
	assert_eq(_refusal(_hello(server, "Bea")[1]), "", "back")
	# For ever; by address; over.
	var access := server.access
	access.ban("Chloe", 0, "", "Alex", "10.0.0.7")
	var now := Time.get_unix_time_from_system()
	assert_eq(access.refusal("Chloe", "", "", now)[0], "REFUSED_BANNED")
	assert_eq(access.refusal("Other", "", "10.0.0.7", now)[0], "REFUSED_BANNED", "the address")
	access.bans["chloe"]["until"] = now - 1.0
	assert_eq(access.refusal("Chloe", "", "", now), [], "over")
	assert_false(access.bans.has("chloe"), "and gone")


func test_the_whitelist() -> void:
	var server := _server()
	server.access.accounts_on = false
	var alex: LocalTransport = _hello(server, "Alex")[0]
	_type(server, alex, "/listeblanche oui")
	assert_true("alex" in server.access.whitelist, "those playing stay on it")
	assert_eq(_refusal(_hello(server, "Bea")[1]), "REFUSED_NOT_LISTED")
	_type(server, alex, "/listeblanche ajoute Bea")
	assert_eq(_refusal(_hello(server, "Bea")[1]), "")


func test_roles() -> void:
	var server := _server()
	server.access.accounts_on = false
	var alex: LocalTransport = _hello(server, "Alex")[0]
	var bea: LocalTransport = _hello(server, "Bea")[0]
	var chloe: LocalTransport = _hello(server, "Chloe")[0]
	var access := server.access
	assert_eq(access.role_of(server, "Alex"), Access.Role.ADMIN, "the first one here")
	assert_eq(access.role_of(server, "Bea"), Access.Role.PLAYER)
	# A player may not kick; a moderator may, not an admin.
	assert_eq(_type(server, bea, "/expulse Chloe")[0]["key"], "CHAT_NOT_ALLOWED")
	_type(server, alex, "/role Bea moderateur")
	assert_eq(access.role_of(server, "Bea"), Access.Role.MODERATOR)
	assert_eq(_type(server, bea, "/expulse Alex")[0]["key"], "CMD_KICK_HIGHER")
	_type(server, bea, "/expulse Chloe")
	assert_eq(_of(chloe.poll(), Msg.KICKED)[0]["args"][0], "Bea", "kicked by Bea")
	# A visitor changes nothing.
	_type(server, alex, "/role Bea visiteur")
	var session := Chat.find_player(server, "Bea")
	var tile := Coords.world_to_tile(session.position)
	var cell := Vector3i(tile.x, floori(session.height) + GameConst.SEA_LEVEL - 1, tile.y)
	var ground := server.world.voxel_at(cell)
	bea.poll()
	bea.send(Msg.block_break(cell, 0))
	server.process_messages()
	var got := bea.poll()
	assert_eq(server.world.voxel_at(cell), ground, "the block stays")
	assert_eq(_of(got, Msg.BLOCK_CHANGED)[0]["voxel"], ground, "told how it is")
	assert_eq(_of(got, Msg.NOTICE)[0]["key"], "HUD_VISITOR")
	var roster: Array = Peers.roster(server)
	assert_eq(roster[1]["role"], Access.Role.VISITOR, "the roster tells it")
	# The last admin stays one.
	assert_eq(_type(server, alex, "/role Alex joueur")[0]["key"], "CMD_ADMIN_LAST")
	# Newcomers may come as visitors.
	access.default_role = Access.Role.VISITOR
	assert_eq(access.role_of(server, "Newcomer"), Access.Role.VISITOR)


func test_saved() -> void:
	var storage := WorldStorage.new(FOLDER)
	storage.erase()
	var access := Access.new()
	access.accounts_on = true
	access.joined("Alex", Access.secret_of("Alex", "pomme"), "10.0.0.2")
	access.roles["bea"] = Access.Role.MODERATOR
	access.whitelist_on = true
	access.whitelist.append("bea")
	access.ban("Chloe", 60, "spam", "Alex", "")
	storage.save_access(access.to_dict())
	storage.save_accounts(access.accounts_dict())
	var again := Access.new()
	again.accounts_on = true
	again.load_dict(storage.read_access())
	again.load_accounts(storage.read_accounts())
	assert_true(again.proves("alex", Access.secret_of("Alex", "pomme")), "the account")
	assert_eq(again.accounts["alex"]["ip"], "10.0.0.2")
	assert_eq(again.roles["bea"], Access.Role.MODERATOR)
	assert_true(again.whitelist_on and "bea" in again.whitelist)
	assert_eq(again.bans["chloe"]["reason"], "spam")
	storage.erase()


func test_backups() -> void:
	var world := FOLDER.path_join("worlds/world")
	_wipe(FOLDER)
	_wipe(BACKUPS)
	DirAccess.make_dir_recursive_absolute(world.path_join("players"))
	_write(world.path_join("world.cfg"), "first")
	_write(world.path_join("players/Alex.cfg"), "Alex")
	var backups := Backups.new(BACKUPS.get_base_dir(), world, "world")
	backups.folder = BACKUPS
	backups.kept = 2
	backups.out = func(_line: String) -> void: pass
	assert_eq(backups.make_now("one"), OK)
	assert_eq(backups.list().size(), 1)
	_write(world.path_join("world.cfg"), "changed")
	DirAccess.remove_absolute(world.path_join("players/Alex.cfg"))
	var first := backups.find("1")
	assert_true(first.ends_with("_one.zip"), "the newest")
	assert_eq(backups.restore(first), "", "restored")
	assert_eq(FileAccess.get_file_as_string(world.path_join("world.cfg")), "first")
	assert_eq(FileAccess.get_file_as_string(world.path_join("players/Alex.cfg")), "Alex")
	assert_eq(backups.list().size(), 2, "the world as it was kept first")
	backups.make_now("three")
	assert_eq(backups.list().size(), 2, "only the newest kept")
	_wipe(FOLDER)
	_wipe(BACKUPS)


func test_settings_and_durations() -> void:
	var saved := ConfigFile.new()
	saved.parse(
		'[server]\naccounts=false\ndefault_role="visitor"\nbackup_hours=0\nbackups_kept="x"\n'
	)
	var config := ServerConfig.new()
	config.take(saved, {"backup-on-start": "no"})
	assert_false(config.accounts)
	assert_eq(config.default_role, Access.Role.VISITOR)
	assert_eq(config.backup_hours, 0)
	assert_false(config.backup_on_start)
	assert_eq(config.backups_kept, 10, "a wrong number")
	assert_eq(config.problems.size(), 1, "told")
	var template := ConfigFile.new()
	assert_eq(template.parse(ServerConfig.TEMPLATE), OK)
	var fresh := ServerConfig.new()
	fresh.take(template, {})
	assert_true(fresh.accounts and fresh.problems.is_empty())
	assert_eq(Access.minutes_in("30m"), 30)
	assert_eq(Access.minutes_in("2h"), 120)
	assert_eq(Access.minutes_in("3j"), 3 * 24 * 60)
	assert_eq(Access.minutes_in("1w"), 7 * 24 * 60)
	assert_eq(Access.minutes_in("soon"), -1)


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _wipe(dir: String) -> void:
	if DirAccess.dir_exists_absolute(dir):
		Backups._empty(dir)
		DirAccess.remove_absolute(dir)
