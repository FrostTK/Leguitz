class_name EffectsRow
extends Control
## What the dishes eaten do (Effects), over the vitality (Hotbar): a round
## badge for each, dark in its color with its sign (a cross healing, a bowl
## keeping hunger off, chevrons for speed, a sword for strength, a pickaxe
## for haste, a flame for warmth, a snowflake for the cold), ringed by an
## arc running out with its time (whole for what lasts as long as its
## cause).

## A badge's size, the room between two, the row's height (UI units).
const BADGE := 11.0
const GAP := 3.0
const HEIGHT := 13.0
## The arcs' smoothness.
const ARC_POINTS := 32
## The signs, 5 x 5 ("#": drawn).
const SIGNS := {
	Effects.Kind.REGEN: ["..#..", "..#..", "#####", "..#..", "..#.."],
	Effects.Kind.FED: [".....", "#...#", "#####", ".###.", "....."],
	Effects.Kind.SWIFT: ["#.#..", ".#.#.", "..#.#", ".#.#.", "#.#.."],
	Effects.Kind.STRONG: ["....#", "...#.", "#.#..", ".#...", "#.#.."],
	Effects.Kind.HASTE: [".###.", "#.#.#", "..#..", "..#..", "..#.."],
	Effects.Kind.WARM: ["..#..", ".##..", ".###.", "#####", ".###."],
	Effects.Kind.COLD: ["#.#.#", ".###.", "##.##", ".###.", "#.#.#"],
}

## Kind -> seconds left, and what each had when last given.
var _effects := {}
var _full := {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows the effects (kind -> seconds left).
func set_effects(effects: Dictionary) -> void:
	for kind: int in effects:
		if effects[kind] > _effects.get(kind, 0.0) + 0.5:
			_full[kind] = effects[kind]
	_effects = effects.duplicate()
	custom_minimum_size.y = HEIGHT if not _effects.is_empty() else 0.0
	queue_redraw()


func _draw() -> void:
	var kinds := _effects.keys()
	kinds.sort()
	var width := kinds.size() * BADGE + (kinds.size() - 1) * GAP
	var x := floorf((size.x - width) * 0.5)
	for kind: int in kinds:
		var middle := Vector2(x + BADGE * 0.5, BADGE * 0.5)
		var radius := BADGE * 0.5
		var color: Color = Effects.COLORS[kind]
		draw_circle(middle, radius - 0.5, color.darkened(0.6), true, -1.0, true)
		var left := 1.0
		if not Effects.LASTING.has(kind):
			left = _effects[kind] / maxf(_full.get(kind, _effects[kind]), 0.01)
		draw_arc(middle, radius - 0.5, 0.0, TAU, ARC_POINTS, Color(color, 0.25), 1.0, true)
		if left > 0.0:
			var start := -PI * 0.5
			draw_arc(
				middle,
				radius - 0.5,
				start,
				start + TAU * clampf(left, 0.0, 1.0),
				ARC_POINTS,
				color,
				1.0,
				true
			)
		var corner := (middle - Vector2(2.5, 2.5)).floor()
		var rows: Array = SIGNS[kind]
		for y in rows.size():
			var row: String = rows[y]
			for column in row.length():
				if row[column] == "#":
					draw_rect(Rect2(corner + Vector2(column, y), Vector2.ONE), color.lightened(0.6))
		x += BADGE + GAP
