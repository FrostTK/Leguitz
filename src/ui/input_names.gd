class_name InputNames
extends RefCounted
## What the player presses for an action, in their own words: the letters
## of their keyboard layout (ZQSD on a French keyboard), translated names
## for the other keys, the mouse buttons and the gamepad's sticks.

## Translation keys of the keys named with a word, and keys named with a
## symbol.
const KEY_WORDS := {
	KEY_SPACE: "KEY_SPACE",
	KEY_SHIFT: "KEY_SHIFT",
	KEY_CTRL: "KEY_CTRL",
	KEY_ESCAPE: "KEY_ESCAPE",
	KEY_HOME: "KEY_HOME",
	KEY_PAGEUP: "KEY_PAGE_UP",
	KEY_PAGEDOWN: "KEY_PAGE_DOWN",
	KEY_UP: "KEY_UP",
	KEY_DOWN: "KEY_DOWN",
	KEY_LEFT: "KEY_LEFT",
	KEY_RIGHT: "KEY_RIGHT",
	KEY_ENTER: "KEY_ENTER",
	KEY_TAB: "KEY_TAB",
	KEY_KP_ADD: "KEY_KP_ADD",
	KEY_KP_SUBTRACT: "KEY_KP_SUBTRACT",
}
const KEY_SYMBOLS := {KEY_EQUAL: "=", KEY_MINUS: "-", KEY_PLUS: "+"}
const MOUSE_WORDS := {
	MOUSE_BUTTON_LEFT: "MOUSE_LEFT",
	MOUSE_BUTTON_RIGHT: "MOUSE_RIGHT",
	MOUSE_BUTTON_MIDDLE: "MOUSE_MIDDLE",
}
## Gamepad buttons (as printed on Xbox-like pads) and sticks.
const PAD_BUTTONS := {
	JOY_BUTTON_A: "A",
	JOY_BUTTON_B: "B",
	JOY_BUTTON_X: "X",
	JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_START: "Start",
	JOY_BUTTON_BACK: "Select",
	JOY_BUTTON_DPAD_UP: "PAD_DPAD",
	JOY_BUTTON_DPAD_DOWN: "PAD_DPAD",
	JOY_BUTTON_DPAD_LEFT: "PAD_DPAD",
	JOY_BUTTON_DPAD_RIGHT: "PAD_DPAD",
}
const PAD_AXES := {
	JOY_AXIS_LEFT_X: "PAD_LEFT_STICK",
	JOY_AXIS_LEFT_Y: "PAD_LEFT_STICK",
	JOY_AXIS_RIGHT_X: "PAD_RIGHT_STICK",
	JOY_AXIS_RIGHT_Y: "PAD_RIGHT_STICK",
	JOY_AXIS_TRIGGER_LEFT: "LT",
	JOY_AXIS_TRIGGER_RIGHT: "RT",
}


## The keyboard keys and mouse buttons of an action.
static func keys(action: StringName) -> PackedStringArray:
	return _names(action, false)


## The gamepad buttons and sticks of an action.
static func pad(action: StringName) -> PackedStringArray:
	return _names(action, true)


## The four movement keys in one word (ZQSD, WASD...).
static func movement_keys() -> String:
	var word := ""
	for action in [
		InputBindings.MOVE_UP,
		InputBindings.MOVE_LEFT,
		InputBindings.MOVE_DOWN,
		InputBindings.MOVE_RIGHT,
	]:
		var names := keys(action)
		word += names[0] if not names.is_empty() else "?"
	return word


## The name of a key, a mouse button or a gamepad input ("" if unknown).
static func name_of(event: InputEvent) -> String:
	var key := event as InputEventKey
	if key != null:
		var code := key.keycode
		if key.physical_keycode != KEY_NONE:
			code = key.physical_keycode
			# What is printed there on the player's keyboard (no keyboard
			# without a screen).
			if DisplayServer.get_name() != "headless":
				var label := DisplayServer.keyboard_get_label_from_physical(code)
				code = label if label != KEY_NONE else code
		if KEY_WORDS.has(code):
			return _t(KEY_WORDS[code])
		if KEY_SYMBOLS.has(code):
			return KEY_SYMBOLS[code]
		return OS.get_keycode_string(code)
	var mouse := event as InputEventMouseButton
	if mouse != null:
		return _t(MOUSE_WORDS.get(mouse.button_index, ""))
	var button := event as InputEventJoypadButton
	if button != null:
		return _t(PAD_BUTTONS.get(button.button_index, ""))
	var axis := event as InputEventJoypadMotion
	if axis != null:
		return _t(PAD_AXES.get(axis.axis, ""))
	return ""


static func _names(action: StringName, gamepad: bool) -> PackedStringArray:
	var names := PackedStringArray()
	if not InputMap.has_action(action):
		return names
	for event in InputMap.action_get_events(action):
		var is_pad := event is InputEventJoypadButton or event is InputEventJoypadMotion
		if is_pad != gamepad:
			continue
		var name := name_of(event)
		if not name.is_empty() and not names.has(name):
			names.append(name)
	return names


static func _t(key: String) -> String:
	return String(TranslationServer.translate(key)) if not key.is_empty() else ""
