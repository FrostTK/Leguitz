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
## The tools' models in hand (see held_mesh).
var _held: Dictionary[int, Mesh] = {}
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


## The model held in hand: the tools, swords, bow and fishing rod
## straight (ToolModels.held, `stage`: how far a bow is drawn, whether the
## rod's bobber is out), else the item's own.
func held_mesh(item: int, stage := 0) -> Mesh:
	if not ToolModels.has(item):
		return mesh(item)
	var key := item * ToolModels.DRAW_STAGES + stage
	if not _held.has(key):
		var model := VoxelMesher.build(ToolModels.held(item, stage))
		if item == Items.Id.BOW:
			_add_lines(model, ToolModels.bow_lines(stage))
		elif item == Items.Id.FISHING_ROD:
			_add_lines(model, ToolModels.rod_lines(stage))
		for surface in model.get_surface_count():
			model.surface_set_material(surface, voxel_material)
		_held[key] = model
	return _held[key]


## Thin boxes ([from, to, half thickness across x, half thickness across
## the other way, color]) added to a model as a surface of its own, colored
## like voxels (voxel.gdshader).
static func _add_lines(model: ArrayMesh, lines: Array) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for line: Array in lines:
		var from: Vector3 = line[0]
		var to: Vector3 = line[1]
		var along := (to - from).normalized()
		var across := Vector3.RIGHT * float(line[2])
		var other := along.cross(Vector3.RIGHT).normalized() * float(line[3])
		var color: Color = line[4]
		var corners: Array[Vector3] = []
		for end: Vector3 in [from, to]:
			for side: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				corners.append(end + across * side.x + other * side.y)
		var faces := [
			[0, 1, 2, 3], [7, 6, 5, 4], [0, 4, 5, 1], [1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0]
		]
		for face: Array in faces:
			var a: Vector3 = corners[face[0]]
			var normal := (corners[face[1]] - a).cross(corners[face[2]] - a).normalized()
			# Both ways round: whichever faces out is drawn.
			for order: Array in [[0, 1, 2, 0, 2, 3], [0, 2, 1, 0, 3, 2]]:
				for i: int in order:
					tool.set_color(Color(color.r, color.g, color.b, 1.0))
					tool.set_uv(Vector2.ZERO)
					tool.set_normal(normal if order[1] == 1 else -normal)
					tool.add_vertex(corners[face[i]])
	tool.commit(model)


## Where a model sits in a hand: its y (the handle) along `handle`, its z
## (the side that strikes) towards `front`, `size` local units per unit of
## the model, its point `grip` (model units) at `fist`.
static func in_hand(
	handle: Vector3, front: Vector3, grip: Vector3, size: float, fist: Vector3
) -> Transform3D:
	var y := handle.normalized()
	var z := (front - y * front.dot(y)).normalized()
	var basis := Basis(y.cross(z), y, z).scaled(Vector3.ONE * size)
	return Transform3D(basis, fist - basis * grip)


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
	elif ShapedBlocks.item_shape(item) >= 0:
		model = _shaped(Items.placed_voxel(item))
	else:
		model = _cube(Items.placed_voxel(item))
	_meshes[item] = model
	var size := model.get_aabb().size
	_fits[item] = 1.0 / maxf(maxf(size.x, size.y), maxf(size.z, 0.001))


## A unit cube (standing on y = 0) wearing a block's textures: its top
## above and below, its face (as on the terrain's sides) around.
static func _cube(voxel: int) -> Mesh:
	var mesh := ArrayMesh.new()
	var ends := [
		[Vector3.UP, Vector3.RIGHT, Vector3.BACK],
		[Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD],
	]
	var sides := [
		[Vector3.RIGHT, Vector3.FORWARD, Vector3.UP],
		[Vector3.LEFT, Vector3.BACK, Vector3.UP],
		[Vector3.BACK, Vector3.RIGHT, Vector3.UP],
		[Vector3.FORWARD, Vector3.LEFT, Vector3.UP],
	]
	_cube_faces(mesh, ends, block_texture(voxel))
	_cube_faces(mesh, sides, face_texture(voxel))
	return mesh


## Stairs or a slab (standing on y = 0, centered) wearing their material's
## textures as on the terrain: its top above and below, its face around.
static func _shaped(voxel: int) -> Mesh:
	var mesh := ArrayMesh.new()
	var block := Voxels.block_of(voxel)
	var material := Voxels.of_block(ShapedBlocks.material_of(block))
	var mask := ShapedBlocks.mask(block, Vector3i.ZERO, Callable())
	var ends := SurfaceTool.new()
	var sides := SurfaceTool.new()
	for tool: SurfaceTool in [ends, sides]:
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for octant in 8:
		if mask & (1 << octant) == 0:
			continue
		var o := Vector3(octant & 1, (octant >> 2) & 1, (octant >> 1) & 1)
		for out: Vector3i in ShapedFaces.OUT:
			var next := Vector3i(o) + out
			var inside := next.clamp(Vector3i.ZERO, Vector3i.ONE) == next
			if inside and mask & (1 << (next.x + next.z * 2 + next.y * 4)) != 0:
				continue
			_octant_face(ends if out.y != 0 else sides, o, Vector3(out))
	_commit(mesh, ends, block_texture(material))
	_commit(mesh, sides, face_texture(material))
	return mesh


## The face of a half-cube octant `o` (0 or 1 along each axis) looking
## `out`, its texture the part of the cell's it covers.
static func _octant_face(tool: SurfaceTool, o: Vector3, out: Vector3) -> void:
	var u := Vector3(out.z, 0.0, -out.x) if out.y == 0 else Vector3.RIGHT
	var v := Vector3.DOWN if out.y == 0 else Vector3(0.0, 0.0, out.y)
	var center := (o + Vector3.ONE * 0.5 + out * 0.5) * 0.5 - Vector3(0.5, 0.0, 0.5)
	var corners := [
		center - u * 0.25 - v * 0.25,
		center + u * 0.25 - v * 0.25,
		center + u * 0.25 + v * 0.25,
		center - u * 0.25 + v * 0.25,
	]
	var uvs := []
	for corner: Vector3 in corners:
		var at := corner + Vector3(0.5, 0.0, 0.5)
		var along := at.dot(u) + (1.0 if u.dot(Vector3.ONE) < 0.0 else 0.0)
		var down := at.dot(v) + (1.0 if v.y < 0.0 else 0.0)
		uvs.append(Vector2(along, down))
	for i: int in [0, 1, 2, 0, 2, 3]:
		tool.set_normal(out)
		tool.set_uv(uvs[i])
		tool.add_vertex(corners[i])


## Adds what a SurfaceTool holds to `mesh`, wearing a texture.
static func _commit(mesh: ArrayMesh, tool: SurfaceTool, texture: Image) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(texture)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.9
	tool.set_material(material)
	tool.commit(mesh)


## Square faces of a unit cube ([normal, u, v] each) wearing a texture,
## added to `mesh` as a surface of their own.
static func _cube_faces(mesh: ArrayMesh, faces: Array, texture: Image) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
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
	material.albedo_texture = ImageTexture.create_from_image(texture)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if texture.detect_alpha() != Image.ALPHA_NONE:
		# Glass: its clear pixels are cut out.
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.9
	tool.set_material(material)
	tool.commit(mesh)


## The 16 x 16 texture of a block's sides (the terrain's face atlas).
static func face_texture(voxel: int) -> Image:
	var row := ChunkMesher.face_kind(voxel)
	return WorldView3D.FACE_ATLAS.get_image().get_region(Rect2i(0, row * 16, 16, 16))


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
