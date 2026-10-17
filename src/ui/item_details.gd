class_name ItemDetails
extends HBoxContainer
## The inventory's bottom line: what the item under the mouse is (its
## name, then what is worth knowing, in grey: what is left of a tool or a
## piece of armor, the water in a can, what a tool is for, the protection
## a piece gives, how much a food feeds, its effects, whether it makes
## sick, how long it burns in a furnace; cut short with an ellipsis where
## the line ends); with nothing under the mouse, a word on the clicks.

## Between two facts.
const DOT := "  ·  "
## What each kind of tool is for.
const TOOL_USES := {
	Items.Tool.PICKAXE: "DETAILS_PICKAXE",
	Items.Tool.AXE: "DETAILS_AXE",
	Items.Tool.SHOVEL: "DETAILS_SHOVEL",
	Items.Tool.SWORD: "DETAILS_SWORD",
	Items.Tool.HOE: "DETAILS_HOE",
}

## What shows (an item and its wear; Items.Id.NONE: the word on clicks).
var _item := -1
var _wear := -1
var _name := Label.new()
var _facts := Label.new()


func _init() -> void:
	add_theme_constant_override("separation", 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for label: Label in [_name, _facts]:
		label.add_theme_font_size_override("font_size", UiTheme.SMALL_FONT_SIZE)
		add_child(label)
	_facts.add_theme_color_override("font_color", UiTheme.MUTED)
	_facts.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_facts.custom_minimum_size.x = 1.0


## Tells about `item` (worn `wear`; Items.Id.NONE: the word on clicks).
func show_item(item: int, wear := 0) -> void:
	if item == _item and wear == _wear:
		return
	_item = item
	_wear = wear
	_name.text = tr(Items.name_key(item)) if item != Items.Id.NONE else ""
	var facts := facts_of(item, wear) if item != Items.Id.NONE else PackedStringArray()
	if item == Items.Id.NONE:
		_facts.text = tr("INVENTORY_HINT")
	else:
		_facts.text = DOT + DOT.join(facts) if not facts.is_empty() else ""


## What is worth knowing about an item worn `wear` (translated).
func facts_of(item: int, wear: int) -> PackedStringArray:
	var facts := PackedStringArray()
	var lasts := Items.durability(item)
	if item == Items.Id.WATERING_CAN:
		facts.append(tr("DETAILS_WATER") % [wear, Items.CAN_WATER])
	elif lasts > 0:
		facts.append(tr("DETAILS_LEFT") % [lasts - wear, lasts])
	if Items.TOOLS.has(item):
		facts.append(tr(TOOL_USES[Items.TOOLS[item][0]]))
	if Armor.is_armor(item):
		facts.append(tr("DETAILS_PROTECTION") % Armor.points_of(item))
	if Food.SATIETY.has(item):
		facts.append(tr("DETAILS_FEEDS") % Food.SATIETY[item])
	for kind: int in Effects.OF_FOOD.get(item, {}):
		facts.append(tr(Effects.NAME_KEYS[kind]))
	if Vitals.POISONS.has(item):
		facts.append(tr("DETAILS_SICK"))
	if Smelting.FUEL_SECONDS.has(item):
		facts.append(tr("DETAILS_BURNS") % roundi(Smelting.FUEL_SECONDS[item]))
	return facts
