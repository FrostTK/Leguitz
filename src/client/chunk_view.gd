class_name ChunkView
extends RefCounted
## Visual representation of one chunk:
## - terrain: one quad drawn by the terrain shader (grounds, water, cliffs,
##   rock walls), plus an additive glow quad when the chunk has lava/gems,
## - shadows: sun shadows of plants and props,
## - plants (swaying) and props (static), Y-sorted with the entities.

const LAVA_LIGHT_COLOR := Color(1.0, 0.45, 0.15)
const LAVA_LIGHT_RADIUS := 5.0
## Lava lights are placed per 8x8 quarter of the chunk.
const LAVA_QUARTER := 8

var coord := Vector2i.ZERO
var terrain := TerrainChunk.new()
var glow := TerrainChunk.new()
var shadow_layer := TileMapLayer.new()
var plant_layer := TileMapLayer.new()
var prop_layer := TileMapLayer.new()
var lava_lights: Array[PointLight2D] = []


func _init(tile_set: TileSet, materials: Dictionary) -> void:
	terrain.material = materials["terrain"]
	glow.material = materials["emission"]
	shadow_layer.material = materials["shadow"]
	plant_layer.material = materials["sway"]
	for layer in [shadow_layer, plant_layer, prop_layer]:
		layer.tile_set = tile_set
		layer.collision_enabled = false
		layer.navigation_enabled = false
	plant_layer.y_sort_enabled = true
	prop_layer.y_sort_enabled = true


func attach(roots: Dictionary) -> void:
	roots["terrain"].add_child(terrain)
	roots["emission"].add_child(glow)
	roots["shadow"].add_child(shadow_layer)
	roots["entities"].add_child(plant_layer)
	roots["entities"].add_child(prop_layer)


func show_chunk(chunk: ChunkData) -> void:
	coord = chunk.coord
	var origin_px := Coords.chunk_to_world(coord)
	for node: Node2D in _nodes():
		node.position = origin_px
		node.visible = true
	for layer in [shadow_layer, plant_layer, prop_layer]:
		layer.clear()
	glow.visible = TerrainRenderer.has_emission(chunk)
	_place_lava_lights(chunk)
	var index := 0
	for ly in GameConst.CHUNK_SIZE:
		for lx in GameConst.CHUNK_SIZE:
			var block := chunk.blocks[index]
			index += 1
			if block == Tiles.Block.AIR or TileAtlas.is_wall(block):
				continue
			var local := Vector2i(lx, ly)
			var layer := plant_layer if TileAtlas.SWAYING.has(block) else prop_layer
			layer.set_cell(local, TileAtlas.BLOCK_SOURCE, TileAtlas.block_cell(block))
			if not TileAtlas.NO_SHADOW.has(block):
				shadow_layer.set_cell(local, TileAtlas.SHADOW_SOURCE, TileAtlas.shadow_cell(block))


func set_terrain_data(values: PackedFloat32Array) -> void:
	terrain.set_data(values)
	glow.data_texture = terrain.data_texture
	glow.queue_redraw()


func hide_chunk() -> void:
	for light in lava_lights:
		light.visible = false
	for layer in [shadow_layer, plant_layer, prop_layer]:
		layer.clear()
	for node: Node2D in _nodes():
		node.visible = false


func free_nodes() -> void:
	for node: Node2D in _nodes():
		node.queue_free()


## Lava lights up its surroundings: one warm light per lava-rich quarter.
func _place_lava_lights(chunk: ChunkData) -> void:
	var used := 0
	for qy in 2:
		for qx in 2:
			var sum := Vector2.ZERO
			var count := 0
			for ly in range(qy * LAVA_QUARTER, (qy + 1) * LAVA_QUARTER):
				for lx in range(qx * LAVA_QUARTER, (qx + 1) * LAVA_QUARTER):
					if chunk.ground[ly * GameConst.CHUNK_SIZE + lx] == Tiles.Ground.LAVA:
						sum += Vector2(lx + 0.5, ly + 0.5)
						count += 1
			if count < 3:
				continue
			var light := _lava_light(used)
			light.position = sum / count * GameConst.TILE_SIZE
			light.energy = clampf(0.6 + count * 0.04, 0.6, 1.6)
			light.visible = true
			used += 1
	for i in range(used, lava_lights.size()):
		lava_lights[i].visible = false


func _lava_light(index: int) -> PointLight2D:
	while lava_lights.size() <= index:
		var light := PointLight2D.new()
		light.texture = LightTextures.radial()
		light.texture_scale = LightTextures.scale_for(LAVA_LIGHT_RADIUS)
		light.color = LAVA_LIGHT_COLOR
		light.height = 0.4
		terrain.add_child(light)
		lava_lights.append(light)
	return lava_lights[index]


func _nodes() -> Array[Node2D]:
	return [terrain, glow, shadow_layer, plant_layer, prop_layer]
