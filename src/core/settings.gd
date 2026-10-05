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
## Frame rate limits offered (0: the screen's rate, -1: none).
const FPS_CHOICES: Array[int] = [30, 60, 100, 120, 144, 165, 240, 0, -1]
## While the game window is in the background.
const BACKGROUND_FPS := 15
## The display settings saved with their own names (see choose).
const DISPLAY_KEYS: Array[StringName] = [
	&"window_mode",
	&"screen",
	&"resolution",
	&"vsync",
	&"show_fps",
	&"far_view",
	&"brightness",
	&"first_person_fov",
	&"mouse_sensitivity",
	&"extreme",
]
## Extreme graphics (see `extreme`): the quality, the first-person view
## and the props' detail reach they set.
const EXTREME_QUALITY := 3
const EXTREME_FAR_VIEW := 12
const EXTREME_DETAIL := 2.0

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
## Renders the 3D world at full screen resolution instead of one texel per
## art pixel: smoother lighting and shadows, same pixel-art textures.
var hd_rendering := false
## Frames per second at most (0: the screen's refresh rate, -1: no limit):
## no need to keep the graphics card at full power for a calm pixel-art
## world.
var max_fps := 60
## The window (DisplayModes): its mode, its screen (-1: where it is), its
## size when windowed (ZERO: as it opens or was resized), vertical sync.
var window_mode := DisplayModes.Mode.WINDOWED
var screen := -1
var resolution := Vector2i.ZERO
var vsync := DisplayModes.Sync.ON
## A small frame rate counter in a corner (the F3 screen tells more).
var show_fps := false
## Chunks loaded around the player in first person: how far one sees (the
## haze follows).
var far_view := 6
## The picture's brightness (1: as made; the caves' dark stays dark).
var brightness := 1.0
## First person: the field of view (degrees) and the mouse's speed.
var first_person_fov := 70.0
var mouse_sensitivity := 1.0
## Goes first person when entering a cave (V switches by hand anyway).
var cave_first_person := true
## The player's book in a 10th slot beside the hotbar (see BookScreen).
var guide_book := true
## Every graphics setting at its most (Ultra, HD, the farthest first-person
## view, props in full detail twice as far) and none of the savings
## (CreaturesView animates every creature every frame, every plant casts
## its shadow: PropLibrary.thrifty): the player's own choices are kept for
## when it is off (`effective_quality`, `effective_hd`,
## `effective_far_view`).
var extreme := false

## The user's own values of the settings overridden for this session only
## (developer options): those are saved instead.
var _saved_values := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputBindings.register_defaults()
	load_settings()
	apply_language()
	apply_display()
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
	_save_choice(&"language")
	changed.emit(&"language")


func apply_language() -> void:
	TranslationServer.set_locale(resolved_language())


func set_world_zoom(value: int) -> void:
	world_zoom = clampi(value, 0, MAX_WORLD_ZOOM)
	_save_choice(&"world_zoom")
	changed.emit(&"world_zoom")


## The graphics quality applied (see `extreme`).
func effective_quality() -> int:
	return EXTREME_QUALITY if extreme else graphics_quality


## Whether the world renders at full screen resolution (see `extreme`).
func effective_hd() -> bool:
	return extreme or hd_rendering


## Chunks seen in first person (see `extreme`).
func effective_far_view() -> int:
	return EXTREME_FAR_VIEW if extreme else far_view


func apply_max_fps() -> void:
	Engine.max_fps = DisplayModes.fps_cap(max_fps, DisplayModes.refresh_rate(screen))


## The window, the vertical sync and the frame limit (DisplayModes).
func apply_display() -> void:
	DisplayModes.apply(window_mode, screen, resolution, vsync, max_fps)


## Sets one of the settings chosen in the menu, applies it, saves it.
func choose(key: StringName, value: Variant) -> void:
	if key == &"language":
		set_language(value)
		return
	set(key, value)
	if key in [&"window_mode", &"screen", &"resolution", &"vsync", &"max_fps"]:
		apply_display()
	elif key == &"ui_scale":
		apply_ui_scale()
	_save_choice(key)
	changed.emit(key)


func _notification(what: int) -> void:
	# Slow down while the window is in the background.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		Engine.max_fps = BACKGROUND_FPS
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		apply_max_fps()


func set_show_debug(value: bool) -> void:
	show_debug = value
	_save_choice(&"show_debug")
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
	hd_rendering = file.get_value("display", "hd_rendering", hd_rendering)
	max_fps = file.get_value("display", "max_fps", max_fps)
	for key: StringName in DISPLAY_KEYS:
		set(key, file.get_value("display", key, get(key)))
	cave_first_person = file.get_value("display", "cave_first_person", cave_first_person)
	guide_book = file.get_value("display", "guide_book", guide_book)
	show_debug = file.get_value("debug", "show_debug", show_debug)


## Changes a setting for this session only: the settings file keeps the
## user's own value (developer command line options).
func override(key: StringName, value: Variant) -> void:
	if not _saved_values.has(key):
		_saved_values[key] = get(key)
	set(key, value)


func save_settings() -> void:
	var file := ConfigFile.new()
	file.set_value("general", "language", _saved(&"language"))
	file.set_value("display", "ui_scale", _saved(&"ui_scale"))
	file.set_value("display", "world_zoom", _saved(&"world_zoom"))
	file.set_value("display", "view_distance", _saved(&"view_distance"))
	file.set_value("display", "graphics_quality", _saved(&"graphics_quality"))
	file.set_value("display", "hd_rendering", _saved(&"hd_rendering"))
	file.set_value("display", "max_fps", _saved(&"max_fps"))
	for key: StringName in DISPLAY_KEYS:
		file.set_value("display", key, _saved(key))
	file.set_value("display", "cave_first_person", _saved(&"cave_first_person"))
	file.set_value("display", "guide_book", _saved(&"guide_book"))
	file.set_value("debug", "show_debug", _saved(&"show_debug"))
	var error := file.save(PATH)
	if error != OK:
		push_warning("Settings: could not save %s (%s)" % [PATH, error_string(error)])


## The value of a setting to write to the file.
func _saved(key: StringName) -> Variant:
	return _saved_values.get(key, get(key))


## Saves a setting the user just chose (it no longer is an override).
func _save_choice(key: StringName) -> void:
	_saved_values.erase(key)
	save_settings()
