extends Node
## Entry point. Phase 0 starts a solo world directly: it creates the
## integrated server, connects the client through a local transport and
## drives the fixed 20 TPS simulation. (Title menu and saves: Phase 8.)

const GAME_CLIENT_SCENE := preload("res://scenes/game_client.tscn")
## Never run more than this many ticks in one frame (avoids a death spiral
## after a long hitch).
const MAX_TICKS_PER_FRAME := 5

var server: GameServer
var client: GameClient
var dev: DevOptions

var _tick_accumulator := 0.0
var _screenshot_taken := false
var _ready_frames := 0
var _dev_actions_started := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	dev = DevOptions.parse(OS.get_cmdline_user_args())
	_apply_dev_preferences()

	var settings := WorldSettings.create(tr("WORLD_DEFAULT_NAME"), dev.seed_text, dev.game_mode)
	var clock := WorldClock.new()
	dev.apply_to_clock(clock)
	server = GameServer.new(settings, clock)
	if dev.has_spawn_override:
		server.spawn_tile = dev.spawn_override

	var transports := LocalTransport.create_pair()
	server.connect_client(transports[1])

	client = GAME_CLIENT_SCENE.instantiate()
	add_child(client)
	client.debug_overlay.server_stats = _server_stats
	client.quit_requested.connect(_quit)
	client.connect_to_server(transports[0], Settings.view_distance)
	# Answer the handshake right away so the first frame has terrain.
	server.process_messages()


func _process(delta: float) -> void:
	server.process_messages()
	if not get_tree().paused:
		_tick_accumulator = minf(
			_tick_accumulator + delta, GameConst.TICK_DELTA * MAX_TICKS_PER_FRAME
		)
		while _tick_accumulator >= GameConst.TICK_DELTA:
			_tick_accumulator -= GameConst.TICK_DELTA
			server.tick()
	if not _dev_actions_started and client.is_ready_to_play():
		_dev_actions_started = true
		_start_dev_actions()
	if not dev.screenshot_path.is_empty():
		_update_screenshot()


func _server_stats() -> PackedStringArray:
	var args := [
		tr("DEBUG_SERVER"),
		server.world.chunks.size(),
		server.tick_count,
		server.player_count(),
		tr("DEBUG_PLAYERS"),
	]
	return PackedStringArray(["%s: %d chunks  |  tick %d  |  %d %s" % args])


func _apply_dev_preferences() -> void:
	# Temporary overrides: not saved to the user's settings file.
	if not dev.language.is_empty():
		Settings.language = dev.language
		Settings.apply_language()
	if dev.zoom > 0:
		Settings.world_zoom = dev.zoom
	if dev.show_debug:
		Settings.show_debug = true


func _start_dev_actions() -> void:
	if dev.autowalk.x != 0:
		Input.action_press(
			InputBindings.MOVE_RIGHT if dev.autowalk.x > 0 else InputBindings.MOVE_LEFT
		)
	if dev.autowalk.y != 0:
		Input.action_press(InputBindings.MOVE_DOWN if dev.autowalk.y > 0 else InputBindings.MOVE_UP)
	if dev.open_pause_menu:
		client.pause()


func _update_screenshot() -> void:
	if _screenshot_taken or not client.is_ready_to_play():
		return
	_ready_frames += 1
	if _ready_frames < dev.screenshot_delay:
		return
	_screenshot_taken = true
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(dev.screenshot_path)
	if error != OK:
		push_error("Screenshot failed: %s" % error_string(error))
	else:
		print("Screenshot saved to ", dev.screenshot_path)
	get_tree().quit()


func _quit() -> void:
	get_tree().quit()
