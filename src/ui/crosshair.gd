class_name Crosshair
extends Control
## The crosshair in the middle of the screen in first person: a dot and
## four short arms set apart from it, light, each outlined in dark so it
## reads on snow as in a cave.

## An arm's length and its gap from the middle (UI units).
const ARM := 2
const GAP := 2
const COLOR := Color(1.0, 1.0, 1.0, 0.9)
const OUTLINE := Color(0.0, 0.0, 0.0, 0.45)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _draw() -> void:
	var middle := (size / 2.0).floor()
	var parts: Array[Rect2] = [
		Rect2(middle, Vector2.ONE),
		Rect2(middle + Vector2(-GAP - ARM, 0), Vector2(ARM, 1)),
		Rect2(middle + Vector2(GAP + 1, 0), Vector2(ARM, 1)),
		Rect2(middle + Vector2(0, -GAP - ARM), Vector2(1, ARM)),
		Rect2(middle + Vector2(0, GAP + 1), Vector2(1, ARM)),
	]
	for part in parts:
		draw_rect(part.grow(1.0), OUTLINE)
	for part in parts:
		draw_rect(part, COLOR)
