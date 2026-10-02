class_name Animal
extends RefCounted
## An animal of the world (Species), run by the server (Creatures): it
## stands and grazes, wanders to places it can walk to (Pathfinder), runs
## away when hurt (its herd too) and dies leaving what it gives
## (Species.DROPS). Its body moves like a player's (PlayerBody, its own
## size: it climbs one level at a time, drops a few, swims). Like a
## player's, its position is its feet (world pixels: the bottom middle of
## its box) and their height (levels).

enum State { IDLE, GRAZE, WANDER, FLEE }

## Seconds standing (idle or grazing) before deciding again.
const REST_SECONDS := Vector2(2.0, 7.0)
## How far it wanders, and how far it runs from what hurt it (tiles).
const WANDER_RANGE := 7
const FLEE_RANGE := 10
## Running away lasts this long; it looks for its way once the blow
## threw it back (FIRST_SEARCH), and again after SEARCH_WAIT when cornered.
const FLEE_SECONDS := 5.0
const FIRST_SEARCH := 0.15
const SEARCH_WAIT := 0.5
## A point of its way is reached this close (tiles).
const REACHED := 0.3
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
## Tiles per second it moved during its last step.
var speed := 0.0

var _timer := 0.0
var _way: Array[Vector3] = []
var _flee_from := Vector2.ZERO
var _knock := Vector2.ZERO
var _immune := 0.0
var _stuck := 0.0
var _search := 0.0
var _rest_check := 0.0


static func create(kind: int, feet: Vector2, height: float) -> Animal:
	var animal := Animal.new()
	animal.species = kind as Species.Id
	animal.body.box = Species.BOX[kind]
	animal.body.tall = Species.TALL[kind]
	animal.body.place(feet, height)
	animal.health = Species.HEALTH[kind]
	return animal


static func from_dict(data: Dictionary) -> Animal:
	var kind := int(data.get("species", 0))
	if not Species.is_valid(kind):
		return null
	var animal := create(kind, data.get("feet", Vector2.ZERO), float(data.get("height", 0.0)))
	animal.health = clampi(int(data.get("health", animal.health)), 1, Species.HEALTH[kind])
	animal.heading = data.get("heading", Vector2.DOWN)
	return animal


func to_dict() -> Dictionary:
	return {
		"species": species,
		"feet": body.feet,
		"height": body.height,
		"health": health,
		"heading": heading,
	}


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


func is_moving() -> bool:
	return not _way.is_empty()


## Decides what to do next (`rng` draws its choices).
func think(delta: float, voxel_at: Callable, rng: RandomNumberGenerator) -> void:
	_immune = maxf(_immune - delta, 0.0)
	_timer -= delta
	match state:
		State.IDLE, State.GRAZE:
			if _timer <= 0.0:
				if rng.randf() < 0.55:
					_wander(voxel_at, rng)
				else:
					_rest(State.GRAZE if rng.randf() < 0.5 else State.IDLE, rng)
		State.WANDER:
			if _way.is_empty():
				_rest(State.IDLE, rng)
		State.FLEE:
			_search -= delta
			if _timer <= 0.0:
				_rest(State.IDLE, rng)
			elif _way.is_empty() and _search <= 0.0:
				_run_away(voxel_at, rng)


## Moves for `delta` seconds: along its way, thrown back by a blow,
## swimming up when in water.
func move(delta: float, voxel_at: Callable) -> void:
	if _way.is_empty() and _knock == Vector2.ZERO and body.on_ground and not body.in_liquid:
		speed = 0.0
		_rest_check -= delta
		if _rest_check > 0.0:
			return
		_rest_check = REST_CHECK
	var before := body.feet
	var before_height := body.height
	var motion := _knock * delta
	_knock *= exp(-KNOCK_DRAG * delta)
	if _knock.length() < 1.0:
		_knock = Vector2.ZERO
	var jump := body.in_liquid
	var expected := 0.0
	if not _way.is_empty():
		var point := _way[0]
		var to := Vector2(point.x, point.z) * GameConst.TILE_SIZE - center()
		var distance := to.length()
		if distance < REACHED * GameConst.TILE_SIZE and absf(point.y - body.height) < 0.6:
			_way.pop_front()
			_stuck = 0.0
			dirty = true
		else:
			var pace: float = (Species.FLEE_SPEED if state == State.FLEE else Species.WALK_SPEED)[species]
			expected = minf(pace * GameConst.TILE_SIZE * delta, distance)
			motion += to / distance * expected
			heading = to / distance
			if point.y > body.height + PlayerBody.STEP_UP and distance < 1.2 * GameConst.TILE_SIZE:
				jump = true
	_pop_out(voxel_at)
	body.step(motion, jump, delta, voxel_at)
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
## back and runs away. False when it was not hurt (just hurt, or dead).
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
	scare(from)
	return true


## Runs away from `from` (world pixels) for a while.
func scare(from: Vector2) -> void:
	state = State.FLEE
	_timer = FLEE_SECONDS
	_flee_from = from
	_search = FIRST_SEARCH
	_way.clear()
	dirty = true


func _rest(next: State, rng: RandomNumberGenerator) -> void:
	state = next
	_timer = rng.randf_range(REST_SECONDS.x, REST_SECONDS.y)
	_way.clear()
	dirty = true


func _wander(voxel_at: Callable, rng: RandomNumberGenerator) -> void:
	var offset := Vector2i(
		rng.randi_range(-WANDER_RANGE, WANDER_RANGE), rng.randi_range(-WANDER_RANGE, WANDER_RANGE)
	)
	if offset == Vector2i.ZERO:
		offset = Vector2i(WANDER_RANGE, 0)
	_way = Pathfinder.find(tile(), body.height, tile() + offset, voxel_at, body.tall)
	if _way.is_empty():
		_rest(State.IDLE, rng)
		return
	state = State.WANDER
	dirty = true


func _run_away(voxel_at: Callable, rng: RandomNumberGenerator) -> void:
	var away := center() - _flee_from
	if away.length() < 0.01:
		away = Vector2.RIGHT.rotated(rng.randf() * TAU)
	away = away.normalized()
	for attempt in 3:
		var turn := rng.randf_range(-0.8, 0.8) * (attempt + 1) * 0.6
		var goal := tile() + Vector2i((away.rotated(turn) * FLEE_RANGE).round())
		_way = Pathfinder.find(tile(), body.height, goal, voxel_at, body.tall)
		if not _way.is_empty():
			return
	# Cornered: it looks again in a moment.
	_search = SEARCH_WAIT


## A block placed on it: it climbs out on top.
func _pop_out(voxel_at: Callable) -> void:
	var at := tile()
	var row := floori(body.height + 0.01) + GameConst.SEA_LEVEL
	if Voxels.is_cube(voxel_at.call(Vector3i(at.x, row, at.y))):
		body.height = float(row + 1 - GameConst.SEA_LEVEL)
		body.vertical_speed = 0.0
