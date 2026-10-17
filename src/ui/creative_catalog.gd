class_name CreativeCatalog
extends HBoxContainer
## The creative catalog (in the inventory screen, over the bag): every item
## sorted into tabs (ItemGroups.Tab: building blocks, stairs and roofs,
## nature, doors and windows, furniture, decoration, the farm, food, tools
## and gear, materials; ItemGroups.tab_of), ROWS rows of the tab chosen at a time, scrolled by
## the wheel or the bar beside them (a click or a drag on it). Its `head`
## (the inventory screen puts it in its top, beside the armor) holds a
## search field (a click or Ctrl+F; Esc, Enter or Tab lets it go): its words
## find the items whose name holds them all, in any language loaded
## (`search`; Chat.plain: case and accents aside), whatever the tab; then
## the tabs (a click goes back to one) and what is shown. A click on an
## item is reported (GameModes.take_from_catalog says what it does).

signal item_clicked(item: int, right: bool, shift: bool)

const ROWS := 5
const BAR_WIDTH := 4.0
const SEARCH_WIDTH := 104.0
## The search field's clearing cross (pixels).
const CROSS := 5
## Each tab: its name's key and the item drawn on it.
const TABS := {
	ItemGroups.Tab.BLOCKS: ["CATALOG_TAB_BLOCKS", Items.Id.BRICKS],
	ItemGroups.Tab.SHAPES: ["CATALOG_TAB_SHAPES", Items.Id.OAK_STAIRS],
	ItemGroups.Tab.NATURE: ["CATALOG_TAB_NATURE", Items.Id.FLOWER_RED],
	ItemGroups.Tab.OPENINGS: ["CATALOG_TAB_OPENINGS", Items.Id.OAK_DOOR],
	ItemGroups.Tab.FURNITURE: ["CATALOG_TAB_FURNITURE", Items.Id.CHAIR],
	ItemGroups.Tab.DECOR: ["CATALOG_TAB_DECOR", Items.Id.LANTERN],
	ItemGroups.Tab.FARM: ["CATALOG_TAB_FARM", Items.Id.WHEAT],
	ItemGroups.Tab.FOOD: ["CATALOG_TAB_FOOD", Items.Id.BREAD],
	ItemGroups.Tab.TOOLS: ["CATALOG_TAB_TOOLS", Items.Id.IRON_PICKAXE],
	ItemGroups.Tab.MATERIALS: ["CATALOG_TAB_MATERIALS", Items.Id.IRON_INGOT],
}
## Each item's names, plain, in every language loaded (made when first
## searched).
static var _names: Dictionary[int, PackedStringArray] = {}

var library: ItemLibrary
## The slots shown, ROWS rows of Inventory.HOTBAR (`slot`: the place in
## the view).
var slots: Array[ItemSlot] = []
## The search field, the tabs and what is shown (see the class).
var head := VBoxContainer.new()
## The tab shown when nothing is searched.
var tab: ItemGroups.Tab = ItemGroups.Tab.BLOCKS

## The items shown: the tab's, or what the search found.
var _shown: Array[int] = []
## The first row of items in view.
var _first_row := 0
var _grid := GridContainer.new()
var _bar := Control.new()
var _field := LineEdit.new()
var _tabs := ChipBar.new()
var _caption := UiTheme.label("", "SectionLabel")


## The items whose name holds every word of `text` (in any language
## loaded; case and accents aside), those whose name begins with it first,
## then those with a word beginning with it, tab after tab.
static func search(text: String) -> Array[int]:
	var words := Chat.plain(text).split(" ", false)
	var found: Array[Vector2i] = []
	if words.is_empty():
		return []
	var every := ItemGroups.order()
	for at in every.size():
		var best := -1
		for name in _names_of(every[at]):
			var rank := _rank(name, words)
			if rank >= 0 and (best < 0 or rank < best):
				best = rank
		if best >= 0:
			found.append(Vector2i(best, at))
	found.sort()
	var result: Array[int] = []
	for hit in found:
		result.append(every[hit.y])
	return result


## An item's names, plain: in every language loaded, and its own (its key).
static func _names_of(item: int) -> PackedStringArray:
	if not _names.has(item):
		var names := PackedStringArray([Chat.plain(String(Items.Id.find_key(item)))])
		for locale in TranslationServer.get_loaded_locales():
			var translation := TranslationServer.get_translation_object(locale)
			var name := String(translation.get_message(Items.name_key(item)))
			if not name.is_empty() and not names.has(Chat.plain(name)):
				names.append(Chat.plain(name))
		_names[item] = names
	return _names[item]


## How well a name answers the words (-1: a word is not in it; 0: it begins
## with the first; 1: one of its words does; 2: they are in it).
static func _rank(name: String, words: PackedStringArray) -> int:
	for word in words:
		if not word in name:
			return -1
	if name.begins_with(words[0]):
		return 0
	return 1 if (" " + words[0]) in name else 2


func _ready() -> void:
	add_theme_constant_override("separation", 2)
	_grid.columns = Inventory.HOTBAR
	_grid.add_theme_constant_override("h_separation", 1)
	_grid.add_theme_constant_override("v_separation", 1)
	add_child(_grid)
	for i in ROWS * Inventory.HOTBAR:
		var slot := ItemSlot.new()
		slot.slot = i
		slot.library = library
		slot.clicked.connect(_on_clicked)
		_grid.add_child(slot)
		slots.append(slot)
	_bar.custom_minimum_size.x = BAR_WIDTH
	_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_bar.draw.connect(_draw_bar)
	_bar.gui_input.connect(_on_bar_input)
	add_child(_bar)
	_build_head()
	visibility_changed.connect(_on_visibility_changed)
	_refresh()


## The search field, the tabs (chips showing an item each, named by their
## tooltip) and the caption (the tab shown, or what was found).
func _build_head() -> void:
	head.add_theme_constant_override("separation", 3)
	head.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_field.placeholder_text = "CATALOG_SEARCH"
	_field.custom_minimum_size.x = SEARCH_WIDTH
	_field.clear_button_enabled = true
	_field.add_theme_icon_override("clear", _cross())
	_field.text_changed.connect(func(_text: String) -> void: _refresh())
	head.add_child(_field)
	_tabs.library = library
	for each: int in ItemGroups.Tab.values():
		_tabs.add_chip(each, TABS[each][0], TABS[each][1])
	_tabs.select(tab)
	_tabs.chosen.connect(show_tab)
	head.add_child(_tabs)
	_caption.uppercase = true
	head.add_child(_caption)


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	for slot in slots:
		slot.show_stack(item_at(slot.slot), 1)
	_tabs.select(-1 if _searching() else tab)


## Shows a tab (what was searched is let go).
func show_tab(which: int) -> void:
	tab = which as ItemGroups.Tab
	_field.text = ""
	_field.release_focus()
	_refresh()


## Searches `text` as if typed (empty: the tab again).
func search_for(text: String) -> void:
	_field.text = text
	_refresh()


## The items shown (the tab's, or what was found).
func shown() -> Array[int]:
	return _shown


## The item in place `index` of the view (Items.Id.NONE: past the last).
func item_at(index: int) -> int:
	var at := _first_row * Inventory.HOTBAR + index
	return _shown[at] if at < _shown.size() else Items.Id.NONE


## Scrolls by `rows` (down for more).
func scroll(rows: int) -> void:
	_first_row = clampi(_first_row + rows, 0, _last_first_row())
	_bar.queue_redraw()


## Ctrl+F takes the search field; while it has the keys, Esc, Enter and Tab
## let it go (they do not close the screen), and a click elsewhere too.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var key := event as InputEventKey
	var button := event as InputEventMouseButton
	if key != null and key.pressed and key.ctrl_pressed and key.keycode == KEY_F:
		_field.grab_focus()
		_field.select_all()
	elif (
		key != null
		and key.pressed
		and _field.has_focus()
		and key.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_TAB]
	):
		_field.release_focus()
	elif (
		button != null
		and button.pressed
		and _field.has_focus()
		and not _field.get_global_rect().has_point(_field.get_global_mouse_position())
	):
		_field.release_focus()
		return
	else:
		return
	get_viewport().set_input_as_handled()


func _searching() -> bool:
	return not Chat.plain(_field.text).is_empty()


## What is shown again (the tab, or what the search finds), from its top.
func _refresh() -> void:
	_first_row = 0
	if _searching():
		_shown = search(_field.text)
		_caption.text = (
			tr("CATALOG_FOUND") % _shown.size() if not _shown.is_empty() else tr("CATALOG_NOTHING")
		)
	else:
		_shown = ItemGroups.items_of(tab)
		_caption.text = tr(TABS[tab][0])
	_bar.queue_redraw()


func _on_visibility_changed() -> void:
	head.visible = visible
	if not is_visible_in_tree():
		_field.release_focus()


func _last_first_row() -> int:
	return maxi(ceili(_shown.size() / float(Inventory.HOTBAR)) - ROWS, 0)


func _on_clicked(index: int, right: bool, shift: bool) -> void:
	var item := item_at(index)
	if item != Items.Id.NONE:
		item_clicked.emit(item, right, shift)


## A click or a drag on the bar shows that part of the catalog.
func _on_bar_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	var motion := event as InputEventMouseMotion
	var held := (
		(button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT)
		or (motion != null and motion.button_mask & MOUSE_BUTTON_MASK_LEFT != 0)
	)
	if not held:
		return
	var along := clampf((event as InputEventMouse).position.y / _bar.size.y, 0.0, 1.0)
	_first_row = roundi(along * _last_first_row())
	_bar.queue_redraw()
	_bar.accept_event()


## The bar: its track, and over it the part in view.
func _draw_bar() -> void:
	var height := _bar.size.y
	UiTheme.draw_box(_bar, Rect2(0.0, 0.0, BAR_WIDTH, height), UiTheme.TRACK, UiTheme.LINE, 2)
	var rows := maxi(ceili(_shown.size() / float(Inventory.HOTBAR)), 1)
	var thumb := roundf(height * minf(float(ROWS) / rows, 1.0))
	var last := _last_first_row()
	var top := roundf((height - thumb) * _first_row / last) if last > 0 else 0.0
	UiTheme.draw_box(_bar, Rect2(0.0, top, BAR_WIDTH, thumb), UiTheme.MUTED, Color.TRANSPARENT, 2)


## The search field's little cross that clears it (white: its color is
## the field's clear_button_color).
static func _cross() -> ImageTexture:
	var image := Image.create(CROSS, CROSS, false, Image.FORMAT_RGBA8)
	for i in CROSS:
		image.set_pixel(i, i, Color.WHITE)
		image.set_pixel(CROSS - 1 - i, i, Color.WHITE)
	return ImageTexture.create_from_image(image)
