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
