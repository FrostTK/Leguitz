class_name CreativeCatalog
extends HBoxContainer
## The creative catalog (in the inventory screen, over the bag): every item
## sorted into tabs (Tab: building blocks, stairs and roofs, nature, doors
## and windows, furniture, decoration, the farm, food, tools and gear,
## materials; `tab_of`), ROWS rows of the tab chosen at a time, scrolled by
## the wheel or the bar beside them (a click or a drag on it). Its `head`
## (the inventory screen puts it in its top, beside the armor) holds a
## search field (a click or Ctrl+F; Esc, Enter or Tab lets it go): its words
## find the items whose name holds them all, in any language loaded
## (`search`; Chat.plain: case and accents aside), whatever the tab; then
## the tabs (a click goes back to one) and what is shown. A click on an
## item is reported (GameModes.take_from_catalog says what it does).

signal item_clicked(item: int, right: bool, shift: bool)

enum Tab { BLOCKS, SHAPES, NATURE, OPENINGS, FURNITURE, DECOR, FARM, FOOD, TOOLS, MATERIALS }

const ROWS := 5
const BAR_WIDTH := 4.0
const TAB_COLUMNS := 5
const SEARCH_WIDTH := 104.0
## The search field's clearing cross (pixels).
const CROSS := 5
## Each tab: its name's key and the item drawn on it.
const TABS := {
	Tab.BLOCKS: ["CATALOG_TAB_BLOCKS", Items.Id.BRICKS],
	Tab.SHAPES: ["CATALOG_TAB_SHAPES", Items.Id.OAK_STAIRS],
	Tab.NATURE: ["CATALOG_TAB_NATURE", Items.Id.FLOWER_RED],
	Tab.OPENINGS: ["CATALOG_TAB_OPENINGS", Items.Id.OAK_DOOR],
	Tab.FURNITURE: ["CATALOG_TAB_FURNITURE", Items.Id.CHAIR],
	Tab.DECOR: ["CATALOG_TAB_DECOR", Items.Id.LANTERN],
	Tab.FARM: ["CATALOG_TAB_FARM", Items.Id.WHEAT],
	Tab.FOOD: ["CATALOG_TAB_FOOD", Items.Id.BREAD],
	Tab.TOOLS: ["CATALOG_TAB_TOOLS", Items.Id.IRON_PICKAXE],
	Tab.MATERIALS: ["CATALOG_TAB_MATERIALS", Items.Id.IRON_INGOT],
}
## The tools' tab besides the tools, the armor and the pots of paint: the
## bow, fishing, boats.
const GEAR := {
	Items.Id.BOW: true,
	Items.Id.ARROW: true,
	Items.Id.FISHING_ROD: true,
	Items.Id.FISHING_NET: true,
	Items.Id.WORM: true,
	Items.Id.BAIT_BALL: true,
	Items.Id.FISH_BAIT: true,
	Items.Id.FISH_TRAP: true,
	Items.Id.SHIPYARD: true,
	Items.Id.BOAT_BOW: true,
	Items.Id.BOAT_SECTION: true,
	Items.Id.BOAT_STERN: true,
	Items.Id.BOILER: true,
	Items.Id.PROPELLER: true,
	Items.Id.COAL_ENGINE: true,
	Items.Id.BOAT_BENCH: true,
}
## The farm's gear and what it gives that is not food.
const FARM_ITEMS := {
	Items.Id.WHEAT: true,
	Items.Id.FLAX: true,
	Items.Id.WATERING_CAN: true,
	Items.Id.SHEARS: true,
	Items.Id.BUCKET: true,
	Items.Id.LEAD: true,
	Items.Id.COMPOST: true,
	Items.Id.EGG: true,
}
## Wild plants (placing nothing), with nature.
const WILD := {
	Items.Id.FLOWER_RED: true,
	Items.Id.FLOWER_YELLOW: true,
	Items.Id.FLOWER_BLUE: true,
	Items.Id.FLOWER_WHITE: true,
	Items.Id.FLOWER_PINK: true,
	Items.Id.FERN: true,
	Items.Id.CACTUS: true,
	Items.Id.LILY_PAD: true,
}
## The cubes the world is made of (the others are building blocks).
const NATURAL_CUBES := {
	Tiles.Block.STONE: true,
	Tiles.Block.DEEPSLATE: true,
	Tiles.Block.SANDSTONE: true,
	Tiles.Block.PACKED_ICE: true,
}
## Doors and windows' tab besides doors, trapdoors, panes and windows, by
## kind.
const OPENING_KINDS := {
	Tiles.Block.LADDER: true,
	Tiles.Block.SHUTTERS: true,
	Tiles.Block.IRON_BARS: true,
	Tiles.Block.WOOD_RAILING: true,
	Tiles.Block.IRON_RAILING: true,
	Tiles.Block.FENCE: true,
	Tiles.Block.GATE: true,
	Tiles.Block.BIG_GATE: true,
}
## The farm's tab besides what is sown and saplings, by kind.
const FARM_KINDS := {
	Tiles.Block.PUMPKIN: true,
	Tiles.Block.COMPOSTER: true,
	Tiles.Block.TRELLIS: true,
	Tiles.Block.SCARECROW: true,
	Tiles.Block.BEEHIVE: true,
	Tiles.Block.NEST_BOX: true,
	Tiles.Block.TURTLE_EGGS: true,
}
## Decoration (the other things placed are furniture), by kind.
const DECOR_KINDS := {
	Tiles.Block.TORCH: true,
	Tiles.Block.TORCH_BRACKET: true,
	Tiles.Block.LANTERN: true,
	Tiles.Block.CAMPFIRE: true,
	Tiles.Block.CURTAINS: true,
	Tiles.Block.CURTAINS_LONG: true,
	Tiles.Block.CURTAINS_IRON: true,
	Tiles.Block.CURTAINS_LONG_IRON: true,
	Tiles.Block.RUG: true,
	Tiles.Block.CANDLE: true,
	Tiles.Block.CANDELABRA: true,
	Tiles.Block.CHANDELIER: true,
	Tiles.Block.BEDSIDE_LAMP: true,
	Tiles.Block.WALL_SCONCE: true,
	Tiles.Block.PAINTING: true,
	Tiles.Block.PORTRAIT: true,
	Tiles.Block.WALL_CLOCK: true,
	Tiles.Block.MIRROR: true,
	Tiles.Block.FRAMED_MAP: true,
	Tiles.Block.DEER_TROPHY: true,
	Tiles.Block.BEAR_TROPHY: true,
	Tiles.Block.TAPESTRY: true,
	Tiles.Block.SPICE_RACK: true,
	Tiles.Block.COAT_RACK: true,
	Tiles.Block.CUSHION: true,
	Tiles.Block.FLOWER_POT: true,
	Tiles.Block.WINDOW_BOX: true,
	Tiles.Block.HOUSEPLANT: true,
	Tiles.Block.FOLDING_SCREEN: true,
}

## Every tab's items (Items order within each; the tools' tab: tools, the
## bow and arrows, armor, the rest); each item's names, plain,
## in every language loaded (made when first searched).
static var _tabs := _sort()
static var _names: Dictionary[int, PackedStringArray] = {}

var library: ItemLibrary
## The slots shown, ROWS rows of Inventory.HOTBAR (`slot`: the place in
## the view).
var slots: Array[ItemSlot] = []
## The search field, the tabs and what is shown (see the class).
var head := VBoxContainer.new()
## The tab shown when nothing is searched.
var tab: Tab = Tab.BLOCKS

## The items shown: the tab's, or what the search found.
var _shown: Array[int] = []
## The first row of items in view.
var _first_row := 0
var _grid := GridContainer.new()
var _bar := Control.new()
var _field := LineEdit.new()
var _tab_slots: Array[ItemSlot] = []
var _caption := Label.new()


## Every item but the player's book, tab after tab.
static func order() -> Array[int]:
	var result: Array[int] = []
	for each: int in Tab.values():
		result.append_array(_tabs[each])
	return result


## The items of a tab.
static func items_of(which: Tab) -> Array[int]:
	return _tabs[which]


## The tab an item is in (see the class).
static func tab_of(item: int) -> Tab:
	if Items.TOOLS.has(item) or Armor.is_armor(item) or GEAR.has(item) or item in Items.PAINTS:
		return Tab.TOOLS
	if Items.is_food(item):
		return Tab.FOOD
	if FARM_ITEMS.has(item):
		return Tab.FARM
	var voxel := Items.placed_voxel(item)
	if voxel == Voxels.AIR:
		return Tab.NATURE if WILD.has(item) else Tab.MATERIALS
	var block := Voxels.block_of(voxel)
	if block == Tiles.Block.AIR:
		# A ground: dirt, sand, snow...
		return Tab.NATURE
	var kind := ObjectShapes.pair_of(ObjectShapes.base_kind(block))
	if (
		Tiles.is_shaped(block)
		or RoofBlocks.is_dormer(block)
		or BuildShapes.material_of(block) != Tiles.Block.AIR
		or block == Tiles.Block.CHIMNEY
	):
		return Tab.SHAPES
	if (
		Glass.is_window(block)
		or Glass.is_pane(block)
		or Openings.is_door(block)
		or Openings.is_trapdoor(block)
		or OPENING_KINDS.has(kind)
	):
		return Tab.OPENINGS
	if Tiles.is_cube(block):
		return Tab.NATURE if NATURAL_CUBES.has(block) else Tab.BLOCKS
	if Farming.SOWN.has(block) or Growth.SAPLINGS.has(block) or FARM_KINDS.has(kind):
		return Tab.FARM
	return Tab.DECOR if DECOR_KINDS.has(kind) else Tab.FURNITURE


## The items whose name holds every word of `text` (in any language
## loaded; case and accents aside), those whose name begins with it first,
## then those with a word beginning with it, tab after tab.
static func search(text: String) -> Array[int]:
	var words := Chat.plain(text).split(" ", false)
	var found: Array[Vector2i] = []
	if words.is_empty():
		return []
	var every := order()
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


static func _sort() -> Dictionary:
	var tabs := {}
	for each: int in Tab.values():
		var items: Array[int] = []
		tabs[each] = items
	for item in range(Items.Id.NONE + 1, Items.Id.size()):
		if item != Items.Id.GUIDE_BOOK:
			(tabs[tab_of(item)] as Array[int]).append(item)
	var gear: Array[int] = tabs[Tab.TOOLS]
	gear.sort_custom(func(a: int, b: int) -> bool: return _gear_rank(a) < _gear_rank(b))
	return tabs


## Where an item of the tools' tab goes in it.
static func _gear_rank(item: int) -> int:
	var group := 3
	if Items.TOOLS.has(item):
		group = 0
	elif item in [Items.Id.BOW, Items.Id.ARROW]:
		group = 1
	elif Armor.is_armor(item):
		group = 2
	return group * Items.Id.size() + item


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


## The search field, the tabs (TAB_COLUMNS a row) and the caption.
func _build_head() -> void:
	head.add_theme_constant_override("separation", 2)
	head.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_field.placeholder_text = "CATALOG_SEARCH"
	_field.custom_minimum_size.x = SEARCH_WIDTH
	_field.clear_button_enabled = true
	_field.add_theme_stylebox_override("normal", _box(UiTheme.WOOD))
	_field.add_theme_stylebox_override("focus", _box(UiTheme.WOOD_DARK))
	_field.add_theme_color_override("font_color", UiTheme.INK)
	_field.add_theme_color_override("caret_color", UiTheme.INK)
	_field.add_theme_color_override("font_placeholder_color", UiTheme.WOOD)
	_field.add_theme_color_override("clear_button_color", UiTheme.WOOD)
	_field.add_theme_color_override("clear_button_color_pressed", UiTheme.WOOD_DARK)
	_field.add_theme_icon_override("clear", _cross())
	_field.text_changed.connect(func(_text: String) -> void: _refresh())
	head.add_child(_field)
	var tabs := GridContainer.new()
	tabs.columns = TAB_COLUMNS
	tabs.add_theme_constant_override("h_separation", 1)
	tabs.add_theme_constant_override("v_separation", 1)
	head.add_child(tabs)
	for each: int in Tab.values():
		var button := ItemSlot.new()
		button.slot = each
		button.library = library
		button.label = TABS[each][0]
		button.clicked.connect(
			func(which: int, _right: bool, _shift: bool) -> void: show_tab(which)
		)
		tabs.add_child(button)
		_tab_slots.append(button)
	_caption.add_theme_color_override("font_color", UiTheme.WOOD_DARK)
	head.add_child(_caption)


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	for slot in slots:
		slot.show_stack(item_at(slot.slot), 1)
	var searching := _searching()
	for button in _tab_slots:
		button.show_stack(TABS[button.slot][1], 1, button.slot == tab and not searching)


## Shows a tab (what was searched is let go).
func show_tab(which: int) -> void:
	tab = which as Tab
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
		_shown = _tabs[tab]
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
	_bar.draw_rect(Rect2(1.0, 0.0, BAR_WIDTH - 2.0, height), Color(UiTheme.WOOD, 0.3))
	var rows := maxi(ceili(_shown.size() / float(Inventory.HOTBAR)), 1)
	var thumb := roundf(height * minf(float(ROWS) / rows, 1.0))
	var last := _last_first_row()
	var top := roundf((height - thumb) * _first_row / last) if last > 0 else 0.0
	_bar.draw_rect(Rect2(0.0, top, BAR_WIDTH, thumb), UiTheme.WOOD)


## The search field's little cross that clears it (white: its color is
## the field's clear_button_color).
static func _cross() -> ImageTexture:
	var image := Image.create(CROSS, CROSS, false, Image.FORMAT_RGBA8)
	for i in CROSS:
		image.set_pixel(i, i, Color.WHITE)
		image.set_pixel(CROSS - 1 - i, i, Color.WHITE)
	return ImageTexture.create_from_image(image)


## The search field's frame (`border`: brown, darker with the keys).
static func _box(border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = UiTheme.PARCHMENT.lightened(0.4)
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(2)
	box.set_content_margin_all(2.0)
	box.anti_aliasing = false
	return box
