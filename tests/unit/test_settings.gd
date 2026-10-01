extends TestCase
## User preferences (the autoload's script, without touching the file).


func test_session_overrides_are_not_saved() -> void:
	var settings: Node = load("res://src/core/settings.gd").new()
	settings.world_zoom = 3
	settings.override(&"world_zoom", 1)
	settings.override(&"world_zoom", 2)
	assert_eq(settings.world_zoom, 2, "the override applies")
	assert_eq(settings._saved(&"world_zoom"), 3, "the file keeps the user's own value")
	assert_eq(settings._saved(&"max_fps"), settings.max_fps, "other settings save as they are")
	settings.free()
