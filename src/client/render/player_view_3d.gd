class_name PlayerView3D
extends Node3D
## The local player in the 3D world: an upright pixel-art sprite (casting a
## real shadow) standing on the terrain, with a lantern. It lives in world
## space (outside the stretched world root: lights do not support it).

const TEXTURE := preload("res://assets/textures/entities/player.png")
const NORMALS := preload("res://assets/textures/entities/player_n.png")
const SPRITE_SHADER := preload("res://src/client/shaders/sprite3d.gdshader")
const FRAMES := 4
const FRAME_PX := Vector2(16, 24)
const LANTERN_RANGE := 9.0
## Render layer of the player sprite: the lantern it carries must not
## shadow it (only the sun and the moon do).
const PLAYER_LAYER := 2

const FRAME_BY_FACING := {
	Vector2i.DOWN: 0,
	Vector2i.LEFT: 1,
	Vector2i.RIGHT: 2,
	Vector2i.UP: 3,
}

var lantern := OmniLight3D.new()
## Feet position in local units (see Render3D), smoothed on steps.
var local_position := Vector3.ZERO

var _sprite := MultiMeshInstance3D.new()


func _ready() -> void:
	var material := ShaderMaterial.new()
	material.shader = SPRITE_SHADER
	material.set_shader_parameter("atlas", TEXTURE)
	material.set_shader_parameter("atlas_normals", NORMALS)
	material.set_shader_parameter("cells", Vector2(FRAMES, 1))
	material.set_shader_parameter("sprite_px", FRAME_PX)
	material.set_shader_parameter("vertical_scale", Render3D.vertical_scale)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = QuadMesh.new()
	multimesh.instance_count = 1
	_sprite.multimesh = multimesh
	_sprite.material_override = material
	_sprite.layers = PLAYER_LAYER
	_sprite.extra_cull_margin = 4.0
	add_child(_sprite)

	lantern.light_color = Color(1.0, 0.8, 0.52)
	lantern.omni_range = LANTERN_RANGE
	lantern.omni_attenuation = 1.0
	lantern.shadow_caster_mask = ~PLAYER_LAYER & 0xFFFFF
	# Held up high enough to light the tops of nearby walls too.
	lantern.position = Vector3(0.0, 3.2, 0.0)
	lantern.light_energy = 0.0
	add_child(lantern)


## Follows the player: `world_px` is the feet position, `height` the local
## ground height, `root` the world root's transform, `yaw` the camera's.
func update_from(
	world_px: Vector2, height: float, facing: Vector2i, yaw: float, root: Transform3D, delta: float
) -> void:
	var target := Render3D.world_px_to_local(world_px, height)
	# Smooth steps and ramps a little so height changes do not pop.
	var smoothed := lerpf(local_position.y, height, 1.0 - exp(-18.0 * delta))
	if absf(smoothed - height) > Render3D.LEVEL_HEIGHT * 2.0:
		smoothed = height
	local_position = Vector3(target.x, smoothed, target.z)
	position = root * local_position
	var on_screen := Render3D.ground_to_screen(Vector2(facing), yaw)
	var screen_facing := Vector2i.DOWN if on_screen.y > 0.0 else Vector2i.UP
	if absf(on_screen.x) > absf(on_screen.y):
		screen_facing = Vector2i.RIGHT if on_screen.x > 0.0 else Vector2i.LEFT
	var frame: int = FRAME_BY_FACING.get(screen_facing, 0)
	_sprite.multimesh.set_instance_custom_data(0, Color(frame, 0, 0, 0))


func place(world_px: Vector2, height: float, root: Transform3D) -> void:
	local_position = Render3D.world_px_to_local(world_px, height)
	position = root * local_position
