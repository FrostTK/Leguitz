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
## Gamepad triggers: break (held) and place (the mouse buttons are handled
## by GameClient: a right click places, a right drag turns the camera).
const BREAK := &"break"
const PLACE := &"place"
## Items: the inventory screen, throwing what is in hand (with Ctrl: the
## whole stack), the hotbar slot in hand (the mouse wheel is handled by
## GameClient, see wheel_zooms). Physical keys, next to the movement
## keys whatever the keyboard.
const INVENTORY := &"inventory"
const DROP_ITEM := &"drop_item"
const HOTBAR_NEXT := &"hotbar_next"
const HOTBAR_PREVIOUS := &"hotbar_previous"
const HOTBAR_SLOTS: Array[StringName] = [
	&"hotbar_1",
	&"hotbar_2",
	&"hotbar_3",
	&"hotbar_4",
	&"hotbar_5",
	&"hotbar_6",
	&"hotbar_7",
	&"hotbar_8",
	&"hotbar_9",
]
# Debug (creative-only later).
const DEPTH_UP := &"depth_up"
const DEPTH_DOWN := &"depth_down"
const TOGGLE_NOCLIP := &"toggle_noclip"
const CYCLE_WEATHER := &"cycle_weather"
## Gives the tools of the next material, until they can be crafted.
const GIVE_TOOLS := &"give_tools"

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
	_bind(ZOOM_IN, [_key(KEY_EQUAL), _key(KEY_KP_ADD)])
	_bind(ZOOM_OUT, [_key(KEY_MINUS), _key(KEY_KP_SUBTRACT)])
	_bind(INVENTORY, [_key(KEY_E)])
	_bind(DROP_ITEM, [_key(KEY_Q)])
	_bind(HOTBAR_NEXT, [_button(JOY_BUTTON_RIGHT_SHOULDER)])
	_bind(HOTBAR_PREVIOUS, [_button(JOY_BUTTON_LEFT_SHOULDER)])
	for i in HOTBAR_SLOTS.size():
		_bind(HOTBAR_SLOTS[i], [_key(KEY_1 + i)])
	_bind(CAMERA_LEFT, [_axis(JOY_AXIS_RIGHT_X, -1.0)])
	_bind(CAMERA_RIGHT, [_axis(JOY_AXIS_RIGHT_X, 1.0)])
	_bind(CAMERA_UP, [_axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_bind(CAMERA_DOWN, [_axis(JOY_AXIS_RIGHT_Y, 1.0)])
	_bind(CAMERA_RESET, [_key(KEY_HOME), _button(JOY_BUTTON_RIGHT_STICK)])
	_bind(TOGGLE_VIEW, [_key(KEY_F5), _button(JOY_BUTTON_X)])
	_bind(BREAK, [_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)])
	_bind(PLACE, [_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)])
	_bind(TOGGLE_MAP, [_letter(KEY_M), _button(JOY_BUTTON_Y)])
	_bind(DEPTH_UP, [_key(KEY_PAGEUP)])
	_bind(DEPTH_DOWN, [_key(KEY_PAGEDOWN)])
	_bind(TOGGLE_NOCLIP, [_key(KEY_F4)])
	_bind(CYCLE_WEATHER, [_key(KEY_F6)])
	_bind(GIVE_TOOLS, [_key(KEY_F7)])


## Whether a turn of the mouse wheel zooms rather than picking the hotbar
## slot: with the wheel button held down in the top-down view, or with Ctrl.
static func wheel_zooms(event: InputEventMouseButton, first_person: bool) -> bool:
	if event.ctrl_pressed:
		return true
	return not first_person and (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0


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
