class_name WarningSign
extends Control
## A small warning sign: a dark red triangle holding a "!", beside a
## setting. Hovered, it shows its tooltip: a title and lines of text
## (translation keys: what the setting does, its pros, its cons), on
## parchment.

const SIZE := Vector2(11, 10)
const RED := Color("7b1e2b")
const RED_DARK := Color("4a0f19")
const MARK := Color("f5d9a3")
## The tooltip: how wide (UI units) and its font size.
const TIP_WIDTH := 220.0
const TIP_FONT_SIZE := 8

## The tooltip's title and lines (translation keys).
var title := ""
var lines: Array[String] = []


func _init(title_key := "", line_keys: Array[String] = []) -> void:
	title = title_key
	lines = line_keys
	custom_minimum_size = SIZE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Any text makes the tooltip show; _make_custom_tooltip draws it.
	tooltip_text = title_key


func _draw() -> void:
	var top := Vector2(SIZE.x * 0.5, 0.0)
	var corners := PackedVector2Array([top, Vector2(SIZE.x, SIZE.y), Vector2(0.0, SIZE.y)])
	draw_colored_polygon(corners, RED)
	draw_polyline(corners + PackedVector2Array([top]), RED_DARK, 1.0)
	# The "!": a bar and a dot.
	var middle := floorf(SIZE.x * 0.5) - 0.5
	draw_rect(Rect2(middle, 3.0, 1.0, 3.5), MARK)
	draw_rect(Rect2(middle, 7.5, 1.0, 1.0), MARK)


func _make_custom_tooltip(_for_text: String) -> Object:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = UiTheme.PARCHMENT
	box.border_color = RED
	box.set_border_width_all(1)
	box.set_corner_radius_all(2)
	box.set_content_margin_all(5.0)
	box.anti_aliasing = false
	panel.add_theme_stylebox_override("panel", box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	panel.add_child(column)
	column.add_child(_label(title, RED))
	for key in lines:
		column.add_child(_label(key, UiTheme.INK))
	return panel


func _label(key: String, color: Color) -> Label:
	var label := Label.new()
	label.text = tr(key)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = TIP_WIDTH
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", TIP_FONT_SIZE)
	return label
