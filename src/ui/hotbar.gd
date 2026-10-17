class_name Hotbar
extends VBoxContainer
## The 9 hotbar slots at the bottom of the screen and the player's book in
## a 10th slot set apart (when shown: the 9 slots stay centered), on dark
## rounded panels; the one in hand ringed in amber, the ring gliding from
## slot to slot. The name of what is in hand shows above in a small panel
## for a moment when it changes, and so do short messages (announce). The
## player's vitality shows over the slots (vitals), what the dishes eaten
## do over it (effects).

const NAME_SECONDS := 1.6
const ANNOUNCE_SECONDS := 2.5
## The name's panel fades out over this long.
const NAME_FADE := 0.4
## Between the 9th slot and the book.
const BOOK_GAP := 6.0
## How far the panels reach around the slots, and the ring around the one
## in hand.
const PANEL_REACH := 2.0
const RING := 1.0
## How fast the ring glides to the slot in hand (the share of the way left
## it goes in a second, as an exponential ease).
const RING_EASE := 22.0

var inventory: Inventory
var library: ItemLibrary
## The vitality gauge over the slots.
var vitals := VitalsBar.new()
## What the dishes eaten do, over the vitality.
var effects := EffectsRow.new()
## The book's slot shows, and the book is in hand (set by GameClient).
var book_shown := false
var book_selected := false

var _slots: Array[ItemSlot] = []
var _row := HBoxContainer.new()
var _book := ItemSlot.new()
## The book's slot and the spaces around the row keeping it centered.
var _book_parts: Array[Control] = []
var _plate := PanelContainer.new()
var _name := Label.new()
var _name_left := 0.0
var _shown_item := -1
var _shown_slot := -1
## A message shows instead of the name for this long.
var _announce_left := 0.0
## Where the ring is (the row's units; NAN: not placed yet).
var _ring_x := NAN


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_END
	_plate.theme_type_variation = "HudPanel"
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_plate.visible = false
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plate.add_child(_name)
	add_child(_plate)
	add_child(effects)
	add_child(vitals)
	var row := _row
	row.add_theme_constant_override("separation", 1)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.draw.connect(_draw_panels)
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
		_ring_x = NAN
		_row.queue_redraw()
	var selected := inventory.selected if not book_selected else Inventory.HOTBAR
	# The row draws the ring: the slots never show themselves chosen.
	for i in Inventory.HOTBAR:
		_slots[i].show_stack(inventory.items[i], inventory.counts[i], false, inventory.wear[i])
	_book.show_stack(Items.Id.GUIDE_BOOK, 1, false)
	_glide(selected, delta)
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
	_plate.modulate.a = clampf(_name_left / NAME_FADE, 0.0, 1.0)
	_plate.visible = _name_left > 0.0 and _name.text != ""


## Shows a message (a translation key) where the name of what is in hand
## shows.
func announce(text: String) -> void:
	_name.text = text
	_name_left = ANNOUNCE_SECONDS
	_announce_left = ANNOUNCE_SECONDS


## The ring glides towards the slot in hand (the book's: Inventory.HOTBAR).
func _glide(selected: int, delta: float) -> void:
	var slot: ItemSlot = _slots[selected] if selected < Inventory.HOTBAR else _book
	if slot.size.x <= 0.0:
		return
	var goal := slot.position.x
	if is_nan(_ring_x) or absf(goal - _ring_x) > ItemSlot.SIZE * Inventory.HOTBAR:
		_ring_x = goal
	elif absf(goal - _ring_x) > 0.01:
		_ring_x = lerpf(_ring_x, goal, 1.0 - exp(-RING_EASE * delta))
		if absf(goal - _ring_x) < 0.05:
			_ring_x = goal
	else:
		return
	_row.queue_redraw()


## The panels behind the slots and the ring around the one in hand (drawn
## by the row, under the slots: a slot covers the ring's middle).
func _draw_panels() -> void:
	var first := _slots[0].get_rect()
	var slots := Rect2(first.position, _slots[-1].get_rect().end - first.position)
	UiTheme.draw_box(_row, slots.grow(PANEL_REACH), UiTheme.PANEL)
	if _book.visible:
		UiTheme.draw_box(_row, _book.get_rect().grow(PANEL_REACH), UiTheme.PANEL)
	if not is_nan(_ring_x):
		var ring := Rect2(Vector2(_ring_x, first.position.y), first.size).grow(RING)
		UiTheme.draw_box(_row, ring, UiTheme.ACCENT, Color.TRANSPARENT, UiTheme.RADIUS)
