class_name LocalPlayer
extends RefCounted
## The player controlled on this machine. Movement is predicted locally
## (instant response) and reported to the server, which may correct it.
## Logic only: PlayerView3D draws it.

## Walking speed in tiles per second (Stardew-like pace).
const WALK_SPEED := 5.0 * GameConst.TILE_SIZE
const SPRINT_MULTIPLIER := 1.45
## Debug "ghost" mode: flies through everything (creative flight later).
const NOCLIP_MULTIPLIER := 2.5
## Collision box (width, height) at the feet, in world pixels.
const BOX := Vector2(10.0, 6.0)
const SEND_INTERVAL := GameConst.TICK_DELTA

var client_world: ClientWorld
var transport: Transport
## Feet position in world pixels.
var position := Vector2.ZERO
var active := false
var noclip := false
## Direction the player looks at, on the ground (world axes).
var facing := Vector2i.DOWN
## Camera turn (radians): movement keys follow the screen, not the map.
var camera_yaw := 0.0

var _send_timer := 0.0
var _last_sent_position := Vector2.INF
var _last_sent_facing := Vector2i.ZERO


func spawn_at(world_position: Vector2) -> void:
	position = world_position
	active = true


func apply_correction(world_position: Vector2) -> void:
	position = world_position
	_last_sent_position = world_position


## Reads the movement input and moves (called every frame).
func step(delta: float) -> void:
	if not active:
		return
	var input := Input.get_vector(
		InputBindings.MOVE_LEFT,
		InputBindings.MOVE_RIGHT,
		InputBindings.MOVE_UP,
		InputBindings.MOVE_DOWN
	)
	if input != Vector2.ZERO:
		input = Render3D.screen_to_ground(input, camera_yaw)
		_update_facing(input)
		var speed := WALK_SPEED * Tiles.ground_speed(client_world.ground_at(current_tile()))
		if Input.is_action_pressed(InputBindings.SPRINT):
			speed *= SPRINT_MULTIPLIER
		# Cap the step so a frame hitch never tunnels through a tile.
		var motion := input * speed * minf(delta, 0.1)
		if noclip:
			position += motion * NOCLIP_MULTIPLIER
		else:
			position = TileCollider.move(position, motion, BOX, client_world.is_solid)
	_send_timer += delta
	if _send_timer >= SEND_INTERVAL:
		_send_timer = 0.0
		_send_state()


func current_tile() -> Vector2i:
	return Coords.world_to_tile(position - Vector2(0, 1))


func _update_facing(input: Vector2) -> void:
	if absf(input.x) > absf(input.y):
		facing = Vector2i.RIGHT if input.x > 0.0 else Vector2i.LEFT
	else:
		facing = Vector2i.DOWN if input.y > 0.0 else Vector2i.UP


func _send_state() -> void:
	if position == _last_sent_position and facing == _last_sent_facing:
		return
	_last_sent_position = position
	_last_sent_facing = facing
	transport.send(Msg.player_move(position, facing))
