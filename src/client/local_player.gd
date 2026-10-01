class_name LocalPlayer
extends RefCounted
## The player controlled on this machine. Movement is predicted locally
## (instant response) and reported to the server, which may correct it.
## Logic only: PlayerModel draws it.

## Walking speed in tiles per second (Stardew-like pace); in water and in
## lava, so much slower.
const WALK_SPEED := 5.0 * GameConst.TILE_SIZE
const WATER_SPEED := 0.6
const LAVA_SPEED := 0.4
const SPRINT_MULTIPLIER := 1.45
## Debug "ghost" mode: flies through everything (creative flight later).
const NOCLIP_MULTIPLIER := 2.5
const SEND_INTERVAL := GameConst.TICK_DELTA

var client_world: ClientWorld
var transport: Transport
var body := PlayerBody.new()
var active := false
var noclip := false
## False while a screen takes the keys (the inventory): the player stands.
var controls_enabled := true
## Too hungry to run (Vitals.WEAK, told by VitalsView).
var can_sprint := true
## Direction the player looks at, on the ground (world axes): exact, and
## rounded to the nearest side.
var heading := Vector2.DOWN
var facing := Vector2i.DOWN
## Walking speed right now, in tiles per second.
var speed := 0.0
## Camera turn (radians): movement keys follow the screen, not the map.
var camera_yaw := 0.0
## Height the camera follows: the ground the player stands on, so jumps do
## not shake the view (it still follows falls).
var view_height := 0.0

## Feet position in world pixels.
var position: Vector2:
	get:
		return body.feet
## Feet height in levels.
var height: float:
	get:
		return body.height

var _send_timer := 0.0
## How far the body fell, for the next report to the server.
var _fell := 0.0
var _last_sent_position := Vector2.INF
var _last_sent_facing := Vector2i.ZERO
var _last_sent_height := INF


func spawn_at(world_position: Vector2, at_height: float) -> void:
	body.place(world_position, at_height)
	view_height = at_height
	active = true


func apply_correction(world_position: Vector2, at_height: float) -> void:
	body.place(world_position, at_height)
	view_height = at_height
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
	if not controls_enabled:
		input = Vector2.ZERO
	var motion := Vector2.ZERO
	if input != Vector2.ZERO:
		input = Render3D.screen_to_ground(input, camera_yaw)
		heading = input.normalized()
		_update_facing(input)
		var ground := client_world.ground_under(current_tile(), body.height)
		var speed := WALK_SPEED * Tiles.ground_speed(ground)
		if can_sprint and Input.is_action_pressed(InputBindings.SPRINT):
			speed *= SPRINT_MULTIPLIER
		if body.in_liquid:
			var lava := Voxels.ground_of(body.liquid) == Tiles.Ground.LAVA
			speed *= LAVA_SPEED if lava else WATER_SPEED
		# Cap the step so a frame hitch never tunnels through a tile.
		motion = input * speed * minf(delta, 0.1)
	var before := body.feet
	if noclip:
		body.glide(motion * NOCLIP_MULTIPLIER, client_world.voxel_at)
	else:
		var jump := controls_enabled and Input.is_action_pressed(InputBindings.JUMP)
		body.step(motion, jump, minf(delta, 0.1), client_world.voxel_at)
	speed = before.distance_to(body.feet) / maxf(delta, 0.001) / GameConst.TILE_SIZE
	if body.on_ground or body.in_liquid or body.height < view_height:
		view_height = body.height
	_fell = maxf(_fell, body.take_fall())
	_send_timer += delta
	if _send_timer >= SEND_INTERVAL:
		_send_timer = 0.0
		_send_state()


## True until the ground under a new position is known.
func is_landing() -> bool:
	return body.needs_landing


func current_tile() -> Vector2i:
	return Coords.world_to_tile(position - Vector2(0, 1))


func _update_facing(input: Vector2) -> void:
	if absf(input.x) > absf(input.y):
		facing = Vector2i.RIGHT if input.x > 0.0 else Vector2i.LEFT
	else:
		facing = Vector2i.DOWN if input.y > 0.0 else Vector2i.UP


func _send_state() -> void:
	if (
		position == _last_sent_position
		and facing == _last_sent_facing
		and height == _last_sent_height
		and _fell == 0.0
	):
		return
	_last_sent_position = position
	_last_sent_facing = facing
	_last_sent_height = height
	transport.send(Msg.player_move(position, facing, height, _fell))
	_fell = 0.0
