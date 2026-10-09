class_name EffectsRow
extends Control
## What the dishes eaten do (Effects), over the vitality (Hotbar): a badge
## for each, in its color with its sign (a cross healing, a bowl keeping
## hunger off, chevrons for speed, a sword for strength, a pickaxe for
## haste), a bar under it running out with its time.

const BADGE := 9.0
const GAP := 3.0
const HEIGHT := 13.0
## The signs, 5 x 5 ("#": drawn).
const SIGNS := {
	Effects.Kind.REGEN: ["..#..", "..#..", "#####", "..#..", "..#.."],
	Effects.Kind.FED: [".....", "#...#", "#####", ".###.", "....."],
	Effects.Kind.SWIFT: ["#.#..", ".#.#.", "..#.#", ".#.#.", "#.#.."],
	Effects.Kind.STRONG: ["....#", "...#.", "#.#..", ".#...", "#.#.."],
	Effects.Kind.HASTE: [".###.", "#.#.#", "..#..", "..#..", "..#.."],
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
		var at := Vector2(x, 0.0)
		var color: Color = Effects.COLORS[kind]
		draw_rect(Rect2(at, Vector2.ONE * BADGE), UiTheme.WOOD_DARK)
		draw_rect(Rect2(at + Vector2.ONE, Vector2.ONE * (BADGE - 2.0)), color.darkened(0.25))
		var rows: Array = SIGNS[kind]
		for y in rows.size():
			var row: String = rows[y]
			for column in row.length():
				if row[column] == "#":
					draw_rect(
						Rect2(at + Vector2(column + 2, y + 2), Vector2.ONE), color.lightened(0.6)
					)
		var left: float = _effects[kind] / maxf(_full.get(kind, _effects[kind]), 0.01)
		var bar := Rect2(at + Vector2(0.0, BADGE + 1.0), Vector2(BADGE, 2.0))
		draw_rect(bar, UiTheme.WOOD_DARK)
		draw_rect(Rect2(bar.position, Vector2(roundf(BADGE * clampf(left, 0.0, 1.0)), 2.0)), color)
		x += BADGE + GAP
