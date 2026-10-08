class_name Fish
extends Animal
## A fish (Species.AQUATIC), run by the server: it swims about where it was
## born, always under water: it only heads for water cells, and a step
## taking it out of the water is undone. Hurt, it darts away. Saved like
## the animals.

## How far it swims from home (tiles across, levels up or down).
const ROAM := 6
const ROAM_ROWS := 2
## Close enough to where it was going (tiles).
const THERE := 0.4
## Seconds between two goals, fewest and most.
const DRIFT := Vector2(2.0, 5.0)
## Seconds it darts away when hurt.
const DART_SECONDS := 3.0

## Where it was born (a water cell).
var home := Vector3i.MAX

var _goal := Vector3.INF


static func create(kind: int, feet: Vector2, height: float) -> Fish:
	var fish := Fish.new()
	fish.setup(kind, feet, height)
	fish.body.flying = true
	return fish


## The middle of its body (local units).
func middle() -> Vector3:
	var at := center() / GameConst.TILE_SIZE
	return Vector3(at.x, body.height + body.tall * 0.5, at.y)


func think(delta: float, voxel_at: Callable, rng: RandomNumberGenerator) -> void:
	_immune_tick(delta)
	_timer -= delta
	if home == Vector3i.MAX:
		var at := middle()
		home = Vector3i(floori(at.x), floori(at.y) + GameConst.SEA_LEVEL, floori(at.z))
	if state == State.FLEE and _timer > 0.0:
		return
	var there := _goal != Vector3.INF and middle().distance_to(_goal) < THERE
	if _goal == Vector3.INF or there or _timer <= 0.0:
		_goal = _water_goal(voxel_at, rng)
		_timer = rng.randf_range(DRIFT.x, DRIFT.y)
		state = State.WANDER if _goal != Vector3.INF else State.IDLE
		dirty = true


func move(delta: float, voxel_at: Callable) -> void:
	var before := body.feet
	var before_height := body.height
	var motion := _knocked(delta)
	var up := false
	var down := false
	if _goal != Vector3.INF:
		var to := _goal - middle()
		var flat := Vector2(to.x, to.z)
		var step := minf(_pace() * delta, flat.length())
		if flat.length() > 0.02:
			motion += flat.normalized() * step * GameConst.TILE_SIZE
			heading = flat.normalized()
		up = to.y > 0.1
		down = to.y < -0.1
	body.flying = true
	body.fly(motion, up, down, delta, voxel_at)
	var at := middle()
	var cell := Vector3i(floori(at.x), floori(at.y) + GameConst.SEA_LEVEL, floori(at.z))
	if not body.feet.is_finite() or not Voxels.is_water(voxel_at.call(cell)):
		# Never out of the water.
		body.place(before, before_height)
		body.flying = true
		_goal = Vector3.INF
	speed = body.feet.distance_to(before) / maxf(delta, 0.001) / GameConst.TILE_SIZE
	if speed > 0.01 or absf(body.height - before_height) > 0.001:
		dirty = true


func _on_hurt(from: Vector2) -> void:
	var away := center() - from
	if away.length() < 0.01:
		away = Vector2.RIGHT
	var at := middle()
	var dart := away.normalized() * ROAM
	_goal = Vector3(at.x + dart.x, at.y, at.z + dart.y)
	state = State.FLEE
	_timer = DART_SECONDS
	dirty = true


func _pace() -> float:
	return (Species.FLEE_SPEED if state == State.FLEE else Species.WALK_SPEED)[species]


## A water cell around home to swim to (its middle, local units; INF if
## none found).
func _water_goal(voxel_at: Callable, rng: RandomNumberGenerator) -> Vector3:
	for attempt in 8:
		var cell := (
			home
			+ Vector3i(
				rng.randi_range(-ROAM, ROAM),
				rng.randi_range(-ROAM_ROWS, ROAM_ROWS),
				rng.randi_range(-ROAM, ROAM)
			)
		)
		if Voxels.is_water(voxel_at.call(cell)):
			return Vector3(cell.x + 0.5, cell.y - GameConst.SEA_LEVEL + 0.5, cell.z + 0.5)
	return Vector3.INF
