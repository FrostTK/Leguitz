class_name LiveProps
extends Node3D
## The props the client brings to life (Decor.LIVE, near the player:
## WorldView3D gathers their cells from the chunk views): the hands of the
## clocks telling the game's time and a grandfather clock's pendulum, the
## map of the surroundings in a frame (drawn from the chunks the client
## has, north up, now and then again), the water of a running shower. In
## the world root, in local units (models' voxels: WallDecorModels,
## AmbianceModels); the shower's drops in world space, as the chimneys'
## smoke (outside the root's stretch).

## A map's pixel covers so many tiles; it is drawn again this often.
const MAP_STEP := 4
const MAP_SECONDS := 8.0
const PARCHMENT := Color("d9c79a")
const MAP_INK := Color("8a2a24")
const HANDS := Color("1e1c20")
const BRASS := Color("c9a24a")
## Shower drops: how often one falls, how fast (local units a second), at
## most so many.
const DROP_EVERY := 0.035
const DROP_SPEED := 3.2
const MOST_DROPS := 300
const WATER := Color("a8d4ec")

var clock: WorldClock

## cell -> [block, holder, hour hand, minute hand, pendulum or map, when
## its map was drawn or its shower's next drop].
var _shown: Dictionary[Vector3i, Array] = {}
var _drops: Array[Array] = []
var _drop_mesh := BoxMesh.new()
var _hands := StandardMaterial3D.new()
var _brass := StandardMaterial3D.new()
var _time := 0.0
var _delta := 0.0


func _ready() -> void:
	_hands.albedo_color = HANDS
	_brass.albedo_color = BRASS
	_brass.metallic = 0.6
	_drop_mesh.size = Vector3(0.05, 0.12, 0.05)
	var water := StandardMaterial3D.new()
	water.albedo_color = WATER
	water.roughness = 0.2
	_drop_mesh.material = water


## Shows the live props in `cells` (world cells), forgets the others,
## moves the hands, falls the drops.
func update(delta: float, cells: Array[Vector3i], world: ClientWorld) -> void:
	_time += delta
	_delta = delta
	var seen := {}
	for cell in cells:
		var block := Voxels.block_of(world.voxel_at(cell))
		if not Decor.is_live(block):
			continue
		seen[cell] = true
		var shown: Array = _shown.get(cell, [])
		if shown.is_empty() or shown[0] != block:
			_forget(cell)
			shown = _show(cell, block, world)
		_animate(cell, shown, world)
	for cell: Vector3i in _shown.keys():
		if not seen.has(cell):
			_forget(cell)
	_fall(delta)


func _show(cell: Vector3i, block: int, world: ClientWorld) -> Array:
	var holder := Node3D.new()
	holder.position = Vector3(cell.x + 0.5, cell.y - GameConst.SEA_LEVEL, cell.z + 0.5)
	holder.rotation.y = ObjectShapes.turn_of(block)
	add_child(holder)
	var shown: Array = [block, holder, null, null, null, -INF]
	var kind := ObjectShapes.base_kind(block)
	if kind == Tiles.Block.WALL_CLOCK or kind == Tiles.Block.GRANDFATHER_CLOCK:
		var face: Vector3 = (
			WallDecorModels.CLOCK_FACE
			if kind == Tiles.Block.WALL_CLOCK
			else AmbianceModels.TALL_CLOCK_FACE
		)
		var long := 5.0 if kind == Tiles.Block.WALL_CLOCK else 4.0
		shown[2] = _hand(holder, face, long * 0.6, 1.0)
		shown[3] = _hand(holder, face + Vector3(0.0, 0.0, 0.3), long, 0.7)
		if kind == Tiles.Block.GRANDFATHER_CLOCK:
			shown[4] = _pendulum(holder)
	elif kind == Tiles.Block.FRAMED_MAP:
		shown[4] = _map_quad(holder)
		_draw_map(cell, shown[4], world)
		shown[5] = _time
	elif kind == Tiles.Block.SHOWER_ON:
		shown[5] = 0.0
	_shown[cell] = shown
	return shown


func _forget(cell: Vector3i) -> void:
	if _shown.has(cell):
		(_shown[cell][1] as Node3D).queue_free()
		_shown.erase(cell)


func _animate(cell: Vector3i, shown: Array, world: ClientWorld) -> void:
	var kind := ObjectShapes.base_kind(shown[0])
	if shown[2] != null and clock != null:
		var hours := clock.time_of_day() / 3600.0
		(shown[2] as Node3D).rotation.z = -fmod(hours, 12.0) / 12.0 * TAU
		(shown[3] as Node3D).rotation.z = -fmod(hours, 1.0) * TAU
	if kind == Tiles.Block.GRANDFATHER_CLOCK and shown[4] != null:
		(shown[4] as Node3D).rotation.z = sin(_time * PI) * 0.22
	elif kind == Tiles.Block.FRAMED_MAP and _time - shown[5] > MAP_SECONDS:
		_draw_map(cell, shown[4], world)
		shown[5] = _time
	elif kind == Tiles.Block.SHOWER_ON:
		shown[5] += _delta
		while shown[5] > DROP_EVERY:
			shown[5] -= DROP_EVERY
			_drop(shown[1], cell)


## A clock's hand (pivot at `face`, model voxels), `long` voxels.
func _hand(holder: Node3D, face: Vector3, long: float, wide: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = _local(face)
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(wide, long, 0.3) / 16.0
	mesh.material = _hands
	box.mesh = mesh
	box.position = Vector3(0.0, long * 0.5 / 16.0, 0.0)
	box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(box)
	holder.add_child(pivot)
	return pivot


## A grandfather clock's pendulum: a rod and its brass bob.
func _pendulum(holder: Node3D) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = _local(AmbianceModels.PENDULUM)
	var rod := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.5, 8.0, 0.5) / 16.0
	mesh.material = _brass
	rod.mesh = mesh
	rod.position = Vector3(0.0, -4.0 / 16.0, 0.0)
	var bob := MeshInstance3D.new()
	var disc := BoxMesh.new()
	disc.size = Vector3(2.5, 2.5, 0.6) / 16.0
	disc.material = _brass
	bob.mesh = disc
	bob.position = Vector3(0.0, -8.5 / 16.0, 0.0)
	for part: MeshInstance3D in [rod, bob]:
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(part)
	holder.add_child(pivot)
	return pivot


## The quad a framed map is drawn on, over its canvas.
func _map_quad(holder: Node3D) -> MeshInstance3D:
	var canvas: Rect2i = WallDecorModels.MAP_CANVAS
	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(canvas.size) / 16.0
	var material := StandardMaterial3D.new()
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 1.0
	mesh.material = material
	quad.mesh = mesh
	var middle := Vector2(canvas.position) + Vector2(canvas.size) * 0.5
	quad.position = _local(Vector3(middle.x, middle.y, WallDecorModels.MAP_DEPTH + 0.05))
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(quad)
	return quad


## The surroundings of the map in `cell` (the client's chunks, north up,
## hills shaded, where it hangs marked), on its quad.
func _draw_map(cell: Vector3i, quad: MeshInstance3D, world: ClientWorld) -> void:
	var size: Vector2i = WallDecorModels.MAP_CANVAS.size
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGB8)
	var heights := {}
	for py in size.y:
		for px in size.x:
			var tile := Vector2i(
				cell.x + (px - size.x / 2) * MAP_STEP, cell.z + (py - size.y / 2) * MAP_STEP
			)
			var chunk := world.chunk_at(tile)
			if chunk == null:
				image.set_pixel(px, py, PARCHMENT.darkened(0.08))
				continue
			var local := Coords.tile_to_local(tile)
			var row := chunk.top_row(local)
			heights[Vector2i(px, py)] = row
			var top := chunk.get_voxel(Vector3i(local.x, maxi(row - 1, 0), local.y))
			var color := BlockColors.of(top)
			if Voxels.is_water(top):
				color = Color("4a7fb8")
			var west: int = heights.get(Vector2i(px - 1, py), row)
			var north: int = heights.get(Vector2i(px, py - 1), row)
			var slope := (row - west) + (row - north)
			color = color.lightened(0.12) if slope > 0 else color
			color = color.darkened(0.15) if slope < 0 else color
			image.set_pixel(px, py, color.lerp(PARCHMENT, 0.35))
	image.set_pixel(size.x / 2, size.y / 2, MAP_INK)
	var material := (quad.mesh as QuadMesh).material as StandardMaterial3D
	material.albedo_texture = ImageTexture.create_from_image(image)


## A drop falls from a running shower's head (in world space).
func _drop(holder: Node3D, cell: Vector3i) -> void:
	if _drops.size() >= MOST_DROPS:
		return
	var head := holder.transform * _local(AmbianceModels.SHOWER_HEAD)
	head += Vector3(randf_range(-0.08, 0.08), 0.0, randf_range(-0.08, 0.08))
	var drop := MeshInstance3D.new()
	drop.mesh = _drop_mesh
	drop.top_level = true
	drop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(drop)
	_drops.append([drop, head, float(cell.y - GameConst.SEA_LEVEL) + 0.1])


func _fall(delta: float) -> void:
	for i in range(_drops.size() - 1, -1, -1):
		var drop: Array = _drops[i]
		var at: Vector3 = drop[1]
		at.y -= DROP_SPEED * delta
		if at.y <= drop[2]:
			(drop[0] as Node3D).queue_free()
			_drops.remove_at(i)
			continue
		drop[1] = at
		(drop[0] as Node3D).global_position = global_transform * at


## A point of a model (voxels, front +z, centered on its tile) in its
## holder's units.
static func _local(voxel: Vector3) -> Vector3:
	return Vector3((voxel.x - 8.0) / 16.0, voxel.y / 16.0, (voxel.z - 8.0) / 16.0)
