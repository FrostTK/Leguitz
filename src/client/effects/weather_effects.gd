class_name WeatherEffects
extends Node2D
## Client-side weather and ambience: rain or snow (depending on the biome
## under the player), lightning, wet ground, falling leaves, fireflies at
## night and dust motes in caves. Particles run on the GPU.

const RAIN_BY_KIND := {Weather.Kind.CLEAR: 0.0, Weather.Kind.RAIN: 0.8, Weather.Kind.THUNDER: 1.0}
const FADE_PER_SECOND := 0.12
const WETTING_PER_SECOND := 0.06
const DRYING_PER_SECOND := 0.012

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

var weather := Weather.new()
var camera: Camera2D
var client_world: ClientWorld
var player: Node2D
## Glowing particles go in the emission layer (not darkened at night).
var emission_root: Node2D

## Smoothed 0..1 values read by the lighting and the shaders.
var rain_intensity := 0.0
var wetness := 0.0
var snowing := false
var darkness := 0.0
var particle_scale := 1.0

var _rain: GPUParticles2D
var _snow: GPUParticles2D
var _leaves: GPUParticles2D
var _fireflies: GPUParticles2D
var _dust: GPUParticles2D
var _flash := 0.0
var _flash_timer := 8.0
var _second_flash := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_rain = _make_rain()
	_snow = _make_snow()
	_leaves = _make_leaves()
	add_child(_rain)
	add_child(_snow)
	add_child(_leaves)


func attach_glowing(root: Node2D) -> void:
	emission_root = root
	_fireflies = _make_fireflies()
	_dust = _make_dust()
	root.add_child(_fireflies)
	root.add_child(_dust)
	set_particle_scale(particle_scale)


func set_particle_scale(scale: float) -> void:
	particle_scale = scale
	var amounts := [[_rain, 700], [_snow, 400], [_leaves, 14], [_fireflies, 40], [_dust, 50]]
	for pair: Array in amounts:
		var particles: GPUParticles2D = pair[0]
		if particles != null:
			particles.amount = maxi(1, int(pair[1] * scale))


func apply_state(data: Dictionary) -> void:
	weather.load_dict(data)


## Current lightning flash brightness (added to the ambient light).
func flash() -> float:
	return _flash


func _process(delta: float) -> void:
	if camera == null or client_world == null:
		return
	var underground := client_world.layer < WorldGenerator.SURFACE_LAYER
	var tile := Coords.world_to_tile(player.position) if player != null else Vector2i.ZERO
	var biome := client_world.biome_at(tile)
	var target: float = RAIN_BY_KIND.get(weather.kind, 0.0)
	if underground or DRY_BIOMES.has(biome):
		target = 0.0
	rain_intensity = move_toward(rain_intensity, target, FADE_PER_SECOND * delta)
	snowing = Biomes.is_cold(biome)
	if rain_intensity > 0.2 and not snowing:
		wetness = move_toward(wetness, 1.0, WETTING_PER_SECOND * delta)
	else:
		wetness = move_toward(wetness, 0.0, DRYING_PER_SECOND * delta)
	if underground:
		wetness = 0.0
	_update_lightning(delta, underground)

	var view := get_viewport_rect().size / camera.zoom
	var center := camera.get_screen_center_position()
	var wind := weather.wind_vector()
	_place(_rain, center + Vector2(0, -view.y * 0.6), view)
	_place(_snow, center + Vector2(0, -view.y * 0.3), view)
	_place(_leaves, center, view)
	_rain.amount_ratio = 0.0 if snowing else rain_intensity
	_snow.amount_ratio = rain_intensity if snowing else 0.0
	var rain_material := _rain.process_material as ParticleProcessMaterial
	rain_material.direction = Vector3(wind.x * 0.5, 1.0, 0.0)
	var leafy := not underground and LEAFY_BIOMES.has(biome)
	_leaves.amount_ratio = (0.5 + wind.length()) if leafy else 0.0
	if _fireflies != null:
		_place(_fireflies, center, view)
		_place(_dust, center, view)
		var fireflies := not underground and FIREFLY_BIOMES.has(biome)
		_fireflies.amount_ratio = darkness * (1.0 - rain_intensity) if fireflies else 0.0
		_dust.amount_ratio = 1.0 if underground else 0.0


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


func _place(particles: GPUParticles2D, center: Vector2, view: Vector2) -> void:
	particles.global_position = center
	var material := particles.process_material as ParticleProcessMaterial
	material.emission_box_extents = Vector3(view.x * 0.6, view.y * 0.6, 1.0)


static func _dot_texture(size: Vector2i, color: Color) -> ImageTexture:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


static func _base(amount: int, lifetime: float) -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.local_coords = false
	particles.preprocess = lifetime
	particles.amount_ratio = 0.0
	particles.visibility_rect = Rect2(-4000, -4000, 8000, 8000)
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.gravity = Vector3.ZERO
	particles.process_material = material
	return particles


func _make_rain() -> GPUParticles2D:
	var particles := _base(700, 0.9)
	particles.texture = _dot_texture(Vector2i(1, 6), Color(0.75, 0.85, 1.0, 0.55))
	var material := particles.process_material as ParticleProcessMaterial
	material.direction = Vector3(0.2, 1.0, 0.0)
	material.spread = 3.0
	material.initial_velocity_min = 300.0
	material.initial_velocity_max = 360.0
	material.particle_flag_align_y = true
	return particles


func _make_snow() -> GPUParticles2D:
	var particles := _base(400, 7.0)
	particles.texture = _dot_texture(Vector2i(2, 2), Color(1, 1, 1, 0.9))
	var material := particles.process_material as ParticleProcessMaterial
	material.direction = Vector3(0.2, 1.0, 0.0)
	material.spread = 25.0
	material.initial_velocity_min = 18.0
	material.initial_velocity_max = 34.0
	material.turbulence_enabled = true
	material.turbulence_noise_strength = 3.0
	material.turbulence_noise_scale = 4.0
	return particles


func _make_leaves() -> GPUParticles2D:
	var particles := _base(14, 7.0)
	particles.texture = _dot_texture(Vector2i(3, 2), Color.WHITE)
	var material := particles.process_material as ParticleProcessMaterial
	material.direction = Vector3(0.6, 1.0, 0.0)
	material.spread = 40.0
	material.initial_velocity_min = 10.0
	material.initial_velocity_max = 22.0
	material.angular_velocity_min = -90.0
	material.angular_velocity_max = 90.0
	material.turbulence_enabled = true
	material.turbulence_noise_strength = 4.0
	var colors := Gradient.new()
	colors.colors = PackedColorArray([Color("7cc255"), Color("d99a3a"), Color("c7602f")])
	colors.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var ramp := GradientTexture1D.new()
	ramp.gradient = colors
	material.color_initial_ramp = ramp
	return particles


func _make_fireflies() -> GPUParticles2D:
	var particles := _base(40, 5.0)
	particles.texture = _dot_texture(Vector2i(1, 1), Color.WHITE)
	var material := particles.process_material as ParticleProcessMaterial
	material.direction = Vector3(0, -1, 0)
	material.spread = 180.0
	material.initial_velocity_min = 3.0
	material.initial_velocity_max = 9.0
	material.turbulence_enabled = true
	material.turbulence_noise_strength = 6.0
	material.turbulence_noise_scale = 3.0
	material.color = Color(1.8, 2.0, 0.6)
	material.color_ramp = _fade_ramp()
	return particles


func _make_dust() -> GPUParticles2D:
	var particles := _base(50, 8.0)
	particles.texture = _dot_texture(Vector2i(1, 1), Color.WHITE)
	var material := particles.process_material as ParticleProcessMaterial
	material.direction = Vector3(0.3, -1, 0)
	material.spread = 180.0
	material.initial_velocity_min = 1.0
	material.initial_velocity_max = 4.0
	material.color = Color(0.6, 0.55, 0.45, 0.6)
	material.color_ramp = _fade_ramp()
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
