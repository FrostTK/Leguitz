extends TestCase
## Top-down view and first person: switching (ViewMode) and the dive.


func test_caves_switch_to_first_person_and_back() -> void:
	var mode := ViewMode.new()
	mode.update(false, false)
	assert_false(mode.first_person, "top-down in the open")
	mode.update(true, false)
	assert_false(mode.first_person, "a roof is not a cave")
	mode.update(true, true)
	assert_true(mode.first_person, "first person in a cave")
	mode.update(true, false)
	assert_true(mode.first_person, "a thinner ceiling keeps it (no flicker)")
	mode.update(false, false)
	assert_false(mode.first_person, "the open sky brings the top-down view back")


func test_f5_switches_until_the_next_cave_change() -> void:
	var mode := ViewMode.new()
	mode.toggle()
	assert_true(mode.first_person, "first person anywhere with F5")
	mode.update(false, false)
	assert_true(mode.first_person, "the open sky does not undo it")
	mode.update(true, true)
	mode.toggle()
	assert_false(mode.first_person, "back to top-down in the cave by hand")
	mode.update(true, true)
	assert_false(mode.first_person, "still in the same cave: the choice holds")
	mode.update(false, false)
	mode.update(true, true)
	assert_true(mode.first_person, "the next cave goes first person again")


func test_the_setting_turns_automatic_switching_off() -> void:
	var mode := ViewMode.new()
	mode.set_automatic(false)
	mode.update(true, true)
	assert_false(mode.first_person, "no first person in caves when off")
	mode.set_automatic(true)
	assert_true(mode.first_person, "turned back on inside a cave")
	mode.set_automatic(false)
	assert_false(mode.first_person)
	mode.toggle()
	assert_true(mode.first_person, "F5 still works")


func test_no_stretch_in_first_person() -> void:
	var pitch := deg_to_rad(Render3D.DEFAULT_PITCH)
	var plain := Render3D.root_basis(0.7, pitch, 0.0)
	assert_true(plain.is_equal_approx(Basis.IDENTITY), "true proportions")
	assert_true(
		Render3D.root_basis(0.7, pitch, 1.0).is_equal_approx(Render3D.root_basis(0.7, pitch))
	)


func test_the_dive_ends_at_the_eye() -> void:
	var top := Basis.from_euler(Vector3(deg_to_rad(-60.0), 0.4, 0.0))
	var look := Basis.from_euler(Vector3(-0.2, 0.4, 0.0))
	var target := Vector3(10.0, 2.0, -4.0)
	var eye := Vector3(10.0, 3.0, -4.0)
	var end := WorldViewport.dive_frame(1.0, top, target, 22.5, look, eye, 60.0, 250.0)
	var at: Transform3D = end[0]
	assert_true(at.origin.is_equal_approx(eye), "at the eye")
	assert_true(at.basis.is_equal_approx(look), "looking where the player looks")
	assert_almost(end[1], WorldViewport.FIRST_PERSON_FOV)
	assert_almost(end[2], WorldViewport.FIRST_PERSON_NEAR)
	# Just started: nearly orthographic, far away, centered on the target.
	var start := WorldViewport.dive_frame(0.001, top, target, 22.5, look, eye, 60.0, 250.0)
	var from: Transform3D = start[0]
	assert_true(start[1] < 1.1, "a narrow field of view")
	var to_target := target - from.origin
	assert_true(to_target.length() > 1000.0, "far away")
	assert_true(to_target.normalized().dot(-from.basis.z) > 0.9999, "the target in the middle")
	assert_true(start[2] < to_target.length() - 50.0, "terrain in front of the target stays")
	assert_true(start[3] > to_target.length() + 200.0, "and behind it")
