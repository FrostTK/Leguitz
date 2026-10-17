class_name ConnectionScreen
extends Control
## The connection to a dedicated server, over the game (GameClient): while
## it connects (`show_connecting`), when the server refuses the player
## (`show_refused`: Msg.REFUSED's reason) and when it is lost or was never
## made (`show_ended`: NetClient.ending). Ended, its buttons try the same
## server again, open the join screen for another, go back to the solo
## world or quit the game; connecting, one goes back to solo. Over its
## title, an amber arc turns while it connects; ended, a red sign. The
## world takes no input while it shows (GameClient.screen_open).

signal quit_requested
signal retry_requested
signal other_requested
signal solo_requested

const SHADE := Color(UiTheme.SHADE, 0.85)
const WIDTH := 220.0
## The sign over the title: its size (UI units) and how fast the arc
## turns (radians a second).
const SIGN := 16.0
const TURN_SPEED := 5.0

var _title := Label.new()
var _text := Label.new()
var _quit := Button.new()
var _retry := Button.new()
var _other := Button.new()
var _solo := Button.new()
## Where the server is ("address:port").
var _address := ""
## A refusal or an end was shown: what comes after keeps it.
var _ended := false
var _sign := Control.new()
var _turn := 0.0


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
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)
	_sign.custom_minimum_size = Vector2(SIGN, SIGN)
	_sign.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_sign.draw.connect(_draw_sign)
	box.add_child(_sign)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.theme_type_variation = "TitleLabel"
	box.add_child(_title)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_color_override("font_color", UiTheme.MUTED)
	box.add_child(_text)
	var buttons := GridContainer.new()
	buttons.columns = 2
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(buttons)
	var choices := [
		[_retry, "CONNECTION_RETRY", retry_requested],
		[_other, "CONNECTION_OTHER", other_requested],
		[_solo, "CONNECTION_SOLO", solo_requested],
		[_quit, "CONNECTION_QUIT", quit_requested],
	]
	for choice: Array in choices:
		var button: Button = choice[0]
		button.text = choice[1]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect((choice[2] as Signal).emit)
		buttons.add_child(button)
	_retry.theme_type_variation = "AccentButton"
	visible = false


## Connecting to the server at `address`.
func show_connecting(address: String) -> void:
	_address = address
	if _ended:
		return
	_title.text = "CONNECTION_TITLE_CONNECTING"
	_text.text = tr("CONNECTION_CONNECTING") % address
	_show_buttons(false)
	_solo.text = "CONNECTION_CANCEL"
	_appear()


## Joined: the screen goes.
func joined() -> void:
	if not _ended:
		visible = false


## The server refused the player (`reason`: a translation key, with its
## `args`: Chat.notice_text).
func show_refused(reason: String, args := []) -> void:
	_show_end("CONNECTION_TITLE_REFUSED", Chat.notice_text({"key": reason, "args": args}))


## The server sent the player away (as show_refused).
func show_kicked(reason: String, args := []) -> void:
	_show_end("CONNECTION_TITLE_KICKED", Chat.notice_text({"key": reason, "args": args}))


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
	_show_buttons(true)
	_solo.text = "CONNECTION_SOLO"
	_appear()
	_sign.queue_redraw()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Shows the screen, fading in when it was hidden.
func _appear() -> void:
	if not visible:
		visible = true
		UiTheme.appear(self)


func _process(delta: float) -> void:
	if visible and not _ended:
		_turn = fmod(_turn + delta * TURN_SPEED, TAU)
		_sign.queue_redraw()


## Connecting: an amber arc turning on a faint ring; ended: a red ring and
## an exclamation mark.
func _draw_sign() -> void:
	var middle := _sign.size * 0.5
	var radius := SIGN * 0.5 - 1.0
	if not _ended:
		_sign.draw_arc(middle, radius, 0.0, TAU, 32, UiTheme.LINE_STRONG, 2.0, true)
		_sign.draw_arc(middle, radius, _turn, _turn + PI * 0.6, 16, UiTheme.ACCENT, 2.0, true)
		return
	_sign.draw_arc(middle, radius, 0.0, TAU, 32, UiTheme.DANGER, 2.0, true)
	_sign.draw_rect(Rect2(middle + Vector2(-1.0, -4.5), Vector2(2.0, 5.0)), UiTheme.DANGER)
	_sign.draw_rect(Rect2(middle + Vector2(-1.0, 2.0), Vector2(2.0, 2.0)), UiTheme.DANGER)


## Ended: every choice; connecting: back to solo only.
func _show_buttons(ended: bool) -> void:
	for button: Button in [_retry, _other, _quit]:
		button.visible = ended
	_solo.visible = true


func _draw() -> void:
	var reach := Vector2(0.0, UiTheme.APPEAR_RISE)
	draw_rect(Rect2(-reach, size + reach * 2.0), SHADE)
