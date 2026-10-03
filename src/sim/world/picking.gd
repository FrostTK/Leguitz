class_name Picking
extends RefCounted
## What is picked without being broken (a right click or the use key), on
## the server (static, given the server): ripe tomatoes, strawberries,
## raspberries and grapes go back a stage and ripen again, sugar cane is cut back to its
## first one, a fruit tree in fruit goes back into blossom (Growth.FRUITING);
## what is picked goes into the bag (`pick`; what does not fit falls at the
## player's feet).

## Server: what is picked is reached this far at most (local units).
const REACH_LEEWAY := 1.5
## What a ripe plant (a tree in fruit) becomes once picked.
const PICKED := {
	Tiles.Block.TOMATOES_3: Tiles.Block.TOMATOES_2,
	Tiles.Block.STRAWBERRIES_3: Tiles.Block.STRAWBERRIES_2,
	Tiles.Block.GRAPES_3: Tiles.Block.GRAPES_2,
	Tiles.Block.SUGAR_CANE: Tiles.Block.SUGAR_CANE_0,
	Tiles.Block.APPLE_TREE_FRUIT: Tiles.Block.APPLE_TREE,
	Tiles.Block.CHERRY_TREE_FRUIT: Tiles.Block.CHERRY_TREE,
	Tiles.Block.ORANGE_TREE_FRUIT: Tiles.Block.ORANGE_TREE,
	Tiles.Block.RASPBERRIES_3: Tiles.Block.RASPBERRIES_2,
	Tiles.Block.PEACH_TREE_FRUIT: Tiles.Block.PEACH_TREE,
}
## What picking gives: [item, fewest, most].
const GIVES := {
	Tiles.Block.TOMATOES_3: [Items.Id.TOMATO, 2, 3],
	Tiles.Block.STRAWBERRIES_3: [Items.Id.STRAWBERRY, 1, 3],
	Tiles.Block.GRAPES_3: [Items.Id.GRAPES, 2, 3],
	Tiles.Block.SUGAR_CANE: [Items.Id.SUGAR_CANE, 2, 3],
	Tiles.Block.APPLE_TREE_FRUIT: [Items.Id.APPLE, 2, 4],
	Tiles.Block.CHERRY_TREE_FRUIT: [Items.Id.CHERRIES, 3, 5],
	Tiles.Block.ORANGE_TREE_FRUIT: [Items.Id.ORANGE, 2, 4],
	Tiles.Block.RASPBERRIES_3: [Items.Id.RASPBERRY, 2, 4],
	Tiles.Block.PEACH_TREE_FRUIT: [Items.Id.PEACH, 2, 4],
}


## Whether a voxel can be picked.
static func can_pick(voxel: int) -> bool:
	return voxel != Voxels.UNKNOWN and PICKED.has(Voxels.block_of(voxel))


## What picking a block gives: [item, count].
static func picking(block: int, rng: RandomNumberGenerator) -> Vector2i:
	var gift: Array = GIVES[block]
	return Vector2i(gift[0], rng.randi_range(gift[1], gift[2]))


## A player picked what grows in `cell` (Msg.PICK): within reach, it goes
## back (PICKED) and what it gives goes into their bag. Refused, they are
## told what is there.
static func pick(
	server: GameServer, session: GameServer.PlayerSession, message: Dictionary
) -> void:
	if not session.joined or not session.alive():
		return
	var cell: Vector3i = message.get("cell", Vector3i.ZERO)
	var voxel := server.world.voxel_at(cell)
	var near := Mining.reach_to(session.position, session.height, cell)
	if not can_pick(voxel) or near > Mining.REACH + REACH_LEEWAY:
		session.transport.send(Msg.block_changed(cell, voxel))
		return
	var block := Voxels.block_of(voxel)
	server.change_voxel(cell, Voxels.of_block(PICKED[block]))
	var got := picking(block, server.rng)
	var bag := session.inventory
	var left := bag.add(got.x, got.y)
	if left > 0:
		server.throw_item(session, got.x, left)
	session.transport.send(Msg.inventory(bag))
