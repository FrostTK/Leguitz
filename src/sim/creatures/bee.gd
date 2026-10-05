class_name Bee
extends Creature
## A bee of a hive (Apiary), run by the server (Creatures): it flies from
## its hive to the flowers around (`flowers`, given by its hive), hovers
## over one, goes back, and so on; at night it flies home, where it goes
## in (Apiary takes it away). Never saved: hives send their bees out
## again.

## How high it flies over what it visits (levels), how close is there,
## and how long it hovers (seconds, fewest and most).
const ABOVE := 0.6
const THERE := 0.35
const HOVER := Vector2(1.5, 4.0)
## Without flowers, it wanders this far from its hive (tiles).
const ROAM := 4.0

## Its hive (a cell) and the flowers it visits (local units: the middle
## of their tiles, on their ground).
var home := Vector3i.MAX
var flowers: Array[Vector3] = []
## Night: it flies home (Apiary.sense).
var night := false

var _goal := Vector3.INF
var _timer := 0.0
var _to_flower := true


static func create(kind: int, feet: Vector2, height: float) -> Bee:
	var bee := Bee.new()
	bee.setup(kind, feet, height)
	return bee


## The middle of its body (local units).
func middle() -> Vector3:
	return bounds().get_center()


## Where its hive's door is (local units).
func doorstep() -> Vector3:
	return Vector3(home.x + 0.5, home.y - GameConst.SEA_LEVEL + 1.0, home.z + 0.5)


## Whether it is back at its hive.
func is_home() -> bool:
	return home != Vector3i.MAX and middle().distance_to(doorstep()) < THERE * 2.0


func think(delta: float, _voxel_at: Callable, rng: RandomNumberGenerator) -> void:
	_immune_tick(delta)
	_timer -= delta
	if night:
		_goal = doorstep()
		_set_state(State.WANDER)
		return
	var there := _goal != Vector3.INF and middle().distance_to(_goal) < THERE
	match state:
		State.GRAZE:
			if _timer <= 0.0:
				_next(rng)
		_:
			if _goal == Vector3.INF:
				_next(rng)
			elif there or _timer <= -8.0:
				# Arrived (or gave up): it hovers a moment.
				_set_state(State.GRAZE)
				_timer = rng.randf_range(HOVER.x, HOVER.y)


func move(delta: float, voxel_at: Callable) -> void:
	var before := body.feet
	var before_height := body.height
	var motion := _knocked(delta)
	var up := false
	var down := false
	if _goal != Vector3.INF:
		var to := _goal - middle()
		var flat := Vector2(to.x, to.z)
		var pace := _pace() * (0.25 if state == State.GRAZE else 1.0)
		var step := minf(pace * delta, flat.length())
		if flat.length() > 0.02:
			motion += flat.normalized() * step * GameConst.TILE_SIZE
			heading = flat.normalized()
		up = to.y > 0.1
		down = to.y < -0.1
	body.flying = true
	body.fly(motion, up, down, delta, voxel_at)
	if not body.feet.is_finite() or not is_finite(body.height):
		body.place(before, before_height)
	speed = body.feet.distance_to(before) / maxf(delta, 0.001) / GameConst.TILE_SIZE
	if speed > 0.01 or absf(body.height - before_height) > 0.001:
		dirty = true


## Where it goes next: a flower (or somewhere around its hive), then home,
## in turn.
func _next(rng: RandomNumberGenerator) -> void:
	_set_state(State.WANDER)
	_timer = 0.0
	if _to_flower:
		if not flowers.is_empty():
			_goal = flowers[rng.randi() % flowers.size()] + Vector3(0.0, ABOVE, 0.0)
		else:
			var around := Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(1.0, ROAM)
			_goal = doorstep() + Vector3(around.x, rng.randf_range(0.0, 1.0), around.y)
	else:
		_goal = doorstep()
	_to_flower = not _to_flower


func _set_state(next: State) -> void:
	if state != next:
		state = next
		dirty = true
