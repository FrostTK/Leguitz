class_name PropLibrary
extends RefCounted
## The voxel meshes of every block drawn as a 3D model (see VoxelModels),
## with their coarser copies for zoomed-out views, loaded once, and the
## material they share.

const SHADER := preload("res://src/client/shaders/voxel.gdshader")

var material := ShaderMaterial.new()

## block -> variant -> level of detail -> mesh.
var _meshes: Dictionary[int, Array] = {}


func _init() -> void:
	material.shader = SHADER
	for block in VoxelModels.modeled_blocks():
		var variants: Array[Array] = []
		for variant in VoxelModels.VARIANTS:
			var lods: Array[Mesh] = []
			for lod in VoxelModels.LODS:
				var path := VoxelModels.block_path(block, variant, lod)
				if ResourceLoader.exists(path):
					lods.append(load(path))
				elif lod > 0 and not lods.is_empty():
					lods.append(lods.back())
			if lods.is_empty():
				push_warning("Missing model %s (run tools/gen_models.gd)" % block)
			else:
				variants.append(lods)
		_meshes[block] = variants


func variant_count(block: int) -> int:
	return _meshes.get(block, []).size()


func mesh(block: int, variant: int, lod := 0) -> Mesh:
	return _meshes[block][variant][lod]
