class_name HudClock
extends PanelContainer
## Small always-visible clock in a little panel at the top right: a sun by
## day or a moon by night, the day (with seasons: the season and its day,
## the year after the first) in grey, the time of day, and whether time is
## frozen or follows the device.

const SUN := (
	'<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">'
	+ '<circle cx="5" cy="5" r="2.2" fill="#e0a84e"/>'
	+ '<path d="M5 0.6V2 M5 8V9.4 M0.6 5H2 M8 5H9.4 M1.9 1.9L2.9 2.9 M7.1 7.1L8.1 8.1'
	+ ' M1.9 8.1L2.9 7.1 M7.1 2.9L8.1 1.9" stroke="#e0a84e" stroke-width="1"'
	+ ' stroke-linecap="round"/></svg>'
)
const MOON := (
	'<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">'
	+ '<path d="M6.2 1.2A4 4 0 1 0 8.8 7.4A3.2 3.2 0 0 1 6.2 1.2Z" fill="#cdd6e0"/></svg>'
)

var clock: WorldClock

var _icon := TextureRect.new()
var _day := Label.new()
var _time := Label.new()
var _mode := Label.new()
var _sun: Texture2D
var _moon: Texture2D


func _ready() -> void:
	theme_type_variation = "HudPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sun = UiTheme.svg(SUN)
	_moon = UiTheme.svg(MOON)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_icon.custom_minimum_size = Vector2(8.0, 8.0)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_icon)
	_day.add_theme_color_override("font_color", UiTheme.MUTED)
	row.add_child(_day)
	row.add_child(_time)
	_mode.add_theme_color_override("font_color", UiTheme.MUTED)
	row.add_child(_mode)
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 4)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN


func _process(_delta: float) -> void:
	if clock == null:
		return
	_icon.texture = _moon if clock.is_night() else _sun
	var day := tr("HUD_DAY") % (clock.day_index() + 1)
	if Seasons.on(clock):
		var season := tr(WorldClock.SEASON_KEYS[Seasons.season(clock)])
		day = tr("HUD_SEASON_DAY") % [season, Seasons.day(clock) + 1]
		var year := Seasons.year(clock)
		if clock.mode != WorldClock.Mode.SYNCED and year > 0:
			day += "  " + tr("HUD_YEAR") % (year + 1)
	_day.text = day
	_time.text = clock.formatted_time()
	match clock.mode:
		WorldClock.Mode.FROZEN:
			_mode.text = "HUD_FROZEN"
		WorldClock.Mode.SYNCED:
			_mode.text = "HUD_SYNCED"
		_:
			_mode.text = ""
	_mode.visible = _mode.text != ""
