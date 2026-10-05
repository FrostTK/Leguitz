class_name Chat
extends RefCounted
## The chat, on the server (static, given the server): what a player types
## (Msg.CHAT) goes to every player with their name (Msg.chat_said), or, when
## it starts with "/", is a command the server runs (Commands) and answers
## the player in the chat (`tell`: a translation key and its words, each
## player reading it in their own language). The world keeps its admins
## (WorldSettings.admins, saved with it): the first player to join a world
## without any, its creator in solo, becomes one; some commands are theirs
## only (Commands.LIST).

## How the chat shows a notice (Msg.chat_notice).
enum Tone { INFO, DONE, ERROR, WHISPER }

## What a player says at most (characters; the rest is cut).
const MAX_LENGTH := 200
## Accented letters typed in names and commands and the plain letters
## they read as (`plain`), one for one, and those read as two.
const ACCENTED := "àâäáãåçéèêëîïíìôöóòõùûüúÿñ"
const UNACCENTED := "aaaaaaceeeeiiiiooooouuuuyn"
const LIGATURES := {"œ": "oe", "æ": "ae"}


## A player typed a line in the chat.
static func receive(
	server: GameServer, session: GameServer.PlayerSession, message: Dictionary
) -> void:
	if not session.joined:
		return
	var text := str(message.get("text", "")).strip_edges().left(MAX_LENGTH)
	if text.is_empty():
		return
	if text.begins_with("/"):
		Commands.run(server, session, text.substr(1))
		return
	server.broadcast(Msg.chat_said(session.player_name, text))


## Tells a player something in the chat: `key` (a translation) with `args`
## (numbers, names, or `word`s translated by the reader).
static func tell(
	session: GameServer.PlayerSession, key: String, args: Array = [], tone := Tone.INFO
) -> void:
	session.transport.send(Msg.chat_notice(key, args, tone))


## A word the reader translates (a key), among a notice's args.
static func word(key: String) -> Dictionary:
	return {"key": key}


## A player joins: in a world without admins, they become its first.
static func on_join(server: GameServer, session: GameServer.PlayerSession) -> void:
	if server.settings.admins.is_empty():
		server.settings.admins.append(session.player_name)


static func is_admin(server: GameServer, session: GameServer.PlayerSession) -> bool:
	return session.player_name in server.settings.admins


## The player called `name` (ignoring case), null if none is here.
static func find_player(server: GameServer, name: String) -> GameServer.PlayerSession:
	for other in server.sessions:
		if other.joined and other.player_name.to_lower() == name.to_lower():
			return other
	return null


## A text as names and commands are matched: lower case, no accents,
## spaces for underscores, single spaces.
static func plain(text: String) -> String:
	var result := ""
	for letter in text.to_lower().replace("_", " "):
		var at := ACCENTED.find(letter)
		result += UNACCENTED[at] if at >= 0 else LIGATURES.get(letter, letter)
	return " ".join(result.split(" ", false))


## Every name of something in both languages and its own (an enum's key):
## `keys` maps each thing to its name key; returns plain name -> thing.
static func names_of(keys: Dictionary, own: Dictionary) -> Dictionary:
	var names := {}
	var languages: Array[Translation] = []
	for locale in ["en", "fr"]:
		var translation := TranslationServer.get_translation_object(locale)
		if translation != null:
			languages.append(translation)
	for thing: int in keys:
		names[plain(own[thing])] = thing
		for translation in languages:
			var name := String(translation.get_message(keys[thing]))
			if not name.is_empty():
				names[plain(name)] = thing
	return names


## What `typed` names among `names` (plain name -> thing): the thing whose
## name it is, else the only thing whose name begins with it; -1 for none,
## and `close` gets the names it could be.
static func lookup(names: Dictionary, typed: String, close: Array = []) -> int:
	var wanted := plain(typed)
	if wanted.is_empty():
		return -1
	if names.has(wanted):
		return names[wanted]
	var found := {}
	for name: String in names:
		if name.begins_with(wanted):
			found[names[name]] = name
	if found.size() == 1:
		return found.keys()[0]
	close.append_array(found.values().slice(0, 5))
	return -1
