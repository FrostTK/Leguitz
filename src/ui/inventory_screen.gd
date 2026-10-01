class_name InventoryScreen
extends Control
## The inventory (E): the bag's 27 slots over the hotbar's 9. Clicks pick
## up, put down, split and swap stacks (Inventory.click: the client shows
## its guess at once, the server decides); the stack held by the cursor
## follows the mouse, and dropped outside the panel it is thrown away.

signal slot_clicked(slot: int, right: bool, shift: bool)
signal cursor_dropped(whole: bool)
signal close_requested

var inventory: Inventory
var library: ItemLibrary

var _slots: Array[ItemSlot] = []
## Draws the cursor's stack over the panel.
var _cursor := Control.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := Label.new()
	title.text = "INVENTORY_TITLE"
	box.add_child(title)
	var bag := GridContainer.new()
	bag.columns = Inventory.HOTBAR
	bag.add_theme_constant_override("h_separation", 1)
	bag.add_theme_constant_override("v_separation", 1)
	box.add_child(bag)
	for i in Inventory.BAG:
		bag.add_child(_new_slot(Inventory.HOTBAR + i))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 3)
	box.add_child(gap)
	var hotbar := HBoxContainer.new()
	hotbar.add_theme_constant_override("separation", 1)
	box.add_child(hotbar)
	for i in Inventory.HOTBAR:
		hotbar.add_child(_new_slot(i))
	_cursor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.draw.connect(_draw_cursor)
	add_child(_cursor)
	visible = false


func open() -> void:
	visible = true


func close() -> void:
	if visible:
		visible = false
		close_requested.emit()


func _new_slot(index: int) -> ItemSlot:
	var slot := ItemSlot.new()
	slot.slot = index
	slot.library = library
	slot.clicked.connect(
		func(at: int, right: bool, shift: bool) -> void: slot_clicked.emit(at, right, shift)
	)
	_slots.append(slot)
	return slot


func _process(_delta: float) -> void:
	if not visible or inventory == null:
		return
	for slot in _slots:
		slot.show_stack(
			inventory.items[slot.slot], inventory.counts[slot.slot], slot.slot == inventory.selected
		)
	_cursor.queue_redraw()


## A click beside the panel throws the cursor's stack (right: one item).
func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed or inventory == null:
		return
	if inventory.items[Inventory.CURSOR] != Items.Id.NONE:
		cursor_dropped.emit(button.button_index != MOUSE_BUTTON_RIGHT)
	accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if (
		visible
		and (
			event.is_action_pressed(InputBindings.INVENTORY)
			or event.is_action_pressed(InputBindings.PAUSE)
		)
	):
		close()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))


## The cursor's stack, under the mouse.
func _draw_cursor() -> void:
	if inventory == null:
		return
	var item := inventory.items[Inventory.CURSOR]
	if item != Items.Id.NONE:
		var at := _cursor.get_local_mouse_position()
		ItemSlot.draw_stack(_cursor, library, item, inventory.counts[Inventory.CURSOR], at)
