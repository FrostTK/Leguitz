extends TestCase
## What the player holds: the arm's strokes (raised, struck fast, back),
## the bow's stages, and the body's hand keeping a tool or a sword out of
## the head through every stroke.

const VOXEL := 1.0 / 16.0


func test_strokes_raise_strike_and_come_back() -> void:
	for kind: int in [PlayerModel.Stroke.MINE, PlayerModel.Stroke.SLASH]:
		assert_almost(PlayerModel.stroke_curve(0.0, kind), 0.0, 0.001, "from rest")
		assert_almost(PlayerModel.stroke_curve(0.35, kind), -1.0, 0.001, "raised")
		assert_almost(PlayerModel.stroke_curve(0.5499, kind), 1.0, 0.01, "struck")
		assert_almost(PlayerModel.stroke_curve(1.0, kind), 0.0, 0.001, "back at rest")
	var jab := PlayerModel.Stroke.JAB
	assert_almost(PlayerModel.stroke_curve(0.35, jab), 1.0, 0.001, "a jab goes out")
	assert_true(PlayerModel.stroke_curve(0.1, jab) > 0.0, "a jab is never raised")
	assert_eq(ToolModels.stage_of(0.0), 0, "a bow at rest")
	assert_eq(ToolModels.stage_of(1.0), ToolModels.DRAW_STAGES - 1, "drawn to the full")


func test_a_tool_never_goes_through_the_head() -> void:
	var shoulder := Vector3(-5.0, 16.0, 0.0) * VOXEL
	var head := AABB(Vector3(-4.0, 16.0, -4.0) * VOXEL, Vector3(8.0, 8.0, 8.0) * VOXEL)
	var items: Array[int] = [
		Items.Id.DIAMOND_PICKAXE,
		Items.Id.IRON_AXE,
		Items.Id.IRON_SHOVEL,
		Items.Id.IRON_SWORD,
		Items.Id.IRON_HOE,
	]
	for item in items:
		var points := _voxels(ToolModels.held(item))
		var grip := ToolModels.grip(item)
		var sword := Items.tool_of(item) == Items.Tool.SWORD
		var holding := PlayerModel.Holding.SWORD if sword else PlayerModel.Holding.TOOL
		var kind := PlayerModel.Stroke.SLASH if sword else PlayerModel.Stroke.MINE
		var inside := 0
		for step in 41:
			var pose := PlayerModel.arm_pose(kind, holding, -1.0 + step * 0.05)
			var arm := Transform3D(Basis.from_euler(Vector3(pose.x, 0.0, pose.y)), shoulder)
			var handle := Vector3(0.0, sin(pose.z), cos(pose.z))
			var front := Vector3(0.0, -cos(pose.z), sin(pose.z))
			var tool := ItemLibrary.in_hand(handle, front, grip, ToolModels.SCALE, PlayerModel.FIST)
			var whole := arm * tool
			for point in points:
				if head.has_point(whole * point):
					inside += 1
		assert_eq(inside, 0, "%s stays out of the head" % Items.name_key(item))


## The middles of a model's voxels (mesh units, see VoxelMesher).
func _voxels(grid: VoxelGrid) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for z in grid.size.z:
		for y in grid.size.y:
			for x in grid.size.x:
				if grid.get_voxel(Vector3i(x, y, z)) != 0:
					var at := Vector3(x + 0.5 - grid.pivot.x, y + 0.5, z + 0.5 - grid.pivot.y)
					points.append(at * VOXEL)
	return points
