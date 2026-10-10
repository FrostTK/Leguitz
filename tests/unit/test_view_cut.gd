extends TestCase
## The view cut under cover: under a building's roof it only reaches the
## building (CutRegion: the room joined to the player's tile and its
## walls), under rock everywhere; the chunk meshes cut their surface maps
## and caps only where it reaches.

const SEA := GameConst.SEA_LEVEL


## Grass at level 0 on stone, with a 7 x 7 house (tiles 4..10) of `roof`
## blocks over walls three levels tall, a door on the south (7, 10).
func _world_with_house(roof: int) -> ClientWorld:
	var chunk := ChunkData.new(Vector2i.ZERO)
	var stone := Voxels.of_block(Tiles.Block.STONE)
	var grass := Voxels.of_ground(Tiles.Ground.GRASS)
	var planks := Voxels.of_block(Tiles.Block.OAK_PLANKS)
	for lz in GameConst.CHUNK_SIZE:
		for lx in GameConst.CHUNK_SIZE:
			for y in SEA:
				chunk.set_voxel(Vector3i(lx, y, lz), grass if y == SEA - 1 else stone)
	for lz in range(4, 11):
		for lx in range(4, 11):
			chunk.set_voxel(Vector3i(lx, SEA + 3, lz), roof)
			if lx != 4 and lx != 10 and lz != 4 and lz != 10:
				continue
			for row in range(SEA, SEA + 3):
				var door := lx == 7 and lz == 10 and row < SEA + 2
				if not door:
					chunk.set_voxel(Vector3i(lx, row, lz), planks)
	var world := ClientWorld.new()
	world.store(chunk)
	return world


func test_under_a_roof_the_cut_only_reaches_the_building() -> void:
	var world := _world_with_house(Voxels.of_block(Tiles.Block.OAK_PLANKS))
	var region := CutRegion.around(world, Vector2i(7, 7), 0.0)
	assert_false(region.everywhere, "a building's roof")
	assert_true(region.covers(Vector2i(7, 7)), "the room")
	assert_true(region.covers(Vector2i(5, 9)))
	assert_true(region.covers(Vector2i(4, 4)), "its walls")
	assert_true(region.covers(Vector2i(10, 7)))
	assert_true(region.covers(Vector2i(7, 10)), "the door")
	assert_true(region.covers(Vector2i(7, 11)), "just outside it")
	assert_false(region.covers(Vector2i(3, 7)), "not beyond the walls")
	assert_false(region.covers(Vector2i(7, 12)))
	assert_false(region.covers(Vector2i(40, 40)), "nor far away")
	assert_eq(region.bounds, Rect2i(4, 4, 7, 8))
	assert_true(region.touches(Vector2i.ZERO))
	assert_false(region.touches(Vector2i(2, 0)), "a chunk away")
	# The mask the shaders read.
	var mask := region.image()
	var at := Vector2i(7, 7) - region.origin
	assert_eq(mask.get_pixel(at.x, at.y).r, 1.0)
	assert_eq(mask.get_pixel(0, 0).r, 0.0)
	# The same room worked out again is the same region.
	assert_true(region.same_as(CutRegion.around(world, Vector2i(6, 6), 0.0)))


func test_under_rock_the_cut_reaches_everywhere() -> void:
	var world := _world_with_house(Voxels.of_block(Tiles.Block.STONE))
	var region := CutRegion.around(world, Vector2i(7, 7), 0.0)
	assert_true(region.everywhere, "rock over the head: a cave")
	assert_true(region.covers(Vector2i(500, -300)))
	assert_true(region.columns_of(Vector2i.ZERO).is_empty(), "every column")


func test_chunks_cut_their_maps_and_caps_where_the_cut_reaches() -> void:
	var world := _world_with_house(Voxels.of_block(Tiles.Block.OAK_PLANKS))
	var chunk := world.chunks[Vector2i.ZERO]
	var planks := Voxels.of_block(Tiles.Block.OAK_PLANKS)
	# A planks pillar outside the house, as tall as its walls and roof.
	for row in range(SEA, SEA + 4):
		chunk.set_voxel(Vector3i(13, row, 13), planks)
	var region := CutRegion.around(world, Vector2i(7, 7), 0.0)
	var job := ChunkJob.of_chunk(chunk, func(_coord: Vector2i) -> ChunkData: return null)
	job.variants.resize(256)
	job.cut_row = SEA + 2
	job.cut_columns = region.columns_of(Vector2i.ZERO)
	var result := ChunkMesher.build(job)
	var span := ChunkMesher.SPAN
	var wall := ((4 + 1) * span + (7 + 1)) * 4 + 2
	assert_almost(result.surface_map[wall], 2.0, 0.001, "the wall, cut")
	var pillar := ((13 + 1) * span + (13 + 1)) * 4 + 2
	assert_almost(result.surface_map[pillar], 4.0, 0.001, "the pillar, whole")
	# Caps on the walls (24 tiles around the room, less the door's), none on
	# the pillar.
	var caps := result.parts[ChunkMesher.Part.CAPS]
	var capped := 0.0
	for quad in caps.quad_count():
		var a := caps.vertices[quad * 4]
		var c := caps.vertices[quad * 4 + 2]
		capped += absf((c.x - a.x) * (c.z - a.z))
		assert_true(a.x < 12.0 and a.z < 12.0, "not on the pillar")
	assert_almost(capped, 23.0, 0.001)
