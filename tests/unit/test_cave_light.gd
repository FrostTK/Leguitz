extends TestCase
## The sky light (LightField): down to the first cube, through glass,
## dimmed by water, spreading under a roof a level a cell, none in a closed
## cave; baked into the chunk meshes; and the light monsters feel (Light).

const H := GameConst.WORLD_HEIGHT
const SEA := GameConst.SEA_LEVEL
const SPAN := 12
const STONE := Tiles.Block.STONE


## A region SPAN x SPAN columns wide: `fill` gives each cell's voxel
## (x, y, z -> voxel id). Returns [voxels, tops].
func _region(fill: Callable) -> Array:
	var voxels := PackedInt32Array()
	var tops := PackedByteArray()
	for z in SPAN:
		for x in SPAN:
			var top := 0
			for y in H:
				var voxel: int = fill.call(x, y, z)
				voxels.append(voxel)
				if voxel != Voxels.AIR:
					top = y + 1
			tops.append(top)
	return [voxels, tops]


## The level of a cell of a region's sky light.
func _level(sky: Array, x: int, y: int, z: int) -> int:
	var levels: PackedByteArray = sky[0]
	var open: PackedInt32Array = sky[1]
	var column := z * SPAN + x
	return LightField.MAX if y >= open[column] else levels[column * H + y]


## A stone floor (rows 0 to 10), a stone roof at row 20 over x 2 to 10, a
## stone wall at x 11 under it: light comes in from x 0 and 1 only.
func _tunnel(x: int, y: int, _z: int) -> int:
	if y <= 10:
		return Voxels.of_block(STONE)
	if x >= 10:
		return Voxels.of_block(STONE) if y <= 20 and (x == 11 or y == 20) else Voxels.AIR
	if y == 20 and x >= 2:
		return Voxels.of_block(STONE)
	return Voxels.AIR


func test_the_sky_spreads_under_a_roof_and_never_into_a_closed_room() -> void:
	var region := _region(_tunnel)
	var sky := LightField.sky(region[0], region[1], SPAN)
	assert_eq(_level(sky, 1, 11, 5), LightField.MAX, "open to the sky")
	assert_eq(_level(sky, 2, 11, 5), LightField.MAX - 1, "under the edge of the roof")
	assert_eq(_level(sky, 5, 15, 5), LightField.MAX - 4, "a level less a cell")
	assert_eq(_level(sky, 9, 11, 5), LightField.MAX - 8)
	assert_eq(_level(sky, 5, 5, 5), 0, "in the rock")
	assert_eq(_level(sky, 10, 15, 5), LightField.MAX - 9, "under the roof's far end")
	var closed := _region(
		func(x: int, y: int, z: int) -> int:
			var inside := x > 2 and x < 8 and z > 2 and z < 8 and y > 20 and y < 25
			return Voxels.AIR if inside or y > 40 else Voxels.of_block(STONE)
	)
	var dark := LightField.sky(closed[0], closed[1], SPAN)
	assert_eq(_level(dark, 5, 22, 5), 0, "a closed cave is black")


func test_glass_lets_the_sky_in_and_water_dims_it() -> void:
	var glass := Voxels.of_block(Tiles.Block.GLASS)
	var water := Voxels.of_ground(Tiles.Ground.WATER)
	var region := _region(
		func(x: int, y: int, _z: int) -> int:
			if y <= 10:
				return Voxels.of_block(STONE)
			if x < 6:
				return glass if y == 20 else Voxels.AIR
			return water if y <= 18 else Voxels.AIR
	)
	var sky := LightField.sky(region[0], region[1], SPAN)
	assert_eq(_level(sky, 3, 15, 5), LightField.MAX, "under glass")
	assert_eq(_level(sky, 9, 18, 5), LightField.MAX - 1, "the top of the water")
	assert_eq(_level(sky, 9, 14, 5), LightField.MAX - 5, "a level less a cell down")
	# Lava shines but stops the sky like rock.
	assert_eq(LightField.passing(Voxels.of_ground(Tiles.Ground.LAVA)), LightField.OPAQUE)
	assert_eq(LightField.shine(Voxels.of_ground(Tiles.Ground.LAVA)), LightField.MAX)
	assert_eq(LightField.shine(Voxels.of_block(Tiles.Block.TORCH)), 14)
	assert_eq(LightField.shine(Voxels.of_block(Tiles.Block.FOOD_FURNACE_LIT_WEST)), 13)
	assert_eq(LightField.shine(Voxels.of_block(Tiles.Block.FOOD_FURNACE_WEST)), 0, "unlit")


func test_chunk_meshes_bake_the_sky_light() -> void:
	var chunk := ChunkData.new(Vector2i.ZERO)
	var stone := Voxels.of_block(STONE)
	for lz in GameConst.CHUNK_SIZE:
		for lx in GameConst.CHUNK_SIZE:
			for y in SEA + 6:
				chunk.set_voxel(Vector3i(lx, y, lz), stone)
	# A closed cave in the rock, a hole down to a shaft lit from above.
	for lz in range(2, 6):
		for lx in range(2, 6):
			for y in range(SEA - 6, SEA - 3):
				chunk.set_voxel(Vector3i(lx, y, lz), Voxels.AIR)
	for y in range(SEA - 2, SEA + 6):
		chunk.set_voxel(Vector3i(10, y, 10), Voxels.AIR)
	var job := ChunkMesher.Job.of_chunk(chunk, func(_coord: Vector2i) -> ChunkData: return null)
	job.variants.resize(Tiles.Block.size())
	var result := ChunkMesher.build(job)
	var deep := result.parts[ChunkMesher.Part.DEEP_TOPS]
	var lights := {}
	for i in deep.vertices.size():
		lights[roundi(deep.colors[i].b * LightField.MAX)] = true
	assert_true(lights.has(0), "the closed cave's floor gets no sky light")
	var surface := result.parts[ChunkMesher.Part.TOPS]
	for i in surface.vertices.size():
		assert_eq(surface.colors[i].b, 1.0, "the open ground gets it all")
	# Kept for the client (WorldView3D.sky_at).
	var view := ChunkView3D.new(ShaderMaterial.new(), ShaderMaterial.new(), ShaderMaterial.new())
	view.apply(result, PropLibrary.new(), 0)
	assert_eq(view.sky_at(Vector3i(3, SEA - 5, 3)), 0)
	assert_eq(view.sky_at(Vector3i(10, SEA - 2, 10)), LightField.MAX, "the shaft's bottom")
	assert_eq(view.sky_at(Vector3i(0, SEA + 6, 0)), LightField.MAX)
	view.free()


## The monsters' light: a flat stone ground at row SEA - 1, a cave from
## x = 20 on (a stone roof at row SEA + 2 over rows SEA, SEA + 1).
func _voxel_at(cell: Vector3i) -> int:
	if cell.y < SEA or (cell.x >= 20 and cell.y == SEA + 2):
		return Voxels.of_block(STONE)
	return Voxels.AIR


func _top_at(tile: Vector2i) -> int:
	return SEA + 3 if tile.x >= 20 else SEA


func test_monsters_feel_daylight_night_and_fires() -> void:
	var day := LightField.MAX
	var field := Vector3i(5, SEA, 5)
	assert_eq(Light.level_at(_voxel_at, _top_at, field, day), LightField.MAX)
	assert_false(Light.level_at(_voxel_at, _top_at, field, Light.NIGHT_SKY) >= Light.LIT, "night")
	var mouth := Vector3i(22, SEA, 5)
	assert_eq(Light.level_at(_voxel_at, _top_at, mouth, day), LightField.MAX - 3)
	var deep := Vector3i(40, SEA, 5)
	assert_false(Light.level_at(_voxel_at, _top_at, deep, day) >= Light.LIT, "deep in the cave")
	# A torch in the cave lights it around, through the tunnel.
	var torch := Vector3i(44, SEA, 5)
	var lit := func(cell: Vector3i) -> int:
		return Voxels.of_block(Tiles.Block.TORCH) if cell == torch else _voxel_at(cell)
	assert_eq(Light.level_at(lit, _top_at, deep, day), 14 - 4)
	assert_false(Light.level_at(lit, _top_at, Vector3i(52, SEA, 5), day) >= Light.LIT, "far")
	# Behind a wall, the torch's light goes around it, a level a cell.
	var walled := func(cell: Vector3i) -> int:
		if cell.x == 42 and cell.y <= SEA + 1:
			return Voxels.of_block(STONE)
		return lit.call(cell)
	assert_false(Light.level_at(walled, _top_at, deep, day) >= Light.LIT, "the wall shades it")
