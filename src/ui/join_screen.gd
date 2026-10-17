class_name JoinScreen
extends Control
## Joining a dedicated server (multiplayer, step 2; opened from the pause
## menu): its address (an IP or a domain name; a port after ":" wins over
## the port's field), the player's name (Lobby.NAME), the server's password
## (if it has one) and the player's own (their account there, step 4: only
## its secret leaves, Access.secret_of; "Remember me" keeps that secret in
## ServerList for the next time, never the password); the servers joined
## lately fill them in a click, × forgets one. Join (or Enter) asks the
## game to leave this world and go (join_requested); Back (or Esc) closes
## it. `prefill` puts back what was tried (after a refusal).

signal join_requested(
	address: String, port: int, player_name: String, password: String, secret: String, keep: bool
)

const WIDTH := 250.0
## Recent servers shown at most.
const SHOWN := 5

var servers := ServerList.new()

var _address := LineEdit.new()
var _port := LineEdit.new()
var _name := LineEdit.new()
var _password := LineEdit.new()
var _account := LineEdit.new()
var _keep := CheckBox.new()
## The secret kept for the server picked (and the name it is for).
var _kept := ["", ""]
var _problem := Label.new()
var _recent := VBoxContainer.new()
var _recent_title := Label.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.08, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = WIDTH
	panel.add_child(box)
	var title := Label.new()
	title.text = "JOIN_TITLE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	box.add_child(title)
	_recent_title.text = "JOIN_RECENT"
	_recent_title.add_theme_color_override("font_color", UiTheme.WOOD)
	box.add_child(_recent_title)
	box.add_child(_recent)
	_address.placeholder_text = "JOIN_ADDRESS_HINT"
	box.add_child(_row("JOIN_ADDRESS", _address))
	_port.text = str(ServerConfig.DEFAULT_PORT)
	_port.max_length = 5
	box.add_child(_row("JOIN_PORT", _port))
	_name.max_length = 16
	box.add_child(_row("JOIN_NAME", _name))
	_password.secret = true
	_password.placeholder_text = "JOIN_PASSWORD_HINT"
	box.add_child(_row("JOIN_PASSWORD", _password))
	_account.secret = true
	_account.placeholder_text = "JOIN_ACCOUNT_HINT"
	box.add_child(_row("JOIN_ACCOUNT", _account))
	_keep.text = "JOIN_KEEP"
	_keep.button_pressed = true
	box.add_child(_keep)
	for field: LineEdit in [_address, _port, _name, _password, _account]:
		field.text_submitted.connect(_join.unbind(1))
	_problem.add_theme_color_override("font_color", Color("c0392b"))
	_problem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_problem.visible = false
	box.add_child(_problem)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var back := Button.new()
	back.text = "JOIN_BACK"
	back.pressed.connect(close)
	buttons.add_child(back)
	var join := Button.new()
	join.text = "JOIN_GO"
	join.pressed.connect(_join)
	buttons.add_child(join)
	box.add_child(buttons)


func open() -> void:
	servers.load_list()
	if _name.text.is_empty():
		_name.text = servers.last_name()
	_problem.visible = false
	_show_recent()
	visible = true
	_address.grab_focus()


func close() -> void:
	visible = false


## Puts back what was tried (the account's secret kept, if it was).
func prefill(address: String, port: int, player_name: String, secret: String) -> void:
	_address.text = address
	_port.text = str(port)
	_name.text = player_name
	_kept = [secret, player_name]
	_account.placeholder_text = "JOIN_ACCOUNT_KEPT" if secret != "" else "JOIN_ACCOUNT_HINT"


## [host, port] from what the player typed: an address, a port after ":"
## or else `port`; [] when it is none.
static func parse(text: String, port: int) -> Array:
	var host := text.strip_edges()
	if host.count(":") == 1:
		var after := host.get_slice(":", 1)
		if not after.is_valid_int():
			return []
		port = after.to_int()
		host = host.get_slice(":", 0)
	if host.is_empty() or " " in host or port < 1 or port > 65535:
		return []
	return [host, port]


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(InputBindings.PAUSE):
		close()
		get_viewport().set_input_as_handled()


func _join() -> void:
	var port := _port.text.to_int() if _port.text.is_valid_int() else 0
	var target := parse(_address.text, port)
	var name := _name.text.strip_edges()
	_problem.visible = target.is_empty() or not Lobby.is_name(name)
	if target.is_empty():
		_problem.text = "JOIN_BAD_ADDRESS"
	elif not Lobby.is_name(name):
		_problem.text = "REFUSED_NAME"
	else:
		visible = false
		var secret := Access.secret_of(name, _account.text)
		if _account.text.is_empty() and _kept[1] == name:
			secret = _kept[0]
		join_requested.emit(
			target[0], target[1], name, _password.text, secret, _keep.button_pressed
		)


## The servers joined lately: a click fills the fields, × forgets one.
func _show_recent() -> void:
	for row in _recent.get_children():
		row.queue_free()
	var shown := servers.servers.slice(0, SHOWN)
	_recent_title.visible = not shown.is_empty()
	for server: Dictionary in shown:
		var row := HBoxContainer.new()
		var pick := Button.new()
		var where := "%s:%d" % [server["address"], server["port"]]
		pick.text = "%s  (%s)" % [where, server["name"]]
		pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.clip_text = true
		pick.pressed.connect(_pick.bind(server))
		row.add_child(pick)
		var drop := Button.new()
		drop.text = "×"
		drop.tooltip_text = "JOIN_FORGET"
		drop.pressed.connect(_forget.bind(server))
		row.add_child(drop)
		_recent.add_child(row)


func _pick(server: Dictionary) -> void:
	prefill(server["address"], server["port"], server["name"], server.get("secret", ""))
	_password.grab_focus()


func _forget(server: Dictionary) -> void:
	servers.forget(server["address"], server["port"])
	_show_recent()


func _row(label_key: String, control: Control) -> HBoxContainer:
	return field_row(label_key, control)


## A field and its name before it (the join screen's, PasswordDialog's).
static func field_row(label_key: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_key
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	control.custom_minimum_size.x = 140
	row.add_child(control)
	return row
