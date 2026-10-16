class_name FurnitureUse
extends Node
## Using furniture, on the client (phase 8, step 7): a right click or E on
## a seat sits the player on it (held there at its height, PlayerModel
## seated, until they move or jump: back where they stood; the server is
## told, Msg.SIT and STAND, and may get them up: on_stand_up); on a bed asks
## to sleep in it (Msg.SLEEP; Msg.SLEEPING lays them down in it, the screen
## darkening, until they move: Msg.WAKE); on a shelf puts one of what is in
## hand on it, or takes the last thing back (Msg.SHELF), and so on a flower
## pot (a plant); on a hearth puts in the fuel in hand or puts it out with
## the watering can (Msg.STOKE); on a picture shows the next one
## (Msg.TURN_PICTURE). Processed after Helm and VitalsView
## (process_priority), whose poses it overrides.

const VEIL := Color(0.02, 0.03, 0.09)
const VEIL_SECONDS := 1.6
const VEIL_MOST := 0.88
## Where a sleeper lies: from the middle of the bed's foot towards its end,
## on its mattress (levels).
const LIE_TOWARDS_FOOT := 0.3
const MATTRESS := 9.0 / 16.0

var client: GameClient
## The seat sat on, the bed's foot slept in (Vector3i.MAX: none).
var seat := Vector3i.MAX
var bed := Vector3i.MAX
## The darkness over the screen while asleep.
var veil := ColorRect.new()
## Where the player stood before sitting or lying down (feet, height).
var _stood_at := Vector3.INF
var _dark := 0.0


func _ready() -> void:
	process_priority = 10
	veil.color = VEIL
	veil.modulate.a = 0.0
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)


## Whether a voxel is used this way (BlockInteraction.usable_here) with
## `held` in hand (the watering can fills at a bathtub, not sits in it).
static func usable(voxel: int, held := Items.Id.NONE) -> bool:
	var block := Voxels.block_of(voxel)
	if held == Items.Id.WATERING_CAN and Watering.fills_from(voxel):
		return false
	return (
		Furniture.is_seat(block)
		or Furniture.is_bed(block)
		or Shelves.slots_of(block) > 0
		or Hearths.is_hearth(block)
		or Decor.is_picture(block)
	)


## Uses the furniture in `cell`. Returns whether it did.
func use(cell: Vector3i, voxel: int) -> bool:
	var block := Voxels.block_of(voxel)
	if Furniture.is_bed(block):
		client.transport.send(Msg.sleep(cell))
		return true
	if Shelves.slots_of(block) > 0:
		client.transport.send(Msg.shelf(cell, client.inventory.selected))
		client.player_model.swing()
		return true
	if Hearths.is_hearth(block):
		client.transport.send(Msg.stoke(cell, client.inventory.selected))
		client.player_model.swing()
		return true
	if Decor.is_picture(block):
		client.transport.send(Msg.turn_picture(cell))
		client.player_model.swing()
		return true
	if Furniture.is_seat(block) and seat == Vector3i.MAX and bed == Vector3i.MAX:
		_remember()
		seat = cell
		client.transport.send(Msg.sit(cell))
		client.hotbar.announce(tr("HUD_SIT_HOW"))
		return true
	return false


## The server refused the seat (another sits there): up again.
func on_stand_up() -> void:
	if seat != Vector3i.MAX:
		seat = Vector3i.MAX
		_back()


## The server lays the player down in their bed, or gets them up.
func on_sleeping(cell: Vector3i, on: bool) -> void:
	if on:
		if seat != Vector3i.MAX:
			seat = Vector3i.MAX
		else:
			_remember()
		bed = cell
		return
	if bed != Vector3i.MAX:
		bed = Vector3i.MAX
		_back()


func _process(delta: float) -> void:
	if client == null or not client.joined:
		return
	_dark = move_toward(_dark, 1.0 if bed != Vector3i.MAX else 0.0, delta / VEIL_SECONDS)
	veil.modulate.a = _dark * VEIL_MOST
	if seat == Vector3i.MAX and bed == Vector3i.MAX:
		return
	var player := client.local_player
	var world := client.world
	var resting_at := seat if seat != Vector3i.MAX else bed
	var block := Voxels.block_of(world.voxel_at(resting_at))
	if seat != Vector3i.MAX and not Furniture.is_seat(block):
		_stand()
		return
	player.aboard = true
	var front := ObjectShapes.front_of(block)
	var middle := Vector2(resting_at.x + 0.5, resting_at.z + 0.5)
	var level := float(resting_at.y - GameConst.SEA_LEVEL)
	if seat != Vector3i.MAX:
		level += Furniture.seat_height(block)
		client.player_model.seated = true
		client.player_model.legs_out = client.first_person < 0.5
	else:
		middle += Vector2(front) * LIE_TOWARDS_FOOT
		level += MATTRESS
		client.player_model.set_down(1.0)
	player.body.place(middle * GameConst.TILE_SIZE, level)
	player.body.needs_landing = false
	player.view_height = level
	if front != Vector2i.ZERO and client.first_person < 1.0:
		player.heading = Vector2(front)
	if _wants_up():
		if seat != Vector3i.MAX:
			_stand()
		else:
			client.transport.send(Msg.wake())


## Whether the player moves or jumps (they get up).
func _wants_up() -> bool:
	if client.screen_open() or not client.local_player.controls_enabled:
		return false
	var moving := Input.get_vector(
		InputBindings.MOVE_LEFT,
		InputBindings.MOVE_RIGHT,
		InputBindings.MOVE_UP,
		InputBindings.MOVE_DOWN
	)
	return moving != Vector2.ZERO or Input.is_action_just_pressed(InputBindings.JUMP)


func _remember() -> void:
	var body := client.local_player.body
	_stood_at = Vector3(body.feet.x, body.height, body.feet.y)


func _stand() -> void:
	seat = Vector3i.MAX
	client.transport.send(Msg.stand())
	_back()


## Back where the player stood before sitting or lying down.
func _back() -> void:
	var player := client.local_player
	player.aboard = false
	client.player_model.seated = false
	if _stood_at != Vector3.INF:
		player.body.place(Vector2(_stood_at.x, _stood_at.z), _stood_at.y)
		player.view_height = _stood_at.y
	_stood_at = Vector3.INF
