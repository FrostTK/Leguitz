class_name LightingController
extends Node

## Sun shadow parameters for sprites that are not tiles (the player...).
signal player_shadow(sun: Vector2, strength: float)
## Drives the light of the world every frame from the time of day, the
## moon phase, the weather and the depth:
## - ambient light (CanvasModulate): dawn, day, dusk, moonlit nights,
## - the sun (a DirectionalLight2D revealing the relief through normal
##   maps) and the sun shadows of trees and props,
## - the player's lantern at night and underground,
## - cloud shadows, glow (bloom) and lightning flashes.

enum Quality { LOW, MEDIUM, HIGH, ULTRA }

const NIGHT := Color(0.15, 0.18, 0.34)
const FULL_MOON_NIGHT := Color(0.22, 0.27, 0.46)
const TWILIGHT := Color(0.95, 0.62, 0.5)
const DAY := Color(0.8, 0.8, 0.78)
const UNDERGROUND := Color(0.14, 0.13, 0.17)
const STORM_TINT := Color(0.55, 0.6, 0.7)
const SUN_WARM := Color(1.0, 0.72, 0.5)
const SUN_NOON := Color(1.0, 0.97, 0.9)
const SUN_ENERGY := 0.42
## Sunrise and sunset hours (the night lasts from sunset to sunrise).
const SUNRISE := 6.0
const SUNSET := 19.5
const SHADOW_STRENGTH := 0.3

var clock: WorldClock
var client_world: ClientWorld
var world_view: WorldView
var weather: WeatherEffects
var clouds: CloudShadows
var canvas_modulate: CanvasModulate
var sun: DirectionalLight2D
var lantern: PointLight2D
var environment: Environment
var quality: Quality = Quality.HIGH

## 0 at midday, 1 at night (read by the particles).
var darkness := 0.0


func apply_quality(value: int) -> void:
	quality = clampi(value, Quality.LOW, Quality.ULTRA) as Quality
	environment.glow_enabled = quality >= Quality.MEDIUM
	environment.glow_intensity = 0.7 if quality == Quality.MEDIUM else 0.9
	environment.set_glow_level(5, quality == Quality.ULTRA)
	clouds.visible = quality >= Quality.MEDIUM
	weather.set_particle_scale([0.3, 0.6, 1.0, 1.5][quality])


## Sun angle for an hour of the day: 0 at sunrise (east), PI/2 at the
## middle of the day (south), PI at sunset (west), then under the horizon.
static func sun_angle(hours: float) -> float:
	var day_length := SUNSET - SUNRISE
	if hours >= SUNRISE and hours <= SUNSET:
		return (hours - SUNRISE) / day_length * PI
	var since_sunset := fposmod(hours - SUNSET, 24.0)
	return PI + since_sunset / (24.0 - day_length) * PI


func _process(_delta: float) -> void:
	if clock == null or client_world == null:
		return
	var underground := client_world.layer < WorldGenerator.SURFACE_LAYER
	var angle := sun_angle(clock.time_of_day() / 3600.0)
	var elevation := sin(angle)
	var daylight := smoothstep(-0.25, 0.22, elevation)
	# Golden hour and twilight, strongest right around sunrise/sunset.
	var twilight := clampf(1.0 - absf(elevation - 0.05) / 0.4, 0.0, 1.0)
	var moon := absf(clock.moon_phase() - WorldClock.MOON_PHASES / 2.0) / 4.0
	var storm := weather.rain_intensity

	var ambient := NIGHT.lerp(FULL_MOON_NIGHT, moon).lerp(DAY, daylight)
	ambient = ambient.lerp(TWILIGHT, twilight * 0.6)
	ambient = ambient * Color.WHITE.lerp(STORM_TINT, storm * 0.85)
	if underground:
		ambient = UNDERGROUND
	var flash := weather.flash()
	ambient = Color(ambient.r + flash, ambient.g + flash, ambient.b + flash * 1.1)
	canvas_modulate.color = ambient
	darkness = 1.0 - clampf(ambient.get_luminance() / DAY.get_luminance(), 0.0, 1.0)
	weather.darkness = darkness

	var sun_power := 0.0 if underground else daylight * (1.0 - 0.75 * storm)
	sun.visible = sun_power > 0.01
	sun.energy = SUN_ENERGY * sun_power
	sun.color = SUN_WARM.lerp(SUN_NOON, smoothstep(0.05, 0.5, elevation))
	sun.height = clampf(elevation, 0.12, 0.95)
	# The light travels away from the sun (east in the morning, south at noon).
	var from_sun := -Vector2(cos(angle), 0.35 + 0.65 * maxf(elevation, 0.0)).normalized()
	sun.rotation = atan2(-from_sun.x, from_sun.y)

	var shadows_on := quality >= Quality.HIGH and not underground
	var shadow_length := clampf(0.35 + (1.0 - elevation) * 0.65, 0.3, 1.0)
	world_view.set_sun_shadows(
		Vector2(-cos(angle) * 0.5, shadow_length),
		SHADOW_STRENGTH * sun_power if shadows_on else 0.0
	)
	world_view.set_weather(weather.weather.wind_vector(), weather.wetness, storm)
	clouds.visible = quality >= Quality.MEDIUM and not underground
	clouds.set_sky(weather.weather.wind_vector(), 0.35 + storm * 0.6, 0.2 * daylight + 0.05)

	lantern.energy = clampf((0.55 - ambient.get_luminance()) * 2.4, 0.0, 1.0) * 1.6
	lantern.visible = lantern.energy > 0.02
	player_shadow.emit(
		Vector2(-cos(angle) * 0.5, shadow_length), 0.3 * sun_power if shadows_on else 0.0
	)
