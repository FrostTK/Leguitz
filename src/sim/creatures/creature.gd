class_name Creature
extends RefCounted
## A creature of the world (Species), run by the server (Creatures): an
## animal (Animal) or a monster (Monster). Its body moves like a player's
## (PlayerBody, its own size); walking ones follow ways (Pathfinder): up one
## level at a time, down a few, swimming when they fall in water. Like a
## player's, its position is its feet (world pixels: the bottom middle of
## its box) and their height (levels). Hit, it is thrown back (`hurt_by`);
## what it does then is its kind's (`_on_hurt`).

## What it does; its players see it (Msg.ENTITY_MOVE): animals graze,
## wander, flee and sleep; monsters chase, strike, lie dormant or freeze;
## a bear warns (ALERT) before it charges, a dog barks; companions sit.
enum State { IDLE, GRAZE, WANDER, FLEE, CHASE, STRIKE, DORMANT, FROZEN, SLEEP, ALERT, SIT }

## A point of its way is reached this close (tiles).
const REACHED := 0.3
## A swimmer's feet float this far under the surface (levels): it rides on
## the water.
const SWIMMER_FLOAT := 0.15
## Hardly moving this long on its way: it gives up.
const STUCK_SECONDS := 1.5
## A blow throws it back this fast (tiles per second, fading by
## KNOCK_DRAG per second) and up (levels per second).
const KNOCKBACK := 6.0
const KNOCK_DRAG := 7.0
const KNOCK_HOP := 5.0
## Hurt again only after this long.
const HURT_IMMUNITY := 0.3
## Standing still on the ground, its body is only moved this often (a
## block broken under it: it falls a moment later).
const REST_CHECK := 0.5

var id := 0
var species := Species.Id.SHEEP
var body := PlayerBody.new()
var health := 1
## Where it looks (ground direction, world axes).
var heading := Vector2.DOWN
var state := State.IDLE
## Moved, turned or changed what it does since its players were told.
var dirty := true
## The boat it sits aboard (-1: none; Boats places it, it does not think).
var seated := -1
## Tiles per second it moved during its last step.
var speed := 0.0

var _way: Array[Vector3] = []
var _knock := Vector2.ZERO
var _immune := 0.0
var _stuck := 0.0
var _rest_check := 0.0


## Makes it a creature of `kind` standing at `feet` and `height`.
func setup(kind: int, feet: Vector2, height: float) -> void:
	species = kind as Species.Id
	body.box = Species.BOX[kind]
	body.tall = Species.TALL[kind]
	body.place(feet, height)
	body.flying = Species.FLIERS.has(kind)
	if Species.SWIMMERS.has(kind):
		body.float_depth = SWIMMER_FLOAT
	health = Species.HEALTH[kind]


func to_dict() -> Dictionary:
	return {
		"species": species,
		"feet": body.feet,
		"height": body.height,
		"health": health,
		"heading": heading,
	}


## Takes back what to_dict kept (after setup).
func load_dict(data: Dictionary) -> void:
	health = clampi(int(data.get("health", health)), 1, Species.HEALTH[species])
	heading = data.get("heading", Vector2.DOWN)
	if not heading.is_finite():
		heading = Vector2.DOWN


## What players see of it besides what it does (Animal.Flag bits).
func flags() -> int:
	return 0


## The player leading it (PlayerSession.id; -1: none).
func led_by() -> int:
	return -1


## Its look among its kind's (a companion's coat; Msg.ENTITY_SPAWN).
func look() -> int:
	return 0


## Whether it is the companion of the player `player` (PlayerSession.id):
## their blows and arrows spare it.
func belongs_to(_player: int) -> bool:
	return false


## The middle of its box on the ground (world pixels).
func center() -> Vector2:
	return body.feet - Vector2(0.0, body.box.y * 0.5)


## The tile it stands on.
func tile() -> Vector2i:
	return Coords.world_to_tile(center())


## Its box (local units).
func bounds() -> AABB:
	var middle := center() / GameConst.TILE_SIZE
	var across := body.box / GameConst.TILE_SIZE
	return AABB(
		Vector3(middle.x - across.x * 0.5, body.height, middle.y - across.y * 0.5),
		Vector3(across.x, body.tall, across.y)
	)


## Decides what to do next (`rng` draws its choices).
func think(_delta: float, _voxel_at: Callable, _rng: RandomNumberGenerator) -> void:
	pass


## Moves for `delta` seconds: along its way at its pace (`_pace`), thrown
## back by a blow, swimming up when in water.
func move(delta: float, voxel_at: Callable) -> void:
	if _way.is_empty() and _knock == Vector2.ZERO and body.on_ground and not body.in_liquid:
		speed = 0.0
		_rest_check -= delta
		if _rest_check > 0.0:
			return
		_rest_check = REST_CHECK
	var before := body.feet
	var before_height := body.height
	var motion := _knocked(delta)
	var jump := body.in_liquid
	var expected := 0.0
	if not _way.is_empty():
		var point := _way[0]
		var to := Vector2(point.x, point.z) * GameConst.TILE_SIZE - center()
		var distance := to.length()
		var reached := distance < REACHED * GameConst.TILE_SIZE
		# Right over or under it: nothing to walk (no dividing by zero).
		if reached and (absf(point.y - body.height) < 0.6 or distance < 0.01):
			_way.pop_front()
			_stuck = 0.0
			dirty = true
		else:
			expected = minf(_pace() * GameConst.TILE_SIZE * delta, distance)
			motion += to / distance * expected
			heading = to / distance
			if point.y > body.height + PlayerBody.STEP_UP and distance < 1.2 * GameConst.TILE_SIZE:
				jump = true
	_pop_out(voxel_at)
	body.step(motion, jump, delta, voxel_at)
	if not body.feet.is_finite() or not is_finite(body.height):
		# Never lose it to a broken step: back where it was, at rest.
		body.place(before, before_height)
		_way.clear()
		_knock = Vector2.ZERO
	var moved := body.feet.distance_to(before)
	speed = moved / maxf(delta, 0.001) / GameConst.TILE_SIZE
	if expected > 0.0 and moved < expected * 0.2:
		_stuck += delta
		if _stuck >= STUCK_SECONDS:
			_stuck = 0.0
			_way.clear()
	if moved > 0.01 or absf(body.height - before_height) > 0.001:
		dirty = true


## A blow from `from` (world pixels) taking `damage` off: it is thrown
## back. False when it was not hurt (just hurt, or dead).
func hurt_by(from: Vector2, damage: int) -> bool:
	if _immune > 0.0 or health <= 0:
		return false
	health = maxi(health - damage, 0)
	_immune = HURT_IMMUNITY
	var away := center() - from
	if away.length() < 0.01:
		away = -heading
	_knock = away.normalized() * KNOCKBACK * GameConst.TILE_SIZE
	if body.on_ground:
		body.vertical_speed = KNOCK_HOP
		body.on_ground = false
	_on_hurt(from)
	return true


## What it does once hurt by a blow from `from` (world pixels).
func _on_hurt(_from: Vector2) -> void:
	pass


## Tiles per second along its way.
func _pace() -> float:
	return Species.WALK_SPEED[species]


## The motion (world pixels) a blow still throws it by this step.
func _knocked(delta: float) -> Vector2:
	var motion := _knock * delta
	_knock *= exp(-KNOCK_DRAG * delta)
	if _knock.length() < 1.0:
		_knock = Vector2.ZERO
	return motion


## Looks for a way to `goal`; false if there is none.
func _walk_to(goal: Vector2i, voxel_at: Callable) -> bool:
	var swims := Species.SWIMMERS.has(species)
	_way = Pathfinder.find(tile(), body.height, goal, voxel_at, body.tall, swims)
	return not _way.is_empty()


func _immune_tick(delta: float) -> void:
	_immune = maxf(_immune - delta, 0.0)


## A block placed on it: it climbs out on top.
func _pop_out(voxel_at: Callable) -> void:
	var at := tile()
	var row := floori(body.height + 0.01) + GameConst.SEA_LEVEL
	if Voxels.is_cube(voxel_at.call(Vector3i(at.x, row, at.y))):
		body.height = float(row + 1 - GameConst.SEA_LEVEL)
		body.vertical_speed = 0.0
