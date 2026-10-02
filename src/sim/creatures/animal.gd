class_name Animal
extends Creature
## An animal (Species: not a monster), run by the server (Creatures): it
## stands and grazes, wanders to places it can walk to, runs away when hurt
## (its herd too) and dies leaving what it gives (Species.DROPS).

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

var _timer := 0.0
var _flee_from := Vector2.ZERO
var _search := 0.0


static func create(kind: int, feet: Vector2, height: float) -> Animal:
	var animal := Animal.new()
	animal.setup(kind, feet, height)
	return animal


func is_moving() -> bool:
	return not _way.is_empty()


func think(delta: float, voxel_at: Callable, rng: RandomNumberGenerator) -> void:
	_immune_tick(delta)
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


## Runs away from `from` (world pixels) for a while.
func scare(from: Vector2) -> void:
	state = State.FLEE
	_timer = FLEE_SECONDS
	_flee_from = from
	_search = FIRST_SEARCH
	_way.clear()
	dirty = true


func _on_hurt(from: Vector2) -> void:
	scare(from)


func _pace() -> float:
	return (Species.FLEE_SPEED if state == State.FLEE else Species.WALK_SPEED)[species]


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
	if not _walk_to(tile() + offset, voxel_at):
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
		if _walk_to(tile() + Vector2i((away.rotated(turn) * FLEE_RANGE).round()), voxel_at):
			return
	# Cornered: it looks again in a moment.
	_search = SEARCH_WAIT
