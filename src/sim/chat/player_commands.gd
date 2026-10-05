class_name PlayerCommands
extends RefCounted
## The commands about items, creatures, the player and the admins
## (Commands; static, given the server): give, clear, summon, heal, admin.
## Items
## and creatures are named in English or French or by their own name
## (oak_planks), accents and case aside, or by the start of only one of
## their names. Each returns false when its words do not fit (Commands
## then shows its usage).

## How many at most: stacks of an item given, creatures summoned.
const MOST_STACKS := 10
const MOST_SUMMONED := 10
const LIST_WORDS := ["list", "liste"]
const ADD_WORDS := ["add", "ajoute"]
const REMOVE_WORDS := ["remove", "retire"]

## Plain names -> items, and -> species (Chat.names_of; made when first
## needed).
static var _items := {}
static var _species := {}


## give <item> [count]: into the player's slots (what does not fit falls).
static func give(server: GameServer, session: GameServer.PlayerSession, args: Array) -> bool:
	if args.is_empty():
		return false
	var count := 1
	var named := args
	if args.size() > 1 and String(args[-1]).is_valid_int():
		count = String(args[-1]).to_int()
		named = args.slice(0, -1)
	var typed := " ".join(PackedStringArray(named))
	var item := _find(item_names(), typed, session, "CMD_GIVE_UNKNOWN")
	if item < 0:
		return true
	if not session.alive():
		Chat.tell(session, "CHAT_PASSED_OUT", [], Chat.Tone.ERROR)
		return true
	count = clampi(count, 1, Items.max_stack(item) * MOST_STACKS)
	var fresh := Items.CAN_WATER if item == Items.Id.WATERING_CAN else 0
	var left := session.inventory.add(item, count, fresh)
	if left > 0:
		server.throw_item(session, item, left, fresh)
	session.transport.send(Msg.inventory(session.inventory))
	Chat.tell(session, "CMD_GIVE_DONE", [count, Chat.word(Items.name_key(item))], Chat.Tone.DONE)
	return true


## clear [item]: empties the player's slots (hotbar, bag, what the cursor
## holds, the crafting grid, the armor worn), or takes only that item.
static func clear(_server: GameServer, session: GameServer.PlayerSession, args: Array) -> bool:
	var only := -1
	if not args.is_empty():
		var typed := " ".join(PackedStringArray(args))
		only = _find(item_names(), typed, session, "CMD_GIVE_UNKNOWN")
		if only < 0:
			return true
	var bag := session.inventory
	var removed := 0
	for slot in Inventory.SIZE:
		if bag.items[slot] != Items.Id.NONE and (only < 0 or bag.items[slot] == only):
			removed += bag.counts[slot]
			bag.items[slot] = Items.Id.NONE
			bag.counts[slot] = 0
			bag.wear[slot] = 0
	session.transport.send(Msg.inventory(bag))
	if only < 0:
		Chat.tell(session, "CMD_CLEAR_DONE", [removed], Chat.Tone.DONE)
	else:
		var name := Chat.word(Items.name_key(only))
		Chat.tell(session, "CMD_CLEAR_ONLY", [removed, name], Chat.Tone.DONE)
	return true


## summon <creature> [count]: around the player (bees only come out of
## their hives).
static func summon(server: GameServer, session: GameServer.PlayerSession, args: Array) -> bool:
	if args.is_empty():
		return false
	var count := 1
	var named := args
	if args.size() > 1 and String(args[-1]).is_valid_int():
		count = clampi(String(args[-1]).to_int(), 1, MOST_SUMMONED)
		named = args.slice(0, -1)
	var typed := " ".join(PackedStringArray(named))
	var kind := _find(species_names(), typed, session, "CMD_SUMMON_UNKNOWN")
	if kind < 0:
		return true
	var creatures := server.creatures
	var before := creatures.living.size()
	creatures.spawn_near(kind, session.position, session.height, count)
	var placed := creatures.living.size() - before
	if placed == 0:
		Chat.tell(session, "CMD_SUMMON_NO_ROOM", [], Chat.Tone.ERROR)
		return true
	var name := Chat.word(Species.NAME_KEYS[kind])
	Chat.tell(session, "CMD_SUMMON_DONE", [placed, name], Chat.Tone.DONE)
	return true


## heal: vitality, satiety and air full.
static func heal(_server: GameServer, session: GameServer.PlayerSession) -> bool:
	if not session.alive():
		Chat.tell(session, "CHAT_PASSED_OUT", [], Chat.Tone.ERROR)
		return true
	GameModes.restore(session)
	Chat.tell(session, "CMD_HEAL_DONE", [], Chat.Tone.DONE)
	return true


## admin list | add <player> | remove <player> (a world keeps one at
## least).
static func admin(server: GameServer, session: GameServer.PlayerSession, args: Array) -> bool:
	var admins := server.settings.admins
	if args.size() == 1 and Commands.is_word(args[0], LIST_WORDS):
		Chat.tell(session, "CMD_ADMIN_LIST", [", ".join(PackedStringArray(admins))])
		return true
	if args.size() != 2:
		return false
	var name: String = args[1]
	var other := Chat.find_player(server, name)
	if other != null:
		name = other.player_name
	var index := -1
	for i in admins.size():
		if admins[i].to_lower() == name.to_lower():
			index = i
	if Commands.is_word(args[0], ADD_WORDS):
		if index >= 0:
			Chat.tell(session, "CMD_ADMIN_ALREADY", [admins[index]], Chat.Tone.ERROR)
			return true
		admins.append(name)
		Chat.tell(session, "CMD_ADMIN_ADDED", [name], Chat.Tone.DONE)
		if other != null and other != session:
			Chat.tell(other, "CMD_ADMIN_YOU", [session.player_name], Chat.Tone.DONE)
		return true
	if Commands.is_word(args[0], REMOVE_WORDS):
		if index < 0:
			Chat.tell(session, "CMD_ADMIN_NOT", [name], Chat.Tone.ERROR)
		elif admins.size() == 1:
			Chat.tell(session, "CMD_ADMIN_LAST", [], Chat.Tone.ERROR)
		else:
			Chat.tell(session, "CMD_ADMIN_REMOVED", [admins[index]], Chat.Tone.DONE)
			admins.remove_at(index)
		return true
	return false


## Plain names of the items one can be given (not the player's book).
static func item_names() -> Dictionary:
	if _items.is_empty():
		var keys := {}
		var own := {}
		for item: int in Items.Id.values():
			if Items.is_valid(item) and item != Items.Id.GUIDE_BOOK:
				keys[item] = Items.name_key(item)
				own[item] = Items.Id.find_key(item)
		_items = Chat.names_of(keys, own)
	return _items


## Plain names of the creatures one can summon (not bees).
static func species_names() -> Dictionary:
	if _species.is_empty():
		var keys := {}
		var own := {}
		for kind: int in Species.NAME_KEYS:
			if kind != Species.Id.BEE:
				keys[kind] = Species.NAME_KEYS[kind]
				own[kind] = Species.Id.find_key(kind)
		_species = Chat.names_of(keys, own)
	return _species


## What `typed` names (Chat.lookup), else tells the player `unknown` or
## the names it could be (-1).
static func _find(
	names: Dictionary, typed: String, session: GameServer.PlayerSession, unknown: String
) -> int:
	var close: Array = []
	var found := Chat.lookup(names, typed, close)
	if found >= 0:
		return found
	if close.is_empty():
		Chat.tell(session, unknown, [typed], Chat.Tone.ERROR)
	else:
		Chat.tell(session, "CHAT_WHICH", [", ".join(PackedStringArray(close))], Chat.Tone.ERROR)
	return -1
