class_name PlayerView3D
extends Node3D
## The local player in the 3D world: an upright pixel-art sprite (casting a
## real shadow), standing on the terrain height, with a lantern.

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

var _sprite := MultiMeshInstance3D.new()
var _height := 0.0


func _ready() -> void:
	var material := ShaderMaterial.new()
	material.shader = SPRITE_SHADER
	material.set_shader_parameter("atlas", TEXTURE)
	material.set_shader_parameter("atlas_normals", NORMALS)
	material.set_shader_parameter("cells", Vector2(FRAMES, 1))
	material.set_shader_parameter("sprite_width_px", FRAME_PX.x)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = QuadMesh.new()
	multimesh.instance_count = 1
	var size := FRAME_PX / Render3D.PIXELS_PER_UNIT
	var scale := Vector3(size.x, size.y * Render3D.sprite_y_scale, 1.0)
	multimesh.set_instance_transform(
		0, Transform3D(Basis.from_scale(scale), Vector3(0, scale.y * 0.5, 0))
	)
	_sprite.multimesh = multimesh
	_sprite.material_override = material
	_sprite.layers = PLAYER_LAYER
	add_child(_sprite)

	lantern.light_color = Color(1.0, 0.8, 0.52)
	lantern.omni_range = LANTERN_RANGE
	lantern.omni_attenuation = 1.0
	lantern.shadow_caster_mask = ~PLAYER_LAYER & 0xFFFFF
	# Held up high enough to light the tops of nearby walls too.
	lantern.position = Vector3(0.0, 3.2, 0.6)
	lantern.light_energy = 0.0
	add_child(lantern)


## Follows the player: `world_px` is the feet position, `height` the ground.
func update_from(world_px: Vector2, height: float, facing: Vector2i, delta: float) -> void:
	# Smooth steps and ramps a little so height changes do not pop.
	_height = lerpf(_height, height, 1.0 - exp(-18.0 * delta))
	if absf(_height - height) > Render3D.LEVEL_HEIGHT * 2.0:
		_height = height
	position = Render3D.world_px_to_3d(world_px, _height)
	var frame: int = FRAME_BY_FACING.get(facing, 0)
	_sprite.multimesh.set_instance_custom_data(0, Color(frame, 0, 0, 0))


func place(world_px: Vector2, height: float) -> void:
	_height = height
	position = Render3D.world_px_to_3d(world_px, height)
