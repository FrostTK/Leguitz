class_name ChipBar
extends HBoxContainer
## A row of chips (UiTheme's ChipButton), one chosen at a time, in amber:
## the bag's filters, the creative catalog's tabs. A chip shows an item's
## icon (from `library`, once rendered) or its name (a translation key, its
## tooltip either way).

signal chosen(id: int)

var library: ItemLibrary
## The chip chosen (its id; -1: none).
var selected := -1

var _group := ButtonGroup.new()
## id -> [its button, the item it shows (Items.Id.NONE: its name)].
var _chips := {}


func _init() -> void:
	add_theme_constant_override("separation", 2)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Adds a chip: its `id`, its name (a key) and the item it shows (none:
## the name instead).
func add_chip(id: int, key: String, item := Items.Id.NONE) -> void:
	var chip := Button.new()
	chip.theme_type_variation = "ChipButton"
	chip.toggle_mode = true
	chip.button_group = _group
	chip.focus_mode = Control.FOCUS_NONE
	chip.tooltip_text = key
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if item == Items.Id.NONE:
		chip.text = key
	else:
		chip.custom_minimum_size = Vector2(16.0, 0.0)
		chip.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		set_process(true)
	chip.toggled.connect(
		func(on: bool) -> void:
			if on and selected != id:
				selected = id
				chosen.emit(id)
	)
	add_child(chip)
	_chips[id] = [chip, item]


## Chooses a chip without telling (-1: none).
func select(id: int) -> void:
	if id == selected:
		return
	selected = id
	for each: int in _chips:
		(_chips[each][0] as Button).set_pressed_no_signal(each == id)


## Icons come after the start: put on once rendered.
func _process(_delta: float) -> void:
	if library == null:
		return
	var waiting := false
	for each: int in _chips:
		var chip: Button = _chips[each][0]
		var item: int = _chips[each][1]
		if item != Items.Id.NONE and chip.icon == null:
			chip.icon = library.icon(item)
			waiting = waiting or chip.icon == null
	set_process(waiting)
