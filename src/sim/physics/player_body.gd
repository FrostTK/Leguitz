class_name PlayerBody
extends RefCounted
## A player's body: feet position on the map (world pixels), height
## (levels) and vertical speed. Like in Minecraft it walks onto tiles up
## to STEP_UP above its feet, falls off edges, and jumps 1.25 levels, so
## it can climb one level (a terrace or a cube block) at a time.
## Shared by the client (prediction) and the server (validation).
##
## `top_at` is a Callable(tile: Vector2i) -> float: the height a body
## stands at on that tile, INF where it cannot go (see
## ChunkData.top_height).

## Collision box (width, depth) at the feet, in world pixels.
const BOX := Vector2(10.0, 6.0)
## Small rises (a water bank) are walked up without jumping.
const STEP_UP := 0.2
## Minecraft's numbers, in levels: gravity 32 /s^2, jumps 1.25 high.
const GRAVITY := 32.0
const JUMP_HEIGHT := 1.25
const MAX_FALL_SPEED := 60.0

var feet := Vector2.ZERO
var height := 0.0
var vertical_speed := 0.0
var on_ground := true
## Set when placed somewhere new: the body lands on the ground as soon as
## the ground there is known (its chunk may still be on its way).
var needs_landing := true


static func jump_speed() -> float:
	return sqrt(2.0 * GRAVITY * JUMP_HEIGHT)


## Highest place to stand under a box (-INF when nothing is known there).
static func support(at: Vector2, top_at: Callable) -> float:
	var best := -INF
	var area := TileCollider.covered_tiles(at, BOX)
	for ty in range(area.position.y, area.end.y):
		for tx in range(area.position.x, area.end.x):
			var top: float = top_at.call(Vector2i(tx, ty))
			if top != INF:
				best = maxf(best, top)
	return best


## Puts the body somewhere new (spawn, teleport, server correction).
func place(at: Vector2) -> void:
	feet = at
	vertical_speed = 0.0
	needs_landing = true


## One frame of movement: `motion` on the map (world pixels), `jump` held.
func step(motion: Vector2, jump: bool, delta: float, top_at: Callable) -> void:
	if needs_landing:
		var ground := support(feet, top_at)
		if ground == -INF:
			return
		height = ground
		on_ground = true
		needs_landing = false
	if motion != Vector2.ZERO:
		var limit := height + STEP_UP
		var blocked := func(tile: Vector2i) -> bool: return top_at.call(tile) > limit
		feet = TileCollider.move(feet, motion, BOX, blocked)
	var below := support(feet, top_at)
	if below == -INF:
		return
	if on_ground and jump:
		vertical_speed = jump_speed()
		on_ground = false
	if not on_ground or height > below + 0.001:
		on_ground = false
		# Exact under constant gravity: same jump whatever the frame rate.
		var next_speed := maxf(vertical_speed - GRAVITY * delta, -MAX_FALL_SPEED)
		height += (vertical_speed + next_speed) * 0.5 * delta
		vertical_speed = next_speed
		if height <= below:
			height = below
			vertical_speed = 0.0
			on_ground = true
	else:
		# Standing: follow small rises of the ground.
		height = below


## Ghost movement (debug): through everything, keeping to the ground.
func glide(motion: Vector2, top_at: Callable) -> void:
	feet += motion
	var below := support(feet, top_at)
	if below != -INF:
		height = below
	vertical_speed = 0.0
	on_ground = true
	needs_landing = false
