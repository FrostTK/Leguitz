class_name SettingsPanel
extends VBoxContainer
## The player's own settings in the pause menu (the Settings autoload; each
## choice is applied and saved at once): display (window mode, screen,
## window size, vertical sync, frame limit, frame counter), graphics
## (quality, HD, zoom, how far one sees in first person, brightness) and
## game (language, interface size, first person's field of view and mouse
## speed, first person in caves, the player's book).

## Its rows were shown or hidden (the menu fits its height again).
signal layout_changed

const LANGUAGE_CHOICES := ["auto", "fr", "en"]
const LANGUAGE_KEYS := ["LANGUAGE_AUTO", "LANGUAGE_FR", "LANGUAGE_EN"]
const WINDOW_KEYS := ["WINDOW_WINDOWED", "WINDOW_FULLSCREEN", "WINDOW_EXCLUSIVE"]
const VSYNC_KEYS := ["VSYNC_OFF", "VSYNC_ON", "VSYNC_ADAPTIVE"]
const QUALITY_KEYS := ["QUALITY_LOW", "QUALITY_MEDIUM", "QUALITY_HIGH", "QUALITY_ULTRA"]
const ZOOM_CHOICES := [0, 2, 3, 4, 5, 6, 8]
const FAR_VIEW_CHOICES := [4, 6, 8, 10, 12]
const BRIGHTNESS_CHOICES := [0.8, 0.9, 1.0, 1.15, 1.3, 1.5]
const UI_SCALE_CHOICES := [0, 1, 2, 3, 4, 5, 6]
const FOV_CHOICES := [60.0, 70.0, 80.0, 90.0, 100.0, 110.0]
const SENSITIVITY_CHOICES := [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0]
## Width of the controls (UI units).
const CONTROL_WIDTH := 110

## Setting -> [its OptionButton, its choices, the text of a choice].
var _options := {}
## Setting -> its CheckButton.
var _toggles := {}
var _screen := OptionButton.new()
var _screen_row: Control
var _resolution := OptionButton.new()
## The window sizes listed (the first: as the window is).
var _sizes: Array[Vector2i] = []
var _updating := false


func _ready() -> void:
	add_child(_section("MENU_DISPLAY_SETTINGS"))
	_add_option(&"window_mode", [0, 1, 2], _keyed.bind(WINDOW_KEYS), "SETTING_WINDOW_MODE")
	_screen.item_selected.connect(_on_screen_selected)
	_screen_row = _row("SETTING_SCREEN", _screen)
	add_child(_screen_row)
	_resolution.item_selected.connect(_on_resolution_selected)
	add_child(_row("SETTING_RESOLUTION", _resolution))
	_add_option(&"vsync", [0, 1, 2], _keyed.bind(VSYNC_KEYS), "SETTING_VSYNC")
	_add_option(&"max_fps", Settings.FPS_CHOICES, _fps_text, "SETTING_MAX_FPS")
	_add_toggle(&"show_fps", "SETTING_SHOW_FPS")

	add_child(_section("MENU_GRAPHICS_SETTINGS"))
	_add_option(&"graphics_quality", [0, 1, 2, 3], _keyed.bind(QUALITY_KEYS), "SETTING_QUALITY")
	_add_toggle(&"hd_rendering", "SETTING_HD")
	_add_option(&"world_zoom", ZOOM_CHOICES, _zoom_text, "SETTING_ZOOM")
	_add_option(&"far_view", FAR_VIEW_CHOICES, _chunks_text, "SETTING_FAR_VIEW")
	_add_option(&"brightness", BRIGHTNESS_CHOICES, _percent_text, "SETTING_BRIGHTNESS")

	add_child(_section("MENU_GAME_SETTINGS"))
	_add_option(
		&"language",
		LANGUAGE_CHOICES,
		_keyed_choice.bind(LANGUAGE_CHOICES, LANGUAGE_KEYS),
		"SETTING_LANGUAGE"
	)
	_add_option(&"ui_scale", UI_SCALE_CHOICES, _zoom_text, "SETTING_UI_SCALE")
	_add_option(&"first_person_fov", FOV_CHOICES, _degrees_text, "SETTING_FOV")
	_add_option(&"mouse_sensitivity", SENSITIVITY_CHOICES, _times_text, "SETTING_MOUSE")
	_add_toggle(&"cave_first_person", "SETTING_CAVE_FIRST_PERSON")
	_add_toggle(&"guide_book", "SETTING_GUIDE_BOOK")
	refresh()


## Shows the settings as they are (and the screens and window sizes now).
func refresh() -> void:
	_updating = true
	for key: StringName in _options:
		var option: OptionButton = _options[key][0]
		option.select(_closest(_options[key][1], Settings.get(key)))
	for key: StringName in _toggles:
		_toggles[key].button_pressed = Settings.get(key)
	_fill_screens()
	_fill_resolutions()
	_updating = false
	texts()


## The texts that depend on the language or the screen.
func texts() -> void:
	for key: StringName in _options:
		var option: OptionButton = _options[key][0]
		var choices: Array = _options[key][1]
		var text_of: Callable = _options[key][2]
		for i in choices.size():
			option.set_item_text(i, text_of.call(choices[i]))


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		texts()
		_fill_screens()
		_fill_resolutions()


func _add_option(key: StringName, choices: Array, text_of: Callable, label: String) -> void:
	var option := OptionButton.new()
	for choice: Variant in choices:
		option.add_item("")
	option.item_selected.connect(_on_option_selected.bind(key))
	_options[key] = [option, choices, text_of]
	add_child(_row(label, option))


func _add_toggle(key: StringName, label: String) -> void:
	var toggle := CheckButton.new()
	toggle.toggled.connect(_on_toggled.bind(key))
	_toggles[key] = toggle
	add_child(_row(label, toggle))


func _on_option_selected(index: int, key: StringName) -> void:
	if _updating:
		return
	Settings.choose(key, _options[key][1][index])
	if key == &"window_mode" or key == &"max_fps":
		# The window changed: its sizes, the screen's rate in the texts.
		refresh.call_deferred()


func _on_toggled(enabled: bool, key: StringName) -> void:
	if not _updating:
		Settings.choose(key, enabled)


func _on_screen_selected(index: int) -> void:
	if not _updating:
		Settings.choose(&"screen", index)
		refresh.call_deferred()


func _on_resolution_selected(index: int) -> void:
	if not _updating and index < _sizes.size():
		Settings.choose(&"resolution", _sizes[index])


## The screens, when there are several.
func _fill_screens() -> void:
	var count := DisplayModes.screen_count()
	_screen_row.visible = count > 1
	_screen.clear()
	for i in count:
		var size := DisplayModes.screen_size(i)
		var hz := roundi(DisplayModes.refresh_rate(i))
		_screen.add_item(tr("SCREEN_ITEM") % [i + 1, size.x, size.y, hz])
	_screen.select(DisplayModes.screen_of(Settings.screen))
	layout_changed.emit()


## The window sizes fitting the screen; in fullscreen only the screen's.
func _fill_resolutions() -> void:
	_resolution.clear()
	var screen_size := DisplayModes.screen_size(Settings.screen)
	if Settings.window_mode != DisplayModes.Mode.WINDOWED:
		_sizes = [Vector2i.ZERO]
		_resolution.add_item(tr("RESOLUTION_SCREEN") % [screen_size.x, screen_size.y])
		_resolution.disabled = true
		_resolution.select(0)
		return
	_resolution.disabled = false
	var window := get_window().size
	_sizes = [Vector2i.ZERO]
	_sizes.append_array(DisplayModes.sizes_fitting(screen_size))
	_resolution.add_item(tr("RESOLUTION_FREE") % [window.x, window.y])
	for i in range(1, _sizes.size()):
		_resolution.add_item("%d × %d" % [_sizes[i].x, _sizes[i].y])
	_resolution.select(maxi(0, _sizes.find(Settings.resolution)))


## The index of the choice nearest a value.
static func _closest(choices: Array, value: Variant) -> int:
	var best := 0
	for i in choices.size():
		if typeof(value) == TYPE_STRING:
			if choices[i] == value:
				return i
		elif absf(float(choices[i]) - float(value)) < absf(float(choices[best]) - float(value)):
			best = i
	return best


func _keyed(choice: int, keys: Array) -> String:
	return tr(keys[choice])


func _keyed_choice(choice: String, choices: Array, keys: Array) -> String:
	return tr(keys[choices.find(choice)])


func _fps_text(fps: int) -> String:
	if fps == 0:
		return tr("FPS_SCREEN") % roundi(DisplayModes.refresh_rate(Settings.screen))
	return tr("FPS_UNLIMITED") if fps < 0 else str(fps)


func _zoom_text(zoom: int) -> String:
	return tr("ZOOM_AUTO") if zoom == 0 else "x%d" % zoom


func _chunks_text(chunks: int) -> String:
	return tr("CHUNKS_COUNT") % chunks


func _percent_text(value: float) -> String:
	return "%d %%" % roundi(value * 100.0)


func _degrees_text(value: float) -> String:
	return "%d°" % roundi(value)


func _times_text(value: float) -> String:
	return "x%s" % str(snappedf(value, 0.01))


func _section(key: String) -> Label:
	var label := Label.new()
	label.text = key
	label.add_theme_color_override("font_color", UiTheme.WOOD)
	return label


func _row(label_key: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_key
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	control.custom_minimum_size.x = CONTROL_WIDTH
	row.add_child(control)
	return row
