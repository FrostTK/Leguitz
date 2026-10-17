class_name ServerConsole
extends RefCounted
## A dedicated server's console (DedicatedServer): lines typed on its
## standard input (read on a thread of their own, `start`; what Pterodactyl
## and a terminal send) and the files dropped in its `folder` (one command
## a line; `poll_folder` reads and removes them in their names' order: the
## helper leguitz-console writes them, where a service or a container has no
## terminal; step 5) are run (`run`): stop (or quit: the world saved,
## the server stops), save, say TEXT (to every player), list (who plays),
## help, backups (the world's, newest first: Backups), restore BACKUP (its
## name or number: the server stops, the backup in place of the world; Act
## RESTORE, `restoring`), and the chat's commands an admin may give from
## here (COMMANDS, with or without "/"; their answers printed). The console
## hears what is told to everyone (GameServer.console: chat lines, arrivals
## and departures, what the guard caught) and prints it.

enum Act { NONE, STOP, RESTORE }

## The chat's commands the console runs (the others need a player in the
## world).
const COMMANDS: Array[String] = [
	"help",
	"players",
	"msg",
	"seed",
	"time",
	"season",
	"weather",
	"gamemode",
	"admin",
	"kick",
	"ban",
	"unban",
	"whitelist",
	"role",
	"account",
	"backup",
]
## The console's name, as players read it.
const NAME := "Server"
## How often the folder is looked into (seconds); files still being written
## end so and are left for later.
const FOLDER_SECONDS := 1.0
const WRITING := ".tmp"


## What the console prints (chat lines told to everyone, a command's
## answers) through `out`.
class Output:
	extends Transport
	var out: Callable

	func send(message: Dictionary) -> void:
		if message.get("t") != Msg.CHAT_LINE:
			return
		if message.has("from"):
			out.call("<%s> %s" % [message["from"], message["text"]])
		else:
			out.call(Chat.notice_text(message))

	func poll() -> Array[Dictionary]:
		return []


var server: GameServer
## The world's backups (null: none), and the one to restore (Act.RESTORE).
var backups: Backups
var restoring := ""
## Prints a line (print; tests keep them).
var out := func(line: String) -> void: print(line)
## The folder commands are dropped in ("": none).
var folder := ""
## The console as a player giving commands (an admin, never in the world).
var session := GameServer.PlayerSession.new()

var _output := Output.new()
var _thread := Thread.new()
var _mutex := Mutex.new()
var _lines: PackedStringArray = []
var _folder_wait := 0.0


func _init(game_server: GameServer) -> void:
	server = game_server
	_output.out = _print
	session.console = true
	session.joined = true
	session.player_name = NAME
	session.transport = _output
	server.console = _output


## Reads the standard input on a thread of its own (when there is one).
func start() -> void:
	var kind := OS.get_stdin_type()
	if kind == OS.STD_HANDLE_CONSOLE or kind == OS.STD_HANDLE_PIPE:
		_thread.start(_read)


## The server stops: the reading thread is waited for if the input ended
## (a terminal's still waits for a line: it goes with the process).
func finish() -> void:
	if _thread.is_started() and not _thread.is_alive():
		_thread.wait_to_finish()


## Every FOLDER_SECONDS: the commands dropped in `folder` since (each
## file's lines), the files removed.
func poll_folder(delta: float) -> void:
	_folder_wait -= delta
	if folder == "" or _folder_wait > 0.0:
		return
	_folder_wait = FOLDER_SECONDS
	var files := DirAccess.get_files_at(folder)
	files.sort()
	for file in files:
		if file.ends_with(WRITING) or file.begins_with("."):
			continue
		var path := folder.path_join(file)
		var text := FileAccess.get_file_as_string(path)
		DirAccess.remove_absolute(path)
		for line in text.split("\n", false):
			_keep(line)


## The lines typed since the last call.
func take_lines() -> PackedStringArray:
	_mutex.lock()
	var lines := _lines
	_lines = PackedStringArray()
	_mutex.unlock()
	return lines


## Runs a line typed in the console; STOP: the server is to stop.
func run(line: String) -> Act:
	var text := line.strip_edges().trim_prefix("/")
	var words := text.split(" ", false)
	if words.is_empty():
		return Act.NONE
	var word := words[0].to_lower()
	match word:
		"stop", "quit":
			return Act.STOP
		"save":
			out.call("World saved." if server.save() else "The world could not be saved.")
		"say":
			var said := text.substr(word.length()).strip_edges()
			if not said.is_empty():
				server.broadcast(Msg.chat_said(NAME, said))
		"list":
			_list()
		"help":
			var own := "stop, save, say TEXT, list, backups, restore BACKUP, help"
			out.call("Console: %s. Commands: %s" % [own, ", ".join(COMMANDS)])
		"backups":
			_list_backups()
		"restore":
			var which := text.substr(word.length()).strip_edges()
			restoring = backups.find(which) if backups != null and which != "" else ""
			if restoring != "":
				return Act.RESTORE
			out.call("Which backup? (backups lists them: restore 1 is the newest.)")
		_:
			var command := Commands.find(word)
			if command.is_empty() or not command["name"] in COMMANDS:
				out.call("Unknown here: %s (help lists what the console runs)." % word)
			else:
				Commands.run(server, session, text)
	return Act.NONE


func _print(line: String) -> void:
	out.call(line)


func _list_backups() -> void:
	var files := backups.list() if backups != null else PackedStringArray()
	if files.is_empty():
		out.call("No backup yet.")
	for i in files.size():
		out.call("%d. %s" % [i + 1, files[i]])


func _list() -> void:
	var names := PackedStringArray()
	for other in server.sessions:
		if other.joined:
			names.append(other.player_name)
	var most := "/%d" % server.max_players if server.max_players > 0 else ""
	out.call("%d%s players: %s" % [names.size(), most, ", ".join(names)])


## The reading thread: line after line, until the input ends.
func _read() -> void:
	var pending := PackedByteArray()
	while true:
		if OS.get_stdin_type() == OS.STD_HANDLE_CONSOLE:
			var typed := OS.read_string_from_stdin(4096)
			if typed.is_empty():
				OS.delay_msec(100)
				continue
			for each in typed.split("\n", false):
				_keep(each)
			continue
		var byte := OS.read_buffer_from_stdin(1)
		if byte.is_empty():
			return
		if byte[0] == 10:
			_keep(pending.get_string_from_utf8())
			pending.clear()
		elif byte[0] != 13:
			pending.append(byte[0])


func _keep(line: String) -> void:
	if line.strip_edges().is_empty():
		return
	_mutex.lock()
	_lines.append(line)
	_mutex.unlock()
