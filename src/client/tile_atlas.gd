class_name TileAtlas
extends RefCounted
## Maps tile ids to cells of the terrain atlas and builds the TileSet.
## Atlas layout (16 px grid): ground type N uses row N-1 with 4 variants in
## columns 0-3; blocks live in columns 4+ (tall ones span two rows).

const TEXTURE := preload("res://assets/textures/tiles/terrain_atlas.png")
const SOURCE_ID := 0
const GROUND_VARIANTS := 4
const VARIANT_SEED := 0x5EED

const BLOCK_CELLS := {
	Tiles.Block.TREE: Vector2i(4, 0),
	Tiles.Block.PINE: Vector2i(5, 0),
	Tiles.Block.ROCK: Vector2i(4, 2),
	Tiles.Block.BUSH: Vector2i(5, 2),
}
const TALL_BLOCKS := {Tiles.Block.TREE: true, Tiles.Block.PINE: true}
## Blocks are sorted with entities at their base (near the cell bottom).
const BLOCK_Y_SORT_ORIGIN := 6


static func ground_cell(ground: int, tile: Vector2i) -> Vector2i:
	var variant := HashUtil.hash2(VARIANT_SEED, tile.x, tile.y) % GROUND_VARIANTS
	return Vector2i(variant, ground - 1)


static func block_cell(block: int) -> Vector2i:
	return BLOCK_CELLS.get(block, Vector2i(-1, -1))


static func build_tile_set() -> TileSet:
	var result := TileSet.new()
	result.tile_size = Vector2i(GameConst.TILE_SIZE, GameConst.TILE_SIZE)
	var source := TileSetAtlasSource.new()
	source.texture = TEXTURE
	source.texture_region_size = Vector2i(GameConst.TILE_SIZE, GameConst.TILE_SIZE)
	for ground in range(1, Tiles.Ground.size()):
		for variant in GROUND_VARIANTS:
			source.create_tile(Vector2i(variant, ground - 1))
	for block: int in BLOCK_CELLS:
		var cell: Vector2i = BLOCK_CELLS[block]
		var tall: bool = TALL_BLOCKS.has(block)
		source.create_tile(cell, Vector2i(1, 2) if tall else Vector2i.ONE)
		var data := source.get_tile_data(cell, 0)
		# Relative to the cell center, independent of texture_origin.
		data.y_sort_origin = BLOCK_Y_SORT_ORIGIN
		if tall:
			# Anchor the bottom of the 16x32 sprite on its cell.
			data.texture_origin = Vector2i(0, GameConst.TILE_SIZE / 2)
	result.add_source(source, SOURCE_ID)
	return result
