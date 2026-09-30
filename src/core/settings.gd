extends Node
## User preferences shared by every world (language, display...).
## Autoloaded as "Settings" and saved in user://settings.cfg.
## World-specific options (seed, game mode, time) live in the world instead.

signal changed(key: StringName)

const PATH := "user://settings.cfg"
const LANGUAGE_AUTO := "auto"
const SUPPORTED_LANGUAGES: Array[String] = ["fr", "en"]
const MAX_UI_SCALE := 8
const MAX_WORLD_ZOOM := 12

## "auto" follows the system language, otherwise one of SUPPORTED_LANGUAGES.
var language := LANGUAGE_AUTO
## 0 = automatic (derived from the window height).
var ui_scale := 0
## Screen pixels per art pixel; 0 = automatic.
var world_zoom := 0
var view_distance := GameConst.DEFAULT_VIEW_DISTANCE
var show_debug := false
## 0 low, 1 medium, 2 high, 3 ultra (see LightingController.Quality).
var graphics_quality := 2


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputBindings.register_defaults()
	load_settings()
	apply_language()
	get_tree().root.size_changed.connect(apply_ui_scale)
	apply_ui_scale()


## Scales every Control (and the 2D canvas) through the window's content
## scale factor. The world camera compensates to keep its own zoom.
func apply_ui_scale() -> void:
	var window := get_tree().root
	window.content_scale_factor = effective_ui_scale(window.size.y)


func resolved_language() -> String:
	if language in SUPPORTED_LANGUAGES:
		return language
	var system := OS.get_locale_language()
	return system if system in SUPPORTED_LANGUAGES else "en"


func set_language(code: String) -> void:
	language = code if code in SUPPORTED_LANGUAGES else LANGUAGE_AUTO
	apply_language()
	save_settings()
	changed.emit(&"language")


func apply_language() -> void:
	TranslationServer.set_locale(resolved_language())


func set_world_zoom(value: int) -> void:
	world_zoom = clampi(value, 0, MAX_WORLD_ZOOM)
	save_settings()
	changed.emit(&"world_zoom")


func set_graphics_quality(value: int) -> void:
	graphics_quality = clampi(value, 0, 3)
	save_settings()
	changed.emit(&"graphics_quality")


func set_show_debug(value: bool) -> void:
	show_debug = value
	save_settings()
	changed.emit(&"show_debug")


## UI scale actually applied for a given window height.
func effective_ui_scale(window_height: int) -> int:
	if ui_scale > 0:
		return ui_scale
	return clampi(roundi(window_height / 360.0), 1, MAX_UI_SCALE)


## World zoom actually applied for a given window height: about 17 tiles
## of height visible by default, like Stardew Valley.
func effective_world_zoom(window_height: int) -> int:
	if world_zoom > 0:
		return world_zoom
	return clampi(roundi(window_height / 270.0), 1, MAX_WORLD_ZOOM)


func load_settings() -> void:
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		return
	language = file.get_value("general", "language", language)
	ui_scale = file.get_value("display", "ui_scale", ui_scale)
	world_zoom = file.get_value("display", "world_zoom", world_zoom)
	view_distance = file.get_value("display", "view_distance", view_distance)
	graphics_quality = file.get_value("display", "graphics_quality", graphics_quality)
	show_debug = file.get_value("debug", "show_debug", show_debug)


func save_settings() -> void:
	var file := ConfigFile.new()
	file.set_value("general", "language", language)
	file.set_value("display", "ui_scale", ui_scale)
	file.set_value("display", "world_zoom", world_zoom)
	file.set_value("display", "view_distance", view_distance)
	file.set_value("display", "graphics_quality", graphics_quality)
	file.set_value("debug", "show_debug", show_debug)
	var error := file.save(PATH)
	if error != OK:
		push_warning("Settings: could not save %s (%s)" % [PATH, error_string(error)])
