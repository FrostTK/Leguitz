class_name Weather
extends RefCounted
## World weather (like Minecraft: one weather for the whole world, shown as
## rain or snow depending on the local biome) and wind.
##
## Durations are authored for the default 20-minute day and scaled by the
## world clock's pace, like every timed process.

enum Kind { CLEAR, RAIN, THUNDER }

## [min, max] real seconds at the default pace.
const DURATIONS := {
	Kind.CLEAR: [600.0, 2400.0],
	Kind.RAIN: [240.0, 720.0],
	Kind.THUNDER: [180.0, 420.0],
}
## Chance that rain turns into a thunderstorm when it starts.
const THUNDER_CHANCE := 0.3
## Wind strength range per weather (0 = still, 1 = storm).
const WIND := {
	Kind.CLEAR: [0.15, 0.45],
	Kind.RAIN: [0.45, 0.75],
	Kind.THUNDER: [0.75, 1.0],
}
const WIND_CHANGE_SECONDS := 90.0

var kind: Kind = Kind.CLEAR
## Real seconds left before the weather changes.
var remaining := 0.0
var wind_angle := 0.3
var wind_strength := 0.3

var _rng := RandomNumberGenerator.new()
var _wind_target_angle := 0.3
var _wind_target_strength := 0.3
var _wind_timer := 0.0


func _init(world_seed := 0) -> void:
	_rng.seed = HashUtil.derive_seed(world_seed, 60)
	remaining = _rng.randf_range(DURATIONS[Kind.CLEAR][0], DURATIONS[Kind.CLEAR][1])
	_pick_wind()
	wind_angle = _wind_target_angle
	wind_strength = _wind_target_strength


## Advances by `delta` real seconds. Returns true when the weather kind changed.
func tick(delta: float, clock: WorldClock) -> bool:
	_update_wind(delta)
	remaining -= delta
	if remaining > 0.0:
		return false
	set_kind(_next_kind(), clock)
	return true


func set_kind(new_kind: Kind, clock: WorldClock = null) -> void:
	kind = new_kind
	var range_seconds: Array = DURATIONS[kind]
	remaining = _rng.randf_range(range_seconds[0], range_seconds[1])
	if clock != null:
		remaining = clock.scale_duration(remaining)
	_pick_wind()


func wind_vector() -> Vector2:
	return Vector2.from_angle(wind_angle) * wind_strength


func is_raining() -> bool:
	return kind != Kind.CLEAR


func to_dict() -> Dictionary:
	return {
		"kind": kind,
		"remaining": remaining,
		"wind_angle": wind_angle,
		"wind_strength": wind_strength,
	}


func load_dict(data: Dictionary) -> void:
	kind = data.get("kind", Kind.CLEAR) as Kind
	remaining = data.get("remaining", remaining)
	wind_angle = data.get("wind_angle", wind_angle)
	wind_strength = data.get("wind_strength", wind_strength)


func _next_kind() -> Kind:
	if kind != Kind.CLEAR:
		return Kind.CLEAR
	return Kind.THUNDER if _rng.randf() < THUNDER_CHANCE else Kind.RAIN


func _pick_wind() -> void:
	var strength: Array = WIND[kind]
	_wind_target_strength = _rng.randf_range(strength[0], strength[1])
	# Prevailing westerly wind with some variation.
	_wind_target_angle = _rng.randf_range(-0.6, 0.6)
	_wind_timer = WIND_CHANGE_SECONDS


func _update_wind(delta: float) -> void:
	_wind_timer -= delta
	if _wind_timer <= 0.0:
		var strength: Array = WIND[kind]
		_wind_target_strength = _rng.randf_range(strength[0], strength[1])
		_wind_target_angle = clampf(_wind_target_angle + _rng.randf_range(-0.4, 0.4), -1.0, 1.0)
		_wind_timer = WIND_CHANGE_SECONDS
	var blend := clampf(delta * 0.05, 0.0, 1.0)
	wind_strength = lerpf(wind_strength, _wind_target_strength, blend)
	wind_angle = lerpf(wind_angle, _wind_target_angle, blend)
