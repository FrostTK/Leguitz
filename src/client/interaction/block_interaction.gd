class_name BlockInteraction
extends Node
## Aiming at the world, breaking and placing blocks (rules: Mining). The
## target is what the mouse points at in the top-down view, what the
## crosshair points at in first person, and with a gamepad what is in
## front of the player. Holding the break button cracks the target over
## its breaking time (faster with the right tool in hand, see
## Mining.break_seconds), then breaks it (a tree falls), and after a short
## pause goes on with what is aimed at next; the place button puts
## the held block against the side aimed at. Changes show at once
## (predicted) and go to the server, whose answer (Msg.BLOCK_CHANGED) has
## the last word. The block placed is the one in hand (GameClient.inventory).

## Seconds between two chips flying off what is being broken.
const CHIP_INTERVAL := 0.16
## Gamepad: the player aims ahead and this much down (radians).
const PAD_AIM_PITCH := 0.6

var client: GameClient
## What is aimed at (null: nothing within reach).
var target: VoxelRay.Hit
## The break button is held.
var breaking := false
## Aim at what is in front of the player (gamepad) instead of the mouse.
var pad_aiming := false
## Dev: aim at this point (screen units from its center) instead of the
## mouse, and place a block once something is aimed at.
var aim_override := Vector2.INF
var place_soon := false

var _progress := 0.0
var _breaking_cell := Vector3i.MAX
## Seconds left before the next block starts breaking (Mining.BREAK_PAUSE).
var _pause := 0.0
var _chip_timer := 0.0
## Changes shown before the server confirmed them: cell -> voxel before.
var _predicted: Dictionary[Vector3i, int] = {}
var _highlight := BlockHighlight.new()
var _cracks := BlockCracks.new()
var _debris := Debris.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	client.world_root.add_child(_highlight)
	client.world_root.add_child(_cracks)
	client.world_viewport.world_root().add_child(_debris)


func _process(delta: float) -> void:
	if not client.joined or client.transport == null:
		return
	target = _aim()
	_highlight.outline(target.box if target != null else AABB())
	_update_breaking(delta)
	if place_soon and target != null:
		place_soon = false
		place()


## Puts the block in hand against the side of the target (the player's
## book in hand opens instead).
func place() -> void:
	if client.held_item() == Items.Id.GUIDE_BOOK:
		client.open_book()
		return
	if target == null or target.normal == Vector3i.ZERO:
		return
	var cell := target.cell + target.normal
	var player := client.local_player
	var slot := client.inventory.selected
	var voxel := Items.placed_voxel(client.inventory.items[slot])
	if (
		not Mining.can_place(voxel)
		or not Mining.is_replaceable(client.world.voxel_at(cell))
		or Mining.overlaps_body(cell, player.position, player.height)
		or Mining.reach_to(player.position, player.height, cell) > Mining.REACH
	):
		return
	_predict(cell, voxel)
	client.inventory.take(slot, 1)
	client.transport.send(Msg.block_place(cell, slot))
	client.player_model.swing()


## The server's word on a voxel (it changed, or our guess was refused).
func on_block_changed(cell: Vector3i, voxel: int) -> void:
	var guessed := _predicted.has(cell)
	_predicted.erase(cell)
	var before := client.world.voxel_at(cell)
	if before == voxel:
		return
	client.world.set_voxel(cell, voxel)
	client.world_view.voxel_changed(cell)
	if not guessed:
		_on_changed(cell, before, voxel)


## Stops breaking (the button was released, the game paused...).
func stop() -> void:
	breaking = false
	_reset_breaking()


func _update_breaking(delta: float) -> void:
	_pause = maxf(_pause - delta, 0.0)
	if not breaking or target == null:
		_reset_breaking()
		return
	if target.cell != _breaking_cell:
		_reset_breaking()
		_breaking_cell = target.cell
	client.player_model.swinging = true
	_face(target.box.get_center())
	if _pause > 0.0:
		return
	var seconds := Mining.break_seconds(target.voxel, client.held_item())
	_progress += delta / seconds
	if Voxels.is_cube(target.voxel):
		_cracks.show_on(target.box, _progress)
	_chip_timer -= delta
	if _chip_timer <= 0.0:
		_chip_timer = CHIP_INTERVAL
		_debris.throw(_world_point(target.point), BlockColors.of(target.voxel), 3, 0.05)
	if _progress >= 1.0:
		_break(target)
		_reset_breaking()
		if seconds > Mining.INSTANT_SECONDS:
			_pause = Mining.BREAK_PAUSE


func _reset_breaking() -> void:
	_progress = 0.0
	_breaking_cell = Vector3i.MAX
	_chip_timer = 0.0
	_cracks.visible = false
	if client != null:
		client.player_model.swinging = false


func _break(hit: VoxelRay.Hit) -> void:
	var center := _world_point(hit.box.get_center())
	_debris.throw(center, BlockColors.of(hit.voxel), 16, 0.3)
	_predict(hit.cell, Mining.left_after_break(hit.cell, client.world.voxel_at))
	var above := hit.cell + Vector3i.UP
	if Mining.needs_support(client.world.voxel_at(above)):
		_predict(above, Voxels.AIR)
	client.transport.send(Msg.block_break(hit.cell))


## Shows a change before the server confirms it.
func _predict(cell: Vector3i, voxel: int) -> void:
	var before := client.world.set_voxel(cell, voxel)
	if before == Voxels.UNKNOWN:
		return
	if not _predicted.has(cell):
		_predicted[cell] = before
	client.world_view.voxel_changed(cell)
	_on_changed(cell, before, voxel)


## A voxel just changed on screen: a tree that was cut falls.
func _on_changed(cell: Vector3i, before: int, after: int) -> void:
	var block := Voxels.block_of(before)
	if after == before or not ObjectShapes.is_tree(block):
		return
	var tile := Vector2i(cell.x, cell.z)
	var props := client.world_view.props
	var variant := ObjectShapes.variant_at(block, tile) % props.variant_count(block)
	var tree := FallingTree.new()
	var material := props.material.duplicate() as ShaderMaterial
	material.set_shader_parameter("use_instance_data", false)
	tree.setup(
		props.mesh(block, variant, 0),
		ChunkMesher.prop_turn(tile),
		material,
		_away_from_player(tile)
	)
	tree.position = Vector3(tile.x + 0.5, cell.y - GameConst.SEA_LEVEL, tile.y + 0.5)
	tree.debris = _debris
	tree.leaves = BlockColors.leaves_of(block)
	tree.wood = BlockColors.of(before)
	tree.height = ObjectShapes.trunk(block, variant).y / float(GameConst.TILE_SIZE) + 2.0
	client.world_root.add_child(tree)


func _away_from_player(tile: Vector2i) -> Vector2:
	var away := Coords.tile_to_world_center(tile) - client.local_player.position
	return away.normalized() if away.length() > 0.5 else client.local_player.heading


## Turns the player towards a point (local units) while they break it.
func _face(point: Vector3) -> void:
	var player := client.local_player
	var towards := Vector2(point.x, point.z) * GameConst.TILE_SIZE - player.position
	if towards.length() > 2.0:
		player.heading = towards.normalized()


## What the player aims at: a ray in local units, kept within reach.
func _aim() -> VoxelRay.Hit:
	if client.first_person > 0.0 and client.first_person < 1.0:
		return null
	var root_inverse := client.world_root.global_transform.affine_inverse()
	var eye := _eye()
	var origin := eye
	var direction: Vector3
	if client.first_person >= 1.0:
		var camera := client.world_viewport.camera.global_transform
		origin = root_inverse * camera.origin
		direction = root_inverse.basis * -camera.basis.z
	elif pad_aiming:
		var heading := client.local_player.heading
		direction = Vector3(heading.x, -tan(PAD_AIM_PITCH), heading.y)
	else:
		var pixel := _viewport_pixel()
		var camera := client.world_viewport.camera
		origin = root_inverse * camera.project_ray_origin(pixel)
		direction = root_inverse.basis * camera.project_ray_normal(pixel)
	direction = direction.normalized()
	var span := _reach_span(origin, direction, eye)
	if span.x > span.y:
		return null
	return VoxelRay.cast(
		origin + direction * span.x, direction, span.y - span.x, client.world.voxel_at
	)


## The player's eye (local units).
func _eye() -> Vector3:
	var player := client.local_player
	var feet := player.position / GameConst.TILE_SIZE
	return Vector3(feet.x, player.height + Mining.EYE_HEIGHT, feet.y)


## Where the mouse (or the dev aim) points, in pixels of the 3D view.
func _viewport_pixel() -> Vector2:
	var display := client.world_viewport.display
	var point := display.get_viewport().get_mouse_position()
	if aim_override != Vector2.INF:
		point = display.get_viewport().get_visible_rect().size / 2.0 + aim_override
	var local := display.get_global_transform().affine_inverse() * point
	return local + Vector2(client.world_viewport.viewport.size) / 2.0


## The part of a ray within reach of the eye: [enter, leave] distances
## (enter > leave: never within reach).
static func _reach_span(origin: Vector3, direction: Vector3, eye: Vector3) -> Vector2:
	var offset := origin - eye
	var b := direction.dot(offset)
	var c := offset.length_squared() - Mining.REACH * Mining.REACH
	var discriminant := b * b - c
	if discriminant < 0.0:
		return Vector2(1.0, 0.0)
	var root := sqrt(discriminant)
	return Vector2(maxf(-b - root, 0.0), -b + root)


## A local point in world space (the bits fly outside the stretched root).
func _world_point(local: Vector3) -> Vector3:
	return client.world_root.global_transform * local
