extends TestCase
## User preferences (the autoload's script, without touching the file).

const SETTINGS_SCRIPT := preload("res://src/core/settings.gd")


func test_session_overrides_are_not_saved() -> void:
	var settings: Node = SETTINGS_SCRIPT.new()
	settings.world_zoom = 3
	settings.override(&"world_zoom", 1)
	settings.override(&"world_zoom", 2)
	assert_eq(settings.world_zoom, 2, "the override applies")
	assert_eq(settings._saved(&"world_zoom"), 3, "the file keeps the user's own value")
	assert_eq(settings._saved(&"max_fps"), settings.max_fps, "other settings save as they are")
	settings.free()


func test_display_choices() -> void:
	var sizes := DisplayModes.sizes_fitting(Vector2i(1920, 1080))
	assert_true(sizes.has(Vector2i(1920, 1080)), "the screen's own size")
	assert_false(sizes.has(Vector2i(2560, 1440)), "nothing larger than the screen")
	assert_eq(DisplayModes.sizes_fitting(Vector2i(800, 600)), [Vector2i(1280, 720)], "at least one")
	assert_eq(DisplayModes.fps_cap(100, 144.0), 100)
	assert_eq(DisplayModes.fps_cap(0, 144.0), 144, "the screen's rate")
	assert_eq(DisplayModes.fps_cap(0, -1.0), 60, "a screen of unknown rate")
	assert_eq(DisplayModes.fps_cap(-1, 144.0), 0, "no limit")
	assert_true(Settings.FPS_CHOICES.has(100), "100 frames per second offered")
	# Every display setting is a setting (saved by its name).
	var settings: Node = SETTINGS_SCRIPT.new()
	for key: StringName in settings.DISPLAY_KEYS:
		assert_true(settings.get(key) != null, "%s exists" % key)
	settings.free()
	# The menu picks the nearest choice of a saved value.
	assert_eq(SettingsPanel._closest(SettingsPanel.BRIGHTNESS_CHOICES, 1.12), 3)
	assert_eq(SettingsPanel._closest(SettingsPanel.LANGUAGE_CHOICES, "fr"), 1)
