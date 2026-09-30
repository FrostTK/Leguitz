class_name TileCollider
extends RefCounted
## Axis-separated movement of an axis-aligned box against solid tiles.
## Shared by the client (prediction) and the server (validation) so both
## always agree. Positions are the bottom-center of the box ("feet").

const MAX_STEP := 4.0
const EPSILON := 0.01


## Moves `feet` by `motion`, stopping at solid tiles.
## `is_solid` is a Callable(tile: Vector2i) -> bool.
static func move(feet: Vector2, motion: Vector2, box: Vector2, is_solid: Callable) -> Vector2:
	var steps := maxi(1, ceili(motion.length() / MAX_STEP))
	var step := motion / steps
	for i in steps:
		if step.x != 0.0:
			feet = _move_axis(feet, Vector2(step.x, 0.0), box, is_solid)
		if step.y != 0.0:
			feet = _move_axis(feet, Vector2(0.0, step.y), box, is_solid)
	return feet


static func overlaps_solid(feet: Vector2, box: Vector2, is_solid: Callable) -> bool:
	var ts := float(GameConst.TILE_SIZE)
	var min_tx := floori((feet.x - box.x * 0.5) / ts)
	var max_tx := floori((feet.x + box.x * 0.5 - EPSILON) / ts)
	var min_ty := floori((feet.y - box.y) / ts)
	var max_ty := floori((feet.y - EPSILON) / ts)
	for ty in range(min_ty, max_ty + 1):
		for tx in range(min_tx, max_tx + 1):
			if is_solid.call(Vector2i(tx, ty)):
				return true
	return false


static func _move_axis(feet: Vector2, delta: Vector2, box: Vector2, is_solid: Callable) -> Vector2:
	var target := feet + delta
	if not overlaps_solid(target, box, is_solid):
		return target
	# Already stuck inside something (e.g. a block placed on us): let go.
	if overlaps_solid(feet, box, is_solid):
		return target
	var ts := float(GameConst.TILE_SIZE)
	if delta.x > 0.0:
		var tx := floori((target.x + box.x * 0.5) / ts)
		target.x = tx * ts - box.x * 0.5 - EPSILON
	elif delta.x < 0.0:
		var tx := floori((target.x - box.x * 0.5) / ts)
		target.x = (tx + 1) * ts + box.x * 0.5 + EPSILON
	elif delta.y > 0.0:
		var ty := floori(target.y / ts)
		target.y = ty * ts - EPSILON
	elif delta.y < 0.0:
		var ty := floori((target.y - box.y) / ts)
		target.y = (ty + 1) * ts + box.y + EPSILON
	if overlaps_solid(target, box, is_solid):
		return feet
	return target
