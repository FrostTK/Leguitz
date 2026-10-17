class_name DeathScreen
extends Control
## What shows when the player passes out (their vitality ran out): the
## world darkens, a panel rises into place (UiTheme.appear) with a cracked
## life crystal, says what happened and that their things lie where they
## fell, and a button gets them up again (at the spawn). In hardcore their
## adventure is over: the button lets them watch the world.
## Also draws the red pulse at the screen's edges when they are hurt
## (flash), alive or not.

signal respawn_requested

## How long the world takes to darken, and how dark it gets.
const FADE_SECONDS := 1.2
const SHADE := Color(0.12, 0.03, 0.02, 0.62)
## The edges' pulse: how wide (UI units, in steps) and how long it lasts.
const PULSE_STEPS := 6
const PULSE_STEP := 4.0
const PULSE_SECONDS := 0.45
const PULSE_COLOR := Color(0.78, 0.06, 0.05)
## The cracked life crystal over the title (SVG).
const CRYSTAL := (
	'<svg xmlns="http://www.w3.org/2000/svg" width="16" height="20">'
	+ '<path d="M8 1L15 8L8 19L1 8Z" fill="#7c1622" stroke="#d9584a" stroke-width="1"'
	+ ' stroke-linejoin="round"/>'
	+ '<path d="M8 1L5 8L8 19" fill="none" stroke="#e2524e" stroke-opacity="0.5"/>'
	+ '<path d="M9 4L7 8L10 11L8 15" fill="none" stroke="#1d2127" stroke-width="1.3"'
	+ ' stroke-linecap="round" stroke-linejoin="round"/></svg>'
)

var _panel := PanelContainer.new()
var _title := Label.new()
var _cause := Label.new()
var _things := Label.new()
var _button := Button.new()
var _fade := 0.0
var _dead := false
var _pulse := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 5)
	_panel.add_child(box)
	var crystal := TextureRect.new()
	crystal.texture = UiTheme.svg(CRYSTAL)
	crystal.custom_minimum_size = Vector2(16.0, 20.0)
	crystal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crystal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crystal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(crystal)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.theme_type_variation = "TitleLabel"
	box.add_child(_title)
	_cause.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_cause)
	_things.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_things.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_things.custom_minimum_size.x = 150.0
	_things.theme_type_variation = "HintLabel"
	box.add_child(_things)
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.theme_type_variation = "AccentButton"
	_button.pressed.connect(func() -> void: respawn_requested.emit())
	box.add_child(_button)
	_panel.visible = false


## The player passed out from `cause` (Vitals.Cause); in a hardcore world
## (`last`), for good.
func open(cause: int, last := false) -> void:
	_dead = true
	_fade = 0.0
	_title.text = "DEATH_TITLE_HARDCORE" if last else "DEATH_TITLE"
	_cause.text = Vitals.CAUSE_KEYS.get(cause, "DEATH_CAUSE_NONE")
	_things.text = "DEATH_THINGS_HARDCORE" if last else "DEATH_THINGS"
	_button.text = "DEATH_WATCH" if last else "DEATH_GET_UP"
	_panel.visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP


## They got up.
func close() -> void:
	_dead = false
	_panel.visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func is_open() -> bool:
	return _dead


## A hurt: the screen's edges pulse red.
func flash() -> void:
	_pulse = 1.0


func _process(delta: float) -> void:
	if _pulse > 0.0:
		_pulse = maxf(_pulse - delta / PULSE_SECONDS, 0.0)
		queue_redraw()
	if _dead and _fade < 1.0:
		_fade = minf(_fade + delta / FADE_SECONDS, 1.0)
		# The words come once the world has darkened, rising into place.
		if _fade > 0.6 and not _panel.visible:
			_panel.visible = true
			UiTheme.appear(_panel)
		queue_redraw()


func _draw() -> void:
	if _dead:
		var shade := SHADE
		shade.a *= _fade
		draw_rect(Rect2(Vector2.ZERO, size), shade)
	if _pulse > 0.0:
		# Bands stepping in from the edges, fainter inwards.
		for step in PULSE_STEPS:
			var color := PULSE_COLOR
			color.a = _pulse * 0.42 * (1.0 - float(step) / PULSE_STEPS)
			var inset := step * PULSE_STEP
			var outer := Rect2(Vector2.ONE * inset, size - Vector2.ONE * inset * 2.0)
			_frame(outer, PULSE_STEP, color)


func _frame(rect: Rect2, width: float, color: Color) -> void:
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, width)), color)
	draw_rect(Rect2(rect.position.x, rect.end.y - width, rect.size.x, width), color)
	var side := rect.size.y - width * 2.0
	draw_rect(Rect2(rect.position.x, rect.position.y + width, width, side), color)
	draw_rect(Rect2(rect.end.x - width, rect.position.y + width, width, side), color)
