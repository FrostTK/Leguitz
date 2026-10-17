class_name PasswordDialog
extends Control
## Changing one's account password on a server (multiplayer, step 4; from
## the pause menu): the current one, the new one twice. Change (or Enter)
## asks for it (change_requested: the passwords as typed; Online sends
## their secrets); Back (or Esc) closes it. The server's answer comes back
## through `answered`.

signal change_requested(old: String, new: String)

const WIDTH := 240.0

var _old := LineEdit.new()
var _new := LineEdit.new()
var _again := LineEdit.new()
var _problem := Label.new()


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
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = WIDTH
	panel.add_child(box)
	var title := Label.new()
	title.text = "PASSWORD_TITLE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.theme_type_variation = "TitleLabel"
	box.add_child(title)
	for row: Array in [["PASSWORD_OLD", _old], ["PASSWORD_NEW", _new], ["PASSWORD_AGAIN", _again]]:
		var field: LineEdit = row[1]
		field.secret = true
		field.text_submitted.connect(_change.unbind(1))
		box.add_child(JoinScreen.field_row(row[0], field))
	_problem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_problem.visible = false
	box.add_child(_problem)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var back := Button.new()
	back.text = "JOIN_BACK"
	back.pressed.connect(close)
	buttons.add_child(back)
	var change := Button.new()
	change.text = "PASSWORD_CHANGE"
	change.theme_type_variation = "AccentButton"
	change.pressed.connect(_change)
	buttons.add_child(change)
	box.add_child(buttons)


func open() -> void:
	for field in [_old, _new, _again]:
		field.text = ""
	_problem.visible = false
	visible = true
	_old.grab_focus()


func close() -> void:
	visible = false


## The server's answer: done (the dialog closes) or the current password
## was wrong.
func answered(done: bool) -> void:
	if done:
		close()
	else:
		_say("PASSWORD_WRONG", true)


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(InputBindings.PAUSE):
		close()
		get_viewport().set_input_as_handled()


func _change() -> void:
	if _new.text.is_empty():
		_say("PASSWORD_EMPTY", true)
	elif _new.text != _again.text:
		_say("PASSWORD_DIFFER", true)
	else:
		_say("PASSWORD_WAIT", false)
		change_requested.emit(_old.text, _new.text)


func _say(key: String, wrong: bool) -> void:
	_problem.text = key
	_problem.visible = true
	var color := UiTheme.DANGER if wrong else UiTheme.MUTED
	_problem.add_theme_color_override("font_color", color)
