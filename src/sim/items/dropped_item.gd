class_name DroppedItem
extends RefCounted
## An item lying in the world (broken blocks drop theirs, players throw
## them): it falls, rests on the ground or floats up in water, and players
## walking by pick it up. Positions in local units (tiles across, levels
## up), the item's center.

## Levels per second squared, and the speed water lifts an item at.
const GRAVITY := 22.0
const FLOAT_SPEED := 0.8
## Half the item's size: it rests this high over the ground.
const RADIUS := 0.15
## Seconds before players can pick it up (thrown: longer, for the
## thrower), and before it vanishes.
const PICKUP_DELAY := 0.4
const THROWN_DELAY := 1.5
const LIFETIME := 300.0

var id := 0
var item := Items.Id.NONE
var count := 0
## A tool's wear (see Inventory.wear).
var wear := 0
var position := Vector3.ZERO
var velocity := Vector3.ZERO
var age := 0.0
var pickup_delay := PICKUP_DELAY
## Lies still on the ground (or floats): no need to move it.
var resting := false


static func create(item_id: int, amount: int, at: Vector3, speed: Vector3) -> DroppedItem:
	var dropped := DroppedItem.new()
	dropped.item = item_id
	dropped.count = amount
	dropped.position = at
	dropped.velocity = speed
	return dropped


## Moves it for `delta` seconds among the voxels. Returns true if it moved.
func step(delta: float, voxel_at: Callable) -> bool:
	age += delta
	pickup_delay = maxf(pickup_delay - delta, 0.0)
	if resting and _supported(voxel_at):
		return false
	resting = false
	var cell := _cell(position)
	var inside: int = voxel_at.call(cell)
	if Voxels.is_cube(inside):
		# Buried (a block was placed on it): it pops out on top.
		position.y = float(cell.y + 1 - GameConst.SEA_LEVEL) + RADIUS
		velocity = Vector3.ZERO
		return true
	if Voxels.is_liquid(inside):
		# Water lifts it to the surface and slows it down.
		velocity.y = move_toward(velocity.y, FLOAT_SPEED, 8.0 * delta)
		velocity.x *= exp(-3.0 * delta)
		velocity.z *= exp(-3.0 * delta)
		var above: int = voxel_at.call(cell + Vector3i.UP)
		var surface := float(cell.y - GameConst.SEA_LEVEL) + Fluids.surface(inside)
		if not Voxels.is_liquid(above) and position.y >= surface:
			position.y = surface
			velocity = Vector3.ZERO
			resting = true
			return true
	else:
		velocity.y -= GRAVITY * delta
	var start := position
	var next := position + velocity * delta
	# Sideways into a cube: it stops there.
	if Voxels.is_cube(voxel_at.call(_cell(Vector3(next.x, position.y, next.z)))):
		next.x = position.x
		next.z = position.z
		velocity.x = 0.0
		velocity.z = 0.0
	var under := Vector3(next.x, next.y - RADIUS, next.z)
	var rest_height := _rest_height(under, voxel_at)
	if velocity.y <= 0.0 and under.y <= rest_height:
		next.y = rest_height + RADIUS
		velocity = Vector3.ZERO
		resting = true
	position = next
	return position.distance_squared_to(start) > 1e-8


func is_expired() -> bool:
	return age >= LIFETIME


func to_dict() -> Dictionary:
	return {"item": item, "count": count, "wear": wear, "position": position, "age": age}


static func from_dict(data: Dictionary) -> DroppedItem:
	var dropped := create(
		int(data.get("item", Items.Id.NONE)),
		int(data.get("count", 0)),
		data.get("position", Vector3.ZERO),
		Vector3.ZERO
	)
	dropped.age = data.get("age", 0.0)
	dropped.wear = int(data.get("wear", 0))
	return dropped


func _supported(voxel_at: Callable) -> bool:
	var cell := _cell(position)
	var inside: int = voxel_at.call(cell)
	if Voxels.is_cube(inside):
		return false
	if Voxels.is_liquid(inside):
		return true
	var under := position - Vector3(0.0, RADIUS + 0.01, 0.0)
	return under.y <= _rest_height(under, voxel_at)


## What an item touching `at` (local units) would rest on there: the top
## of a cube, or of furniture under it (levels; -INF: nothing).
static func _rest_height(at: Vector3, voxel_at: Callable) -> float:
	var cell := _cell(at)
	var voxel: int = voxel_at.call(cell)
	if Voxels.is_cube(voxel):
		return float(cell.y + 1 - GameConst.SEA_LEVEL)
	if Voxels.is_object(voxel):
		var block := Voxels.block_of(voxel)
		var stand := ObjectShapes.stand_height(block)
		var foot := ObjectShapes.footprint_rect(block, Vector2i(cell.x, cell.z))
		if stand > 0.0 and foot.has_point(Vector2(at.x, at.z) * GameConst.TILE_SIZE):
			return float(cell.y - GameConst.SEA_LEVEL) + stand
	return -INF


static func _cell(at: Vector3) -> Vector3i:
	return Vector3i(floori(at.x), floori(at.y) + GameConst.SEA_LEVEL, floori(at.z))
