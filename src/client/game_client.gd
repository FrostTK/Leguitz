class_name GameClient
extends Node
## Everything the player sees and controls. It only knows the world
## through messages from the server, which keeps solo and multiplayer on
## the same code path. The world is drawn in 3D (see WorldViewport).

signal quit_requested

## Point the camera looks at, above the player's feet (local units).
const CAMERA_TARGET_OFFSET := Vector3(0.0, 0.75, 0.0)
const CAMERA_FOLLOW_SHARPNESS := 10.0
## Orbit speed: radians per screen pixel of mouse drag, and per second
## with a gamepad stick.
const MOUSE_ORBIT_SPEED := Vector2(0.006, 0.004)
const STICK_ORBIT_SPEED := Vector2(2.4, 1.3)

var transport: Transport
var world := ClientWorld.new()
var clock := WorldClock.new()
var world_info := {}
var player_id := -1
var joined := false
var local_player := LocalPlayer.new()
## Radius (chunks) last asked to the server.
var view_distance := 0

var world_viewport := WorldViewport.new()
## Holds the terrain in local tile units; its basis stretches them for the
## camera's yaw and pitch (see Render3D.root_basis).
var world_root := Node3D.new()
var world_view := WorldView3D.new()
var player_model := PlayerModel.new()
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
## Set on spawn and teleport: place the camera without smoothing once the
## player has landed on known ground.
var _needs_snap := false
var _min_view_distance := GameConst.DEFAULT_VIEW_DISTANCE
## Smoothed camera target (local units).
var _camera_local := Vector3.ZERO
## Camera yaw and pitch the world root is stretched for.
var _root_orbit := Vector2.INF
var _dragging := false

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
	root.add_child(world_root)
	world_root.add_child(world_view)
	world_root.add_child(clouds)
	world_root.add_child(player_model)
	weather_effects.client_world = world
	weather_effects.local_player = local_player
	root.add_child(weather_effects)

	lighting.process_mode = Node.PROCESS_MODE_PAUSABLE
	lighting.clock = clock
	lighting.client_world = world
	lighting.weather = weather_effects
	lighting.clouds = clouds
	lighting.sun = sun
	lighting.lantern = player_model.lantern
	lighting.environment = environment
	add_child(lighting)
	lighting.apply_quality(Settings.graphics_quality)
	Settings.changed.connect(_on_settings_changed)


func _on_settings_changed(key: StringName) -> void:
	if key == &"graphics_quality":
		lighting.apply_quality(Settings.graphics_quality)


## `min_view_distance` is the smallest radius (chunks) to load around the
## player; more is asked when the view needs it (see _update_view_distance).
func connect_to_server(server_transport: Transport, min_view_distance: int) -> void:
	transport = server_transport
	local_player.transport = server_transport
	_min_view_distance = min_view_distance
	view_distance = needed_view_distance()
	transport.send(Msg.hello("Player", view_distance))


## Chunks needed around the player to fill the screen: the ground in view
## (zoom, window size, camera angle), turned by the camera's yaw, plus a
## margin for the chunk the player is in and for terrain above or below.
func needed_view_distance() -> int:
	var ground := world_viewport.ground_size()
	var yaw := world_viewport.current_yaw
	var c := absf(cos(yaw))
	var s := absf(sin(yaw))
	var half := maxf(c * ground.x + s * ground.y, s * ground.x + c * ground.y) * 0.5
	var radius := ceili(half / GameConst.CHUNK_SIZE) + 2
	return clampi(
		maxi(radius, _min_view_distance), GameConst.MIN_VIEW_DISTANCE, GameConst.MAX_VIEW_DISTANCE
	)


## Asks the server for more chunks when the view grows; gives them back
## only once it shrank clearly (no back and forth while zooming).
func _update_view_distance() -> void:
	var needed := needed_view_distance()
	if needed > view_distance or needed < view_distance - 1:
		view_distance = needed
		transport.send(Msg.set_view_distance(needed))


func _process(delta: float) -> void:
	if transport == null:
		return
	for message in transport.poll():
		_handle_message(message)
	if not get_tree().paused:
		clock.advance(delta)
		_update_orbit(delta)
		local_player.step(delta)
		_update_view(delta)
	_loading_label.visible = not is_ready_to_play()


## Turns the camera (gamepad stick) and the world root with it.
func _update_orbit(delta: float) -> void:
	var stick := Input.get_vector(
		InputBindings.CAMERA_LEFT,
		InputBindings.CAMERA_RIGHT,
		InputBindings.CAMERA_UP,
		InputBindings.CAMERA_DOWN
	)
	if stick != Vector2.ZERO:
		world_viewport.orbit(-stick.x * STICK_ORBIT_SPEED.x * delta, 0.0)
		world_viewport.orbit(0.0, stick.y * STICK_ORBIT_SPEED.y * delta)
	world_viewport.update_orbit(delta)
	var orbit := Vector2(world_viewport.current_yaw, world_viewport.current_pitch)
	local_player.camera_yaw = orbit.x
	if orbit != _root_orbit:
		_root_orbit = orbit
		world_root.basis = Render3D.root_basis(orbit.x, orbit.y)
		world_view.place_lights()


func _update_view(delta: float) -> void:
	if not joined or local_player.is_landing():
		return
	var root := world_root.transform
	var feet := local_player.position
	player_model.animate(
		Render3D.world_px_to_local(feet, local_player.height),
		local_player.heading,
		local_player.speed,
		not local_player.body.on_ground,
		delta
	)
	# The camera follows the ground the player stands on (not each jump).
	var focus := Render3D.world_px_to_local(feet, local_player.view_height)
	focus += CAMERA_TARGET_OFFSET
	if _needs_snap:
		_needs_snap = false
		_camera_local = focus
	var follow := 1.0 - exp(-CAMERA_FOLLOW_SHARPNESS * delta)
	_camera_local = _camera_local.lerp(focus, follow)
	var target := root * _camera_local
	world_view.focus = Coords.tile_to_chunk(local_player.current_tile())
	world_viewport.target = target
	clouds.target = _camera_local
	weather_effects.target = target
	weather_effects.view_size = world_viewport.view_size()
	weather_effects.view_pitch = world_viewport.current_pitch
	lighting.reference_height = (root * focus).y
	lighting.camera_distance = world_viewport.camera_distance
	lighting.view_depth = world_viewport.far_ground_distance()
	world_view.set_lod(WorldView3D.lod_for_view(world_viewport.ground_size()))
	_update_view_distance()


## True once the player has spawned and stands on loaded ground.
func is_ready_to_play() -> bool:
	return joined and not local_player.is_landing()


## True once everything received is on screen (used for screenshots).
func is_view_complete() -> bool:
	return is_ready_to_play() and world_view.is_up_to_date()


func pause() -> void:
	debug_map.close()
	get_tree().paused = true
	world_viewport.set_paused(true)
	pause_menu.open()


func resume() -> void:
	pause_menu.close()
	get_tree().paused = false
	world_viewport.set_paused(false)


func _unhandled_input(event: InputEvent) -> void:
	if not joined or get_tree().paused:
		_dragging = false
		return
	if _handle_camera_input(event):
		get_viewport().set_input_as_handled()
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


## Mouse drag (right or middle button) orbits the camera around the
## player; the wheel and +/- zoom. Returns true when the event was used.
func _handle_camera_input(event: InputEvent) -> bool:
	var button := event as InputEventMouseButton
	if button != null and button.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		_dragging = button.pressed
		return true
	var motion := event as InputEventMouseMotion
	if motion != null and _dragging:
		var drag := motion.screen_relative
		# Grab the world: dragging right turns it right, dragging down tilts
		# the view towards a top-down one.
		world_viewport.orbit(-drag.x * MOUSE_ORBIT_SPEED.x, drag.y * MOUSE_ORBIT_SPEED.y)
		return true
	if event.is_action_pressed(InputBindings.CAMERA_RESET):
		world_viewport.reset_orbit()
		return true
	if event.is_action_pressed(InputBindings.ZOOM_IN):
		Settings.set_world_zoom(mini(world_viewport.world_zoom + 1, Settings.MAX_WORLD_ZOOM))
		return true
	if event.is_action_pressed(InputBindings.ZOOM_OUT):
		Settings.set_world_zoom(maxi(world_viewport.world_zoom - 1, 1))
		return true
	return false


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
