class_name Crow
extends Creature
## A crow (Pests), run by the server: it flies in to a young crop
## (`target`), lands on it and pecks (State.GRAZE; `bite` after
## PECK_SECONDS: Pests takes the seedling and gives it the next one, if
## any). Scared (a scarecrow near, a player close, the night, a blow) it
## flies off (State.FLEE) and is `gone`. Never saved.

const PECK_SECONDS := 5.0
## Close enough to where it flies (tiles).
const THERE := 0.35
## Scared, it flies off this far and this high, this long.
const OFF := Vector2(10.0, 6.0)
const OFF_SECONDS := 4.0

## The crop it goes for (a cell; MAX: none).
var target := Vector3i.MAX
## It pecked a seedling through this step (Pests takes it).
var bite := false
var gone := false

var _goal := Vector3.INF
var _timer := 0.0


static func create(kind: int, feet: Vector2, height: float) -> Crow:
	var crow := Crow.new()
	crow.setup(kind, feet, height)
	crow.body.flying = true
	crow.state = State.WANDER
	return crow


## The middle of its body (local units).
func middle() -> Vector3:
	return bounds().get_center()


func think(delta: float, _voxel_at: Callable, _rng: RandomNumberGenerator) -> void:
	_immune_tick(delta)
	_timer -= delta
	match state:
		State.FLEE:
			if _timer <= 0.0:
				gone = true
		State.GRAZE:
			if _timer <= 0.0:
				bite = true
				_timer = PECK_SECONDS
		_:
			if target == Vector3i.MAX:
				scare(center())
				return
			_goal = Vector3(target.x + 0.5, target.y - GameConst.SEA_LEVEL + 0.3, target.z + 0.5)
			if middle().distance_to(_goal) < THERE:
				_set_state(State.GRAZE)
				_timer = PECK_SECONDS


## Goes for another crop.
func peck(cell: Vector3i) -> void:
	target = cell
	_set_state(State.WANDER)


## Flies off, away from `from` (world pixels), and is gone.
func scare(from: Vector2) -> void:
	if state == State.FLEE:
		return
	var away := center() - from
	if away.length() < 0.01:
		away = Vector2.RIGHT.rotated(id)
	away = away.normalized() * OFF.x
	var at := middle()
	_goal = Vector3(at.x + away.x, at.y + OFF.y, at.z + away.y)
	_timer = OFF_SECONDS
	_set_state(State.FLEE)


func move(delta: float, voxel_at: Callable) -> void:
	var before := body.feet
	var before_height := body.height
	var motion := _knocked(delta)
	var up := false
	var down := false
	if _goal != Vector3.INF and state != State.GRAZE:
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
	if not body.feet.is_finite() or not is_finite(body.height):
		body.place(before, before_height)
	speed = body.feet.distance_to(before) / maxf(delta, 0.001) / GameConst.TILE_SIZE
	if speed > 0.01 or absf(body.height - before_height) > 0.001:
		dirty = true


func _on_hurt(from: Vector2) -> void:
	scare(from)


func _pace() -> float:
	return (Species.FLEE_SPEED if state == State.FLEE else Species.WALK_SPEED)[species]


func _set_state(next: State) -> void:
	if state != next:
		state = next
		dirty = true
