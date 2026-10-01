class_name BlockHighlight
extends MeshInstance3D
## A thin dark frame around what the player aims at: the block, or the
## body of an object (local units, in the world root: it stretches with
## the terrain). Top-down its bars are one art pixel thick, in pixel-art
## and HD views alike; in first person (close up, in perspective) they
## are a couple of pixels of the screen (thickness_for).

const COLOR := Color(0.06, 0.05, 0.07, 0.8)
## Bar thickness top-down (local units: an art pixel).
const ART_PIXEL := 1.0 / 16.0
## In perspective: about SCREEN_PIXELS of the screen, never thinner than a
## texel of the view (nor MIN_THICKNESS), in steps of THICKNESS_STEP (the
## frame is rebuilt when it changes).
const SCREEN_PIXELS := 2.0
const MIN_THICKNESS := 1.0 / 512.0
const THICKNESS_STEP := 1.0 / 1024.0

var _box := AABB()
var _thickness := ART_PIXEL


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = COLOR
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = material
	visible = false


## How thick the bars are (local units): an art pixel for the top-down
## view; in perspective (`fov` degrees, the frame `distance` away from
## the camera, the view rendering `texels` rows for a screen `screen` rows
## tall), SCREEN_PIXELS of the screen, at least a texel, at most an art
## pixel.
static func thickness_for(
	perspective: bool, fov: float, distance: float, texels: float, screen: float
) -> float:
	if not perspective:
		return ART_PIXEL
	var texel := 2.0 * distance * tan(deg_to_rad(fov) * 0.5) / maxf(texels, 1.0)
	var pixels := maxf(SCREEN_PIXELS * texels / maxf(screen, 1.0), 1.0)
	return clampf(snappedf(texel * pixels, THICKNESS_STEP), MIN_THICKNESS, ART_PIXEL)


## Frames `box` (local units) with bars `thickness` thick, or hides the
## frame (empty box).
func outline(box: AABB, thickness := ART_PIXEL) -> void:
	if not box.has_volume():
		visible = false
		return
	visible = true
	if box == _box and thickness == _thickness:
		return
	_box = box
	_thickness = thickness
	# The bars sit just outside the box, so they show over its faces.
	var low := box.position - Vector3.ONE * thickness * 0.5
	var high := box.end + Vector3.ONE * thickness * 0.5
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in 3:
		for corner in 4:
			# The 4 edges along `axis`, at the corners of the other two.
			var a := (axis + 1) % 3
			var b := (axis + 2) % 3
			var from := low
			from[a] = high[a] if corner & 1 else low[a]
			from[b] = high[b] if corner & 2 else low[b]
			var size := Vector3.ONE * thickness
			size[axis] = high[axis] - low[axis] + thickness
			_add_bar(tool, from - Vector3.ONE * thickness * 0.5, size)
	tool.generate_normals()
	mesh = tool.commit()


static func _add_bar(tool: SurfaceTool, low: Vector3, size: Vector3) -> void:
	var c: Array[Vector3] = []
	for i in 8:
		c.append(
			(
				low
				+ Vector3(
					size.x if i & 1 else 0.0, size.y if i & 2 else 0.0, size.z if i & 4 else 0.0
				)
			)
		)
	var faces := [
		[0, 2, 3, 1], [4, 5, 7, 6], [0, 1, 5, 4], [2, 6, 7, 3], [0, 4, 6, 2], [1, 3, 7, 5]
	]
	for face: Array in faces:
		tool.add_vertex(c[face[0]])
		tool.add_vertex(c[face[1]])
		tool.add_vertex(c[face[2]])
		tool.add_vertex(c[face[0]])
		tool.add_vertex(c[face[2]])
		tool.add_vertex(c[face[3]])
