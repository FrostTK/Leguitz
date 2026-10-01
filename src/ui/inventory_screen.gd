class_name InventoryScreen
extends Control
## The inventory (E): the crafting grid (3 x 3; a workbench's, 5 x 5, when
## one is opened) and what it makes (or an open chest's slots, or a
## furnace: what it cooks, its fire, its fuel, an arrow filling up as it
## cooks and what it made), the
## bag's 27 slots over the hotbar's 9, and the player's book set apart (it
## stays there: a click opens it). Clicks pick up, put down, split and swap
## stacks (Inventory.click: the client shows its guess at once, the server
## decides), a click on what the grid makes takes it (shift: as many as
## possible); the stack held by the cursor follows the mouse, and dropped
## outside the panel it is thrown away. With empty hands, the name of the
## item under the mouse shows beside it.

signal slot_clicked(slot: int, right: bool, shift: bool)
signal cursor_dropped(whole: bool)
signal close_requested
signal book_requested
## What the crafting grid makes was clicked (shift: make as many as possible).
signal craft_clicked(shift: bool)
## A slot of the open chest was clicked.
signal chest_clicked(slot: int, right: bool, shift: bool)
## A slot of the open furnace was clicked.
signal furnace_clicked(slot: int, right: bool, shift: bool)

## The flame shown under what a furnace cooks: its rows' widths, from the
## bottom; and its colors (embers to tip).
const FLAME_ROWS: Array[int] = [8, 8, 8, 6, 6, 6, 4, 4, 2, 2]
const FLAME_COLORS: Array[Color] = [Color("ee6420"), Color("ffa634"), Color("ffe27a")]

var inventory: Inventory
var library: ItemLibrary
## Cells across of the crafting grid shown (see open).
var craft_width := Inventory.OWN_GRID
## The chest shown instead of the crafting grid (see open_chest; null: none).
var chest: Inventory
## The furnace shown instead of the crafting grid (see open_furnace; null:
## none).
var furnace: Furnace
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
var _crafting_area: Control
var _chest_grid := GridContainer.new()
var _chest_slots: Array[ItemSlot] = []
var _furnace_area: Control
var _furnace_slots: Array[ItemSlot] = []
var _furnace_hint := Label.new()
var _flame := Control.new()
var _cooking := Control.new()
## Over the bag when a chest is open: whose slots are whose.
var _bag_label := Label.new()
## Draws the cursor's stack (or the name of the item under the mouse) over
## the panel.
var _cursor := Control.new()
## The slot under the mouse (null: none), and where the mouse is (in
## _cursor, from its own events).
var _hovered: ItemSlot
var _pointer := Vector2.ZERO


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
	_crafting_area = _crafting()
	top.add_child(_crafting_area)
	_furnace_area = _furnace()
	top.add_child(_furnace_area)
	_chest_grid.columns = Inventory.HOTBAR
	_chest_grid.add_theme_constant_override("h_separation", 1)
	_chest_grid.add_theme_constant_override("v_separation", 1)
	box.add_child(_chest_grid)
	for i in Inventory.CHEST:
		var chest_slot := ItemSlot.new()
		chest_slot.slot = i
		chest_slot.library = library
		chest_slot.clicked.connect(
			func(at: int, right: bool, shift: bool) -> void: chest_clicked.emit(at, right, shift)
		)
		_chest_grid.add_child(chest_slot)
		_chest_slots.append(chest_slot)
	_bag_label.text = "INVENTORY_TITLE"
	box.add_child(_bag_label)
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
	for node in find_children("*", "ItemSlot", true, false):
		var slot := node as ItemSlot
		slot.mouse_entered.connect(_on_slot_entered.bind(slot))
		slot.mouse_exited.connect(_on_slot_exited.bind(slot))
	visible = false


## Opens with a crafting grid `width` cells across: the inventory's own,
## or a workbench's (Inventory.GRID).
func open(width := Inventory.OWN_GRID) -> void:
	chest = null
	furnace = null
	_furnace_area.visible = false
	_chest_grid.visible = false
	_bag_label.visible = false
	_crafting_area.visible = true
	craft_width = width
	_title.text = "WORKBENCH_TITLE" if width > Inventory.OWN_GRID else "INVENTORY_TITLE"
	_grid.columns = width
	for cell in _cells.size():
		_cells[cell].visible = cell % Inventory.GRID < width and cell / Inventory.GRID < width
	visible = true


## Opens with a chest's slots over the bag (`view`: what it holds, kept
## up to date by GameClient) instead of the crafting grid.
func open_chest(view: Inventory) -> void:
	chest = view
	furnace = null
	_furnace_area.visible = false
	_title.text = "CHEST_TITLE"
	_crafting_area.visible = false
	_chest_grid.visible = true
	_bag_label.visible = true
	visible = true


## Opens with a furnace over the bag (`view`: kept up to date by
## GameClient) instead of the crafting grid.
func open_furnace(view: Furnace) -> void:
	furnace = view
	chest = null
	var food := view.kind == Tiles.Block.FOOD_FURNACE
	_title.text = "ITEM_FOOD_FURNACE" if food else "ITEM_FACTORY_FURNACE"
	_furnace_hint.text = "FURNACE_FOOD_HINT" if food else "FURNACE_FACTORY_HINT"
	_crafting_area.visible = false
	_chest_grid.visible = false
	_furnace_area.visible = true
	_bag_label.visible = true
	visible = true


func close() -> void:
	if visible:
		visible = false
		_hovered = null
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


## A furnace: what it cooks over its fire and its fuel, an arrow, what it
## made; a word on what it is for under them.
func _furnace() -> Control:
	var area := VBoxContainer.new()
	area.add_theme_constant_override("separation", 2)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	area.add_child(row)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 1)
	row.add_child(column)
	for i in Furnace.SLOTS:
		var slot := ItemSlot.new()
		slot.slot = i
		slot.library = library
		slot.clicked.connect(
			func(at: int, right: bool, shift: bool) -> void: furnace_clicked.emit(at, right, shift)
		)
		_furnace_slots.append(slot)
	column.add_child(_furnace_slots[Furnace.INPUT])
	_flame.custom_minimum_size = Vector2(ItemSlot.SIZE, FLAME_ROWS.size() + 2.0)
	_flame.draw.connect(_draw_flame)
	column.add_child(_flame)
	column.add_child(_furnace_slots[Furnace.FUEL])
	_cooking.custom_minimum_size = Vector2(24.0, 0.0)
	_cooking.draw.connect(_draw_cooking)
	row.add_child(_cooking)
	var output := _furnace_slots[Furnace.OUTPUT]
	output.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(output)
	_furnace_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_furnace_hint.custom_minimum_size.x = 76.0
	_furnace_hint.add_theme_color_override("font_color", UiTheme.WOOD)
	_furnace_hint.add_theme_font_size_override("font_size", 6)
	area.add_child(_furnace_hint)
	return area


## The fire: a flame burning down as its fuel goes (dim when out).
func _draw_flame() -> void:
	var fire := furnace.fire if furnace != null else 0.0
	var lit_rows := ceili(fire * FLAME_ROWS.size())
	var bottom := _flame.size.y - 1.0
	for row in FLAME_ROWS.size():
		var width := float(FLAME_ROWS[row])
		var rect := Rect2(floorf((_flame.size.x - width) * 0.5), bottom - row - 1.0, width, 1.0)
		var color := Color(UiTheme.WOOD, 0.3)
		if row < lit_rows:
			color = FLAME_COLORS[mini(row * FLAME_COLORS.size() / FLAME_ROWS.size(), 2)]
		_flame.draw_rect(rect, color)


## The arrow from the furnace to what it made, filling up as it cooks.
func _draw_cooking() -> void:
	var progress := furnace.progress if furnace != null else 0.0
	var middle := floorf(_cooking.size.y * 0.5)
	var length := _cooking.size.x - 3.0
	var head := 7.0
	for x in int(length):
		var half := 1.0 if x < length - head else ceilf((length - x) * 5.0 / head)
		var filled := x < progress * length
		var color := UiTheme.WOOD if filled else Color(UiTheme.WOOD, 0.3)
		_cooking.draw_rect(Rect2(1.0 + x, middle - half, 1.0, half * 2.0), color)


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
	if chest != null:
		for i in Inventory.CHEST:
			_chest_slots[i].show_stack(chest.items[i], chest.counts[i], false, chest.wear[i])
	if furnace != null:
		var held := furnace.slots
		for i in Furnace.SLOTS:
			_furnace_slots[i].show_stack(held.items[i], held.counts[i], false, held.wear[i])
		_flame.queue_redraw()
		_cooking.queue_redraw()
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


func _input(event: InputEvent) -> void:
	var mouse := event as InputEventMouse
	if visible and mouse != null:
		_pointer = (_cursor.make_input_local(mouse) as InputEventMouse).position


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


func _on_slot_entered(slot: ItemSlot) -> void:
	_hovered = slot


func _on_slot_exited(slot: ItemSlot) -> void:
	if _hovered == slot:
		_hovered = null


## The cursor's stack under the mouse; with empty hands, the name of the
## item under it.
func _draw_cursor() -> void:
	if inventory == null:
		return
	var at := _pointer
	var item := inventory.items[Inventory.CURSOR]
	if item != Items.Id.NONE:
		var count := inventory.counts[Inventory.CURSOR]
		var worn := inventory.wear[Inventory.CURSOR]
		ItemSlot.draw_stack(_cursor, library, item, count, at, worn)
	elif _hovered != null and _hovered.is_visible_in_tree():
		ItemSlot.draw_name(_cursor, _hovered.shown_item(), at)
