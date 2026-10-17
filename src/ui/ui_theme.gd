class_name UiTheme
extends RefCounted
## The interface's look, « Ardoise » (asked by the owner, October 2026):
## dark, slightly see-through panels with a faint light line and rounded
## corners, flat rounded tiles for slots, one accent (amber) for what is
## chosen, focused or the main action, off-white text and a grey for what
## is secondary; strong colors only where they mean something (vitality,
## satiety, air, armor). Every color is here; `build` makes the Theme set
## on the UI root (every control inherits it), and the helpers give the
## shared pieces: boxes (`box`, `draw_box`), gauges (`draw_gauge`), the
## shade behind a screen (`shade`), titled and secondary labels (theme
## variations TitleLabel, SectionLabel, HintLabel; `label`), a card's
## header (`header`), the main action's button (AccentButton). Icons
## (check boxes, switches, arrows) are drawn as SVG (DPITexture: sharp at
## every UI scale). The player's book keeps its own paper (BookScreen).

## Surfaces: a screen's panel, the same without see-through, a card in a
## panel, a slot (and under the mouse), a gauge's track.
const PANEL := Color(0.094, 0.106, 0.125, 0.92)
const PANEL_SOLID := Color("1d2127")
const CARD := Color("23282f")
const SLOT := Color("353a42")
const SLOT_HOVER := Color("424852")
const TRACK := Color("121519")
## Lines: the faint one around panels and fields, a stronger one.
const LINE := Color(1.0, 1.0, 1.0, 0.08)
const LINE_STRONG := Color(1.0, 1.0, 1.0, 0.18)
## Text: the main one, the secondary, the faint (placeholders, disabled).
const TEXT := Color("e8e4dc")
const MUTED := Color("9aa0a6")
const FAINT := Color("6c727a")
## The accent (amber) and text on it.
const ACCENT := Color("e0a84e")
const ACCENT_HOVER := Color("ebba68")
const ACCENT_PRESSED := Color("c9913a")
const ON_ACCENT := Color("1c1a17")
## What things mean.
const DANGER := Color("e0645a")
const SUCCESS := Color("7bc96f")
const LIFE := Color("d9584a")
const FOOD := Color("d99a3e")
const AIR := Color("6cbbe8")
const STEEL := Color("aab6c2")
## Behind a screen opened over the world.
const SHADE := Color(0.035, 0.04, 0.05, 0.62)
const RADIUS := 4
const SMALL_RADIUS := 3
const BASE_FONT_SIZE := 8
const TITLE_FONT_SIZE := 12
const SMALL_FONT_SIZE := 7
## The icons (SVG).

const _CHECKED := (
	'<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">'
	+ '<rect x="0.5" y="0.5" width="9" height="9" rx="2" fill="#e0a84e"/>'
	+ '<path d="M2.6 5.2 L4.3 6.9 L7.5 3.4" fill="none" stroke="#1c1a17" stroke-width="1.4"'
	+ ' stroke-linecap="round" stroke-linejoin="round"/></svg>'
)
const _UNCHECKED := (
	'<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">'
	+ '<rect x="0.5" y="0.5" width="9" height="9" rx="2" fill="#121519"'
	+ ' stroke="#ffffff" stroke-opacity="0.25"/></svg>'
)
const _RADIO_ON := (
	'<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">'
	+ '<circle cx="5" cy="5" r="4.5" fill="#121519" stroke="#e0a84e"/>'
	+ '<circle cx="5" cy="5" r="2.2" fill="#e0a84e"/></svg>'
)
const _RADIO_OFF := (
	'<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">'
	+ '<circle cx="5" cy="5" r="4.5" fill="#121519" stroke="#ffffff" stroke-opacity="0.25"/>'
	+ "</svg>"
)
const _SWITCH_ON := (
	'<svg xmlns="http://www.w3.org/2000/svg" width="18" height="10">'
	+ '<rect x="0.5" y="0.5" width="17" height="9" rx="4.5" fill="#e0a84e"/>'
	+ '<circle cx="13" cy="5" r="3.2" fill="#1c1a17"/></svg>'
)
const _SWITCH_OFF := (
	'<svg xmlns="http://www.w3.org/2000/svg" width="18" height="10">'
	+ '<rect x="0.5" y="0.5" width="17" height="9" rx="4.5" fill="#121519"'
	+ ' stroke="#ffffff" stroke-opacity="0.25"/>'
	+ '<circle cx="5" cy="5" r="3.2" fill="#9aa0a6"/></svg>'
)
const _ARROW_DOWN := (
	'<svg xmlns="http://www.w3.org/2000/svg" width="8" height="8">'
	+ '<path d="M1.5 3 L4 5.5 L6.5 3" fill="none" stroke="#9aa0a6" stroke-width="1.3"'
	+ ' stroke-linecap="round" stroke-linejoin="round"/></svg>'
)

## Boxes made for drawing (draw_box), by their look.
static var _boxes: Dictionary[String, StyleBoxFlat] = {}


## A rounded box: `fill`, a `line` around it (transparent: none), its
## corners, the room inside. A see-through line is laid over the fill
## first: a box's border replaces its fill, it would show what lies behind
## (and its corners, drawn twice, as dots).
static func box(
	fill: Color, line := LINE, radius := RADIUS, margin := 6.0, line_width := 1
) -> StyleBoxFlat:
	var made := StyleBoxFlat.new()
	made.bg_color = fill
	made.border_color = _over(fill, line) if line.a < 1.0 else line
	made.set_border_width_all(line_width if line.a > 0.0 else 0)
	made.set_corner_radius_all(radius)
	made.set_content_margin_all(margin)
	made.anti_aliasing = true
	made.anti_aliasing_size = 0.5
	return made


## Draws a rounded box on any canvas (`fill` and its `line`; a line alone
## with a transparent fill).
static func draw_box(
	canvas: CanvasItem, rect: Rect2, fill: Color, line := LINE, radius := RADIUS, line_width := 1
) -> void:
	var key := "%s %s %d %d" % [fill.to_html(), line.to_html(), radius, line_width]
	if not _boxes.has(key):
		_boxes[key] = box(fill, line, radius, 0.0, line_width)
	canvas.draw_style_box(_boxes[key], rect)


## Draws a gauge: its track and `fraction` (0..1) of it in `fill`, rounded.
static func draw_gauge(
	canvas: CanvasItem, rect: Rect2, fraction: float, fill: Color, track := TRACK
) -> void:
	var radius := floori(rect.size.y * 0.5)
	draw_box(canvas, rect, track, LINE, radius)
	var width := roundf(rect.size.x * clampf(fraction, 0.0, 1.0))
	if width >= 1.0:
		var filled := Rect2(rect.position, Vector2(maxf(width, rect.size.y), rect.size.y))
		draw_box(canvas, filled, fill, Color.TRANSPARENT, radius)


## The shade behind a screen (fills its parent).
static func shade(color := SHADE) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return rect


## A label showing `key` in a theme variation (TitleLabel, SectionLabel,
## HintLabel; "": a plain one).
static func label(key: String, variation := "") -> Label:
	var made := Label.new()
	made.text = key
	if variation != "":
		made.theme_type_variation = variation
	return made


## A card's header: its icon (null: none), its title and a faint line under.
static func header(title_key: String, icon: Texture2D = null) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	if icon != null:
		var picture := TextureRect.new()
		picture.texture = icon
		picture.custom_minimum_size = Vector2(12.0, 12.0)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(picture)
	row.add_child(label(title_key, "TitleLabel"))
	column.add_child(row)
	var line := HSeparator.new()
	column.add_child(line)
	return column


## Set once on the UI root; child controls inherit it.
static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = BASE_FONT_SIZE
	_panels(theme)
	_buttons(theme)
	_toggles(theme)
	_fields(theme)
	_lists(theme)
	_labels(theme)
	return theme


static func _panels(theme: Theme) -> void:
	var panel := box(PANEL, LINE, RADIUS, 8.0)
	for type in ["PanelContainer", "Panel"]:
		theme.set_stylebox("panel", type, panel)
	# A small panel over the world (the clock, notices).
	theme.set_type_variation("HudPanel", "PanelContainer")
	var hud := box(PANEL, LINE, RADIUS, 4.0)
	hud.content_margin_top = 2.0
	hud.content_margin_bottom = 2.0
	theme.set_stylebox("panel", "HudPanel", hud)
	# A card inside a panel.
	theme.set_type_variation("CardPanel", "PanelContainer")
	theme.set_stylebox("panel", "CardPanel", box(CARD, LINE, SMALL_RADIUS, 6.0))
	theme.set_stylebox("panel", "TooltipPanel", box(PANEL_SOLID, LINE_STRONG, SMALL_RADIUS, 4.0))
	theme.set_color("font_color", "TooltipLabel", TEXT)
	var line := StyleBoxLine.new()
	line.color = LINE
	line.thickness = 1
	theme.set_stylebox("separator", "HSeparator", line)
	theme.set_constant("separation", "HSeparator", 1)
	var upright := StyleBoxLine.new()
	upright.color = LINE
	upright.vertical = true
	theme.set_stylebox("separator", "VSeparator", upright)


static func _buttons(theme: Theme) -> void:
	for type in ["Button", "OptionButton"]:
		_button_look(theme, type, SLOT, SLOT_HOVER, CARD, TEXT)
	# The main action: amber.
	theme.set_type_variation("AccentButton", "Button")
	_button_look(theme, "AccentButton", ACCENT, ACCENT_HOVER, ACCENT_PRESSED, ON_ACCENT)
	theme.set_icon("arrow", "OptionButton", _svg(_ARROW_DOWN))
	theme.set_constant("arrow_margin", "OptionButton", 4)
	theme.set_constant("h_separation", "Button", 4)


static func _button_look(
	theme: Theme, type: String, fill: Color, hover: Color, pressed: Color, ink: Color
) -> void:
	theme.set_stylebox("normal", type, box(fill, LINE, SMALL_RADIUS, 4.0))
	theme.set_stylebox("hover", type, box(hover, LINE_STRONG, SMALL_RADIUS, 4.0))
	theme.set_stylebox("pressed", type, box(pressed, LINE_STRONG, SMALL_RADIUS, 4.0))
	theme.set_stylebox("hover_pressed", type, box(hover, LINE_STRONG, SMALL_RADIUS, 4.0))
	theme.set_stylebox("disabled", type, box(Color(fill, 0.45), LINE, SMALL_RADIUS, 4.0))
	theme.set_stylebox("focus", type, box(Color.TRANSPARENT, ACCENT, SMALL_RADIUS, 4.0))
	for state in [
		"font_color",
		"font_hover_color",
		"font_pressed_color",
		"font_focus_color",
		"font_hover_pressed_color",
	]:
		theme.set_color(state, type, ink)
	theme.set_color("font_disabled_color", type, Color(ink, 0.45))


## Check boxes and switches: no box around, their own icons.
static func _toggles(theme: Theme) -> void:
	var bare := StyleBoxEmpty.new()
	bare.set_content_margin_all(2.0)
	for type in ["CheckBox", "CheckButton"]:
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			theme.set_stylebox(state, type, bare)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			theme.set_color(state, type, TEXT)
		theme.set_color("font_hover_pressed_color", type, TEXT)
		theme.set_color("font_disabled_color", type, FAINT)
		theme.set_constant("h_separation", type, 5)
	theme.set_icon("checked", "CheckBox", _svg(_CHECKED))
	theme.set_icon("unchecked", "CheckBox", _svg(_UNCHECKED))
	theme.set_icon("checked_disabled", "CheckBox", _svg(_CHECKED, 0.45))
	theme.set_icon("unchecked_disabled", "CheckBox", _svg(_UNCHECKED, 0.45))
	theme.set_icon("radio_checked", "CheckBox", _svg(_RADIO_ON))
	theme.set_icon("radio_unchecked", "CheckBox", _svg(_RADIO_OFF))
	theme.set_icon("checked", "CheckButton", _svg(_SWITCH_ON))
	theme.set_icon("unchecked", "CheckButton", _svg(_SWITCH_OFF))
	theme.set_icon("checked_disabled", "CheckButton", _svg(_SWITCH_ON, 0.45))
	theme.set_icon("unchecked_disabled", "CheckButton", _svg(_SWITCH_OFF, 0.45))


static func _fields(theme: Theme) -> void:
	theme.set_stylebox("normal", "LineEdit", box(TRACK, LINE_STRONG, SMALL_RADIUS, 4.0))
	theme.set_stylebox("focus", "LineEdit", box(Color.TRANSPARENT, ACCENT, SMALL_RADIUS, 4.0))
	theme.set_stylebox("read_only", "LineEdit", box(Color(TRACK, 0.5), LINE, SMALL_RADIUS, 4.0))
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", FAINT)
	theme.set_color("caret_color", "LineEdit", ACCENT)
	theme.set_color("selection_color", "LineEdit", Color(ACCENT, 0.35))
	theme.set_color("font_selected_color", "LineEdit", TEXT)
	theme.set_color("clear_button_color", "LineEdit", MUTED)
	theme.set_color("clear_button_color_pressed", "LineEdit", ACCENT)


## Drop-down lists and scroll bars.
static func _lists(theme: Theme) -> void:
	theme.set_stylebox("panel", "PopupMenu", box(PANEL_SOLID, LINE_STRONG, SMALL_RADIUS, 3.0))
	theme.set_stylebox("hover", "PopupMenu", box(SLOT_HOVER, Color.TRANSPARENT, 2, 2.0))
	theme.set_color("font_color", "PopupMenu", TEXT)
	theme.set_color("font_hover_color", "PopupMenu", TEXT)
	theme.set_color("font_disabled_color", "PopupMenu", FAINT)
	theme.set_color("font_separator_color", "PopupMenu", MUTED)
	theme.set_icon("radio_checked", "PopupMenu", _svg(_RADIO_ON))
	theme.set_icon("radio_unchecked", "PopupMenu", _svg(_RADIO_OFF))
	theme.set_icon("checked", "PopupMenu", _svg(_CHECKED))
	theme.set_icon("unchecked", "PopupMenu", _svg(_UNCHECKED))
	theme.set_constant("v_separation", "PopupMenu", 4)
	for type in ["VScrollBar", "HScrollBar"]:
		# A scroll bar is as wide as its track's margins (not its grabber).
		var track := box(Color(TRACK, 0.6), Color.TRANSPARENT, 2, 2.0)
		theme.set_stylebox("scroll", type, track)
		theme.set_stylebox("scroll_focus", type, track)
		theme.set_stylebox("grabber", type, box(SLOT_HOVER, Color.TRANSPARENT, 2, 2.0))
		theme.set_stylebox("grabber_highlight", type, box(MUTED, Color.TRANSPARENT, 2, 2.0))
		theme.set_stylebox("grabber_pressed", type, box(ACCENT, Color.TRANSPARENT, 2, 2.0))
		for icon in ["increment", "decrement", "increment_highlight", "decrement_highlight"]:
			theme.set_icon(icon, type, ImageTexture.new())
	for type in ["TabBar", "TabContainer"]:
		theme.set_stylebox("tab_selected", type, box(SLOT_HOVER, LINE_STRONG, SMALL_RADIUS, 4.0))
		theme.set_stylebox("tab_unselected", type, box(Color.TRANSPARENT, LINE, SMALL_RADIUS, 4.0))
		theme.set_stylebox("tab_hovered", type, box(SLOT, LINE_STRONG, SMALL_RADIUS, 4.0))
		theme.set_color("font_selected_color", type, TEXT)
		theme.set_color("font_unselected_color", type, MUTED)
		theme.set_color("font_hovered_color", type, TEXT)
	theme.set_stylebox("panel", "TabContainer", StyleBoxEmpty.new())


static func _labels(theme: Theme) -> void:
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("default_color", "RichTextLabel", TEXT)
	theme.set_type_variation("TitleLabel", "Label")
	theme.set_font_size("font_size", "TitleLabel", TITLE_FONT_SIZE)
	theme.set_color("font_color", "TitleLabel", TEXT)
	theme.set_type_variation("SectionLabel", "Label")
	theme.set_font_size("font_size", "SectionLabel", SMALL_FONT_SIZE)
	theme.set_color("font_color", "SectionLabel", MUTED)
	theme.set_type_variation("HintLabel", "Label")
	theme.set_font_size("font_size", "HintLabel", SMALL_FONT_SIZE)
	theme.set_color("font_color", "HintLabel", MUTED)


## `over` laid on `under`.
static func _over(under: Color, over: Color) -> Color:
	var alpha := over.a + under.a * (1.0 - over.a)
	if alpha <= 0.0:
		return Color.TRANSPARENT
	var rgb := (Color(over, 1.0) * over.a + Color(under, 1.0) * under.a * (1.0 - over.a)) / alpha
	return Color(rgb, alpha)


## An icon from SVG text (`alpha`: dimmed), sharp at every UI scale.
static func _svg(source: String, alpha := 1.0) -> Texture2D:
	var text := source
	if alpha < 1.0:
		text = text.replace("<svg ", '<svg opacity="%.2f" ' % alpha)
	return DPITexture.create_from_string(text)
