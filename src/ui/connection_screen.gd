class_name ConnectionScreen
extends Control
## The connection to a dedicated server, over the game (GameClient): while
## it connects (`show_connecting`), when the server refuses the player
## (`show_refused`: Msg.REFUSED's reason) and when it is lost or was never
## made (`show_ended`: NetClient.ending). Ended, a button quits the game.
## The world takes no input while it shows (GameClient.screen_open).

signal quit_requested

const SHADE := Color(0.02, 0.02, 0.05, 0.82)
const WIDTH := 220.0

var _title := Label.new()
var _text := Label.new()
var _quit := Button.new()
## Where the server is ("address:port").
var _address := ""
## A refusal or an end was shown: what comes after keeps it.
var _ended := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = WIDTH
	panel.add_child(box)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_text)
	_quit.text = "CONNECTION_QUIT"
	_quit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_quit.pressed.connect(quit_requested.emit)
	box.add_child(_quit)
	visible = false


## Connecting to the server at `address`.
func show_connecting(address: String) -> void:
	_address = address
	if _ended:
		return
	_title.text = "CONNECTION_TITLE_CONNECTING"
	_text.text = tr("CONNECTION_CONNECTING") % address
	_quit.visible = false
	visible = true


## Joined: the screen goes.
func joined() -> void:
	if not _ended:
		visible = false


## The server refused the player (`reason`: a translation key).
func show_refused(reason: String) -> void:
	_show_end("CONNECTION_TITLE_REFUSED", tr(reason))


## The connection ended (`why`: CONNECTION_LOST, CONNECTION_UNREACHABLE).
func show_ended(why: String) -> void:
	if _ended:
		return
	var unreachable := why == "CONNECTION_UNREACHABLE"
	var title := "CONNECTION_TITLE_UNREACHABLE" if unreachable else "CONNECTION_TITLE_LOST"
	_show_end(title, tr(why) % _address if "%s" in tr(why) else tr(why))


func is_ended() -> bool:
	return _ended


func _show_end(title: String, text: String) -> void:
	_ended = true
	_title.text = title
	_text.text = text
	_quit.visible = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SHADE)
