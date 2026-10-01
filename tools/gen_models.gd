extends SceneTree
## Builds the voxel models (VoxelModels) into meshes saved under
## assets/models/. Run after changing a model:
##
##   godot --headless --path . -s res://tools/gen_models.gd [-- --only=oak]


func _initialize() -> void:
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(VoxelModels.BLOCK_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(VoxelModels.PLAYER_DIR))
	var started := Time.get_ticks_msec()
	var triangles := 0
	for block in VoxelModels.modeled_blocks():
		var name := String(Tiles.Block.find_key(block)).to_lower()
		if not only.is_empty() and name != only:
			continue
		for variant in VoxelModels.VARIANTS:
			triangles += _save(
				VoxelModels.build(block, variant), VoxelModels.block_path(block, variant)
			)
	if only.is_empty() or only == "player":
		for part in VoxelModels.PLAYER_PARTS:
			triangles += _save(VoxelModels.build_player_part(part), VoxelModels.player_path(part))
	print(
		"Models built in %d ms, %d triangles in all" % [Time.get_ticks_msec() - started, triangles]
	)
	quit()


func _save(grid: VoxelGrid, path: String) -> int:
	var mesh := VoxelMesher.build(grid)
	var error := ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		push_error("Could not save %s: %s" % [path, error_string(error)])
	var count := 0
	if mesh.get_surface_count() > 0:
		count = mesh.surface_get_array_index_len(0) / 3
	print("%s: %d triangles" % [path.get_file(), count])
	return count
