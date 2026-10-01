extends TestCase
## Input rules that do not need the input map.


func test_wheel_zooms_with_its_button_held_in_the_top_down_view() -> void:
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	assert_false(InputBindings.wheel_zooms(wheel, false), "the wheel alone picks the slot")
	wheel.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	assert_true(InputBindings.wheel_zooms(wheel, false), "with its button held, it zooms")
	assert_false(InputBindings.wheel_zooms(wheel, true), "but not in first person")
	wheel.button_mask = MOUSE_BUTTON_MASK_RIGHT
	assert_false(InputBindings.wheel_zooms(wheel, false), "other buttons do not count")
	wheel.button_mask = 0
	wheel.ctrl_pressed = true
	assert_true(InputBindings.wheel_zooms(wheel, false), "Ctrl + wheel zooms")
	assert_true(InputBindings.wheel_zooms(wheel, true), "in first person too")


func test_tab_opens_the_inventory_and_e_uses_what_is_aimed_at() -> void:
	InputBindings.register_defaults()
	var tab := InputEventKey.new()
	tab.physical_keycode = KEY_TAB
	assert_true(InputMap.event_is_action(tab, InputBindings.INVENTORY), "Tab: the inventory")
	var e := InputEventKey.new()
	e.physical_keycode = KEY_E
	assert_true(InputMap.event_is_action(e, InputBindings.USE), "E: use what is aimed at")
	assert_false(InputMap.event_is_action(e, InputBindings.INVENTORY))
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_B
	assert_true(InputMap.event_is_action(b, InputBindings.USE), "B on a gamepad")
	var used := GuideBook.chapters()[0].filter(
		func(entry: Dictionary) -> bool: return entry["text"] == tr("BOOK_USE")
	)
	assert_eq(used.size(), 1, "the book tells it")
