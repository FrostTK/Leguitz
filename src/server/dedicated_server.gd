class_name DedicatedServer
extends Node
## A dedicated server (multiplayer, step 1): the game run without a window
## (--headless) as a server only, by the option --server or in a build
## exported as a dedicated server (the "dedicated_server" feature). It reads
## its settings (ServerConfig: server.cfg in its data folder, the launch
## options), loads or makes its world (in worlds/), listens for players
## (NetServer, ENet over UDP) and runs the world at 20 ticks a second,
## READY printed once it listens (Pterodactyl waits for it). Its console
## (ServerConsole) reads commands; `stop`, the file STOP_FILE appearing in
## the data folder (a service's stop: systemd) or the engine quitting save
## the world and let the players go. The world also saves every two minutes
## (GameServer.AUTOSAVE_TICKS).

## Printed once the server listens.
const READY := "Leguitz server ready"
## Created in the data folder, it stops the server (then goes).
const STOP_FILE := "stop"
## The loop's pace (frames a second; the world ticks at its own).
const FRAMES := 60
const MAX_TICKS_PER_FRAME := 5
## Connections taken beyond max_players (to tell them the server is full).
const SPARE_CONNECTIONS := 4
const STOP_CHECK_SECONDS := 1.0

var config: ServerConfig
var server: GameServer
var net := NetServer.new()
var console: ServerConsole

var _tick_accumulator := 0.0
var _stop_check := 0.0
var _stopping := false


## Whether the game was launched as a dedicated server.
static func wanted() -> bool:
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	return OS.has_feature("dedicated_server") or "--server" in args


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.max_fps = FRAMES
	config = ServerConfig.read(OS.get_cmdline_args() + OS.get_cmdline_user_args())
	TranslationServer.set_locale(config.language)
	for problem in config.problems:
		push_warning(problem)
	var storage := WorldStorage.new(config.world_dir())
	var saved := storage.read_world()
	var settings := WorldSettings.new()
	var clock := WorldClock.new()
	if saved.is_empty():
		settings = WorldSettings.create(config.world, config.seed_text, config.game_mode)
	else:
		settings.load_dict(saved["settings"])
		clock.load_dict(saved["clock"])
	server = GameServer.new(settings, clock)
	server.dedicated = true
	server.password = config.password
	server.max_players = config.max_players
	server.view_limit = config.view_distance
	server.use_storage(storage, saved)
	console = ServerConsole.new(server)
	var most := config.max_players + SPARE_CONNECTIONS
	var error := net.listen(config.ip, config.port, most)
	if error != OK:
		printerr("Cannot listen on %s:%d (%s)." % [config.ip, config.port, error_string(error)])
		get_tree().quit(1)
		return
	console.start()
	var made := "made" if saved.is_empty() else "loaded"
	print(
		(
			'World "%s" %s (seed %d), saved in %s.'
			% [
				config.world,
				made,
				settings.world_seed,
				ProjectSettings.globalize_path(storage.folder)
			]
		)
	)
	print("%s on %s:%d (%d players at most)." % [READY, config.ip, config.port, config.max_players])


func _process(delta: float) -> void:
	if server == null or _stopping:
		return
	for transport in net.service():
		server.connect_client(transport)
		print("A player connects from %s." % transport.address())
	server.process_messages()
	_tick_accumulator = minf(_tick_accumulator + delta, GameConst.TICK_DELTA * MAX_TICKS_PER_FRAME)
	while _tick_accumulator >= GameConst.TICK_DELTA:
		_tick_accumulator -= GameConst.TICK_DELTA
		server.tick()
	for line in console.take_lines():
		if console.run(line) == ServerConsole.Act.STOP:
			stop()
			return
	_stop_check += delta
	if _stop_check >= STOP_CHECK_SECONDS:
		_stop_check = 0.0
		var asked := config.data_dir.path_join(STOP_FILE)
		if FileAccess.file_exists(asked):
			DirAccess.remove_absolute(asked)
			print("Asked to stop (%s)." % asked)
			stop()
			return
	net.flush()


## Saves the world, lets the players go and quits.
func stop() -> void:
	if _stopping:
		return
	_stopping = true
	print("Stopping: saving the world...")
	server.broadcast(Msg.chat_notice("CHAT_SERVER_STOPPING", [], Chat.Tone.INFO))
	_close()
	print("Stopped.")
	get_tree().quit()


func _exit_tree() -> void:
	_close()


func _close() -> void:
	if server == null:
		return
	server.shutdown()
	server.save()
	net.close()
	if console != null:
		console.finish()
	server = null
