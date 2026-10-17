class_name CraftCard
extends PanelContainer
## The inventory's right card: crafting. Its title (crafting, or cooking at
## a kitchen counter), the grid (the inventory's 3 x 3, a workbench's 5 x 5:
## the cells past the width in use hide), an arrow and what the grid makes,
## its name and how many under them. In a block's screen (a workbench, a
## kitchen counter) it lies in the block's card, without a frame or a
## title of its own (`set_framed`).

## What the grid makes was clicked (shift: as many as possible).
signal craft_clicked(shift: bool)

## What the grid makes, and the grid's cells (all GRID x GRID, row by row).
var result := ItemSlot.new()
var cells: Array[ItemSlot] = []

var _title := UiTheme.label("CRAFTING_TITLE", "SectionLabel")
var _grid := GridContainer.new()
var _made := UiTheme.label("", "HintLabel")
var _shown := Vector2i(-1, -1)


## Made by the inventory screen: `make_slot` makes one of its slots.
func build(make_slot: Callable, library: ItemLibrary) -> void:
	theme_type_variation = "CardPanel"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	add_child(box)
	_title.uppercase = true
	box.add_child(_title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	_grid.add_theme_constant_override("h_separation", 1)
	_grid.add_theme_constant_override("v_separation", 1)
	row.add_child(_grid)
	for cell in Inventory.GRID * Inventory.GRID:
		var slot: ItemSlot = make_slot.call(Inventory.CRAFT + cell)
		cells.append(slot)
		_grid.add_child(slot)
	var arrow := Control.new()
	arrow.custom_minimum_size = Vector2(12.0, 0.0)
	arrow.draw.connect(_draw_arrow.bind(arrow))
	row.add_child(arrow)
	result.library = library
	result.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	result.clicked.connect(
		func(_slot: int, _right: bool, shift: bool) -> void: craft_clicked.emit(shift)
	)
	row.add_child(result)
	_made.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_made.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_made)


## The grid `width` cells across; `cooking`: a kitchen counter's.
func set_width(width: int, cooking: bool) -> void:
	_title.text = "KITCHEN_COOK" if cooking else "CRAFTING_TITLE"
	_grid.columns = width
	for cell in cells.size():
		cells[cell].visible = cell % Inventory.GRID < width and cell / Inventory.GRID < width
	# The name under the grid wraps within it.
	_made.custom_minimum_size.x = width * (ItemSlot.SIZE + 1.0) + 12.0 + ItemSlot.SIZE


## In a card of its own (the inventory) or bare (a block's screen).
func set_framed(framed: bool) -> void:
	_title.visible = framed
	if framed:
		remove_theme_stylebox_override("panel")
	else:
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())


## What the grid makes now: [item, count].
func show_result(made: Vector2i) -> void:
	result.show_stack(made.x, made.y)
	if made == _shown:
		return
	_shown = made
	var name := tr(Items.name_key(made.x)) if made.x != Items.Id.NONE else ""
	_made.text = tr("CRAFT_MAKES") % [made.y, name] if made.y > 1 else name


## An arrow pointing from the grid to what it makes.
static func _draw_arrow(arrow: Control) -> void:
	var middle := floorf(arrow.size.y * 0.5)
	arrow.draw_rect(Rect2(1.0, middle - 1.0, 6.0, 2.0), UiTheme.MUTED)
	arrow.draw_colored_polygon(
		PackedVector2Array(
			[Vector2(6.0, middle - 4.0), Vector2(11.0, middle), Vector2(6.0, middle + 4.0)]
		),
		UiTheme.MUTED
	)
