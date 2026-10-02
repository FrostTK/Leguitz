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
## In creative, everything breaks at once (a short pause between two),
## blocks placed are not used up and tools do not wear; a spectator aims
## at nothing.

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
	target = _aim() if not client.modes.watching else null
	var box := _whole_box(target)
	_highlight.outline(box, _frame_thickness(box))
	_update_breaking(delta)
	if place_soon and target != null:
		place_soon = false
		if not use_target():
			place()


## Uses what is aimed at (InputBindings.USE): opens a workbench, a chest
## or a furnace. Returns whether there was something to use.
func use_target() -> bool:
	if target == null or not Mining.opens(target.voxel):
		return false
	var block := Voxels.block_of(target.voxel)
	if ObjectShapes.is_chest(block):
		client.actions.open_chest(target.cell)
	elif ObjectShapes.furnace_kind(block) != -1:
		client.actions.open_furnace(target.cell)
	else:
		client.actions.open_workbench(target.cell)
	return true


## Puts the block in hand against the side of the target (a right click);
## the player's book in hand opens instead.
func place() -> void:
	if client.held_item() == Items.Id.GUIDE_BOOK:
		client.open_book()
		return
	if target == null:
		return
	# A small plant aimed at gives way to the block (as in Minecraft).
	var replaced := Mining.is_replaceable(target.voxel)
	if target.normal == Vector3i.ZERO and not replaced:
		return
	var cell := target.cell if replaced else target.cell + target.normal
	var player := client.local_player
	var slot := client.inventory.selected
	var voxel := Items.placed_voxel(client.inventory.items[slot])
	if (
		not Mining.can_place(voxel)
		or Mining.reach_to(player.position, player.height, cell) > Mining.REACH
	):
		return
	var front := Mining.front_towards(cell, player.position)
	var cells := Mining.placement(cell, voxel, front, client.world.voxel_at)
	if cells.is_empty():
		return
	for at: Vector3i in cells:
		if Mining.overlaps_body(at, player.position, player.height):
			return
	for at: Vector3i in cells:
		_predict(at, cells[at])
	if not client.modes.creative():
		client.inventory.take(slot, 1)
	client.transport.send(Msg.block_place(cell, slot, front))
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


## How thick the aiming frame around `box` is seen from the camera now
## (BlockHighlight.thickness_for: thin in first person).
func _frame_thickness(box: AABB) -> float:
	var view := client.world_viewport
	var camera := view.camera
	var center := client.world_root.global_transform * box.get_center()
	return BlockHighlight.thickness_for(
		camera.projection == Camera3D.PROJECTION_PERSPECTIVE,
		camera.fov,
		camera.global_position.distance_to(center),
		view.viewport.size.y,
		get_window().size.y
	)


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
	var creative := client.modes.creative()
	var seconds := Mining.break_seconds(target.voxel, client.held_item())
	_progress = 1.0 if creative else _progress + delta / seconds
	if Voxels.is_cube(target.voxel):
		_cracks.show_on(target.box, _progress)
	_chip_timer -= delta
	if _chip_timer <= 0.0:
		_chip_timer = CHIP_INTERVAL
		_debris.throw(_world_point(target.point), BlockColors.of(target.voxel), 3, 0.05)
	if _progress >= 1.0:
		_break(target)
		_reset_breaking()
		if creative or seconds > Mining.INSTANT_SECONDS:
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
	var voxel_at := client.world.voxel_at
	var cells := Mining.object_cells(hit.cell, hit.voxel, voxel_at)
	for part in cells:
		_predict(part, Mining.left_after_break(part, voxel_at))
	for part in cells:
		var above := part + Vector3i.UP
		var standing := client.world.voxel_at(above)
		if Mining.needs_support(standing):
			for piece in Mining.object_cells(above, standing, voxel_at):
				_predict(piece, Voxels.AIR)
	var slot := -1 if client.book_in_hand else client.inventory.selected
	client.transport.send(Msg.block_break(hit.cell, slot))
	_wear_tool(slot, hit.voxel)


## The tool in hand wears when it breaks something (as the server will
## say); worn out, it breaks in a burst of bits.
func _wear_tool(slot: int, voxel: int) -> void:
	if slot < 0 or not Mining.wears(voxel) or client.modes.creative():
		return
	var tool := client.inventory.items[slot]
	if Items.durability(tool) == 0 or not client.inventory.wear_out(slot):
		return
	var head: Array = ItemModels.TOOL_HEADS[Items.tier_of(tool)]
	var heading := client.local_player.heading
	var hand := _eye() + Vector3(heading.x, -0.5, heading.y) * 0.4
	_debris.throw(_world_point(hand), Color(head[1]), 14, 0.25)
	client.tool_broke(tool)


## The frame around what is aimed at: a whole workbench, both its ends.
func _whole_box(hit: VoxelRay.Hit) -> AABB:
	if hit == null:
		return AABB()
	var box := hit.box
	if ObjectShapes.is_bench(Voxels.block_of(hit.voxel)):
		for part in Mining.object_cells(hit.cell, hit.voxel, client.world.voxel_at):
			var block := Voxels.block_of(client.world.voxel_at(part))
			box = box.merge(VoxelRay.object_box(block, part))
	return box


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
	if (
		ObjectShapes.furnace_kind(block) != -1
		and ObjectShapes.kind_of(Voxels.block_of(after)) == Tiles.Block.BROKEN_FURNACE
	):
		var middle := Vector3(cell.x + 0.5, cell.y - GameConst.SEA_LEVEL + 0.7, cell.z + 0.5)
		_debris.throw(_world_point(middle), BlockColors.of(before), 24, 0.4)
		client.furnace_broke(cell)
		return
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


## A few crumbs of `color` at the player's mouth (eating; not in first
## person: they would fly into the eye).
func crumbs(color: Color) -> void:
	if client.first_person > 0.5:
		return
	var player := client.local_player
	var feet := Render3D.world_px_to_local(player.position, player.height)
	var mouth := feet + Vector3(player.heading.x, 0.0, player.heading.y) * 0.3
	_debris.throw(_world_point(mouth + Vector3(0.0, 1.35, 0.0)), color, 3, 0.06)


## Drops flying where the player goes into water (or lava).
func splash(lava: bool) -> void:
	var player := client.local_player
	var feet := Render3D.world_px_to_local(player.position, player.height + 0.3)
	var color := Color("f06a1e") if lava else Color("a8d8f0")
	_debris.throw(_world_point(feet), color, 14, 0.35)


## A local point in world space (the bits fly outside the stretched root).
func _world_point(local: Vector3) -> Vector3:
	return client.world_root.global_transform * local
