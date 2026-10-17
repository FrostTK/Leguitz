class_name JoinScreen
extends Control
## Joining a dedicated server (multiplayer, step 2; opened from the pause
## menu): its address (an IP or a domain name; a port after ":" wins over
## the port's field), the player's name (Lobby.NAME), the server's password
## (if it has one) and the player's own (their account there, step 4: only
## its secret leaves, Access.secret_of; "Remember me" keeps that secret in
## ServerList for the next time, never the password); the servers joined
## lately (in cards on the left, step 5 of the redesign) fill them in a
## click, × forgets one. The fields are named over them (`field_row`, also
## PasswordDialog's). Join (or Enter) asks the game to leave this world and
## go (join_requested); Back (or Esc) closes it. `prefill` puts back what
## was tried (after a refusal). It opens fading in (UiTheme.appear).

signal join_requested(
	address: String, port: int, player_name: String, password: String, secret: String, keep: bool
)

const WIDTH := 210.0
const RECENT_WIDTH := 150.0
const PORT_WIDTH := 52.0
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
var _recent_area := VBoxContainer.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	add_child(UiTheme.shade())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 10)
	panel.add_child(columns)
	_recent_area.custom_minimum_size.x = RECENT_WIDTH
	_recent_area.add_theme_constant_override("separation", 4)
	var recent_title := UiTheme.label("JOIN_RECENT", "SectionLabel")
	recent_title.uppercase = true
	_recent_area.add_child(recent_title)
	_recent.add_theme_constant_override("separation", 3)
	_recent_area.add_child(_recent)
	columns.add_child(_recent_area)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = WIDTH
	box.add_theme_constant_override("separation", 5)
	columns.add_child(box)
	box.add_child(UiTheme.label("JOIN_TITLE", "TitleLabel"))
	var where := HBoxContainer.new()
	_address.placeholder_text = "JOIN_ADDRESS_HINT"
	var address := field_row("JOIN_ADDRESS", _address)
	address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	where.add_child(address)
	_port.text = str(ServerConfig.DEFAULT_PORT)
	_port.max_length = 5
	var port := field_row("JOIN_PORT", _port)
	port.custom_minimum_size.x = PORT_WIDTH
	where.add_child(port)
	box.add_child(where)
	_name.max_length = 16
	box.add_child(field_row("JOIN_NAME", _name))
	_password.secret = true
	_password.placeholder_text = "JOIN_PASSWORD_HINT"
	box.add_child(field_row("JOIN_PASSWORD", _password))
	_account.secret = true
	_account.placeholder_text = "JOIN_ACCOUNT_HINT"
	box.add_child(field_row("JOIN_ACCOUNT", _account))
	_keep.text = "JOIN_KEEP"
	_keep.button_pressed = true
	box.add_child(_keep)
	for field: LineEdit in [_address, _port, _name, _password, _account]:
		field.text_submitted.connect(_join.unbind(1))
	_problem.add_theme_color_override("font_color", UiTheme.DANGER)
	_problem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_problem.visible = false
	box.add_child(_problem)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	var back := Button.new()
	back.text = "JOIN_BACK"
	back.pressed.connect(close)
	buttons.add_child(back)
	var join := Button.new()
	join.text = "JOIN_GO"
	join.theme_type_variation = "AccentButton"
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
	UiTheme.appear(self)


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


## The servers joined lately, in cards (the address, the name played
## under): a click fills the fields, × forgets one.
func _show_recent() -> void:
	for row in _recent.get_children():
		row.queue_free()
	var shown := servers.servers.slice(0, SHOWN)
	_recent_area.visible = not shown.is_empty()
	for server: Dictionary in shown:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var card := PanelContainer.new()
		card.theme_type_variation = "CardPanel"
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var lines := VBoxContainer.new()
		lines.add_theme_constant_override("separation", 0)
		var where := UiTheme.label("%s:%d" % [server["address"], server["port"]])
		where.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		where.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		where.custom_minimum_size.x = 1.0
		lines.add_child(where)
		var who := UiTheme.label(server["name"], "HintLabel")
		who.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		lines.add_child(who)
		card.add_child(lines)
		# A flat button over the card takes the click (lighter under the mouse).
		var pick := Button.new()
		var light := UiTheme.box(Color(1.0, 1.0, 1.0, 0.06), Color.TRANSPARENT, 3, 0.0)
		for state in ["normal", "focus", "disabled", "hover", "pressed", "hover_pressed"]:
			var lit: bool = state in ["hover", "pressed", "hover_pressed"]
			pick.add_theme_stylebox_override(state, light if lit else StyleBoxEmpty.new())
		pick.focus_mode = Control.FOCUS_NONE
		pick.pressed.connect(_pick.bind(server))
		card.add_child(pick)
		row.add_child(card)
		var drop := Button.new()
		drop.text = "×"
		drop.theme_type_variation = "ChipButton"
		drop.tooltip_text = "JOIN_FORGET"
		drop.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		drop.pressed.connect(_forget.bind(server))
		row.add_child(drop)
		_recent.add_child(row)


func _pick(server: Dictionary) -> void:
	prefill(server["address"], server["port"], server["name"], server.get("secret", ""))
	_password.grab_focus()


func _forget(server: Dictionary) -> void:
	servers.forget(server["address"], server["port"])
	_show_recent()


## A field and its name over it (the join screen's, PasswordDialog's).
static func field_row(label_key: String, control: Control) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 1)
	column.add_child(UiTheme.label(label_key, "HintLabel"))
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(control)
	return column
