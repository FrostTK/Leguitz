class_name LocalPlayer
extends Node2D
## The player controlled on this machine. Movement is predicted locally
## (instant response) and reported to the server, which may correct it.

const TEXTURE := preload("res://assets/textures/entities/player.png")
const NORMALS := preload("res://assets/textures/entities/player_n.png")
## Walking speed in tiles per second (Stardew-like pace).
const WALK_SPEED := 5.0 * GameConst.TILE_SIZE
const SPRINT_MULTIPLIER := 1.45
## Debug "ghost" mode: flies through everything (creative flight later).
const NOCLIP_MULTIPLIER := 2.5
## Collision box (width, height) at the feet, in world pixels.
const BOX := Vector2(10.0, 6.0)
const SEND_INTERVAL := GameConst.TICK_DELTA
const SPRITE_OFFSET := Vector2(-8, -23)
const SPRITE_HEIGHT := 24.0
## Lantern radius in tiles.
const LANTERN_RADIUS := 7.0

const FRAME_BY_FACING := {
	Vector2i.DOWN: 0,
	Vector2i.LEFT: 1,
	Vector2i.RIGHT: 2,
	Vector2i.UP: 3,
}

var client_world: ClientWorld
var transport: Transport
var active := false
var noclip := false
var facing := Vector2i.DOWN
var lantern := PointLight2D.new()

var _sprite := Sprite2D.new()
var _shadow := Sprite2D.new()
var _send_timer := 0.0
var _last_sent_position := Vector2.INF
var _last_sent_facing := Vector2i.ZERO


func _ready() -> void:
	var texture := CanvasTexture.new()
	texture.diffuse_texture = TEXTURE
	texture.normal_texture = NORMALS
	for sprite: Sprite2D in [_shadow, _sprite]:
		sprite.texture = texture
		sprite.hframes = 4
		sprite.centered = false
		sprite.offset = SPRITE_OFFSET
		add_child(sprite)
	_shadow.texture = TEXTURE
	_shadow.modulate = Color(0.04, 0.06, 0.14, 0.0)
	_shadow.show_behind_parent = true

	lantern.texture = LightTextures.radial()
	lantern.texture_scale = LightTextures.scale_for(LANTERN_RADIUS)
	lantern.color = Color(1.0, 0.8, 0.52)
	lantern.height = 0.6
	lantern.position = Vector2(0, -10)
	lantern.energy = 0.0
	add_child(lantern)


func spawn_at(world_position: Vector2) -> void:
	position = world_position
	active = true


func apply_correction(world_position: Vector2) -> void:
	position = world_position
	_last_sent_position = world_position


## Sun shadow: `sun` as in the shadow shader (x slant, y length).
func set_sun_shadow(sun: Vector2, strength: float) -> void:
	_shadow.visible = strength > 0.001
	_shadow.modulate.a = strength
	_shadow.scale = Vector2(1.0, sun.y)
	_shadow.skew = atan(sun.x)
	_shadow.position = Vector2(0, 0)
	_shadow.offset = Vector2(SPRITE_OFFSET.x, -SPRITE_HEIGHT + 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputBindings.TOGGLE_NOCLIP):
		noclip = not noclip
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not active:
		return
	var input := Input.get_vector(
		InputBindings.MOVE_LEFT,
		InputBindings.MOVE_RIGHT,
		InputBindings.MOVE_UP,
		InputBindings.MOVE_DOWN
	)
	if input != Vector2.ZERO:
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
	var frame: int = FRAME_BY_FACING.get(facing, 0)
	_sprite.frame = frame
	_shadow.frame = frame
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
