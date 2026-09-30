class_name ChunkView
extends RefCounted
## Visual representation of one chunk, in three tile layers:
## - ground (and cliff faces), drawn under everything,
## - overlay: cliff edge lines and the shadow under cliffs,
## - blocks, Y-sorted with the entities (walk behind and in front of trees).

var coord := Vector2i.ZERO
var ground_layer := TileMapLayer.new()
var overlay_layer := TileMapLayer.new()
var block_layer := TileMapLayer.new()


func _init(tile_set: TileSet) -> void:
	for layer in [ground_layer, overlay_layer, block_layer]:
		layer.tile_set = tile_set
		layer.collision_enabled = false
		layer.navigation_enabled = false
	block_layer.y_sort_enabled = true


func attach(ground_parent: Node, overlay_parent: Node, block_parent: Node) -> void:
	ground_parent.add_child(ground_layer)
	overlay_parent.add_child(overlay_layer)
	block_parent.add_child(block_layer)


func show_chunk(chunk: ChunkData) -> void:
	coord = chunk.coord
	var origin_px := Coords.chunk_to_world(coord)
	for layer in [ground_layer, overlay_layer, block_layer]:
		layer.position = origin_px
		layer.clear()
	var origin_tile := Coords.chunk_origin_tile(coord)
	var index := 0
	for ly in GameConst.CHUNK_SIZE:
		for lx in GameConst.CHUNK_SIZE:
			var local := Vector2i(lx, ly)
			var ground := chunk.ground[index]
			var shape := chunk.shapes[index]
			if shape & ChunkData.SHAPE_LOWER_S:
				var ramp := shape & ChunkData.SHAPE_RAMP != 0
				ground_layer.set_cell(
					local, TileAtlas.CLIFF_SOURCE, TileAtlas.face_cell(ground, ramp)
				)
			elif ground != Tiles.Ground.NONE:
				ground_layer.set_cell(
					local,
					TileAtlas.GROUND_SOURCE,
					TileAtlas.ground_cell(ground, origin_tile + local)
				)
			var overlay := TileAtlas.overlay_bits(shape)
			if overlay != 0:
				overlay_layer.set_cell(
					local, TileAtlas.CLIFF_SOURCE, TileAtlas.overlay_cell(overlay)
				)
			var block := chunk.blocks[index]
			if block != Tiles.Block.AIR:
				block_layer.set_cell(local, TileAtlas.BLOCK_SOURCE, TileAtlas.block_cell(block))
			index += 1
	for layer in [ground_layer, overlay_layer, block_layer]:
		layer.visible = true


func hide_chunk() -> void:
	for layer in [ground_layer, overlay_layer, block_layer]:
		layer.clear()
		layer.visible = false


func free_nodes() -> void:
	for layer in [ground_layer, overlay_layer, block_layer]:
		layer.queue_free()
