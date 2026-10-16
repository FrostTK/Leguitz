class_name MoveCheck
extends RefCounted
## Where players say they are (multiplayer, step 3; static, given the
## server). Every move (Msg.player_move) must answer the last place the
## server put them in (`teleport`, numbered: Track.seq; moves sent before
## it are dropped), in solo too. A dedicated server (`check`; a solo game
## trusts its client) then takes it only if, unless the player flies by
## right (creative, a spectator), rides a boat, sits or sleeps:
## - it is not faster than the body goes (PlayerBody's run, a SWIFT dish,
##   LEEWAY more) over the time since the last one: a budget of distance
##   filling with time, at most BURST seconds of it, plus what blows push
##   (`pushed`), SLACK pixels more;
## - it does not go through walls (along the straight way from where it
##   was, the body never sinks into them more than WALL_SLACK) nor down
##   through a floor;
## - it does not rise more than a step and a jump over where it last stood
##   (RISE_SLACK more, and what a blow threw it up), nor hang in the air:
##   HOVER_SLACK after the top of a jump it must come down as it falls;
## else it is put back (a correction): where it was, on the ground under
## it when it rose or hung. A first move after being put somewhere starts
## the track over from there (standing; a teleport fills the budget, a
## correction does not: else each would win a burst again); getting up
## from a seat or a bed (back where the body stood) skips the walls. Falls
## are measured here (from the
## highest point to the landing; a liquid or a ladder ends them): what the
## client says it fell (`fell`) can only add to it. Guard.report tells the
## console.

const LEEWAY := 1.25
const BURST := 1.0
const SLACK := 8.0
const WALL_SLACK := 3.0
const SWEEP_STEP := 4.0
const RISE_SLACK := 0.35
const HOVER_SLACK := 0.6
## This little over the ground, a body may have touched it since the last
## move (levels): a landing and the next jump fall between two moves (they
## come every TICK, the body touches the ground for a frame).
const NEAR_GROUND := 0.5
## A blow's push fades this fast (LocalPlayer's): it carries the body its
## speed over this.
const PUSH_DRAG := 6.0
## Tiles from its seat or bed a body sitting or lying may be said to be.
const OFF_REST := 1.5
## A fall the client tells of this soon after the server counted a landing
## is that one (seconds).
const SAME_LANDING := 0.4


## What the server keeps of a player's moves (Guard.Watch.move).
class Track:
	extends RefCounted
	## The last place the server put them in (moves answer it).
	var seq := 0
	## Whether the next move starts the track over (after a teleport), and
	## whether it gets up from a seat or a bed.
	var fresh := true
	var getting_up := false
	## Whether that fills the budget (a teleport, joining).
	var refill := true
	## The time of the last move (seconds, GameServer.now) and the distance
	## still allowed (world pixels).
	var last := -INF
	var budget := 0.0
	## The height it last stood at and when, the highest point since, how
	## high a blow may still throw it (levels).
	var ground := 0.0
	var ground_time := -INF
	var peak := 0.0
	var hop := 0.0
	## Whether the last move stood on the ground (moves only come when the
	## body moves: standing still, nothing comes until the jump), and when
	## the server last counted a landing.
	var standing := true
	var landed := -INF
	## A fall the client told of, waiting for the landing (levels).
	var claimed := 0.0


## Tells a player where the server puts them (`snap`: a teleport, the
## camera follows at once; else a correction), under a new number.
static func teleport(session: GameServer.PlayerSession, snap := true) -> void:
	var track := session.guard.move
	track.seq += 1
	track.fresh = true
	track.refill = track.refill or snap
	var position := session.position
	var message := (
		Msg.player_teleport(position, session.height, track.seq)
		if snap
		else Msg.player_correction(position, session.height, track.seq)
	)
	session.transport.send(message)


## A blow pushes a player (Msg.PUSH: `speed` world pixels a second, `hop`
## levels a second up): that move is allowed.
static func pushed(session: GameServer.PlayerSession, speed: Vector2, hop: float) -> void:
	var track := session.guard.move
	track.budget += speed.length() / PUSH_DRAG
	track.hop = maxf(track.hop, hop * hop / (2.0 * PlayerBody.GRAVITY))


## The fastest a player may go (world pixels a second).
static func top_speed(session: GameServer.PlayerSession) -> float:
	var speed := PlayerBody.WALK_SPEED * PlayerBody.SPRINT_MULTIPLIER * LEEWAY
	if Effects.has(session.effects, Effects.Kind.SWIFT):
		speed *= Effects.SWIFT_SPEED
	return speed


## Checks a move of `session` to `pos` (world pixels), `height` (levels),
## the client saying it fell `fell` (see the class). Returns the fall to
## count (levels; 0: none), or -1 when the move is refused (it was put
## back).
static func check(
	server: GameServer, session: GameServer.PlayerSession, pos: Vector2, height: float, fell: float
) -> float:
	var track := session.guard.move
	var now := server.now()
	if now - track.landed > SAME_LANDING:
		track.claimed = maxf(track.claimed, fell)
	if _free(server, session) or _resting(session, pos):
		_stand(track, height, now)
		track.last = now
		track.claimed = 0.0
		return 0.0
	var getting_up := track.fresh and track.getting_up
	if track.fresh:
		track.fresh = false
		track.getting_up = false
		_stand(track, session.height, now)
		if track.refill:
			track.refill = false
			track.budget = top_speed(session) * BURST
			track.last = now
	var voxel_at := server.world.loaded_voxel_at
	var speed := top_speed(session)
	var since := clampf(now - track.last, 0.0, BURST)
	track.last = now
	track.budget = minf(track.budget + speed * since, maxf(track.budget, speed * BURST))
	var distance := pos.distance_to(session.position)
	if distance > track.budget + SLACK:
		return _refuse(server, session, "GUARD_TOO_FAST", false)
	track.budget = maxf(track.budget - distance, 0.0)
	if not getting_up and _through_walls(session, pos, height, voxel_at):
		return _refuse(server, session, "GUARD_THROUGH_WALLS", false)
	if (
		PlayerBody.liquid_at(pos, height, voxel_at) != Voxels.AIR
		or PlayerBody.ladder_at(pos, height, voxel_at)
	):
		# Swimming and climbing go up as they will; a fall ends there.
		_stand(track, height, now)
		track.claimed = 0.0
		return 0.0
	var top := track.ground + PlayerBody.STEP_UP + PlayerBody.JUMP_HEIGHT + RISE_SLACK + track.hop
	if height > top:
		return _refuse(server, session, "GUARD_FLYING", true)
	var ground := PlayerBody.support(pos, height + PlayerBody.STEP_UP, voxel_at)
	var near := ground != -INF and height <= ground + NEAR_GROUND
	if track.standing and not near:
		# It left the ground since the last move.
		track.ground_time = now
	track.standing = near
	var apex := PlayerBody.jump_speed() / PlayerBody.GRAVITY
	var falling := now - track.ground_time - apex - HOVER_SLACK
	if not near and falling > 0.0:
		if height > top - 0.5 * PlayerBody.GRAVITY * falling * falling:
			return _refuse(server, session, "GUARD_HOVERING", true)
	track.peak = maxf(track.peak, height)
	if not near:
		return 0.0
	var fall := maxf(maxf(track.peak - ground, 0.0), track.claimed)
	if fall > 0.0:
		track.landed = now
	_stand(track, ground, now)
	track.peak = maxf(ground, height)
	track.claimed = 0.0
	return fall


## Flying by right, aboard a boat: nothing to check.
static func _free(server: GameServer, session: GameServer.PlayerSession) -> bool:
	return GameModes.creative(server) or session.spectator or session.boat >= 0


## Sitting or lying down, and said to be by the seat or the bed; moved off
## it, they got up: the seat is free, and the next move starts over.
static func _resting(session: GameServer.PlayerSession, pos: Vector2) -> bool:
	var rest := session.sits_on
	if rest == GameServer.NO_CELL and session.sleeping:
		rest = session.bed
	if rest == GameServer.NO_CELL:
		return false
	var spot := Vector2(rest.x + 0.5, rest.z + 0.5) * GameConst.TILE_SIZE
	if pos.distance_to(spot) <= OFF_REST * GameConst.TILE_SIZE:
		return true
	session.sits_on = GameServer.NO_CELL
	session.guard.move.fresh = true
	session.guard.move.getting_up = true
	return false


## Whether a move goes through something solid: along the way from where
## it was (at the higher of both heights, a sample every SWEEP_STEP) and
## where it ends, the body sinks more than WALL_SLACK into it (sliding
## along a wall or round a corner, the client's small steps take another
## way than the straight one); or it goes down through a floor.
static func _through_walls(
	session: GameServer.PlayerSession, pos: Vector2, height: float, voxel_at: Callable
) -> bool:
	var high := maxf(height, session.height)
	var from := session.position
	var steps := maxi(1, ceili(from.distance_to(pos) / SWEEP_STEP))
	for i in range(1, steps + 1):
		var at := from.lerp(pos, float(i) / steps)
		if _sunk(at, height if i == steps else high, voxel_at) > WALL_SLACK:
			return true
	if height < session.height - PlayerBody.STEP_UP:
		var floor_under := PlayerBody.support(pos, session.height + PlayerBody.EPSILON, voxel_at)
		return floor_under > height + PlayerBody.STEP_UP
	return false


## How deep (world pixels) a body at `at`, `height` sinks into what blocks
## it: the narrower side of its overlap with each obstacle, the deepest.
static func _sunk(at: Vector2, height: float, voxel_at: Callable) -> float:
	var body := TileCollider.body_rect(at, PlayerBody.BOX)
	var area := TileCollider.covered_tiles(at, PlayerBody.BOX)
	var deepest := 0.0
	for ty in range(area.position.y, area.end.y):
		for tx in range(area.position.x, area.end.x):
			var blocked := PlayerBody.obstacle(Vector2i(tx, ty), height, voxel_at)
			if blocked.has_area() and blocked.intersects(body):
				var overlap := blocked.intersection(body).size
				deepest = maxf(deepest, minf(overlap.x, overlap.y))
	return deepest


## The body stands at `height` at `now`: a jump or a fall starts there.
static func _stand(track: Track, height: float, now: float) -> void:
	track.ground = height
	track.ground_time = now
	track.peak = height
	track.hop = 0.0
	track.standing = true


## Puts a player back where they were (`down`: on the ground under it),
## tells the console. Returns -1 (refused).
static func _refuse(
	server: GameServer, session: GameServer.PlayerSession, key: String, down: bool
) -> float:
	if down:
		var voxel_at := server.world.loaded_voxel_at
		var ground := PlayerBody.support(session.position, session.height, voxel_at)
		if ground != -INF:
			session.height = ground
	Guard.report(server, session, key)
	teleport(session, false)
	return -1.0
