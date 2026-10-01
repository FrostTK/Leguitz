class_name ItemLibrary
extends RefCounted
## How every item looks: its 3D model (lying in the world, in hand, in its
## icon) and its icon (rendered off screen by ItemIcons). Block items are
## cubes wearing their block's texture; the others are voxel models
## (ItemModels).

const VOXEL_SHADER := preload("res://src/client/shaders/voxel.gdshader")

## For the voxel models (no per-instance tint, no see-through hole).
var voxel_material := ShaderMaterial.new()

var _meshes: Dictionary[int, Mesh] = {}
## Per item: the factor bringing its model to a 1-unit box.
var _fits: Dictionary[int, float] = {}
var _icons: Dictionary[int, Texture2D] = {}


func _init() -> void:
	voxel_material.shader = VOXEL_SHADER
	voxel_material.set_shader_parameter("use_instance_data", false)
	voxel_material.set_shader_parameter("cut_out", false)


## The item's model, standing on its base, centered (local units).
func mesh(item: int) -> Mesh:
	if not _meshes.has(item):
		_build(item)
	return _meshes[item]


## Scale bringing the item's model to fill a 1-unit box.
func fit(item: int) -> float:
	if not _fits.has(item):
		_build(item)
	return _fits[item]


## The item's icon (null until ItemIcons rendered it).
func icon(item: int) -> Texture2D:
	return _icons.get(item)


func set_icon(item: int, texture: Texture2D) -> void:
	_icons[item] = texture


func _build(item: int) -> void:
	var grid := ItemModels.build(item)
	var model: Mesh
	if grid != null:
		model = VoxelMesher.build(grid)
		model.surface_set_material(0, voxel_material)
	else:
		model = _cube(Items.placed_voxel(item))
	_meshes[item] = model
	var size := model.get_aabb().size
	_fits[item] = 1.0 / maxf(maxf(size.x, size.y), maxf(size.z, 0.001))


## A unit cube (standing on y = 0) wearing a block's top texture on every
## side.
static func _cube(voxel: int) -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := [
		[Vector3.UP, Vector3.RIGHT, Vector3.BACK],
		[Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD],
		[Vector3.RIGHT, Vector3.FORWARD, Vector3.UP],
		[Vector3.LEFT, Vector3.BACK, Vector3.UP],
		[Vector3.BACK, Vector3.RIGHT, Vector3.UP],
		[Vector3.FORWARD, Vector3.LEFT, Vector3.UP],
	]
	for face: Array in faces:
		var normal: Vector3 = face[0]
		var u: Vector3 = face[1]
		var v: Vector3 = face[2]
		var center := normal * 0.5 + Vector3(0.0, 0.5, 0.0)
		var corners := [
			center - u * 0.5 + v * 0.5,
			center + u * 0.5 + v * 0.5,
			center + u * 0.5 - v * 0.5,
			center - u * 0.5 - v * 0.5,
		]
		var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for i: int in [0, 1, 2, 0, 2, 3]:
			tool.set_normal(normal)
			tool.set_uv(uvs[i])
			tool.add_vertex(corners[i])
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(block_texture(voxel))
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.9
	tool.set_material(material)
	return tool.commit()


## The 16 x 16 top texture of a block (from the terrain atlases).
static func block_texture(voxel: int) -> Image:
	var block := Voxels.block_of(voxel)
	var atlas: Image
	var row: int
	if block != Tiles.Block.AIR and TileAtlas.is_wall(block):
		atlas = TerrainRenderer.WALL_ATLAS.get_image()
		row = TileAtlas.WALL_KINDS[block]
	else:
		atlas = TerrainRenderer.GROUND_ATLAS.get_image()
		row = Voxels.ground_of(voxel)
	return atlas.get_region(Rect2i(0, row * 16, 16, 16))
