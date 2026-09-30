class_name WorldMapRenderer
extends RefCounted
## Renders a top-down color map of the generated world: biome colors with
## hill shading, water depth, cliff lines; or caves and ores underground.
## Used by the debug map (M key) and tools/render_world_map.gd.

const ORE_COLORS := {
	Tiles.Block.COAL_ORE: Color("26262b"),
	Tiles.Block.COPPER_ORE: Color("d5824a"),
	Tiles.Block.IRON_ORE: Color("d8b59a"),
	Tiles.Block.GOLD_ORE: Color("f2cf3a"),
	Tiles.Block.LAPIS_ORE: Color("2f56c7"),
	Tiles.Block.RUBY_ORE: Color("d8283f"),
	Tiles.Block.DIAMOND_ORE: Color("5fe3e0"),
	Tiles.Block.EMERALD_ORE: Color("2fcf6a"),
}
const ROCK_COLOR := Color("4a4950")
const DEEP_ROCK_COLOR := Color("34333d")
const FLOOR_COLOR := Color("9a98a2")
const DEEP_FLOOR_COLOR := Color("6d6b78")
const WATER_COLOR := Color("3f7fd0")
const LAVA_COLOR := Color("f2682a")


## `tiles_per_pixel` >= 1. The map is centered on `center` (a tile).
static func render(
	generator: WorldGenerator, layer: int, center: Vector2i, size_px: int, tiles_per_pixel: int
) -> Image:
	if layer < WorldGenerator.SURFACE_LAYER:
		return _render_underground(generator, layer, center, size_px, tiles_per_pixel)
	return _render_surface(generator, center, size_px, tiles_per_pixel)


static func _render_surface(
	generator: WorldGenerator, center: Vector2i, size_px: int, step: int
) -> Image:
	var x0 := center.x - size_px * step / 2
	var y0 := center.y - size_px * step / 2
	var span := size_px + 1
	var grid := ClimateGrid.new(generator.climate, Rect2i(x0, y0, span * step, span * step))
	var heights := PackedFloat32Array()
	var levels := PackedInt32Array()
	var biomes := PackedInt32Array()
	heights.resize(span * span)
	levels.resize(span * span)
	biomes.resize(span * span)
	for py in span:
		for px in span:
			var column := generator.column_from_grid(grid, x0 + px * step, y0 + py * step)
			var index := py * span + px
			heights[index] = column.height
			levels[index] = column.level
			biomes[index] = column.biome
	var image := Image.create(size_px, size_px, false, Image.FORMAT_RGB8)
	for py in size_px:
		for px in size_px:
			var index := py * span + px
			var h := heights[index]
			var color := Biomes.map_color(biomes[index])
			if h < 0.0:
				color = color.darkened(clampf(-h / 90.0, 0.0, 0.45))
			else:
				var slope := (heights[index + 1] - h) + (heights[index + span] - h)
				var shade := clampf(slope / (6.0 * step), -0.35, 0.35)
				color = color.darkened(shade) if shade > 0.0 else color.lightened(-shade)
				if levels[index + 1] != levels[index] or levels[index + span] != levels[index]:
					color = color.darkened(0.22)
			image.set_pixel(px, py, color)
	return image


static func _render_underground(
	generator: WorldGenerator, layer: int, center: Vector2i, size_px: int, step: int
) -> Image:
	var x0 := center.x - size_px * step / 2
	var y0 := center.y - size_px * step / 2
	var deep := -layer >= CaveGenerator.DEEPSLATE_DEPTH
	var rock := DEEP_ROCK_COLOR if deep else ROCK_COLOR
	var floor_color := DEEP_FLOOR_COLOR if deep else FLOOR_COLOR
	var image := Image.create(size_px, size_px, false, Image.FORMAT_RGB8)
	for py in size_px:
		for px in size_px:
			var tx := x0 + px * step
			var ty := y0 + py * step
			var color := rock
			if generator.caves.is_open(layer, tx, ty):
				match generator.caves.chamber_ground_at(layer, tx, ty):
					Tiles.Ground.WATER:
						color = WATER_COLOR
					Tiles.Ground.LAVA:
						color = LAVA_COLOR
					_:
						color = floor_color
			else:
				color = ORE_COLORS.get(generator.caves.rock_at(layer, tx, ty), rock)
			image.set_pixel(px, py, color)
	return image
