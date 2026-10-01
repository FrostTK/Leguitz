class_name PauseMenu
extends Control
## Pause menu: resume, world time settings, language, zoom, graphics, quit.
## World settings are sent to the server (they belong to the world);
## user preferences go to the Settings autoload.

signal resume_requested
signal quit_requested
## `mode` is a WorldClock.Mode, `value` depends on the mode (see Msg.set_time).
signal time_settings_requested(mode: int, value: float)

const FROZEN_CHOICES := [
	["FROZEN_SUNRISE", WorldClock.FROZEN_SUNRISE],
	["FROZEN_NOON", WorldClock.FROZEN_NOON],
	["FROZEN_SUNSET", WorldClock.FROZEN_SUNSET],
	["FROZEN_MIDNIGHT", WorldClock.FROZEN_MIDNIGHT],
]
const LANGUAGE_CHOICES := [
	["LANGUAGE_AUTO", "auto"],
	["LANGUAGE_FR", "fr"],
	["LANGUAGE_EN", "en"],
]
const ZOOM_CHOICES := [0, 2, 3, 4, 5, 6, 8]
## The panel's width and the room kept around it (UI units): taller than
## the window, it scrolls.
const WIDTH := 230.0
const SCREEN_MARGIN := 8.0
const QUALITY_KEYS := ["QUALITY_LOW", "QUALITY_MEDIUM", "QUALITY_HIGH", "QUALITY_ULTRA"]

var clock: WorldClock

var _resume_button := Button.new()
var _time_mode := OptionButton.new()
var _day_length := OptionButton.new()
var _frozen_at := OptionButton.new()
var _day_length_row: Control
var _frozen_row: Control
var _pace_info := Label.new()
var _language := OptionButton.new()
var _zoom := OptionButton.new()
var _quality := OptionButton.new()
var _hd := CheckButton.new()
var _cave_first_person := CheckButton.new()
var _guide_book := CheckButton.new()
var _max_fps := OptionButton.new()
var _scroll := ScrollContainer.new()
var _box := VBoxContainer.new()
var _updating := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.08, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(_scroll)
	var box := _box
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(box)
	get_viewport().size_changed.connect(_fit_height)

	var title := Label.new()
	title.text = "MENU_PAUSE_TITLE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	box.add_child(title)

	_resume_button.text = "MENU_RESUME"
	_resume_button.pressed.connect(resume_requested.emit)
	box.add_child(_resume_button)

	box.add_child(_section("MENU_WORLD_SETTINGS"))
	for key in ["TIME_MODE_NORMAL", "TIME_MODE_SYNCED", "TIME_MODE_FROZEN"]:
		_time_mode.add_item(key)
	_time_mode.item_selected.connect(_on_time_changed.unbind(1))
	box.add_child(_row("SETTING_TIME_MODE", _time_mode))

	for minutes in WorldClock.DAY_MINUTES_PRESETS:
		_day_length.add_item("")
	_day_length.item_selected.connect(_on_time_changed.unbind(1))
	_day_length_row = _row("SETTING_DAY_LENGTH", _day_length)
	box.add_child(_day_length_row)

	for choice in FROZEN_CHOICES:
		_frozen_at.add_item(choice[0])
	_frozen_at.item_selected.connect(_on_time_changed.unbind(1))
	_frozen_row = _row("SETTING_FROZEN_AT", _frozen_at)
	box.add_child(_frozen_row)

	_pace_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pace_info.add_theme_font_size_override("font_size", 6)
	box.add_child(_pace_info)

	box.add_child(_section("MENU_GAME_SETTINGS"))
	for choice in LANGUAGE_CHOICES:
		_language.add_item(choice[0])
	_language.item_selected.connect(_on_language_selected)
	box.add_child(_row("SETTING_LANGUAGE", _language))

	for zoom in ZOOM_CHOICES:
		_zoom.add_item("")
	_zoom.item_selected.connect(_on_zoom_selected)
	box.add_child(_row("SETTING_ZOOM", _zoom))

	for key in QUALITY_KEYS:
		_quality.add_item(key)
	_quality.item_selected.connect(_on_quality_selected)
	box.add_child(_row("SETTING_QUALITY", _quality))

	_hd.toggled.connect(_on_hd_toggled)
	box.add_child(_row("SETTING_HD", _hd))

	for fps in Settings.FPS_CHOICES:
		_max_fps.add_item("")
	_max_fps.item_selected.connect(_on_max_fps_selected)
	box.add_child(_row("SETTING_MAX_FPS", _max_fps))

	_cave_first_person.toggled.connect(_on_cave_first_person_toggled)
	box.add_child(_row("SETTING_CAVE_FIRST_PERSON", _cave_first_person))

	_guide_book.toggled.connect(_on_guide_book_toggled)
	box.add_child(_row("SETTING_GUIDE_BOOK", _guide_book))

	var quit := Button.new()
	quit.text = "MENU_QUIT"
	quit.pressed.connect(quit_requested.emit)
	box.add_child(quit)

	_refresh_dynamic_texts()


func open() -> void:
	visible = true
	refresh_from_state()
	_resume_button.grab_focus()


## As tall as its content, within the window (the rest scrolls).
func _fit_height() -> void:
	var panel_margins := 16.0
	var room := get_viewport_rect().size.y - SCREEN_MARGIN * 2.0 - panel_margins
	var content := _box.get_combined_minimum_size().y
	_scroll.custom_minimum_size = Vector2(WIDTH - panel_margins, minf(content, room))


func close() -> void:
	visible = false


## Re-reads the clock and settings (the server may have changed the time).
func refresh_from_state() -> void:
	if clock == null:
		return
	_updating = true
	_time_mode.select(clock.mode)
	_day_length.select(_closest_preset(clock.day_minutes))
	_frozen_at.select(_closest_frozen_choice(clock.time_of_day()))
	var language_index := (
		LANGUAGE_CHOICES.map(func(c: Array) -> String: return c[1]).find(Settings.language)
	)
	_language.select(maxi(0, language_index))
	_zoom.select(maxi(0, ZOOM_CHOICES.find(Settings.world_zoom)))
	_quality.select(Settings.graphics_quality)
	_hd.button_pressed = Settings.hd_rendering
	_cave_first_person.button_pressed = Settings.cave_first_person
	_guide_book.button_pressed = Settings.guide_book
	_max_fps.select(maxi(0, Settings.FPS_CHOICES.find(Settings.max_fps)))
	_updating = false
	_refresh_dynamic_texts()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(InputBindings.PAUSE):
		resume_requested.emit()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_dynamic_texts()


func _on_time_changed() -> void:
	if _updating:
		return
	var mode := _time_mode.selected
	var value := 0.0
	match mode:
		WorldClock.Mode.NORMAL:
			value = WorldClock.DAY_MINUTES_PRESETS[_day_length.selected]
		WorldClock.Mode.FROZEN:
			value = FROZEN_CHOICES[_frozen_at.selected][1]
	time_settings_requested.emit(mode, value)
	_refresh_dynamic_texts()


func _on_language_selected(index: int) -> void:
	if not _updating:
		Settings.set_language(LANGUAGE_CHOICES[index][1])


func _on_zoom_selected(index: int) -> void:
	if not _updating:
		Settings.set_world_zoom(ZOOM_CHOICES[index])


func _on_quality_selected(index: int) -> void:
	if not _updating:
		Settings.set_graphics_quality(index)


func _on_max_fps_selected(index: int) -> void:
	if not _updating:
		Settings.set_max_fps(Settings.FPS_CHOICES[index])


func _on_hd_toggled(enabled: bool) -> void:
	if not _updating:
		Settings.set_hd_rendering(enabled)


func _on_cave_first_person_toggled(enabled: bool) -> void:
	if not _updating:
		Settings.set_cave_first_person(enabled)


func _on_guide_book_toggled(enabled: bool) -> void:
	if not _updating:
		Settings.set_guide_book(enabled)


func _refresh_dynamic_texts() -> void:
	for i in WorldClock.DAY_MINUTES_PRESETS.size():
		_day_length.set_item_text(i, tr("DAY_LENGTH_VALUE") % WorldClock.DAY_MINUTES_PRESETS[i])
	for i in ZOOM_CHOICES.size():
		var zoom: int = ZOOM_CHOICES[i]
		_zoom.set_item_text(i, tr("ZOOM_AUTO") if zoom == 0 else "x%d" % zoom)
	for i in Settings.FPS_CHOICES.size():
		var fps: int = Settings.FPS_CHOICES[i]
		_max_fps.set_item_text(i, tr("FPS_SCREEN") if fps == 0 else str(fps))
	var mode := _time_mode.selected
	_day_length_row.visible = mode == WorldClock.Mode.NORMAL
	_frozen_row.visible = mode == WorldClock.Mode.FROZEN
	var minutes: float = WorldClock.DAY_MINUTES_PRESETS[maxi(0, _day_length.selected)]
	var pace := 1.0
	match mode:
		WorldClock.Mode.NORMAL:
			pace = WorldClock.pace_for_day_minutes(minutes)
		WorldClock.Mode.SYNCED:
			pace = WorldClock.pace_for_day_minutes(WorldClock.SYNCED_DAY_MINUTES)
	var info := tr("TIME_PACE_INFO") % ("%.2f" % pace)
	if mode == WorldClock.Mode.SYNCED:
		info = tr("TIME_SYNCED_INFO") + "\n" + info
	_pace_info.text = info
	_fit_height.call_deferred()


func _closest_preset(minutes: float) -> int:
	var best := 0
	for i in WorldClock.DAY_MINUTES_PRESETS.size():
		var diff := absf(WorldClock.DAY_MINUTES_PRESETS[i] - minutes)
		if diff < absf(WorldClock.DAY_MINUTES_PRESETS[best] - minutes):
			best = i
	return best


func _closest_frozen_choice(time_of_day: float) -> int:
	var best := 0
	var best_diff := INF
	for i in FROZEN_CHOICES.size():
		var diff := absf(float(FROZEN_CHOICES[i][1]) - time_of_day)
		diff = minf(diff, WorldClock.GAME_SECONDS_PER_DAY - diff)
		if diff < best_diff:
			best_diff = diff
			best = i
	return best


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
	control.custom_minimum_size.x = 110
	row.add_child(control)
	return row
