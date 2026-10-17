class_name FurnaceParts
extends RefCounted
## A furnace as the inventory screen shows it (moved out of it). The food
## furnace (`area`): what it cooks over its fire and its fuel, an arrow
## filling up as it cooks, what it made, a word on what it is for. The
## factory furnace: its four lanes (`factory_area`: what each cooks, a bar
## filling up under it), its fire and how many times faster it burns, a
## word on it; and its three chests beside the screen's panel (`left`:
## what is to cook and its fuel; `right`: what it made).

## A slot of the furnace was clicked (its index in Furnace's slots).
signal clicked(slot: int, right: bool, shift: bool)

## The flame shown under what a furnace cooks: its rows' widths, from the
## bottom; and its colors (embers to tip).
const FLAME_ROWS: Array[int] = [8, 8, 8, 6, 6, 6, 4, 4, 2, 2]
const FLAME_COLORS: Array[Color] = [Color("ee6420"), Color("ffa634"), Color("ffe27a")]

var area: Control
var factory_area: Control
var left := VBoxContainer.new()
var right := VBoxContainer.new()
## The food furnace's slots (Furnace.SLOTS) and the factory's (by index,
## Furnace.FACTORY_SLOTS).
var slots: Array[ItemSlot] = []
var factory_slots: Array[ItemSlot] = []
## What is shown (null: none).
var furnace: Furnace

var _hint := Label.new()
var _flame := Control.new()
var _cooking := Control.new()
var _lane_bars: Array[Control] = []
var _factory_flame := Control.new()
var _burn_rate := Label.new()


func _init(library: ItemLibrary) -> void:
	for i in Furnace.SLOTS:
		slots.append(_slot(i, library))
	for i in Furnace.FACTORY_SLOTS:
		factory_slots.append(_slot(i, library))
	area = _food_furnace()
	factory_area = _factory()
	_side(left, "FURNACE_TO_COOK", Furnace.TO_COOK, Furnace.TO_COOK_SIZE)
	_side(left, "FURNACE_FUELS", Furnace.FUELS, Furnace.FUELS_SIZE)
	_side(right, "FURNACE_COOKED", Furnace.COOKED, Furnace.COOKED_SIZE)


## Shows `view` (null: hides everything).
func show_furnace(view: Furnace) -> void:
	furnace = view
	var factory := view != null and view.is_factory()
	area.visible = view != null and not factory
	factory_area.visible = factory
	left.visible = factory
	right.visible = factory
	if view != null:
		var food := view.kind == Tiles.Block.FOOD_FURNACE
		_hint.text = "FURNACE_FOOD_HINT" if food else "FURNACE_FACTORY_HINT"


## Every frame while it shows.
func refresh() -> void:
	if furnace == null:
		return
	if furnace.is_factory():
		var kept := furnace.slots
		for i in Furnace.FACTORY_SLOTS:
			factory_slots[i].show_stack(kept.items[i], kept.counts[i], false, kept.wear[i])
		for bar in _lane_bars:
			bar.queue_redraw()
		_factory_flame.queue_redraw()
		var cooking := furnace.lanes_cooking()
		_burn_rate.text = "x%d" % cooking if cooking > 1 and furnace.burning() else ""
		return
	var held := furnace.slots
	for i in Furnace.SLOTS:
		slots[i].show_stack(held.items[i], held.counts[i], false, held.wear[i])
	_flame.queue_redraw()
	_cooking.queue_redraw()


## The slots a drag can put items into: what cooks and burns.
func drop_slots() -> Array[ItemSlot]:
	var them: Array[ItemSlot] = [slots[Furnace.INPUT], slots[Furnace.FUEL]]
	them.append_array(factory_slots.slice(0, Furnace.COOKED))
	return them


## The slots that only give: what was made.
func given_slots() -> Array[ItemSlot]:
	var them: Array[ItemSlot] = [slots[Furnace.OUTPUT]]
	them.append_array(factory_slots.slice(Furnace.COOKED))
	return them


func owns(slot: ItemSlot) -> bool:
	return slot in slots or slot in factory_slots


func _slot(index: int, library: ItemLibrary) -> ItemSlot:
	var slot := ItemSlot.new()
	slot.slot = index
	slot.library = library
	slot.clicked.connect(
		func(at: int, right_button: bool, shift: bool) -> void:
			clicked.emit(at, right_button, shift)
	)
	return slot


## What it cooks over its fire and its fuel, an arrow, what it made; a
## word on what it is for under them.
func _food_furnace() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 1)
	row.add_child(column)
	column.add_child(slots[Furnace.INPUT])
	_flame.custom_minimum_size = Vector2(ItemSlot.SIZE, FLAME_ROWS.size() + 2.0)
	_flame.draw.connect(_draw_flame.bind(_flame))
	column.add_child(_flame)
	column.add_child(slots[Furnace.FUEL])
	_cooking.custom_minimum_size = Vector2(24.0, 0.0)
	_cooking.draw.connect(_draw_cooking)
	row.add_child(_cooking)
	var output := slots[Furnace.OUTPUT]
	output.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(output)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.custom_minimum_size.x = 120.0
	_hint.theme_type_variation = "HintLabel"
	box.add_child(_hint)
	return box


## Its four lanes (what each cooks, a bar filling up under it), its fire
## and how many times faster it burns, a word on it.
func _factory() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	var lanes := HBoxContainer.new()
	lanes.alignment = BoxContainer.ALIGNMENT_CENTER
	lanes.add_theme_constant_override("separation", 6)
	box.add_child(lanes)
	for lane in Furnace.LANE_COUNT:
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 1)
		lanes.add_child(column)
		column.add_child(factory_slots[Furnace.LANES + lane])
		var bar := Control.new()
		bar.custom_minimum_size = Vector2(ItemSlot.SIZE, 5.0)
		bar.draw.connect(_draw_lane.bind(bar, lane))
		column.add_child(bar)
		_lane_bars.append(bar)
	var fire := HBoxContainer.new()
	fire.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(fire)
	_factory_flame.custom_minimum_size = Vector2(ItemSlot.SIZE, FLAME_ROWS.size() + 2.0)
	_factory_flame.draw.connect(_draw_flame.bind(_factory_flame))
	fire.add_child(_factory_flame)
	_burn_rate.theme_type_variation = "HintLabel"
	fire.add_child(_burn_rate)
	var hint := UiTheme.label("FURNACE_FACTORY_LANES_HINT", "HintLabel")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.custom_minimum_size.x = 120.0
	box.add_child(hint)
	return box


## One of the factory's chests, titled, CHEST_COLUMNS across, in a panel
## of `side`.
func _side(side: VBoxContainer, title: String, first: int, count: int) -> void:
	side.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	side.add_theme_constant_override("separation", 4)
	side.visible = false
	var panel := PanelContainer.new()
	side.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	var label := UiTheme.label(title, "SectionLabel")
	label.uppercase = true
	box.add_child(label)
	var grid := GridContainer.new()
	grid.columns = Furnace.CHEST_COLUMNS
	grid.add_theme_constant_override("h_separation", 1)
	grid.add_theme_constant_override("v_separation", 1)
	box.add_child(grid)
	for i in count:
		grid.add_child(factory_slots[first + i])


## The fire: a flame burning down as its fuel goes (dim when out).
func _draw_flame(on: Control) -> void:
	var fire := furnace.fire if furnace != null else 0.0
	var lit_rows := ceili(fire * FLAME_ROWS.size())
	var bottom := on.size.y - 1.0
	for row in FLAME_ROWS.size():
		var width := float(FLAME_ROWS[row])
		var rect := Rect2(floorf((on.size.x - width) * 0.5), bottom - row - 1.0, width, 1.0)
		var color := UiTheme.LINE_STRONG
		if row < lit_rows:
			color = FLAME_COLORS[mini(row * FLAME_COLORS.size() / FLAME_ROWS.size(), 2)]
		on.draw_rect(rect, color)


## Under a lane: a bar filling up as it cooks.
func _draw_lane(bar: Control, lane: int) -> void:
	var progress := furnace.lane_progress[lane] if furnace != null else 0.0
	UiTheme.draw_gauge(bar, Rect2(1.0, 1.0, bar.size.x - 2.0, 3.0), progress, UiTheme.ACCENT)


## The arrow from the furnace to what it made, filling up as it cooks.
func _draw_cooking() -> void:
	var progress := furnace.progress if furnace != null else 0.0
	var middle := floorf(_cooking.size.y * 0.5)
	var length := _cooking.size.x - 3.0
	var head := 7.0
	for x in int(length):
		var half := 1.0 if x < length - head else ceilf((length - x) * 5.0 / head)
		var filled := x < progress * length
		var color := UiTheme.ACCENT if filled else UiTheme.LINE_STRONG
		_cooking.draw_rect(Rect2(1.0 + x, middle - half, 1.0, half * 2.0), color)
