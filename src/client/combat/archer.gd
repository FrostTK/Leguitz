class_name Archer
extends Node
## Drawing and shooting a bow, on the client: with a bow in hand and arrows
## in the slots (none needed in creative), holding the right button (the
## left trigger) draws it, FULL_DRAW seconds to the full; letting go shoots
## (Msg.SHOOT, the server decides; turning the camera instead lets the
## string go without a shot). In first person the arrow flies along the
## crosshair, with a gamepad ahead, from above to the point aimed at (the
## arc that lands there, if it reaches). A small gauge shows the draw over
## the player's head (under the crosshair in first person); the arms rise.

const FULL_DRAW := 1.0
## Drawn less than this, letting go shoots nothing.
const MIN_DRAW := 0.15
## The gauge (UI units), and how high over the feet it shows (local
## units).
const GAUGE := Vector2(18.0, 3.0)
const OVER_HEAD := 2.2
## With a gamepad, arrows leave ahead and this much up.
const PAD_LIFT := 0.12

var client: GameClient
## Draws the gauge (added to the UI by GameClient).
var meter := Control.new()
## Seconds the bow has been drawn (0: not drawn).
var drawn := 0.0


func _ready() -> void:
	meter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.draw.connect(_draw_meter)


## How far the bow is drawn (0..1).
func power() -> float:
	return clampf(drawn / FULL_DRAW, 0.0, 1.0)


## The direction an arrow leaves in (local units) at `speed`, from the
## chest `start`, to land at `goal` (the low arc; 45 degrees out of reach).
static func ballistic(start: Vector3, goal: Vector3, speed: float) -> Vector3:
	var flat := Vector2(goal.x - start.x, goal.z - start.z)
	var distance := flat.length()
	if distance < 0.1:
		return Vector3.DOWN
	var rise := goal.y - start.y
	var gravity := Archery.GRAVITY
	var square := speed * speed
	var under := square * square - gravity * (gravity * distance * distance + 2.0 * rise * square)
	var angle := PI * 0.25
	if under >= 0.0:
		angle = atan((square - sqrt(under)) / (gravity * distance))
	var across := flat / distance
	return Vector3(across.x * cos(angle), sin(angle), across.y * cos(angle))


## The bow in hand, the button held and arrows left; not aimed at what the
## right click uses (a chest, a gate...: BlockInteraction.usable_here).
func _may_draw() -> bool:
	return (
		client.held_item() == Items.Id.BOW
		and client.wants_to_use()
		and _has_arrows()
		and not client.interaction.usable_here()
	)


func _process(delta: float) -> void:
	if client == null or not client.joined:
		return
	if client.dragging():
		drawn = 0.0
	elif _may_draw():
		drawn += delta
	elif drawn > 0.0:
		if drawn >= MIN_DRAW:
			_shoot(power())
		drawn = 0.0
	client.player_model.aiming = smoothstep(0.0, 0.25, drawn)
	meter.queue_redraw()


func _has_arrows() -> bool:
	return client.modes.creative() or Archery.arrow_slot(client.inventory) >= 0


func _shoot(strength: float) -> void:
	var slot := client.inventory.selected
	client.transport.send(Msg.shoot(slot, _direction(strength), strength))
	if not client.modes.creative():
		var ammo := Archery.arrow_slot(client.inventory)
		if ammo >= 0:
			client.inventory.take(ammo, 1)
	client.player_model.swing()


## Where the arrow goes (see the class).
func _direction(strength: float) -> Vector3:
	var player := client.local_player
	if client.first_person >= 1.0:
		var inverse := client.world_root.global_transform.affine_inverse()
		var camera := client.world_viewport.camera.global_transform
		return (inverse.basis * -camera.basis.z).normalized()
	var ahead := Vector3(player.heading.x, PAD_LIFT, player.heading.y).normalized()
	if client.interaction.pad_aiming:
		return ahead
	var goal := client.interaction.aim_point()
	if goal == Vector3.INF:
		return ahead
	var feet := player.position / GameConst.TILE_SIZE
	var start := Vector3(feet.x, player.height + Archery.CHEST, feet.y)
	return ballistic(start, goal, Archery.ARROW_SPEED * strength)


## The gauge: a dark track, filling up as the bow is drawn, golden when
## full.
func _draw_meter() -> void:
	if drawn <= 0.0:
		return
	var at := meter.size * 0.5 + Vector2(0.0, 12.0)
	if client.first_person < 1.0:
		var player := client.local_player
		var feet := player.position / GameConst.TILE_SIZE
		at = _screen_point(Vector3(feet.x, player.height + OVER_HEAD, feet.y))
	var rect := Rect2((at - GAUGE * 0.5).floor(), GAUGE)
	meter.draw_rect(rect.grow(1.0), UiTheme.WOOD_DARK)
	meter.draw_rect(rect, Color("2a1410"))
	var full := power() >= 1.0
	var fill := Rect2(rect.position, Vector2(roundf(rect.size.x * power()), rect.size.y))
	meter.draw_rect(fill, Color("f2c84a") if full else Color("c08a4a"))


## Where a point of the world (local units) shows on the screen (UI units).
func _screen_point(local: Vector3) -> Vector2:
	var view := client.world_viewport
	var pixel := view.camera.unproject_position(client.world_root.global_transform * local)
	var display := view.display
	return display.get_global_transform() * (pixel - Vector2(view.viewport.size) * 0.5)
