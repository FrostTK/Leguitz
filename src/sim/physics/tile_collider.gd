class_name TileCollider
extends RefCounted
## Axis-separated movement of an axis-aligned box among obstacles. Each tile
## holds at most one obstacle box: the whole tile, the foot of a tree, a
## rock... given by a Callable(tile: Vector2i) -> Rect2 (world pixels; an
## empty Rect2 for nothing). Shared by the client (prediction) and the
## server (validation) so both always agree. Positions are the
## bottom-center of the box ("feet").

const MAX_STEP := 4.0
const EPSILON := 0.01


## Moves `feet` by `motion`, stopping at obstacles.
static func move(feet: Vector2, motion: Vector2, box: Vector2, obstacle_at: Callable) -> Vector2:
	var steps := maxi(1, ceili(motion.length() / MAX_STEP))
	var step := motion / steps
	for i in steps:
		if step.x != 0.0:
			feet = _move_axis(feet, Vector2(step.x, 0.0), box, obstacle_at)
		if step.y != 0.0:
			feet = _move_axis(feet, Vector2(0.0, step.y), box, obstacle_at)
	return feet


## True if a box at `feet` overlaps an obstacle.
static func overlaps(feet: Vector2, box: Vector2, obstacle_at: Callable) -> bool:
	return not _hits(feet, box, obstacle_at).is_empty()


## The tiles a box at `feet` touches.
static func covered_tiles(feet: Vector2, box: Vector2) -> Rect2i:
	var ts := float(GameConst.TILE_SIZE)
	var min_tile := Vector2i(floori((feet.x - box.x * 0.5) / ts), floori((feet.y - box.y) / ts))
	var max_tile := Vector2i(
		floori((feet.x + box.x * 0.5 - EPSILON) / ts), floori((feet.y - EPSILON) / ts)
	)
	return Rect2i(min_tile, max_tile - min_tile + Vector2i.ONE)


## The rectangle of a box at `feet` (world pixels).
static func body_rect(feet: Vector2, box: Vector2) -> Rect2:
	return Rect2(feet.x - box.x * 0.5, feet.y - box.y, box.x, box.y)


## Obstacles a box at `feet` overlaps.
static func _hits(feet: Vector2, box: Vector2, obstacle_at: Callable) -> Array[Rect2]:
	var body := body_rect(feet, box)
	var area := covered_tiles(feet, box)
	var hits: Array[Rect2] = []
	for ty in range(area.position.y, area.end.y):
		for tx in range(area.position.x, area.end.x):
			var obstacle: Rect2 = obstacle_at.call(Vector2i(tx, ty))
			if obstacle.has_area() and body.intersects(obstacle):
				hits.append(obstacle)
	return hits


static func _move_axis(
	feet: Vector2, delta: Vector2, box: Vector2, obstacle_at: Callable
) -> Vector2:
	var target := feet + delta
	var hits := _hits(target, box, obstacle_at)
	if hits.is_empty():
		return target
	# Already stuck inside something (e.g. a block placed on us): let go.
	if overlaps(feet, box, obstacle_at):
		return target
	if delta.x > 0.0:
		var edge := INF
		for hit in hits:
			edge = minf(edge, hit.position.x)
		target.x = edge - box.x * 0.5 - EPSILON
	elif delta.x < 0.0:
		var edge := -INF
		for hit in hits:
			edge = maxf(edge, hit.end.x)
		target.x = edge + box.x * 0.5 + EPSILON
	elif delta.y > 0.0:
		var edge := INF
		for hit in hits:
			edge = minf(edge, hit.position.y)
		target.y = edge - EPSILON
	else:
		var edge := -INF
		for hit in hits:
			edge = maxf(edge, hit.end.y)
		target.y = edge + box.y + EPSILON
	if overlaps(target, box, obstacle_at):
		return feet
	return target
