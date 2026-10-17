class_name InventoryScreen
extends Control
## The inventory (Tab; a workbench, a kitchen counter, a chest, a furnace
## or a boat used with E), in one panel (« Ardoise » layout, asked by the
## owner): its title; on the left what the player wears (EquipmentCard:
## the body turned by a drag, the armor's four slots, the protection); in
## the middle the bag's 27 slots over the hotbar's 9 and the player's book
## set apart (it stays there: a click opens it), filters over them
## (ItemGroups.Filter chips: what they leave out fades) and Sort (BagSort,
## the server too: Msg.SORT_BAG); on the right crafting (CraftCard: the
## grid, 3 x 3 or a workbench's 5 x 5, and what it makes); along the
## bottom what the item under the mouse is (ItemDetails); in creative, the
## catalog of every item (CreativeCatalog: its search field and tabs, the
## wheel scrolls it) over the bag instead of crafting. A block's screen
## (step 4 of the redesign: one frame for all) has the block's icon and
## name in its header, the block's part in a card at the top (a
## workbench's or a kitchen counter's grid, a chest's slots, a furnace,
## FurnaceParts, a factory furnace's chests in panels beside the panel, a
## boat's screen, BoatPanel) and the player's bag always under it.
## Clicks pick up, put down, split and swap stacks (Inventory.click: the
## client shows its guess at once, the server decides), a click on what
## the grid makes takes it (shift: as many as possible); the stack held by
## the cursor follows the mouse, and dropped outside the panel it is
## thrown away. Holding a button with a stack and moving over slots (the
## bag, the hotbar, the crafting grid, a chest, a furnace) works as in
## Minecraft: the right one puts one item into each slot crossed, the left
## one shares the stack evenly between them (shown as it goes, done when it
## is let go; let go on the slot it began on, a plain click). A double
## click gathers on the cursor the same items as its stack lying elsewhere
## (Inventory.collect). With empty hands, the name of the item under the
## mouse shows beside it. It opens fading in and rising into place
## (UiTheme.appear).

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
## A left drag shares the stack between `targets` (Vector2i(Inventory.Holder,
## index), two or more): to show, then done.
signal spread_previewed(targets: Array)
signal spread_finished(targets: Array)
## A double click: the cursor's stack gathers its kind (Inventory.collect).
signal collect_requested
## An item of the creative catalog was clicked (GameModes.take_from_catalog).
signal catalog_clicked(item: int, right: bool, shift: bool)
## A click on a slot of the boat shown, a button of its screen.
signal boat_clicked(slot: int, right: bool, shift: bool)
signal boat_acted(act: int, place: int)
## Sort was clicked: the bag is sorted (BagSort).
signal sort_requested

## What the screen shows: the inventory, the creative catalog, a
## workbench's or a kitchen counter's grid, a chest, a furnace, a boat.
enum Mode { OWN, CATALOG, BENCH, CHEST, FURNACE, BOAT }

## The bag's filters: their names and the items drawn on them.
const FILTERS := {
	ItemGroups.Filter.ALL: ["INVENTORY_FILTER_ALL", Items.Id.NONE],
	ItemGroups.Filter.TOOLS: ["INVENTORY_FILTER_TOOLS", Items.Id.IRON_PICKAXE],
	ItemGroups.Filter.BLOCKS: ["INVENTORY_FILTER_BLOCKS", Items.Id.BRICKS],
	ItemGroups.Filter.FOOD: ["INVENTORY_FILTER_FOOD", Items.Id.BREAD],
	ItemGroups.Filter.NATURE: ["INVENTORY_FILTER_NATURE", Items.Id.OAK_SAPLING],
	ItemGroups.Filter.HOME: ["INVENTORY_FILTER_HOME", Items.Id.CHAIR],
	ItemGroups.Filter.MATERIALS: ["INVENTORY_FILTER_MATERIALS", Items.Id.IRON_INGOT],
}

var inventory: Inventory
var library: ItemLibrary
## Cells across of the crafting grid shown (see open).
var craft_width := Inventory.OWN_GRID
## The crafting grid is a kitchen counter's (its dishes only).
var kitchen := false
## The chest shown instead of the crafting grid (see open_chest; null: none).
var chest: Inventory
## The furnace shown instead of the crafting grid (see open_furnace; null:
## none).
var furnace: Furnace
## The book's slot shows, and the book is in hand (set by GameClient).
var book_shown := false
var book_selected := false
## Creative: the inventory shows the catalog (set by GameModeView).
var creative := false
## What the bag shows plainly (ItemGroups.Filter; the rest fades).
var filter := ItemGroups.Filter.ALL

var _slots: Array[ItemSlot] = []
var _book := ItemSlot.new()
var _book_gap := Control.new()
var _title := UiTheme.label("INVENTORY_TITLE", "TitleLabel")
## In a block's screen: the block's icon (its item's), and the card holding
## the block's part.
var _icon := TextureRect.new()
var _icon_item := Items.Id.NONE
var _block_card := PanelContainer.new()
var _block_box := VBoxContainer.new()
## The cards' row (what is worn, the middle, crafting) and the bag's part
## of the middle (always under the block's part).
var _body := HBoxContainer.new()
var _bag_area := VBoxContainer.new()
var _equipment := EquipmentCard.new()
var _craft := CraftCard.new()
var _details := ItemDetails.new()
var _filters := ChipBar.new()
var _chest_grid := GridContainer.new()
var _chest_slots: Array[ItemSlot] = []
var _catalog := CreativeCatalog.new()
var _catalog_area := VBoxContainer.new()
var _furnace: FurnaceParts
var _boat_area := BoatPanel.new()
## Over the bag when a chest is open: whose slots are whose.
var _bag_label := UiTheme.label("INVENTORY_TITLE", "SectionLabel")
## Draws the cursor's stack (or the name of the item under the mouse) over
## the panel.
var _cursor := Control.new()
## The slot under the mouse (null: none), and where the mouse is (in
## _cursor, from its own events).
var _hovered: ItemSlot
var _pointer := Vector2.ZERO
## The slots a right drag puts items into, whether one is going on, and
## the slots it already gave one (each gets one per drag).
var _drop_slots: Array[ItemSlot] = []
var _dragging := false
var _dragged: Dictionary[ItemSlot, bool] = {}
## A left drag: going on, the slot it began on, the item and how many of
## it were in hand then, and the slots taking a share (in the order
## crossed).
var _spreading := false
var _spread_from: ItemSlot
var _spread_item := Items.Id.NONE
var _spread_count := 0
var _spread: Array[Vector2i] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_furnace = FurnaceParts.new(library)
	_furnace.clicked.connect(
		func(at: int, right: bool, shift: bool) -> void: furnace_clicked.emit(at, right, shift)
	)
	# The panel, between a factory furnace's chests.
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.grow_vertical = Control.GROW_DIRECTION_BOTH
	row.add_theme_constant_override("separation", 4)
	add_child(row)
	row.add_child(_furnace.left)
	var panel := PanelContainer.new()
	row.add_child(panel)
	row.add_child(_furnace.right)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 5)
	_icon.custom_minimum_size = Vector2(14.0, 14.0)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_icon)
	head.add_child(_title)
	box.add_child(head)
	_body.add_theme_constant_override("separation", 6)
	box.add_child(_body)
	_equipment.build(_new_slot, library)
	_equipment.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_body.add_child(_equipment)
	_body.add_child(_center())
	_craft.build(_new_slot, library)
	_craft.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_craft.craft_clicked.connect(func(shift: bool) -> void: craft_clicked.emit(shift))
	_body.add_child(_craft)
	box.add_child(HSeparator.new())
	box.add_child(_details)
	_cursor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.draw.connect(_draw_cursor)
	add_child(_cursor)
	for node in find_children("*", "ItemSlot", true, false):
		var slot := node as ItemSlot
		slot.mouse_entered.connect(_on_slot_entered.bind(slot))
		slot.mouse_exited.connect(_on_slot_exited.bind(slot))
	_drop_slots.append_array(_slots)
	_drop_slots.append_array(_chest_slots)
	_drop_slots.append_array(_furnace.drop_slots())
	visible = false


## Opens with a crafting grid `width` cells across: the inventory's own,
## or a workbench's (Inventory.GRID); `cooking`: a kitchen counter's (its
## dishes). In creative the inventory shows the catalog instead.
func open(width := Inventory.OWN_GRID, cooking := false) -> void:
	var catalog := creative and width == Inventory.OWN_GRID and not cooking
	var bench := width > Inventory.OWN_GRID or cooking
	kitchen = cooking
	craft_width = width
	_craft.set_width(width, cooking)
	if bench:
		_show_mode(Mode.BENCH, Items.Id.KITCHEN if cooking else Items.Id.WORKBENCH)
	else:
		_show_mode(Mode.CATALOG if catalog else Mode.OWN)
		_title.text = "CATALOG_TITLE" if catalog else "INVENTORY_TITLE"
	_show()


## Opens with a chest's slots over the bag (`view`: what it holds, kept
## up to date by GameClient; `item`: the chest's or the furniture's, for
## the header).
func open_chest(view: Inventory, item := Items.Id.CHEST) -> void:
	_show_mode(Mode.CHEST, item)
	chest = view
	_show()


## Opens with a furnace over the bag (`view`: kept up to date by
## GameClient).
func open_furnace(view: Furnace) -> void:
	var food := view.kind == Tiles.Block.FOOD_FURNACE
	_show_mode(Mode.FURNACE, Items.Id.FOOD_FURNACE if food else Items.Id.FACTORY_FURNACE)
	furnace = view
	_furnace.show_furnace(view)
	_show()


## Opens a boat's screen over the bag (BoatPanel; `boats`: as the client
## knows them, `id` the one shown, -1 none yet; `yard`: a shipyard's).
func open_boat(boats: Dictionary, id: int, yard: bool) -> void:
	_show_mode(Mode.BOAT, Items.Id.SHIPYARD if yard else Items.Id.BOAT_BOW)
	if not yard:
		_title.text = "BOAT_TITLE"
	_boat_area.show_boat(boats, id, yard)
	_show()


func close() -> void:
	if visible:
		visible = false
		_hovered = null
		_dragging = false
		if _spreading:
			_end_spread(false)
		close_requested.emit()


## The middle: the catalog or a block's card (a chest, a furnace, a boat,
## crafting brought in) over the bag's part: its filters and Sort, the
## bag, the hotbar and the book.
func _center() -> Control:
	var center := VBoxContainer.new()
	center.add_theme_constant_override("separation", 3)
	_catalog.library = library
	_catalog.item_clicked.connect(
		func(item: int, right: bool, shift: bool) -> void: catalog_clicked.emit(item, right, shift)
	)
	_catalog_area.add_theme_constant_override("separation", 3)
	_catalog_area.add_child(_catalog.head)
	_catalog_area.add_child(_catalog)
	center.add_child(_catalog_area)
	_block_card.theme_type_variation = "CardPanel"
	_block_box.add_theme_constant_override("separation", 3)
	_block_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_block_card.add_child(_block_box)
	center.add_child(_block_card)
	_chest_grid.columns = Inventory.HOTBAR
	_chest_grid.add_theme_constant_override("h_separation", 1)
	_chest_grid.add_theme_constant_override("v_separation", 1)
	_chest_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_block_box.add_child(_chest_grid)
	for i in Inventory.CHEST:
		var chest_slot := ItemSlot.new()
		chest_slot.slot = i
		chest_slot.library = library
		chest_slot.clicked.connect(
			func(at: int, right: bool, shift: bool) -> void: chest_clicked.emit(at, right, shift)
		)
		_chest_grid.add_child(chest_slot)
		_chest_slots.append(chest_slot)
	_block_box.add_child(_furnace.area)
	_block_box.add_child(_furnace.factory_area)
	_boat_area.library = library
	_boat_area.clicked.connect(
		func(at: int, right: bool, shift: bool) -> void: boat_clicked.emit(at, right, shift)
	)
	_boat_area.acted.connect(func(act: int, place: int) -> void: boat_acted.emit(act, place))
	_boat_area.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_block_box.add_child(_boat_area)
	# The bag's part, as wide as the bag, in the middle under the rest.
	_bag_area.add_theme_constant_override("separation", 3)
	_bag_area.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.add_child(_bag_area)
	_bag_label.uppercase = true
	_bag_area.add_child(_bag_label)
	_bag_area.add_child(_bag_tools())
	var bag := GridContainer.new()
	bag.columns = Inventory.HOTBAR
	bag.add_theme_constant_override("h_separation", 1)
	bag.add_theme_constant_override("v_separation", 1)
	_bag_area.add_child(bag)
	for i in Inventory.BAG:
		bag.add_child(_new_slot(Inventory.HOTBAR + i))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 2)
	_bag_area.add_child(gap)
	var hotbar := HBoxContainer.new()
	hotbar.add_theme_constant_override("separation", 1)
	_bag_area.add_child(hotbar)
	for i in Inventory.HOTBAR:
		hotbar.add_child(_new_slot(i))
	_book_gap.custom_minimum_size.x = Hotbar.BOOK_GAP - 2.0
	hotbar.add_child(_book_gap)
	_book.library = library
	_book.clicked.connect(_on_book_clicked.unbind(3))
	hotbar.add_child(_book)
	return center


## Over the bag: its filters, and Sort.
func _bag_tools() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_filters.library = library
	for each: int in FILTERS:
		_filters.add_chip(each, FILTERS[each][0], FILTERS[each][1])
	_filters.select(filter)
	_filters.chosen.connect(func(which: int) -> void: filter = which as ItemGroups.Filter)
	_filters.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_filters)
	var sort := Button.new()
	sort.text = "INVENTORY_SORT"
	sort.tooltip_text = "INVENTORY_SORT_HOW"
	sort.theme_type_variation = "ChipButton"
	sort.focus_mode = Control.FOCUS_NONE
	sort.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sort.pressed.connect(sort_requested.emit)
	row.add_child(sort)
	return row


## Shows the parts of a mode; a block's (`item`: its item) with its icon
## and name in the header, its part in the card over the bag, crafting
## brought into the card for a workbench or a kitchen counter.
func _show_mode(mode: Mode, item := Items.Id.NONE) -> void:
	chest = null
	furnace = null
	_furnace.show_furnace(null)
	var cards := mode in [Mode.OWN, Mode.CATALOG]
	_equipment.visible = cards
	_catalog_area.visible = mode == Mode.CATALOG
	_block_card.visible = not cards
	_chest_grid.visible = mode == Mode.CHEST
	_boat_area.visible = mode == Mode.BOAT
	_craft.visible = mode in [Mode.OWN, Mode.BENCH]
	_bag_label.visible = mode != Mode.OWN
	var parent: Container = _block_box if mode == Mode.BENCH else _body
	if _craft.get_parent() != parent:
		_craft.reparent(parent, false)
	_craft.set_framed(mode != Mode.BENCH)
	_icon_item = item
	_icon.visible = item != Items.Id.NONE
	_icon.texture = library.icon(item) if item != Items.Id.NONE else null
	if item != Items.Id.NONE:
		_title.text = Items.name_key(item)


## Shows the screen, fading in and rising into place when it was closed.
func _show() -> void:
	if not visible:
		visible = true
		UiTheme.appear(self)


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
		var item := inventory.items[at]
		slot.show_stack(item, inventory.counts[at], at == selected, inventory.wear[at])
		slot.faded = at < Inventory.SLOTS and not _shown_by_filter(item)
	if chest != null:
		for i in Inventory.CHEST:
			_chest_slots[i].show_stack(chest.items[i], chest.counts[i], false, chest.wear[i])
			_chest_slots[i].faded = not _shown_by_filter(chest.items[i])
	_furnace.refresh()
	if _equipment.visible:
		var held := Items.Id.GUIDE_BOOK if book_selected else inventory.held()
		_equipment.refresh(inventory, held)
	_craft.show_result(inventory.craft_result(craft_width, kitchen))
	if _icon.visible and _icon.texture == null:
		_icon.texture = library.icon(_icon_item)
	_book.visible = book_shown
	_book_gap.visible = book_shown
	_book.show_stack(Items.Id.GUIDE_BOOK, 1, book_selected)
	_details.show_item(_detailed(), _hovered.shown_wear() if _hovered != null else 0)
	_cursor.queue_redraw()


## Whether the bag's filter shows `item` plainly (an empty slot: always).
func _shown_by_filter(item: int) -> bool:
	return item == Items.Id.NONE or ItemGroups.matches(item, filter)


## The item the bottom line tells about: under the mouse (none: the word
## on clicks).
func _detailed() -> int:
	if _hovered == null or not _hovered.is_visible_in_tree() or _hovered.label != "":
		return Items.Id.NONE
	return _hovered.shown_item()


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


## Follows the mouse (from its own events: the slots keep it while a
## button is held) and runs the drags.
func _input(event: InputEvent) -> void:
	var mouse := event as InputEventMouse
	if not visible or mouse == null:
		return
	var from := _pointer
	_pointer = (_cursor.make_input_local(mouse) as InputEventMouse).position
	var button := event as InputEventMouseButton
	if (
		button != null
		and button.pressed
		and button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]
		and _catalog.is_visible_in_tree()
		and _catalog.get_global_rect().has_point(_pointer)
	):
		_catalog.scroll(-1 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
		get_viewport().set_input_as_handled()
	elif button != null and button.button_index == MOUSE_BUTTON_RIGHT and not _spreading:
		_dragged.clear()
		var start: ItemSlot = _drop_slot_at(_pointer) if button.pressed else null
		_dragging = start != null and not button.shift_pressed and _holding()
		if _dragging:
			# Its own click puts the first item.
			_dragged[start] = true
	elif button != null and button.button_index == MOUSE_BUTTON_LEFT:
		_on_left_button(button)
	elif event is InputEventMouseMotion and (_dragging or _spreading):
		# Every slot on the way (a fast mouse jumps over some).
		var steps := maxi(ceili(from.distance_to(_pointer) / 4.0), 1)
		for i in steps:
			var slot := _drop_slot_at(from.lerp(_pointer, float(i + 1) / steps))
			if slot == null:
				continue
			if _spreading:
				_spread_over(slot)
			elif not _dragged.has(slot) and _holding():
				_dragged[slot] = true
				_click(slot, true)


## The left button: down over a slot with a stack in hand, a left drag
## begins (the slot's own click waits for the button to come up).
func _on_left_button(button: InputEventMouseButton) -> void:
	if not button.pressed:
		if _spreading:
			_end_spread(true)
			get_viewport().set_input_as_handled()
		return
	if button.double_click and not button.shift_pressed and _holding() and _over_a_slot():
		# The first click took the stack up: the second gathers its kind.
		collect_requested.emit()
		get_viewport().set_input_as_handled()
		return
	var start := _drop_slot_at(_pointer)
	if start == null or button.shift_pressed or _dragging or not _holding():
		return
	_spreading = true
	_spread_from = start
	_spread_item = inventory.items[Inventory.CURSOR]
	_spread_count = inventory.counts[Inventory.CURSOR]
	_spread.clear()
	_spread_over(start)
	get_viewport().set_input_as_handled()


## A slot a left drag crosses takes a share if it can take the stack and
## there are items enough for one more slot.
func _spread_over(slot: ItemSlot) -> void:
	var target := _target_of(slot)
	if _spread.has(target) or _spread.size() >= _spread_count:
		return
	if not inventory.can_spread_to(target, _spread_item, chest, furnace):
		return
	_spread.append(target)
	if _spread.size() >= 2:
		spread_previewed.emit(_spread.duplicate())


## The left drag is over: shared between the slots crossed, or (one slot)
## a plain click on the slot it began on (`click`: false when the screen
## closes meanwhile).
func _end_spread(click: bool) -> void:
	_spreading = false
	if _spread.size() >= 2:
		spread_finished.emit(_spread.duplicate())
	elif click and _spread_from != null:
		_click(_spread_from, false)
	_spread.clear()


## Which slot a slot of the screen is, for a left drag.
func _target_of(slot: ItemSlot) -> Vector2i:
	if slot in _chest_slots:
		return Vector2i(Inventory.Holder.CHEST, slot.slot)
	if _furnace.owns(slot):
		return Vector2i(Inventory.Holder.FURNACE, slot.slot)
	return Vector2i(Inventory.Holder.OWN, slot.slot)


func _holding() -> bool:
	return inventory != null and inventory.items[Inventory.CURSOR] != Items.Id.NONE


## Whether the mouse is over a slot (one a drag reaches, or what a
## furnace made).
func _over_a_slot() -> bool:
	if _drop_slot_at(_pointer) != null:
		return true
	for slot in _furnace.given_slots():
		if slot.is_visible_in_tree() and slot.get_global_rect().has_point(_pointer):
			return true
	return false


## The slot a drag can put items into at `point` (null: none).
func _drop_slot_at(point: Vector2) -> ItemSlot:
	for slot in _drop_slots:
		if slot.is_visible_in_tree() and slot.get_global_rect().has_point(point):
			return slot
	return null


## A click on a slot, as if the player clicked it.
func _click(slot: ItemSlot, right: bool) -> void:
	if slot in _chest_slots:
		chest_clicked.emit(slot.slot, right, false)
	elif _furnace.owns(slot):
		furnace_clicked.emit(slot.slot, right, false)
	else:
		slot_clicked.emit(slot.slot, right, false)


func _unhandled_input(event: InputEvent) -> void:
	if (
		visible
		and (
			event.is_action_pressed(InputBindings.INVENTORY)
			or event.is_action_pressed(InputBindings.USE)
			or event.is_action_pressed(InputBindings.PAUSE)
		)
	):
		close()
		get_viewport().set_input_as_handled()


## The shade over the world (reaching under the screen as it rises into
## place).
func _draw() -> void:
	var reach := Vector2(0.0, UiTheme.APPEAR_RISE)
	draw_rect(Rect2(-reach, size + reach * 2.0), UiTheme.SHADE)


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
	elif _hovered != null and _hovered.is_visible_in_tree() and not (_spreading or _dragging):
		if _hovered.label != "":
			ItemSlot.draw_label(_cursor, tr(_hovered.label), at)
		else:
			ItemSlot.draw_name(_cursor, _hovered.shown_item(), at)
