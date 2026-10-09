class_name BoatPanel
extends VBoxContainer
## A boat's screen in the inventory (InventoryScreen.open_boat): at a
## shipyard its hull's slots (stern, sections, bow), then its engine, its
## coal and its net (its wear), its deck seen from above in its paint (the stern
## on the left, the pilot's thwart there, the bow on the right) holding a
## slot for each place (a bench or a chest; a chest's button opens it), a
## line saying how many it carries and how it goes, and its buttons:
## launch it (at a shipyard, its hull whole) or take it back up a shipyard
## near (afloat). Its slots are Boat's (Boat.click on the server).

signal clicked(slot: int, right: bool, shift: bool)
signal acted(act: int, place: int)

## The deck's drawing: its height, room for a place, the stern's and the
## bow's.
const DECK_HEIGHT := 34.0
const PLACE_ROOM := 26.0
const STERN_ROOM := 22.0
const BOW_ROOM := 26.0
const HULL := Color("946a3c")
const DECK := Color("c49a62")
const OUTLINE := Color("4a2c14")

var library: ItemLibrary
## The boats as the client knows them (BoatsView.boats) and the one shown
## (-1: none yet, an empty shipyard).
var source: Dictionary = {}
var id := -1
var at_yard := false

var _slots: Array[ItemSlot] = []
var _hull_row := HBoxContainer.new()
var _deck := Control.new()
var _opens: Array[Button] = []
var _launch := Button.new()
var _dock := Button.new()
var _info := Label.new()


func _ready() -> void:
	add_theme_constant_override("separation", 3)
	for slot in Boat.SLOT_COUNT:
		var item_slot := ItemSlot.new()
		item_slot.slot = slot
		item_slot.library = library
		item_slot.clicked.connect(
			func(at: int, right: bool, shift: bool) -> void: clicked.emit(at, right, shift)
		)
		_slots.append(item_slot)
	_slots[Boat.STERN].hint = Items.Id.BOAT_STERN
	_slots[Boat.SECTIONS].hint = Items.Id.BOAT_SECTION
	_slots[Boat.BOW].hint = Items.Id.BOAT_BOW
	_slots[Boat.ENGINE].hint = Items.Id.COAL_ENGINE
	_slots[Boat.FUEL].hint = Items.Id.COAL
	_slots[Boat.NET].hint = Items.Id.FISHING_NET
	_hull_row.add_theme_constant_override("separation", 2)
	_hull_row.add_child(_label("BOAT_HULL"))
	for slot: int in [Boat.STERN, Boat.SECTIONS, Boat.BOW]:
		_hull_row.add_child(_slots[slot])
	add_child(_hull_row)
	var engine_row := HBoxContainer.new()
	engine_row.add_theme_constant_override("separation", 2)
	engine_row.add_child(_label("BOAT_ENGINE"))
	for slot: int in [Boat.ENGINE, Boat.FUEL, Boat.NET]:
		engine_row.add_child(_slots[slot])
	add_child(engine_row)
	_deck.custom_minimum_size = Vector2(
		STERN_ROOM + PLACE_ROOM * Boat.MOST_PLACES + BOW_ROOM, DECK_HEIGHT + 12.0
	)
	_deck.draw.connect(_draw_deck)
	add_child(_deck)
	for place in Boat.MOST_PLACES:
		_deck.add_child(_slots[Boat.PLACE + place])
		var open := Button.new()
		open.text = "BOAT_OPEN_CHEST"
		open.add_theme_font_size_override("font_size", 6)
		open.pressed.connect(func() -> void: acted.emit(Boats.Act.OPEN_CHEST, place))
		_deck.add_child(open)
		_opens.append(open)
	_info.add_theme_color_override("font_color", UiTheme.WOOD)
	_info.add_theme_font_size_override("font_size", 6)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_info)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	_launch.text = "BOAT_LAUNCH"
	_launch.pressed.connect(func() -> void: acted.emit(Boats.Act.LAUNCH, -1))
	buttons.add_child(_launch)
	_dock.text = "BOAT_DOCK"
	_dock.pressed.connect(func() -> void: acted.emit(Boats.Act.DOCK, -1))
	buttons.add_child(_dock)
	add_child(buttons)


## Shows a boat's screen (`yard`: a shipyard's).
func show_boat(boats: Dictionary, shown: int, yard: bool) -> void:
	source = boats
	id = shown
	at_yard = yard


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	var boat: Boat = source.get(id)
	var places := boat.places() if boat != null else 2
	_hull_row.visible = at_yard
	for slot in Boat.SLOT_COUNT:
		var item := boat.slots.items[slot] if boat != null else Items.Id.NONE
		var count := boat.slots.counts[slot] if boat != null else 0
		var worn := boat.slots.wear[slot] if boat != null else 0
		_slots[slot].show_stack(item, count, false, worn)
	for place in Boat.MOST_PLACES:
		var item_slot := _slots[Boat.PLACE + place]
		item_slot.visible = place < places
		item_slot.position = Vector2(_place_x(place, places) - ItemSlot.SIZE * 0.5, 7.0)
		var open := _opens[place]
		open.visible = place < places and boat != null and boat.place_item(place) == Items.Id.CHEST
		open.position = Vector2(_place_x(place, places) - open.size.x * 0.5, 7.0 + ItemSlot.SIZE)
	_launch.visible = at_yard
	_launch.disabled = boat == null or not boat.complete()
	_dock.visible = not at_yard
	_info.text = _describe(boat)
	_deck.queue_redraw()


## Where a place's slot stands on the deck (its middle), stern first.
func _place_x(place: int, places: int) -> float:
	var length := STERN_ROOM + PLACE_ROOM * places + BOW_ROOM
	var left := (_deck.size.x - length) * 0.5
	return left + STERN_ROOM + PLACE_ROOM * (place + 0.5)


## The deck from above: the hull's planks, its stern square on the left with
## the pilot's thwart and tiller, its bow pointed on the right.
func _draw_deck() -> void:
	var boat: Boat = source.get(id)
	var places := boat.places() if boat != null else 2
	var length := STERN_ROOM + PLACE_ROOM * places + BOW_ROOM
	var left := floorf((_deck.size.x - length) * 0.5)
	var top := 2.0
	var bottom := top + DECK_HEIGHT
	var middle := (top + bottom) * 0.5
	var bow := left + length - BOW_ROOM
	var hull := PackedVector2Array(
		[
			Vector2(left, top),
			Vector2(bow, top),
			Vector2(left + length - 6.0, middle - 6.0),
			Vector2(left + length, middle),
			Vector2(left + length - 6.0, middle + 6.0),
			Vector2(bow, bottom),
			Vector2(left, bottom),
		]
	)
	var whole := boat != null and boat.complete()
	var outside := HULL
	if boat != null and boat.paint[0] >= 0:
		outside = Color(BoatModels.PAINT_COLORS[boat.paint[0]])
	_deck.draw_colored_polygon(hull, outside if whole else outside.darkened(0.3))
	var inside := PackedVector2Array()
	for point in hull:
		inside.append(point.lerp(Vector2(left + length * 0.5, middle), 0.08))
	_deck.draw_colored_polygon(inside, DECK if whole else DECK.darkened(0.3))
	hull.append(hull[0])
	if boat != null and boat.paint[1] >= 0:
		var stripe := Color(BoatModels.PAINT_COLORS[boat.paint[1]])
		var band := PackedVector2Array()
		for point in hull:
			band.append(point.lerp(Vector2(left + length * 0.5, middle), 0.04))
		_deck.draw_polyline(band, stripe, 2.0)
	_deck.draw_polyline(hull, OUTLINE, 1.0)
	# The pilot's thwart and the tiller at the stern.
	_deck.draw_rect(Rect2(left + 8.0, top + 3.0, 4.0, DECK_HEIGHT - 6.0), HULL.darkened(0.2))
	_deck.draw_line(Vector2(left - 4.0, middle), Vector2(left + 6.0, middle), OUTLINE, 2.0)


## How many it carries and how it goes.
func _describe(boat: Boat) -> String:
	if boat == null:
		return tr("BOAT_EMPTY_YARD")
	var text := tr("BOAT_PLACES") % boat.places()
	if not boat.complete():
		return text + " " + tr("BOAT_UNFINISHED")
	if boat.powered():
		text += " " + tr("BOAT_ENGINE_RUNS") % boat.fuel()
	else:
		text += " " + tr("BOAT_ROWED")
	if Nets.has_net(boat):
		var key := " / ".join(InputNames.keys(InputBindings.NET))
		text += " " + tr("BOAT_NET_HOW") % key
	return text


func _label(key: String) -> Label:
	var label := Label.new()
	label.text = key
	label.add_theme_color_override("font_color", UiTheme.WOOD)
	label.add_theme_font_size_override("font_size", 6)
	label.custom_minimum_size.x = 34.0
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label
