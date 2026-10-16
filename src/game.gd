class_name Game
extends Node
## The game played on this machine (Main's, when it is no dedicated
## server). Until the title screen, it plays one solo world directly:
## the saved one (created and saved on first launch), or a throwaway world
## for a dev seed (see DevOptions.saves_world). It creates the integrated
## server, connects the client through a local transport, drives the fixed
## 20 TPS simulation and saves the world when the game closes. With
## --connect, or from the join screen (Online's signals), the client joins
## a dedicated server instead (NetClient, no server here): the world played
## is left first (saved), and it can be joined again or left for the solo
## world without starting the game again.

## Loaded when a client starts (never on a dedicated server).
const GAME_CLIENT_SCENE := "res://scenes/game_client.tscn"
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
## The server joined last [address, port, name, password] (try again), and
## whether it goes into the recent servers once it welcomes the player.
var _joining := []
var _remember := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	dev = DevOptions.parse(OS.get_cmdline_user_args())
	_apply_dev_preferences()
	if not dev.connect_address.is_empty():
		join(dev.connect_address, dev.connect_port, dev.player_name, dev.password)
	else:
		play_solo()


## Plays the solo world (left from a server: back to it).
func play_solo() -> void:
	_leave()
	var storage: WorldStorage = null
	var saved := {}
	if dev.saves_world():
		storage = WorldStorage.of_world(dev.world_folder)
		if dev.new_world:
			storage.erase()
			dev.new_world = false
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
	# Developer options moving between caves or showing the map work in
	# every game mode.
	server.cheats_anywhere = dev.descend != 0 or dev.open_map

	var transports := LocalTransport.create_pair()
	server.connect_client(transports[1])

	_start_client(transports[0], "Player")
	client.debug_overlay.server_stats = _server_stats
	# Answer the handshake right away so the first frame has terrain.
	server.process_messages()


## Leaves the world played (solo: saved) and joins a dedicated server: the
## client alone, through the network. `remember`: into the recent servers
## once it welcomes the player.
func join(
	address: String, port: int, player_name: String, password: String, remember := false
) -> void:
	_leave()
	_joining = [address, port, player_name, password]
	_remember = remember
	var net := NetClient.new()
	net.connect_to(address, port)
	_start_client(net, player_name, password, "%s:%d" % [address, port])


func _start_client(
	transport: Transport, player_name: String, password := "", address := ""
) -> void:
	client = (load(GAME_CLIENT_SCENE) as PackedScene).instantiate()
	add_child(client)
	client.quit_requested.connect(_quit)
	var online := client.online
	online.join_requested.connect(_on_join_requested, CONNECT_DEFERRED)
	online.retry_requested.connect(_retry, CONNECT_DEFERRED)
	online.solo_requested.connect(play_solo, CONNECT_DEFERRED)
	online.welcomed.connect(_on_welcomed)
	online.play_on(address)
	client.connect_to_server(transport, Settings.view_distance, player_name, password)
	if not address.is_empty():
		client.connection.show_connecting(address)
	client.world_viewport.set_orbit_degrees(dev.camera_angles.x, dev.camera_angles.y)
	if dev.first_person or dev.dive >= 0.0:
		client.start_first_person(deg_to_rad(dev.look_pitch))
		client.dive_hold = dev.dive


func _process(delta: float) -> void:
	if client == null:
		return
	if server != null:
		server.process_messages()
	if server != null and not get_tree().paused:
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
	if server == null:
		_open_dev_screens()
		return
	var session := server.first_session()
	for entry in dev.animals:
		server.creatures.spawn_near(entry.x, session.position, session.height, entry.y)
	for entry in dev.give:
		session.inventory.add(entry.x, entry.y)
	for row in mini(dev.grid.size(), Inventory.GRID):
		for column in mini(dev.grid[row].size(), Inventory.GRID):
			var cell := Inventory.CRAFT + row * Inventory.GRID + column
			if dev.grid[row][column] != Items.Id.NONE:
				session.inventory.items[cell] = dev.grid[row][column]
				session.inventory.counts[cell] = 1
	if not dev.give.is_empty() or not dev.grid.is_empty():
		session.transport.send(Msg.inventory(session.inventory))
	_open_dev_screens()


func _open_dev_screens() -> void:
	if dev.open_inventory:
		client.actions.open_inventory()
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
	if dev.open_join_screen:
		client.pause()
		client.online.join_screen.open()
	if dev.show_players:
		Input.action_press(InputBindings.PLAYER_LIST)


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


func _on_join_requested(address: String, port: int, player_name: String, password: String) -> void:
	join(address, port, player_name, password, true)


## The same server again (its connection ended).
func _retry() -> void:
	if not _joining.is_empty():
		join(_joining[0], _joining[1], _joining[2], _joining[3], _remember)


func _on_welcomed() -> void:
	if _remember and not _joining.is_empty():
		_remember = false
		client.online.join_screen.servers.remember(_joining[0], _joining[1], _joining[2])


## Leaves the world played: the client goes, the integrated server saves.
func _leave() -> void:
	get_tree().paused = false
	if client != null:
		client.transport.close()
		remove_child(client)
		client.queue_free()
		client = null
	if server != null:
		# Let worker threads finish first.
		server.shutdown()
		server.save()
		server = null
	_tick_accumulator = 0.0
	_ready_frames = 0
	_seen_chunks = 0


func _exit_tree() -> void:
	_leave()
