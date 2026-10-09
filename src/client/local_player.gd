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
## Flying (creative flight, a spectator's ghost, the debug ghost mode)
## goes this many times faster than walking.
const FLY_MULTIPLIER := 2.5
## Two presses of jump this close (seconds) start or stop flying.
const DOUBLE_JUMP_SECONDS := 0.3
const SEND_INTERVAL := GameConst.TICK_DELTA
## A push fades this fast (per second).
const PUSH_DRAG := 6.0

var client_world: ClientWorld
var transport: Transport
var body := PlayerBody.new()
var active := false
## Debug ghost mode (creative): glides through everything, onto the ground.
var noclip := false
## Creative: two presses of jump start or stop flying (jump rises, sprint
## sinks; landing ends it).
var can_fly := false
## A spectator: flies through everything.
var ghost := false
## False while a screen takes the keys (the inventory): the player stands.
var controls_enabled := true
## Too hungry to run (Vitals.WEAK, told by VitalsView).
var can_sprint := true
## Walking faster (a dish's Effects.Kind.SWIFT).
var speed_bonus := 1.0
## Aboard a boat: Helm seats the body, the keys steer the boat.
var aboard := false
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
## A blow's push (world pixels per second), fading.
var _push := Vector2.ZERO
## When jump was last pressed (seconds; see DOUBLE_JUMP_SECONDS).
var _jumped_at := -INF
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
	if aboard:
		speed = 0.0
		_send_timer += delta
		if _send_timer >= SEND_INTERVAL:
			_send_timer = 0.0
			_send_state()
		return
	var input := Input.get_vector(
		InputBindings.MOVE_LEFT,
		InputBindings.MOVE_RIGHT,
		InputBindings.MOVE_UP,
		InputBindings.MOVE_DOWN
	)
	if not controls_enabled:
		input = Vector2.ZERO
	_toggle_flight()
	var flying := ghost or noclip or body.flying
	var motion := Vector2.ZERO
	if input != Vector2.ZERO:
		input = Render3D.screen_to_ground(input, camera_yaw)
		heading = input.normalized()
		_update_facing(input)
		var ground := client_world.ground_under(current_tile(), body.height)
		var speed := WALK_SPEED * Tiles.ground_speed(ground) * speed_bonus
		if flying:
			speed = WALK_SPEED * FLY_MULTIPLIER
		elif can_sprint and Input.is_action_pressed(InputBindings.SPRINT):
			speed *= SPRINT_MULTIPLIER
		if body.in_liquid and not flying:
			var lava := Voxels.is_lava(body.liquid)
			speed *= LAVA_SPEED if lava else WATER_SPEED
		# Cap the step so a frame hitch never tunnels through a tile.
		motion = input * speed * minf(delta, 0.1)
	if _push != Vector2.ZERO and not ghost and not noclip:
		motion += _push * minf(delta, 0.1)
		_push *= exp(-PUSH_DRAG * delta)
		if _push.length() < 1.0:
			_push = Vector2.ZERO
	var before := body.feet
	var up := controls_enabled and Input.is_action_pressed(InputBindings.JUMP)
	var down := controls_enabled and Input.is_action_pressed(InputBindings.SPRINT)
	var voxel_at := client_world.voxel_at
	if ghost:
		body.fly(motion, up, down, minf(delta, 0.1), voxel_at, true)
	elif noclip:
		body.glide(motion, voxel_at)
	elif body.flying:
		body.fly(motion, up, down, minf(delta, 0.1), voxel_at)
	else:
		body.step(motion, up, minf(delta, 0.1), voxel_at)
	speed = before.distance_to(body.feet) / maxf(delta, 0.001) / GameConst.TILE_SIZE
	if flying or body.on_ground or body.in_liquid or body.height < view_height:
		view_height = body.height
	_fell = maxf(_fell, body.take_fall())
	_send_timer += delta
	if _send_timer >= SEND_INTERVAL:
		_send_timer = 0.0
		_send_state()


## Creative: two presses of jump close together start or stop flying
## (out of creative, the body stops flying).
func _toggle_flight() -> void:
	if not can_fly:
		body.flying = false
		return
	if not controls_enabled or not Input.is_action_just_pressed(InputBindings.JUMP):
		return
	var now := Time.get_ticks_msec() * 0.001
	if now - _jumped_at > DOUBLE_JUMP_SECONDS:
		_jumped_at = now
		return
	_jumped_at = -INF
	body.flying = not body.flying
	if not body.flying:
		body.vertical_speed = 0.0


## A monster's blow pushes the body back (`speed`: world pixels per
## second, fading) and up (`hop`: levels per second, from the ground).
func push(speed: Vector2, hop: float) -> void:
	_push = speed
	if body.on_ground and not body.flying and not body.in_liquid:
		body.vertical_speed = hop
		body.on_ground = false


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
