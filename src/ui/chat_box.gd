class_name ChatBox
extends Control
## The chat, at the bottom left over the hotbar's height. T opens it, "/"
## opens it on a command; Enter sends what is typed to the server
## (Msg.chat: it says it to every player, or runs the command, Chat and
## Commands), Esc closes, Up and Down go back through what was sent, Tab
## completes a command and its words (ChatCompletion: what it could be
## shows under the lines; Tab again goes through them, Shift back). The
## lines the server sends (Msg.CHAT_LINE: what players said, the answers
## to commands, in the reader's language) fade LINE_SECONDS after they
## came; while typing, the last TYPING_LINES show on a dark wooden board
## and the wheel scrolls back through them. The world takes no key nor
## click while the player types (GameClient.screen_open).

## How long a line stays, then fades (seconds); how many show.
const LINE_SECONDS := 10.0
const FADE_SECONDS := 1.5
const SHOWN_LINES := 8
const TYPING_LINES := 16
## Lines kept to scroll back to; lines sent kept for Up and Down.
const KEPT_LINES := 100
const SENT_KEPT := 50
## Size and place (UI units): widest, and over the hotbar.
const WIDTH := 260.0
const MARGIN := 6.0
const BOTTOM := 52.0
const INPUT_HEIGHT := 14.0
## Kept free at the top of the screen (the board stops under it).
const TOP_ROOM := 28.0
const NAME_COLOR := "f3c86b"
const TONE_COLORS := {
	Chat.Tone.INFO: "f5e6c8",
	Chat.Tone.DONE: "b8e08a",
	Chat.Tone.ERROR: "f09a86",
	Chat.Tone.WHISPER: "d6b8f0",
}
const SAID_COLOR := "ffffff"
const HINT_COLOR := Color("d8c39a")
## Options of a completion shown at most.
const HINTS := 8
const SLASH := 47

var client: GameClient
## The player is typing (the box takes the keys).
var typing := false

## {"text": bbcode, "age": seconds}, oldest first.
var _lines: Array[Dictionary] = []
var _sent := PackedStringArray()
var _sent_at := 0
## Lines scrolled back while typing.
var _scroll := 0
var _board := PanelContainer.new()
var _log := VBoxContainer.new()
var _labels: Array[RichTextLabel] = []
## The line of each label shown (-1: none).
var _shown: Array[int] = []
var _entry := LineEdit.new()
## What Tab can complete (ChatCompletion), where that part starts, the one
## shown (-1: none yet) and the text as Tab left it.
var _options := PackedStringArray()
var _option_start := 0
var _option_at := -1
var _completed := ""
var _hint := Label.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_board.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_board.add_child(_log)
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log.add_theme_constant_override("separation", 1)
	add_child(_board)
	for i in TYPING_LINES:
		var label := RichTextLabel.new()
		label.bbcode_enabled = true
		label.fit_content = true
		label.scroll_active = false
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		_log.add_child(label)
		_labels.append(label)
		_shown.append(-1)
	_entry.max_length = Chat.MAX_LENGTH
	_entry.visible = false
	_entry.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_entry.add_theme_stylebox_override("normal", _box(UiTheme.PARCHMENT, UiTheme.WOOD, 1.0))
	_entry.add_theme_stylebox_override("focus", _box(UiTheme.PARCHMENT, UiTheme.WOOD_DARK, 1.0))
	_entry.add_theme_color_override("font_color", UiTheme.INK)
	_entry.add_theme_color_override("caret_color", UiTheme.INK)
	_entry.add_theme_color_override("font_placeholder_color", UiTheme.WOOD)
	_entry.placeholder_text = "CHAT_PLACEHOLDER"
	_entry.text_submitted.connect(_on_submitted)
	_entry.text_changed.connect(_on_typed)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_color_override("font_color", HINT_COLOR)
	_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_hint.visible = false
	_log.add_child(_hint)
	_entry.focus_exited.connect(_keep_focus)
	add_child(_entry)
	_set_board(false)
	_layout()


## Opens the chat to type, `prefix` already typed ("/" for a command).
func open(prefix := "") -> void:
	typing = true
	_scroll = 0
	_sent_at = _sent.size()
	_entry.text = prefix
	_entry.visible = true
	_entry.grab_focus()
	_entry.caret_column = prefix.length()
	client.interaction.stop()
	client.local_player.controls_enabled = false
	_set_board(true)
	_refresh()


func close() -> void:
	if not typing:
		return
	typing = false
	_on_typed("")
	_entry.visible = false
	_entry.release_focus()
	client.local_player.controls_enabled = not client.vitals.passed_out
	_set_board(false)
	_refresh()


## A line from the server (Msg.CHAT_LINE).
func show_line(message: Dictionary) -> void:
	var text := ""
	if message.has("from"):
		text = (
			"[color=#%s]%s[/color]  [color=#%s]%s[/color]"
			% [NAME_COLOR, _escape(message["from"]), SAID_COLOR, _escape(message["text"])]
		)
	else:
		var color: String = TONE_COLORS.get(int(message.get("tone", 0)), SAID_COLOR)
		text = "[color=#%s]%s[/color]" % [color, _escape(notice_text(message))]
	_lines.append({"text": text, "age": 0.0})
	if _lines.size() > KEPT_LINES:
		_lines.pop_front()
	_scroll = 0
	_refresh()


## A notice in the reader's language: its key with its args, the words
## among them ({"key": ...}) translated too.
static func notice_text(message: Dictionary) -> String:
	var args := []
	for arg: Variant in message.get("args", []):
		if arg is Dictionary:
			args.append(String(TranslationServer.translate(arg.get("key", ""))))
		else:
			args.append(arg)
	var text := String(TranslationServer.translate(message.get("key", "")))
	return text % args if not args.is_empty() else text


## Lines age and fade; the newest show, as many as fit over the hotbar
## (long ones take several rows).
func _process(delta: float) -> void:
	_layout()
	for line in _lines:
		line["age"] += delta
	var room := size.y - BOTTOM - INPUT_HEIGHT - TOP_ROOM
	if _hint.visible:
		room -= _hint.get_combined_minimum_size().y + 1.0
	var full := false
	for i in range(_labels.size() - 1, -1, -1):
		var index := _shown[i]
		if index < 0 or index >= _lines.size():
			continue
		var faded := 1.0
		if not typing:
			var left: float = LINE_SECONDS + FADE_SECONDS - _lines[index]["age"]
			faded = clampf(left / FADE_SECONDS, 0.0, 1.0)
		var height := _labels[i].get_combined_minimum_size().y + 1.0
		full = full or height > room
		room -= height
		_labels[i].modulate.a = faded
		_labels[i].visible = faded > 0.0 and not full


## While typing: Esc closes, Up and Down go through what was sent, the
## wheel scrolls, Tab completes (it would move the focus otherwise).
func _input(event: InputEvent) -> void:
	if not typing:
		return
	if event.is_action_pressed(InputBindings.PAUSE):
		close()
	elif event is InputEventKey and event.pressed:
		match (event as InputEventKey).keycode:
			KEY_UP:
				_browse(-1)
			KEY_DOWN:
				_browse(1)
			KEY_TAB:
				_complete(-1 if (event as InputEventKey).shift_pressed else 1)
			_:
				return
	elif event is InputEventMouseButton and event.pressed:
		var button := (event as InputEventMouseButton).button_index
		if button == MOUSE_BUTTON_WHEEL_UP:
			_scroll = mini(_scroll + 1, maxi(_lines.size() - TYPING_LINES, 0))
		elif button == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll = maxi(_scroll - 1, 0)
		else:
			return
		_refresh()
	else:
		return
	get_viewport().set_input_as_handled()


## T (or "/") opens the chat over the world; while typing, nothing goes
## through to it.
func _unhandled_input(event: InputEvent) -> void:
	if typing:
		get_viewport().set_input_as_handled()
		return
	if not _can_open():
		return
	var key := event as InputEventKey
	if event.is_action_pressed(InputBindings.CHAT):
		open()
	elif key != null and key.pressed and not key.echo and key.unicode == SLASH:
		open("/")
	else:
		return
	get_viewport().set_input_as_handled()


func _can_open() -> bool:
	return (
		client != null
		and client.joined
		and not client.get_tree().paused
		and not client.inventory_screen.visible
		and not client.book_screen.visible
	)


func _on_submitted(text: String) -> void:
	var line := text.strip_edges()
	if not line.is_empty():
		client.transport.send(Msg.chat(line))
		if _sent.is_empty() or _sent[-1] != line:
			_sent.append(line)
			if _sent.size() > SENT_KEPT:
				_sent.remove_at(0)
	close()


## Tab: the part being typed becomes what it can only be, or what all it
## can be begin with; then each in turn (`step`: -1 back).
func _complete(step: int) -> void:
	var text := _entry.text
	if _option_at >= 0 and text == _completed and _options.size() > 1:
		_option_at = posmod(_option_at + step, _options.size())
		_set_text(text.left(_option_start) + _options[_option_at])
		return
	var found := ChatCompletion.options(text)
	_options = found["options"]
	_option_start = found["start"]
	_option_at = -1
	if _options.is_empty():
		_show_hint()
		return
	var base := text.left(_option_start)
	if _options.size() == 1:
		_set_text(base + _options[0] + " ")
		_options.clear()
	else:
		var common := ChatCompletion.common_start(_options)
		var typed := text.substr(_option_start)
		if common.length() > typed.length():
			_set_text(base + common)
		else:
			_option_at = 0 if step > 0 else _options.size() - 1
			_set_text(base + _options[_option_at])
	_show_hint()


func _set_text(text: String) -> void:
	_entry.text = text
	_entry.caret_column = text.length()
	_completed = text


## What the part typed could be, under the lines (none: hidden).
func _show_hint() -> void:
	_hint.visible = _options.size() > 1
	if _hint.visible:
		var shown := ", ".join(_options.slice(0, HINTS))
		_hint.text = shown + (" …" if _options.size() > HINTS else "")
		_board.visible = true


## The player typed: a completion starts again.
func _on_typed(_text: String) -> void:
	_options.clear()
	_option_at = -1
	_show_hint()


## Back (-1) or forth (1) through the lines sent; past the last, empty.
func _browse(step: int) -> void:
	if _sent.is_empty():
		return
	_sent_at = clampi(_sent_at + step, 0, _sent.size())
	_entry.text = _sent[_sent_at] if _sent_at < _sent.size() else ""
	_entry.caret_column = _entry.text.length()


func _keep_focus() -> void:
	if typing:
		_entry.grab_focus.call_deferred()


## Which lines show in which labels: the last ones (scrolled back while
## typing), oldest at the top.
func _refresh() -> void:
	var count := TYPING_LINES if typing else SHOWN_LINES
	var last := _lines.size() - 1 - (_scroll if typing else 0)
	var first := maxi(last - count + 1, 0)
	for i in _labels.size():
		var index := first + i
		var label := _labels[i]
		if i >= count or index > last:
			_shown[i] = -1
			label.visible = false
			continue
		if _shown[i] != index:
			label.text = _lines[index]["text"]
		_shown[i] = index
		label.visible = true
	_board.visible = typing or last >= 0


## The board and the input line at the bottom left, as wide as the screen
## lets them.
func _layout() -> void:
	var width := minf(WIDTH, size.x - MARGIN * 2.0)
	for label in _labels:
		label.custom_minimum_size.x = width
	_hint.custom_minimum_size.x = width
	_board.offset_left = MARGIN
	_board.offset_bottom = -BOTTOM - INPUT_HEIGHT - 2.0
	_board.offset_top = _board.offset_bottom
	_board.offset_right = MARGIN + width
	_entry.offset_left = MARGIN
	_entry.offset_right = MARGIN + width
	_entry.offset_bottom = -BOTTOM
	_entry.offset_top = -BOTTOM - INPUT_HEIGHT


## The board shows (a dark wooden plank behind the lines) while typing;
## otherwise the lines float over the world.
func _set_board(shown: bool) -> void:
	if shown:
		var board := _box(Color(UiTheme.WOOD_DARK, 0.72), UiTheme.WOOD, 1.0)
		_board.add_theme_stylebox_override("panel", board)
	else:
		_board.add_theme_stylebox_override("panel", StyleBoxEmpty.new())


static func _box(color: Color, border: Color, margin: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(2)
	box.set_content_margin_all(margin + 2.0)
	box.anti_aliasing = false
	return box


## Text shown as typed, not as bbcode.
static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")
