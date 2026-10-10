class_name Companion
extends Animal
## A dog or a cat (Species.COMPANIONS), run by the server; Companions tells
## it where its player is, what it goes for and lands its bites. Not tame
## (`owner_name` ""; a stray dog, a wild cat) it lives as animals do. Tame,
## it does what its player told it (`order`):
## - FOLLOW: it keeps at their heel (hurrying when far; sitting when they
##   stand a while); Companions brings it to them when they go too far;
## - STAY: it sits where it was told (`post`), asleep at night;
## - GUARD: a dog keeps the farm animals around its post (it herds back
##   those that stray: `drive_at`), a cat prowls round it.
## Following or guarding, it goes for what it hunts (`target`: a monster or
## a predator for a dog, a mole or a crow for a cat) and bites it when
## close (`strike`, every STRIKE_PAUSE), waiting when it cannot be reached
## yet (`target_ready`: a mole under ground, a crow in the air); a dog
## barks at what comes near (`barking`, Flag.BARK). Its coat (`coat`, among
## Companions.COATS) and all this are saved.

enum Order { FOLLOW, STAY, GUARD }

## Within this far (tiles across, from its middle to the target's) a bite
## lands, and this far up or down (levels).
const REACH := 1.3
const REACH_HEIGHT := 1.2
## Seconds between two bites.
const STRIKE_PAUSE := {Species.Id.DOG: 1.1, Species.Id.CAT: 1.4}
const REPATH_SECONDS := 0.5
## Following: close enough within HEEL tiles; standing there SIT_AFTER
## seconds, it sits.
const HEEL := 2.0
const SIT_AFTER := 4.0
## Staying or guarding: it walks back to its post when farther than AWAY
## tiles; guarding, it walks round it within ROUND (a cat PROWL).
const AWAY := 2.5
const ROUND := 3
const PROWL := 6

var owner_name := ""
var order := Order.FOLLOW
## Where it stays or guards (local units: its feet; INF: where it is).
var post := Vector3.INF
var coat := 0
## Its player (PlayerSession.id, -1: not here), where they stand (world
## pixels; NOWHERE: not here) and how high (levels): Companions.sense.
var owner_id := -1
var owner_at := NOWHERE
var owner_height := 0.0
## What it goes for (local units, its feet; INF: nothing), which creature,
## and whether it can be bitten now.
var target := Vector3.INF
var target_id := -1
var target_ready := true
## Where it stands to drive back a farm animal (local units; INF: none),
## which one, and since when (seconds).
var drive_at := Vector3.INF
var drive_id := -1
var driving := 0.0
## Something comes near: it barks.
var barking := false
## A bite lands this step (Companions.land_blow takes it).
var strike := false
## Seconds until it looks around again (Companions), until a point of
## vitality comes back, since it stood still by its player, until its
## player is told it barks again.
var look_in := 0.0
var mend_in := 0.0
var still := 0.0
var told_in := 0.0
## The animal it last gave up driving back (-1: none).
var gave_up := -1

var _cooldown := 0.0
var _repath := 0.0


static func create(kind: int, feet: Vector2, height: float) -> Companion:
	var companion := Companion.new()
	companion.setup(kind, feet, height)
	return companion


func is_tame() -> bool:
	return owner_name != ""


func look() -> int:
	return coat


func belongs_to(player: int) -> bool:
	return is_tame() and player >= 0 and owner_id == player


func follows(player: int) -> bool:
	return is_tame() and order == Order.FOLLOW and player >= 0 and owner_id == player


func flags() -> int:
	var bits := super.flags()
	if is_tame():
		bits |= Flag.TAME
	if barking:
		bits |= Flag.BARK
	return bits


func has_target() -> bool:
	return target != Vector3.INF


func forget() -> void:
	target = Vector3.INF
	target_id = -1
	target_ready = true


## The middle of its body (local units).
func middle() -> Vector3:
	return bounds().get_center()


## Where it stands (local units: the middle of its box on the ground).
func feet() -> Vector3:
	var at := center() / GameConst.TILE_SIZE
	return Vector3(at.x, body.height, at.y)


## Becomes the companion of the player named `player` (told to follow).
func tame(player: String) -> void:
	owner_name = player
	order = Order.FOLLOW
	post = Vector3.INF
	affection = maxi(affection, 1)
	leader = -1
	forget()
	_way.clear()
	state = State.IDLE
	dirty = true


## Brought beside its player (feet in world pixels, height in levels).
func brought(feet: Vector2, height: float) -> void:
	body.place(feet, height)
	_way.clear()
	_knock = Vector2.ZERO
	forget()
	drive_at = Vector3.INF
	drive_id = -1
	state = State.IDLE
	dirty = true


## Its player tells it what to do from now on: it stays or guards where it
## stands.
func command(next: Order) -> void:
	order = next
	post = feet() if next != Order.FOLLOW else Vector3.INF
	forget()
	drive_at = Vector3.INF
	drive_id = -1
	_way.clear()
	_hurry = false
	still = 0.0
	state = State.SIT if next == Order.STAY else State.IDLE
	dirty = true


func to_dict() -> Dictionary:
	var data := super.to_dict()
	data.merge({"owner": owner_name, "order": order, "post": post, "coat": coat})
	return data


func load_dict(data: Dictionary) -> void:
	super.load_dict(data)
	owner_name = String(data.get("owner", ""))
	order = clampi(int(data.get("order", Order.FOLLOW)), 0, Order.size() - 1) as Order
	var at: Variant = data.get("post", Vector3.INF)
	post = at if at is Vector3 and (at as Vector3).is_finite() else Vector3.INF
	coat = maxi(int(data.get("coat", 0)), 0)


func think(delta: float, voxel_at: Callable, rng: RandomNumberGenerator) -> void:
	_cooldown -= delta
	_repath -= delta
	if not is_tame():
		super.think(delta, voxel_at, rng)
		return
	_immune_tick(delta)
	_timer -= delta
	_search -= delta
	if state == State.FLEE:
		# Hurt by someone: it runs a moment.
		if _timer <= 0.0:
			_rest(State.IDLE, rng)
		elif _way.is_empty() and _search <= 0.0:
			_run_away(voxel_at, rng)
		return
	if has_target():
		_chase(voxel_at)
		return
	if drive_at != Vector3.INF:
		_go(drive_at, 0.6, voxel_at, true)
		return
	if mate_at != NOWHERE:
		_follow(mate_at, NEAR * 0.5, voxel_at)
		return
	if order == Order.FOLLOW and owner_at != NOWHERE:
		_heel(delta, voxel_at)
	elif order == Order.GUARD:
		_guard(voxel_at, rng)
	else:
		_stay(voxel_at)


## Running after its target, it hurries.
func _pace() -> float:
	if state in [State.CHASE, State.STRIKE]:
		return Species.CHASE_SPEED[species]
	return super._pace()


## Goes for its target: a way to it now and then, a bite when close (when
## it can be bitten; else it waits there, barking up at a flier).
func _chase(voxel_at: Callable) -> void:
	var at := middle()
	var toward := Vector2(target.x - at.x, target.z - at.z)
	if toward.length() <= REACH:
		_way.clear()
		if toward.length() > 0.01:
			heading = toward.normalized()
		var reachable := absf(target.y - body.height) <= REACH_HEIGHT
		if not reachable or not target_ready:
			_set_state(State.ALERT if species == Species.Id.DOG else State.CHASE)
			return
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


## At its player's heel, facing them; sitting once they stand still a
## while (it gets up when they walk off).
func _heel(delta: float, voxel_at: Callable) -> void:
	var distance := center().distance_to(owner_at) / GameConst.TILE_SIZE
	var slack := HEEL + (1.0 if state == State.SIT else 0.0)
	if distance > slack:
		still = 0.0
		_follow(owner_at, HEEL, voxel_at)
		return
	if not _way.is_empty():
		_way.clear()
		_hurry = false
	still += delta
	var next := State.SIT if still >= SIT_AFTER or state == State.SIT else State.IDLE
	if next != state:
		var toward := owner_at - center()
		if toward.length() > 0.01:
			heading = toward.normalized()
		_set_state(next)


## Staying: back to its post if it was taken away, then it sits (asleep
## at night).
func _stay(voxel_at: Callable) -> void:
	if post != Vector3.INF and _go(post, AWAY, voxel_at, false):
		return
	_way.clear()
	_set_state(State.SLEEP if night and order == Order.STAY else State.SIT)


## Guarding: back to its post when far, else it sits watching there, and
## now and then walks round it (a cat prowls farther); awake all night.
func _guard(voxel_at: Callable, rng: RandomNumberGenerator) -> void:
	if post == Vector3.INF:
		post = feet()
	var reach := PROWL if species == Species.Id.CAT else ROUND
	if _go(post, reach + AWAY, voxel_at, false):
		return
	match state:
		State.WANDER:
			if _way.is_empty():
				_rest(State.SIT, rng)
		_:
			if _timer <= 0.0:
				if rng.randf() < 0.5:
					var offset := Vector2i(
						rng.randi_range(-reach, reach), rng.randi_range(-reach, reach)
					)
					var goal := Vector2i(floori(post.x), floori(post.z)) + offset
					if _walk_to(goal, voxel_at):
						_set_state(State.WANDER)
						return
				_rest(State.SIT, rng)


## Walks to `goal` (local units) unless within `near` tiles of it (true
## while on its way). `hurry`: at a run.
func _go(goal: Vector3, near: float, voxel_at: Callable, hurry: bool) -> bool:
	var at := feet()
	if Vector2(goal.x - at.x, goal.z - at.z).length() <= near:
		return false
	_hurry = hurry
	if _way.is_empty() or _search <= 0.0:
		_search = SEARCH_WAIT
		if not _walk_to(Vector2i(floori(goal.x), floori(goal.z)), voxel_at):
			return false
	_set_state(State.WANDER)
	return true


func _set_state(next: State) -> void:
	if state != next:
		state = next
		dirty = true
