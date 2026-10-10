class_name GlassLight
extends Node3D
## Sunlight through tinted glass colors what it falls on (phase 8, step 2;
## asked by the owner): a Decal per sunlit glass cell with a tint near the
## player (the MOST nearest within REACH chunks), in the world root (local
## units). The sun's rays are taken back to local units by the root's
## inverse (the shadows fall in world space on the stretched terrain), so
## a patch lands where the light does. Each decal's box is the face of the
## glass the light comes in by (`_entry`: open, the most towards the sun)
## swept along the rays, from the far side of the cell to what they meet
## (`_landing`, LIGHT_REACH cells at most; Decals take any affine box): it
## colors what stands in that light. Its texture is the face's clear pixels
## (a window's bars stay out: their shadow is the real one), colored by the
## tint (ALBEDO_MIX, a little EMISSION); it fades with the sun (the moon
## dimmer). Placed again when the rays turn (the sun moves, the camera
## turns: TURN) or the world changes (ClientWorld.revision), at most every
## PLACE_SECONDS.

const MOST := 24
const REACH := 1
const LIGHT_REACH := 10.0
const SKY_REACH := 24.0
const STEP := 0.25
const SKY_STEP := 0.5
const TURN := 0.0005
const PLACE_SECONDS := 0.1
const ALBEDO_MIX := 0.45
const EMISSION := 0.35
## How far past the landing the box goes (it fades out there).
const OVERSHOOT := 0.6
## The sun under this (its rays' local y) lights nothing through glass.
const LOWEST := 0.08
const PANE_HALF := 1.0 / 16.0

var client_world: ClientWorld
var sun: DirectionalLight3D
var player: LocalPlayer

var _decals: Array[Decal] = []
var _tints: Array[Color] = []
var _masks: Dictionary[int, Texture2D] = {}
var _revision := -1
var _way := Vector3.ZERO
var _wait := 0.0
var _shown := 0


func _ready() -> void:
	# Pixel art: the masks' pixels stay sharp on the floor.
	RenderingServer.decals_set_filter(RenderingServer.DECAL_FILTER_NEAREST)


func _process(delta: float) -> void:
	if client_world == null or sun == null or player == null:
		return
	_wait -= delta
	var way := _light_way()
	var turned := way.dot(_way) < 1.0 - TURN
	if _wait <= 0.0 and (turned or client_world.revision != _revision):
		_wait = PLACE_SECONDS
		_way = way
		_revision = client_world.revision
		_place(way)
	var strength := clampf(sun.light_energy / LightingController.SUN_ENERGY, 0.0, 1.0)
	if not sun.visible:
		strength = 0.0
	for i in _shown:
		var decal := _decals[i]
		decal.modulate = Color(_tints[i], strength)
		decal.emission_energy = EMISSION * strength


## Which way the sun's light goes, in local units (unit length).
func _light_way() -> Vector3:
	var down := -sun.global_transform.basis.z
	var root := get_parent() as Node3D
	var local := down if root == null else root.global_transform.basis.inverse() * down
	return local.normalized()


## Places a decal at each of the nearest sunlit tinted glass cells.
func _place(way: Vector3) -> void:
	var count := 0
	if way.y < -LOWEST:
		for entry: Array in _glass_near():
			if count == MOST:
				break
			var cell: Vector3i = entry[1]
			var voxel := client_world.voxel_at(cell)
			var face := _entry(cell, voxel, way)
			if face == Vector3i.ZERO:
				continue
			var start := _face_center(cell, voxel, face)
			if not _sunlit(start + Vector3(face) * 0.01, way):
				continue
			_aim(_decal(count), cell, voxel, face, way)
			_decals[count].texture_albedo = _mask(voxel)
			_decals[count].texture_emission = _decals[count].texture_albedo
			_tints[count] = Tints.color(Tints.glass_of(entry[2]))
			count += 1
	for i in range(count, _decals.size()):
		_decals[i].visible = false
	_shown = count


## [distance², cell, packed tint] of the glass with a tinted pane around
## the player, nearest first.
func _glass_near() -> Array:
	var feet := player.position / GameConst.TILE_SIZE
	var here := Vector3(feet.x, player.height, feet.y)
	var middle := Coords.tile_to_chunk(Vector2i(floori(feet.x), floori(feet.y)))
	var found := []
	for dz in range(-REACH, REACH + 1):
		for dx in range(-REACH, REACH + 1):
			var chunk: ChunkData = client_world.chunks.get(middle + Vector2i(dx, dz))
			if chunk == null:
				continue
			for cell: Vector3i in chunk.tints:
				var packed: int = chunk.tints[cell]
				if Tints.glass_of(packed) < 0:
					continue
				var at := Vector3(cell.x + 0.5, cell.y - GameConst.SEA_LEVEL + 0.5, cell.z + 0.5)
				found.append([at.distance_squared_to(here), cell, packed])
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	return found


## The face the light comes in by: of a pane, its side towards the sun; of
## a cube, its open face the most towards it (ZERO: none).
func _entry(cell: Vector3i, voxel: int, way: Vector3) -> Vector3i:
	var block := Voxels.block_of(voxel)
	if Glass.is_pane(block):
		var sides := Glass.pane_sides(block, cell, client_world.voxel_at)
		var across_x := sides & 0b1010 != 0 and sides & 0b0101 == 0
		var across_z := sides & 0b0101 != 0 and sides & 0b1010 == 0
		var normal := Vector3i(0, 0, 1)
		if across_z or (not across_x and absf(way.x) > absf(way.z)):
			normal = Vector3i(1, 0, 0)
		return normal if Vector3(normal).dot(way) < 0.0 else -normal
	var best := Vector3i.ZERO
	var most := 0.05
	for normal: Vector3i in ShapedFaces.OUT:
		var towards := -Vector3(normal).dot(way)
		if towards <= most:
			continue
		if LightField.passing(client_world.voxel_at(cell + normal)) == LightField.OPAQUE:
			continue
		best = normal
		most = towards
	return best


## The middle of the face the light comes in by (a pane's: the cell's).
func _face_center(cell: Vector3i, voxel: int, face: Vector3i) -> Vector3:
	var center := Vector3(cell.x + 0.5, cell.y - GameConst.SEA_LEVEL + 0.5, cell.z + 0.5)
	if Glass.is_pane(Voxels.block_of(voxel)):
		return center + Vector3(face) * PANE_HALF
	return center + Vector3(face) * 0.5


## Whether the sun is seen from `point` (nothing opaque on the way to it).
func _sunlit(point: Vector3, way: Vector3) -> bool:
	var t := SKY_STEP
	while t < SKY_REACH:
		var cell := _cell_of(point - way * t)
		if cell.y >= GameConst.WORLD_HEIGHT:
			return true
		if LightField.passing(client_world.voxel_at(cell)) == LightField.OPAQUE:
			return false
		t += SKY_STEP
	return true


## How far the light goes from `point` before it meets something opaque.
func _landing(point: Vector3, way: Vector3) -> float:
	var t := STEP
	while t < LIGHT_REACH:
		var cell := _cell_of(point + way * t)
		if cell.y < 0:
			return t
		if LightField.passing(client_world.voxel_at(cell)) == LightField.OPAQUE:
			return t
		t += STEP
	return LIGHT_REACH


## Puts a decal's box on the light coming through a face: its section the
## face, its length along the rays from the far side of the glass to
## where they land.
func _aim(decal: Decal, cell: Vector3i, voxel: int, face: Vector3i, way: Vector3) -> void:
	var inside := Vector3(-face)
	var across := PANE_HALF * 2.0 if Glass.is_pane(Voxels.block_of(voxel)) else 1.0
	var past := (across + 0.02) / maxf(inside.dot(way), 0.05)
	var start := _face_center(cell, voxel, face) + way * past
	var length := _landing(start, way) + OVERSHOOT
	var u := Vector3.RIGHT
	var v := Vector3.BACK
	if face.x != 0:
		u = Vector3.BACK
		v = Vector3.DOWN
	elif face.z != 0:
		v = Vector3.DOWN
	decal.transform = Transform3D(Basis(u, -way * length, v), start + way * (length * 0.5))
	decal.visible = true


## The decal at `index` (made the first time).
func _decal(index: int) -> Decal:
	while _decals.size() <= index:
		var decal := Decal.new()
		decal.size = Vector3.ONE
		decal.albedo_mix = ALBEDO_MIX
		decal.normal_fade = 0.2
		decal.lower_fade = 0.05
		decal.upper_fade = 0.0
		decal.cull_mask = 1
		add_child(decal)
		_decals.append(decal)
		_tints.append(Color.WHITE)
	return _decals[index]


## A glass's clear pixels, white (its frame, bars and lead: none); a cube
## or a pane's border lets the light through (glass goes on).
func _mask(voxel: int) -> Texture2D:
	var block := Voxels.block_of(voxel)
	var art_voxel := voxel
	if Glass.is_pane(block):
		art_voxel = Voxels.of_block(Glass.pane_glass(block))
	var kind := ChunkMesher.face_kind(art_voxel)
	if _masks.has(kind):
		return _masks[kind]
	var art := WorldView3D.FACE_ATLAS.get_image().get_region(Rect2i(0, kind * 16, 16, 16))
	var framed := Glass.is_window(block)
	var mask := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var border := not framed and (x == 0 or y == 0 or x == 15 or y == 15)
			var clear := art.get_pixel(x, y).a < 0.5 or border
			mask.set_pixel(x, y, Color(1, 1, 1, 1.0 if clear else 0.0))
	_masks[kind] = ImageTexture.create_from_image(mask)
	return _masks[kind]


static func _cell_of(point: Vector3) -> Vector3i:
	return Vector3i(floori(point.x), floori(point.y) + GameConst.SEA_LEVEL, floori(point.z))
