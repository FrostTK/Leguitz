class_name TerrainChunk
extends Node2D
## One chunk of terrain: a single 256x256 px quad drawn by the terrain
## shader from the chunk's data texture.

var data_texture: ImageTexture
var _image := Image.create(
	TerrainRenderer.DATA_SIZE, TerrainRenderer.DATA_SIZE, false, Image.FORMAT_RGBAF
)


func _init() -> void:
	data_texture = ImageTexture.create_from_image(_image)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func set_data(values: PackedFloat32Array) -> void:
	_image.set_data(
		TerrainRenderer.DATA_SIZE,
		TerrainRenderer.DATA_SIZE,
		false,
		Image.FORMAT_RGBAF,
		values.to_byte_array()
	)
	data_texture.update(_image)
	queue_redraw()


func _draw() -> void:
	draw_texture_rect(
		data_texture, Rect2(0, 0, GameConst.CHUNK_PIXELS, GameConst.CHUNK_PIXELS), false
	)
