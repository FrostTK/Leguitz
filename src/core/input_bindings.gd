class_name InputBindings
extends RefCounted
## Default controls, registered in code so they can be rebound and saved
## later from the settings menu.
##
## Movement keys use *physical* key positions: WASD on a QWERTY keyboard
## is automatically ZQSD on a French AZERTY keyboard. Letter shortcuts
## (M for the map...) use the letter printed on the key instead.

const MOVE_UP := &"move_up"
const MOVE_DOWN := &"move_down"
const MOVE_LEFT := &"move_left"
const MOVE_RIGHT := &"move_right"
const SPRINT := &"sprint"
const JUMP := &"jump"
const PAUSE := &"pause"
const TOGGLE_DEBUG := &"toggle_debug"
const ZOOM_IN := &"zoom_in"
const ZOOM_OUT := &"zoom_out"
const TOGGLE_MAP := &"toggle_map"
## Camera: orbit with the gamepad's right stick (the mouse drags it), and
## back to the default view.
const CAMERA_LEFT := &"camera_left"
const CAMERA_RIGHT := &"camera_right"
const CAMERA_UP := &"camera_up"
const CAMERA_DOWN := &"camera_down"
const CAMERA_RESET := &"camera_reset"
## Switches between the top-down view and the first-person view.
const TOGGLE_VIEW := &"toggle_view"
# Debug (creative-only later).
const DEPTH_UP := &"depth_up"
const DEPTH_DOWN := &"depth_down"
const TOGGLE_NOCLIP := &"toggle_noclip"
const CYCLE_WEATHER := &"cycle_weather"

const STICK_DEADZONE := 0.25


static func register_defaults() -> void:
	_bind(
		MOVE_UP,
		[_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0), _button(JOY_BUTTON_DPAD_UP)]
	)
	_bind(
		MOVE_DOWN,
		[_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0), _button(JOY_BUTTON_DPAD_DOWN)]
	)
	_bind(
		MOVE_LEFT,
		[_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0), _button(JOY_BUTTON_DPAD_LEFT)]
	)
	_bind(
		MOVE_RIGHT,
		[
			_key(KEY_D),
			_key(KEY_RIGHT),
			_axis(JOY_AXIS_LEFT_X, 1.0),
			_button(JOY_BUTTON_DPAD_RIGHT),
		]
	)
	_bind(SPRINT, [_key(KEY_SHIFT), _button(JOY_BUTTON_LEFT_STICK)])
	_bind(JUMP, [_key(KEY_SPACE), _button(JOY_BUTTON_A)])
	_bind(PAUSE, [_key(KEY_ESCAPE), _button(JOY_BUTTON_START)])
	_bind(TOGGLE_DEBUG, [_key(KEY_F3), _button(JOY_BUTTON_BACK)])
	_bind(
		ZOOM_IN,
		[
			_key(KEY_EQUAL),
			_key(KEY_KP_ADD),
			_mouse(MOUSE_BUTTON_WHEEL_UP),
			_button(JOY_BUTTON_RIGHT_SHOULDER),
		]
	)
	_bind(
		ZOOM_OUT,
		[
			_key(KEY_MINUS),
			_key(KEY_KP_SUBTRACT),
			_mouse(MOUSE_BUTTON_WHEEL_DOWN),
			_button(JOY_BUTTON_LEFT_SHOULDER),
		]
	)
	_bind(CAMERA_LEFT, [_axis(JOY_AXIS_RIGHT_X, -1.0)])
	_bind(CAMERA_RIGHT, [_axis(JOY_AXIS_RIGHT_X, 1.0)])
	_bind(CAMERA_UP, [_axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_bind(CAMERA_DOWN, [_axis(JOY_AXIS_RIGHT_Y, 1.0)])
	_bind(CAMERA_RESET, [_key(KEY_HOME), _button(JOY_BUTTON_RIGHT_STICK)])
	_bind(TOGGLE_VIEW, [_key(KEY_F5), _button(JOY_BUTTON_X)])
	_bind(TOGGLE_MAP, [_letter(KEY_M), _button(JOY_BUTTON_Y)])
	_bind(DEPTH_UP, [_key(KEY_PAGEUP)])
	_bind(DEPTH_DOWN, [_key(KEY_PAGEDOWN)])
	_bind(TOGGLE_NOCLIP, [_key(KEY_F4)])
	_bind(CYCLE_WEATHER, [_key(KEY_F6)])


static func _bind(action: StringName, events: Array[InputEvent]) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, STICK_DEADZONE)
	for event in events:
		InputMap.action_add_event(action, event)


static func _key(physical_key: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = physical_key
	return event


static func _mouse(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	return event


static func _letter(key: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = key
	return event


static func _button(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	return event


static func _axis(axis: JoyAxis, direction: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = direction
	return event
