class_name WeatherEffects
extends Node3D
## Client-side weather and ambience in the 3D world: rain or snow
## (depending on the biome under the player), lightning, wet ground,
## falling leaves, fireflies at night and dust motes in caves.
## Particles run on the GPU around the camera target, in world space (rain
## and snow move along with the player: nobody notices, and they stay
## put when the camera turns).

const RAIN_BY_KIND := {Weather.Kind.CLEAR: 0.0, Weather.Kind.RAIN: 0.8, Weather.Kind.THUNDER: 1.0}
const FADE_PER_SECOND := 0.12
const WETTING_PER_SECOND := 0.06
const DRYING_PER_SECOND := 0.012
## Particles live in a slab this many units above and below the target.
const SLAB_HALF_HEIGHT := 12.0
const RAIN_SPEED := 30.0

## Biomes where it never rains (like Minecraft's deserts and savannas).
const DRY_BIOMES := {
	Biomes.Id.DESERT: true,
	Biomes.Id.BADLANDS: true,
	Biomes.Id.SAVANNA: true,
	Biomes.Id.SAVANNA_PLATEAU: true,
}
const LEAFY_BIOMES := {
	Biomes.Id.FOREST: true,
	Biomes.Id.FLOWER_FOREST: true,
	Biomes.Id.BIRCH_FOREST: true,
	Biomes.Id.DARK_FOREST: true,
	Biomes.Id.JUNGLE: true,
	Biomes.Id.SPARSE_JUNGLE: true,
	Biomes.Id.SWAMP: true,
}
const FIREFLY_BIOMES := {
	Biomes.Id.PLAINS: true,
	Biomes.Id.FOREST: true,
	Biomes.Id.FLOWER_FOREST: true,
	Biomes.Id.BIRCH_FOREST: true,
	Biomes.Id.DARK_FOREST: true,
	Biomes.Id.MEADOW: true,
	Biomes.Id.SWAMP: true,
	Biomes.Id.JUNGLE: true,
	Biomes.Id.SPARSE_JUNGLE: true,
	Biomes.Id.TAIGA: true,
	Biomes.Id.RIVER: true,
}
const AMOUNTS := {&"rain": 2000, &"snow": 1100, &"leaves": 24, &"fireflies": 60, &"dust": 90}

var weather := Weather.new()
var client_world: ClientWorld
var local_player: LocalPlayer
## The point the camera looks at (world space), and the visible size
## (units) around it.
var target := Vector3.ZERO
var view_size := Vector2(30.0, 17.0)

## Smoothed 0..1 values read by the lighting and the shaders.
var rain_intensity := 0.0
var wetness := 0.0
var snowing := false
var darkness := 0.0
var particle_scale := 1.0

var _particles: Dictionary[StringName, GPUParticles3D] = {}
## The first state (on joining) applies at once, later changes fade in.
var _has_state := false
var _snap_state := false
var _flash := 0.0
var _flash_timer := 8.0
var _second_flash := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_particles[&"rain"] = _make_rain()
	_particles[&"snow"] = _make_snow()
	_particles[&"leaves"] = _make_leaves()
	_particles[&"fireflies"] = _make_fireflies()
	_particles[&"dust"] = _make_dust()
	for particles: GPUParticles3D in _particles.values():
		add_child(particles)
	set_particle_scale(particle_scale)


func set_particle_scale(scale: float) -> void:
	particle_scale = scale
	for key: StringName in _particles:
		_particles[key].amount = maxi(1, int(AMOUNTS[key] * scale))


func apply_state(data: Dictionary) -> void:
	weather.load_dict(data)
	if not _has_state:
		_has_state = true
		_snap_state = true


## Current lightning flash brightness (added to the ambient light).
func flash() -> float:
	return _flash


func _process(delta: float) -> void:
	if client_world == null or local_player == null:
		return
	var underground := client_world.layer < WorldGenerator.SURFACE_LAYER
	var biome := client_world.biome_at(local_player.current_tile())
	var goal: float = RAIN_BY_KIND.get(weather.kind, 0.0)
	if underground or DRY_BIOMES.has(biome):
		goal = 0.0
	rain_intensity = move_toward(rain_intensity, goal, FADE_PER_SECOND * delta)
	snowing = Biomes.is_cold(biome)
	if rain_intensity > 0.2 and not snowing:
		wetness = move_toward(wetness, 1.0, WETTING_PER_SECOND * delta)
	else:
		wetness = move_toward(wetness, 0.0, DRYING_PER_SECOND * delta)
	if _snap_state:
		_snap_state = false
		rain_intensity = goal
		wetness = 1.0 if rain_intensity > 0.2 and not snowing else 0.0
	if underground:
		wetness = 0.0
	_update_lightning(delta, underground)

	var wind := weather.wind_vector()
	RenderingServer.global_shader_parameter_set(&"weather_wind", wind)
	RenderingServer.global_shader_parameter_set(&"weather_wetness", wetness)
	RenderingServer.global_shader_parameter_set(&"weather_rain", rain_intensity)

	for particles: GPUParticles3D in _particles.values():
		_place(particles)
	var rain := _particles[&"rain"]
	rain.amount_ratio = 0.0 if snowing else rain_intensity
	(rain.process_material as ParticleProcessMaterial).direction = Vector3(
		wind.x * 0.25, -1.0, wind.y * 0.25
	)
	_particles[&"snow"].amount_ratio = rain_intensity if snowing else 0.0
	var leafy := not underground and LEAFY_BIOMES.has(biome)
	_particles[&"leaves"].amount_ratio = minf(0.4 + wind.length(), 1.0) if leafy else 0.0
	var fireflies := not underground and FIREFLY_BIOMES.has(biome)
	_particles[&"fireflies"].amount_ratio = (
		darkness * (1.0 - rain_intensity) if fireflies else 0.0
	)
	_particles[&"dust"].amount_ratio = 1.0 if underground else 0.0


func _update_lightning(delta: float, underground: bool) -> void:
	_flash = move_toward(_flash, 0.0, delta * 6.0)
	if _second_flash > 0.0:
		_second_flash -= delta
		if _second_flash <= 0.0:
			_flash = 0.8
	if weather.kind != Weather.Kind.THUNDER or underground:
		return
	_flash_timer -= delta
	if _flash_timer <= 0.0:
		_flash = 1.2
		_second_flash = 0.18
		_flash_timer = _rng.randf_range(5.0, 18.0)


## Keeps an emitter around the visible area. Seen from the tilted camera,
## a particle higher up shows further away, and the camera can turn: the
## box covers the view in every direction.
func _place(particles: GPUParticles3D) -> void:
	particles.global_position = target
	var depth := view_size.y * Render3D.depth_stretch
	var reach := maxf(view_size.x * 0.5 + 1.0, depth * 0.5 + SLAB_HALF_HEIGHT * 0.6)
	var material := particles.process_material as ParticleProcessMaterial
	material.emission_box_extents = Vector3(reach, SLAB_HALF_HEIGHT, reach)


static func _base(
	amount: int, lifetime: float, mesh_material: StandardMaterial3D
) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.local_coords = false
	particles.preprocess = lifetime
	particles.amount_ratio = 0.0
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb = AABB(Vector3(-80, -40, -80), Vector3(160, 80, 160))
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.gravity = Vector3.ZERO
	particles.process_material = material
	var quad := QuadMesh.new()
	quad.material = mesh_material
	particles.draw_pass_1 = quad
	return particles


## Material for particle quads; billboards face the camera.
static func _particle_material(color: Color, billboard: bool, lit: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.1
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if not lit:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if billboard:
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	return material


## Size of a particle quad showing `pixels` art pixels on screen.
static func _pixel_size(pixels: Vector2, billboard: bool) -> Vector2:
	var size := pixels / Render3D.PIXELS_PER_UNIT
	if not billboard:
		size.y *= Render3D.vertical_scale
	return size


func _make_rain() -> GPUParticles3D:
	var material := _particle_material(Color(0.75, 0.85, 1.0, 0.6), false, false)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	var particles := _base(2000, SLAB_HALF_HEIGHT * 2.0 / RAIN_SPEED, material)
	particles.local_coords = true
	(particles.draw_pass_1 as QuadMesh).size = _pixel_size(Vector2(1, 6), false)
	var process := particles.process_material as ParticleProcessMaterial
	process.direction = Vector3(0.1, -1.0, 0.0)
	process.spread = 2.0
	process.initial_velocity_min = RAIN_SPEED
	process.initial_velocity_max = RAIN_SPEED * 1.1
	return particles


func _make_snow() -> GPUParticles3D:
	var particles := _base(1100, 12.0, _particle_material(Color(1, 1, 1, 0.95), true, false))
	particles.local_coords = true
	(particles.draw_pass_1 as QuadMesh).size = _pixel_size(Vector2(2, 2), true)
	var process := particles.process_material as ParticleProcessMaterial
	process.direction = Vector3(0.2, -1.0, 0.1)
	process.spread = 25.0
	process.initial_velocity_min = 1.6
	process.initial_velocity_max = 2.6
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 1.5
	process.turbulence_noise_scale = 2.0
	return particles


func _make_leaves() -> GPUParticles3D:
	var particles := _base(24, 9.0, _particle_material(Color.WHITE, true, true))
	(particles.draw_pass_1 as QuadMesh).size = _pixel_size(Vector2(3, 2), true)
	var process := particles.process_material as ParticleProcessMaterial
	process.direction = Vector3(0.8, -0.6, 0.2)
	process.spread = 40.0
	process.initial_velocity_min = 1.0
	process.initial_velocity_max = 2.2
	process.angle_min = -180.0
	process.angle_max = 180.0
	process.angular_velocity_min = -90.0
	process.angular_velocity_max = 90.0
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 2.0
	var colors := Gradient.new()
	colors.colors = PackedColorArray([Color("7cc255"), Color("d99a3a"), Color("c7602f")])
	colors.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var ramp := GradientTexture1D.new()
	ramp.gradient = colors
	process.color_initial_ramp = ramp
	return particles


func _make_fireflies() -> GPUParticles3D:
	var particles := _base(60, 6.0, _particle_material(Color.WHITE, true, false))
	(particles.draw_pass_1 as QuadMesh).size = _pixel_size(Vector2(1, 1), true)
	var process := particles.process_material as ParticleProcessMaterial
	process.direction = Vector3(0, 1, 0)
	process.spread = 180.0
	process.initial_velocity_min = 0.2
	process.initial_velocity_max = 0.6
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.8
	process.turbulence_noise_scale = 1.5
	# Brighter than white: they glow (bloom).
	process.color = Color(2.6, 3.0, 0.9)
	process.color_ramp = _fade_ramp()
	return particles


func _make_dust() -> GPUParticles3D:
	var particles := _base(90, 9.0, _particle_material(Color.WHITE, true, true))
	(particles.draw_pass_1 as QuadMesh).size = _pixel_size(Vector2(1, 1), true)
	var process := particles.process_material as ParticleProcessMaterial
	process.direction = Vector3(0.3, 1.0, 0.0)
	process.spread = 180.0
	process.initial_velocity_min = 0.05
	process.initial_velocity_max = 0.25
	process.color = Color(0.85, 0.8, 0.7, 0.8)
	process.color_ramp = _fade_ramp()
	return particles


static func _fade_ramp() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray(
		[Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)]
	)
	gradient.offsets = PackedFloat32Array([0.0, 0.2, 0.7, 1.0])
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	return ramp
