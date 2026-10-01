class_name WorldMapRenderer
extends RefCounted
## Renders a top-down color map of the generated world: biome colors with
## hill shading, water depth, cliff lines; or a horizontal cut through the
## voxels at a row, showing caves, lakes and lava.
## Used by the debug map (M key) and tools/render_world_map.gd.

const ROCK_COLOR := Color("4a4950")
const DEEP_ROCK_COLOR := Color("34333d")
const FLOOR_COLOR := Color("9a98a2")
const DEEP_FLOOR_COLOR := Color("6d6b78")
const WATER_COLOR := Color("3f7fd0")
const LAVA_COLOR := Color("f2682a")


## `tiles_per_pixel` >= 1. The map is centered on `center` (a tile); `row`
## is Msg.MAP_SURFACE for the surface, or the row of a horizontal cut.
static func render(
	generator: WorldGenerator, row: int, center: Vector2i, size_px: int, tiles_per_pixel: int
) -> Image:
	if row != Msg.MAP_SURFACE:
		return _render_cut(generator, row, center, size_px, tiles_per_pixel)
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


static func _render_cut(
	generator: WorldGenerator, row: int, center: Vector2i, size_px: int, step: int
) -> Image:
	var x0 := center.x - size_px * step / 2
	var y0 := center.y - size_px * step / 2
	var deep := row < CaveGenerator.DEEPSLATE_ROW
	var rock := DEEP_ROCK_COLOR if deep else ROCK_COLOR
	var floor_color := DEEP_FLOOR_COLOR if deep else FLOOR_COLOR
	var grid := ClimateGrid.new(
		generator.climate, Rect2i(x0, y0, size_px * step + 1, size_px * step + 1)
	)
	var image := Image.create(size_px, size_px, false, Image.FORMAT_RGB8)
	for py in size_px:
		for px in size_px:
			var tx := x0 + px * step
			var ty := y0 + py * step
			var column := generator.column_from_grid(grid, tx, ty)
			var color := rock
			if row >= GameConst.SEA_LEVEL + column.level - 1:
				# Above the rock: the terrain seen from the cut.
				color = Biomes.map_color(column.biome).darkened(0.3)
			elif generator.caves.is_open(tx, row, ty):
				color = floor_color
				if not generator.caves.is_open(tx, row - 1, ty):
					var fluid := generator.caves.fluid_at(tx, row - 1, ty)
					if fluid == Voxels.of_ground(Tiles.Ground.WATER):
						color = WATER_COLOR
					elif fluid == Voxels.of_ground(Tiles.Ground.LAVA):
						color = LAVA_COLOR
			image.set_pixel(px, py, color)
	return image
