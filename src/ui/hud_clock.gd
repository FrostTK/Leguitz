class_name HudClock
extends PanelContainer
## Small always-visible clock: day number and time of day.

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
	match clock.mode:
		WorldClock.Mode.FROZEN:
			text += "  " + tr("HUD_FROZEN")
		WorldClock.Mode.SYNCED:
			text += "  " + tr("HUD_SYNCED")
	_label.text = text
