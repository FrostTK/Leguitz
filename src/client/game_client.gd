class_name GameClient
extends Node2D
## Everything the player sees and controls. It only knows the world
## through messages from the server, which keeps solo and multiplayer on
## the same code path.

signal quit_requested

var transport: Transport
var world := ClientWorld.new()
var clock := WorldClock.new()
var world_info := {}
var player_id := -1
var joined := false

var lighting := LightingController.new()
var weather_effects := WeatherEffects.new()
var clouds := CloudShadows.new()
var sun := DirectionalLight2D.new()
var environment := Environment.new()

var debug_overlay := DebugOverlay.new()
var debug_map := DebugMap.new()
var hud_clock := HudClock.new()
var pause_menu := PauseMenu.new()
var _loading_label := Label.new()

@onready var world_view: WorldView = $WorldView
@onready var local_player: LocalPlayer = $WorldView/Entities/LocalPlayer
@onready var camera: CameraRig = $Camera
@onready var ambient: CanvasModulate = $Ambient
@onready var _ui_root: Control = $UI/Root


func _ready() -> void:
	# Keep receiving server messages while paused; the world itself pauses.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for node: Node in [world_view, camera]:
		node.process_mode = Node.PROCESS_MODE_PAUSABLE
	local_player.client_world = world
	world_view.client_world = world
	_setup_rendering()
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


func _setup_rendering() -> void:
	# Glow (bloom) needs HDR 2D, enabled in the project settings.
	environment.background_mode = Environment.BG_CANVAS
	environment.glow_enabled = true
	environment.glow_intensity = 0.9
	environment.glow_strength = 1.0
	environment.glow_bloom = 0.02
	environment.glow_hdr_threshold = 1.0
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	sun.energy = 0.0
	sun.blend_mode = Light2D.BLEND_MODE_ADD
	add_child(sun)

	clouds.camera = camera
	add_child(clouds)
	move_child(clouds, world_view.get_index() + 1)

	weather_effects.camera = camera
	weather_effects.client_world = world
	weather_effects.player = local_player
	add_child(weather_effects)
	weather_effects.attach_glowing($Emission/Root)

	lighting.clock = clock
	lighting.client_world = world
	lighting.world_view = world_view
	lighting.weather = weather_effects
	lighting.clouds = clouds
	lighting.canvas_modulate = ambient
	lighting.sun = sun
	lighting.lantern = local_player.lantern
	lighting.environment = environment
	lighting.player_shadow.connect(local_player.set_sun_shadow)
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
	_loading_label.visible = not is_ready_to_play()


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
			camera.snap_to_target()
			joined = true
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
	camera.snap_to_target()


func _on_time_settings_requested(mode: int, value: float) -> void:
	transport.send(Msg.set_time(mode, value))


func _on_map_requested(center: Vector2i, layer: int, size_px: int, scale: int) -> void:
	transport.send(Msg.map_request(center, layer, size_px, scale))
