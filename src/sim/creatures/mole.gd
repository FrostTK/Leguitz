class_name Mole
extends Creature
## A mole (Pests), run by the server: it tunnels under a field from crop to
## crop (State.WANDER, out of sight), gnaws one from below (State.GRAZE;
## `bite` when done: Pests takes the crop and leaves a molehill), comes up
## a moment (State.IDLE: seen, and only then it can be hit), then goes on
## to the nearest crop left. After RAVAGES crops, or once hurt, it is
## `done` and leaves. Never saved.

const GNAW_SECONDS := 4.0
const UP_SECONDS := 3.0
const RAVAGES := 4
## Close enough to its crop (tiles).
const THERE := 0.2

## The crops of its field (cells) and the one it goes for.
var field: Array[Vector3i] = []
var target := Vector3i.MAX
## It gnawed through a crop this step (Pests takes it).
var bite := false
var ravaged := 0
var done := false

var _timer := 0.0


static func create(kind: int, feet: Vector2, height: float) -> Mole:
	var mole := Mole.new()
	mole.setup(kind, feet, height)
	mole.state = State.WANDER
	return mole


## Whether it is up, seen (and can be hit).
func is_up() -> bool:
	return state == State.IDLE


func think(delta: float, voxel_at: Callable, _rng: RandomNumberGenerator) -> void:
	_immune_tick(delta)
	_timer -= delta
	if done:
		return
	match state:
		State.WANDER:
			if target == Vector3i.MAX:
				_next(voxel_at)
			elif _flat_distance() < THERE:
				_set_state(State.GRAZE)
				_timer = GNAW_SECONDS
		State.GRAZE:
			if _timer <= 0.0:
				bite = true
				ravaged += 1
				_set_state(State.IDLE)
				_timer = UP_SECONDS
		_:
			if _timer <= 0.0:
				if ravaged >= RAVAGES:
					done = true
				else:
					_next(voxel_at)


## Under ground it goes straight (nothing stops it), at its field's level.
func move(delta: float, _voxel_at: Callable) -> void:
	if state != State.WANDER or target == Vector3i.MAX:
		speed = 0.0
		return
	var goal := Coords.tile_to_world_center(Vector2i(target.x, target.z))
	var to := goal - center()
	var step := minf(Species.WALK_SPEED[species] * GameConst.TILE_SIZE * delta, to.length())
	if to.length() > 0.01:
		heading = to.normalized()
		body.feet += to.normalized() * step
	body.height = float(target.y - GameConst.SEA_LEVEL)
	speed = step / maxf(delta, 0.001) / GameConst.TILE_SIZE
	dirty = true


## Only up can it be hit; hurt, it leaves.
func hurt_by(from: Vector2, damage: int) -> bool:
	if not is_up():
		return false
	var hurt := super.hurt_by(from, damage)
	if hurt:
		done = true
	return hurt


## On to the nearest crop of its field still standing (none: done).
func _next(voxel_at: Callable) -> void:
	var best := Vector3i.MAX
	var nearest := INF
	var here := tile()
	for cell in field:
		if not Farming.is_crop(Voxels.block_of(voxel_at.call(cell))):
			continue
		var distance := Vector2(cell.x - here.x, cell.z - here.y).length()
		if distance < nearest:
			nearest = distance
			best = cell
	target = best
	if best == Vector3i.MAX:
		done = true
	else:
		_set_state(State.WANDER)


func _flat_distance() -> float:
	var goal := Coords.tile_to_world_center(Vector2i(target.x, target.z))
	return goal.distance_to(center()) / GameConst.TILE_SIZE


func _set_state(next: State) -> void:
	if state != next:
		state = next
		dirty = true
