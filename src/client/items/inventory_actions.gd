class_name InventoryActions
extends RefCounted
## What the player does in the inventory screen and with what it opens (a
## workbench, a kitchen counter, a chest, a furnace, a shipyard, a boat): opening them, clicks,
## drags, double clicks, crafting, throwing what the cursor holds, closing. Each is shown
## at once on the client's copies (Inventory's rules, shared) and told to
## the server, which has the last word. GameClient owns it.

var client: GameClient
## Cells across of the crafting grid in use (a workbench's is wider).
var craft_width := Inventory.OWN_GRID
## The crafting grid is a kitchen counter's (Recipes: its dishes only).
var kitchen := false
## The chest open (what it holds as the server last told; null: none), and
## where it stands.
var chest: Inventory
var chest_cell := Vector3i.MAX
## The furnace open (as the server last told; null: none), and where it
## stands.
var furnace: Furnace
var furnace_cell := Vector3i.MAX
## The boat whose screen is open (-1: none or an empty shipyard's), and
## the shipyard's (NO_CELL: the boat's own screen).
var boat_id := -1
var boat_yard := GameServer.NO_CELL

## During a left drag: the slots as they were before it (the inventory,
## the chest's, the furnace's), each new share shown from there; empty
## when no drag is going on.
var _spread_base: Array = []


## Listens to the inventory screen.
func connect_screen(screen: InventoryScreen) -> void:
	screen.slot_clicked.connect(_on_slot_clicked)
	screen.cursor_dropped.connect(_on_cursor_dropped)
	screen.close_requested.connect(_on_inventory_closed)
	screen.craft_clicked.connect(_on_craft_clicked)
	screen.chest_clicked.connect(_on_chest_clicked)
	screen.furnace_clicked.connect(_on_furnace_clicked)
	screen.spread_previewed.connect(_on_spread_previewed)
	screen.spread_finished.connect(_on_spread_finished)
	screen.collect_requested.connect(_on_collect_requested)
	screen.catalog_clicked.connect(_on_catalog_clicked)
	screen.boat_clicked.connect(_on_boat_clicked)
	screen.boat_acted.connect(_on_boat_acted)


func open_inventory() -> void:
	client.interaction.stop()
	client.local_player.controls_enabled = false
	craft_width = Inventory.OWN_GRID
	kitchen = false
	client.inventory_screen.open(craft_width)


## Opens the kitchen counter standing in `cell`: the inventory with its
## grid making the dishes (the server is told: the grid makes them until it
## closes).
func open_kitchen(cell: Vector3i) -> void:
	client.interaction.stop()
	client.local_player.controls_enabled = false
	craft_width = Inventory.OWN_GRID
	kitchen = true
	client.transport.send(Msg.open_workbench(cell))
	client.inventory_screen.open(craft_width, true)


## Opens the chest standing in `cell`: its slots over the inventory (what
## it holds comes from the server).
func open_chest(cell: Vector3i) -> void:
	client.interaction.stop()
	client.local_player.controls_enabled = false
	craft_width = Inventory.OWN_GRID
	chest = Inventory.new()
	chest_cell = cell
	client.transport.send(Msg.open_chest(cell))
	client.inventory_screen.open_chest(chest)


## Opens the shipyard standing in `cell` (the screen opens when the server
## says which boat is on it: show_boat_screen).
func open_yard(cell: Vector3i) -> void:
	client.interaction.stop()
	client.transport.send(Msg.open_yard(cell))


## Opens a boat's own screen (its shipyard's if it lies on one).
func open_boat(id: int) -> void:
	client.interaction.stop()
	client.transport.send(Msg.open_boat(id))


## The server's answer (Msg.BOAT_SCREEN): a boat's or a shipyard's screen.
func show_boat_screen(yard: Vector3i, id: int) -> void:
	boat_id = id
	boat_yard = yard
	client.local_player.controls_enabled = false
	craft_width = Inventory.OWN_GRID
	chest = null
	chest_cell = Vector3i.MAX
	client.inventory_screen.open_boat(client.boats.boats, id, yard != GameServer.NO_CELL)


func _on_boat_clicked(slot: int, right: bool, shift: bool) -> void:
	client.transport.send(Msg.boat_click(slot, right, shift))


## A button of a boat's screen; a chest's opens it over the bag (its
## contents come from the server).
func _on_boat_acted(act: int, place: int) -> void:
	client.transport.send(Msg.boat_act(act, place))
	if act == Boats.Act.OPEN_CHEST and boat_id >= 0:
		chest = Inventory.new()
		chest_cell = Boats.chest_cell(boat_id, place)
		client.inventory_screen.open_chest(chest)


## A click on the creative catalog.
func _on_catalog_clicked(item: int, right: bool, shift: bool) -> void:
	GameModes.take_from_catalog(client.inventory, item, right, shift)
	client.transport.send(Msg.catalog_click(item, right, shift))


func _on_chest_clicked(slot: int, right: bool, shift: bool) -> void:
	if chest != null:
		client.inventory.click_chest(chest, slot, right, shift)
		client.transport.send(Msg.chest_click(slot, right, shift))


## Opens the furnace standing in `cell`: its slots over the inventory
## (what it holds and how it burns come from the server).
func open_furnace(cell: Vector3i) -> void:
	client.interaction.stop()
	client.local_player.controls_enabled = false
	craft_width = Inventory.OWN_GRID
	furnace = Furnace.new(ObjectShapes.furnace_kind(Voxels.block_of(client.world.voxel_at(cell))))
	furnace_cell = cell
	client.transport.send(Msg.open_furnace(cell))
	client.inventory_screen.open_furnace(furnace)


func _on_furnace_clicked(slot: int, right: bool, shift: bool) -> void:
	if furnace != null:
		client.inventory.click_furnace(furnace, slot, right, shift)
		client.transport.send(Msg.furnace_click(slot, right, shift))


## Opens the workbench standing in `cell`: the inventory with its 5 x 5
## crafting grid (the server is told: its grid is used until it closes).
func open_workbench(cell: Vector3i) -> void:
	client.interaction.stop()
	client.local_player.controls_enabled = false
	craft_width = Inventory.GRID
	client.transport.send(Msg.open_workbench(cell))
	client.inventory_screen.open(craft_width)


func _on_slot_clicked(slot: int, right: bool, shift: bool) -> void:
	client.inventory.click(slot, right, shift, chest, furnace)
	client.transport.send(Msg.slot_click(slot, right, shift))


## A left drag crossed one more slot: the stack shared between those so
## far, shown from the slots as they were before the drag.
func _on_spread_previewed(targets: Array) -> void:
	if _spread_base.is_empty():
		_spread_base = [
			client.inventory.snapshot(),
			chest.snapshot() if chest != null else null,
			furnace.slots.snapshot() if furnace != null else null,
		]
	else:
		client.inventory.restore(_spread_base[0])
		if chest != null and _spread_base[1] != null:
			chest.restore(_spread_base[1])
		if furnace != null and _spread_base[2] != null:
			furnace.slots.restore(_spread_base[2])
	client.inventory.spread(targets, chest, furnace)


## The left drag is over: what shows is the share, the server is told.
func _on_spread_finished(targets: Array) -> void:
	_spread_base = []
	client.transport.send(Msg.slot_spread(targets))


## A double click: the cursor's stack gathers its kind (predicted, then
## told to the server).
func _on_collect_requested() -> void:
	client.inventory.collect(chest, furnace)
	client.transport.send(Msg.slot_collect())


func _on_cursor_dropped(whole: bool) -> void:
	var count := client.inventory.counts[Inventory.CURSOR]
	client.inventory.take(Inventory.CURSOR, count if whole else 1)
	client.transport.send(Msg.item_drop(Inventory.CURSOR, whole))


func _on_inventory_closed() -> void:
	client.local_player.controls_enabled = true
	kitchen = false
	chest = null
	chest_cell = Vector3i.MAX
	furnace = null
	furnace_cell = Vector3i.MAX
	boat_id = -1
	boat_yard = GameServer.NO_CELL
	_spread_base = []
	client.inventory.put_back_all()
	client.transport.send(Msg.inventory_close())


## The chest or furnace open was broken (or broke): its screen closes.
func close_if_gone(cell: Vector3i) -> void:
	var block := Voxels.block_of(client.world.voxel_at(cell))
	var gone := (
		(chest != null and cell == chest_cell and not ObjectShapes.is_chest(block))
		or (furnace != null and cell == furnace_cell and ObjectShapes.furnace_kind(block) == -1)
	)
	if gone or (boat_yard == cell and not ObjectShapes.is_shipyard(block)):
		client.inventory_screen.close()


## A boat went: its screen (or its chest's) closes.
func close_if_boat_gone(id: int) -> void:
	if id == boat_id and boat_id >= 0:
		client.inventory_screen.close()


func _on_craft_clicked(shift: bool) -> void:
	client.inventory.craft(craft_width, shift, kitchen)
	client.transport.send(Msg.craft(shift))
