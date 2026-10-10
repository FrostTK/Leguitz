class_name PauseMenu
extends Control
## Pause menu: resume, the world's game mode and time settings, the
## player's own settings (SettingsPanel: display, graphics, game), quit.
## World settings are sent to the server (they belong to the world);
## user preferences go to the Settings autoload.

signal resume_requested
signal quit_requested
## `mode` is a WorldClock.Mode, `value` depends on the mode (see Msg.set_time).
signal time_settings_requested(mode: int, value: float)
## Another game mode for the world (survival and creative swap; a hardcore
## world stays hardcore).
signal game_mode_requested(mode: int)
## The world's seasons: `days` each (0: none).
signal seasons_requested(days: int)

const FROZEN_CHOICES := [
	["FROZEN_SUNRISE", WorldClock.FROZEN_SUNRISE],
	["FROZEN_NOON", WorldClock.FROZEN_NOON],
	["FROZEN_SUNSET", WorldClock.FROZEN_SUNSET],
	["FROZEN_MIDNIGHT", WorldClock.FROZEN_MIDNIGHT],
]
## The panel's width and the room kept around it (UI units): taller than
## the window, it scrolls.
const WIDTH := 230.0
const SCREEN_MARGIN := 8.0

var clock: WorldClock
## The world's game mode (WorldSettings.GameMode, set by GameModeView).
var game_mode := WorldSettings.GameMode.SURVIVAL

var _resume_button := Button.new()
var _game_mode := OptionButton.new()
var _time_mode := OptionButton.new()
var _day_length := OptionButton.new()
var _frozen_at := OptionButton.new()
var _seasons := OptionButton.new()
var _day_length_row: Control
var _frozen_row: Control
var _pace_info := Label.new()
var _settings := SettingsPanel.new()
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
	for mode in WorldSettings.GameMode.size():
		_game_mode.add_item(WorldSettings.GAME_MODE_KEYS[mode])
	_game_mode.item_selected.connect(_on_game_mode_selected)
	box.add_child(_row("SETTING_GAME_MODE", _game_mode))

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

	for days in WorldClock.SEASON_DAYS_PRESETS:
		_seasons.add_item("")
	_seasons.item_selected.connect(_on_seasons_selected)
	box.add_child(_row("SETTING_SEASONS", _seasons))

	_pace_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pace_info.add_theme_font_size_override("font_size", 6)
	box.add_child(_pace_info)

	_settings.layout_changed.connect(_fit_height.call_deferred)
	box.add_child(_settings)

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
	_game_mode.select(game_mode)
	var hardcore := game_mode == WorldSettings.GameMode.HARDCORE
	_game_mode.disabled = hardcore
	_game_mode.set_item_disabled(WorldSettings.GameMode.HARDCORE, not hardcore)
	_time_mode.select(clock.mode)
	_day_length.select(_closest_preset(clock.day_minutes))
	_frozen_at.select(_closest_frozen_choice(clock.time_of_day()))
	_seasons.select(_closest_seasons(clock.season_days))
	_settings.refresh()
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


func _on_game_mode_selected(index: int) -> void:
	if not _updating:
		game_mode_requested.emit(index)


func _on_seasons_selected(index: int) -> void:
	if not _updating:
		seasons_requested.emit(WorldClock.SEASON_DAYS_PRESETS[index])


func _refresh_dynamic_texts() -> void:
	for i in WorldClock.DAY_MINUTES_PRESETS.size():
		_day_length.set_item_text(i, tr("DAY_LENGTH_VALUE") % WorldClock.DAY_MINUTES_PRESETS[i])
	for i in WorldClock.SEASON_DAYS_PRESETS.size():
		var days := WorldClock.SEASON_DAYS_PRESETS[i]
		_seasons.set_item_text(i, tr("SEASONS_DAYS") % days if days > 0 else tr("SEASONS_OFF"))
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
		if _seasons.selected > 0:
			info += "\n" + tr("SEASONS_SYNCED_INFO")
	_pace_info.text = info
	_fit_height.call_deferred()


func _closest_preset(minutes: float) -> int:
	var best := 0
	for i in WorldClock.DAY_MINUTES_PRESETS.size():
		var diff := absf(WorldClock.DAY_MINUTES_PRESETS[i] - minutes)
		if diff < absf(WorldClock.DAY_MINUTES_PRESETS[best] - minutes):
			best = i
	return best


func _closest_seasons(days: int) -> int:
	var best := 0
	for i in WorldClock.SEASON_DAYS_PRESETS.size():
		if (
			absi(WorldClock.SEASON_DAYS_PRESETS[i] - days)
			< absi(WorldClock.SEASON_DAYS_PRESETS[best] - days)
		):
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
