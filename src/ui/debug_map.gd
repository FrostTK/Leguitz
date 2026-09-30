class_name DebugMap
extends Control
## Debug world map (M): asks the server for a rendered map around the
## player. Pressing M again zooms out, then closes. A real in-game map
## item (revealed as you explore) comes later.

signal map_requested(center: Vector2i, layer: int, size_px: int, scale: int)

const SIZE_PX := 256
const SCALES: Array[int] = [2, 8]

var _scale_index := -1
var _title := Label.new()
var _status := Label.new()
var _texture_rect := TextureRect.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)

	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_texture_rect.custom_minimum_size = Vector2(SIZE_PX, SIZE_PX)
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	box.add_child(_texture_rect)
	var marker := MapMarker.new()
	marker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_texture_rect.add_child(marker)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 6)
	box.add_child(_status)


## Opens the map, zooms out, or closes it (cycles on each press).
func cycle(center_tile: Vector2i, layer: int) -> void:
	_scale_index += 1
	if _scale_index >= SCALES.size():
		close()
		return
	visible = true
	_title.text = tr("MAP_TITLE") % _layer_name(layer)
	_status.text = tr("MAP_LOADING")
	_texture_rect.texture = null
	map_requested.emit(center_tile, layer, SIZE_PX, SCALES[_scale_index])


func close() -> void:
	visible = false
	_scale_index = -1


func show_map(png: PackedByteArray, scale: int) -> void:
	if not visible:
		return
	var image := Image.new()
	if image.load_png_from_buffer(png) != OK:
		_status.text = "?"
		return
	_texture_rect.texture = ImageTexture.create_from_image(image)
	_status.text = tr("MAP_SCALE") % [scale, SIZE_PX * scale]


func _layer_name(layer: int) -> String:
	if layer >= WorldGenerator.SURFACE_LAYER:
		return tr("LAYER_SURFACE")
	return tr("LAYER_UNDERGROUND") % -layer


class MapMarker:
	extends Control

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var middle := size / 2.0
		draw_rect(Rect2(middle - Vector2(3, 0.5), Vector2(7, 1)), Color.RED)
		draw_rect(Rect2(middle - Vector2(0.5, 3), Vector2(1, 7)), Color.RED)
