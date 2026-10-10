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
## Where the lantern is carried in first person (right, up, back of the
## eye, in its frame).
const LANTERN_IN_HAND := Vector3(-0.5, -0.3, 0.05)
## Under cover (top-down), the lantern hangs this high over the feet
## (levels: under a ceiling two levels up) and this far towards the camera
## (tiles), lighting the body seen from above.
const LANTERN_UNDER_COVER := 1.8
const LANTERN_TOWARDS_CAMERA := 0.45
## A right click moving less than this (screen pixels) places a block; more
## is a drag turning the camera.
const CLICK_SLOP := 6.0
## Size (local units) of what the player holds in the hand of the body
## (not tools, swords nor the bow: ToolModels).
const HELD_SIZE := 0.28
## A food furnace breaking is told to players within this many tiles.
const FURNACE_NEWS_RANGE := 12.0
## The hand's "slot" of the player's book (beside the hotbar's 9).
const BOOK_SLOT := Inventory.HOTBAR

var transport: Transport
var world := ClientWorld.new()
var clock := WorldClock.new()
var world_info := {}
var player_id := -1
var joined := false
var local_player := LocalPlayer.new()
## The player's items, as the server last told (clicks are predicted on it).
var inventory := Inventory.new()
## How items look (models, icons).
var items := ItemLibrary.new()
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
var save_notice := SaveNotice.new()
var pause_menu := PauseMenu.new()
var crosshair := Crosshair.new()
## Aiming, breaking and placing blocks.
var interaction := BlockInteraction.new()
var hotbar := Hotbar.new()
## The player's vitality: the gauge, hurts, passing out (VitalsView).
var vitals := VitalsView.new()
## The game mode: creative's flight and debug keys, the spectator.
var modes := GameModeView.new()
var inventory_screen := InventoryScreen.new()
## The player's book, open.
var book_screen := BookScreen.new()
## The chat (T; "/" for a command).
var chat := ChatBox.new()
## The player's book is in hand (its slot: Settings.guide_book). Only the
## client knows: the server keeps the hotbar slot chosen before.
var book_in_hand := false
## What the player does in the inventory screen and with what it opens.
var actions := InventoryActions.new()
var dropped_items := DroppedItemsView.new()
## The animals and monsters around, the arrows in flight, the bow, the
## fishing rod.
var creatures := CreaturesView.new()
var arrows := ArrowsView.new()
var archer := Archer.new()
var angler := Angler.new()
## The boats, and the one the player is aboard.
var boats := BoatsView.new()
var helm := Helm.new()
var item_icons := ItemIcons.new()
## The arm and what is in hand in first person (a child of the camera).
var held_view := HeldView.new()
## Chooses between the top-down view and first person (caves, V).
var view_mode := ViewMode.new()
## 0 = top-down view, 1 = first person, in between during the dive.
var first_person := 0.0
## Developer option: holds the dive at this point (-1: off).
var dive_hold := -1.0
## True while the view cuts the world above the player (see CUT_ABOVE).
var covered := false
## True deep enough under the rock for caves' light and silence.
var underground := false
## Voxel rows from this one up are cut away from the view (ChunkData.HEIGHT:
## no cut) where `cut_region` reaches: what is there cannot be aimed at.
var shown_below_row := ChunkData.HEIGHT
var cut_region := CutRegion.new()
var _loading_label := Label.new()
## The cut region's mask for the shaders, and what the region was last
## worked out for: [tile, level, world revision].
var _cut_mask := ImageTexture.create_from_image(CutRegion.new().image())
var _cut_key := []
## The feet were in water or lava last frame (a splash when they go in).
var _was_in_liquid := false
## Set on spawn and teleport: place the camera without smoothing once the
## player has landed on known ground.
var _needs_snap := false
var _min_view_distance := GameConst.DEFAULT_VIEW_DISTANCE
## Smoothed camera target (local units).
var _camera_local := Vector3.ZERO
## Camera yaw, pitch and stretch the world root is set for.
var _root_orbit := Vector3.INF
var _dragging := false
## The item shown in hand (see _update_held).
var _shown_held := -1
## The right or middle button is down (MOUSE_BUTTON_NONE: neither): a drag
## turns the camera once it moved CLICK_SLOP (how far it moved so far), a
## right click places a block.
var _drag_button := MOUSE_BUTTON_NONE
var _drag_moved := 0.0
## First-person look angles (radians; pitch > 0 looks up).
var _look_yaw := 0.0
var _look_pitch := ENTRY_LOOK_PITCH

@onready var _ui_root: Control = $UI/Root


func _ready() -> void:
	# Keep receiving server messages while paused; the world itself pauses.
	process_mode = Node.PROCESS_MODE_ALWAYS
	local_player.client_world = world
	world_view.client_world = world
	RenderingServer.global_shader_parameter_set(&"cut_mask", _cut_mask)
	RenderingServer.global_shader_parameter_set(&"cut_local", 0.0)
	_setup_world()
	interaction.client = self
	add_child(interaction)
	vitals.client = self
	add_child(vitals)
	modes.client = self
	add_child(modes)
	archer.client = self
	add_child(archer)
	item_icons.library = items
	add_child(item_icons)
	hotbar.inventory = inventory
	hotbar.library = items
	inventory_screen.inventory = inventory
	inventory_screen.library = items
	actions.client = self
	actions.connect_screen(inventory_screen)
	inventory_screen.book_requested.connect(_on_book_requested)
	book_screen.library = items
	book_screen.close_requested.connect(_on_book_closed)
	dropped_items.library = items
	dropped_items.local_player = local_player
	world_root.add_child(dropped_items)
	world_root.add_child(creatures)
	arrows.library = items
	arrows.client_world = world
	world_root.add_child(arrows)
	creatures.burst.connect(interaction.burst)
	held_view.library = items
	world_viewport.camera.add_child(held_view)
	angler.client = self
	add_child(angler)
	boats.client = self
	world_root.add_child(boats)
	helm.client = self
	add_child(helm)
	hud_clock.clock = clock
	pause_menu.clock = clock
	debug_overlay.client = self
	chat.client = self

	_ui_root.theme = UiTheme.build()
	_loading_label.text = "LOADING_WORLD"
	_loading_label.add_theme_color_override("font_color", Color.WHITE)
	_loading_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_ui_root.add_child(_loading_label)
	_ui_root.add_child(crosshair)
	_ui_root.add_child(hud_clock)
	save_notice.anchor = hud_clock
	_ui_root.add_child(save_notice)
	_ui_root.add_child(vitals.veil)
	_ui_root.add_child(modes.banner)
	_ui_root.add_child(archer.meter)
	_ui_root.add_child(helm.meter)
	_ui_root.add_child(hotbar)
	_ui_root.add_child(vitals.screen)
	_ui_root.add_child(chat)
	_ui_root.add_child(debug_overlay)
	_ui_root.add_child(debug_map)
	_ui_root.add_child(inventory_screen)
	_ui_root.add_child(book_screen)
	_ui_root.add_child(pause_menu)

	pause_menu.resume_requested.connect(resume)
	pause_menu.quit_requested.connect(quit_requested.emit)
	pause_menu.time_settings_requested.connect(_on_time_settings_requested)
	pause_menu.seasons_requested.connect(
		func(days: int) -> void: transport.send(Msg.set_seasons(days))
	)
	pause_menu.game_mode_requested.connect(
		func(mode: int) -> void: transport.send(Msg.set_game_mode(mode))
	)
	debug_map.map_requested.connect(_on_map_requested)
	view_mode.automatic = Settings.cave_first_person


## Builds the 3D scene: terrain, player, sky light, environment, weather.
func _setup_world() -> void:
	world_viewport.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world_viewport)
	move_child(world_viewport, 0)
	world_viewport.first_person_fov = Settings.first_person_fov
	var root := world_viewport.world_root()
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	root.add_child(world_environment)
	creatures.light_parent = root
	creatures.sky_at = world_view.sky_at
	creatures.player = local_player
	root.add_child(sun)
	root.add_child(world_root)
	world_root.add_child(world_view)
	world_root.add_child(clouds)
	world_root.add_child(player_model)
	weather_effects.client_world = world
	weather_effects.local_player = local_player
	weather_effects.clock = clock
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
	_apply_quality()
	Settings.changed.connect(_on_settings_changed)


func _on_settings_changed(key: StringName) -> void:
	if key in [&"graphics_quality", &"extreme"]:
		_apply_quality()
	elif key == &"cave_first_person":
		view_mode.set_automatic(Settings.cave_first_person)
	elif key == &"guide_book" and not Settings.guide_book:
		book_in_hand = false
		book_screen.close()
	elif key == &"first_person_fov":
		world_viewport.first_person_fov = Settings.first_person_fov


## The graphics quality, the props' detail reach and the savings
## (Settings.extreme sets them all to their most).
func _apply_quality() -> void:
	var quality := Settings.effective_quality()
	lighting.apply_quality(quality)
	var detail := WorldView3D.DETAIL_BY_QUALITY[quality]
	world_view.set_detail(Settings.EXTREME_DETAIL if Settings.extreme else detail)
	world_view.set_thrifty(not Settings.extreme)
	creatures.thrifty = not Settings.extreme


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
		radius = maxi(radius, Settings.effective_far_view())
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
		ClientMessages.handle(self, message)
	if not get_tree().paused:
		clock.advance(delta)
		_update_view_mode(delta)
		_update_orbit(delta)
		local_player.step(delta)
		_update_view(delta)
		player_model.set_armor(_worn())
		held_view.set_armor(_worn())
		_update_held(delta)
	hotbar.book_shown = Settings.guide_book
	hotbar.book_selected = book_in_hand
	inventory_screen.book_shown = Settings.guide_book
	inventory_screen.book_selected = book_in_hand
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
		_drag_button = MOUSE_BUTTON_NONE
	elif wanted < first_person and first_person == 1.0:
		# Leaving: the top-down camera faces where the player looked.
		var pitch_degrees := rad_to_deg(world_viewport.pitch)
		world_viewport.set_orbit_degrees(rad_to_deg(_look_yaw), pitch_degrees)
	first_person = move_toward(first_person, wanted, delta / DIVE_TIME)
	if dive_hold >= 0.0:
		first_person = dive_hold
	var captured := view_mode.first_person and not screen_open()
	var mouse := Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE
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
			var scale := world_viewport.look_scale() * Settings.mouse_sensitivity * delta
			_look(-stick.x * STICK_LOOK_SPEED.x * scale, -stick.y * STICK_LOOK_SPEED.y * scale)
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
	elif covered:
		var yaw := world_viewport.current_yaw
		var low := Render3D.world_px_to_local(feet, local_player.height + LANTERN_UNDER_COVER)
		low += Vector3(sin(yaw), 0.0, cos(yaw)) * LANTERN_TOWARDS_CAMERA
		player_model.lantern_override = root * low
	player_model.set_fade(smoothstep(0.55, 0.85, first_person))
	# Held in first person, the zoom narrows the view (not over a screen).
	var zooming := (
		first_person >= 1.0
		and Input.is_action_pressed(InputBindings.ZOOM_VIEW)
		and not screen_open()
		and not get_tree().paused
	)
	world_viewport.zoom_towards(1.0 if zooming else 0.0, delta)
	player_model.animate(
		Render3D.world_px_to_local(feet, local_player.height),
		local_player.heading,
		local_player.speed,
		not local_player.body.on_ground,
		delta
	)
	player_model.swimming = local_player.body.in_liquid and not local_player.body.on_ground
	var tile := local_player.current_tile()
	lighting.sky_here = world_view.sky_of_body(tile, local_player.height)
	player_model.set_sky_light(lighting.sky_seen)
	if local_player.body.in_liquid and not _was_in_liquid:
		interaction.splash(Voxels.is_lava(local_player.body.liquid))
	_was_in_liquid = local_player.body.in_liquid
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
	world_view.focus_tile = local_player.position / GameConst.TILE_SIZE
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
	# Beyond the haze nothing shows: what the top-down view loaded stays
	# loaded, hidden.
	world_view.set_far_reach((Settings.effective_far_view() + 1.0) * GameConst.CHUNK_SIZE)
	creatures.zoomed_out = first_person < 0.5 and world_viewport.world_zoom <= 2
	creatures.eye = eye if first_person > 0.5 else Vector3.INF
	var ground := world_viewport.ground_size()
	world_view.set_lod(WorldView3D.lod_for_view(ground, world_view.detail))
	var center := Vector2(_camera_local.x, _camera_local.z)
	world_view.set_view_area(center, ground * 0.5, world_viewport.current_yaw)
	_update_view_distance()


## Under cover (a cave, a tunnel, a roof), cuts the world above the
## player's head so the view shows where they are (under a roof, only over
## the building: CutRegion).
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
	shown_below_row = cut_row if cut_height < 100000.0 else ChunkData.HEIGHT
	_update_cut_region(tile, ground)
	var cutting := cut_height < 100000.0
	world_view.set_view(cut_row, covered or first_person > 0.0, cutting, cut_region)
	RenderingServer.global_shader_parameter_set(&"cut_height", cut_height)
	var to_local := world_root.global_transform.affine_inverse()
	RenderingServer.global_shader_parameter_set(&"world_to_local", Projection(to_local))
	lighting.underground = underground
	weather_effects.underground = underground


## Works out where the cut reaches when the player stands on another tile
## or level or the world changed (underground: everywhere), and hands its
## mask to the shaders.
func _update_cut_region(tile: Vector2i, ground: float) -> void:
	if not covered:
		_cut_key = []
		return
	var key := [tile, floori(ground + 0.01), world.revision, underground]
	if key == _cut_key:
		return
	_cut_key = key
	var region := CutRegion.new() if underground else CutRegion.around(world, tile, ground)
	if region.same_as(cut_region):
		return
	cut_region = region
	_cut_mask.update(region.image())
	RenderingServer.global_shader_parameter_set(&"cut_mask_origin", Vector2(region.origin))
	RenderingServer.global_shader_parameter_set(&"cut_local", 0.0 if region.everywhere else 1.0)


## True once the player has spawned and stands on loaded ground.
func is_ready_to_play() -> bool:
	return joined and not local_player.is_landing()


## True once everything received is on screen (used for screenshots).
func is_view_complete() -> bool:
	return is_ready_to_play() and world_view.is_up_to_date()


func pause() -> void:
	debug_map.close()
	inventory_screen.close()
	book_screen.close()
	chat.close()
	interaction.stop()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if joined:
		transport.send(Msg.save_request())
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
		_drag_button = MOUSE_BUTTON_NONE
		return
	if vitals.passed_out and not event.is_action_pressed(InputBindings.PAUSE):
		return
	if event.is_action_pressed(InputBindings.TOGGLE_VIEW):
		view_mode.toggle()
		get_viewport().set_input_as_handled()
		return
	if (not modes.watching and _handle_block_input(event)) or _handle_item_input(event):
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
	elif not modes.debug_key(event):
		return
	get_viewport().set_input_as_handled()


## Breaking (left button held, right trigger), placing (right click, left
## trigger), using what is aimed at (E, B) and, in first person, taking the
## block aimed at in hand (the middle click). Returns true when the event
## was used.
func _handle_block_input(event: InputEvent) -> bool:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		interaction.pad_aiming = true
	elif event is InputEventMouseMotion:
		interaction.pad_aiming = false
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		interaction.breaking = button.pressed
		interaction.pad_aiming = false
		return true
	if button != null and button.button_index == MOUSE_BUTTON_RIGHT and view_mode.first_person:
		if button.pressed:
			interaction.place()
		return true
	if button != null and button.button_index == MOUSE_BUTTON_MIDDLE and view_mode.first_person:
		if button.pressed:
			interaction.pick_block()
		return true
	if event.is_action_pressed(InputBindings.BREAK):
		interaction.breaking = true
		return true
	if event.is_action_released(InputBindings.BREAK):
		interaction.breaking = false
		return true
	if event.is_action_pressed(InputBindings.PLACE):
		interaction.place()
		return true
	if event.is_action_pressed(InputBindings.USE):
		interaction.use_target()
		return true
	return false


## The hotbar (wheel, 1-9, shoulders), the inventory (Tab) and throwing
## (Q, with Ctrl the whole stack). The wheel zooms with its button held
## down (top-down view) or with Ctrl (InputBindings.wheel_zooms). Returns
## true when the event was used.
func _handle_item_input(event: InputEvent) -> bool:
	var button := event as InputEventMouseButton
	if (
		button != null
		and button.pressed
		and button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]
	):
		var up := button.button_index == MOUSE_BUTTON_WHEEL_UP
		if InputBindings.wheel_zooms(button, view_mode.first_person):
			if _drag_button == MOUSE_BUTTON_MIDDLE and not _dragging:
				# The wheel button was held to zoom: that press does not
				# turn the camera when the mouse slips a little.
				_drag_button = MOUSE_BUTTON_NONE
			var zoom := world_viewport.world_zoom + (1 if up else -1)
			Settings.set_world_zoom(clampi(zoom, 1, Settings.MAX_WORLD_ZOOM))
		elif not modes.watching:
			_cycle_hand(-1 if up else 1)
		return true
	if modes.watching:
		return false
	if event.is_action_pressed(InputBindings.HOTBAR_NEXT):
		_cycle_hand(1)
		return true
	if event.is_action_pressed(InputBindings.HOTBAR_PREVIOUS):
		_cycle_hand(-1)
		return true
	for i in Inventory.HOTBAR:
		if event.is_action_pressed(InputBindings.HOTBAR_SLOTS[i]):
			select_hand(i)
			return true
	if event.is_action_pressed(InputBindings.HOTBAR_BOOK) and Settings.guide_book:
		if book_in_hand:
			open_book()
		else:
			select_hand(BOOK_SLOT)
		return true
	if event.is_action_pressed(InputBindings.INVENTORY):
		actions.open_inventory()
		return true
	if event.is_action_pressed(InputBindings.DROP_ITEM):
		if book_in_hand:
			return true
		var key := event as InputEventKey
		var whole := key != null and key.ctrl_pressed
		if inventory.held() != Items.Id.NONE:
			inventory.take(inventory.selected, inventory.counts[inventory.selected] if whole else 1)
			transport.send(Msg.item_drop(inventory.selected, whole))
		return true
	return false


## The player holds the right button (or the left trigger) with food in
## hand, free to act: they eat (VitalsView).
func wants_to_eat() -> bool:
	return Items.is_food(held_item()) and wants_to_use() and not interaction.tends_here()


## The player holds the right button (or the left trigger), free to act,
## not turning the camera: eating, drawing a bow.
func wants_to_use() -> bool:
	if not local_player.controls_enabled or vitals.passed_out or get_tree().paused:
		return false
	if modes.watching:
		return false
	if Input.is_action_pressed(InputBindings.PLACE):
		return true
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not _dragging


## A right or middle drag is turning the camera.
func dragging() -> bool:
	return _dragging


## What is in hand: the player's book or the selected hotbar slot's item.
func held_item() -> int:
	return Items.Id.GUIDE_BOOK if book_in_hand else inventory.held()


## The slot in hand: a hotbar slot, or BOOK_SLOT.
func hand_slot() -> int:
	return BOOK_SLOT if book_in_hand else inventory.selected


## Takes a hotbar slot, or the player's book (BOOK_SLOT), in hand.
func select_hand(slot: int) -> void:
	book_in_hand = slot == BOOK_SLOT and Settings.guide_book
	if slot < Inventory.HOTBAR:
		select_slot(slot)


## The next slot in hand (the wheel, the shoulders), the book included.
func _cycle_hand(step: int) -> void:
	var slots := Inventory.HOTBAR + (1 if Settings.guide_book else 0)
	select_hand(posmod(hand_slot() + step, slots))


## Whether a screen over the world takes the keys and the mouse: the
## inventory, the book, the chat while typing.
func screen_open() -> bool:
	return inventory_screen.visible or book_screen.visible or chat.typing


## The camera goes straight to the player (after a teleport).
func snap_camera() -> void:
	_needs_snap = true


## Opens the player's book (the world goes on).
func open_book() -> void:
	if not Settings.guide_book or book_screen.visible:
		return
	inventory_screen.close()
	interaction.stop()
	local_player.controls_enabled = false
	book_screen.open()


func _on_book_requested() -> void:
	open_book()


func _on_book_closed() -> void:
	local_player.controls_enabled = true


## The armor worn (its four slots, Armor.Piece order).
func _worn() -> Array[int]:
	var worn: Array[int] = []
	for piece in Armor.PIECES:
		worn.append(inventory.items[Inventory.ARMOR + piece])
	return worn


## A tool in hand just broke (worn out): said over the hotbar.
func tool_broke(tool: int) -> void:
	hotbar.announce(tr("HUD_TOOL_BROKE") % tr(Items.name_key(tool)))


## Takes a hotbar slot in hand.
func select_slot(slot: int) -> void:
	if slot != inventory.selected:
		inventory.selected = slot
		transport.send(Msg.select_slot(slot))


## A food furnace near the player melted ore and broke: said over the
## hotbar (its screen closes if it was open).
func furnace_broke(cell: Vector3i) -> void:
	var tile := Coords.tile_to_world_center(Vector2i(cell.x, cell.z))
	if local_player.position.distance_to(tile) <= FURNACE_NEWS_RANGE * GameConst.TILE_SIZE:
		hotbar.announce(tr("HUD_FURNACE_BROKE"))


## Puts what is in hand in the body's hand and, in first person, at the
## bottom right of the view with the arm (HeldView).
func _update_held(delta: float) -> void:
	var held := held_item()
	if held != _shown_held:
		_shown_held = held
		_hold(held)
	# Zooming in, the hand goes down (it would fill the narrowed view); a
	# spectator has none.
	held_view.visible = (
		first_person >= 1.0 and world_viewport.zoom < 0.98 and not local_player.ghost
	)
	if held_view.visible:
		held_view.animate(
			delta,
			player_model,
			local_player.speed,
			vitals.eating,
			vitals.eat_time,
			world_viewport.zoom,
			lighting.sky_seen,
			player_model.hurt
		)


## Gives the body's hand and the first-person view what is in hand: tools,
## swords, the bow and the fishing rod by their grip (ToolModels), anything
## else resting in the hand.
func _hold(held: int) -> void:
	held_view.show_item(held)
	if held == Items.Id.NONE:
		player_model.hold(null, 0.0)
	elif held == Items.Id.BOW:
		var stages: Array[Mesh] = []
		for stage in ToolModels.DRAW_STAGES:
			stages.append(items.held_mesh(held, stage))
		player_model.hold_bow(stages, ToolModels.grip(held))
	elif held == Items.Id.FISHING_ROD:
		var stages: Array[Mesh] = []
		for stage in ToolModels.ROD_STAGES:
			stages.append(items.held_mesh(held, stage))
		player_model.hold_rod(stages, ToolModels.grip(held))
	elif ToolModels.has(held):
		var sword := Items.tool_of(held) == Items.Tool.SWORD
		player_model.hold_tool(items.held_mesh(held), ToolModels.grip(held), sword)
	else:
		player_model.hold(items.mesh(held), HELD_SIZE * items.fit(held))


## Mouse drag (right or middle button) orbits the camera around the
## player (a right click without dragging places a block); +/- zoom (and
## the wheel, see _handle_item_input). Returns true when the event was
## used.
func _handle_camera_input(event: InputEvent) -> bool:
	var button := event as InputEventMouseButton
	if button != null and button.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		if button.pressed:
			_drag_button = button.button_index
			_drag_moved = 0.0
		elif button.button_index == _drag_button:
			if _drag_button == MOUSE_BUTTON_RIGHT and not _dragging:
				interaction.place()
			_drag_button = MOUSE_BUTTON_NONE
			_dragging = false
		return true
	var motion := event as InputEventMouseMotion
	if motion != null and _drag_button != MOUSE_BUTTON_NONE and not _dragging:
		_drag_moved += motion.screen_relative.length()
		_dragging = _drag_moved > CLICK_SLOP
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
		var speed := MOUSE_LOOK_SPEED * Settings.mouse_sensitivity * world_viewport.look_scale()
		var turn := motion.screen_relative * speed
		_look(-turn.x, -turn.y)
		return true
	if event.is_action_pressed(InputBindings.CAMERA_RESET):
		_look_pitch = ENTRY_LOOK_PITCH
		return true
	return false


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
