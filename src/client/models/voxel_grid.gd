class_name VoxelGrid
extends RefCounted
## A small 3D grid of colored voxels: the building material of every 3D
## model (trees, plants, rocks, the player...). One voxel is one art pixel
## (1/16 of a tile), so models look like the pixel-art world around them.
##
## A voxel value packs an sRGB color (24 bits) with a kind (see Kind);
## 0 is empty. Models stand on y = 0, centered on x and z.

## PAINT and STRIPE: a boat's planks its paint covers (voxel.gdshader's
## paint_color, stripe_color).
enum Kind { SOLID, FOLIAGE, GLOW, PAINT, STRIPE }

var size := Vector3i.ONE
var voxels := PackedInt32Array()
## Bending in the wind: amplitude (0 = never moves) and the voxel height
## where bending starts (the trunk below stays put).
var sway := 0.0
var sway_from := 0
## Point (x, z, in voxels) the model stands centered on; negative = the
## middle of the grid. Coarser copies keep the original's center.
var pivot := Vector2(-1.0, -1.0)
## Corner shading on foliage. Off for tree crowns: their faces merge far
## better (a much lighter mesh) and the light painted on the leaves
## already darkens the inside.
var foliage_ao := true


func _init(grid_size := Vector3i.ONE) -> void:
	size = grid_size
	voxels.resize(size.x * size.y * size.z)


## Packs a color and a kind into a voxel value.
static func voxel(color: Color, kind := Kind.SOLID) -> int:
	return (color.to_rgba32() >> 8) | ((kind + 1) << 24)


static func color_of(value: int) -> Color:
	return Color.hex(((value & 0xFFFFFF) << 8) | 0xFF)


static func kind_of(value: int) -> int:
	return (value >> 24) - 1


func has(p: Vector3i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.z >= 0 and p.x < size.x and p.y < size.y and p.z < size.z


func get_voxel(p: Vector3i) -> int:
	if not has(p):
		return 0
	return voxels[p.x + size.x * (p.y + size.y * p.z)]


func set_voxel(p: Vector3i, value: int) -> void:
	if has(p):
		voxels[p.x + size.x * (p.y + size.y * p.z)] = value


## A coarser copy for far views: each factor x factor x factor block
## becomes one voxel of its most common color (the top one on a tie: snow
## stays on the leaves), kept when enough of the block is filled (thin
## stems and blades survive at factor 2).
func downsampled(factor: int) -> VoxelGrid:
	var out := VoxelGrid.new(
		Vector3i(
			ceili(size.x / float(factor)),
			ceili(size.y / float(factor)),
			ceili(size.z / float(factor))
		)
	)
	out.sway = sway
	out.sway_from = sway_from / factor
	out.foliage_ao = foliage_ao
	out.pivot = Vector2(size.x, size.z) * 0.5 / factor
	var needed := 2 if factor <= 2 else factor * factor * factor / 10
	for z in out.size.z:
		for y in out.size.y:
			for x in out.size.x:
				var counts := {}
				var filled := 0
				for dz in factor:
					for dy in range(factor - 1, -1, -1):
						for dx in factor:
							var value := get_voxel(
								Vector3i(x, y, z) * factor + Vector3i(dx, dy, dz)
							)
							if value != 0:
								counts[value] = counts.get(value, 0) + 1
								filled += 1
				if filled < needed:
					continue
				var best := 0
				for value: int in counts:
					if best == 0 or counts[value] > counts[best]:
						best = value
				out.set_voxel(Vector3i(x, y, z), best)
	return out


## A copy trimmed to the filled voxels (sides and top); the model keeps
## standing on the same point (the pivot follows).
func cropped() -> VoxelGrid:
	var low := size
	var high := Vector3i(-1, -1, -1)
	for z in size.z:
		for y in size.y:
			var row := size.x * (y + size.y * z)
			for x in size.x:
				if voxels[row + x] != 0:
					low = Vector3i(mini(low.x, x), mini(low.y, y), mini(low.z, z))
					high = Vector3i(maxi(high.x, x), maxi(high.y, y), maxi(high.z, z))
	if high.x < 0:
		return self
	# Models stand on y = 0: what is under them stays.
	low.y = 0
	var out := VoxelGrid.new(high - low + Vector3i.ONE)
	for z in out.size.z:
		for y in out.size.y:
			for x in out.size.x:
				out.voxels[x + out.size.x * (y + out.size.y * z)] = get_voxel(
					low + Vector3i(x, y, z)
				)
	var center := pivot if pivot.x >= 0.0 else Vector2(size.x, size.z) * 0.5
	out.pivot = center - Vector2(low.x, low.z)
	out.sway = sway
	out.sway_from = sway_from
	out.foliage_ao = foliage_ao
	return out


func is_empty() -> bool:
	for value in voxels:
		if value != 0:
			return false
	return true


## Fills a box (inclusive corners) with `paint`: a voxel value, or a
## Callable(p: Vector3i) -> int (0 leaves the voxel unchanged).
func box(from: Vector3i, to: Vector3i, paint: Variant) -> void:
	for z in range(mini(from.z, to.z), maxi(from.z, to.z) + 1):
		for y in range(mini(from.y, to.y), maxi(from.y, to.y) + 1):
			for x in range(mini(from.x, to.x), maxi(from.x, to.x) + 1):
				_paint(Vector3i(x, y, z), paint)


## Fills an ellipsoid (center and radii in voxels).
func ellipsoid(center: Vector3, radii: Vector3, paint: Variant) -> void:
	var low := Vector3i((center - radii).floor())
	var high := Vector3i((center + radii).ceil())
	for z in range(low.z, high.z + 1):
		for y in range(low.y, high.y + 1):
			for x in range(low.x, high.x + 1):
				var d := (Vector3(x, y, z) + Vector3.ONE * 0.5 - center) / radii
				if d.length_squared() <= 1.0:
					_paint(Vector3i(x, y, z), paint)


## Fills a vertical cylinder: base center (x, z), from y0 to y1 inclusive.
func cylinder(center: Vector2, radius: float, y0: int, y1: int, paint: Variant) -> void:
	for y in range(y0, y1 + 1):
		disc(center, radius, y, paint)


## Fills a horizontal disc at height y.
func disc(center: Vector2, radius: float, y: int, paint: Variant) -> void:
	for z in range(floori(center.y - radius), ceili(center.y + radius) + 1):
		for x in range(floori(center.x - radius), ceili(center.x + radius) + 1):
			var d := Vector2(x + 0.5, z + 0.5) - center
			if d.length_squared() <= radius * radius:
				_paint(Vector3i(x, y, z), paint)


## A thick line between two points (branches, stems).
func line(from: Vector3, to: Vector3, radius: float, paint: Variant) -> void:
	var steps := maxi(1, ceili(from.distance_to(to) * 2.0))
	for i in steps + 1:
		var p := from.lerp(to, float(i) / steps)
		if radius <= 0.5:
			_paint(Vector3i(p.floor()), paint)
		else:
			ellipsoid(p, Vector3.ONE * radius, paint)


func _paint(p: Vector3i, paint: Variant) -> void:
	if not has(p):
		return
	var value: int = paint.call(p) if paint is Callable else paint
	if value != 0:
		voxels[p.x + size.x * (p.y + size.y * p.z)] = value
