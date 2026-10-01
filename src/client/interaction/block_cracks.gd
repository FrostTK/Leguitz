class_name BlockCracks
extends MeshInstance3D
## Cracks spreading over a block as it is broken (local units, in the world
## root): a box a hair larger than the block, drawn by block_cracks.gdshader
## with the stage of the progress.

const SHADER := preload("res://src/client/shaders/block_cracks.gdshader")
const STAGES := 10
const BOX_SIZE := 1.006
const CRACK_COLOR := Color(0.07, 0.05, 0.05, 0.85)
const EDGE_COLOR := Color(0.32, 0.27, 0.24, 0.6)

var _material := ShaderMaterial.new()


func _ready() -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE * BOX_SIZE
	mesh = box
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material.shader = SHADER
	_material.set_shader_parameter("cracks", ImageTexture.create_from_image(crack_stages()))
	_material.set_shader_parameter("box_size", BOX_SIZE)
	material_override = _material
	visible = false


## Shows the cracks of `progress` (0..1) over the block `box` (local units).
func show_on(box: AABB, progress: float) -> void:
	position = box.get_center()
	scale = box.size
	_material.set_shader_parameter("stage", clampi(int(progress * STAGES), 0, STAGES - 1))
	visible = true


## The crack pattern, 16 x 16 art pixels per stage side by side: lines
## branching out from the middle, each stage drawing more of them.
static func crack_stages() -> Image:
	var image := Image.create(16 * STAGES, 16, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xC4AC
	# Every branch is a path of pixels; stage k shows the start of each.
	var branches: Array[PackedVector2Array] = []
	for i in 7:
		var path := PackedVector2Array()
		var at := (
			Vector2(7.5, 7.5) + Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0))
		)
		var heading := TAU * i / 7.0 + rng.randf_range(-0.4, 0.4)
		for step in 14:
			path.append(at)
			heading += rng.randf_range(-0.6, 0.6)
			at += Vector2.from_angle(heading)
		branches.append(path)
	for stage in STAGES:
		var shown := (stage + 1.0) / STAGES
		for path in branches:
			for k in ceili(path.size() * shown):
				var p := Vector2i(path[k].floor())
				if p.x < 0 or p.y < 0 or p.x > 15 or p.y > 15:
					break
				image.set_pixel(stage * 16 + p.x, p.y, CRACK_COLOR)
				# A lighter rim along the crack (chipped edge).
				var rim := p + Vector2i(1, 1)
				if (
					rim.x <= 15
					and rim.y <= 15
					and image.get_pixel(stage * 16 + rim.x, rim.y).a == 0.0
				):
					image.set_pixel(stage * 16 + rim.x, rim.y, EDGE_COLOR)
	return image
