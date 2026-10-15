class_name ServerConfig
extends RefCounted
## A dedicated server's settings (DedicatedServer): FILE in its data folder
## (written with its defaults and their explanations on the first start),
## then the options given at launch over it (each as --name=value, after
## "--" or not): --data=FOLDER (where FILE and the worlds are; the current
## folder by default), --ip=ADDRESS, --port=N, --world=NAME, --seed=TEXT,
## --game-mode=MODE, --max-players=N, --password=TEXT, --view-distance=N,
## --language=CODE. The game mode and the seed only make a new world.

const FILE := "server.cfg"
const SECTION := "server"
const DEFAULT_PORT := 27420
## FILE as first written.
const TEMPLATE := """; Leguitz dedicated server. Restart the server after changing this file.
; Options given at launch (--port=27420 ...) take over these.
[server]
; The address to listen on ("*": every address of the machine) and the UDP port.
ip="*"
port=27420
; The world's folder (in worlds/). Its seed and game mode are only used to
; make it, the first time.
world="world"
seed=""
; survival, creative or hardcore.
game_mode="survival"
; How many players at once.
max_players=10
; What players must type to join ("": nobody is asked).
password=""
; How far a player's view may reach (chunks, 2 to 16).
view_distance=12
; The console's language: en or fr.
language="en"
"""
## The game modes by their names in FILE and in the options.
const MODES := {
	"survival": WorldSettings.GameMode.SURVIVAL,
	"creative": WorldSettings.GameMode.CREATIVE,
	"hardcore": WorldSettings.GameMode.HARDCORE,
}

var data_dir := "."
var ip := "*"
var port := DEFAULT_PORT
var world := "world"
var seed_text := ""
var game_mode := WorldSettings.GameMode.SURVIVAL
var max_players := 10
var password := ""
var view_distance := 12
var language := "en"
## What was wrong in FILE or the options (told in the console).
var problems: PackedStringArray = []


## The settings of a server launched with `args` (OS.get_cmdline_args and
## OS.get_cmdline_user_args): FILE read from its data folder (written there
## first if missing), the options over it.
static func read(args: PackedStringArray) -> ServerConfig:
	var options := _options(args)
	var config := ServerConfig.new()
	config.data_dir = options.get("data", ".")
	var path := config.data_dir.path_join(FILE)
	if not FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_string(TEMPLATE)
			file.close()
	var saved := ConfigFile.new()
	if FileAccess.file_exists(path) and saved.load(path) != OK:
		config.problems.append("%s could not be read: its settings are left aside" % path)
		saved = ConfigFile.new()
	config.take(saved, options)
	return config


## Takes the settings of `saved` (FILE's), then `options` (name -> value).
func take(saved: ConfigFile, options: Dictionary) -> void:
	var values := {}
	if saved.has_section(SECTION):
		for key in saved.get_section_keys(SECTION):
			values[key] = str(saved.get_value(SECTION, key))
	for key: String in options:
		values[key.replace("-", "_")] = options[key]
	ip = str(values.get("ip", ip))
	world = str(values.get("world", world)).validate_filename()
	seed_text = str(values.get("seed", seed_text))
	password = str(values.get("password", password))
	language = str(values.get("language", language))
	port = _number(values, "port", port, 1, 65535)
	max_players = _number(values, "max_players", max_players, 1, 1000)
	var view := _number(values, "view_distance", view_distance, 2, GameConst.MAX_VIEW_DISTANCE)
	view_distance = clampi(view, GameConst.MIN_VIEW_DISTANCE, GameConst.MAX_VIEW_DISTANCE)
	var mode := str(values.get("game_mode", "")).to_lower()
	if MODES.has(mode):
		game_mode = MODES[mode]
	elif not mode.is_empty():
		problems.append("game_mode: %s is none of %s" % [mode, ", ".join(MODES.keys())])


## The folder the world is saved in.
func world_dir() -> String:
	return data_dir.path_join("worlds").path_join(world)


## The options given (name -> value; "--name" alone: "true").
static func _options(args: PackedStringArray) -> Dictionary:
	var options := {}
	for arg in args:
		if not arg.begins_with("--"):
			continue
		var pair := arg.substr(2).split("=", true, 1)
		options[pair[0]] = pair[1] if pair.size() > 1 else "true"
	return options


func _number(values: Dictionary, key: String, fallback: int, low: int, high: int) -> int:
	if not values.has(key):
		return fallback
	var text := str(values[key])
	if not text.is_valid_int() or int(text) < low or int(text) > high:
		problems.append("%s: %s is not a number from %d to %d" % [key, text, low, high])
		return fallback
	return int(text)
