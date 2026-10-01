class_name GameClient
extends Node
## Everything the player sees and controls. It only knows the world
## through messages from the server, which keeps solo and multiplayer on
## the same code path. The world is drawn in 3D (see WorldViewport).

signal quit_requested

## Point the camera looks at, above the player's feet (units).
const CAMERA_TARGET_OFFSET := Vector3(0.0, 1.5, 0.0)

var transport: Transport
var world := ClientWorld.new()
var clock := WorldClock.new()
var world_info := {}
var player_id := -1
var joined := false
var local_player := LocalPlayer.new()

var world_viewport := WorldViewport.new()
var world_view := WorldView3D.new()
var player_view := PlayerView3D.new()
var lighting := LightingController.new()
var weather_effects := WeatherEffects.new()
var clouds := CloudShadows3D.new()
var sun := DirectionalLight3D.new()
var environment := Environment.new()

var debug_overlay := DebugOverlay.new()
var debug_map := DebugMap.new()
var hud_clock := HudClock.new()
var pause_menu := PauseMenu.new()
var _loading_label := Label.new()
## Set on spawn and teleport: place the view without smoothing once the
## ground under the player is loaded.
var _needs_snap := false

@onready var _ui_root: Control = $UI/Root


func _ready() -> void:
	# Keep receiving server messages while paused; the world itself pauses.
	process_mode = Node.PROCESS_MODE_ALWAYS
	local_player.client_world = world
	world_view.client_world = world
	_setup_world()
	hud_clock.clock = clock
	pause_menu.clock = clock
	debug_overlay.client = self

	_ui_root.theme = UiTheme.build()
	_loading_label.text = "LOADING_WORLD"
	_loading_label.add_theme_color_override("font_color", Color.WHITE)
	_loading_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_ui_root.add_child(_loading_label)
	_ui_root.add_child(hud_clock)
	_ui_root.add_child(debug_overlay)
	_ui_root.add_child(debug_map)
	_ui_root.add_child(pause_menu)

	pause_menu.resume_requested.connect(resume)
	pause_menu.quit_requested.connect(quit_requested.emit)
	pause_menu.time_settings_requested.connect(_on_time_settings_requested)
	debug_map.map_requested.connect(_on_map_requested)


## Builds the 3D scene: terrain, player, sky light, environment, weather.
func _setup_world() -> void:
	world_viewport.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world_viewport)
	move_child(world_viewport, 0)
	var root := world_viewport.world_root()
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	root.add_child(world_environment)
	root.add_child(sun)
	root.add_child(world_view)
	root.add_child(player_view)
	root.add_child(clouds)
	weather_effects.client_world = world
	weather_effects.local_player = local_player
	root.add_child(weather_effects)

	lighting.process_mode = Node.PROCESS_MODE_PAUSABLE
	lighting.clock = clock
	lighting.client_world = world
	lighting.weather = weather_effects
	lighting.clouds = clouds
	lighting.sun = sun
	lighting.lantern = player_view.lantern
	lighting.environment = environment
	lighting.camera_distance = WorldViewport.CAMERA_DISTANCE
	add_child(lighting)
	lighting.apply_quality(Settings.graphics_quality)
	Settings.changed.connect(_on_settings_changed)


func _on_settings_changed(key: StringName) -> void:
	if key == &"graphics_quality":
		lighting.apply_quality(Settings.graphics_quality)


func connect_to_server(server_transport: Transport, view_distance: int) -> void:
	transport = server_transport
	local_player.transport = server_transport
	transport.send(Msg.hello("Player", view_distance))


func _process(delta: float) -> void:
	if transport == null:
		return
	for message in transport.poll():
		_handle_message(message)
	if not get_tree().paused:
		clock.advance(delta)
		local_player.step(delta)
		_update_view(delta)
	_loading_label.visible = not is_ready_to_play()


func _update_view(delta: float) -> void:
	if not joined:
		return
	var height := ChunkMesher.height_at(world, local_player.position)
	if _needs_snap and world.has_tile_chunk(local_player.current_tile()):
		_needs_snap = false
		player_view.place(local_player.position, height)
		world_viewport.target = player_view.position + CAMERA_TARGET_OFFSET
		world_viewport.snap_to_target()
	player_view.update_from(local_player.position, height, local_player.facing, delta)
	var target := player_view.position + CAMERA_TARGET_OFFSET
	world_viewport.target = target
	clouds.target = target
	weather_effects.target = target
	weather_effects.view_size = world_viewport.view_size()
	lighting.reference_height = player_view.position.y


## True once the player has spawned and the ground under them is loaded.
func is_ready_to_play() -> bool:
	return joined and world.has_tile_chunk(local_player.current_tile())


func pause() -> void:
	debug_map.close()
	get_tree().paused = true
	pause_menu.open()


func resume() -> void:
	pause_menu.close()
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not joined or get_tree().paused:
		return
	if event.is_action_pressed(InputBindings.PAUSE):
		if debug_map.visible:
			debug_map.close()
		else:
			pause()
	elif event.is_action_pressed(InputBindings.TOGGLE_MAP):
		debug_map.cycle(local_player.current_tile(), world.layer)
	elif event.is_action_pressed(InputBindings.LAYER_UP):
		transport.send(Msg.debug_change_layer(1))
	elif event.is_action_pressed(InputBindings.LAYER_DOWN):
		transport.send(Msg.debug_change_layer(-1))
	elif event.is_action_pressed(InputBindings.CYCLE_WEATHER):
		var next := (weather_effects.weather.kind + 1) % Weather.Kind.size()
		transport.send(Msg.debug_set_weather(next))
	elif event.is_action_pressed(InputBindings.TOGGLE_NOCLIP):
		local_player.noclip = not local_player.noclip
	else:
		return
	get_viewport().set_input_as_handled()


func _handle_message(message: Dictionary) -> void:
	match message.get("t"):
		Msg.WELCOME:
			player_id = message["player_id"]
			world_info = message["world"]
			world.layer = message["layer"]
			local_player.spawn_at(message["spawn"])
			joined = true
			_needs_snap = true
		Msg.CHUNK_DATA:
			var chunk := ChunkData.from_dict(message["chunk"])
			if chunk.layer == world.layer:
				world.store(chunk)
				world_view.show_chunk(chunk)
		Msg.CHUNK_UNLOAD:
			world.remove(message["key"])
			world_view.remove_chunk(message["key"])
		Msg.TIME_STATE:
			clock.load_dict(message["clock"])
			if pause_menu.visible:
				pause_menu.refresh_from_state()
		Msg.PLAYER_CORRECTION:
			local_player.apply_correction(message["pos"])
		Msg.PLAYER_TELEPORT:
			_teleport(message["pos"], message["layer"])
		Msg.MAP_DATA:
			debug_map.show_map(message["png"], message["scale"])
		Msg.WEATHER_STATE:
			weather_effects.apply_state(message["weather"])
		var unknown:
			push_warning("Client: unknown message type %s" % unknown)


func _teleport(position: Vector2, layer: int) -> void:
	if layer != world.layer:
		world.clear()
		world_view.clear()
		world.layer = layer
		debug_map.close()
	local_player.apply_correction(position)
	_needs_snap = true


func _on_time_settings_requested(mode: int, value: float) -> void:
	transport.send(Msg.set_time(mode, value))


func _on_map_requested(center: Vector2i, layer: int, size_px: int, scale: int) -> void:
	transport.send(Msg.map_request(center, layer, size_px, scale))
