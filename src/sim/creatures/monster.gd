class_name Monster
extends Creature
## A monster (Species.MONSTERS), run by the server (Creatures), which tells
## it the player it hunts (`hunt`/`forget`) and whether it stands in the
## light (`lit`), and lands its blows (`strike`: set when one hits). Each
## kind hunts its own way:
## - lantern moth: flutters round the player at night, now and then dives
##   at them (its blow puts their lantern out a while), then draws back;
## - shade lurker: walks up to them in the dark, freezes in the light (lava,
##   fire, daylight), strikes with its long arms;
## - rock mimic: lies in caves as a rock (DORMANT) until someone comes close
##   or hits it, lunges and bites, and settles again when left alone;
## - will-o'-wisp: floats a few tiles away (it lures), drawing back when
##   approached, and now and then darts in to burn.

## A blow lands this close (tiles from the middle of its box to the
## player's chest).
const REACH := 1.1
## Seconds between two blows of the walkers; a dive gives up after
## DIVE_SECONDS, then the flier draws back for BACK_SECONDS.
const STRIKE_PAUSE := {Species.Id.SHADE_LURKER: 1.6, Species.Id.ROCK_MIMIC: 2.0}
const DIVE_SECONDS := 2.5
const BACK_SECONDS := 1.5
## Seconds between a flier's dives.
const DIVE_EVERY := {Species.Id.LANTERN_MOTH: Vector2(3.0, 6.0), Species.Id.WISP: Vector2(6.0, 9.0)}
## Walkers look for their way to the player this often.
const REPATH_SECONDS := 0.7
## A moth circles this far round the player, this high over them; a wisp
## keeps between WISP_NEAR and WISP_FAR tiles away, this high.
const MOTH_RING := 3.0
const MOTH_ABOVE := 2.5
const WISP_NEAR := 4.0
const WISP_FAR := 7.0
const WISP_ABOVE := 1.0
## A mimic wakes with someone this close (tiles), lunges at them, and
## settles again after CALM_SECONDS with nobody near.
const WAKE_RANGE := 2.5
const LUNGE := Vector2(9.0, 6.0)
const CALM_SECONDS := 6.0
## Fliers without prey drift this far from where they came out.
const DRIFT_RANGE := 6.0

## The player hunted: their feet (local units: tiles across, levels up),
## Vector3.INF when none.
var prey := Vector3.INF
## Standing in the light (the shade lurker freezes).
var lit := false
## A blow just landed (Monsters.land_blow hurts the player and clears it).
var strike := false
## The id of the player hunted (-1: none), and seconds before the light it
## stands in is felt again (Monsters.sense).
var prey_id := -1
var light_wait := 0.0

var _timer := 0.0
var _cooldown := 0.0
var _repath := 0.0
var _phase := 0.0
var _goal := Vector3.INF
var _home := Vector3.ZERO


static func create(kind: int, feet: Vector2, height: float) -> Monster:
	var monster := Monster.new()
	monster.setup(kind, feet, height)
	var middle := monster.center() / GameConst.TILE_SIZE
	monster._home = Vector3(middle.x, height, middle.y)
	if kind == Species.Id.ROCK_MIMIC:
		monster.state = State.DORMANT
	return monster


## Hunts the player whose feet are at `feet` (world pixels) and `height`.
func hunt(feet: Vector2, height: float) -> void:
	var at := feet / GameConst.TILE_SIZE
	prey = Vector3(at.x, height, at.y)


func forget() -> void:
	prey = Vector3.INF


func has_prey() -> bool:
	return prey != Vector3.INF


## How far (tiles) its middle is from the prey's chest.
func prey_distance() -> float:
	if not has_prey():
		return INF
	return middle().distance_to(prey + Vector3(0.0, 0.9, 0.0))


func think(delta: float, voxel_at: Callable, rng: RandomNumberGenerator) -> void:
	_immune_tick(delta)
	_timer -= delta
	_cooldown -= delta
	_repath -= delta
	_phase += delta
	match species:
		Species.Id.LANTERN_MOTH, Species.Id.WISP:
			_think_flier(rng)
		Species.Id.SHADE_LURKER:
			_think_lurker(voxel_at)
		_:
			_think_mimic(voxel_at)


func move(delta: float, voxel_at: Callable) -> void:
	if Species.FLIERS.has(species):
		_fly(delta, voxel_at)
		return
	if state in [State.DORMANT, State.FROZEN, State.STRIKE]:
		_way.clear()
	super.move(delta, voxel_at)


func _on_hurt(_from: Vector2) -> void:
	if state == State.DORMANT:
		_wake()


func _pace() -> float:
	match state:
		State.CHASE, State.STRIKE:
			return Species.CHASE_SPEED[species]
		State.FLEE:
			return Species.FLEE_SPEED[species]
	return Species.WALK_SPEED[species]


# ---------------------------------------------------------------- fliers


## Fliers: drift without prey; with one, the moth circles above them and
## dives, the wisp keeps its distance and darts; both draw back after.
func _think_flier(rng: RandomNumberGenerator) -> void:
	var dives: Vector2 = DIVE_EVERY[species]
	match state:
		State.STRIKE:
			if not has_prey() or _timer <= 0.0:
				_draw_back()
			elif prey_distance() <= REACH:
				strike = true
				_draw_back()
		State.FLEE:
			if _timer <= 0.0:
				_set_state(State.CHASE if has_prey() else State.WANDER)
				_timer = rng.randf_range(dives.x, dives.y)
		_:
			if not has_prey():
				_set_state(State.WANDER)
				if _goal == Vector3.INF or middle().distance_to(_goal) < 0.5 or _timer <= 0.0:
					var drift := (
						Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf() * DRIFT_RANGE
					)
					var rise := rng.randf_range(
						1.0, 3.5 if species == Species.Id.LANTERN_MOTH else 1.5
					)
					_goal = _home + Vector3(drift.x, rise, drift.y)
					_timer = 4.0
			elif state != State.CHASE:
				_set_state(State.CHASE)
				_timer = rng.randf_range(dives.x, dives.y)
			elif _timer <= 0.0:
				_set_state(State.STRIKE)
				_timer = DIVE_SECONDS
	if has_prey():
		var chest := prey + Vector3(0.0, 0.9, 0.0)
		match state:
			State.STRIKE:
				_goal = chest
			State.FLEE:
				var away := middle() - chest
				away.y = 0.0
				if away.length() < 0.01:
					away = Vector3.RIGHT
				_goal = middle() + away.normalized() * 3.0 + Vector3(0.0, 1.5, 0.0)
			State.CHASE:
				_goal = _keep_near()


## Where a flier hovers while hunting: the moth round and over the prey,
## the wisp a few tiles off it (drawing back when it comes, coming when it
## leaves).
func _keep_near() -> Vector3:
	if species == Species.Id.LANTERN_MOTH:
		var ring := Vector2.RIGHT.rotated(_phase * 1.3) * MOTH_RING
		var bob := sin(_phase * 5.0) * 0.4
		return prey + Vector3(ring.x, MOTH_ABOVE + bob, ring.y)
	var off := Vector2(middle().x - prey.x, middle().z - prey.z)
	var distance := off.length()
	if distance < 0.01:
		off = Vector2.RIGHT
	var keep := clampf(distance, WISP_NEAR, WISP_FAR)
	var around := off.normalized().rotated(0.25) * keep
	return Vector3(
		prey.x + around.x, prey.y + WISP_ABOVE + sin(_phase * 2.0) * 0.2, prey.z + around.y
	)


func _draw_back() -> void:
	_set_state(State.FLEE)
	_timer = BACK_SECONDS


func _fly(delta: float, voxel_at: Callable) -> void:
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
		up = to.y > 0.15
		down = to.y < -0.15
	body.flying = true
	body.fly(motion, up, down, delta, voxel_at)
	speed = body.feet.distance_to(before) / maxf(delta, 0.001) / GameConst.TILE_SIZE
	if speed > 0.01 or absf(body.height - before_height) > 0.001:
		dirty = true


# ---------------------------------------------------------------- walkers


## The lurker: frozen in the light; in the dark it walks up to its prey
## and strikes.
func _think_lurker(voxel_at: Callable) -> void:
	if lit:
		_set_state(State.FROZEN)
		return
	if state == State.FROZEN:
		_set_state(State.IDLE)
	_hunt_on_foot(voxel_at)


## The mimic: a rock until someone comes close; then it hunts, and
## settles again once left alone a while.
func _think_mimic(voxel_at: Callable) -> void:
	if state == State.DORMANT:
		if prey_distance() <= WAKE_RANGE:
			_wake()
		return
	if has_prey():
		_timer = CALM_SECONDS
	elif _timer <= 0.0:
		_set_state(State.DORMANT)
		_way.clear()
		return
	_hunt_on_foot(voxel_at)


## Walks up to the prey (a way looked for again every REPATH_SECONDS) and
## strikes when close, every STRIKE_PAUSE.
func _hunt_on_foot(voxel_at: Callable) -> void:
	if not has_prey():
		if state != State.IDLE:
			_set_state(State.IDLE)
			_way.clear()
		return
	if prey_distance() <= REACH:
		_way.clear()
		var toward := Vector2(prey.x - middle().x, prey.z - middle().z)
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
		_walk_to(Vector2i(floori(prey.x), floori(prey.z)), voxel_at)


## The mimic wakes: it lunges at its prey.
func _wake() -> void:
	_set_state(State.CHASE)
	_timer = CALM_SECONDS
	var toward := Vector2(1.0, 0.0)
	if has_prey():
		toward = Vector2(prey.x - middle().x, prey.z - middle().z)
	if toward.length() > 0.01:
		heading = toward.normalized()
	_knock = heading * LUNGE.x * GameConst.TILE_SIZE
	if body.on_ground:
		body.vertical_speed = LUNGE.y
		body.on_ground = false


func _set_state(next: State) -> void:
	if state != next:
		state = next
		dirty = true


## The middle of its body (local units).
func middle() -> Vector3:
	var at := center() / GameConst.TILE_SIZE
	return Vector3(at.x, body.height + body.tall * 0.5, at.y)
