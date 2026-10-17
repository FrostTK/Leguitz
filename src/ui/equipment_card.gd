class_name EquipmentCard
extends PanelContainer
## The inventory's left card: what the player wears. Its title, the body
## (CharacterPreview: wearing it, holding what is in hand, turned by a
## drag) beside the armor's four slots (each taking its own piece; the
## shape of the piece while empty), and under them the protection they
## give (a shield and the points).

var preview := CharacterPreview.new()
var slots: Array[ItemSlot] = []

var _shield := Control.new()
var _points := 0


## Made by the inventory screen: `make_slot` makes one of its slots.
func build(make_slot: Callable, library: ItemLibrary) -> void:
	theme_type_variation = "CardPanel"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	add_child(box)
	var title := UiTheme.label("INVENTORY_WORN", "SectionLabel")
	title.uppercase = true
	box.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	box.add_child(row)
	preview.library = library
	row.add_child(preview)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 1)
	row.add_child(column)
	for piece in Armor.PIECES:
		var slot: ItemSlot = make_slot.call(Inventory.ARMOR + piece)
		slot.hint = Armor.ITEMS.find_key([piece, Armor.Kind.HIDE])
		slots.append(slot)
		column.add_child(slot)
	_shield.custom_minimum_size = Vector2(0.0, 9.0)
	_shield.draw.connect(_draw_shield)
	box.add_child(_shield)


## What the player wears and holds (every frame while it shows).
func refresh(inventory: Inventory, held: int) -> void:
	var worn: Array[int] = []
	for piece in Armor.PIECES:
		worn.append(inventory.items[Inventory.ARMOR + piece])
	preview.show_player(worn, held)
	var points := Armor.defense(inventory)
	if points != _points:
		_points = points
		_shield.queue_redraw()


## The protection worn: a steel shield (dim with nothing worn) and the
## points.
func _draw_shield() -> void:
	VitalsBar.draw_shield(_shield, Vector2(1.0, 1.0), _points > 0)
	var font := _shield.get_theme_default_font()
	var size := UiTheme.SMALL_FONT_SIZE
	var text := tr("INVENTORY_DEFENSE") % _points
	var baseline := Vector2(11.0, 1.0 + font.get_ascent(size))
	var color := UiTheme.TEXT if _points > 0 else UiTheme.FAINT
	_shield.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
