class_name InventoryScreen
extends Control
## The inventory (E): the crafting grid (3 x 3; a workbench's, 5 x 5, when
## one is opened) and what it makes, the
## bag's 27 slots over the hotbar's 9, and the player's book set apart (it
## stays there: a click opens it). Clicks pick up, put down, split and swap
## stacks (Inventory.click: the client shows its guess at once, the server
## decides), a click on what the grid makes takes it (shift: as many as
## possible); the stack held by the cursor follows the mouse, and dropped
## outside the panel it is thrown away.

signal slot_clicked(slot: int, right: bool, shift: bool)
signal cursor_dropped(whole: bool)
signal close_requested
signal book_requested
## What the crafting grid makes was clicked (shift: make as many as possible).
signal craft_clicked(shift: bool)

var inventory: Inventory
var library: ItemLibrary
## Cells across of the crafting grid shown (see open).
var craft_width := Inventory.OWN_GRID
## The book's slot shows, and the book is in hand (set by GameClient).
var book_shown := false
var book_selected := false

var _slots: Array[ItemSlot] = []
var _book := ItemSlot.new()
var _book_gap := Control.new()
## What the crafting grid makes.
var _result := ItemSlot.new()
var _title := Label.new()
## The crafting grid's cells (all GRID x GRID, row by row; those past the
## width in use hide).
var _grid := GridContainer.new()
var _cells: Array[ItemSlot] = []
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
	var top := HBoxContainer.new()
	box.add_child(top)
	_title.text = "INVENTORY_TITLE"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(_title)
	top.add_child(_crafting())
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
	_book_gap.custom_minimum_size.x = Hotbar.BOOK_GAP - 2.0
	hotbar.add_child(_book_gap)
	_book.library = library
	_book.clicked.connect(_on_book_clicked.unbind(3))
	hotbar.add_child(_book)
	_cursor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.draw.connect(_draw_cursor)
	add_child(_cursor)
	visible = false


## Opens with a crafting grid `width` cells across: the inventory's own,
## or a workbench's (Inventory.GRID).
func open(width := Inventory.OWN_GRID) -> void:
	craft_width = width
	_title.text = "WORKBENCH_TITLE" if width > Inventory.OWN_GRID else "INVENTORY_TITLE"
	_grid.columns = width
	for cell in _cells.size():
		_cells[cell].visible = cell % Inventory.GRID < width and cell / Inventory.GRID < width
	visible = true


func close() -> void:
	if visible:
		visible = false
		close_requested.emit()


## The crafting grid, an arrow and what the grid makes.
func _crafting() -> Control:
	var area := VBoxContainer.new()
	area.add_theme_constant_override("separation", 2)
	var label := Label.new()
	label.text = "CRAFTING_TITLE"
	label.add_theme_color_override("font_color", UiTheme.WOOD)
	area.add_child(label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	area.add_child(row)
	_grid.add_theme_constant_override("h_separation", 1)
	_grid.add_theme_constant_override("v_separation", 1)
	row.add_child(_grid)
	for cell in Inventory.GRID * Inventory.GRID:
		var slot := _new_slot(Inventory.CRAFT + cell)
		_cells.append(slot)
		_grid.add_child(slot)
	var arrow := Control.new()
	arrow.custom_minimum_size = Vector2(12.0, 0.0)
	arrow.draw.connect(_draw_arrow.bind(arrow))
	row.add_child(arrow)
	_result.library = library
	_result.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_result.clicked.connect(
		func(_slot: int, _right: bool, shift: bool) -> void: craft_clicked.emit(shift)
	)
	row.add_child(_result)
	return area


## An arrow pointing from the grid to what it makes.
func _draw_arrow(arrow: Control) -> void:
	var middle := floorf(arrow.size.y * 0.5)
	arrow.draw_rect(Rect2(1.0, middle - 1.0, 6.0, 2.0), UiTheme.WOOD)
	arrow.draw_colored_polygon(
		PackedVector2Array(
			[Vector2(6.0, middle - 4.0), Vector2(11.0, middle), Vector2(6.0, middle + 4.0)]
		),
		UiTheme.WOOD
	)


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
	var selected := inventory.selected if not book_selected else Inventory.HOTBAR
	for slot in _slots:
		var at := slot.slot
		slot.show_stack(
			inventory.items[at], inventory.counts[at], at == selected, inventory.wear[at]
		)
	var made := inventory.craft_result(craft_width)
	_result.show_stack(made.x, made.y)
	_book.visible = book_shown
	_book_gap.visible = book_shown
	_book.show_stack(Items.Id.GUIDE_BOOK, 1, book_selected)
	_cursor.queue_redraw()


## The book never leaves its slot: a click opens it (with empty hands).
func _on_book_clicked() -> void:
	if inventory.items[Inventory.CURSOR] == Items.Id.NONE:
		book_requested.emit()


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
		var count := inventory.counts[Inventory.CURSOR]
		var worn := inventory.wear[Inventory.CURSOR]
		ItemSlot.draw_stack(_cursor, library, item, count, at, worn)
