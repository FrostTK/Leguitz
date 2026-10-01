class_name Crosshair
extends Control
## The small cross in the middle of the screen in first person.

const ARM := 3
const COLOR := Color(1.0, 1.0, 1.0, 0.8)
const SHADOW := Color(0.0, 0.0, 0.0, 0.35)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _draw() -> void:
	var middle := (size / 2.0).floor()
	for pass_offset: Vector2 in [Vector2.ONE, Vector2.ZERO]:
		var color := SHADOW if pass_offset != Vector2.ZERO else COLOR
		var at := middle + pass_offset
		draw_rect(Rect2(at + Vector2(-ARM, 0), Vector2(ARM * 2 + 1, 1)), color)
		draw_rect(Rect2(at + Vector2(0, -ARM), Vector2(1, ARM * 2 + 1)), color)
