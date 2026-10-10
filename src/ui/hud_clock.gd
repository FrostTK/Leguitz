class_name HudClock
extends PanelContainer
## Small always-visible clock: day number (with seasons: the season and
## its day, the year after the first) and time of day.

var clock: WorldClock

var _label := Label.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 4)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN


func _process(_delta: float) -> void:
	if clock == null:
		return
	var text := tr("HUD_DAY_TIME") % [clock.day_index() + 1, clock.formatted_time()]
	if Seasons.on(clock):
		var season := tr(WorldClock.SEASON_KEYS[Seasons.season(clock)])
		var day := Seasons.day(clock) + 1
		text = tr("HUD_SEASON_TIME") % [season, day, clock.formatted_time()]
		var year := Seasons.year(clock)
		if clock.mode != WorldClock.Mode.SYNCED and year > 0:
			text += "  " + tr("HUD_YEAR") % (year + 1)
	match clock.mode:
		WorldClock.Mode.FROZEN:
			text += "  " + tr("HUD_FROZEN")
		WorldClock.Mode.SYNCED:
			text += "  " + tr("HUD_SYNCED")
	_label.text = text
