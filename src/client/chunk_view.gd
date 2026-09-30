class_name ChunkView
extends RefCounted
## Visual representation of one chunk: a ground layer drawn under
## everything and a block layer Y-sorted with the entities (so the player
## walks behind trees and in front of them).

var coord := Vector2i.ZERO
var ground_layer := TileMapLayer.new()
var block_layer := TileMapLayer.new()


func _init(tile_set: TileSet) -> void:
	for layer in [ground_layer, block_layer]:
		layer.tile_set = tile_set
		layer.collision_enabled = false
		layer.navigation_enabled = false
	block_layer.y_sort_enabled = true


func attach(ground_parent: Node, block_parent: Node) -> void:
	ground_parent.add_child(ground_layer)
	block_parent.add_child(block_layer)


func show_chunk(chunk: ChunkData) -> void:
	coord = chunk.coord
	var origin_px := Coords.chunk_to_world(coord)
	ground_layer.position = origin_px
	block_layer.position = origin_px
	ground_layer.clear()
	block_layer.clear()
	var origin_tile := Coords.chunk_origin_tile(coord)
	var index := 0
	for ly in GameConst.CHUNK_SIZE:
		for lx in GameConst.CHUNK_SIZE:
			var local := Vector2i(lx, ly)
			var ground := chunk.ground[index]
			if ground != Tiles.Ground.NONE:
				ground_layer.set_cell(
					local, TileAtlas.SOURCE_ID, TileAtlas.ground_cell(ground, origin_tile + local)
				)
			var block := chunk.blocks[index]
			if block != Tiles.Block.AIR:
				block_layer.set_cell(local, TileAtlas.SOURCE_ID, TileAtlas.block_cell(block))
			index += 1
	ground_layer.visible = true
	block_layer.visible = true


func hide_chunk() -> void:
	ground_layer.clear()
	block_layer.clear()
	ground_layer.visible = false
	block_layer.visible = false


func free_nodes() -> void:
	ground_layer.queue_free()
	block_layer.queue_free()
