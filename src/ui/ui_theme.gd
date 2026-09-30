class_name UiTheme
extends RefCounted
## Warm, wooden, Stardew-like interface theme (placeholder until Phase 8
## brings the final UI art and a pixel font).

const INK := Color("4a2410")
const PARCHMENT := Color("f5d9a3")
const WOOD := Color("8a4b1f")
const WOOD_DARK := Color("5b2c0f")
const BUTTON := Color("e9b86a")
const BUTTON_HOVER := Color("f4ca80")
const BUTTON_PRESSED := Color("d49e4f")
const BASE_FONT_SIZE := 8


static func _box(bg: Color, border: Color, width: int, margin: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(2)
	box.set_content_margin_all(margin)
	box.anti_aliasing = false
	return box


## Set once on the UI root; child controls inherit it.
static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = BASE_FONT_SIZE

	var panel := _box(PARCHMENT, WOOD, 2, 8.0)
	panel.shadow_color = Color(0, 0, 0, 0.35)
	panel.shadow_size = 2
	panel.shadow_offset = Vector2(1, 2)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "Panel", panel)

	for type in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", type, _box(BUTTON, WOOD, 1, 3.0))
		theme.set_stylebox("hover", type, _box(BUTTON_HOVER, WOOD, 1, 3.0))
		theme.set_stylebox("pressed", type, _box(BUTTON_PRESSED, WOOD_DARK, 1, 3.0))
		theme.set_stylebox("focus", type, _box(Color(0, 0, 0, 0), WOOD_DARK, 1, 3.0))
		theme.set_stylebox("disabled", type, _box(BUTTON.darkened(0.2), WOOD, 1, 3.0))
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			theme.set_color(state, type, INK)
	theme.set_color("font_color", "Label", INK)
	theme.set_constant("separation", "VBoxContainer", 4)
	theme.set_constant("separation", "HBoxContainer", 6)
	return theme
