class_name VoxelMesher
extends RefCounted
## Turns a VoxelGrid into a mesh: only faces between a voxel and empty
## space, merged into large rectangles when color and shading match
## (greedy meshing), with Minecraft-style ambient occlusion in the corners.
##
## Vertex data, read by voxel.gdshader:
## - COLOR.rgb: sRGB color, COLOR.a: ambient occlusion (1 = open),
## - UV.x: how much the vertex bends in the wind, UV.y: 1 for foliage
##   (lets light through).
## Positions are in local units (1 voxel = 1/16), standing on y = 0,
## centered on x and z.

const VOXEL := 1.0 / 16.0
## Light left in a corner by 0..3 occluding neighbors.
const AO := [0.45, 0.65, 0.83, 1.0]
const AXES: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 0, 1)]


class Builder:
	extends RefCounted
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()


static func build(grid: VoxelGrid) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var arrays := build_arrays(grid)
	if not arrays.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Surface arrays of a grid ([] when it has no visible face).
static func build_arrays(grid: VoxelGrid) -> Array:
	var out := Builder.new()
	for axis in 3:
		for direction in [-1, 1]:
			_mesh_direction(grid, axis, direction, out)
	if out.vertices.is_empty():
		return []
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = out.vertices
	arrays[Mesh.ARRAY_NORMAL] = out.normals
	arrays[Mesh.ARRAY_COLOR] = out.colors
	arrays[Mesh.ARRAY_TEX_UV] = out.uvs
	arrays[Mesh.ARRAY_INDEX] = out.indices
	return arrays


## All faces looking towards `direction` along `axis`, slice by slice.
static func _mesh_direction(grid: VoxelGrid, axis: int, direction: int, out: Builder) -> void:
	var u_axis := (axis + 1) % 3
	var v_axis := (axis + 2) % 3
	var normal := Vector3i.ZERO
	normal[axis] = direction
	var e_u := AXES[u_axis]
	var e_v := AXES[v_axis]
	var width := grid.size[u_axis]
	var height := grid.size[v_axis]
	var mask := PackedInt64Array()
	mask.resize(width * height)
	for slice in grid.size[axis]:
		var any := false
		for b in height:
			for a in width:
				var p := Vector3i.ZERO
				p[axis] = slice
				p[u_axis] = a
				p[v_axis] = b
				var value := grid.get_voxel(p)
				var key := 0
				if value != 0 and grid.get_voxel(p + normal) == 0:
					key = (value << 8) | _ao_bits(grid, p + normal, e_u, e_v)
					any = true
				mask[a + b * width] = key
		if any:
			_greedy(grid, mask, width, height, axis, slice, direction, out)


## Occlusion of the 4 face corners (2 bits each), from the voxels around
## the cell in front of the face.
static func _ao_bits(grid: VoxelGrid, front: Vector3i, e_u: Vector3i, e_v: Vector3i) -> int:
	var bits := 0
	var corners := [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1)]
	for i in 4:
		var c: Vector2i = corners[i]
		var side_u := 1 if grid.get_voxel(front + e_u * c.x) != 0 else 0
		var side_v := 1 if grid.get_voxel(front + e_v * c.y) != 0 else 0
		var corner := 1 if grid.get_voxel(front + e_u * c.x + e_v * c.y) != 0 else 0
		var level := 0 if side_u + side_v == 2 else 3 - (side_u + side_v + corner)
		bits |= level << (i * 2)
	return bits


static func _greedy(
	grid: VoxelGrid,
	mask: PackedInt64Array,
	width: int,
	height: int,
	axis: int,
	slice: int,
	direction: int,
	out: Builder
) -> void:
	for b in height:
		var a := 0
		while a < width:
			var key := mask[a + b * width]
			if key == 0:
				a += 1
				continue
			var w := 1
			while a + w < width and mask[a + w + b * width] == key:
				w += 1
			var h := 1
			var grow := true
			while b + h < height and grow:
				for k in w:
					if mask[a + k + (b + h) * width] != key:
						grow = false
						break
				if grow:
					h += 1
			for dy in h:
				for k in w:
					mask[a + k + (b + dy) * width] = 0
			_emit(grid, key, axis, slice, direction, Rect2i(a, b, w, h), out)
			a += w


static func _emit(
	grid: VoxelGrid, key: int, axis: int, slice: int, direction: int, area: Rect2i, out: Builder
) -> void:
	var u_axis := (axis + 1) % 3
	var v_axis := (axis + 2) % 3
	var value := key >> 8
	var color := VoxelGrid.color_of(value)
	var foliage := 1.0 if VoxelGrid.kind_of(value) == VoxelGrid.Kind.FOLIAGE else 0.0
	var plane := slice + (1 if direction > 0 else 0)
	var corners_uv := [
		Vector2i(area.position.x, area.position.y),
		Vector2i(area.end.x, area.position.y),
		Vector2i(area.end.x, area.end.y),
		Vector2i(area.position.x, area.end.y),
	]
	var normal := Vector3.ZERO
	normal[axis] = direction
	var offset := Vector3(grid.size.x * 0.5, 0.0, grid.size.z * 0.5)
	var start := out.vertices.size()
	var ao := PackedFloat32Array()
	for i in 4:
		var c: Vector2i = corners_uv[i]
		var p := Vector3.ZERO
		p[axis] = plane
		p[u_axis] = c.x
		p[v_axis] = c.y
		out.vertices.append((p - offset) * VOXEL)
		out.normals.append(normal)
		var light: float = AO[(key >> (i * 2)) & 3]
		ao.append(light)
		out.colors.append(Color(color.r, color.g, color.b, light))
		out.uvs.append(Vector2(_sway_weight(grid, p.y), foliage))
	# Split along the diagonal that keeps the occlusion gradient smooth,
	# and wind the triangles clockwise seen from the front (Godot's front).
	var flip := ao[0] + ao[2] < ao[1] + ao[3]
	var order := [0, 1, 2, 0, 2, 3] if not flip else [1, 2, 3, 1, 3, 0]
	var v0 := out.vertices[start + order[0]]
	var v1 := out.vertices[start + order[1]]
	var v2 := out.vertices[start + order[2]]
	if (v1 - v0).cross(v2 - v0).dot(normal) > 0.0:
		order = [order[0], order[2], order[1], order[3], order[5], order[4]]
	for index: int in order:
		out.indices.append(start + index)


static func _sway_weight(grid: VoxelGrid, y: float) -> float:
	if grid.sway <= 0.0:
		return 0.0
	var span := maxf(1.0, grid.size.y - grid.sway_from)
	var t := clampf((y - grid.sway_from) / span, 0.0, 1.0)
	return grid.sway * t * t
