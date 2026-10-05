class_name LightingController
extends Node
## Drives the light of the 3D world every frame from the time of day, the
## moon phase, the weather and the depth:
## - the sky light: one shadow-casting DirectionalLight3D that is the sun by
##   day and the moon by night (it switches while both are at the horizon,
##   where its energy is zero),
## - ambient light and background: dawn, day, dusk, moonlit nights (the
##   sky light baked into the world lets as much of it reach each face:
##   none in a closed cave, see LightField),
## - the player's lantern at night and in the dark (`sky_here`),
## - fog (haze in the valleys below the player, morning mist, rain), cloud
##   shadows, glow (bloom) and lightning flashes,
## - in first person: the sky (sky.gdshader: its gradient, glows at sunrise
##   and sunset, the sun, the moon in its phase, stars, clouds matching their
##   shadows), a distance haze (the loaded world ends somewhere), sharper
##   shadows near the eye.

enum Quality { LOW, MEDIUM, HIGH, ULTRA }

const NIGHT := Color(0.34, 0.4, 0.66)
const FULL_MOON_NIGHT := Color(0.42, 0.5, 0.78)
const TWILIGHT := Color(1.0, 0.66, 0.5)
const DAY := Color(0.8, 0.84, 0.92)
const STORM_TINT := Color(0.62, 0.66, 0.74)
const SUN_WARM := Color(1.0, 0.68, 0.45)
const SUN_NOON := Color(1.0, 0.96, 0.88)
const MOON_COLOR := Color(0.6, 0.72, 1.0)
const DAY_FOG := Color(0.72, 0.8, 0.9)
const NIGHT_FOG := Color(0.1, 0.13, 0.24)
const TWILIGHT_FOG := Color(0.95, 0.6, 0.48)
const CAVE_FOG := Color(0.05, 0.04, 0.06)
const DAY_SKY := Color(0.36, 0.56, 0.86)
const NIGHT_SKY := Color(0.03, 0.04, 0.1)
const TWILIGHT_SKY := Color(0.45, 0.42, 0.7)
const SKY_SHADER := preload("res://src/client/shaders/sky.gdshader")
## The sun's disk: white-gold high up, deep orange low.
const SUN_HIGH := Color(1.0, 0.94, 0.78)
const SUN_LOW := Color(1.0, 0.46, 0.16)
## The clouds' layer over the sea (local units).
const CLOUD_LEVEL := 70.0

const DAY_AMBIENT_ENERGY := 0.62
const NIGHT_AMBIENT_ENERGY := 0.3
const SUN_ENERGY := 0.95
const MOON_ENERGY := 0.3
const MIN_ELEVATION := 12.0
const MAX_ELEVATION := 62.0
## Sunrise and sunset hours (the night lasts from sunset to sunrise).
const SUNRISE := 6.0
const SUNSET := 19.5
## Haze in the valleys: starts this far below the player, then thickens
## by VALLEY_HAZE per unit of depth.
const VALLEY_HAZE_BELOW := 5.0
const VALLEY_HAZE := 0.03
const SHADOW_SIZES: Array[int] = [1024, 2048, 4096, 8192]
const PARTICLE_SCALES: Array[float] = [0.3, 0.6, 1.0, 1.5]
## Shadows reach this far beyond the ground at the top of the screen
## (valleys below the player show farther away).
const SHADOW_MARGIN := 20.0
## First person: the haze reaches this much at this distance (world units),
## underground the fog closes in; shadows reach this far from the eye.
const FIRST_PERSON_HAZE := 0.6
## The haze's distance for each chunk seen in first person (Settings.far_view,
## Settings.effective_far_view;
## 80 for 6).
const FIRST_PERSON_HAZE_PER_CHUNK := 80.0 / 6.0
const FIRST_PERSON_CAVE_FOG := 0.5
const FIRST_PERSON_CAVE_FOG_DISTANCE := 28.0
const FIRST_PERSON_SHADOW_DISTANCE := 45.0
## How fast `sky_seen` follows `sky_here` (per second).
const SKY_SHARPNESS := 4.0

var clock: WorldClock
var client_world: ClientWorld
## Deep under the rock: no sun, cave fog.
var underground := false
## The sky light where the player is (0..1, see WorldView3D.sky_at), and
## the one their eyes got used to (following it): in the dark, the lantern
## lights up and the body darkens.
var sky_here := 1.0
var sky_seen := 1.0
var weather: WeatherEffects
var environment: Environment
var sun: DirectionalLight3D
var lantern: OmniLight3D
var clouds: CloudShadows3D
## Height of the camera target (the player), for the valley haze.
var reference_height := 0.0
## Distance from the camera to the player (for the fog).
var camera_distance := 80.0
## Distance from the camera to the ground at the top of the screen: a
## lower camera sees much farther, and the shadows must reach that far.
var view_depth := 80.0
## 0 = top-down view, 1 = first person (see WorldViewport.first_person).
var first_person := 0.0
var quality: Quality = Quality.HIGH

## 0 in daylight, 1 in the dark (read by the particles and the lantern).
var darkness := 0.0
## Seconds the lantern stays out (lantern_out).
var _lantern_out := 0.0

var _sky_material := ShaderMaterial.new()


func _ready() -> void:
	environment.background_mode = Environment.BG_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.glow_intensity = 0.6
	environment.glow_bloom = 0.02
	environment.glow_hdr_threshold = 1.0
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	environment.ssao_radius = 1.4
	environment.ssao_intensity = 1.6
	environment.ssao_power = 1.4
	environment.ssao_light_affect = 0.15
	environment.ssil_radius = 3.0
	environment.ssil_intensity = 0.6
	environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	environment.fog_sky_affect = 0.0
	# Only seen in first person (the lights use their own colors).
	var sky := Sky.new()
	sky.sky_material = _sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	environment.sky = sky
	_sky_material.shader = SKY_SHADER

	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 0.6
	sun.light_angular_distance = 0.4
	lantern.shadow_bias = 0.05


func apply_quality(value: int) -> void:
	quality = clampi(value, Quality.LOW, Quality.ULTRA) as Quality
	var high := quality >= Quality.HIGH
	sun.shadow_enabled = quality >= Quality.MEDIUM
	sun.shadow_blur = 1.5 if high else 1.0
	RenderingServer.directional_shadow_atlas_set_size(SHADOW_SIZES[quality], true)
	var soft := RenderingServer.SHADOW_QUALITY_SOFT_LOW
	if quality == Quality.ULTRA:
		soft = RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM
	elif quality == Quality.LOW:
		soft = RenderingServer.SHADOW_QUALITY_HARD
	RenderingServer.directional_soft_shadow_filter_set_quality(soft)
	RenderingServer.positional_soft_shadow_filter_set_quality(soft)
	lantern.shadow_enabled = high
	environment.glow_enabled = quality >= Quality.MEDIUM
	environment.ssao_enabled = high
	environment.ssil_enabled = quality == Quality.ULTRA
	environment.fog_enabled = quality >= Quality.MEDIUM
	clouds.visible = high
	weather.set_particle_scale(PARTICLE_SCALES[quality])


## Sun angle for an hour of the day: 0 at sunrise (east), PI/2 at the
## middle of the day (south), PI at sunset (west), then under the horizon
## (the moon takes over: its angle is this one minus PI).
static func sun_angle(hours: float) -> float:
	var day_length := SUNSET - SUNRISE
	if hours >= SUNRISE and hours <= SUNSET:
		return (hours - SUNRISE) / day_length * PI
	var since_sunset := fposmod(hours - SUNSET, 24.0)
	return PI + since_sunset / (24.0 - day_length) * PI


## Direction towards a sky light at `angle` (0..PI): it rises in the east
## (+X), culminates in the south (+Z, towards the camera) and sets in the
## west, never too low so shadows stay readable.
static func sky_direction(angle: float) -> Vector3:
	var arc := clampf(sin(angle), 0.0, 1.0)
	var horizontal := Vector2(cos(angle), 0.35 + 0.65 * arc).normalized()
	var elevation := deg_to_rad(lerpf(MIN_ELEVATION, MAX_ELEVATION, arc))
	return Vector3(horizontal.x * cos(elevation), sin(elevation), horizontal.y * cos(elevation))


## A lantern moth's blow: the lantern goes out for `seconds`, sputtering
## back at the end.
func lantern_out(seconds: float) -> void:
	_lantern_out = seconds


func _process(delta: float) -> void:
	if clock == null or client_world == null:
		return
	_lantern_out = maxf(_lantern_out - delta, 0.0)
	var hours := clock.time_of_day() / 3600.0
	var angle := sun_angle(hours)
	var sun_height := sin(angle)
	var daylight := smoothstep(-0.25, 0.22, sun_height)
	# Golden hour and twilight, strongest right around sunrise/sunset.
	var twilight := clampf(1.0 - absf(sun_height - 0.05) / 0.4, 0.0, 1.0)
	var moon := absf(clock.moon_phase() - WorldClock.MOON_PHASES / 2.0) / 4.0
	var storm := weather.rain_intensity

	var ambient := NIGHT.lerp(FULL_MOON_NIGHT, moon).lerp(DAY, daylight)
	ambient = ambient.lerp(TWILIGHT, twilight * 0.55)
	ambient = ambient * Color.WHITE.lerp(STORM_TINT, storm * 0.85)
	var ambient_energy := lerpf(NIGHT_AMBIENT_ENERGY, DAY_AMBIENT_ENERGY, daylight)
	ambient_energy *= 1.0 - storm * 0.25
	environment.ambient_light_color = ambient
	environment.ambient_light_energy = ambient_energy + weather.flash() * 2.5
	environment.adjustment_enabled = not is_equal_approx(Settings.brightness, 1.0)
	environment.adjustment_brightness = Settings.brightness
	sky_seen = lerpf(sky_seen, sky_here, 1.0 - exp(-SKY_SHARPNESS * delta))
	darkness = clampf(1.0 - daylight * (1.0 - storm * 0.4), 0.0, 1.0)
	darkness = maxf(darkness, 1.0 - smoothstep(0.0, 1.0, sky_seen))
	weather.darkness = darkness

	_update_sky_light(angle, moon, storm, underground)
	_update_fog(hours, daylight, twilight, storm, underground)
	environment.background_color = environment.fog_light_color.darkened(0.2)
	_update_sky(daylight, twilight, storm, underground, angle)
	lantern.light_energy = clampf(darkness * 2.0 - 0.4, 0.0, 1.6)
	if _lantern_out > 0.0:
		# Out; in its last second it sputters back.
		var sputter := 1.0 - _lantern_out if _lantern_out < 1.0 else 0.0
		lantern.light_energy *= sputter * (0.5 + 0.5 * sin(_lantern_out * 40.0))
	lantern.visible = lantern.light_energy > 0.02
	clouds.visible = quality >= Quality.HIGH and not underground
	clouds.set_sky(weather.weather.wind_vector(), 0.3 + storm * 0.55)


func _update_sky_light(angle: float, moon: float, storm: float, underground: bool) -> void:
	var is_day := angle <= PI
	var light_angle := angle if is_day else angle - PI
	var rise := smoothstep(0.0, 0.1, sin(light_angle))
	var energy: float
	var color: Color
	if is_day:
		energy = SUN_ENERGY * rise
		# Golden hour: warm light while the sun is low.
		color = SUN_WARM.lerp(SUN_NOON, smoothstep(0.15, 0.55, sin(light_angle)))
	else:
		energy = MOON_ENERGY * (0.35 + 0.65 * moon) * rise
		color = MOON_COLOR
	energy *= 1.0 - 0.8 * storm
	if underground:
		energy = 0.0
	sun.light_energy = energy
	sun.light_color = color
	sun.visible = energy > 0.001
	var top_down_shadows := view_depth + SHADOW_MARGIN
	sun.directional_shadow_max_distance = lerpf(
		top_down_shadows, FIRST_PERSON_SHADOW_DISTANCE, first_person
	)
	# In perspective, split shadows keep them sharp near the eye.
	sun.directional_shadow_mode = (
		DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		if first_person > 0.5
		else DirectionalLight3D.SHADOW_ORTHOGONAL
	)
	_aim(sun, sky_direction(light_angle))


func _update_fog(
	hours: float, daylight: float, twilight: float, storm: float, underground: bool
) -> void:
	var color := NIGHT_FOG.lerp(DAY_FOG, daylight).lerp(TWILIGHT_FOG, twilight * 0.5)
	color = color.lerp(color * STORM_TINT, storm)
	# Morning mist: rises before dawn, burns off by mid-morning.
	var mist := smoothstep(SUNRISE - 1.5, SUNRISE, hours) * (1.0 - smoothstep(7.5, 9.5, hours))
	var amount := maxf(mist * 0.14, storm * 0.1)
	var haze := VALLEY_HAZE
	if underground:
		color = CAVE_FOG
		amount = 0.2
		haze = VALLEY_HAZE * 2.0
	environment.fog_light_color = color
	# Exponential fog reaches `amount` at the player's distance; in first
	# person, a haze over the distance instead.
	var distance := camera_distance
	if first_person > 0.0:
		var far_amount := FIRST_PERSON_CAVE_FOG if underground else FIRST_PERSON_HAZE
		var far_distance := (
			FIRST_PERSON_CAVE_FOG_DISTANCE
			if underground
			else FIRST_PERSON_HAZE_PER_CHUNK * Settings.effective_far_view()
		)
		amount = lerpf(amount, maxf(amount, far_amount), first_person)
		distance = lerpf(distance, far_distance, first_person)
	environment.fog_density = -log(1.0 - amount) / distance
	environment.fog_height = reference_height - VALLEY_HAZE_BELOW
	environment.fog_height_density = haze


## The sky behind the horizon, in first person in the open air.
func _update_sky(
	daylight: float, twilight: float, storm: float, underground: bool, angle: float
) -> void:
	var open_sky := first_person > 0.0 and not underground
	environment.background_mode = Environment.BG_SKY if open_sky else Environment.BG_COLOR
	if not open_sky:
		return
	var top := NIGHT_SKY.lerp(DAY_SKY, daylight).lerp(TWILIGHT_SKY, twilight * 0.4)
	top = top.lerp(top * STORM_TINT, storm)
	var horizon := environment.fog_light_color
	var sky := _sky_material
	sky.set_shader_parameter("top_color", top)
	sky.set_shader_parameter("horizon_color", horizon)
	sky.set_shader_parameter("ground_color", horizon.darkened(0.55))
	var sun_dir := sky_body_direction(angle)
	sky.set_shader_parameter("sun_dir", sun_dir)
	sky.set_shader_parameter("moon_dir", sky_body_direction(angle - PI))
	var high := smoothstep(0.0, 0.5, sun_dir.y)
	sky.set_shader_parameter("sun_color", SUN_LOW.lerp(SUN_HIGH, high))
	sky.set_shader_parameter("twilight", twilight)
	sky.set_shader_parameter("night", 1.0 - smoothstep(0.0, 0.6, daylight + twilight * 0.3))
	sky.set_shader_parameter("storm", storm)
	# Full at phase 0, new halfway (WorldClock.moon_phase).
	var phase := float(clock.moon_phase()) / WorldClock.MOON_PHASES
	sky.set_shader_parameter("moon_light", PI - phase * TAU)
	sky.set_shader_parameter("cloud_coverage", clouds.coverage)
	sky.set_shader_parameter("cloud_drift", clouds.drift)
	sky.set_shader_parameter("cloud_scale", CloudShadows3D.CLOUD_SCALE)
	sky.set_shader_parameter("cloud_height", CLOUD_LEVEL)
	sky.set_shader_parameter("star_turn", clock.time_of_day() / 86400.0 * TAU)


## Where the sun (or the moon: `angle` - PI) shows in the sky, towards it:
## the azimuth of sky_direction, but on its true arc, down to the horizon
## and under it at its rise and set (the light keeps a little higher).
static func sky_body_direction(angle: float) -> Vector3:
	var arc := sin(angle)
	var horizontal := Vector2(cos(angle), 0.35 + 0.65 * clampf(arc, 0.0, 1.0)).normalized()
	var elevation := deg_to_rad(MAX_ELEVATION) * arc
	return Vector3(horizontal.x * cos(elevation), sin(elevation), horizontal.y * cos(elevation))


## Points a directional light so that it shines from `towards_light`.
static func _aim(light: DirectionalLight3D, towards_light: Vector3) -> void:
	light.basis = Basis.looking_at(-towards_light, Vector3.UP)
