class_name SaveNotice
extends PanelContainer
## A small note under the clock when the world has just been saved; it
## fades away.

const SHOWN_SECONDS := 1.6
const FADE_SECONDS := 0.6

## The panel it shows under (the clock).
var anchor: Control

var _label := Label.new()
var _left := 0.0


func _ready() -> void:
	# It also fades over the pause menu (the world saves when pausing).
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.text = "HUD_SAVED"
	add_child(_label)
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 4)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	visible = false


func flash() -> void:
	_left = SHOWN_SECONDS + FADE_SECONDS
	visible = true


func _process(delta: float) -> void:
	if not visible:
		return
	if anchor != null:
		position.y = anchor.position.y + anchor.size.y + 2.0
	_left -= delta
	modulate.a = clampf(_left / FADE_SECONDS, 0.0, 1.0)
	visible = _left > 0.0
