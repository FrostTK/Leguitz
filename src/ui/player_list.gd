class_name PlayerList
extends Control
## Who plays (multiplayer, step 2), shown while its key is held
## (InputBindings.PLAYER_LIST, when `can_show` allows): the server, then
## each player in the order they came, the admins marked, and how long
## their messages take there and back (Msg.PLAYERS: Peers.roster).

## A ping under these (milliseconds) is good, fair; slower is poor.
const GOOD_PING := 80
const FAIR_PING := 200
const GOOD := UiTheme.SUCCESS
const FAIR := UiTheme.ACCENT
const POOR := UiTheme.DANGER

## Who plays: [{id, name, ping, admin}].
var roster: Array = []
var player_id := -1
## The server ("address:port"; "": solo).
var server := ""
## Whether it may show now (no screen over the world).
var can_show := func() -> bool: return true

var _title := Label.new()
var _grid := GridContainer.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var panel := PanelContainer.new()
	panel.position.y = 24
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 160
	panel.add_child(box)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_grid.columns = 2
	box.add_child(_grid)
	panel.resized.connect(func() -> void: panel.position.x = -panel.size.x * 0.5)


func _process(_delta: float) -> void:
	var wanted: bool = Input.is_action_pressed(InputBindings.PLAYER_LIST) and can_show.call()
	if wanted and not visible:
		_fill()
	visible = wanted


## The roster as the server tells it.
func set_roster(players: Array) -> void:
	roster = players
	if visible:
		_fill()


## Whether the local player is one of the server's admins.
func is_admin() -> bool:
	for entry: Dictionary in roster:
		if entry.get("id") == player_id:
			return entry.get("admin", false)
	return false


func _fill() -> void:
	var where := server if server != "" else tr("PLAYERS_SOLO")
	_title.text = tr("PLAYERS_TITLE") % [roster.size(), where]
	for child in _grid.get_children():
		child.queue_free()
	for entry: Dictionary in roster:
		var name := Label.new()
		name.text = str(entry.get("name", ""))
		var tag := {
			Access.Role.ADMIN: "PLAYERS_ADMIN",
			Access.Role.MODERATOR: "PLAYERS_MODERATOR",
			Access.Role.VISITOR: "PLAYERS_VISITOR",
		}
		var role := int(entry.get("role", Access.Role.PLAYER))
		if entry.get("admin", false):
			role = Access.Role.ADMIN
		if tag.has(role):
			name.text += "  " + tr(tag[role])
		if entry.get("id") == player_id:
			name.add_theme_color_override("font_color", UiTheme.ACCENT)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.add_child(name)
		var ping := Label.new()
		var ms := int(entry.get("ping", 0))
		ping.text = tr("PLAYERS_PING") % ms if ms > 0 else ""
		ping.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		ping.add_theme_color_override("font_color", _ping_color(ms))
		_grid.add_child(ping)


static func _ping_color(ms: int) -> Color:
	if ms < GOOD_PING:
		return GOOD
	return FAIR if ms < FAIR_PING else POOR
