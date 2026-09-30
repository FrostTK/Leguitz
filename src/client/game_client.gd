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

var debug_overlay := DebugOverlay.new()
var hud_clock := HudClock.new()
var pause_menu := PauseMenu.new()
var _loading_label := Label.new()

@onready var world_view: WorldView = $WorldView
@onready var local_player: LocalPlayer = $WorldView/Entities/LocalPlayer
@onready var camera: CameraRig = $Camera
@onready var day_night: DayNightTint = $DayNight
@onready var _ui_root: Control = $UI/Root


func _ready() -> void:
	# Keep receiving server messages while paused; the world itself pauses.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for node: Node in [world_view, camera, day_night]:
		node.process_mode = Node.PROCESS_MODE_PAUSABLE
	local_player.client_world = world
	day_night.clock = clock
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
	_ui_root.add_child(pause_menu)

	pause_menu.resume_requested.connect(resume)
	pause_menu.quit_requested.connect(quit_requested.emit)
	pause_menu.time_settings_requested.connect(_on_time_settings_requested)


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
	return joined and world.has_chunk(Coords.tile_to_chunk(local_player.current_tile()))


func pause() -> void:
	get_tree().paused = true
	pause_menu.open()


func resume() -> void:
	pause_menu.close()
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputBindings.PAUSE) and joined and not get_tree().paused:
		pause()
		get_viewport().set_input_as_handled()


func _handle_message(message: Dictionary) -> void:
	match message.get("t"):
		Msg.WELCOME:
			player_id = message["player_id"]
			world_info = message["world"]
			local_player.spawn_at(message["spawn"])
			camera.snap_to_target()
			joined = true
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
			local_player.apply_correction(message["pos"])
		var unknown:
			push_warning("Client: unknown message type %s" % unknown)


func _on_time_settings_requested(mode: int, value: float) -> void:
	transport.send(Msg.set_time(mode, value))
