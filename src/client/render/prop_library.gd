class_name PropLibrary
extends RefCounted
## The voxel meshes of every block drawn as a 3D model (see VoxelModels),
## loaded once, and the material they share.

const SHADER := preload("res://src/client/shaders/voxel.gdshader")

var material := ShaderMaterial.new()

var _meshes: Dictionary[int, Array] = {}


func _init() -> void:
	material.shader = SHADER
	for block in VoxelModels.modeled_blocks():
		var variants: Array[Mesh] = []
		for variant in VoxelModels.VARIANTS:
			var path := VoxelModels.block_path(block, variant)
			if ResourceLoader.exists(path):
				variants.append(load(path))
			else:
				push_warning("Missing model %s (run tools/gen_models.gd)" % path)
		_meshes[block] = variants


func variant_count(block: int) -> int:
	return _meshes.get(block, []).size()


func mesh(block: int, variant: int) -> Mesh:
	return _meshes[block][variant]
