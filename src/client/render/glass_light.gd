class_name GlassLight
extends Node3D
## Sunlight through tinted glass colors what it falls on (phase 8, step 2;
## made natural at the owner's request): tinted glass keeps the sun's white
## light out (GlassFaces.TINTED_SHADOW) and the shaders bring it in through
## the glass, in its color (glass_light.gdshaderinc), looking towards the
## sun cell by cell: the patches fall exactly where the light goes, follow
## the sun smoothly, keep the texture of what they light and the shadows of
## a window's bars and the lead. This node (in the world root) keeps the
## shaders' globals: the cells around the tinted glass near the player
## (`glass_cells`, a 3D texture, each cell's code from `cell_code` and
## `pane_info`; the tinted glass within REACH chunks, AROUND cells around it
## and ABOVE over it, at most MOST across), made again when the tints there
## change or a voxel or a chunk in it does (ClientWorld.take_changes), and
## every frame the sun: its way in local units (through the root's inverse,
## so the light lands where the shadows do), its color and energy.

const REACH := 1
const AROUND := 10
const ABOVE := 3
const MOST := 64
## How often (seconds) the world's changes are looked at.
const CHECK_SECONDS := 0.2
## A cell's code: nothing in the way, or opaque (else: the face kind of
## the glass art, see cell_code).
const CLEAR := 0
const OPAQUE := 255
## Light through stained glass: raised towards this brightness, at most
## VIVID times (palette).
const LIGHT_LUMA := 0.6
const VIVID := 3.0
const HEIGHT := GameConst.WORLD_HEIGHT
const SEA := GameConst.SEA_LEVEL

var client_world: ClientWorld
var sun: DirectionalLight3D
var player: LocalPlayer

var _revision := -1
var _wait := 0.0
var _signature := 0
var _on := false
## The cells the texture covers (lowest corner, highest corner).
var _low := Vector3i.ZERO
var _high := Vector3i(-1, -1, -1)
var _codes := PackedByteArray()


func _ready() -> void:
	RenderingServer.global_shader_parameter_set("glass_art", WorldView3D.FACE_ATLAS)
	RenderingServer.global_shader_parameter_set("glass_palette", palette())
	RenderingServer.global_shader_parameter_set("glass_light_on", 0.0)


func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set("glass_light_on", 0.0)


func _process(delta: float) -> void:
	if client_world == null or sun == null or player == null:
		return
	_wait -= delta
	if _wait <= 0.0 and client_world.revision != _revision:
		_wait = CHECK_SECONDS
		_revision = client_world.revision
		_check()
	var on := _on and sun.visible and sun.light_energy > 0.001
	RenderingServer.global_shader_parameter_set("glass_light_on", 1.0 if on else 0.0)
	if not on:
		return
	# Towards the sun (a light shines along its -z), in the world and in
	# local units.
	var to_sun := sun.global_transform.basis.z.normalized()
	var root := get_parent() as Node3D
	var local := to_sun if root == null else root.global_transform.basis.inverse() * to_sun
	var color := sun.light_color.srgb_to_linear() * sun.light_energy
	RenderingServer.global_shader_parameter_set("glass_to_sun", local)
	RenderingServer.global_shader_parameter_set("glass_sun_world", to_sun)
	RenderingServer.global_shader_parameter_set(
		"glass_sun_color", Vector3(color.r, color.g, color.b)
	)


## The light through each color of the palette (Tints.COLORS) as the
## shaders read it (16 x 1, linear): stained glass lets its color through
## brightly (raised towards LIGHT_LUMA, at most VIVID times), dark glass
## stays dark.
static func palette() -> ImageTexture:
	var image := Image.create_empty(Tints.COLORS.size(), 1, false, Image.FORMAT_RGBAF)
	for i in Tints.COLORS.size():
		image.set_pixel(i, 0, light_through(i))
	return ImageTexture.create_from_image(image)


## The light (linear) that comes through glass of a palette color.
static func light_through(index: int) -> Color:
	var color := Tints.color(index).srgb_to_linear()
	var luma := color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
	var raise := clampf(LIGHT_LUMA / maxf(luma, 0.001), 1.0, VIVID)
	return Color(minf(color.r * raise, 1.0), minf(color.g * raise, 1.0), minf(color.b * raise, 1.0))


## A voxel's code: glass the face kind of its art (a pane: its glass's),
## what stops the daylight OPAQUE (LightField), else CLEAR.
static func cell_code(voxel: int) -> int:
	if voxel == Voxels.UNKNOWN:
		return CLEAR
	var block := Voxels.block_of(voxel)
	if Glass.is_glass(block):
		var art := Glass.pane_glass(block) if Glass.is_pane(block) else block
		return ChunkMesher.face_kind(Voxels.of_block(art))
	return OPAQUE if LightField.passing(voxel) == LightField.OPAQUE else CLEAR


## A glass cell's shape for the shaders: a pane's plane (1 across z: it
## runs east to west; 2 across x), + 4 a window (framed: its border stops
## the light).
static func pane_info(block: int, sides: int) -> int:
	var info := 4 if Glass.is_window(block) else 0
	if Glass.is_pane(block):
		info += 1 if sides & 0b1010 != 0 else 2
	return info


## Looks at what changed: the tinted glass near the player, the cells and
## chunks under the texture; makes it again if needed.
func _check() -> void:
	var tinted := _tinted_near()
	var signature := hash(tinted)
	var changes := client_world.take_changes()
	var again: bool = signature != _signature or changes["all"]
	for cell: Vector3i in changes["cells"]:
		again = again or _covers(cell)
	for coord: Vector2i in changes["coords"]:
		var origin := Coords.chunk_origin_tile(coord)
		var corner := Vector3i(origin.x, _low.y, origin.y)
		var size := GameConst.CHUNK_SIZE - 1
		again = (
			again
			or (
				corner.x <= _high.x
				and corner.x + size >= _low.x
				and corner.z <= _high.z
				and corner.z + size >= _low.z
			)
		)
	_signature = signature
	if not again:
		return
	_on = not tinted.is_empty()
	if _on:
		_build(tinted.keys())


## The cells of tinted glass within REACH chunks of the player: cell ->
## packed tint.
func _tinted_near() -> Dictionary:
	var feet := Coords.world_to_tile(player.position)
	var middle := Coords.tile_to_chunk(feet)
	var found := {}
	for dz in range(-REACH, REACH + 1):
		for dx in range(-REACH, REACH + 1):
			var chunk: ChunkData = client_world.chunks.get(middle + Vector2i(dx, dz))
			if chunk == null:
				continue
			for cell: Vector3i in chunk.tints:
				var packed: int = chunk.tints[cell]
				if Tints.glass_of(packed) >= 0 and Glass.is_glass(Voxels.block_of(_voxel(cell))):
					found[cell] = packed
	return found


func _covers(cell: Vector3i) -> bool:
	return (
		cell.x >= _low.x
		and cell.y >= _low.y
		and cell.z >= _low.z
		and cell.x <= _high.x
		and cell.y <= _high.y
		and cell.z <= _high.z
	)


func _voxel(cell: Vector3i) -> int:
	return client_world.voxel_at(cell)


## Makes the texture of the cells around the tinted glass `cells`.
func _build(cells: Array) -> void:
	if _codes.is_empty():
		_codes.resize(Voxels.used_ids())
		for voxel in _codes.size():
			_codes[voxel] = cell_code(voxel)
	var box_low: Vector3i = cells[0]
	var box_high: Vector3i = cells[0]
	for cell: Vector3i in cells:
		box_low = box_low.min(cell)
		box_high = box_high.max(cell)
	var low := box_low - Vector3i(AROUND, AROUND, AROUND)
	var high := box_high + Vector3i(AROUND, ABOVE, AROUND)
	low.y = maxi(low.y, 0)
	high.y = mini(high.y, HEIGHT - 1)
	for axis in 3:
		if high[axis] - low[axis] + 1 > MOST:
			low[axis] = (box_low[axis] + box_high[axis]) / 2 - MOST / 2
			high[axis] = low[axis] + MOST - 1
	_low = low
	_high = high
	var size := high - low + Vector3i.ONE
	var slices: Array[Image] = []
	for z in size.z:
		slices.append(_slice(low, size, z))
	var texture := ImageTexture3D.new()
	texture.create(Image.FORMAT_RGBA8, size.x, size.y, size.z, false, slices)
	var origin := Vector3(low.x, low.y - SEA, low.z)
	var box_from := Vector3(box_low.x, box_low.y - SEA, box_low.z)
	var box_to := Vector3(box_high.x + 1, box_high.y + 1 - SEA, box_high.z + 1)
	RenderingServer.global_shader_parameter_set("glass_cells", texture)
	RenderingServer.global_shader_parameter_set("glass_origin", origin)
	RenderingServer.global_shader_parameter_set("glass_size", Vector3(size))
	RenderingServer.global_shader_parameter_set("glass_box_min", box_from)
	RenderingServer.global_shader_parameter_set("glass_box_max", box_to)


## One slice (a row of tiles, `z` from the lowest corner) of the texture:
## x across, rows up.
func _slice(low: Vector3i, size: Vector3i, z: int) -> Image:
	var data := PackedByteArray()
	data.resize(size.x * size.y * 4)
	for x in size.x:
		var tile := Vector2i(low.x + x, low.z + z)
		var chunk := client_world.chunk_at(tile)
		if chunk == null:
			continue
		var local := Coords.tile_to_local(tile)
		var base := ChunkData.voxel_index(local.x, 0, local.y)
		for y in size.y:
			var voxel := chunk.voxels[base + low.y + y]
			var code := _codes[voxel] if voxel < _codes.size() else CLEAR
			if code == CLEAR:
				continue
			var at := (y * size.x + x) * 4
			data[at] = code
			data[at + 3] = 255
			if code == OPAQUE:
				continue
			var cell := Vector3i(tile.x, low.y + y, tile.y)
			var block := Voxels.block_of(voxel)
			data[at + 1] = Tints.glass_of(chunk.tints.get(cell, 0)) + 1
			var sides := Glass.pane_sides(block, cell, _voxel) if Glass.is_pane(block) else 0
			data[at + 2] = pane_info(block, sides)
	return Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBA8, data)
