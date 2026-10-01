class_name GameClient
extends Node
## Everything the player sees and controls. It only knows the world
## through messages from the server, which keeps solo and multiplayer on
## the same code path. The world is drawn in 3D (see WorldViewport), seen
## from above or in first person (see ViewMode): the camera dives into the
## player's head and back.

signal quit_requested

## Point the camera looks at, above the player's feet (local units).
const CAMERA_TARGET_OFFSET := Vector3(0.0, 0.75, 0.0)
const CAMERA_FOLLOW_SHARPNESS := 10.0
## Orbit speed: radians per screen pixel of mouse drag, and per second
## with a gamepad stick.
const MOUSE_ORBIT_SPEED := Vector2(0.006, 0.004)
const STICK_ORBIT_SPEED := Vector2(2.4, 1.3)
## Under cover, the view cuts the world this many levels above the ground
## the player stands on (just over their head).
const CUT_ABOVE := 2
## This much rock over the player means caves: cave light and no weather.
const UNDERGROUND_COVER := 6.0
## Seconds the dive between the top-down view and first person lasts.
const DIVE_TIME := 0.6
## First person: the eye above the feet (local units), look speeds
## (radians per pixel of mouse motion, per second with a stick), the pitch
## limit and the pitch the view starts at (slightly down).
const EYE_HEIGHT := 1.35
const MOUSE_LOOK_SPEED := 0.0025
const STICK_LOOK_SPEED := Vector2(2.6, 1.8)
const MAX_LOOK_PITCH := 1.53
const ENTRY_LOOK_PITCH := -0.2
## The ceiling closes over the view (the cut stops) this far into the dive.
const CUT_UNTIL := 0.95
## Radius (chunks) loaded around the player in first person.
const FIRST_PERSON_VIEW_DISTANCE := 6
## Where the lantern is carried in first person (right, up, back of the
## eye, in its frame).
const LANTERN_IN_HAND := Vector3(0.35, -0.3, -0.25)

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
var crosshair := Crosshair.new()
## Chooses between the top-down view and first person (caves, F5).
var view_mode := ViewMode.new()
## 0 = top-down view, 1 = first person, in between during the dive.
var first_person := 0.0
## Developer option: holds the dive at this point (-1: off).
var dive_hold := -1.0
## True while the view cuts the world above the player (see CUT_ABOVE).
var covered := false
## True deep enough under the rock for caves' light and silence.
var underground := false
var _loading_label := Label.new()
## Set on spawn and teleport: place the camera without smoothing once the
## player has landed on known ground.
var _needs_snap := false
var _min_view_distance := GameConst.DEFAULT_VIEW_DISTANCE
## Smoothed camera target (local units).
var _camera_local := Vector3.ZERO
## Camera yaw, pitch and stretch the world root is set for.
var _root_orbit := Vector3.INF
var _dragging := false
## First-person look angles (radians; pitch > 0 looks up).
var _look_yaw := 0.0
var _look_pitch := ENTRY_LOOK_PITCH

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
	_ui_root.add_child(crosshair)
	_ui_root.add_child(hud_clock)
	_ui_root.add_child(debug_overlay)
	_ui_root.add_child(debug_map)
	_ui_root.add_child(pause_menu)

	pause_menu.resume_requested.connect(resume)
	pause_menu.quit_requested.connect(quit_requested.emit)
	pause_menu.time_settings_requested.connect(_on_time_settings_requested)
	debug_map.map_requested.connect(_on_map_requested)
	view_mode.automatic = Settings.cave_first_person


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
	elif key == &"cave_first_person":
		view_mode.set_automatic(Settings.cave_first_person)


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
	if view_mode.first_person or first_person > 0.0:
		radius = maxi(radius, FIRST_PERSON_VIEW_DISTANCE)
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
		_update_view_mode(delta)
		_update_orbit(delta)
		local_player.step(delta)
		_update_view(delta)
	_loading_label.visible = not is_ready_to_play()


## Starts in first person right away (developer option).
func start_first_person(look_pitch := ENTRY_LOOK_PITCH) -> void:
	if not view_mode.first_person:
		view_mode.toggle()
	_look_yaw = world_viewport.current_yaw
	_look_pitch = look_pitch
	first_person = 1.0


## Follows the chosen view: dives into the player's head for first person,
## back out for the top-down view.
func _update_view_mode(delta: float) -> void:
	if not joined:
		return
	view_mode.update(covered, underground)
	var wanted := 1.0 if view_mode.first_person else 0.0
	if wanted > first_person and first_person == 0.0:
		# Entering: look the way the top-down camera faced, a little down.
		_look_yaw = world_viewport.current_yaw
		_look_pitch = ENTRY_LOOK_PITCH
		_dragging = false
	elif wanted < first_person and first_person == 1.0:
		# Leaving: the top-down camera faces where the player looked.
		var pitch_degrees := rad_to_deg(world_viewport.pitch)
		world_viewport.set_orbit_degrees(rad_to_deg(_look_yaw), pitch_degrees)
	first_person = move_toward(first_person, wanted, delta / DIVE_TIME)
	if dive_hold >= 0.0:
		first_person = dive_hold
	var mouse := Input.MOUSE_MODE_CAPTURED if view_mode.first_person else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != mouse:
		Input.mouse_mode = mouse
	crosshair.visible = first_person >= 1.0


## Turns the camera (gamepad stick) and the world root with it.
func _update_orbit(delta: float) -> void:
	var stick := Input.get_vector(
		InputBindings.CAMERA_LEFT,
		InputBindings.CAMERA_RIGHT,
		InputBindings.CAMERA_UP,
		InputBindings.CAMERA_DOWN
	)
	if stick != Vector2.ZERO:
		if view_mode.first_person:
			_look(-stick.x * STICK_LOOK_SPEED.x * delta, -stick.y * STICK_LOOK_SPEED.y * delta)
		else:
			world_viewport.orbit(-stick.x * STICK_ORBIT_SPEED.x * delta, 0.0)
			world_viewport.orbit(0.0, stick.y * STICK_ORBIT_SPEED.y * delta)
	world_viewport.update_orbit(delta)
	# Keys move relative to the view: the top-down camera, or the eye.
	local_player.camera_yaw = _look_yaw if first_person > 0.0 else world_viewport.current_yaw
	# The stretch for the top-down view fades out during the dive.
	var stretch := 1.0 - smoothstep(0.0, 1.0, first_person)
	var orbit := Vector3(world_viewport.current_yaw, world_viewport.current_pitch, stretch)
	if orbit != _root_orbit:
		_root_orbit = orbit
		world_root.basis = Render3D.root_basis(orbit.x, orbit.y, stretch)
		world_view.place_lights()


func _look(delta_yaw: float, delta_pitch: float) -> void:
	_look_yaw = wrapf(_look_yaw + delta_yaw, -PI, PI)
	_look_pitch = clampf(_look_pitch + delta_pitch, -MAX_LOOK_PITCH, MAX_LOOK_PITCH)


func _update_view(delta: float) -> void:
	if not joined or local_player.is_landing():
		return
	var root := world_root.transform
	var feet := local_player.position
	var eye := root * Render3D.world_px_to_local(feet, local_player.height + EYE_HEIGHT)
	if first_person > 0.0:
		# The body (unseen) faces the way the player looks.
		local_player.heading = Vector2(-sin(_look_yaw), -cos(_look_yaw))
	player_model.lantern_override = Vector3.INF
	if first_person > 0.5:
		var look := Basis.from_euler(Vector3(_look_pitch, _look_yaw, 0.0))
		player_model.lantern_override = eye + look * LANTERN_IN_HAND
	player_model.set_fade(smoothstep(0.55, 0.85, first_person))
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
	_update_cut(root)
	world_viewport.target = target
	world_viewport.eye = eye
	world_viewport.look_yaw = _look_yaw
	world_viewport.look_pitch = _look_pitch
	world_viewport.first_person = first_person
	RenderingServer.global_shader_parameter_set(
		&"see_through_on", 1.0 if first_person < 0.5 else 0.0
	)
	var diving := first_person > 0.0 and first_person < 1.0
	RenderingServer.global_shader_parameter_set(&"section_on", 0.0 if diving else 1.0)
	clouds.target = _camera_local
	weather_effects.first_person = first_person > 0.5
	weather_effects.target = eye if first_person > 0.5 else target
	weather_effects.view_size = world_viewport.view_size()
	weather_effects.view_pitch = world_viewport.current_pitch
	lighting.first_person = smoothstep(0.0, 1.0, first_person)
	lighting.reference_height = (root * focus).y
	lighting.camera_distance = world_viewport.camera_distance
	lighting.view_depth = world_viewport.far_ground_distance()
	world_view.set_lod_by_distance(first_person > 0.5)
	world_view.set_lod(WorldView3D.lod_for_view(world_viewport.ground_size()))
	_update_view_distance()


## Under cover (a cave, a tunnel, a roof), cuts the world above the
## player's head so the view shows where they are.
func _update_cut(root: Transform3D) -> void:
	var tile := local_player.current_tile()
	var ground := local_player.view_height
	covered = world.is_covered(tile, ground)
	var top := world.surface_height(tile)
	underground = covered and top - ground > UNDERGROUND_COVER
	var cut_row := ChunkData.HEIGHT
	var cut_height := 100000.0
	if covered:
		var cut_level := floori(ground + 0.01) + CUT_ABOVE
		cut_row = cut_level + GameConst.SEA_LEVEL
		# In first person the ceiling is over the eye: no cut (the surface
		# maps keep it, so the floor around blends its grounds).
		if first_person < CUT_UNTIL:
			cut_height = (root.basis * Vector3(0.0, cut_level, 0.0)).y
	world_view.set_view(cut_row, covered or first_person > 0.0)
	RenderingServer.global_shader_parameter_set(&"cut_height", cut_height)
	lighting.underground = underground
	weather_effects.underground = underground


## True once the player has spawned and stands on loaded ground.
func is_ready_to_play() -> bool:
	return joined and not local_player.is_landing()


## True once everything received is on screen (used for screenshots).
func is_view_complete() -> bool:
	return is_ready_to_play() and world_view.is_up_to_date()


func pause() -> void:
	debug_map.close()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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
	if event.is_action_pressed(InputBindings.TOGGLE_VIEW):
		view_mode.toggle()
		get_viewport().set_input_as_handled()
		return
	var used := _handle_look_input(event) if view_mode.first_person else _handle_camera_input(event)
	if used:
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(InputBindings.PAUSE):
		if debug_map.visible:
			debug_map.close()
		else:
			pause()
	elif event.is_action_pressed(InputBindings.TOGGLE_MAP):
		debug_map.cycle(local_player.current_tile(), map_row())
	elif event.is_action_pressed(InputBindings.DEPTH_UP):
		transport.send(Msg.debug_move_depth(1))
	elif event.is_action_pressed(InputBindings.DEPTH_DOWN):
		transport.send(Msg.debug_move_depth(-1))
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


## First person: the mouse (captured) turns the eye; Home levels it.
## Returns true when the event was used.
func _handle_look_input(event: InputEvent) -> bool:
	var motion := event as InputEventMouseMotion
	if motion != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var turn := motion.screen_relative * MOUSE_LOOK_SPEED
		_look(-turn.x, -turn.y)
		return true
	if event.is_action_pressed(InputBindings.CAMERA_RESET):
		_look_pitch = ENTRY_LOOK_PITCH
		return true
	return false


func _handle_message(message: Dictionary) -> void:
	match message.get("t"):
		Msg.WELCOME:
			player_id = message["player_id"]
			world_info = message["world"]
			local_player.spawn_at(message["spawn"], message["h"])
			joined = true
			_needs_snap = true
		Msg.CHUNK_DATA:
			var chunk := ChunkData.from_dict(message["chunk"])
			world.store(chunk)
			world_view.show_chunk(chunk)
		Msg.CHUNK_UNLOAD:
			world.remove(message["coord"])
			world_view.remove_chunk(message["coord"])
		Msg.TIME_STATE:
			clock.load_dict(message["clock"])
			if pause_menu.visible:
				pause_menu.refresh_from_state()
		Msg.PLAYER_CORRECTION:
			local_player.apply_correction(message["pos"], message["h"])
		Msg.PLAYER_TELEPORT:
			local_player.apply_correction(message["pos"], message["h"])
			_needs_snap = true
		Msg.MAP_DATA:
			debug_map.show_map(message["png"], message["scale"])
		Msg.WEATHER_STATE:
			weather_effects.apply_state(message["weather"])
		var unknown:
			push_warning("Client: unknown message type %s" % unknown)


func _on_time_settings_requested(mode: int, value: float) -> void:
	transport.send(Msg.set_time(mode, value))


func _on_map_requested(center: Vector2i, row: int, size_px: int, scale: int) -> void:
	transport.send(Msg.map_request(center, row, size_px, scale))


## What the debug map shows: the surface, or a cut at the player's feet
## when they are under cover.
func map_row() -> int:
	if not covered:
		return Msg.MAP_SURFACE
	return floori(local_player.view_height + 0.01) + GameConst.SEA_LEVEL
