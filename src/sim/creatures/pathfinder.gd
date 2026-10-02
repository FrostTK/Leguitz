class_name Pathfinder
extends RefCounted
## Ways for animals over the voxels (A*): from tile to tile, eight ways
## (no cutting corners), up one level at a time (a jump) and down a few
## (MAX_DROP), only where the body fits (`tall` levels free over the
## ground), never into water, lava or the tile of a solid object (a
## trunk, a rock, furniture). Within a budget of nodes: an unreachable
## goal gives the way to the closest place found.

## Levels an animal drops down at most, and the nodes a search may open.
const MAX_DROP := 3
const MAX_NODES := 400
const DIAGONAL := 1.4142
## Extra cost of a climb and of each level dropped (they prefer the flat).
const CLIMB_COST := 0.6
const DROP_COST := 0.3
const NEIGHBORS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
	Vector2i(1, 1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(-1, -1),
]


## The way from `start` (standing at `height`, levels) to `goal`: the
## places to walk through (local units: the middle of each tile, the
## height of its ground), the start left out. Empty when there is no way
## (or the closest place found is not nearer than the start).
static func find(
	start: Vector2i, height: float, goal: Vector2i, voxel_at: Callable, tall: float
) -> Array[Vector3]:
	var heights := {start: height}
	var costs := {start: 0.0}
	var came := {}
	var open: Array[Vector2i] = [start]
	var best := start
	var best_left := _estimate(start, goal)
	var opened := 0
	while not open.is_empty() and opened < MAX_NODES:
		var index := _cheapest(open, costs, goal)
		var here: Vector2i = open[index]
		open.remove_at(index)
		opened += 1
		if here == goal:
			best = goal
			break
		var left := _estimate(here, goal)
		if left < best_left:
			best = here
			best_left = left
		var at: float = heights[here]
		for step in NEIGHBORS:
			var next := here + step
			var ground := ground_at(next, at, voxel_at, tall)
			if is_nan(ground):
				continue
			if step.x != 0 and step.y != 0:
				# Diagonally only past both sides.
				var side_a := ground_at(here + Vector2i(step.x, 0), at, voxel_at, tall)
				var side_b := ground_at(here + Vector2i(0, step.y), at, voxel_at, tall)
				if is_nan(side_a) or is_nan(side_b) or side_a > at + 0.5 or side_b > at + 0.5:
					continue
			var cost: float = costs[here] + (DIAGONAL if step.x != 0 and step.y != 0 else 1.0)
			if ground > at + 0.01:
				cost += CLIMB_COST
			elif ground < at - 0.01:
				cost += DROP_COST * (at - ground)
			if costs.has(next) and costs[next] <= cost:
				continue
			costs[next] = cost
			heights[next] = ground
			came[next] = here
			if not next in open:
				open.append(next)
	if best == start:
		return []
	var way: Array[Vector3] = []
	var node := best
	while node != start:
		way.push_front(Vector3(node.x + 0.5, heights[node], node.y + 0.5))
		node = came[node]
	return way


## The height (levels) a body `tall` levels high stands at on a tile,
## coming from `from` (levels): up one level at most, down MAX_DROP at
## most, with room for it and no liquid; NAN where it cannot.
static func ground_at(tile: Vector2i, from: float, voxel_at: Callable, tall: float) -> float:
	var sea := GameConst.SEA_LEVEL
	var top := floori(from + 1.01) + sea - 1
	var bottom := floori(from - MAX_DROP + 0.01) + sea - 1
	var ground := NAN
	for row in range(top, bottom - 1, -1):
		var voxel: int = voxel_at.call(Vector3i(tile.x, row, tile.y))
		if voxel == Voxels.UNKNOWN or Voxels.is_liquid(voxel):
			return NAN
		if Voxels.is_cube(voxel):
			ground = float(row + 1 - sea)
			break
		if Voxels.is_solid(voxel):
			# A trunk, a rock, furniture: no way through its tile.
			return NAN
	if is_nan(ground):
		return NAN
	# Room for the body, above the ground and up to where it comes from.
	var first := int(ground) + sea
	var last := ceili(maxf(ground, from) + tall - 0.01) + sea
	for row in range(first, last):
		var voxel: int = voxel_at.call(Vector3i(tile.x, row, tile.y))
		if voxel == Voxels.UNKNOWN or Voxels.is_solid(voxel) or Voxels.is_liquid(voxel):
			return NAN
	return ground


static func _estimate(from: Vector2i, to: Vector2i) -> float:
	var dx := absi(to.x - from.x)
	var dy := absi(to.y - from.y)
	return maxi(dx, dy) + (DIAGONAL - 1.0) * mini(dx, dy)


static func _cheapest(open: Array[Vector2i], costs: Dictionary, goal: Vector2i) -> int:
	var best := 0
	var best_score := INF
	for i in open.size():
		var score: float = costs[open[i]] + _estimate(open[i], goal)
		if score < best_score:
			best_score = score
			best = i
	return best
