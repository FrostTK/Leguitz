class_name ChatCompletion
extends RefCounted
## What Tab completes in the chat (ChatBox): a command's name (as the
## player's language writes it, else in English), then its first word (the
## words its usage shows in the player's language: /heure jour, midi...),
## a command for help, an item for give and clear, a creature for summon
## (their names in the player's language, else in English: the rest of the
## line). Matched plainly (Chat.plain): case and accents aside.

## Commands whose argument is an item's or a creature's name (words).
const ITEM_COMMANDS := ["give", "clear"]
const CREATURE_COMMANDS := ["summon"]


## What can complete `line` (typed, from "/"): {"start": where the part
## to complete starts, "options": what that part can become}.
static func options(line: String) -> Dictionary:
	var none := {"start": line.length(), "options": PackedStringArray()}
	if not line.begins_with("/"):
		return none
	var space := line.find(" ")
	if space < 0:
		return {"start": 1, "options": _command_names(line.substr(1))}
	var command := Commands.find(line.substr(1, space - 1))
	if command.is_empty():
		return none
	var rest := line.substr(space + 1)
	var name: String = command["name"]
	var start := space + 1 + (rest.length() - rest.strip_edges(true, false).length())
	var typed := line.substr(start)
	var names := PackedStringArray()
	if name in ITEM_COMMANDS or name in CREATURE_COMMANDS:
		var keys := _item_keys() if name in ITEM_COMMANDS else _creature_keys()
		var found := starting(_names(keys, ""), typed)
		if found.is_empty():
			found = starting(_names(keys, "en"), typed)
		return {"start": start, "options": found}
	if " " in rest.strip_edges():
		return none
	if name == "help":
		for other in Commands.LIST:
			names.append(local_name(other))
	else:
		names = usage_words(command)
	return {"start": start, "options": starting(names, typed)}


## A command's name as the player's language writes it (from its usage).
static func local_name(command: Dictionary) -> String:
	var usage := String(TranslationServer.translate(Commands.usage_key(command)))
	return usage.get_slice(" ", 0).trim_prefix("/")


## The words a command's usage shows for its first word, in the player's
## language (not the <things to name>, [optional], numbers nor ~).
static func usage_words(command: Dictionary) -> PackedStringArray:
	var usage := String(TranslationServer.translate(Commands.usage_key(command)))
	var words := PackedStringArray()
	var tokens := usage.split(" ", false)
	for i in range(1, tokens.size()):
		var token := tokens[i]
		if token == "|" or token[0] in ["<", "[", "~"] or _has_digit(token):
			continue
		if not token in words:
			words.append(token)
	return words


## The names beginning (plainly) with `typed`, each once.
static func starting(names: PackedStringArray, typed: String) -> PackedStringArray:
	var wanted := Chat.plain(typed)
	var found := PackedStringArray()
	var seen := {}
	for name in names:
		var plain := Chat.plain(name)
		if plain.begins_with(wanted) and not seen.has(plain):
			seen[plain] = true
			found.append(name)
	return found


## How far the options begin alike (plainly), as the first one writes it.
static func common_start(options: PackedStringArray) -> String:
	var first := options[0]
	var length := first.length()
	for option in options:
		var same := 0
		while (
			same < mini(length, option.length())
			and Chat.plain(first[same]) == Chat.plain(option[same])
		):
			same += 1
		length = same
	return first.left(length)


## Command names in the player's language, else in English (and their
## French aliases), beginning with `typed`.
static func _command_names(typed: String) -> PackedStringArray:
	var names := PackedStringArray()
	for command in Commands.LIST:
		names.append(local_name(command))
	var found := starting(names, typed)
	if not found.is_empty():
		return found
	names.clear()
	for command in Commands.LIST:
		names.append(command["name"])
		names.append(command["alias"])
	return starting(names, typed)


## The name keys of the items one can be given (not the player's book).
static func _item_keys() -> PackedStringArray:
	var keys := PackedStringArray()
	for item: int in Items.Id.values():
		if Items.is_valid(item) and item != Items.Id.GUIDE_BOOK:
			keys.append(Items.name_key(item))
	return keys


## The name keys of the creatures one can summon (not bees).
static func _creature_keys() -> PackedStringArray:
	var keys := PackedStringArray()
	for kind: int in Species.NAME_KEYS:
		if kind != Species.Id.BEE:
			keys.append(Species.NAME_KEYS[kind])
	return keys


## Names of `keys` in `locale` ("": the player's), sorted.
static func _names(keys: PackedStringArray, locale: String) -> PackedStringArray:
	var translation: Translation = null
	if not locale.is_empty():
		translation = TranslationServer.get_translation_object(locale)
	var names := PackedStringArray()
	for key in keys:
		var name := String(TranslationServer.translate(key))
		if translation != null:
			name = String(translation.get_message(key))
		names.append(name)
	names.sort()
	return names


static func _has_digit(token: String) -> bool:
	for letter in token:
		if letter >= "0" and letter <= "9":
			return true
	return false
