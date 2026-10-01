extends TestCase
## Voxel models: grids, coarser copies and meshes.


func test_voxel_values_pack_color_and_kind() -> void:
	var value := VoxelGrid.voxel(Color("#46963f"), VoxelGrid.Kind.FOLIAGE)
	assert_ne(value, 0)
	assert_eq(VoxelGrid.kind_of(value), VoxelGrid.Kind.FOLIAGE)
	assert_eq(VoxelGrid.color_of(value).to_html(false), "46963f")
	assert_ne(VoxelGrid.voxel(Color.BLACK), 0, "black is not empty")


func test_coarser_copy_keeps_shape_and_center() -> void:
	var grid := VoxelGrid.new(Vector3i(6, 8, 6))
	var green := VoxelGrid.voxel(Color.GREEN)
	grid.box(Vector3i(0, 0, 0), Vector3i(5, 3, 5), green)
	# A one-voxel blade sticking up: thin things survive the first level.
	grid.box(Vector3i(2, 4, 2), Vector3i(2, 7, 2), VoxelGrid.voxel(Color.RED))
	var coarse := grid.downsampled(2)
	assert_eq(coarse.size, Vector3i(3, 4, 3))
	assert_eq(coarse.get_voxel(Vector3i(0, 0, 0)), green)
	assert_ne(coarse.get_voxel(Vector3i(1, 3, 1)), 0, "the blade is still there")
	assert_eq(coarse.pivot, Vector2(1.5, 1.5), "same center as the original")


func test_coarser_meshes_are_lighter_and_same_size() -> void:
	var grid := VoxelModels.build(Tiles.Block.OAK, 0)
	var fine := VoxelMesher.build_arrays(grid)
	var coarse := VoxelMesher.build_arrays(grid.downsampled(2), 2)
	var fine_count: int = fine[Mesh.ARRAY_INDEX].size()
	var coarse_count: int = coarse[Mesh.ARRAY_INDEX].size()
	assert_true(coarse_count * 3 < fine_count, "at least 3 times fewer triangles")
	var fine_box := _bounds(fine[Mesh.ARRAY_VERTEX])
	var coarse_box := _bounds(coarse[Mesh.ARRAY_VERTEX])
	assert_almost(coarse_box.get_center().x, fine_box.get_center().x, 0.07)
	assert_almost(coarse_box.size.y, fine_box.size.y, 0.13)


func _bounds(points: PackedVector3Array) -> AABB:
	var box := AABB(points[0], Vector3.ZERO)
	for p in points:
		box = box.expand(p)
	return box
