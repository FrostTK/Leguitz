class_name Animal
extends Creature
## An animal (Species: not a monster), run by the server (Creatures): it
## stands and grazes, wanders to places it can walk to, runs away when hurt
## (its herd too) and dies leaving what it gives (Species.DROPS). Farm life
## (Husbandry): fed, it looks for a mate and a young one is born, small
## until it grows up; on a lead it follows its player; at night it sleeps,
## under a roof if it is cared for and finds one; it loves the players who
## pet and feed it, and gives wool, milk or eggs (its timers here,
## the rules in Husbandry).

## What players see of it (Msg.ENTITY_*, `flags`): young, shorn, in love.
enum Flag { BABY = 1, SHORN = 2, LOVE = 4 }

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
## A young one's body, of a grown one's.
const BABY_SIZE := 0.6
## Following something (its player, its mate): close enough within this
## many tiles; it hurries farther than HURRY.
const NEAR := 1.2
const HURRY := 5.0
## Somewhere it is not (INF: nowhere), and no shelter.
const NOWHERE := Vector2.INF
const NO_SHELTER := Vector2i.MAX

## Seconds left as a young one (0: grown), wanting a mate (fed), resting
## after a young one was born (all of them paced when set: Husbandry).
var age := 0.0
var love := 0.0
var breed_rest := 0.0
## How much it loves its players (0 to Husbandry.MAX_AFFECTION), and the
## days (WorldClock.day_index) it was last petted, fed and cared for
## (petted, fed or sheltered: Husbandry.update takes a point off a day
## without care).
var affection := 0
var petted_day := -1
var fed_day := -1
var cared_day := -1
## Shorn (its wool grows back in `wool_in` seconds); milk again in
## `milk_in`, an egg in `egg_in` (seconds, paced).
var shorn := false
var wool_in := 0.0
var milk_in := 0.0
var egg_in := 0.0
## The player leading it on a lead (PlayerSession.id, -1: none; not saved)
## and where they stand (world pixels), where its mate stands, whether it
## is night and where it sleeps tonight (Husbandry.sense, every step).
var leader := -1
var leader_at := NOWHERE
var mate_at := NOWHERE
var night := false
var shelter := NO_SHELTER
var shelter_searched := false

var _timer := 0.0
var _flee_from := Vector2.ZERO
var _search := 0.0
var _hurry := false


static func create(kind: int, feet: Vector2, height: float) -> Animal:
	var animal := Animal.new()
	animal.setup(kind, feet, height)
	return animal


func is_moving() -> bool:
	return not _way.is_empty()


func is_baby() -> bool:
	return age > 0.0


func led_by() -> int:
	return leader


## What players see of it (Flag bits).
func flags() -> int:
	var bits := 0
	if is_baby():
		bits |= Flag.BABY
	if shorn:
		bits |= Flag.SHORN
	if love > 0.0:
		bits |= Flag.LOVE
	return bits


## Makes it young for `seconds` (a small body), or grown (0).
func set_age(seconds: float) -> void:
	age = maxf(seconds, 0.0)
	var size := BABY_SIZE if age > 0.0 else 1.0
	body.box = Species.BOX[species] * size
	body.tall = Species.TALL[species] * size
	dirty = true


func to_dict() -> Dictionary:
	var data := super.to_dict()
	(
		data
		. merge(
			{
				"age": age,
				"breed_rest": breed_rest,
				"affection": affection,
				"petted": petted_day,
				"fed": fed_day,
				"cared": cared_day,
				"shorn": shorn,
				"wool_in": wool_in,
				"milk_in": milk_in,
				"egg_in": egg_in,
			}
		)
	)
	return data


func load_dict(data: Dictionary) -> void:
	super.load_dict(data)
	set_age(_finite(data.get("age", 0.0)))
	breed_rest = _finite(data.get("breed_rest", 0.0))
	affection = clampi(int(data.get("affection", 0)), 0, Husbandry.MAX_AFFECTION)
	petted_day = int(data.get("petted", -1))
	fed_day = int(data.get("fed", -1))
	cared_day = int(data.get("cared", -1))
	shorn = bool(data.get("shorn", false))
	wool_in = _finite(data.get("wool_in", 0.0))
	milk_in = _finite(data.get("milk_in", 0.0))
	egg_in = _finite(data.get("egg_in", 0.0))


func think(delta: float, voxel_at: Callable, rng: RandomNumberGenerator) -> void:
	_immune_tick(delta)
	_timer -= delta
	_search -= delta
	if state == State.FLEE:
		if _timer <= 0.0:
			_rest(State.IDLE, rng)
		elif _way.is_empty() and _search <= 0.0:
			_run_away(voxel_at, rng)
		return
	if leader_at != NOWHERE:
		_follow(leader_at, Husbandry.LEAD_SLACK, voxel_at)
		return
	if mate_at != NOWHERE:
		_follow(mate_at, NEAR * 0.5, voxel_at)
		return
	if night:
		_bed(voxel_at)
		return
	match state:
		State.IDLE, State.GRAZE, State.SLEEP:
			if _timer <= 0.0 or state == State.SLEEP:
				if state != State.SLEEP and rng.randf() < 0.55:
					_wander(voxel_at, rng)
				else:
					_rest(State.GRAZE if rng.randf() < 0.5 else State.IDLE, rng)
		State.WANDER:
			if _way.is_empty():
				_rest(State.IDLE, rng)


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
	var running := state == State.FLEE or _hurry
	return (Species.FLEE_SPEED if running else Species.WALK_SPEED)[species]


func _rest(next: State, rng: RandomNumberGenerator) -> void:
	state = next
	_timer = rng.randf_range(REST_SECONDS.x, REST_SECONDS.y)
	_way.clear()
	_hurry = false
	dirty = true


## Walks towards `goal` (world pixels) until within `near` tiles of it,
## looking for its way again now and then (it moves).
func _follow(goal: Vector2, near: float, voxel_at: Callable) -> void:
	var distance := center().distance_to(goal) / GameConst.TILE_SIZE
	if distance <= near:
		if state != State.IDLE or not _way.is_empty():
			state = State.IDLE
			_way.clear()
			_hurry = false
			dirty = true
		return
	_hurry = distance > HURRY
	if _way.is_empty() or _search <= 0.0:
		_search = SEARCH_WAIT
		var goal_tile := Coords.world_to_tile(goal)
		if goal_tile != tile() and _walk_to(goal_tile, voxel_at):
			state = State.WANDER
			dirty = true


## At night: to its shelter if it has one, then asleep.
func _bed(voxel_at: Callable) -> void:
	if state == State.SLEEP:
		return
	if shelter != NO_SHELTER and tile() != shelter:
		if _way.is_empty() and _search <= 0.0:
			_search = SEARCH_WAIT * 4.0
			if not _walk_to(shelter, voxel_at):
				shelter = NO_SHELTER
		if not _way.is_empty():
			state = State.WANDER
			return
		if shelter != NO_SHELTER and _search > 0.0:
			return
	state = State.SLEEP
	_way.clear()
	_hurry = false
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


static func _finite(value: Variant) -> float:
	var number := float(value)
	return number if is_finite(number) and number > 0.0 else 0.0
