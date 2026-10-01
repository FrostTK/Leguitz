extends Node
## Entry point. Until the title screen, it plays one solo world directly:
## the saved one (created and saved on first launch), or a throwaway world
## for a dev seed (see DevOptions.saves_world). It creates the integrated
## server, connects the client through a local transport, drives the fixed
## 20 TPS simulation and saves the world when the game closes.

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
var _seen_chunks := 0
var _dev_actions_started := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	dev = DevOptions.parse(OS.get_cmdline_user_args())
	_apply_dev_preferences()

	var storage: WorldStorage = null
	var saved := {}
	if dev.saves_world():
		storage = WorldStorage.of_world(dev.world_folder)
		if dev.new_world:
			storage.erase()
		saved = storage.read_world()
	var settings := WorldSettings.new()
	var clock := WorldClock.new()
	if saved.is_empty():
		settings = WorldSettings.create(tr("WORLD_DEFAULT_NAME"), dev.seed_text, dev.game_mode)
	else:
		settings.load_dict(saved["settings"])
		clock.load_dict(saved["clock"])
	dev.apply_to_clock(clock)
	server = GameServer.new(settings, clock)
	if dev.has_spawn_override:
		server.spawn_tile = dev.spawn_override
		server.spawn_forced = true
	if storage != null:
		server.use_storage(storage, saved)
	if dev.weather >= 0:
		server.weather.set_kind(dev.weather as Weather.Kind, clock)

	var transports := LocalTransport.create_pair()
	server.connect_client(transports[1])

	client = GAME_CLIENT_SCENE.instantiate()
	add_child(client)
	client.debug_overlay.server_stats = _server_stats
	client.quit_requested.connect(_quit)
	client.connect_to_server(transports[0], Settings.view_distance)
	client.world_viewport.set_orbit_degrees(dev.camera_angles.x, dev.camera_angles.y)
	if dev.first_person or dev.dive >= 0.0:
		client.start_first_person(deg_to_rad(dev.look_pitch))
		client.dive_hold = dev.dive
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
	if not _dev_actions_started and client.is_view_complete():
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
	var lines := PackedStringArray(["%s: %d chunks  |  tick %d  |  %d %s" % args])
	var session := server.first_session()
	if session != null:
		var tile := Coords.world_to_tile(session.position)
		var column := server.world.generator.sample_column(tile.x, tile.y)
		var climate := [
			column.continentalness,
			column.erosion,
			column.weirdness,
			TerrainShaper.peaks_valleys(column.weirdness),
			column.temperature,
			column.humidity,
			column.height,
		]
		lines.append("C %.2f  E %.2f  W %.2f  PV %.2f  T %.2f  H %.2f  |  %.1f m" % climate)
	return lines


func _apply_dev_preferences() -> void:
	# Temporary overrides: not saved to the user's settings file.
	if not dev.language.is_empty():
		Settings.override(&"language", dev.language)
		Settings.apply_language()
	if dev.zoom > 0:
		Settings.override(&"world_zoom", dev.zoom)
	if dev.show_debug or dev.hide_debug:
		Settings.override(&"show_debug", not dev.hide_debug)
	if dev.quality >= 0:
		Settings.override(&"graphics_quality", clampi(dev.quality, 0, 3))
	if dev.hd:
		Settings.override(&"hd_rendering", true)


func _start_dev_actions() -> void:
	if dev.autowalk.x != 0:
		Input.action_press(
			InputBindings.MOVE_RIGHT if dev.autowalk.x > 0 else InputBindings.MOVE_LEFT
		)
	if dev.autowalk.y != 0:
		Input.action_press(InputBindings.MOVE_DOWN if dev.autowalk.y > 0 else InputBindings.MOVE_UP)
	if dev.hold_jump:
		Input.action_press(InputBindings.JUMP)
	for i in absi(dev.descend):
		client.transport.send(Msg.debug_move_depth(-signi(dev.descend)))
	client.local_player.noclip = dev.noclip
	client.interaction.aim_override = dev.aim
	client.interaction.breaking = dev.hold_break
	client.interaction.place_soon = dev.place_once
	var session := server.first_session()
	for entry in dev.give:
		session.inventory.add(entry.x, entry.y)
	if not dev.give.is_empty():
		session.transport.send(Msg.inventory(session.inventory))
	if dev.open_inventory:
		client.open_inventory()
	if dev.book_spread >= 0:
		client.select_hand(GameClient.BOOK_SLOT)
		client.open_book()
		client.book_screen.turn(dev.book_spread)
	if dev.drop_held:
		client.transport.send(Msg.item_drop(0, true))
	if dev.open_map:
		client.debug_map.cycle(client.local_player.current_tile(), client.map_row())
	if dev.open_pause_menu:
		client.pause()


func _update_screenshot() -> void:
	if _screenshot_taken or not client.is_view_complete():
		return
	# Wait until chunks stop streaming in (the world around is complete).
	if client.world.chunks.size() != _seen_chunks:
		_seen_chunks = client.world.chunks.size()
		_ready_frames = 0
		return
	_ready_frames += 1
	if _ready_frames < dev.screenshot_delay:
		return
	_screenshot_taken = true
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	# With HDR 2D the viewport holds linear colors; the screen shows sRGB.
	if get_viewport().use_hdr_2d:
		image.convert(Image.FORMAT_RGBA8)
		image.linear_to_srgb()
	var error := image.save_png(dev.screenshot_path)
	if error != OK:
		push_error("Screenshot failed: %s" % error_string(error))
	else:
		print("Screenshot saved to ", dev.screenshot_path)
	get_tree().quit()


func _quit() -> void:
	get_tree().quit()


func _exit_tree() -> void:
	# Let worker threads finish before the engine shuts down.
	server.shutdown()
	server.save()
