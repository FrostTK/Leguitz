class_name Archery
extends RefCounted
## Bows and arrows on the server. A player shoots (Msg.SHOOT) with a bow in
## the hotbar slot named and an arrow in their slots (used up, not in
## creative; the bow wears), not sooner than SHOT_PAUSE after the last: the
## arrow leaves their chest along the direction given, ARROW_SPEED times
## how far the bow was drawn (`power`, 0..1). Arrows fall (GRAVITY): one
## meeting a creature hurts it (DAMAGE at full speed, it is thrown back and
## an animal runs away) and is gone; one meeting a block falls there, to be
## picked up again (not a creative player's). Every player is told
## (Msg.ARROW_SPAWN, ARROW_REMOVE) and flies them the same way (fly).
## Positions in local units (tiles across, levels up).

## Levels per second at full draw, the pull down, what a full-speed arrow
## takes off, and how long one flies at most.
const ARROW_SPEED := 32.0
const GRAVITY := 20.0
const DAMAGE := 6.0
const LIFETIME := 8.0
## Seconds between two shots (the client draws longer anyway).
const SHOT_PAUSE := 0.25
## An arrow moves this far at most between two checks (local units).
const STEP := 0.25
## The chest: arrows leave from this high over the feet.
const CHEST := 1.25


## An arrow in flight.
class Arrow:
	extends RefCounted
	var id := 0
	## Where and how fast it left (see fly), how long it has flown, where it
	## is and how fast it goes now.
	var origin := Vector3.ZERO
	var launch := Vector3.ZERO
	var age := 0.0
	var position := Vector3.ZERO
	var velocity := Vector3.ZERO
	## Who shot it (a player's id), and whether it may be picked up again.
	var shooter := 0
	var keep := true


var arrows: Dictionary[int, Arrow] = {}
var _next_id := 1


## Where an arrow is `time` seconds after leaving `from` at `velocity`
## (the same flight on the server and the clients).
static func fly(from: Vector3, velocity: Vector3, time: float) -> Vector3:
	return from + velocity * time + Vector3(0.0, -0.5 * GRAVITY * time * time, 0.0)


## The slot of the first arrows a player carries (hotbar first; -1: none).
static func arrow_slot(bag: Inventory) -> int:
	for slot in Inventory.SLOTS:
		if bag.items[slot] == Items.Id.ARROW:
			return slot
	return -1


## A player shoots (see the class).
func shoot(
	server: GameServer,
	session: GameServer.PlayerSession,
	slot: int,
	direction: Vector3,
	power: float
) -> void:
	if not session.joined or not session.alive() or slot < 0 or slot >= Inventory.HOTBAR:
		return
	var bag := session.inventory
	var now := server.tick_count * GameConst.TICK_DELTA
	var creative := GameModes.creative(server)
	var ammo := arrow_slot(bag)
	if bag.items[slot] != Items.Id.BOW or (ammo < 0 and not creative):
		session.transport.send(Msg.inventory(bag))
		return
	if now - session.last_shot < SHOT_PAUSE or direction.length() < 0.01:
		return
	session.last_shot = now
	if not creative:
		bag.take(ammo, 1)
		bag.wear_out(slot)
		session.transport.send(Msg.inventory(bag))
	var arrow := Arrow.new()
	arrow.id = _next_id
	_next_id += 1
	var feet := session.position / GameConst.TILE_SIZE
	arrow.origin = Vector3(feet.x, session.height + CHEST, feet.y)
	arrow.launch = direction.normalized() * ARROW_SPEED * clampf(power, 0.1, 1.0)
	arrow.position = arrow.origin
	arrow.velocity = arrow.launch
	arrow.shooter = session.id
	arrow.keep = not creative
	arrows[arrow.id] = arrow
	server.broadcast(Msg.arrow_spawn(arrow.id, arrow.origin, arrow.launch))


## The arrows fly for `delta` seconds: into creatures or blocks.
func update(server: GameServer, delta: float) -> void:
	for id: int in arrows.keys():
		var arrow := arrows[id]
		var steps := maxi(1, ceili(arrow.velocity.length() * delta / STEP))
		var done := arrow.age > LIFETIME
		for i in steps:
			if done:
				break
			var before := arrow.position
			arrow.age += delta / steps
			arrow.position = fly(arrow.origin, arrow.launch, arrow.age)
			arrow.velocity = arrow.launch + Vector3(0.0, -GRAVITY * arrow.age, 0.0)
			done = _meet_creature(server, arrow, before) or _meet_block(server, arrow, before)
		if done:
			arrows.erase(id)
			server.broadcast(Msg.arrow_remove(id))


## Hurts the first creature the arrow's last move went through (it is
## gone then).
func _meet_creature(server: GameServer, arrow: Arrow, before: Vector3) -> bool:
	for creature: Creature in server.creatures.living.values():
		if creature.bounds().intersects_segment(before, arrow.position) == null:
			continue
		var damage := maxi(1, roundi(DAMAGE * arrow.velocity.length() / ARROW_SPEED))
		var back := before - arrow.velocity.normalized()
		if creature.hurt_by(Vector2(back.x, back.z) * GameConst.TILE_SIZE, damage):
			server.creatures.tell_seers(server, creature.id, Msg.entity_hurt(creature.id))
			if creature.health <= 0:
				server.creatures.die(server, creature)
		return true
	return false


## Stops the arrow on a block (or out of the loaded world): it falls
## there, to be picked up again.
func _meet_block(server: GameServer, arrow: Arrow, before: Vector3) -> bool:
	var at := arrow.position
	var cell := Vector3i(floori(at.x), floori(at.y) + GameConst.SEA_LEVEL, floori(at.z))
	var voxel := server.world.loaded_voxel_at(cell)
	if not Voxels.is_solid(voxel) or Voxels.is_liquid(voxel):
		return false
	if arrow.keep and voxel != Voxels.UNKNOWN:
		server.spawn_item(Items.Id.ARROW, 1, before, Vector3.ZERO, DroppedItem.THROWN_DELAY)
	return true
