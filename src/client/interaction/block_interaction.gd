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
## at nothing. An animal nearer than the block aimed at (within
## Combat.REACH) is aimed at instead: the break button hits it, every
## Combat.BLOW_SECONDS while held (Msg.ATTACK); the place button (or the
## use key) tends an animal (Husbandry: feeds, pets, shears, milks, a
## lead).

## Seconds between two chips flying off what is being broken.
const CHIP_INTERVAL := 0.16
## Gamepad: the player aims ahead and this much down (radians).
const PAD_AIM_PITCH := 0.6
## Drops from a watering can, bits of waste and of compost.
const WATER_COLOR := Color("8cc8ec")
const WASTE_COLOR := Color("6f8f3c")
const COMPOST_COLOR := Color("4a3424")
## Leaves rustling when something is picked.
const PICK_COLOR := Color("5e9a3a")
## How far (local units) the mouse's ray looks for what a bow aims at.
const AIM_FAR := 96.0

var client: GameClient
## What is aimed at (null: nothing within reach).
var target: VoxelRay.Hit
## The animal aimed at (-1: none; then `target` is null).
var target_creature := -1
## The break button is held.
var breaking := false
## Aim at what is in front of the player (gamepad) instead of the mouse.
var pad_aiming := false
## Dev: aim at this point (screen units from its center) instead of the
## mouse, and place a block once something is aimed at.
var aim_override := Vector2.INF
var place_soon := false

## The ray aimed along last (local units) and the part of it within reach
## ([enter, leave]; enter > leave: none): a watering can looks along it for
## water.
var _ray_origin := Vector3.ZERO
var _ray_direction := Vector3.FORWARD
var _ray_span := Vector2(1.0, 0.0)

var _progress := 0.0
var _breaking_cell := Vector3i.MAX
## Seconds left before the next block starts breaking (Mining.BREAK_PAUSE),
## and before the next blow.
var _pause := 0.0
var _blow_wait := 0.0
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
	target = null
	target_creature = -1
	if not client.modes.watching:
		target = _aim()
	var box := _whole_box(target)
	if target_creature >= 0:
		box = client.creatures.bounds_of(target_creature)
	_highlight.outline(box, _frame_thickness(box))
	_update_breaking(delta)
	if place_soon and target != null:
		place_soon = false
		if not use_target():
			place()


## Uses what is aimed at (InputBindings.USE): opens a workbench, a chest
## or a furnace, swings a gate, fills or empties a composter, picks what is
## ripe. Returns whether there was something to use.
func use_target() -> bool:
	if _tend_animal():
		return true
	if target != null and Mining.swings(target.voxel):
		_swing_gate(target.cell, target.voxel)
		return true
	if target != null and (_compost() or _pick()):
		return true
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
	if _tend_animal() or _tend() or _sow_on_water() or target == null:
		return
	var player := client.local_player
	var slot := client.inventory.selected
	var voxel := Items.placed_voxel(client.inventory.items[slot])
	# A small plant aimed at gives way to the block (as in Minecraft); a
	# torch goes into an empty bracket aimed at.
	var fills := Mining.fills(target.voxel, voxel)
	var replaced := not fills and Mining.is_replaceable(target.voxel)
	if target.normal == Vector3i.ZERO and not replaced and not fills:
		return
	var cell := target.cell if replaced or fills else target.cell + target.normal
	var face := Vector3i.UP if replaced else target.normal
	if (
		Voxels.block_of(voxel) == Tiles.Block.LANTERN
		and face == Vector3i.UP
		and Input.is_action_pressed(InputBindings.SPRINT)
	):
		# Shift: hung from the ceiling over the floor aimed at (the camera
		# never sees a ceiling's underside from above).
		var under := Mining.under_ceiling(cell, client.world.voxel_at)
		if under == Vector3i.MAX:
			return
		cell = under
		face = Vector3i.DOWN
	if (
		not Mining.can_place(voxel)
		or Mining.reach_to(player.position, player.height, cell) > Mining.REACH
	):
		return
	var front := Mining.front_towards(cell, player.position)
	if Mining.minds_the_side(voxel) and face.y == 0 and not fills:
		# Hung on the side aimed at, facing away from it.
		front = Vector2i(face.x, face.z)
	elif ObjectShapes.is_wall_mounted(Voxels.block_of(voxel)):
		return
	var cells := Mining.placement(cell, voxel, front, client.world.voxel_at, face)
	if cells.is_empty():
		return
	for at: Vector3i in cells:
		if Voxels.is_solid(cells[at]) and Mining.overlaps_body(at, player.position, player.height):
			return
	_put(cells, cell, slot, front, face)


## Shows what is placed at once, uses it up (not in creative) and tells
## the server.
func _put(cells: Dictionary, cell: Vector3i, slot: int, front: Vector2i, face: Vector3i) -> void:
	for at: Vector3i in cells:
		_predict(at, cells[at])
	if not client.modes.creative():
		client.inventory.take(slot, 1)
	client.transport.send(Msg.block_place(cell, slot, front, face))
	client.player_model.swing()


## Rice in hand is sown over the water aimed at (still, one deep: Farming
## .sowing); the aiming ray goes through water. Returns whether rice was in
## hand.
func _sow_on_water() -> bool:
	var slot := client.inventory.selected
	var voxel := Items.placed_voxel(client.inventory.items[slot])
	if client.book_in_hand or Farming.bed_of(Voxels.block_of(voxel)) != Farming.Bed.WATER:
		return false
	var water := _water_aimed()
	if water == Vector3i.MAX:
		return true
	var player := client.local_player
	var cell := water + Vector3i.UP
	var cells := Mining.placement(cell, voxel, Vector2i(0, 1), client.world.voxel_at)
	if cells.is_empty() or Mining.reach_to(player.position, player.height, cell) > Mining.REACH:
		return true
	_put(cells, cell, slot, Vector2i(0, 1), Vector3i.UP)
	return true


## Whether what is in hand would be sown where the player aims (food
## that is a seed, a carrot, a potato: sown on farmland, eaten elsewhere).
func sows_here() -> bool:
	var voxel := Items.placed_voxel(client.held_item())
	return (
		target != null
		and Farming.SOWN.has(Voxels.block_of(voxel))
		and Farming.is_farmland(target.voxel)
		and target.normal == Vector3i.UP
	)


## The hoe in hand tills what is aimed at (grass, dirt; the ground under
## the small plant aimed at), shown at once; the server decides (Msg.TILL).
func _till() -> void:
	var player := client.local_player
	var cell := target.cell
	if not Voxels.is_cube(target.voxel):
		cell += Vector3i.DOWN
	if Mining.reach_to(player.position, player.height, cell) > Mining.REACH:
		return
	var voxel_at := client.world.voxel_at
	var cells := Farming.tilled(cell, voxel_at)
	if cells.is_empty():
		return
	var slot := client.inventory.selected
	_wear_tool(slot, voxel_at.call(cell))
	for at: Vector3i in cells:
		_predict(at, cells[at])
	client.transport.send(Msg.till(cell, slot))
	client.player_model.swing()


## What is in hand tends the farm rather than being placed (a right
## click): a watering can, a hoe, compost; waste goes into the composter
## aimed at, a ready one gives its compost. Returns whether it did (or was
## the tool for it).
func _tend() -> bool:
	var held := client.held_item()
	if held == Items.Id.WATERING_CAN:
		_use_can()
		return true
	if target == null:
		return false
	if _pick():
		return true
	if Items.tool_of(held) == Items.Tool.HOE:
		_till()
		return true
	if held == Items.Id.COMPOST:
		_spread_compost()
		return true
	return _compost()


## Whether a right click would tend what is aimed at rather than place or
## eat what is in hand: an animal, sow it on farmland, put it in a
## composter, pick what is ripe.
func tends_here() -> bool:
	if sows_here() or _animal_aimed():
		return true
	return (
		target != null
		and (not _composting(target.voxel).is_empty() or _pickable(target.cell, target.voxel))
	)


## An animal is aimed at (not a monster), and no bow is in hand (the bow
## shoots it).
func _animal_aimed() -> bool:
	return (
		target_creature >= 0
		and client.held_item() != Items.Id.BOW
		and client.creatures.is_animal(target_creature)
	)


## The animal aimed at is tended with what is in hand (the server decides
## what it does and tells how it went: Husbandry.tend). Returns whether
## there was one.
func _tend_animal() -> bool:
	if not _animal_aimed():
		return false
	var slot := -1 if client.book_in_hand else client.inventory.selected
	client.transport.send(Msg.tend_animal(target_creature, slot))
	client.player_model.swing()
	return true


## Whether something ripe within reach is picked there (Picking).
func _pickable(cell: Vector3i, voxel: int) -> bool:
	var player := client.local_player
	return (
		Picking.can_pick(voxel)
		and Mining.reach_to(player.position, player.height, cell) <= Mining.REACH
	)


## The ripe plant or the fruit tree aimed at is picked: shown at once as it
## goes back (Picking.PICKED); the server puts what it gives in the bag
## (Msg.PICK). Returns whether it did.
func _pick() -> bool:
	if not _pickable(target.cell, target.voxel):
		return false
	var cell := target.cell
	_predict(cell, Voxels.of_block(Picking.PICKED[Voxels.block_of(target.voxel)]))
	client.transport.send(Msg.pick(cell))
	var up := 2.0 if ObjectShapes.is_tree(Voxels.block_of(target.voxel)) else 0.6
	_debris.throw(_world_point(_cell_middle(cell, up)), PICK_COLOR, 10, 0.25)
	client.player_model.swing()
	return true


## The watering can in hand: filled at the water (or the sink) aimed at,
## else waters the farmland aimed at (under the crop aimed at) if it holds
## water (shown at once; the server decides, Msg.FILL_CAN, Msg.WATER).
func _use_can() -> void:
	var player := client.local_player
	var slot := client.inventory.selected
	var source := _water_aimed()
	if source == Vector3i.MAX and target != null and Watering.fills_from(target.voxel):
		source = target.cell
	if source != Vector3i.MAX:
		client.inventory.wear[slot] = Items.CAN_WATER
		client.transport.send(Msg.fill_can(source, slot))
		_debris.throw(_world_point(_cell_middle(source, 0.6)), WATER_COLOR, 10, 0.25)
		client.player_model.swing()
		return
	if target == null:
		return
	var bed := Watering.bed_of(target.cell, client.world.voxel_at)
	if bed == Vector3i.MAX or Mining.reach_to(player.position, player.height, bed) > Mining.REACH:
		return
	var creative := client.modes.creative()
	if client.inventory.wear[slot] <= 0 and not creative:
		client.hotbar.announce(tr("HUD_CAN_EMPTY"))
		return
	if not creative:
		client.inventory.wear[slot] -= 1
	_predict(bed, Voxels.of_ground(Tiles.Ground.FARMLAND_WET))
	client.transport.send(Msg.water(bed, slot))
	_debris.throw(_world_point(_cell_middle(bed, 1.4)), WATER_COLOR, 12, 0.12)
	client.player_model.swing()


## The first water along the aiming ray within reach (Vector3i.MAX: none):
## the can is filled there (the ray goes through water to aim at blocks).
func _water_aimed() -> Vector3i:
	if _ray_span.x > _ray_span.y:
		return Vector3i.MAX
	var watery := func(cell: Vector3i) -> int:
		var voxel := _shown_voxel(cell)
		return Voxels.of_block(Tiles.Block.STONE) if Voxels.is_water(voxel) else voxel
	var start := _ray_origin + _ray_direction * _ray_span.x
	var hit := VoxelRay.cast(start, _ray_direction, _ray_span.y - _ray_span.x, watery)
	if hit == null or not Voxels.is_water(_shown_voxel(hit.cell)):
		return Vector3i.MAX
	return hit.cell


## What using the composter aimed at with what is in hand does
## (Composting.use; {}: nothing, or no composter within reach).
func _composting(voxel: int) -> Dictionary:
	var block := Voxels.block_of(voxel)
	if not Composting.is_composter(block):
		return {}
	var player := client.local_player
	if Mining.reach_to(player.position, player.height, target.cell) > Mining.REACH:
		return {}
	var held := Items.Id.NONE if client.book_in_hand else client.held_item()
	return Composting.use(block, held)


## The composter aimed at takes the waste in hand, or gives its compost
## when ready (shown at once; the server decides, Msg.COMPOST). Returns
## whether it did.
func _compost() -> bool:
	var done := _composting(target.voxel)
	if done.is_empty():
		return false
	var slot := client.inventory.selected
	var cell := target.cell
	_predict(cell, Voxels.of_block(done["block"]))
	if done.get("used", false) and not client.modes.creative():
		client.inventory.take(slot, 1)
	var color := WASTE_COLOR if done.get("used", false) else COMPOST_COLOR
	_debris.throw(_world_point(_cell_middle(cell, 0.9)), color, 8, 0.15)
	client.transport.send(Msg.compost(cell, slot))
	client.player_model.swing()
	return true


## The compost in hand spread on the crop or the sapling aimed at (the
## crop on the farmland aimed at): a crop shows its next stage at once, a
## tree waits for the server (Msg.SPREAD_COMPOST).
func _spread_compost() -> void:
	var player := client.local_player
	var cell := target.cell
	if Farming.is_farmland(target.voxel):
		cell += Vector3i.UP
	var voxel := client.world.voxel_at(cell)
	if not Composting.takes_compost(Voxels.block_of(voxel)):
		return
	if Mining.reach_to(player.position, player.height, cell) > Mining.REACH:
		return
	var slot := client.inventory.selected
	var guess := Composting.guess_spread(voxel)
	if guess != Voxels.AIR:
		_predict(cell, guess)
	if not client.modes.creative():
		client.inventory.take(slot, 1)
	client.transport.send(Msg.spread_compost(cell, slot))
	_debris.throw(_world_point(_cell_middle(cell, 0.5)), COMPOST_COLOR, 12, 0.2)
	client.player_model.swing()


## The middle of a cell's tile, `up` levels over its floor (local units).
static func _cell_middle(cell: Vector3i, up: float) -> Vector3:
	return Vector3(cell.x + 0.5, cell.y - GameConst.SEA_LEVEL + up, cell.z + 0.5)


## A gate aimed at swings open or shut (shown at once; the server
## decides, Msg.SWING_GATE).
func _swing_gate(cell: Vector3i, voxel: int) -> void:
	var player := client.local_player
	if Mining.reach_to(player.position, player.height, cell) > Mining.REACH:
		return
	var cells := Mining.swung_cells(cell, voxel, client.world.voxel_at)
	for at: Vector3i in cells:
		if Voxels.is_solid(cells[at]) and Mining.overlaps_body(at, player.position, player.height):
			return
	for at: Vector3i in cells:
		_predict(at, cells[at])
	client.transport.send(Msg.swing_gate(cell))
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
	_blow_wait = maxf(_blow_wait - delta, 0.0)
	if target_creature >= 0:
		_reset_breaking()
		if breaking:
			_hit_creature()
		return
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
		_predict(part, Voxels.AIR)
	for part in cells:
		var above := part + Vector3i.UP
		var standing := client.world.voxel_at(above)
		if Mining.needs_support(standing):
			for piece in Mining.object_cells(above, standing, voxel_at):
				_predict(piece, Voxels.AIR)
	var slot := -1 if client.book_in_hand else client.inventory.selected
	client.transport.send(Msg.block_break(hit.cell, slot))
	_wear_tool(slot, hit.voxel)


## The break button held on an animal: a blow every Combat.BLOW_SECONDS
## (it reddens at once; the server says the rest).
func _hit_creature() -> void:
	client.player_model.swinging = true
	_face(client.creatures.bounds_of(target_creature).get_center())
	if _blow_wait > 0.0:
		return
	_blow_wait = Combat.BLOW_SECONDS
	var slot := -1 if client.book_in_hand else client.inventory.selected
	client.transport.send(Msg.attack(target_creature, slot))
	client.creatures.hurt(target_creature)


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


## The frame around what is aimed at: a whole wide object (a workbench, a
## big gate), both its ends.
func _whole_box(hit: VoxelRay.Hit) -> AABB:
	if hit == null:
		return AABB()
	var box := hit.box
	if ObjectShapes.wide_kind(Voxels.block_of(hit.voxel)) != -1:
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
	if not fells(before, after):
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


## Whether a voxel changing shows a tree falling: a tree gone (not one
## turning into another: a young one grown, a fruit tree bearing its fruit
## or picked).
static func fells(before: int, after: int) -> bool:
	return (
		after != before
		and ObjectShapes.is_tree(Voxels.block_of(before))
		and not ObjectShapes.is_tree(Voxels.block_of(after))
	)


func _away_from_player(tile: Vector2i) -> Vector2:
	var away := Coords.tile_to_world_center(tile) - client.local_player.position
	return away.normalized() if away.length() > 0.5 else client.local_player.heading


## Turns the player towards a point (local units) while they break it.
func _face(point: Vector3) -> void:
	var player := client.local_player
	var towards := Vector2(point.x, point.z) * GameConst.TILE_SIZE - player.position
	if towards.length() > 2.0:
		player.heading = towards.normalized()


## Where the mouse points in the world (local units), far beyond reach (a
## bow aims there): the creature or the block its ray meets first, else the
## level of the player's feet; Vector3.INF if none.
func aim_point() -> Vector3:
	var root_inverse := client.world_root.global_transform.affine_inverse()
	var pixel := _viewport_pixel()
	var camera := client.world_viewport.camera
	var origin := root_inverse * camera.project_ray_origin(pixel)
	var direction := (root_inverse.basis * camera.project_ray_normal(pixel)).normalized()
	var hit := VoxelRay.cast(origin, direction, AIM_FAR, _shown_voxel)
	var far := AIM_FAR if hit == null else (hit.point - origin).dot(direction)
	var creature := client.creatures.pick(origin, direction, far)
	if creature.x >= 0.0 and _shown(int(creature.x)):
		return client.creatures.bounds_of(int(creature.x)).get_center()
	if hit != null:
		return hit.point
	var height := client.local_player.height
	if absf(direction.y) < 0.001:
		return Vector3.INF
	var along := (height - origin.y) / direction.y
	return origin + direction * along if along > 0.0 else Vector3.INF


## What the player aims at: a ray in local units, kept within reach; an
## animal nearer than the block met is aimed at instead (`target_creature`,
## then null). What the view cuts away (a roof over the player) is not
## met: the ray goes through it to what shows under it.
func _aim() -> VoxelRay.Hit:
	target_creature = -1
	_ray_span = Vector2(1.0, 0.0)
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
	_ray_origin = origin
	_ray_direction = direction
	_ray_span = span
	var hit: VoxelRay.Hit = null
	if span.x <= span.y:
		hit = VoxelRay.cast(origin + direction * span.x, direction, span.y - span.x, _shown_voxel)
	var reach := _reach_span(origin, direction, eye, Combat.REACH)
	if reach.x <= reach.y:
		var start := origin + direction * reach.x
		var animal := client.creatures.pick(start, direction, reach.y - reach.x)
		var block := INF if hit == null else (hit.point - origin).dot(direction)
		if animal.x >= 0.0 and reach.x + animal.y < block and _shown(int(animal.x)):
			target_creature = int(animal.x)
			return null
	return hit


## The voxel at a cell as the view shows it: air where it is cut away.
func _shown_voxel(cell: Vector3i) -> int:
	if cell.y >= client.shown_below_row and client.cut_region.covers(Vector2i(cell.x, cell.z)):
		return Voxels.AIR
	return client.world.voxel_at(cell)


## Whether a creature shows (not standing above the view's cut).
func _shown(creature: int) -> bool:
	var box := client.creatures.bounds_of(creature)
	if box.position.y + GameConst.SEA_LEVEL < client.shown_below_row:
		return true
	var middle := box.get_center()
	return not client.cut_region.covers(Vector2i(floori(middle.x), floori(middle.z)))


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
static func _reach_span(
	origin: Vector3, direction: Vector3, eye: Vector3, reach := Mining.REACH
) -> Vector2:
	var offset := origin - eye
	var b := direction.dot(offset)
	var c := offset.length_squared() - reach * reach
	var discriminant := b * b - c
	if discriminant < 0.0:
		return Vector2(1.0, 0.0)
	var root := sqrt(discriminant)
	return Vector2(maxf(-b - root, 0.0), -b + root)


## Bits of `color` bursting from `at` (local units: an animal dying).
func burst(at: Vector3, color: Color, count := 18) -> void:
	_debris.throw(_world_point(at), color, count, 0.3 if count > 6 else 0.12)


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
