class_name SettingsPanel
extends VBoxContainer
## The player's own settings in the pause menu (the Settings autoload; each
## choice is applied and saved at once), in tabs (chips, one page at a
## time; step 5 of the redesign): display (window mode, screen, window
## size, vertical sync, frame limit, frame counter), graphics (extreme,
## with its warning sign telling its pros and cons; quality, HD, zoom, how
## far one sees in first person, brightness: extreme sets the first ones,
## shown greyed out at their most), game (language, interface size, first
## person's field of view and mouse speed, first person in caves, the
## player's book) and the controls (GuideBook.controls: the keyboard and
## the mouse, then a gamepad; each control's keys on caps).

## Its rows were shown or hidden (the menu fits its height again).
signal layout_changed

enum Tab { DISPLAY, GRAPHICS, GAME, CONTROLS }

const TAB_KEYS := {
	Tab.DISPLAY: "MENU_DISPLAY_SETTINGS",
	Tab.GRAPHICS: "MENU_GRAPHICS_SETTINGS",
	Tab.GAME: "MENU_GAME_SETTINGS",
	Tab.CONTROLS: "MENU_CONTROLS",
}

const LANGUAGE_CHOICES := ["auto", "fr", "en"]
const LANGUAGE_KEYS := ["LANGUAGE_AUTO", "LANGUAGE_FR", "LANGUAGE_EN"]
const WINDOW_KEYS := ["WINDOW_WINDOWED", "WINDOW_FULLSCREEN", "WINDOW_EXCLUSIVE"]
const VSYNC_KEYS := ["VSYNC_OFF", "VSYNC_ON", "VSYNC_ADAPTIVE"]
const QUALITY_KEYS := ["QUALITY_LOW", "QUALITY_MEDIUM", "QUALITY_HIGH", "QUALITY_ULTRA"]
const ZOOM_CHOICES := [0, 1, 2, 3, 4, 5, 6, 8]
## The settings extreme graphics take over (shown at their most, greyed).
const EXTREME_KEYS: Array[StringName] = [&"graphics_quality", &"hd_rendering", &"far_view"]
const EXTREME_TIP: Array[String] = [
	"SETTING_EXTREME_ABOUT", "SETTING_EXTREME_PRO", "SETTING_EXTREME_CON", "SETTING_EXTREME_BACK"
]
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
## The tabs, their pages, the page rows are added to (while making them).
var _tabs := ChipBar.new()
var _tab_pages := {}
var _target: VBoxContainer


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	add_child(UiTheme.label("MENU_SETTINGS", "TitleLabel"))
	add_child(_tabs)
	for each: int in TAB_KEYS:
		_tabs.add_chip(each, TAB_KEYS[each])
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", 4)
		add_child(page)
		_tab_pages[each] = page
	_tabs.chosen.connect(show_tab)
	_target = _tab_pages[Tab.DISPLAY]
	_add_option(&"window_mode", [0, 1, 2], _keyed.bind(WINDOW_KEYS), "SETTING_WINDOW_MODE")
	_screen.item_selected.connect(_on_screen_selected)
	_screen_row = _row("SETTING_SCREEN", _screen)
	_target.add_child(_screen_row)
	_resolution.item_selected.connect(_on_resolution_selected)
	_target.add_child(_row("SETTING_RESOLUTION", _resolution))
	_add_option(&"vsync", [0, 1, 2], _keyed.bind(VSYNC_KEYS), "SETTING_VSYNC")
	_add_option(&"max_fps", Settings.FPS_CHOICES, _fps_text, "SETTING_MAX_FPS")
	_add_toggle(&"show_fps", "SETTING_SHOW_FPS")

	_target = _tab_pages[Tab.GRAPHICS]
	_add_toggle(&"extreme", "SETTING_EXTREME")
	var row: Control = _toggles[&"extreme"].get_parent()
	var warning := WarningSign.new("SETTING_EXTREME", EXTREME_TIP)
	row.add_child(warning)
	row.move_child(warning, 1)
	_add_option(&"graphics_quality", [0, 1, 2, 3], _keyed.bind(QUALITY_KEYS), "SETTING_QUALITY")
	_add_toggle(&"hd_rendering", "SETTING_HD")
	_add_option(&"world_zoom", ZOOM_CHOICES, _zoom_text, "SETTING_ZOOM")
	_add_option(&"far_view", FAR_VIEW_CHOICES, _chunks_text, "SETTING_FAR_VIEW")
	_add_option(&"brightness", BRIGHTNESS_CHOICES, _percent_text, "SETTING_BRIGHTNESS")

	_target = _tab_pages[Tab.GAME]
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
	show_tab(Tab.DISPLAY)
	refresh()


## Shows a tab's page.
func show_tab(which: int) -> void:
	_tabs.select(which)
	for each: int in _tab_pages:
		(_tab_pages[each] as Control).visible = each == which
	layout_changed.emit()


## Shows the settings as they are (and the screens and window sizes now).
func refresh() -> void:
	_updating = true
	for key: StringName in _options:
		var option: OptionButton = _options[key][0]
		option.select(_closest(_options[key][1], _shown(key)))
		option.disabled = Settings.extreme and key in EXTREME_KEYS
	for key: StringName in _toggles:
		_toggles[key].button_pressed = _shown(key)
		_toggles[key].disabled = Settings.extreme and key in EXTREME_KEYS
	_fill_screens()
	_fill_resolutions()
	_updating = false
	texts()


## The texts that depend on the language or the screen (the controls'
## page too: its words and keys).
func texts() -> void:
	_fill_controls()
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
	_target.add_child(_row(label, option))


func _add_toggle(key: StringName, label: String) -> void:
	var toggle := CheckButton.new()
	toggle.toggled.connect(_on_toggled.bind(key))
	_toggles[key] = toggle
	_target.add_child(_row(label, toggle))


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
		if key == &"extreme":
			refresh.call_deferred()


## A setting as it applies (extreme graphics take some over).
func _shown(key: StringName) -> Variant:
	match key:
		&"graphics_quality":
			return Settings.effective_quality()
		&"hd_rendering":
			return Settings.effective_hd()
		&"far_view":
			return Settings.effective_far_view()
	return Settings.get(key)


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


## The controls' page: a title for the keyboard and the mouse, then the
## gamepad; a row per control, its keys on caps or how it is done.
func _fill_controls() -> void:
	var page: VBoxContainer = _tab_pages[Tab.CONTROLS]
	for child in page.get_children():
		child.queue_free()
	for entry: Dictionary in GuideBook.controls():
		match entry["kind"]:
			GuideBook.Kind.TITLE:
				page.add_child(_section(entry["text"]))
			GuideBook.Kind.KEYS:
				var caps := HBoxContainer.new()
				caps.add_theme_constant_override("separation", 2)
				for key: String in entry["keys"]:
					caps.add_child(_cap(key))
				page.add_child(_row(entry["text"], caps, false))
			GuideBook.Kind.COMBO:
				var how := UiTheme.label(entry["how"], "HintLabel")
				how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				how.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				how.custom_minimum_size.x = CONTROL_WIDTH
				page.add_child(_row(entry["text"], how))


## A key's name on a cap.
static func _cap(key: String) -> Control:
	var cap := PanelContainer.new()
	var look := UiTheme.box(UiTheme.SLOT, UiTheme.LINE_STRONG, 2, 0.0)
	look.content_margin_left = 3.0
	look.content_margin_right = 3.0
	look.border_width_bottom = 2
	cap.add_theme_stylebox_override("panel", look)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var name := Label.new()
	name.text = key
	name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name.add_theme_font_size_override("font_size", UiTheme.SMALL_FONT_SIZE)
	cap.add_child(name)
	return cap


func _section(key: String) -> Label:
	var label := UiTheme.label(key, "SectionLabel")
	label.uppercase = true
	return label


## A setting's row: its name, then its control (CONTROL_WIDTH wide unless
## not `sized`).
func _row(label_key: String, control: Control, sized := true) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_key
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 60.0
	row.add_child(label)
	if sized:
		control.custom_minimum_size.x = CONTROL_WIDTH
	row.add_child(control)
	return row
