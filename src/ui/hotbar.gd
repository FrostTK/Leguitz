class_name Hotbar
extends VBoxContainer
## The 9 hotbar slots at the bottom of the screen, the one in hand
## highlighted, and the player's book in a 10th slot set apart (when
## shown: the 9 slots stay centered); the name of what is in hand shows
## above for a moment when it changes, and so do short messages
## (announce).

const NAME_SECONDS := 1.6
const ANNOUNCE_SECONDS := 2.5
## Between the 9th slot and the book.
const BOOK_GAP := 4.0

var inventory: Inventory
var library: ItemLibrary
## The book's slot shows, and the book is in hand (set by GameClient).
var book_shown := false
var book_selected := false

var _slots: Array[ItemSlot] = []
var _book := ItemSlot.new()
## The book's slot and the spaces around the row keeping it centered.
var _book_parts: Array[Control] = []
var _name := Label.new()
var _name_left := 0.0
var _shown_item := -1
var _shown_slot := -1
## A message shows instead of the name for this long.
var _announce_left := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_END
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.add_theme_color_override("font_color", Color.WHITE)
	_name.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_name.add_theme_constant_override("shadow_offset_x", 1)
	_name.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_name)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	# As wide on the left as the gap and the book on the right.
	var balance := Control.new()
	balance.custom_minimum_size.x = BOOK_GAP + ItemSlot.SIZE - 1.0
	row.add_child(balance)
	for i in Inventory.HOTBAR:
		var slot := ItemSlot.new()
		slot.slot = i
		slot.library = library
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(slot)
		_slots.append(slot)
	var gap := Control.new()
	gap.custom_minimum_size.x = BOOK_GAP - 2.0
	row.add_child(gap)
	_book.library = library
	_book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_book)
	_book_parts = [balance, gap, _book]
	for part in _book_parts:
		part.visible = false
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 4)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN


func _process(delta: float) -> void:
	if inventory == null:
		return
	if _book.visible != book_shown:
		for part in _book_parts:
			part.visible = book_shown
	var selected := inventory.selected if not book_selected else Inventory.HOTBAR
	for i in Inventory.HOTBAR:
		_slots[i].show_stack(
			inventory.items[i], inventory.counts[i], i == selected, inventory.wear[i]
		)
	_book.show_stack(Items.Id.GUIDE_BOOK, 1, book_selected)
	# The name of what is in hand, when it changes.
	var held := Items.Id.GUIDE_BOOK if book_selected else inventory.held()
	if held != _shown_item or selected != _shown_slot:
		_shown_item = held
		_shown_slot = selected
		if _announce_left <= 0.0:
			_name.text = Items.name_key(held) if held != Items.Id.NONE else ""
			_name_left = NAME_SECONDS
	_name_left -= delta
	_announce_left -= delta
	_name.modulate.a = clampf(_name_left / 0.4, 0.0, 1.0)


## Shows a message (a translation key) where the name of what is in hand
## shows.
func announce(text: String) -> void:
	_name.text = text
	_name_left = ANNOUNCE_SECONDS
	_announce_left = ANNOUNCE_SECONDS
