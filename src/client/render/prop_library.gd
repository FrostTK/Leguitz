class_name PropLibrary
extends RefCounted
## The voxel meshes of every block drawn as a 3D model (see VoxelModels),
## with their coarser copies for zoomed-out views, loaded once, and the
## material they share. Small props (grass, flowers, crops...) drawn in
## their coarser copies cast no shadow while `thrifty` (casts_shadow): far
## or zoomed out, their shadows are a pixel or two, thousands of draws.

const SHADER := preload("res://src/client/shaders/voxel.gdshader")
## Props no taller than this (tiles) are small.
const SMALL_HEIGHT := 0.8
## Never cast a shadow (they lie on the water).
const NO_SHADOW := {Tiles.Block.LILY_PAD: true}

var material := ShaderMaterial.new()
## Saves on small props' shadows (off: Settings.extreme).
var thrifty := true

## block -> variant -> level of detail -> mesh.
var _meshes: Dictionary[int, Array] = {}
## block -> whether it is small (made when first asked).
var _small: Dictionary[int, bool] = {}


func _init() -> void:
	material.shader = SHADER
	for block in VoxelModels.modeled_blocks():
		var variants: Array[Array] = []
		for variant in ObjectShapes.variant_count(block):
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


## Versions of a block's model (0: it shows none).
func variant_count(block: int) -> int:
	return _meshes.get(ObjectShapes.model_block(block), []).size()


func mesh(block: int, variant: int, lod := 0) -> Mesh:
	return _meshes[ObjectShapes.model_block(block)][variant][lod]


## Whether a block's props cast a shadow at a level of detail.
func casts_shadow(block: int, lod: int) -> bool:
	if NO_SHADOW.has(block):
		return false
	return not (thrifty and lod > 0 and is_small(block))


## Whether a block's model is small (no taller than SMALL_HEIGHT).
func is_small(block: int) -> bool:
	if not _small.has(block):
		var variants: Array = _meshes.get(ObjectShapes.model_block(block), [])
		var height := 0.0
		if not variants.is_empty():
			height = (variants[0][0] as Mesh).get_aabb().size.y
		_small[block] = height <= SMALL_HEIGHT
	return _small[block]
