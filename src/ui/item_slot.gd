class_name ItemSlot
extends Control
## One inventory slot: a small frame, the item's icon and how many there
## are, or for a worn tool what is left of it (a bar going from green to
## red). Draws itself (see show_stack); clicks are reported by `clicked`.
## Empty, it may show the shape of what goes in it (`hint`, armor slots).

signal clicked(slot: int, right: bool, shift: bool)

const SIZE := 20.0
const ICON := 16.0
const FRAME := Color(0.36, 0.2, 0.08, 0.95)
const FILL := Color(0.16, 0.1, 0.06, 0.55)
const SELECTED := Color(1.0, 0.92, 0.6)
## The name of the item under the mouse (draw_name): its box, the room
## around the text, and where it sits from the mouse (above on the right).
const NAME_FILL := Color(0.13, 0.07, 0.03, 0.94)
const NAME_PADDING := Vector2(4.0, 2.0)
const NAME_OFFSET := Vector2(9.0, -15.0)
const HINT := Color(0.0, 0.0, 0.0, 0.35)

var slot := 0
var selected := false
var library: ItemLibrary
## Drawn as a dark shape while the slot is empty (Items.Id.NONE: nothing).
var hint := Items.Id.NONE

var _item := Items.Id.NONE
var _count := 0
var _wear := 0
## The icon drawn (icons are rendered after the game starts: redraw once
## the item's arrives).
var _icon: Texture2D


func _init() -> void:
	custom_minimum_size = Vector2.ONE * SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP


func show_stack(item: int, count: int, is_selected := false, wear := 0) -> void:
	var icon := library.icon(item) if library != null else null
	if (
		item == _item
		and count == _count
		and is_selected == selected
		and icon == _icon
		and wear == _wear
	):
		return
	_icon = icon
	_item = item
	_count = count
	_wear = wear
	selected = is_selected
	queue_redraw()


## The item shown (Items.Id.NONE: empty).
func shown_item() -> int:
	return _item


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
	draw_stack(self, library, _item, _count, size * 0.5, _wear)
	if _item == Items.Id.NONE and hint != Items.Id.NONE and library != null:
		var shape := library.icon(hint)
		if shape != null:
			var corner := size * 0.5 - Vector2.ONE * ICON * 0.5
			draw_texture_rect(shape, Rect2(corner, Vector2.ONE * ICON), false, HINT)
		else:
			# Icons come after the start: try again.
			queue_redraw.call_deferred()


## Draws an item's name in a dark box beside `at` (the mouse) on any
## control, kept inside it.
static func draw_name(canvas: Control, item: int, at: Vector2) -> void:
	if item == Items.Id.NONE:
		return
	var font := canvas.get_theme_default_font()
	var font_size := UiTheme.BASE_FONT_SIZE
	var text := canvas.tr(Items.name_key(item))
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var box := (text_size + NAME_PADDING * 2.0).ceil()
	var corner := (at + NAME_OFFSET).floor()
	corner.x = clampf(corner.x, 0.0, maxf(canvas.size.x - box.x, 0.0))
	corner.y = clampf(corner.y, 0.0, maxf(canvas.size.y - box.y, 0.0))
	var rect := Rect2(corner, box)
	canvas.draw_rect(rect, NAME_FILL)
	canvas.draw_rect(rect, UiTheme.WOOD, false, 1.0)
	var baseline := corner + Vector2(NAME_PADDING.x, NAME_PADDING.y + font.get_ascent(font_size))
	canvas.draw_string(
		font, baseline.round(), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UiTheme.PARCHMENT
	)


## Draws a stack (icon and count, or a worn tool's bar) centered at
## `center` on any control.
static func draw_stack(
	canvas: Control, items: ItemLibrary, item: int, count: int, center: Vector2, wear := 0
) -> void:
	if item == Items.Id.NONE or items == null:
		return
	var icon := items.icon(item)
	if icon != null:
		canvas.draw_texture_rect(
			icon, Rect2(center - Vector2.ONE * ICON * 0.5, Vector2.ONE * ICON), false
		)
	var durability := Items.durability(item)
	if wear > 0 and durability > 0:
		var left := 1.0 - float(wear) / durability
		var bar := Rect2(
			center + Vector2(-ICON * 0.5 + 2.0, ICON * 0.5 - 2.0), Vector2(ICON - 4.0, 2.0)
		)
		canvas.draw_rect(bar, Color(0.05, 0.05, 0.05))
		var fill := Rect2(bar.position, Vector2(maxf(roundf(bar.size.x * left), 1.0), 1.0))
		canvas.draw_rect(fill, Color.from_hsv(left / 3.0, 0.9, 0.95))
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
