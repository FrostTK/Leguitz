class_name Predator
extends Animal
## A wolf or a bear (Species.PREDATORS), run by the server; Wildlife gives
## it what it goes for and lands its blows. With a target (a prey animal,
## or a player: `target`, their feet in local units) it chases it and
## strikes when close (`strike`, every STRIKE_PAUSE). Without one it
## wanders as animals do; a bear sleeps at night, wolves roam (they hunt
## by night), and a bear warns a player who comes close (State.ALERT)
## before it charges. Hurt, it does not run away: it turns on who hit it
## (`provoked`). Saved like the animals (not what it was after).

## Within this far (tiles, from its middle to the target's) a blow lands.
const REACH := 1.3
## Seconds between two blows.
const STRIKE_PAUSE := {Species.Id.WOLF: 1.2, Species.Id.BEAR: 1.8}
const REPATH_SECONDS := 0.6
## A chase after prey ends after this long (seconds): it tries again later.
const CHASE_SECONDS := 20.0

## What it goes for (local units, the feet; INF: nothing): a creature
## (`target_id`) or a player (`target_player`, their session id).
var target := Vector3.INF
var target_id := -1
var target_player := -1
## Seconds until it hunts again (fed: Wildlife.HUNGER_SECONDS).
var hunger := 0.0
## A blow lands this step (Wildlife.land_blow takes it).
var strike := false
## Hurt by a blow from there (world pixels; INF: not hurt): Wildlife turns
## it on the player there.
var provoked := Vector2.INF
## The player it is angry with (session id, -1: none) and how much longer
## (seconds).
var angry_at := -1
var anger := 0.0
## How long a player has stood too close (a bear warns, then charges).
var warned := 0.0
## How long it has been chasing prey.
var chased := 0.0

var _cooldown := 0.0
var _repath := 0.0


static func create(kind: int, feet: Vector2, height: float) -> Predator:
	var predator := Predator.new()
	predator.setup(kind, feet, height)
	return predator


func has_target() -> bool:
	return target != Vector3.INF


func forget() -> void:
	target = Vector3.INF
	target_id = -1
	target_player = -1
	chased = 0.0


## The middle of its body (local units).
func middle() -> Vector3:
	var at := center() / GameConst.TILE_SIZE
	return Vector3(at.x, body.height + body.tall * 0.5, at.y)


## How far (tiles, across) its target is.
func target_distance() -> float:
	if not has_target():
		return INF
	return Vector2(target.x - middle().x, target.z - middle().z).length()


func think(delta: float, voxel_at: Callable, rng: RandomNumberGenerator) -> void:
	_immune_tick(delta)
	_timer -= delta
	_search -= delta
	_cooldown -= delta
	_repath -= delta
	hunger = maxf(hunger - delta, 0.0)
	if has_target():
		_chase(voxel_at)
		return
	if state == State.ALERT:
		return
	if state in [State.CHASE, State.STRIKE, State.FLEE]:
		_rest(State.IDLE, rng)
	if night and species == Species.Id.BEAR:
		_bed(voxel_at)
		return
	match state:
		State.IDLE, State.GRAZE, State.SLEEP:
			if _timer <= 0.0 or state == State.SLEEP:
				if rng.randf() < 0.6:
					_wander(voxel_at, rng)
				else:
					_rest(State.IDLE, rng)
		State.WANDER:
			if _way.is_empty():
				_rest(State.IDLE, rng)


## Warns a player too close (a bear): it stands up, facing them.
func warn(toward: Vector2) -> void:
	if toward.length() > 0.01:
		heading = toward.normalized()
	_way.clear()
	_set_state(State.ALERT)


## Calms down after a warning.
func calm() -> void:
	if state == State.ALERT:
		_set_state(State.IDLE)


func _on_hurt(from: Vector2) -> void:
	provoked = from


func _pace() -> float:
	if state in [State.CHASE, State.STRIKE]:
		return Species.CHASE_SPEED[species]
	return super._pace()


## Goes for its target: a way to it now and then, a blow when close.
func _chase(voxel_at: Callable) -> void:
	var toward := Vector2(target.x - middle().x, target.z - middle().z)
	if toward.length() <= REACH and absf(target.y - body.height) < 1.5:
		_way.clear()
		if toward.length() > 0.01:
			heading = toward.normalized()
		if _cooldown <= 0.0:
			strike = true
			_cooldown = STRIKE_PAUSE[species]
			_set_state(State.STRIKE)
		elif state == State.STRIKE and _cooldown < STRIKE_PAUSE[species] - 0.4:
			_set_state(State.CHASE)
		return
	if state != State.CHASE:
		_set_state(State.CHASE)
	if _repath <= 0.0 or _way.is_empty():
		_repath = REPATH_SECONDS
		_walk_to(Vector2i(floori(target.x), floori(target.z)), voxel_at)


func _set_state(next: State) -> void:
	if state != next:
		state = next
		dirty = true
