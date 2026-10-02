class_name CreativeCatalog
extends HBoxContainer
## The creative catalog (in the inventory screen, over the bag): every
## item, the blocks first, then what stands in the world (plants,
## furniture), the materials, the food, the tools and weapons, then the
## bow, arrows and armor; ROWS rows at a time,
## scrolled by the wheel or the bar beside them (a click or a drag on it).
## A click on an item is reported (GameModes.take_from_catalog says what
## it does).

signal item_clicked(item: int, right: bool, shift: bool)

const ROWS := 5
const BAR_WIDTH := 4.0

var library: ItemLibrary
## The slots shown, ROWS rows of Inventory.HOTBAR (`slot`: the place in
## the view).
var slots: Array[ItemSlot] = []

var _items := order()
## The first row of items in view.
var _first_row := 0
var _grid := GridContainer.new()
var _bar := Control.new()


## Every item but the player's book: blocks, then things standing in the
## world, materials, food, tools, the bow, arrows and armor (in Items
## order within each).
static func order() -> Array[int]:
	var result: Array[int] = []
	for item in range(Items.Id.NONE + 1, Items.Id.size()):
		if item != Items.Id.GUIDE_BOOK:
			result.append(item)
	result.sort_custom(func(a: int, b: int) -> bool: return _rank(a) < _rank(b))
	return result


static func _rank(item: int) -> int:
	var group := 2
	var voxel := Items.placed_voxel(item)
	if Items.TOOLS.has(item):
		group = 4
	elif Armor.is_armor(item) or item in [Items.Id.BOW, Items.Id.ARROW]:
		group = 5
	elif voxel != Voxels.AIR:
		group = 0 if Voxels.is_cube(voxel) else 1
	elif Items.is_food(item):
		group = 3
	return group * Items.Id.size() + item


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


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	for slot in slots:
		slot.show_stack(item_at(slot.slot), 1)


## The item in place `index` of the view (Items.Id.NONE: past the last).
func item_at(index: int) -> int:
	var at := _first_row * Inventory.HOTBAR + index
	return _items[at] if at < _items.size() else Items.Id.NONE


## Scrolls by `rows` (down for more).
func scroll(rows: int) -> void:
	_first_row = clampi(_first_row + rows, 0, _last_first_row())
	_bar.queue_redraw()


func _last_first_row() -> int:
	return maxi(ceili(_items.size() / float(Inventory.HOTBAR)) - ROWS, 0)


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
	var rows := ceili(_items.size() / float(Inventory.HOTBAR))
	var thumb := roundf(height * minf(float(ROWS) / rows, 1.0))
	var last := _last_first_row()
	var top := roundf((height - thumb) * _first_row / last) if last > 0 else 0.0
	_bar.draw_rect(Rect2(0.0, top, BAR_WIDTH, thumb), UiTheme.WOOD)
