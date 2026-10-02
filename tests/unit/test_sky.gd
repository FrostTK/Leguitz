extends TestCase
## Where the sun and the moon show in the sky (LightingController): on
## their true arc, at the horizon when they rise and set, under it after.


func _body(hours: float, moon := false) -> Vector3:
	var angle := LightingController.sun_angle(hours)
	return LightingController.sky_body_direction(angle - PI if moon else angle)


func test_the_sun_and_the_moon_cross_the_sky() -> void:
	var noon := _body(12.75)
	assert_true(noon.y > 0.8, "high at noon: %s" % noon)
	assert_true(noon.z > 0.0, "in the south (towards the camera)")
	var rise := _body(LightingController.SUNRISE)
	assert_almost(rise.y, 0.0, 0.01, "on the horizon at sunrise")
	assert_true(rise.x > 0.9, "in the east")
	assert_true(_body(LightingController.SUNSET).x < -0.9, "sets in the west")
	assert_true(_body(0.0).y < -0.5, "under the horizon at night")
	assert_true(_body(0.0, true).y > 0.5, "the moon up at midnight")
	assert_true(_body(12.0, true).y < 0.0, "and down at noon")
	for hours in 24:
		assert_almost(_body(hours).length(), 1.0, 0.0001)
	# The light stays a little higher than the disk (shadows readable).
	var light := LightingController.sky_direction(LightingController.sun_angle(6.5))
	assert_true(light.y > _body(6.5).y)
