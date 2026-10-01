class_name Hotbar
extends VBoxContainer
## The 9 hotbar slots at the bottom of the screen, the one in hand
## highlighted; its name shows above for a moment when it changes.

const NAME_SECONDS := 1.6

var inventory: Inventory
var library: ItemLibrary

var _slots: Array[ItemSlot] = []
var _name := Label.new()
var _name_left := 0.0
var _shown_item := -1
var _shown_slot := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_END
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.add_theme_color_override("font_color", Color.WHITE)
	_name.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_name.add_theme_constant_override("shadow_offset_x", 1)
	_name.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_name)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	for i in Inventory.HOTBAR:
		var slot := ItemSlot.new()
		slot.slot = i
		slot.library = library
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(slot)
		_slots.append(slot)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 4)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN


func _process(delta: float) -> void:
	if inventory == null:
		return
	for i in Inventory.HOTBAR:
		_slots[i].show_stack(inventory.items[i], inventory.counts[i], i == inventory.selected)
	# The name of what is in hand, when it changes.
	var held := inventory.held()
	if held != _shown_item or inventory.selected != _shown_slot:
		_shown_item = held
		_shown_slot = inventory.selected
		_name.text = Items.name_key(held) if held != Items.Id.NONE else ""
		_name_left = NAME_SECONDS
	_name_left -= delta
	_name.modulate.a = clampf(_name_left / 0.4, 0.0, 1.0)
