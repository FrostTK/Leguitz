class_name PeerNames
extends Control
## The other players' names over their heads (multiplayer, step 2), drawn
## in the UI's letters where PeersView.labels puts them on the screen
## (WorldViewport.screen_point), on a dark rounded plate; they fade with the body
## and with the distance from the local player (FADE_FROM to RANGE tiles).

const RANGE := 40.0
const FADE_FROM := 28.0
const PLATE := Color(UiTheme.PANEL, 0.7)
const PADDING := Vector2(3.0, 1.0)

var peers: PeersView
var viewport: WorldViewport
## The local player's feet (local units; Callable returning a Vector3).
var player_feet: Callable

var _drawn := false
## The plate, its color set before each name is drawn (a style box's
## colors are read as it draws).
var _plate := UiTheme.box(PLATE, Color.TRANSPARENT, UiTheme.SMALL_RADIUS, 0.0)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if _drawn or (peers != null and not peers.peers.is_empty()):
		queue_redraw()


func _draw() -> void:
	_drawn = false
	if peers == null or viewport == null:
		return
	var font := get_theme_default_font()
	var font_size := UiTheme.BASE_FONT_SIZE
	var from: Vector3 = player_feet.call()
	for label: Array in peers.labels():
		var at := viewport.screen_point(label[1])
		var distance := (label[3] as Vector3).distance_to(from)
		var alpha: float = label[2] * (1.0 - smoothstep(FADE_FROM, RANGE, distance))
		if at == Vector2.INF or alpha <= 0.01:
			continue
		var text: String = label[0]
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var box := (text_size + PADDING * 2.0).ceil()
		var corner := (at - Vector2(box.x * 0.5, box.y)).floor()
		_plate.bg_color = Color(PLATE, PLATE.a * alpha)
		draw_style_box(_plate, Rect2(corner, box))
		var baseline := corner + Vector2(PADDING.x, PADDING.y + font.get_ascent(font_size))
		var ink := Color(UiTheme.TEXT, alpha)
		draw_string(font, baseline.round(), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
		_drawn = true
