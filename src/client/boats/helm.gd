class_name Helm
extends Node
## Aboard a boat, on the client. The local player is aboard when their boat
## (BoatsView.mine: Msg.BOAT names them its pilot or on a place): the body
## sits there (LocalPlayer.aboard, PlayerModel.seated), facing the bow
## top-down. The pilot steers: the movement keys forward and back give the
## throttle, left and right the helm, sprint full throttle (the engine
## running); the boat moves at once (BoatBody) and the server is told
## (Msg.BOAT_STEER every SEND_INTERVAL); without the engine running they row.
## Jump leaves it (Msg.LEAVE_BOAT: the server finds a bank). A gauge over
## the pilot's head (under the crosshair in first person) tells the coal:
## the one burning and how many are left, or that they row.

const SEND_INTERVAL := GameConst.TICK_DELTA
## The gauge (UI units), and how high over the feet it shows (local units).
const GAUGE := Vector2(24.0, 3.0)
const OVER_HEAD := 2.3
const COAL := Color("e8792a")
const TRACK := Color("2a1410")

var client: GameClient
## Draws the gauge (added to the UI by GameClient).
var meter := Control.new()

var _send := 0.0
var _was_aboard := false


func _ready() -> void:
	meter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.draw.connect(_draw_meter)


## The boat the local player is aboard (null: none).
func boat() -> Boat:
	return client.boats.mine() if client != null else null


func _process(delta: float) -> void:
	if client == null or not client.joined:
		return
	var aboard := boat()
	var player := client.local_player
	player.aboard = aboard != null
	client.player_model.seated = aboard != null
	client.player_model.legs_out = client.first_person < 0.5
	client.player_model.rowing = false
	meter.queue_redraw()
	if aboard == null:
		_was_aboard = false
		return
	if not _was_aboard:
		_was_aboard = true
		client.hotbar.announce(tr("HUD_BOAT_ABOARD_HOW"))
	var me := client.player_id
	var place := -1
	for seat: int in aboard.seats:
		if aboard.seats[seat] == me:
			place = seat
	var free := not client.screen_open() and player.controls_enabled
	if aboard.pilot == me:
		_steer(aboard, delta, free)
	var seat := aboard.seat(place)
	player.body.place(Vector2(seat.x, seat.z) * GameConst.TILE_SIZE, seat.y)
	player.body.needs_landing = false
	player.view_height = seat.y
	if client.first_person < 1.0:
		player.heading = aboard.forward()
	if free and Input.is_action_just_pressed(InputBindings.JUMP):
		client.transport.send(Msg.leave_boat())


## The pilot's keys move the boat at once; the server is told.
func _steer(aboard: Boat, delta: float, free: bool) -> void:
	var throttle := 0.0
	var steer := 0.0
	var full := false
	if free:
		throttle = Input.get_axis(InputBindings.MOVE_DOWN, InputBindings.MOVE_UP)
		steer = Input.get_axis(InputBindings.MOVE_LEFT, InputBindings.MOVE_RIGHT)
		full = Input.is_action_pressed(InputBindings.SPRINT)
	aboard.throttle = throttle
	aboard.full = full
	BoatBody.step(aboard, throttle, steer, full, minf(delta, 0.1), client.world.voxel_at)
	client.player_model.rowing = throttle != 0.0 and not aboard.powered()
	_send += delta
	if _send >= SEND_INTERVAL:
		_send = 0.0
		client.transport.send(Msg.boat_steer(aboard))


## The coal gauge (see the class): a dark track filling with the coal
## burning, how many more there are; an oar's words while rowing.
func _draw_meter() -> void:
	var aboard := boat()
	if aboard == null or aboard.pilot != client.player_id or client.screen_open():
		return
	var at := meter.size * 0.5 + Vector2(0.0, 14.0)
	if client.first_person < 1.0:
		var player := client.local_player
		var feet := player.position / GameConst.TILE_SIZE
		at = _screen_point(Vector3(feet.x, player.height + OVER_HEAD, feet.y))
	var font := meter.get_theme_default_font()
	var size := meter.get_theme_default_font_size()
	if not aboard.powered():
		var words := tr("HUD_BOAT_ROWING")
		var width := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		meter.draw_string_outline(
			font, at - Vector2(width * 0.5, 0.0), words, 0, -1, size, 3, TRACK
		)
		meter.draw_string(font, at - Vector2(width * 0.5, 0.0), words, 0, -1, size)
		return
	var rect := Rect2((at - GAUGE * 0.5).floor(), GAUGE)
	meter.draw_rect(rect.grow(1.0), UiTheme.WOOD_DARK)
	meter.draw_rect(rect, TRACK)
	var left := clampf(aboard.burn / Boats.COAL_SECONDS, 0.0, 1.0)
	meter.draw_rect(Rect2(rect.position, Vector2(roundf(rect.size.x * left), rect.size.y)), COAL)
	var count := "x%d" % aboard.fuel()
	var spot := rect.position + Vector2(rect.size.x + 4.0, rect.size.y + 2.0)
	meter.draw_string_outline(font, spot, count, 0, -1, size, 3, TRACK)
	meter.draw_string(font, spot, count, 0, -1, size)


## Where a point of the world (local units) shows on the screen (UI units).
func _screen_point(local: Vector3) -> Vector2:
	var view := client.world_viewport
	var pixel := view.camera.unproject_position(client.world_root.global_transform * local)
	var display := view.display
	return display.get_global_transform() * (pixel - Vector2(view.viewport.size) * 0.5)
