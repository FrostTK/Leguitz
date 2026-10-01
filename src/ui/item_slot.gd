class_name ItemSlot
extends Control
## One inventory slot: a small frame, the item's icon and how many there
## are. Draws itself (see show_stack); clicks are reported by `clicked`.

signal clicked(slot: int, right: bool, shift: bool)

const SIZE := 20.0
const ICON := 16.0
const FRAME := Color(0.36, 0.2, 0.08, 0.95)
const FILL := Color(0.16, 0.1, 0.06, 0.55)
const SELECTED := Color(1.0, 0.92, 0.6)

var slot := 0
var selected := false
var library: ItemLibrary

var _item := Items.Id.NONE
var _count := 0


func _init() -> void:
	custom_minimum_size = Vector2.ONE * SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP


func show_stack(item: int, count: int, is_selected := false) -> void:
	if item == _item and count == _count and is_selected == selected:
		return
	_item = item
	_count = count
	selected = is_selected
	tooltip_text = Items.name_key(item) if item != Items.Id.NONE else ""
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	if button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		clicked.emit(slot, button.button_index == MOUSE_BUTTON_RIGHT, button.shift_pressed)
		accept_event()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, FILL)
	draw_rect(rect, SELECTED if selected else FRAME, false, 2.0 if selected else 1.0)
	draw_stack(self, library, _item, _count, size * 0.5)


## Draws a stack (icon and count) centered at `center` on any control.
static func draw_stack(
	canvas: Control, items: ItemLibrary, item: int, count: int, center: Vector2
) -> void:
	if item == Items.Id.NONE or items == null:
		return
	var icon := items.icon(item)
	if icon != null:
		canvas.draw_texture_rect(
			icon, Rect2(center - Vector2.ONE * ICON * 0.5, Vector2.ONE * ICON), false
		)
	if count > 1:
		var font := canvas.get_theme_default_font()
		var text := str(count)
		var at := (
			center
			+ Vector2(
				ICON * 0.5 - font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 6).x + 1.0,
				ICON * 0.5 + 1.0
			)
		)
		canvas.draw_string(
			font,
			at + Vector2.ONE * 0.5,
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			6,
			Color(0, 0, 0, 0.8)
		)
		canvas.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color.WHITE)
